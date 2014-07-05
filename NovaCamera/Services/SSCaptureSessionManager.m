//
//  SSCaptureSessionManager.m
//  NovaCamera
//
//  Created by Mike Matz on 1/2/14.
//  Copyright (c) 2014 Sneaky Squid. All rights reserved.
//
//  Largely based on Apple's AVCam sample code

#import "SSCaptureSessionManager.h"
#import <CoreMedia/CoreMedia.h>
#import <AVFoundation/AVCaptureSession.h>


// These constants are used to determine how long to pause before taking a photo to ensure focus/exposure/whitebalance are correct:

// How long to pause when photo is first requested, allowing the camera hardware to determine it needs to adjust focus/exposure/whitebalance.
const double kPauseToAllowCameraToDetermineItNeedsAdjustment = 0.2;
// The checks are performed in a loop until the all succeed. Time to sleep between checks.
const double kPauseBetweenEachAdjustmentCheck = 0.01;
// How long to attempt the adjustments, before giving up and taking the photo anyway.
const double kCameraAdjustmentTimeout = 1.5;
// Once all adjustments are complete, ensure they remain stable for this time period before proceeding. Prevents jitter.
const double kDurationCameraAdjustmentsNeedToSettle = 0.05;


static void * CapturingStillImageContext = &CapturingStillImageContext;
static void * AdjustingFocusContext = &AdjustingFocusContext;
static void * AdjustingExposureContext = &AdjustingExposureContext;
static void * AdjustingWhiteBalanceContext = &AdjustingWhiteBalanceContext;
static void * LowLightBoostEnabledContext = &LowLightBoostEnabledContext;
static void * TorchActiveContext = &TorchActiveContext;
static void * TorchLevelContext = &TorchLevelContext;

@interface SSCaptureSessionManager () {
    BOOL _sessionHasBeenConfigured;
    AVCaptureVideoOrientation _orientation;
}

@property (nonatomic, strong) dispatch_queue_t sessionQueue;
@property (nonatomic, readonly) AVCaptureDevice *device;
@property (nonatomic, strong) AVCaptureDeviceInput *deviceInput;
@property (nonatomic, strong) AVCaptureStillImageOutput *stillImageOutput;
@property (nonatomic, strong) id runtimeErrorObserver;
@property (nonatomic, copy) void (^shutterHandler)(int shutterCurtain);

- (BOOL)setDevice:(AVCaptureDevice *)device withError:(NSError **)error;
- (BOOL)configureSession;
- (void)subjectAreaDidChange:(NSNotification *)notification;
- (void)deviceOrientationDidChange;

@end

@implementation SSCaptureSessionManager

@synthesize session=_session;
@synthesize previewLayer=_previewLayer;
@synthesize videoGravity=_videoGravity;
@synthesize videoScaleAndCropFactor=_videoScaleAndCropFactor;

@synthesize sessionQueue=_sessionQueue;
@synthesize device=_device;

#pragma mark - NSObject

- (id)init {
    self = [super init];
    if (self) {
        // Defaults
        self.videoScaleAndCropFactor = 1.0;
        self.shouldAutoFocusAndAutoExposeOnDeviceAreaChange = NO;
        self.videoGravity = AVLayerVideoGravityResizeAspectFill;
        
        // Create session
        _session = [[AVCaptureSession alloc] init];
    }
    return self;
}

+ (id)sharedService {
    static id _sharedService;
    static dispatch_once_t once;

    dispatch_once(&once, ^{
        _sharedService = [[self alloc] init];
    });

    return _sharedService;
}

#pragma mark - Public methods
#pragma mark Session lifecycle

