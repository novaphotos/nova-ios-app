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
@synthesize focusMode=_focusMode;
@synthesize exposureMode=_exposureMode;
@synthesize flashMode=_flashMode;
@synthesize videoScaleAndCropFactor=_videoScaleAndCropFactor;

@synthesize sessionQueue=_sessionQueue;
@synthesize device=_device;

#pragma mark - NSObject

- (id)init {
    self = [super init];
    if (self) {
        // Defaults
        self.focusMode = AVCaptureFocusModeContinuousAutoFocus;
        self.exposureMode = AVCaptureExposureModeContinuousAutoExposure;
        self.flashMode = AVCaptureFlashModeOff;
        self.videoScaleAndCropFactor = 1.0;
        self.shouldAutoFocusAndAutoExposeOnDeviceAreaChange = YES;
        self.shouldAutoFocusAndExposeOnDeviceChange = YES;
        self.videoGravity = AVLayerVideoGravityResizeAspectFill;
        
        // Create session
        _session = [[AVCaptureSession alloc] init];
    }
    return self;
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

- (void)autoFocusAndExposeAtCenterPoint {
    return [self autoFocusAndExposeAtDevicePoint:CGPointMake(0.5, 0.5)];
}

- (void)continuousAutoFocusAndExposeAtCenterPoint {
    return [self continuousAutoFocusAndExposeAtDevicePoint:CGPointMake(0.5, 0.5)];
}

- (void)autoFocusAndExposeAtDevicePoint:(CGPoint)point {
    [self focusWithMode:AVCaptureFocusModeAutoFocus exposeWithMode:AVCaptureExposureModeAutoExpose atDevicePoint:point];
}

- (void)continuousAutoFocusAndExposeAtDevicePoint:(CGPoint)point {
    [self focusWithMode:AVCaptureFocusModeContinuousAutoFocus exposeWithMode:AVCaptureExposureModeContinuousAutoExposure atDevicePoint:point];
}

- (void)focusWithMode:(AVCaptureFocusMode)focusMode exposeWithMode:(AVCaptureExposureMode)exposureMode atDevicePoint:(CGPoint)point {
    // DDLogVerbose(@"focusWithMode:%d exposeWithMode:%d atDevicePoint:%@", focusMode, exposureMode, NSStringFromCGPoint(point));
    dispatch_async(self.sessionQueue, ^{
        NSError *error = nil;
        if ([self.device lockForConfiguration:&error]) {
            if ([self.device isExposurePointOfInterestSupported] && [self.device isExposureModeSupported:exposureMode]) {
                [self.device setExposureMode:exposureMode];
                [self.device setExposurePointOfInterest:point];
            } else {
                if (![self.device isExposurePointOfInterestSupported]) {
                    DDLogWarn(@"Exposure point of interest not supported");
                } else {
                    DDLogWarn(@"Exposure mode not supported: %d", exposureMode);
                }
            }
            if ([self.device isFocusPointOfInterestSupported] && [self.device isFocusModeSupported:focusMode]) {
                [self.device setFocusMode:focusMode];
                [self.device setFocusPointOfInterest:point];
            } else {
                if (![self.device isFocusPointOfInterestSupported]) {
                    DDLogWarn(@"Focus point of interest not supported");
                } else {
                    DDLogWarn(@"Focus mode not supported: %d", focusMode);
                }
            }
            [self.device unlockForConfiguration];
        } else {
            DDLogError(@"Error locking device %@ for configuration: %@", self.device, error);
        }
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

- (void)setFocusMode:(AVCaptureFocusMode)focusMode {
    dispatch_async(self.sessionQueue, ^{
        // Only reconfigure device if mode does not match
        if (self.device && self.device.focusMode != focusMode) {
            if ([self.device isFocusModeSupported:focusMode]) {
                NSError *error = nil;
                if ([self.device lockForConfiguration:&error]) {
                    [self willChangeValueForKey:@"focusMode"];
                    self.device.focusMode = focusMode;
                    _focusMode = focusMode;
                    [self didChangeValueForKey:@"focusMode"];
                } else {
                    DDLogError(@"Error locking device %@ for configuration (attempting to change focus mode): %@", self.device, error);
                }
            }
        } else {
            // Device focus mode already matches (or device isn't set)
            // Ensure that our ivar also matches.
            if (_focusMode != focusMode) {
                [self willChangeValueForKey:@"focusMode"];
                _focusMode = focusMode;
                [self didChangeValueForKey:@"focusMode"];
            }
        }
    });
}

- (void)setExposureMode:(AVCaptureExposureMode)exposureMode {
    dispatch_async(self.sessionQueue, ^{
        // Only reconfigure device if mode does not match
        if (self.device && self.device.exposureMode != exposureMode) {
            if ([self.device isExposureModeSupported:exposureMode]) {
                NSError *error = nil;
                if ([self.device lockForConfiguration:&error]) {
                    [self willChangeValueForKey:@"exposureMode"];
                    self.device.exposureMode = exposureMode;
                    _exposureMode = exposureMode;
                    [self didChangeValueForKey:@"exposureMode"];
                } else {
                    DDLogError(@"Error locking device %@ for configuration (attempting to change exposure mode): %@", self.device, error);
                }
            }
        } else {
            // Device exposure mode already matches (or device isn't set)
            // Ensure that our ivar also matches.
            if (_exposureMode != exposureMode) {
                [self willChangeValueForKey:@"exposureMode"];
                _exposureMode = exposureMode;
                [self didChangeValueForKey:@"exposureMode"];
            }
        }
    });
}

- (void)setFlashMode:(AVCaptureFlashMode)flashMode {
    dispatch_async(self.sessionQueue, ^{
        // Only reconfigure device if mode does not match
        if (self.device && self.device.flashMode != flashMode) {
            if ([self.device isFlashModeSupported:flashMode]) {
                NSError *error = nil;
                if ([self.device lockForConfiguration:&error]) {
                    [self willChangeValueForKey:@"flashMode"];
                    self.device.flashMode = flashMode;
                    _flashMode = flashMode;
                    [self.device unlockForConfiguration];
                    [self didChangeValueForKey:@"flashMode"];
                } else {
                    DDLogError(@"Error locking device %@ for configuration (attempting to change flash mode): %@", self.device, error);
                }
            }
        } else {
            // Device flash mode already matches (or device isn't set)
            // Ensure that our ivar also matches.
            if (_flashMode != flashMode) {
                [self willChangeValueForKey:@"flashMode"];
                _flashMode = flashMode;
                [self didChangeValueForKey:@"flashMode"];
            }
        }
    });
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
    
    if (self.shouldAutoFocusAndExposeOnDeviceChange) {
        // Because this is a different device, set continuous autofocus and autoexposure on center point
        [self continuousAutoFocusAndExposeAtCenterPoint];
    } else {
        // Don't reset autofocus and exposure; instead ensure our ivars match device settings
        AVCaptureExposureMode exposureMode = self.device.exposureMode;
        if (exposureMode != _exposureMode) {
            [self willChangeValueForKey:@"exposureMode"];
            _exposureMode = exposureMode;
            [self didChangeValueForKey:@"focusMode"];
        }
        AVCaptureFocusMode focusMode = self.device.focusMode;
        if (focusMode != _focusMode) {
            [self willChangeValueForKey:@"focusMode"];
            _focusMode = focusMode;
            [self didChangeValueForKey:@"focusMode"];
        }
    }
    
    // Ensure subject area change notifications are enabled
    if (!_device.subjectAreaChangeMonitoringEnabled) {
        if ([_device lockForConfiguration:&error]) {
            _device.subjectAreaChangeMonitoringEnabled = YES;
            [_device unlockForConfiguration];
        } else {
            DDLogError(@"Error locking device %@ for configuration (attempting to enable subject area change monitoring): %@", _device, error);
        }
    }


    // Attempt to persist current flash mode
    [self setFlashMode:[self flashMode]];
    
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
        [self continuousAutoFocusAndExposeAtCenterPoint];
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
        // ...
    }
    if (context == AdjustingExposureContext) {
        // ...
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
}



@end
