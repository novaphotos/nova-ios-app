//
//  SSFlashSettingsViewController.m
//  NovaCamera
//
//  Created by Mike Matz on 1/24/14.
//  Copyright (c) 2014 Sneaky Squid. All rights reserved.
//

#import "SSFlashSettingsViewController.h"
#import "SSTheme.h"

static const CGFloat customSettingsHeight = 70.0;
static const NSTimeInterval customSettingsAnimationDuration = 0.25;

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
                    @(SSFlashModeBright),
                    @(SSFlashModeCustom),
                    ];
    _flashModeButtons = @[
                          self.flashOffButton,
                          self.flashGentleButton,
                          self.flashWarmButton,
                          self.flashBrightButton,
                          self.flashCustomButton,
                          ];
    _flashModeImageNames = @[
                             @"btn-flash-off",
                             @"btn-flash-gentle",
                             @"btn-flash-warm",
                             @"btn-flash-bright",
                             @"btn-flash-custom",
                             ];
    
    [[SSTheme currentTheme] updateFontsInView:self.view includeSubviews:YES];
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
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
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
        default:
            settings.flashBrightness = 0.5;
            settings.flashColorTemperature = 0.5;
            settings.flashMode = mode;
            break;
    }
    [self setFlashSettings:settings animated:YES];
}

- (IBAction)testFlash:(id)sender {
}

- (IBAction)confirmFlashSettings:(id)sender {
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
    
    self.colorTempSlider.value = flashSettings.flashColorTemperature;
    self.brightnessSlider.value = flashSettings.flashBrightness;
    
    if (flashSettings.flashMode == SSFlashModeCustom && oldSettings.flashMode != SSFlashModeCustom) {
        // Show custom settings
        [self showCustomSettingsAnimated:animated];
    } else if (flashSettings.flashMode != SSFlashModeCustom && oldSettings.flashMode == SSFlashModeCustom) {
        // Hide custom settings
        [self hideCustomSettingsAnimated:animated];
    }
    
    [self updateFlashModeButtons];
    
    [self didChangeValueForKey:@"flashSettings"];
}

#pragma mark - Properties

- (void)setFlashSettings:(SSFlashSettings)flashSettings {
    [self setFlashSettings:flashSettings animated:NO];
}

#pragma mark - Private methods

- (void)initialSetup {
    self.previousCustomFlashSettings = SSFlashSettingsCustomDefault;
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

@end
