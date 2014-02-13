//
//  SSCameraViewController.h
//  NovaCamera
//
//  Created by Mike Matz on 12/20/13.
//  Copyright (c) 2013 Sneaky Squid. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SSFlashSettingsViewController.h"

@class SSCameraPreviewView;
@class SSNovaFlashService;

/**
 * Camera capture view; handles preview, camera capture, displaying of
 * various settings, and transitions to library view
 */
@interface SSCameraViewController : UIViewController <UIImagePickerControllerDelegate, UINavigationControllerDelegate, SSFlashSettingsViewControllerDelegate>

@property (nonatomic, strong) IBOutlet SSCameraPreviewView *previewView;
@property (nonatomic, strong) IBOutlet UIButton *captureButton;
@property (nonatomic, strong) IBOutlet UIButton *libraryButton;
@property (nonatomic, strong) IBOutlet UIButton *flashSettingsButton;
@property (nonatomic, strong) IBOutlet UIButton *generalSettingsButton;
@property (nonatomic, strong) IBOutlet UIButton *toggleCameraButton;
@property (nonatomic, strong) IBOutlet UIImageView *flashIconImage;

@property (nonatomic, strong) IBOutlet SSFlashSettingsViewController *flashSettingsViewController;

@property (nonatomic, strong) SSNovaFlashService *flashService;

- (IBAction)capture:(id)sender;
- (IBAction)showGeneralSettings:(id)sender;
- (IBAction)showFlashSettings:(id)sender;
- (IBAction)showLibrary:(id)sender;
- (IBAction)toggleCamera:(id)sender;
- (IBAction)focusAndExposeTap:(id)sender;

@end