- (void)startSession {
    dispatch_async(self.sessionQueue, ^{
        
        // Configure session (one time per session)
        if (!_sessionHasBeenConfigured) {
            if (![self configureSession]) {
                // Unable to start session
                [self willChangeValueForKey:@"session"];
                _session = nil;
                [self didChangeValueForKey:@"session"];
            }
        }
        
        if (_sessionHasBeenConfigured) {
            // Add observer for image capture (shutter indication)
            [self addObserver:self forKeyPath:@"stillImageOutput.capturingStillImage" options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) context:CapturingStillImageContext];

            // Add error notification observer
            __block typeof(self) bSelf = self;
            self.runtimeErrorObserver = [[NSNotificationCenter defaultCenter] addObserverForName:AVCaptureSessionRuntimeErrorNotification object:self.session queue:nil usingBlock:^(NSNotification *note) {
                dispatch_async(bSelf.sessionQueue, ^{
                    // Manually restarting the session since it must have been stopped due to an error.
                    DDLogError(@"Received AVCaptureSessionRuntimeErrorNotification; restarting session");
                    [bSelf.session startRunning];
                });
            }];
            
            // Add device orientation observer
            [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceOrientationDidChange) name:UIDeviceOrientationDidChangeNotification object:nil];
            // Setup initial orientation
            [self deviceOrientationDidChange];

            [self addDeviceObservers:self.device];

            // Start the capture session
            [self.session startRunning];
        }
    });
}

- (void)stopSession {
    dispatch_async(self.sessionQueue, ^{
        if (_sessionHasBeenConfigured) {
            
            [self removeObserver:self forKeyPath:@"stillImageOutput.capturingStillImage" context:CapturingStillImageContext];
            [[NSNotificationCenter defaultCenter] removeObserver:self.runtimeErrorObserver];
            [[NSNotificationCenter defaultCenter] removeObserver:self name:UIDeviceOrientationDidChangeNotification object:nil];

            [self removeDeviceObservers:self.device];

            [self.session stopRunning];
        }
    });
}

#pragma mark Authorization

- (void)checkDeviceAuthorizationWithCompletion:(void (^)(BOOL isAuthorized))completion {
    [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
        self.deviceAuthorized = granted;
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(granted);
            });
        }
    }];
}

#pragma mark Camera interaction

- (void)focusOnDevicePoint:(CGPoint)devicePoint {
    [self setFocusMode:AVCaptureFocusModeContinuousAutoFocus atDevicePoint:[self constrainBounds:devicePoint] isActive:YES];
}

- (void)exposeOnDevicePoint:(CGPoint)devicePoint {
    [self setExposureMode:AVCaptureExposureModeContinuousAutoExposure atDevicePoint:[self constrainBounds:devicePoint] isActive:YES];
}

- (void)focusReset {
    [self setFocusMode:AVCaptureFocusModeContinuousAutoFocus atDevicePoint:CGPointMake(0.5f, 0.5f) isActive:NO];
}

- (void)exposeReset {
    [self setExposureMode:AVCaptureExposureModeContinuousAutoExposure atDevicePoint:CGPointMake(0.5f, 0.5f) isActive:NO];
}

// Ensure point is never beyond (0,0) - (1,1) coords
- (CGPoint)constrainBounds:(CGPoint) devicePoint {
    return CGPointMake(
            MIN(1, MAX(0, devicePoint.x)),
            MIN(1, MAX(0, devicePoint.y)));
}

- (void)setFocusMode:(AVCaptureFocusMode)mode atDevicePoint:(CGPoint)devicePoint isActive:(BOOL)active {
    dispatch_async(self.sessionQueue, ^{
        NSError *error = nil;
        BOOL success = NO;

        if ([self.device lockForConfiguration:&error]) {
            if ([self.device isFocusPointOfInterestSupported]) {
                if ([self.device isFocusModeSupported:mode]) {
                    self.device.focusPointOfInterest = devicePoint;
                    self.device.focusMode = mode;
                    success = YES;
                }
            }
            [self.device unlockForConfiguration];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [self willChangeValueForKey:@"focusLockAvailable"];
            _focusLockAvailable = success;
            [self didChangeValueForKey:@"focusLockAvailable"];

            [self willChangeValueForKey:@"focusLockActive"];
            _focusLockActive = success && active;
            [self didChangeValueForKey:@"focusLockActive"];

            [self willChangeValueForKey:@"focusLockDevicePoint"];
            _focusLockDevicePoint = devicePoint;
            [self didChangeValueForKey:@"focusLockDevicePoint"];
        });
    });
}

