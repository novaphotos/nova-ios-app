//
//  SSCameraViewController.m
//  NovaCamera
//
//  Created by Mike Matz on 12/20/13.
//  Copyright (c) 2013 Sneaky Squid. All rights reserved.
//

#import "SSCameraViewController.h"
#import "SSCameraPreviewView.h"
#import "SSCaptureSessionManager.h"
#import "SSLibraryViewController.h"
#import "SSFlashSettingsViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <CocoaLumberjack/DDLog.h>

static void * SessionRunningAndDeviceAuthorizedContext = &SessionRunningAndDeviceAuthorizedContext;

@interface SSCameraViewController () {
    NSURL *_showPhotoURL;
    NSMutableArray *_flashSettingsConstraints;
}
@property (nonatomic, strong) SSCaptureSessionManager *captureSessionManager;
- (void)runStillImageCaptureAnimation;
- (void)showFlashSettings;
- (void)hideFlashSettings;
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
    self.captureSessionManager.shouldAutoFocusAndExposeOnDeviceChange = YES;
    self.captureSessionManager.shouldAutoFocusAndAutoExposeOnDeviceAreaChange = YES;
    
    // Check authorization
    [self.captureSessionManager checkDeviceAuthorizationWithCompletion:^(BOOL granted) {
        if (!granted) {
            // Complain to the user that we haven't been authorized
            [[[UIAlertView alloc] initWithTitle:@"Error" message:@"Device not authorized" delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil] show];
        }
    }];
    
    // Setup preview layer
    self.previewView.session = self.captureSessionManager.session;
    
    // Add gesture recognizer
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(focusAndExposeTap:)];
    tapGesture.numberOfTapsRequired = 1;
    [self.previewView addGestureRecognizer:tapGesture];
    
    // Set up flash settings
    self.flashSettingsViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"flashSettings"];
}

- (void)viewWillAppear:(BOOL)animated {
    [self.captureSessionManager startSession];
    
    // Add observers
    [self.captureSessionManager addObserver:self forKeyPath:@"sessionRunningAndDeviceAuthorized" options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) context:SessionRunningAndDeviceAuthorizedContext];
}

- (void)viewDidDisappear:(BOOL)animated {
    [self.captureSessionManager stopSession];
    
    // Remove observers
    [self.captureSessionManager removeObserver:self forKeyPath:@"sessionRunningAndDeviceAuthorized" context:SessionRunningAndDeviceAuthorizedContext];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    AVCaptureVideoPreviewLayer *previewLayer = (AVCaptureVideoPreviewLayer *)self.previewView.layer;
    AVCaptureConnection *connection = previewLayer.connection;
    connection.videoOrientation = (AVCaptureVideoOrientation)toInterfaceOrientation;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"showPhoto"]) {
        SSLibraryViewController *vc = (SSLibraryViewController *)segue.destinationViewController;
        [vc showAssetWithURL:_showPhotoURL];
        _showPhotoURL = nil;
    }
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
    DDLogVerbose(@"Capture!");
    [self.captureSessionManager captureStillImageWithCompletionHandler:^(NSData *imageData, UIImage *image, NSError *error) {
        if (error) {
            DDLogError(@"Error capturing: %@", error);
        } else {
            DDLogVerbose(@"Saving to asset library");
            __block typeof(self) bSelf = self;
            [[[ALAssetsLibrary alloc] init] writeImageToSavedPhotosAlbum:[image CGImage] orientation:(ALAssetOrientation)[image imageOrientation] completionBlock:^(NSURL *assetURL, NSError *error) {
                [bSelf performSegueWithIdentifier:@"showPhoto" sender:self];
            }];
        }
    } shutterHandler:^{
        [self runStillImageCaptureAnimation];
    }];
}

- (IBAction)showGeneralSettings:(id)sender {
}

- (IBAction)showFlashSettings:(id)sender {
    [self showFlashSettings];
}

- (IBAction)showLibrary:(id)sender {
    _showPhotoURL = nil;
    [self performSegueWithIdentifier:@"showPhoto" sender:nil];
}

- (IBAction)toggleCamera:(id)sender {
    [self.captureSessionManager toggleCamera];
}

- (IBAction)focusAndExposeTap:(id)sender {
    DDLogVerbose(@"focusAndExposeTap");
    if ([sender isKindOfClass:[UIGestureRecognizer class]]) {
        UIGestureRecognizer *gestureRecognizer = (UIGestureRecognizer *)sender;
        AVCaptureVideoPreviewLayer *previewLayer = (AVCaptureVideoPreviewLayer *)self.previewView.layer;
        CGPoint viewPoint = [gestureRecognizer locationInView:gestureRecognizer.view];
        CGPoint devicePoint = [previewLayer captureDevicePointOfInterestForPoint:viewPoint];
        [self.captureSessionManager focusWithMode:AVCaptureFocusModeAutoFocus exposeWithMode:AVCaptureExposureModeContinuousAutoExposure atDevicePoint:devicePoint];
    }
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

- (void)showFlashSettings {
    [self.flashSettingsViewController viewWillAppear:NO];
    [self.view addSubview:self.flashSettingsViewController.view];
    
    // Constraints
    _flashSettingsConstraints = [NSMutableArray array];
    NSDictionary *views = @{
                            @"flashSettings": self.flashSettingsViewController.view,
                            @"view": self.view,
                            };
    [_flashSettingsConstraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[flashSettings]|" options:0 metrics:Nil views:views]];
    [_flashSettingsConstraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[flashSettings]|" options:0 metrics:nil views:views]];
    [self.view addConstraints:_flashSettingsConstraints];
    
    [self.flashSettingsViewController viewDidAppear:NO];
    
    double delayInSeconds = 2.0;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        DDLogVerbose(@"%@", [self.view recursiveDescription]);
    });
}

- (void)hideFlashSettings {
    [self.flashSettingsViewController viewWillDisappear:NO];
    [self.view removeConstraints:_flashSettingsConstraints];
    [self.flashSettingsViewController.view removeFromSuperview];
    [self.flashSettingsViewController viewDidDisappear:NO];
    _flashSettingsConstraints = nil;
}

@end
