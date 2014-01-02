//
//  SSCameraViewController.m
//  Nova Camera
//
//  Created by Mike Matz on 12/20/13.
//  Copyright (c) 2013 Sneaky Squid. All rights reserved.
//

#import "SSCameraViewController.h"
#import "SSCameraPreviewView.h"
#import "SSCaptureSessionManager.h"
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>

static void * SessionRunningAndDeviceAuthorizedContext = &SessionRunningAndDeviceAuthorizedContext;

@interface SSCameraViewController ()
@property (nonatomic, strong) SSCaptureSessionManager *captureSessionManager;
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
    
    // Setup capture session
    self.captureSessionManager = [[SSCaptureSessionManager alloc] init];
    
    // Check authorization
    [self.captureSessionManager checkDeviceAuthorizationWithCompletion:^(BOOL granted) {
        if (!granted) {
            // Complain to the user that we haven't been authorized
            [[[UIAlertView alloc] initWithTitle:@"Error" message:@"Device not authorized" delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil] show];
        }
    }];
    
    // Setup preview layer
    self.previewView.session = self.captureSessionManager.session;
}

- (void)viewWillAppear:(BOOL)animated {
    [self.captureSessionManager startSession];
    
    // Add observers
    [self.captureSessionManager addObserver:self forKeyPath:@"sessionRunningAndDeviceAuthorized" options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) context:SessionRunningAndDeviceAuthorizedContext];
}

- (void)viewDidDisappear:(BOOL)animated {
    [self.captureSessionManager stopSession];
    
    // Remove observers
    [self removeObserver:self forKeyPath:@"sessionRunningAndDeviceAuthorized" context:SessionRunningAndDeviceAuthorizedContext];
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
    if (context == SessionRunningAndDeviceAuthorizedContext) {
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
    [self.captureSessionManager captureStillImageWithCompletionHandler:^(NSData *imageData, UIImage *image, NSError *error) {
        if (error) {
            NSLog(@"Error capturing!");
        } else {
            NSLog(@"Saving to asset library");
            [[[ALAssetsLibrary alloc] init] writeImageToSavedPhotosAlbum:[image CGImage] orientation:(ALAssetOrientation)[image imageOrientation] completionBlock:nil];
        }
    } shutterHandler:^{
        [self runStillImageCaptureAnimation];
    }];
}

- (IBAction)showGeneralSettings:(id)sender {
}

- (IBAction)showFlashSettings:(id)sender {
}

- (IBAction)showLibrary:(id)sender {
}

- (IBAction)toggleCamera:(id)sender {
    [self.captureSessionManager toggleCamera];
}

#pragma mark - Private methods

- (void)runStillImageCaptureAnimation {
	dispatch_async(dispatch_get_main_queue(), ^{
        self.previewView.layer.opacity = 0.0;
		[UIView animateWithDuration:.25 animations:^{
            self.previewView.layer.opacity = 1.0;
		}];
	});
}

@end