- (void)setExposureMode:(AVCaptureExposureMode)mode atDevicePoint:(CGPoint)devicePoint isActive:(BOOL)active {
    dispatch_async(self.sessionQueue, ^{
        NSError *error = nil;
        BOOL success = NO;

        if ([self.device lockForConfiguration:&error]) {
            if ([self.device isExposurePointOfInterestSupported]) {
                if ([self.device isExposureModeSupported:mode]) {
                    self.device.exposureMode = mode;
                    self.device.exposurePointOfInterest = devicePoint;
                    success = YES;
                }
            }
            [self.device unlockForConfiguration];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [self willChangeValueForKey:@"exposureLockAvailable"];
            _exposureLockAvailable = success;
            [self didChangeValueForKey:@"exposureLockAvailable"];

            [self willChangeValueForKey:@"exposureLockActive"];
            _exposureLockActive = success && active;
            [self didChangeValueForKey:@"exposureLockActive"];

            [self willChangeValueForKey:@"exposureLockDevicePoint"];
            _exposureLockDevicePoint = devicePoint;
            [self didChangeValueForKey:@"exposureLockDevicePoint"];
        });
    });
}

- (void)toggleCamera {
    dispatch_async(self.sessionQueue, ^{
        NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
        if (devices.count > 1) {
            AVCaptureDevice *newDevice;
            NSInteger idx = [devices indexOfObject:self.device];
            if (idx > 0) {
                newDevice = devices[0];
            } else {
                newDevice = devices[1];
            }
            
            NSError *error = nil;
            [self setDevice:newDevice withError:&error];
            if (error) {
                DDLogError(@"Error changing device: %@", error);
            }
        }
    });
}

- (void)captureStillImageWithCompletionHandler:(void (^)(NSData *imageData, UIImage *image, NSError *error))completion shutterHandler:(void (^)(int shutterCurtain))shutter {
    self.shutterHandler = shutter;
    dispatch_async(self.sessionQueue, ^{
        // Set up capture connection

        
        // Before we take the photo, let's give the focus/exposure/whitebalance a chance to adapt to the new light.
        // Focus now

        // Focus/expose/whitebalance now
        NSError *error;
        if ([self.device lockForConfiguration:&error]) {
            if ([self.device isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus]) {
                self.device.focusMode = AVCaptureFocusModeContinuousAutoFocus;
            }
            if ([self.device isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure]) {
                self.device.exposureMode = AVCaptureExposureModeContinuousAutoExposure;
            }
            if ([self.device isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance]) {
                self.device.whiteBalanceMode = AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance;
            }
            [self.device unlockForConfiguration];
        }

        // Pause a little, to allow the camera to determine if it needs to adjust itself.
        // Because we're on a background thread we can block without locking up the UI.
        [NSThread sleepForTimeInterval:kPauseToAllowCameraToDetermineItNeedsAdjustment];

        // Go into a loop, checking if the camera focus/exposure/whitebalance is still adjusting.
        // When all have stopped adjusting, keep going for a little longer to confirm they've settled.
        // If they have settled for kDurationCameraAdjustmentsNeedToSettle seconds, we're ready to take the photo.
        // If they never settle, this will eventually timeout.
        int successCount = 0;
        for (int i = 0; i < kCameraAdjustmentTimeout / kPauseBetweenEachAdjustmentCheck; i++) {
            if (!self.device.isAdjustingFocus && !self.device.isAdjustingExposure && !self.device.isAdjustingWhiteBalance) {
                successCount++;
                if (successCount > kDurationCameraAdjustmentsNeedToSettle / kPauseBetweenEachAdjustmentCheck) {
                    break;
                }
            } else {
                successCount = 0;
            }
            [NSThread sleepForTimeInterval:kPauseBetweenEachAdjustmentCheck];
        }

        AVCaptureConnection *connection = [self.stillImageOutput connectionWithMediaType:AVMediaTypeVideo];
        if (self.videoScaleAndCropFactor <= connection.videoMaxScaleAndCropFactor) {
            connection.videoScaleAndCropFactor = self.videoScaleAndCropFactor;
        } else {
            DDLogError(@"Unable to set videoScaleAndCropFactor %g as it is beyond the current AVCaptureConnection's maximum of %g", self.videoScaleAndCropFactor, connection.videoMaxScaleAndCropFactor);
        }
        
        // Attempt to set orientation
        if ([connection isVideoOrientationSupported]) {
            connection.videoOrientation = _orientation;
        }

        [self.stillImageOutput captureStillImageAsynchronouslyFromConnection:connection completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
            // Save to asset library
            if (imageDataSampleBuffer) {
                if (completion) {
                    NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
                    UIImage *image = [[UIImage alloc] initWithData:imageData];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completion(imageData, image, error);
                    });
                }
            } else if (error) {
                DDLogError(@"Error capturing image: %@", error);
                if (completion) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completion(nil, nil, error);
                    });
                }
            }
        }];
    });
}

