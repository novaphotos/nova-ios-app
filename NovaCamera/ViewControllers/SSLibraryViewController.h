//
//  SSLibraryViewController.h
//  NovaCamera
//
//  Created by Mike Matz on 1/15/14.
//  Copyright (c) 2014 Sneaky Squid. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SSLibraryViewController : UIViewController <UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIPageViewControllerDataSource, UIPageViewControllerDelegate, UIAlertViewDelegate>

/**
 * Index of current photo
 */
@property (nonatomic, assign) NSUInteger selectedIndex;

/**
 * Parent view containing controls
 */
@property (nonatomic, strong) IBOutlet UIView *controlsView;

/**
 * Container view for UIPageViewController
 */
@property (nonatomic, strong) IBOutlet UIView *containerView;

/**
 * Child view controller: UIPageViewController
 */
@property (nonatomic, strong) IBOutlet UIPageViewController *pageViewController;

/**
 * Show the image library; specify whether to animate the modal
 */
- (void)showLibraryAnimated:(BOOL)animated sender:(id)sender;

/**
 * Action to show the image library (will use animation)
 */
- (IBAction)showLibrary:(id)sender;

/**
 * Return to the camera screen, dismissing this view controller
 */
- (IBAction)showCamera:(id)sender;

/**
 * Delete the currently displayed photo
 */
- (IBAction)deletePhoto:(id)sender;

/**
 * Launch the Aviary image editor
 */
- (IBAction)editPhoto:(id)sender;

/**
 * Share photo using UIActivityViewController
 */
- (IBAction)sharePhoto:(id)sender;

/**
 * Show specified asset
 */
- (void)showAssetWithURL:(NSURL *)assetURL;


@end
