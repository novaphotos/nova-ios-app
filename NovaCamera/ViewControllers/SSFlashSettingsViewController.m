//
//  SSFlashSettingsViewController.m
//  NovaCamera
//
//  Created by Mike Matz on 1/24/14.
//  Copyright (c) 2014 Sneaky Squid. All rights reserved.
//

#import "SSFlashSettingsViewController.h"
#import "SSStatsService.h"
#import "SSTheme.h"


static const CGFloat customSettingsHeight = 70.0;
static const NSTimeInterval customSettingsAnimationDuration = 0.25;

static void * NovaFlashServiceStatus = &NovaFlashServiceStatus;

@interface SSFlashSettingsViewController () {
    NSArray *_flashModeButtons;
    NSArray *_flashModes;
    NSArray *_flashModeImageNames;
}

/**
 * Shared setup / initialization
 */
- (void)initialSetup;

/**
 * Expand to show custom settings
 */
- (void)showCustomSettingsAnimated:(BOOL)animated;

/**
 * Contract to hide custom settings
 */
- (void)hideCustomSettingsAnimated:(BOOL)animated;

/**
 * Helper to find the flash mode indicated by the UIButton
 */
- (SSFlashMode)flashModeForButton:(UIButton *)button;

/**
 * Update button images to indicate active flash mode
 */
- (void)updateFlashModeButtons;

/**
 * Update flash status text
 */
- (void)updateFlashStatus;

/**
 * Persist changes to color temp to flashSettings
 */
- (IBAction)warmBrightnessChanged:(id)sender;

/**
 * Persist changes to brightness to flashSettings
 */
- (IBAction)coolBrightnessChanged:(id)sender;

/**
 * Capture background view taps; hide the flash view
 * when received.
 */
- (IBAction)backgroundViewTapped:(id)sender;

@end

@implementation SSFlashSettingsViewController

@synthesize flashSettings=_flashSettings;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        [self initialSetup];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self initialSetup];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _flashModes = @[
                    @(SSFlashModeOff),
                    @(SSFlashModeGentle),
                    @(SSFlashModeWarm),
                    @(SSFlashModeNeutral),
                    @(SSFlashModeBright),
                    @(SSFlashModeCustom),
                    ];
    _flashModeButtons = @[
                          self.flashOffButton,
                          self.flashGentleButton,
                          self.flashWarmButton,
                          self.flashNeutralButton,
                          self.flashBrightButton,
                          self.flashCustomButton,
                          ];
    _flashModeImageNames = @[
                             @"btn-flash-off",
                             @"btn-flash-gentle",
                             @"btn-flash-warm",
                             @"btn-flash-neutral",
                             @"btn-flash-bright",
                             @"btn-flash-custom",
                             ];
    
    [[SSTheme currentTheme] updateFontsInView:self.view includeSubviews:YES];
    
    [[SSTheme currentTheme] styleSlider:self.coolBrightnessSlider];
    [[SSTheme currentTheme] styleSlider:self.warmBrightnessSlider];
    
    // Set up the background view to respond to tap events, so that the view can
    // be dismissed when tapped.
    UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(backgroundViewTapped:)];
    tapGestureRecognizer.delegate = self;
    [self.view addGestureRecognizer:tapGestureRecognizer];
    
    // Add stats service
    self.statsService = [SSStatsService sharedService];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    // Determine whether custom menu should be displayed
    if (self.flashSettings.flashMode == SSFlashModeCustom) {
        [self showCustomSettingsAnimated:animated];
    } else {
        [self hideCustomSettingsAnimated:animated];
    }
    
    [self updateFlashModeButtons];
    [self updateFlashStatus];
    
    [self.flashService addObserver:self forKeyPath:@"status" options:0 context:NovaFlashServiceStatus];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
    [self.flashService removeObserver:self forKeyPath:@"status"];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == NovaFlashServiceStatus) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateFlashStatus];
        });
    }
}

#pragma mark - Public methods

- (IBAction)changeFlashMode:(id)sender {
    SSFlashMode mode = [self flashModeForButton:sender];
    SSFlashSettings settings = self.flashSettings;
    switch (mode) {
        case SSFlashModeCustom:
            settings = self.previousCustomFlashSettings;
            break;
        case SSFlashModeGentle:
            settings = SSFlashSettingsGentle;
            break;
        case SSFlashModeBright:
            settings = SSFlashSettingsBright;
            break;
        case SSFlashModeWarm:
            settings = SSFlashSettingsWarm;
            break;
        case SSFlashModeNeutral:
            settings = SSFlashSettingsNeutral;
            break;
        default:
            settings.warmBrightness = 1.0;
            settings.coolBrightness = 1.0;
            settings.flashMode = mode;
            break;
    }
    [self setFlashSettings:settings animated:YES];
}

- (IBAction)testFlash:(id)sender {
    [self.flashService beginFlashWithSettings:self.flashSettings callback:^(BOOL status) {
        [self.statsService report:status ? @"Test Flash Succeeded" : @"Test Flash Failed"
                       properties:@{ @"Flash Mode": SSFlashSettingsDescribe(self.flashService.flashSettings) }];
    }];
}

