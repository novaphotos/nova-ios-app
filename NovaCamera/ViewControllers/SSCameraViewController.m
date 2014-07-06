//
//  SSCameraViewController.m
//  NovaCamera
//
//  Created by Mike Matz on 12/20/13.
//  Copyright (c) 2013 Sneaky Squid. All rights reserved.
//

#import "SSCameraViewController.h"
#import "SSCameraPreviewView.h"
#import "SSCameraLockView.h"
#import "SSCaptureSessionManager.h"
#import "SSLibraryViewController.h"
#import "SSSettingsService.h"
#import "SSStatsService.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import <MediaPlayer/MediaPlayer.h>

static void * SessionRunningAndDeviceAuthorizedContext = &SessionRunningAndDeviceAuthorizedContext;
static void * NovaFlashServiceStatus = &NovaFlashServiceStatus;
static void * CaptureSessionFocusExposureChange = &CaptureSessionFocusExposureChange;

static const NSTimeInterval kFlashSettingsAnimationDuration = 0.25;
static const NSTimeInterval kOrientationChangeAnimationDuration = 0.25;
static const CFTimeInterval kTransformAnimationDuration = 0.025;
static const CFTimeInterval kMinimumTimeBeforeVolumeButtonCapture = 0.1;
static const CGFloat kZoomMaxScale = 2.5;
static const CFTimeInterval kZoomSliderHideDelay = 3.0;
static const NSTimeInterval kZoomSliderAnimationDuration = 0.25;

@interface SSCameraViewController () {
    NSURL *_showPhotoURL;
    BOOL _editPhoto;
    BOOL _sharePhoto;
    CFTimeInterval _audioSessionTimestamp; // Ugly workaround for premature volume notification
    
    // Track zoom scale
    CGFloat _beginGestureScale;

    // Track rotation angle
    CGFloat _rotationAngle;

    // Zoom slider state
    BOOL _zoomSliderVisible;
    CFTimeInterval _zoomActiveTimestamp;
    
    // Temporary storage for zoom data
    CGFloat _previousScaleAndCropFactor;
    CGFloat _previousZoomSliderValue;

    // Indicator of camera lock
    SSCameraLockView *_focusLockIndicator;
    SSCameraLockView *_exposureLockIndicator;

    BOOL _capturingPhoto;
}
@property (nonatomic, strong) SSCaptureSessionManager *captureSessionManager;
@property (nonatomic, strong) AVAudioPlayer *captureButtonAudioPlayer;
@property (nonatomic, strong) MPVolumeView *volumeView;
- (void)updateZoomTransform;
- (void)runStillImageCaptureAnimation;
- (void)showFlashSettingsAnimated:(BOOL)animated;
- (void)hideFlashSettingsAnimated:(BOOL)animated;
- (void)updateFlashStatusIcon;
- (void)setupCaptureButtonAudioPlayer;
- (void)volumeChanged:(NSNotification *)notification;
- (void)setupZoomSlider;
- (void)zoomActive;
- (void)zoomCheckActivityAndClose;
- (void)saveAndResetZoom;
- (void)restoreOrResetZoom;
@end