#pragma mark - Properties

- (void)setLightBoostEnabled:(BOOL)lightBoostEnabled {
    [self willChangeValueForKey:@"lightBoostEnabled"];
    _lightBoostEnabled = lightBoostEnabled;
    [self didChangeValueForKey:@"lightBoostEnabled"];

    dispatch_async(self.sessionQueue, ^{
        NSError *error = nil;
        if ([_device lockForConfiguration:&error]) {
            if (_device.lowLightBoostSupported) {
                _device.automaticallyEnablesLowLightBoostWhenAvailable = lightBoostEnabled;
            }
            [_device unlockForConfiguration];
        } else {
            DDLogError(@"Error locking device %@ for configuration: %@", _device, error);
        }
    });
}

- (AVCaptureSession *)session {
    return _session;
}

- (AVCaptureVideoPreviewLayer *)previewLayer {
    if (!_previewLayer) {
        [self willChangeValueForKey:@"previewLayer"];
        _previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.session];
        _previewLayer.videoGravity = self.videoGravity;
        [self didChangeValueForKey:@"previewLayer"];
    }
    return _previewLayer;
}

- (void)setVideoGravity:(NSString *)videoGravity {
    if (videoGravity != _videoGravity) {
        [self willChangeValueForKey:@"videoGravity"];
        _videoGravity = [videoGravity copy];
        self.previewLayer.videoGravity = _videoGravity;
        [self didChangeValueForKey:@"videoGravity"];
    }
}

- (void)setVideoScaleAndCropFactor:(CGFloat)videoScaleAndCropFactor {
    DDLogVerbose(@"setVideoScaleAndCropFactor:%g", videoScaleAndCropFactor);
    if (_videoScaleAndCropFactor != videoScaleAndCropFactor) {
        [self willChangeValueForKey:@"videoScaleAndCropFactor"];
        _videoScaleAndCropFactor = videoScaleAndCropFactor;
        [self didChangeValueForKey:@"videoScaleAndCropFactor"];
        
        // Attempt to set in the running session
        if (self.sessionRunningAndDeviceAuthorized) {
            dispatch_async(self.sessionQueue, ^{
                AVCaptureConnection *connection = [self.stillImageOutput connectionWithMediaType:AVMediaTypeVideo];
                if (connection) {
                    if (self.videoScaleAndCropFactor <= connection.videoMaxScaleAndCropFactor) {
                        DDLogVerbose(@"Setting videoScaleAndCropFactor to %g on currently running session", videoScaleAndCropFactor);
                        connection.videoScaleAndCropFactor = videoScaleAndCropFactor;
                    } else {
                        DDLogError(@"Unable to set videoScaleAndCropFactor %g as it is beyond the current AVCaptureConnection's maximum of %g", videoScaleAndCropFactor, connection.videoMaxScaleAndCropFactor);
                    }
                }
            });
        }
    }
}

