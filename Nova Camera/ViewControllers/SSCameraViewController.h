//
//  SSCameraViewController.h
//  Nova Camera
//
//  Created by Mike Matz on 12/20/13.
//  Copyright (c) 2013 Sneaky Squid. All rights reserved.
//

#import <UIKit/UIKit.h>

@class SSCameraPreviewView;

@interface SSCameraViewController : UIViewController

@property (nonatomic, strong) IBOutlet SSCameraPreviewView *previewView;
@property (nonatomic, strong) IBOutlet UIButton *captureButton;
@property (nonatomic, strong) IBOutlet UIButton *libraryButton;
@property (nonatomic, strong) IBOutlet UIButton *flashSettingsButton;
@property (nonatomic, strong) IBOutlet UIButton *generalSettingsButton;
@property (nonatomic, strong) IBOutlet UIButton *toggleCameraButton;

- (IBAction)capture:(id)sender;
- (IBAction)showGeneralSettings:(id)sender;
- (IBAction)showFlashSettings:(id)sender;
- (IBAction)showLibrary:(id)sender;
- (IBAction)toggleCamera:(id)sender;

@end