@implementation SSCameraViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void)commonInit {
    _rotationAngle = [self rotationAngle];
    _capturingPhoto = NO;

    // Listen to device orientation notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didRotate:) name:UIDeviceOrientationDidChangeNotification object:nil];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Setup capture session
    self.captureSessionManager = [SSCaptureSessionManager sharedService];

    // Check authorization
    [self.captureSessionManager checkDeviceAuthorizationWithCompletion:^(BOOL granted) {
        if (!granted) {
            // Complain to the user that we haven't been authorized
            [[[UIAlertView alloc] initWithTitle:@"Error" message:@"Device not authorized" delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil] show];
        }
    }];
    
    // Setup preview layer
    self.previewView.session = self.captureSessionManager.session;
    //self.previewView.layer.anchorPoint = CGPointMake(self.previewView.bounds.size.width / 2, self.previewView.bounds.size.height / 2);
    self.previewView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    // Add flash service
    self.flashService = [SSNovaFlashService sharedService];
    
    // Add stats service
    self.statsService = [SSStatsService sharedService];
    
    // Add tap gesture recognizer for focus/expose
    UITapGestureRecognizer *singleTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleSingleTapFrom:)];
    singleTapGesture.numberOfTapsRequired = 1;
    [self.previewView addGestureRecognizer:singleTapGesture];
    
    UITapGestureRecognizer *doubleTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleTapFrom:)];
    doubleTapGesture.numberOfTapsRequired = 2;
    [self.previewView addGestureRecognizer:doubleTapGesture];

    [singleTapGesture requireGestureRecognizerToFail:doubleTapGesture];

    // Add pinch gesture recognizer for zoom
    UIPinchGestureRecognizer *pinchGesture = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinchFrom:)];
    pinchGesture.delegate = self;
    
    // Temporarily disabled until zoom bugs are resolved. -Joe 2014/05/18
    // TODO: Fix this
    // [self.previewView addGestureRecognizer:pinchGesture];
    
    // Set effective zoom scale to 1.0 (default value)
    _scaleAndCropFactor = 1.0;
    
    // Set up zoom slider
    [self setupZoomSlider];
    
    // Set up flash settings
    self.flashSettingsViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"flashSettings"];
    self.flashSettingsViewController.delegate = self;
    
    // Remove "Back" text from navigation item
    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"" style:UIBarButtonItemStylePlain target:nil action:nil];

    _focusLockIndicator = [SSCameraFocusLockView view];
    _exposureLockIndicator = [SSCameraExposureLockView view];

    [_focusLockIndicator addTarget:self action:@selector(focusDragged:withEvent:) forControlEvents:UIControlEventTouchDragInside];
    [_exposureLockIndicator addTarget:self action:@selector(exposureDragged:withEvent:) forControlEvents:UIControlEventTouchDragInside];

    [self.previewView addSubview:_focusLockIndicator];
    [self.previewView addSubview:_exposureLockIndicator];

    [self didRotate:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    // Hide nav bar
    [self.navigationController setNavigationBarHidden:YES animated:animated];

    [self.captureSessionManager startSession];
    
    // Add observers
    
    [self.captureSessionManager addObserver:self forKeyPath:@"sessionRunningAndDeviceAuthorized" options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) context:SessionRunningAndDeviceAuthorizedContext];

    [self.captureSessionManager addObserver:self forKeyPath:@"focusLockAvailable" options:0 context:CaptureSessionFocusExposureChange];
    [self.captureSessionManager addObserver:self forKeyPath:@"focusLockActive" options:0 context:CaptureSessionFocusExposureChange];
    [self.captureSessionManager addObserver:self forKeyPath:@"focusLockDevicePoint" options:0 context:CaptureSessionFocusExposureChange];
    [self.captureSessionManager addObserver:self forKeyPath:@"focusLockAdjusting" options:0 context:CaptureSessionFocusExposureChange];
    [self.captureSessionManager addObserver:self forKeyPath:@"exposureLockAvailable" options:0 context:CaptureSessionFocusExposureChange];
    [self.captureSessionManager addObserver:self forKeyPath:@"exposureLockActive" options:0 context:CaptureSessionFocusExposureChange];
    [self.captureSessionManager addObserver:self forKeyPath:@"exposureLockDevicePoint" options:0 context:CaptureSessionFocusExposureChange];
    [self.captureSessionManager addObserver:self forKeyPath:@"exposureLockAdjusting" options:0 context:CaptureSessionFocusExposureChange];
    
    [self.flashService addObserver:self forKeyPath:@"status" options:0 context:NovaFlashServiceStatus];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(volumeChanged:) name:@"AVSystemController_SystemVolumeDidChangeNotification" object:nil];
    
    [self updateFlashStatusIcon];
    
    // Ensure flash is enabled, if appropriate
    [self.flashService enableFlashIfNeeded];
    
    // Setup capture button
    [self setupCaptureButtonAudioPlayer];
   
    // Reset zoom
    [self restoreOrResetZoom];
    
    // Manually ensure preview view is full-screen
    self.previewView.frame = self.view.bounds;
    
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
    [self.captureSessionManager stopSession];
    
    // Remove observers
    [self.captureSessionManager removeObserver:self forKeyPath:@"sessionRunningAndDeviceAuthorized" context:SessionRunningAndDeviceAuthorizedContext];

    [self.captureSessionManager removeObserver:self forKeyPath:@"focusLockAvailable" context:CaptureSessionFocusExposureChange];
    [self.captureSessionManager removeObserver:self forKeyPath:@"focusLockActive" context:CaptureSessionFocusExposureChange];
    [self.captureSessionManager removeObserver:self forKeyPath:@"focusLockDevicePoint" context:CaptureSessionFocusExposureChange];
    [self.captureSessionManager removeObserver:self forKeyPath:@"focusLockAdjusting" context:CaptureSessionFocusExposureChange];
    [self.captureSessionManager removeObserver:self forKeyPath:@"exposureLockAvailable" context:CaptureSessionFocusExposureChange];
    [self.captureSessionManager removeObserver:self forKeyPath:@"exposureLockActive" context:CaptureSessionFocusExposureChange];
    [self.captureSessionManager removeObserver:self forKeyPath:@"exposureLockDevicePoint" context:CaptureSessionFocusExposureChange];
    [self.captureSessionManager removeObserver:self forKeyPath:@"exposureLockAdjusting" context:CaptureSessionFocusExposureChange];

    [self.flashService removeObserver:self forKeyPath:@"status"];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"AVSystemController_SystemVolumeDidChangeNotification" object:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    // Store zoom information and reset before disappearing
    [self saveAndResetZoom];

    // Show nav bar
    [self.navigationController setNavigationBarHidden:NO animated:animated];
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
    if (context == NovaFlashServiceStatus) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateFlashStatusIcon];
        });
    }
    if (context == CaptureSessionFocusExposureChange) {
        AVCaptureVideoPreviewLayer *previewLayer = (AVCaptureVideoPreviewLayer *)self.previewView.layer;

        if (_captureSessionManager.focusLockActive) {
            CGPoint viewPoint = [previewLayer pointForCaptureDevicePointOfInterest:_captureSessionManager.focusLockDevicePoint];
            [_focusLockIndicator show:viewPoint];
            _focusLockIndicator.adjusting = _captureSessionManager.focusLockAdjusting;
        } else {
            [_focusLockIndicator hide];
        }

        if (_captureSessionManager.exposureLockActive) {
            CGPoint viewPoint = [previewLayer pointForCaptureDevicePointOfInterest:_captureSessionManager.exposureLockDevicePoint];
            [_exposureLockIndicator show:viewPoint];
            _exposureLockIndicator.adjusting = _captureSessionManager.exposureLockAdjusting;
        } else {
            [_exposureLockIndicator hide];
        }
    }
}