- (BOOL)isSessionRunningAndDeviceAuthorized {
    return [self.session isRunning] && [self isDeviceAuthorized];
}

- (BOOL)canToggleCamera {
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    return (devices.count > 1);
}

#pragma mark - Private methods & properties

- (void)addDeviceObservers:(AVCaptureDevice *)device {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(subjectAreaDidChange:) name:AVCaptureDeviceSubjectAreaDidChangeNotification object:device];
    [device addObserver:self forKeyPath:@"adjustingFocus" options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) context:AdjustingFocusContext];
    [device addObserver:self forKeyPath:@"adjustingExposure" options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) context:AdjustingExposureContext];
    [device addObserver:self forKeyPath:@"adjustingWhiteBalance" options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) context:AdjustingWhiteBalanceContext];
    [device addObserver:self forKeyPath:@"lowLightBoostEnabled" options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) context:LowLightBoostEnabledContext];
    [device addObserver:self forKeyPath:@"torchActive" options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) context:TorchActiveContext];
    [device addObserver:self forKeyPath:@"torchLevel" options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) context:TorchLevelContext];
}

- (void)removeDeviceObservers:(AVCaptureDevice *)device {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVCaptureDeviceSubjectAreaDidChangeNotification object:device];
    [device removeObserver:self forKeyPath:@"adjustingFocus" context:AdjustingFocusContext];
    [device removeObserver:self forKeyPath:@"adjustingExposure" context:AdjustingExposureContext];
    [device removeObserver:self forKeyPath:@"adjustingWhiteBalance" context:AdjustingWhiteBalanceContext];
    [device removeObserver:self forKeyPath:@"lowLightBoostEnabled" context:LowLightBoostEnabledContext];
    [device removeObserver:self forKeyPath:@"torchActive" context:TorchActiveContext];
    [device removeObserver:self forKeyPath:@"torchLevel" context:TorchLevelContext];
}

- (BOOL)setDevice:(AVCaptureDevice *)device withError:(NSError **)outError {
    NSError *error = nil;
    AVCaptureDevice *prevDevice = _device;
    DDLogVerbose(@"setDevice:%@", device);
    
    AVCaptureDeviceInput *newInput = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
    if (error) {
        DDLogError(@"Error creating device input: %@ for device: %@", error, device);
        *outError = error;
        return NO;
    }
    
    [self.session beginConfiguration];
    
    // Remove current device input before adding new
    if (self.deviceInput) {
        [self.session removeInput:self.deviceInput];
    }
    
    if (![self.session canAddInput:newInput]) {
        DDLogError(@"Unable to add new input %@", newInput);
        if (self.deviceInput) {
            // Attempt to restore state by adding previous input
            [self.session addInput:self.deviceInput];
        }
        return NO;
    }
    
    [self.session addInput:newInput];
    self.deviceInput = newInput;

    [self.session commitConfiguration];

    [self willChangeValueForKey:@"device"];
    _device = device;
    [self didChangeValueForKey:@"device"];

    // Because this is a different device, set continuous autofocus and autoexposure on center point
    [self focusReset];
    [self exposeReset];

    if ([_device lockForConfiguration:&error]) {

        // Ensure subject area change notifications are enabled
        if (!_device.subjectAreaChangeMonitoringEnabled) {
            _device.subjectAreaChangeMonitoringEnabled = YES;
        }

        // Attempt to boost low light scenese
        if (_device.lowLightBoostSupported) {
            _device.automaticallyEnablesLowLightBoostWhenAvailable = self.lightBoostEnabled;
        }

        // If necessary, use torch to help focus
        //if (_device.hasTorch && _device.torchAvailable) {
        //    _device.torchMode = AVCaptureTorchModeAuto;
        //}

        [_device unlockForConfiguration];
    } else {
        DDLogError(@"Error locking device %@ for configuration: %@", _device, error);
    }

    if (prevDevice) {
        // Re-subscribe observer
        [self removeDeviceObservers:prevDevice];
        [self addDeviceObservers:_device];
    }
    
    return YES;
}

