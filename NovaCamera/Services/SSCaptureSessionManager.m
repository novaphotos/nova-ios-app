//
//  SSCaptureSessionManager.m
//  NovaCamera
//
//  Created by Mike Matz on 1/2/14.
//  Copyright (c) 2014 Sneaky Squid. All rights reserved.
//
//  Largely based on Apple's AVCam sample code

#import "SSCaptureSessionManager.h"
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>


static void * CapturingStillImageContext = &CapturingStillImageContext;

@interface SSCaptureSessionManager () {
    BOOL _preparedSession, _sessionRunning;
}

@property (nonatomic, strong) dispatch_queue_t sessionQueue;
@property (nonatomic, readonly) AVCaptureDevice *device;
@property (nonatomic, strong) AVCaptureDeviceInput *deviceInput;
@property (nonatomic, strong) AVCaptureStillImageOutput *stillImageOutput;
@property (nonatomic, strong) id runtimeErrorObserver;
@property (nonatomic, copy) void (^shutterHandler)();

- (BOOL)setDevice:(AVCaptureDevice *)device withError:(NSError **)error;
- (void)configureSession;

@end

@implementation SSCaptureSessionManager

@synthesize session=_session;
@synthesize previewLayer=_previewLayer;
@synthesize videoGravity=_videoGravity;

@synthesize sessionQueue=_sessionQueue;

#pragma mark - NSObject

- (id)init {
    self = [super init];
    if (self) {
        // Defaults
        self.videoGravity = AVLayerVideoGravityResizeAspectFill;
    }
    return self;
}

#pragma mark - Public methods

- (void)startSession {
    dispatch_async(self.sessionQueue, ^{
        // Configure session
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
            NSLog(@"Error setting up device; giving up. %@", error);
            return;
        }
        
        // Configure still image output
        AVCaptureStillImageOutput *stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
        if ([self.session canAddOutput:stillImageOutput]) {
            [self.session addOutput:stillImageOutput];
            self.stillImageOutput = stillImageOutput;
        } else {
            NSLog(@"Unable to add still image output");
            self.stillImageOutput = nil;
            return;
        }
        
        // Add observer for image capture (shutter indication)
		[self addObserver:self forKeyPath:@"stillImageOutput.capturingStillImage" options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) context:CapturingStillImageContext];
        
        // Add error notification observer
        __block typeof(self) bSelf = self;
		self.runtimeErrorObserver = [[NSNotificationCenter defaultCenter] addObserverForName:AVCaptureSessionRuntimeErrorNotification object:self.session queue:nil usingBlock:^(NSNotification *note) {
			dispatch_async(bSelf.sessionQueue, ^{
				// Manually restarting the session since it must have been stopped due to an error.
                NSLog(@"Received AVCaptureSessionRuntimeErrorNotification; restarting session");
                [bSelf.session startRunning];
			});
        }];
        
        // Start the capture session
        [self.session startRunning];
    });
}

- (void)stopSession {
    dispatch_async(self.sessionQueue, ^{
        [self.session stopRunning];
        
		[self removeObserver:self forKeyPath:@"stillImageOutput.capturingStillImage" context:CapturingStillImageContext];
        
        [[NSNotificationCenter defaultCenter] removeObserver:self.runtimeErrorObserver];
    });
}

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

- (void)resetFocus {
    if ([self.device isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus]) {
        // Focus at center of screen
        NSError *error;
        [self.device lockForConfiguration:&error];
        CGPoint focusPoint = CGPointMake(0.5, 0.5);
        self.device.focusMode = AVCaptureFocusModeContinuousAutoFocus;
        self.device.focusPointOfInterest = focusPoint;
        [self.device unlockForConfiguration];
    }
}

- (void)resetExposure {
    if ([self.device isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure]) {
        NSError *error;
        [self.device lockForConfiguration:&error];
        CGPoint exposurePoint = CGPointMake(0.5, 0.5);
        self.device.exposureMode = AVCaptureExposureModeContinuousAutoExposure;
        self.device.exposurePointOfInterest = exposurePoint;
        [self.device unlockForConfiguration];
    }
}