#pragma mark - Public methods

- (IBAction)capture:(id)sender {
    if (_capturingPhoto) {
        DDLogVerbose(@"Still capturing previous image. Ignore trigger.");
        [self.statsService report:@"Photo Failed (already capturing)"
                       properties:@{}];
        return;
    }
    _capturingPhoto = YES;
    DDLogVerbose(@"Capture!");
    [self.statsService report:@"Take Photo"
                   properties:@{ @"Flash Mode": SSFlashSettingsDescribe(self.flashService.flashSettings) }];
    [self.flashService beginFlashWithCallback:^(BOOL status) {
        [self.statsService report: status ? @"Flash Succeeded" : @"Flash Failed"];
        DDLogVerbose(@"Nova flash begin returned with status %d; performing capture", status);
        [self.captureSessionManager captureStillImageWithCompletionHandler:^(NSData *imageData, UIImage *image, NSError *error) {
            
            DDLogVerbose(@"Finished capture; turning off flash");
            [self.flashService endFlashWithCallback:nil];
            
            if (error) {
                DDLogError(@"Error capturing: %@", error);
                _capturingPhoto = NO;
            } else {
                DDLogVerbose(@"Saving to asset library");
                __block typeof(self) bSelf = self;
                [[[ALAssetsLibrary alloc] init] writeImageToSavedPhotosAlbum:[image CGImage]
                                                                 orientation:(ALAssetOrientation)[image imageOrientation]
                                                             completionBlock:^(NSURL *assetURL, NSError *error) {

                    _capturingPhoto = NO;
                    _editPhoto = [self.settingsService boolForKey:kSettingsServiceEditAfterCaptureKey];
                    _sharePhoto = [self.settingsService boolForKey:kSettingsServiceShareAfterCaptureKey];

                    if (_editPhoto || _sharePhoto || [self.settingsService boolForKey:kSettingsServicePreviewAfterCaptureKey]) {
                        _showPhotoURL = assetURL;
                        [bSelf performSegueWithIdentifier:@"showPhoto" sender:self];
                    } else {
                        DDLogVerbose(@"Continuous shooting; skipping view screen");
                    }
                }];
            }
        } shutterHandler:^(int shutterCurtain) {
            DDLogVerbose(@"Shutter curtain %d", shutterCurtain);
            if (shutterCurtain == 1) {
                [self runStillImageCaptureAnimation];
            }
        }];
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

- (IBAction)zoomSliderValueChanged:(id)sender {
    self.scaleAndCropFactor = self.zoomSlider.value;
    [self zoomActive];
}

- (void)handleSingleTapFrom:(UITapGestureRecognizer *)recognizer {
    AVCaptureVideoPreviewLayer *previewLayer = (AVCaptureVideoPreviewLayer *)self.previewView.layer;
    CGPoint viewPoint = [recognizer locationInView:recognizer.view];
    CGPoint devicePoint = [previewLayer captureDevicePointOfInterestForPoint:viewPoint];

    // If tap is outside photo, ignore it - the user was mostly trying to tap a button. We don't try to fix the
    // missed button, but we also don't potentially mess up their focus.
    if (devicePoint.y > 1.0 || devicePoint.y < 0.0 || devicePoint.x > 1.0 || devicePoint.x < 0.0) {
        return;
    }

    [self.captureSessionManager focusOnDevicePoint:devicePoint];
    [self.captureSessionManager exposeOnDevicePoint:devicePoint];
}

- (void)handleDoubleTapFrom:(UITapGestureRecognizer *)recognizer {
    [self.captureSessionManager focusReset];
    [self.captureSessionManager exposeReset];
}

- (void)focusDragged:(SSCameraLockView *)view withEvent:(UIEvent *)event {
    CGPoint oldViewPoint = _focusLockIndicator.center;

    UITouch *touch = [[event touchesForView:view] anyObject];

    CGPoint oldTouchPoint = [touch previousLocationInView:view];
    CGPoint newTouchPoint = [touch locationInView:view];
    CGFloat dx = newTouchPoint.x - oldTouchPoint.x;
    CGFloat dy = newTouchPoint.y - oldTouchPoint.y;

    CGPoint newViewPoint = CGPointMake(oldViewPoint.x + dx, oldViewPoint.y + dy);
    AVCaptureVideoPreviewLayer *previewLayer = (AVCaptureVideoPreviewLayer *)self.previewView.layer;
    CGPoint devicePoint = [previewLayer captureDevicePointOfInterestForPoint:newViewPoint];

    [_captureSessionManager focusOnDevicePoint:devicePoint];
}

- (void)exposureDragged:(SSCameraLockView *)view withEvent:(UIEvent *)event {
    CGPoint oldViewPoint = _exposureLockIndicator.center;

    UITouch *touch = [[event touchesForView:view] anyObject];

    CGPoint oldTouchPoint = [touch previousLocationInView:view];
    CGPoint newTouchPoint = [touch locationInView:view];
    CGFloat dx = newTouchPoint.x - oldTouchPoint.x;
    CGFloat dy = newTouchPoint.y - oldTouchPoint.y;

    CGPoint newViewPoint = CGPointMake(oldViewPoint.x + dx, oldViewPoint.y + dy);
    AVCaptureVideoPreviewLayer *previewLayer = (AVCaptureVideoPreviewLayer *)self.previewView.layer;
    CGPoint devicePoint = [previewLayer captureDevicePointOfInterestForPoint:newViewPoint];

    [_captureSessionManager exposeOnDevicePoint:devicePoint];
}

- (void)handlePinchFrom:(UIPinchGestureRecognizer *)recognizer {
    DDLogVerbose(@"handlePinch");
    CGFloat scale = _beginGestureScale * recognizer.scale;
    self.scaleAndCropFactor = scale;
    self.zoomSlider.value = self.scaleAndCropFactor;
    [self zoomActive];
}

- (void)resetZoom {
    self.scaleAndCropFactor = 1.0;
    self.zoomSlider.value = self.scaleAndCropFactor;
}

#pragma mark - Properties

- (void)setScaleAndCropFactor:(CGFloat)scaleAndCropFactor {
    CGFloat scale = scaleAndCropFactor;
    if (scale < 1.0) {
        scale = 1.0;
    }
    if (scale > kZoomMaxScale) {
        scale = kZoomMaxScale;
    }
    [self willChangeValueForKey:@"scaleAndCropFactor"];
    _scaleAndCropFactor = scale;
    [self didChangeValueForKey:@"scaleAndCropFactor"];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateZoomTransform];
        self.captureSessionManager.videoScaleAndCropFactor = scale;
    });
}