- (BOOL)configureSession {
    self.session.sessionPreset = AVCaptureSessionPresetPhoto;
    
    // Find suitable capture device (default to back facing)
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    AVCaptureDevice *selectedDevice = [devices firstObject];
    for (AVCaptureDevice *device in devices) {
        if (device.position == AVCaptureDevicePositionBack) {
            selectedDevice = device;
            break;
        }
    }
    
    // Set up device
    NSError *error = nil;
    if (![self setDevice:selectedDevice withError:&error]) {
        // Error setting up device
        DDLogError(@"Error setting up device; giving up. %@", error);
        return NO;
    }
    
    // Configure still image output
    AVCaptureStillImageOutput *stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
    DDLogVerbose(@"Current session outputs: %@", self.session.outputs);
    if ([self.session canAddOutput:stillImageOutput]) {
        [self.session addOutput:stillImageOutput];
        self.stillImageOutput = stillImageOutput;
    } else {
        DDLogError(@"Unable to add still image output");
        self.stillImageOutput = nil;
        return NO;
    }
    
    _sessionHasBeenConfigured = YES;
    return YES;
}

- (void)subjectAreaDidChange:(NSNotification *)notification {
    if (self.shouldAutoFocusAndAutoExposeOnDeviceAreaChange) {
        [self focusReset];
        [self exposeReset];
    }
}
             
- (void)deviceOrientationDidChange {
    UIDeviceOrientation deviceOrientation = [[UIDevice currentDevice] orientation];
    switch (deviceOrientation) {
        case UIDeviceOrientationPortrait:
        default:
            _orientation = AVCaptureVideoOrientationPortrait;
            break;
        case UIDeviceOrientationPortraitUpsideDown:
            _orientation = AVCaptureVideoOrientationPortraitUpsideDown;
            break;
        case UIDeviceOrientationLandscapeLeft:
            // Swap right and left?
            _orientation = AVCaptureVideoOrientationLandscapeRight;
            break;
        case UIDeviceOrientationLandscapeRight:
            // Swap right and left?
            _orientation = AVCaptureVideoOrientationLandscapeLeft;
            break;
    }
}

- (dispatch_queue_t)sessionQueue {
    if (!_sessionQueue) {
        self.sessionQueue = dispatch_queue_create("capture session queue", DISPATCH_QUEUE_SERIAL);
    }
    return _sessionQueue;
}

#pragma mark - KVO

+ (NSSet *)keyPathsForValuesAffectingSessionRunningAndDeviceAuthorized {
    return [NSSet setWithObjects:@"session.running", @"deviceAuthorized", nil];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    dispatch_async(dispatch_get_main_queue(), ^{


        if (context == CapturingStillImageContext) {
            BOOL isCapturingStillImage = [change[NSKeyValueChangeNewKey] boolValue];

            int shutterCurtain;
            if (isCapturingStillImage) {
                shutterCurtain = 1;
            } else {
                shutterCurtain = 2;
            }

            if (self.shutterHandler) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.shutterHandler(shutterCurtain);
                });
            }
        }
        if (context == AdjustingFocusContext) {
            [self willChangeValueForKey:@"focusLockAdjusting"];
            _focusLockAdjusting = self.device.adjustingFocus;
            [self didChangeValueForKey:@"focusLockAdjusting"];
        }
        if (context == AdjustingExposureContext) {
            [self willChangeValueForKey:@"exposureLockAdjusting"];
            _exposureLockAdjusting = self.device.adjustingExposure;
            [self didChangeValueForKey:@"exposureLockAdjusting"];
        }
        if (context == AdjustingWhiteBalanceContext) {
            // ...
        }
        if (context == LowLightBoostEnabledContext) {
            // ...
        }
        if (context == TorchActiveContext) {
            // ...
        }
        if (context == TorchLevelContext) {
            // ...
        }
    });
}



@end
