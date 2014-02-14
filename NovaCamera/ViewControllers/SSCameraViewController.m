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
#import "SSNovaFlashService.h"
#import "SSFlashSettingsViewController.h"
#import "SSSettingsService.h"
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <CocoaLumberjack/DDLog.h>

static void * SessionRunningAndDeviceAuthorizedContext = &SessionRunningAndDeviceAuthorizedContext;

static const NSTimeInterval flashSettingsAnimationDuration = 0.25;

@interface SSCameraViewController () {
    NSURL *_showPhotoURL;
    BOOL _editPhoto;
    BOOL _sharePhoto;
}
@property (nonatomic, strong) SSCaptureSessionManager *captureSessionManager;
- (void)runStillImageCaptureAnimation;
- (void)showFlashSettingsAnimated:(BOOL)animated;
- (void)hideFlashSettingsAnimated:(BOOL)animated;
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
    
    // Add flash service
    self.flashService = [[SSNovaFlashService alloc] init];
    
    // Add gesture recognizer
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(focusAndExposeTap:)];
    tapGesture.numberOfTapsRequired = 1;
    [self.previewView addGestureRecognizer:tapGesture];
    
    // Set up flash settings
    self.flashSettingsViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"flashSettings"];
    self.flashSettingsViewController.delegate = self;
    
    // Remove "Back" text from navigation item
    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"" style:UIBarButtonItemStylePlain target:nil action:nil];
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

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"showPhoto"]) {
        SSLibraryViewController *vc = (SSLibraryViewController *)segue.destinationViewController;
        if (_showPhotoURL) {
            vc.prepareToDisplayAssetURL = _showPhotoURL;
            vc.automaticallyEditPhoto = _editPhoto;
            vc.automaticallySharePhoto = _sharePhoto;
            _editPhoto = NO;
            _sharePhoto = NO;
            _showPhotoURL = nil;
        } else {
            DDLogVerbose(@"showPhoto with no photo URL");
        }
    } else {
        DDLogVerbose(@"Got unknown segue %@", segue.identifier);
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
                
                if ([self.settingsService boolForKey:kSettingsServiceEditAfterCaptureKey]) {
                    _editPhoto = YES;
                } else {
                    _editPhoto = NO;
                }
                
                if ([self.settingsService boolForKey:kSettingsServiceShareAfterCaptureKey]) {
                    _sharePhoto = YES;
                } else {
                    _sharePhoto = NO;
                }
                
                _showPhotoURL = assetURL;
                
                [bSelf performSegueWithIdentifier:@"showPhoto" sender:self];
            }];
        }
    } shutterHandler:^{
        [self runStillImageCaptureAnimation];
    }];
}

- (IBAction)showGeneralSettings:(id)sender {
    [self performSegueWithIdentifier:@"showSettings" sender:sender];
}

- (IBAction)showFlashSettings:(id)sender {
    [self showFlashSettingsAnimated:YES];
}

- (IBAction)showLibrary:(id)sender {
    _showPhotoURL = nil;
    _editPhoto = NO;
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

#pragma mark - Properties

- (SSSettingsService *)settingsService {
    if (_settingsService == nil) {
        _settingsService = [SSSettingsService sharedService];
    }
    return _settingsService;
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

- (void)showFlashSettingsAnimated:(BOOL)animated {
    [self.flashSettingsViewController viewWillAppear:animated];
    [self.view addSubview:self.flashSettingsViewController.view];
    
    // Load settings from flash service
    self.flashSettingsViewController.flashSettings = self.flashService.flashSettings;
    
    if (animated) {
        CGRect flashSettingsFrame = self.view.frame;
        flashSettingsFrame.origin.y += flashSettingsFrame.size.height;
        self.flashSettingsViewController.view.frame = flashSettingsFrame;
        
        [UIView animateWithDuration:flashSettingsAnimationDuration delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
            self.flashSettingsViewController.view.frame = self.view.frame;
        } completion:^(BOOL finished) {
            [self.flashSettingsViewController viewDidAppear:animated];
        }];
    } else {
        self.flashSettingsViewController.view.frame = self.view.frame;
        [self.flashSettingsViewController viewDidAppear:animated];
    }
}

- (void)hideFlashSettingsAnimated:(BOOL)animated {
    [self.flashSettingsViewController viewWillDisappear:animated];
    
    if (animated) {
        [UIView animateWithDuration:flashSettingsAnimationDuration delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            CGRect flashSettingsFrame = self.view.frame;
            flashSettingsFrame.origin.y += flashSettingsFrame.size.height;
            self.flashSettingsViewController.view.frame = flashSettingsFrame;
        } completion:^(BOOL finished) {
            [self.flashSettingsViewController.view removeFromSuperview];
            [self.flashSettingsViewController viewDidDisappear:animated];
        }];
    } else {
        [self.flashSettingsViewController.view removeFromSuperview];
        [self.flashSettingsViewController viewDidDisappear:animated];
    }
}

#pragma mark - SSFlashSettingsViewControllerDelegate

- (void)flashSettingsViewController:(SSFlashSettingsViewController *)flashSettingsViewController didConfirmSettings:(SSFlashSettings)flashSettings {
    // Update settings in flash service
    self.flashService.flashSettings = flashSettings;
    [self hideFlashSettingsAnimated:YES];
}

- (void)flashSettingsViewController:(SSFlashSettingsViewController *)flashSettingsViewController testFlashWithSettings:(SSFlashSettings)flashSettings {
    [self hideFlashSettingsAnimated:YES];
}

@end