- (SSSettingsService *)settingsService {
    if (_settingsService == nil) {
        _settingsService = [SSSettingsService sharedService];
    }
    return _settingsService;
}

#pragma mark - Private methods

- (void)updateZoomTransform {
    DDLogVerbose(@"updateZoomTransform; scaleAndCropFactor: %g", self.scaleAndCropFactor);
    CGAffineTransform transform = CGAffineTransformMakeScale(self.scaleAndCropFactor, self.scaleAndCropFactor);
    CGAffineTransform currTransform = self.previewView.layer.affineTransform;
    DDLogVerbose(@"Current transform: %@ new transform: %@", NSStringFromCGAffineTransform(currTransform), NSStringFromCGAffineTransform(transform));
    [CATransaction begin];
    [CATransaction setAnimationDuration:kTransformAnimationDuration];
    self.previewView.layer.affineTransform = transform;
    [CATransaction commit];
}

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

        [UIView animateWithDuration:kFlashSettingsAnimationDuration delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
            self.flashSettingsViewController.view.frame = self.view.frame;
        } completion:^(BOOL finished) {
            [self.flashSettingsViewController viewDidAppear:animated];
        }];
    } else {
        self.flashSettingsViewController.view.frame = self.view.frame;
        [self.flashSettingsViewController viewDidAppear:animated];
    }
    
    [self.flashService temporaryEnableFlashIfDisabled];
}