- (void)resetFlash {
    NSError *error;
    [self.device lockForConfiguration:&error];
    [self.device setFlashMode:AVCaptureFlashModeOff];
    [self.device unlockForConfiguration];
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
                NSLog(@"Error changing device: %@", error);
            }
        }
    });
}

- (void)captureStillImageWithCompletionHandler:(void (^)(NSData *imageData, UIImage *image, NSError *error))completion shutterHandler:(void (^)())shutter {
    self.shutterHandler = shutter;
    dispatch_async(self.sessionQueue, ^{
        // Set up capture connection
        AVCaptureConnection *connection = [self.stillImageOutput connectionWithMediaType:AVMediaTypeVideo];
        [self.stillImageOutput captureStillImageAsynchronouslyFromConnection:connection completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
            // Save to asset library
            if (imageDataSampleBuffer) {
                if (completion) {
                    NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
                    UIImage *image = [[UIImage alloc] initWithData:imageData];
                    completion(imageData, image, error);
                }
            } else if (error) {
                NSLog(@"Error capturing image: %@", error);
                if (completion) {
                    completion(nil, nil, error);
                }
            }
        }];
    });
}

#pragma mark - Properties

- (AVCaptureSession *)session {
    if (!_session) {
        [self willChangeValueForKey:@"session"];
        [self willChangeValueForKey:@"previewLayer"];
        _session = [[AVCaptureSession alloc] init];
        _previewLayer = nil;
        [self didChangeValueForKey:@"session"];
        [self didChangeValueForKey:@"previewLayer"];
    }
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

- (BOOL)isSessionRunningAndDeviceAuthorized {
    return [self.session isRunning] && [self isDeviceAuthorized];
}

- (BOOL)canToggleCamera {
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    return (devices.count > 1);
}

#pragma mark - Private methods & properties

- (BOOL)setDevice:(AVCaptureDevice *)device withError:(NSError **)outError {
    NSError *error = nil;
    NSLog(@"setDevice:%@", device);
    AVCaptureDeviceInput *newInput = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
    if (error) {
        NSLog(@"Error creating device input: %@ for device: %@", error, device);
        *outError = error;
        return NO;
    }
    [self willChangeValueForKey:@"device"];
    
    [self.session beginConfiguration];
    
    // Remove current device input before adding new
    if (self.deviceInput) {
        [self.session removeInput:self.deviceInput];
    }
    
    if (![self.session canAddInput:newInput]) {
        NSLog(@"Unable to add new input %@", newInput);
        if (self.deviceInput) {
            // Attempt to restore state by adding previous input
            [self.session addInput:self.deviceInput];
        }
        return NO;
    }
    
    [self.session addInput:newInput];
    self.deviceInput = newInput;
    _device = device;
    
    // Reset exposure, focus and flash
    [_device lockForConfiguration:&error];
    
    // Expose for center of screen
    CGPoint centerPoint = CGPointMake(0.5, 0.5);
    if ([_device isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure]) {
        _device.exposureMode = AVCaptureExposureModeContinuousAutoExposure;
        _device.exposurePointOfInterest = centerPoint;
    }
    
    // Set continuous autofocus and focus at center of screen
    if ([_device isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus]) {
        _device.focusMode = AVCaptureFocusModeContinuousAutoFocus;
        _device.focusPointOfInterest = centerPoint;
    }
    
    // Disable flash
    if ([_device isFlashModeSupported:AVCaptureFlashModeOff]) {
        [_device setFlashMode:AVCaptureFlashModeOff];
    }
    
    [_device unlockForConfiguration];
    [self.session commitConfiguration];
    [self didChangeValueForKey:@"device"];
    
    return YES;
}

- (void)configureSession {
    dispatch_async(self.sessionQueue, ^{
    });
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
		
		if (isCapturingStillImage) {
            if (self.shutterHandler) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.shutterHandler();
                });
            }
		}
	}
}



@end