- (IBAction)confirmFlashSettings:(id)sender {
    self.flashService.flashSettings = self.flashSettings;
    if (self.delegate) {
        [self.delegate flashSettingsViewController:self didConfirmSettings:self.flashSettings];
    } else {
        DDLogError(@"No delegate set for SSFlashSettingsViewController");
    }
}

- (void)setFlashSettings:(SSFlashSettings)flashSettings animated:(BOOL)animated {
    [self willChangeValueForKey:@"flashSettings"];
    SSFlashSettings oldSettings = _flashSettings;
    _flashSettings = flashSettings;
    
    self.warmBrightnessSlider.value = flashSettings.warmBrightness;
    self.coolBrightnessSlider.value = flashSettings.coolBrightness;
    
    if (flashSettings.flashMode == SSFlashModeCustom && oldSettings.flashMode != SSFlashModeCustom) {
        // Show custom settings
        [self showCustomSettingsAnimated:animated];
    } else if (flashSettings.flashMode != SSFlashModeCustom && oldSettings.flashMode == SSFlashModeCustom) {
        // Hide custom settings
        [self hideCustomSettingsAnimated:animated];
    }
    
    if (flashSettings.flashMode == SSFlashModeCustom) {
        self.previousCustomFlashSettings = flashSettings;
    }
    
    [self updateFlashModeButtons];
    
    [self didChangeValueForKey:@"flashSettings"];
}

#pragma mark - Properties

- (void)setFlashSettings:(SSFlashSettings)flashSettings {
    [self setFlashSettings:flashSettings animated:NO];
}

- (SSNovaFlashService *)flashService {
    if (!_flashService) {
        _flashService = [SSNovaFlashService sharedService];
    }
    return _flashService;
}

#pragma mark - Private methods

- (void)initialSetup {
    self.previousCustomFlashSettings = SSFlashSettingsCustomDefault;
    
    // Read flash settings from flash service
    self.flashSettings = self.flashService.flashSettings;
}

- (void)showCustomSettingsAnimated:(BOOL)animated {
    if (animated) {
        UIViewAnimationOptions opts = UIViewAnimationOptionCurveEaseInOut;
        [UIView animateWithDuration:customSettingsAnimationDuration delay:0 options:opts animations:^{
            self.flashCustomSettingsHeightConstraint.constant = customSettingsHeight;
            [self.view layoutIfNeeded];
        } completion:nil];
    } else {
        self.flashCustomSettingsHeightConstraint.constant = customSettingsHeight;
    }
}

- (void)hideCustomSettingsAnimated:(BOOL)animated {
    if (animated) {
        UIViewAnimationOptions opts = UIViewAnimationOptionCurveEaseInOut;
        [UIView animateWithDuration:customSettingsAnimationDuration delay:0 options:opts animations:^{
            self.flashCustomSettingsHeightConstraint.constant = 0.0;
            [self.view layoutIfNeeded];
        } completion:nil];
    } else {
        self.flashCustomSettingsHeightConstraint.constant = 0.0;
    }
}

- (SSFlashMode)flashModeForButton:(UIButton *)button {
    NSUInteger idx = [_flashModeButtons indexOfObject:button];
    NSNumber *modeNumber = _flashModes[idx];
    SSFlashMode mode = (SSFlashMode)[modeNumber intValue];
    return mode;
}

- (void)updateFlashModeButtons {
    for (NSUInteger k = 0; k < _flashModes.count; k++) {
        NSNumber *modeNumber = _flashModes[k];
        SSFlashMode mode = (SSFlashMode)modeNumber.intValue;
        UIButton *flashButton = _flashModeButtons[k];
        NSString *imgName = _flashModeImageNames[k];
        if (mode == self.flashSettings.flashMode) {
            imgName = [imgName stringByAppendingString:@"-selected"];
        }
        UIImage *image = [UIImage imageNamed:imgName];
        [flashButton setImage:image forState:UIControlStateNormal];
    }
}

- (void)updateFlashStatus {
    SSNovaFlashStatus status = self.flashService.status;
    NSString *statusStr = nil;
    NSString *strengthStr = nil;
    switch (status) {
        case SSNovaFlashStatusDisabled:
            statusStr = @"Disabled";
            break;
        case SSNovaFlashStatusError:
            statusStr = @"Error";
            break;
        case SSNovaFlashStatusOK:
            statusStr = @"OK";
            strengthStr = @"Good";
            break;
        case SSNovaFlashStatusSearching:
            statusStr = @"Searching";
            break;
        case SSNovaFlashStatusUnknown:
        default:
            statusStr = @"";
            break;
    }
    self.flashStatusLabel.text = statusStr;
    self.flashStrengthLabel.text = strengthStr;
}

- (IBAction)warmBrightnessChanged:(id)sender {
    SSFlashSettings settings = self.flashSettings;
    settings.warmBrightness = self.warmBrightnessSlider.value;
    self.flashSettings = settings;
}

- (IBAction)coolBrightnessChanged:(id)sender {
    SSFlashSettings settings = self.flashSettings;
    settings.coolBrightness = self.coolBrightnessSlider.value;
    self.flashSettings = settings;
}

- (IBAction)backgroundViewTapped:(id)sender {
    // For now, we'll pretend the user tapped OK
    [self confirmFlashSettings:sender];
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    // We only want taps to the main view, not subviews.
    if (touch.view == self.view) {
        return YES;
    } else {
        return NO;
    }
}

@end