- (void)hideFlashSettingsAnimated:(BOOL)animated {
    [self.flashSettingsViewController viewWillDisappear:animated];
    
    if (animated) {
        [UIView animateWithDuration:kFlashSettingsAnimationDuration delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
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
    
    [self.flashService endTemporaryEnableFlash];
}

- (void)updateFlashStatusIcon {
    // Update flash status icon to match flash service status
    SSNovaFlashStatus status = self.flashService.status;
    NSString *iconImageName = nil;
    switch (status) {
        case SSNovaFlashStatusDisabled:
        case SSNovaFlashStatusUnknown:
        default:
            iconImageName = nil;
            break;
        case SSNovaFlashStatusOK:
            [self.statsService report:@"Flash Connection OK"];
            iconImageName = @"icon-ok";
            break;
        case SSNovaFlashStatusError:
            [self.statsService report:@"Flash Connection Error"];
            iconImageName = @"icon-error";
            break;
        case SSNovaFlashStatusSearching:
            iconImageName = @"icon-searching";
            break;
    }
    if (iconImageName) {
        self.flashIconImage.image = [UIImage imageNamed:iconImageName];
        self.flashIconImage.hidden = NO;
    } else {
        self.flashIconImage.hidden = YES;
    }
}

- (void)setupCaptureButtonAudioPlayer {
    // Hack to enable physical volume button: set up an audio player
    // See: http://stackoverflow.com/a/10460866/72
    
    NSError *audioPlayerError = nil;
    NSURL *emptySoundURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"empty" ofType:@"wav"]];
    
    DDLogVerbose(@"Created new audio player");
    self.captureButtonAudioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:emptySoundURL error:&audioPlayerError];
    if (audioPlayerError) {
        DDLogError(@"Error setting up audio player: %@", audioPlayerError);
    } else {
        [self.captureButtonAudioPlayer prepareToPlay];
        [self.captureButtonAudioPlayer stop];
        _audioSessionTimestamp = CACurrentMediaTime();
    }
    
    if (self.volumeView) {
        [self.volumeView removeFromSuperview];
    }
    
    // Create volume view off-screen
    self.volumeView = [[MPVolumeView alloc] initWithFrame:CGRectMake(-1000, -1000, 100, 100)];
    [self.volumeView sizeToFit];
    [self.view addSubview:self.volumeView];
}

