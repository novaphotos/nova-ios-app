//
//  SSPhotoViewController.h
//  NovaCamera
//
//  Created by Mike Matz on 1/9/14.
//  Copyright (c) 2014 Sneaky Squid. All rights reserved.
//

#import <UIKit/UIKit.h>

/**
 * Photo viewer; UIImageView embedded in a UIScrollView allowing user to
 * pan and zoom around image.
 */
@interface SSPhotoViewController : UIViewController <UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIScrollViewDelegate>

/**
 * Local URL of photo asset to use.
 */
@property (nonatomic, strong) NSURL *photoURL;

/**
 * Image view containing the target image
 */
@property (nonatomic, strong) IBOutlet UIImageView *imageView;

/**
 * Scroll view allowing for zooming and panning. This will actually
 * be assigned an SSCenteredScrollView instance in the storyboard to
 * ensure that the image remains centered on the screen when zoom
 * scale allows for margins.
 */
@property (nonatomic, strong) IBOutlet UIScrollView *scrollView;

/**
 * Image width contraint; modified when image is changed
 */
@property (nonatomic, strong) IBOutlet NSLayoutConstraint *imageWidthConstraint;

/**
 * Image height constraint; modified when image is changed
 */
@property (nonatomic, strong) IBOutlet NSLayoutConstraint *imageHeightConstraint;

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

@end
