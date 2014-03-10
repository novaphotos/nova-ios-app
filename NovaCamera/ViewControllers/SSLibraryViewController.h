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
 * URL of asset to display as soon as the view is displayed
 */
@property (nonatomic, strong) NSURL *prepareToDisplayAssetURL;

/**
 * Flag to determine whetehr this photo should be automatically edited
 */
@property (nonatomic, assign) BOOL automaticallyEditPhoto;

/**
 * Flag to determine whether this photo should be automatically shared
 */
@property (nonatomic, assign) BOOL automaticallySharePhoto;

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
- (void)showAssetWithURL:(NSURL *)assetURL animated:(BOOL)animated;

/**
 * Edit specified asset
 */
- (void)editAssetWithURL:(NSURL *)assetURL animated:(BOOL)animated;

@end