- (void)volumeChanged:(NSNotification *)notification {
    bool enabled = [[SSSettingsService sharedService] boolForKey:kSettingsServiceEnableVolumeButtonTriggerKey];

    if (!enabled) {
        return;
    }

    DDLogVerbose(@"Volume button pressed");
    CFTimeInterval timeSinceSessionSetup = CACurrentMediaTime() - _audioSessionTimestamp;
    if (timeSinceSessionSetup > kMinimumTimeBeforeVolumeButtonCapture) {
        [self capture:nil];
    } else {
        DDLogVerbose(@"Ignoring volume change notification as only %g has passed since session init", timeSinceSessionSetup);
    }
}

- (void)setupZoomSlider {
    // Set up slider for zoom indication
    UIImage *sliderTrack = [UIImage imageNamed:@"zoom-slider-track"];
    UIImage *sliderThumb = [UIImage imageNamed:@"zoom-slider-thumb"];
    [self.zoomSlider setMaximumTrackImage:sliderTrack forState:UIControlStateNormal];
    [self.zoomSlider setMinimumTrackImage:sliderTrack forState:UIControlStateNormal];
    [self.zoomSlider setThumbImage:sliderThumb forState:UIControlStateNormal];
    self.zoomSlider.minimumValue = 1.0;
    self.zoomSlider.maximumValue = kZoomMaxScale;
    self.zoomSlider.value = 1.0;
    self.zoomSlider.alpha = 0.0;
    self.zoomSlider.userInteractionEnabled = NO;
    _zoomActiveTimestamp = 0;
    _zoomSliderVisible = NO;
}

- (void)zoomActive {
    if (!_zoomSliderVisible) {
        // Show slider
        dispatch_async(dispatch_get_main_queue(), ^{
            _zoomSliderVisible = YES;
            self.zoomSlider.hidden = NO;
            self.zoomSlider.userInteractionEnabled = YES;
            [UIView animateWithDuration:kZoomSliderAnimationDuration animations:^{
                self.zoomSlider.alpha = 1.0;
            } completion:^(BOOL finished) {
            }];
        });
    }
    _zoomActiveTimestamp = CACurrentMediaTime();
    
    // Set timer to check activity after kZoomSliderHideDelay seconds
    double delayInSeconds = (double)kZoomSliderHideDelay;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [self zoomCheckActivityAndClose];
    });
}

