//
//  SSCameraViewController.m
//  Nova Camera
//
//  Created by Mike Matz on 12/20/13.
//  Copyright (c) 2013 Sneaky Squid. All rights reserved.
//
//  Largely based on Apple's AVCam sample code

#import "SSCameraViewController.h"
#import "SSCameraPreviewView.h"
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>

static void * CapturingStillImageContext = &CapturingStillImageContext;
static void * SessionRunningAndDeviceAuthorizedContext = &SessionRunningAndDeviceAuthorizedContext;

@interface SSCameraViewController ()

@property (nonatomic, strong) dispatch_queue_t sessionQueue;
@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic, readonly) AVCaptureDevice *device;
@property (nonatomic, strong) AVCaptureDeviceInput *deviceInput;
@property (nonatomic, strong) AVCaptureStillImageOutput *stillImageOutput;
@property (nonatomic, assign, getter=isDeviceAuthorized) BOOL deviceAuthorized;
@property (nonatomic, readonly, getter=isSessionRunningAndDeviceAuthorized) BOOL sessionRunningAndDeviceAuthorized;

- (BOOL)setDevice:(AVCaptureDevice *)device withError:(NSError **)error;
- (void)checkDeviceAuthorizationStatus;
- (void)configureSession;
- (void)runStillImageCaptureAnimation;

@end

@implementation SSCameraViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Create capture session
    self.session = [[AVCaptureSession alloc] init];
    
    // Setup preview view
    self.previewView.session = self.session;
    
    // Check device authorization
    [self checkDeviceAuthorizationStatus];
    
    // Create queue for capture session setup
    self.sessionQueue = dispatch_queue_create("session queue", DISPATCH_QUEUE_SERIAL);
    
    [self configureSession];
}

- (void)viewWillAppear:(BOOL)animated {
    // Setup observers and start capture session
    dispatch_async(self.sessionQueue, ^{
        [self addObserver:self forKeyPath:@"sessionRunningAndDeviceAuthorized" options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) context:SessionRunningAndDeviceAuthorizedContext];
		[self addObserver:self forKeyPath:@"stillImageOutput.capturingStillImage" options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) context:CapturingStillImageContext];
        
        [self.session startRunning];
    });
}

- (void)viewDidDisappear:(BOOL)animated {
    // Remove observers and end session
    dispatch_async(self.sessionQueue, ^{
        [self.session stopRunning];
        
		[self removeObserver:self forKeyPath:@"sessionRunningAndDeviceAuthorized" context:SessionRunningAndDeviceAuthorizedContext];
		[self removeObserver:self forKeyPath:@"stillImageOutput.capturingStillImage" context:CapturingStillImageContext];
    });
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
	if (context == CapturingStillImageContext) {
		BOOL isCapturingStillImage = [change[NSKeyValueChangeNewKey] boolValue];
		
		if (isCapturingStillImage) {
			[self runStillImageCaptureAnimation];
		}
	}
    
	else if (context == SessionRunningAndDeviceAuthorizedContext) {
		BOOL isRunning = [change[NSKeyValueChangeNewKey] boolValue];
		
		dispatch_async(dispatch_get_main_queue(), ^{
			if (isRunning) {
                self.captureButton.enabled = YES;
			} else {
                self.captureButton.enabled = NO;
			}
		});
	}
}

#pragma mark - Public methods

- (IBAction)capture:(id)sender {
    NSLog(@"Capture!");
    dispatch_async(self.sessionQueue, ^{
        // Set up capture connection
        AVCaptureConnection *connection = [self.stillImageOutput connectionWithMediaType:AVMediaTypeVideo];
        [self.stillImageOutput captureStillImageAsynchronouslyFromConnection:connection completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
            // Save to asset library
            if (imageDataSampleBuffer) {
                NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
				UIImage *image = [[UIImage alloc] initWithData:imageData];
				[[[ALAssetsLibrary alloc] init] writeImageToSavedPhotosAlbum:[image CGImage] orientation:(ALAssetOrientation)[image imageOrientation] completionBlock:nil];
            } else if (error) {
                NSLog(@"Error capturing image: %@", error);
            }
        }];
    });
}

- (IBAction)showGeneralSettings:(id)sender {
}

- (IBAction)showFlashSettings:(id)sender {
}

- (IBAction)showLibrary:(id)sender {
}

- (IBAction)toggleCamera:(id)sender {
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

#pragma mark - Private methods

- (BOOL)setDevice:(AVCaptureDevice *)device withError:(NSError **)outError {
    NSError *error = nil;
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

- (BOOL)isSessionRunningAndDeviceAuthorized {
    return [self.session isRunning] && [self isDeviceAuthorized];
}

+ (NSSet *)keyPathsForValuesAffectingSessionRunningAndDeviceAuthorized {
    return [NSSet setWithObjects:@"session.running", @"deviceAuthorized", nil];
}

- (void)checkDeviceAuthorizationStatus {
	[AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
        if (granted) {
            self.deviceAuthorized = YES;
        } else {
            self.deviceAuthorized = NO;
            dispatch_async(dispatch_get_main_queue(), ^{
                [[[UIAlertView alloc] initWithTitle:@"Error" message:@"Device not authorized" delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil] show];
            });
        }
    }];
}

- (void)configureSession {
    dispatch_async(self.sessionQueue, ^{
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
    });
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

- (void)runStillImageCaptureAnimation {
	dispatch_async(dispatch_get_main_queue(), ^{
        self.previewView.layer.opacity = 0.0;
		[UIView animateWithDuration:.25 animations:^{
            self.previewView.layer.opacity = 1.0;
		}];
	});
}

@end
