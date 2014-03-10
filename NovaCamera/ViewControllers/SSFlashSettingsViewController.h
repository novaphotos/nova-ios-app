//
//  SSFlashSettingsViewController.h
//  NovaCamera
//
//  Created by Mike Matz on 1/24/14.
//  Copyright (c) 2014 Sneaky Squid. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SSNovaFlashService.h"

@class SSFlashSettingsViewController;

/**
 * Delegate protocol handling settings changes. The delegate, typically
 * the displaying view controller, is responsible for hiding the flash
 * settings view controller when the settings have been confirmed, and
 * for orchestrating test flash fires.
 */
@protocol SSFlashSettingsViewControllerDelegate<NSObject>
@required

/**
 * Sent when the settings have been selected by the user; settings
 * should now be hidden by the parent view controller, and the specified
 * settings should be stored.
 */
- (void)flashSettingsViewController:(SSFlashSettingsViewController *)flashSettingsViewController didConfirmSettings:(SSFlashSettings)flashSettings;

@end

@interface SSFlashSettingsViewController : UIViewController <UIGestureRecognizerDelegate>

/**
 * Delegate responsible for showing/hiding the settings and responding to settings changes
 */
@property (nonatomic, weak) id<SSFlashSettingsViewControllerDelegate> delegate;

/**
 * Current flash settings; will be updated when user makes changes, and setting these
 * will update UI accordingly.
 */
@property (nonatomic, assign) SSFlashSettings flashSettings;

/**
 * Remember the user's previously-used custom flash settings.
 */
@property (nonatomic, assign) SSFlashSettings previousCustomFlashSettings;

/**
 * Reference to flash service
 */
@property (nonatomic, strong) SSNovaFlashService *flashService;

// Flash modes
@property (nonatomic, strong) IBOutlet UIView *flashModesView;
@property (nonatomic, strong) IBOutlet UIButton *flashOffButton;
@property (nonatomic, strong) IBOutlet UIButton *flashGentleButton;
@property (nonatomic, strong) IBOutlet UIButton *flashWarmButton;
@property (nonatomic, strong) IBOutlet UIButton *flashBrightButton;
@property (nonatomic, strong) IBOutlet UIButton *flashCustomButton;

// Custom settings
@property (nonatomic, strong) IBOutlet UIView *flashCustomSettingsView;
@property (nonatomic, strong) IBOutlet UISlider *colorTempSlider;
@property (nonatomic, strong) IBOutlet UISlider *brightnessSlider;
@property (nonatomic, strong) IBOutlet NSLayoutConstraint *flashCustomSettingsHeightConstraint;

// Flash status
@property (nonatomic, strong) IBOutlet UIView *flashStatusView;
@property (nonatomic, strong) IBOutlet UIButton *flashTestButton;
@property (nonatomic, strong) IBOutlet UIButton *flashOKButton;
@property (nonatomic, strong) IBOutlet UILabel *flashStatusLabel;
@property (nonatomic, strong) IBOutlet UILabel *flashStrengthLabel;

/**
 * Handle flash mode button taps: compare sender to each flash mode
 * button and take appropriate action
 */
- (IBAction)changeFlashMode:(id)sender;

/**
 * Test-fire the Nova flash (if connected)
 */
- (IBAction)testFlash:(id)sender;

/**
 * User presses OK in flash mode screen; dismiss
 */
- (IBAction)confirmFlashSettings:(id)sender;

/**
 * Change UI to reflect the specified flash settings
 */
- (void)setFlashSettings:(SSFlashSettings)flashSettings animated:(BOOL)animated;


@end