- (void)zoomCheckActivityAndClose {
    DDLogVerbose(@"zoomCheckActivityAndClose");
    if (_zoomSliderVisible) {
        DDLogVerbose(@"slider visible");
        CFTimeInterval elapsed = CACurrentMediaTime() - _zoomActiveTimestamp;
        DDLogVerbose(@"elapsed = %g", elapsed);
        if (elapsed >= kZoomSliderHideDelay) {
            DDLogVerbose(@"Hiding slider");
            // Hide slider
            dispatch_async(dispatch_get_main_queue(), ^{
                _zoomSliderVisible = NO;
                [UIView animateWithDuration:kZoomSliderAnimationDuration animations:^{
                    self.zoomSlider.alpha = 0.0;
                } completion:^(BOOL finished) {
                    self.zoomSlider.hidden = YES;
                    self.zoomSlider.userInteractionEnabled = NO;
                }];
            });
        }
    }
}

- (void)saveAndResetZoom {
    _previousScaleAndCropFactor = self.scaleAndCropFactor;
    _previousZoomSliderValue = self.zoomSlider.value;
    [self resetZoom];
    self.previewView.center = self.view.center;
}

- (void)restoreOrResetZoom {
    if (_previousScaleAndCropFactor > 0.01) {
        self.scaleAndCropFactor = _previousScaleAndCropFactor;
        self.zoomSlider.value = _previousZoomSliderValue;
    } else {
        [self resetZoom];
    }
    self.previewView.center = self.view.center;
}

#pragma mark - SSFlashSettingsViewControllerDelegate

- (void)flashSettingsViewController:(SSFlashSettingsViewController *)flashSettingsViewController didConfirmSettings:(SSFlashSettings)flashSettings {
    [self hideFlashSettingsAnimated:YES];
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    if ([gestureRecognizer isKindOfClass:[UIPinchGestureRecognizer class]]) {
        _beginGestureScale = self.scaleAndCropFactor;
        DDLogVerbose(@"pinch gesture beginning with scale %g", self.scaleAndCropFactor);
    }
    return YES;
}

#pragma mark - Handle device rotation

- (void)didRotate:(NSNotification *)notification {
    // Rotate icons

    CGFloat newRotationAngle = [self closestAngleFrom:_rotationAngle to:[self rotationAngle]];

    [UIView animateWithDuration:kOrientationChangeAnimationDuration animations:^{
        CGAffineTransform rotationTransform = CGAffineTransformMakeRotation(newRotationAngle);
        self.libraryButton.transform = rotationTransform;
        self.flashSettingsButton.transform = rotationTransform;
        self.generalSettingsButton.transform = rotationTransform;
        self.toggleCameraButton.transform = rotationTransform;
        self.captureButton.transform = rotationTransform;
        self.flashIconImage.transform = rotationTransform;
        [_focusLockIndicator transformContents:rotationTransform];
        [_exposureLockIndicator transformContents:rotationTransform];

        self.flashSettingsViewController.view.transform = rotationTransform;
    } completion:nil];

    _rotationAngle = newRotationAngle;
}

- (CGFloat)rotationAngle {
    UIDeviceOrientation orientation = [[UIDevice currentDevice] orientation];

    switch (orientation) {
        case UIDeviceOrientationPortraitUpsideDown:
            return (CGFloat)M_PI;
        case UIDeviceOrientationLandscapeLeft:
            return (CGFloat)M_PI * 0.5f;
        case UIDeviceOrientationLandscapeRight:
            return (CGFloat)M_PI * 1.5f;
        default:
            return 0;
    }
}

- (CGFloat)closestAngleFrom:(CGFloat)oldAngle to:(CGFloat)newAngle {
    // When rotating from one angle to another, adjust to the shortest location.
    // e.g. going from 270deg to 0deg, don't rotate 3 quarters in the opposite direction,
    // but instead head to 360 deg instead which is only 1 quarter turn.
    if (ABS(oldAngle - newAngle) > M_PI) {
        if (oldAngle > newAngle) {
            return newAngle + (CGFloat)M_PI * 2.0f;
        } else {
            return newAngle - (CGFloat)M_PI * 2.0f;
        }
    } else {
        return newAngle;
    }
}

@end
