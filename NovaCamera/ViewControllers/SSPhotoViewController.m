//
//  SSPhotoViewController.m
//  NovaCamera
//
//  Created by Mike Matz on 1/9/14.
//  Copyright (c) 2014 Sneaky Squid. All rights reserved.
//

#import "SSPhotoViewController.h"
#import <AssetsLibrary/AssetsLibrary.h>

/**
 * Private ivars, properties and methods supporting SSPhotoViewController
 */
@interface SSPhotoViewController () {
    /**
     * References full resolution image when first requested after
     * loading a new ALAsset
     */
    UIImage *_fullResolutionImage;
}

/**
 * Display the specified image. Called from -loadAssetForURL:
 */
- (void)displayImage:(UIImage *)image;

/**
 * Display image from specified asset
 */
- (void)displayAsset:(ALAsset *)asset;

@end


@implementation SSPhotoViewController

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
    
    // Use auto layout for scroll view & image view layout
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.imageView.translatesAutoresizingMaskIntoConstraints = NO;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (self.asset && !self.imageView.image) {
        [self displayAsset:self.asset];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    [self resetZoom];
}

#pragma mark - Public methods

- (void)resetZoom {
    // Calculate minimum zoom that fits entire image within view bounds
    CGFloat minZoomX = self.view.bounds.size.width / self.imageView.image.size.width;
    CGFloat minZoomY = self.view.bounds.size.height / self.imageView.image.size.height;
    CGFloat minZoom = MIN(minZoomX, minZoomY);
    
    // Ensure that minimum zoom is not greater than 1.0, so that image will
    // not be forcibly stretched
    minZoom = MIN(1.0, minZoom);
    
    // Set minimum and initial zoom to the calculated scale so that entire
    // image is displayed within bounds
    self.scrollView.minimumZoomScale = minZoom;
    self.scrollView.zoomScale = minZoom;
    
    // Max zoom should be at least 2x, but should be sufficient to allow
    // image to stretch to fill the screen
    CGFloat maxZoom = MAX(minZoomX, minZoomY);
    maxZoom = MAX(maxZoom, 2.0);
    self.scrollView.maximumZoomScale = maxZoom;
    
    // Disable scrolling on scrollview
    self.scrollView.scrollEnabled = NO;
    
    // Ensure scrollview updates its layout
    [self.scrollView setNeedsLayout];
}

#pragma mark - Properties

- (void)setAsset:(ALAsset *)asset {
    [self willChangeValueForKey:@"asset"];
    _asset = asset;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self displayAsset:asset];
    });
    [self didChangeValueForKey:@"asset"];
}

#pragma mark - Private methods

- (void)displayImage:(UIImage *)image {
    DDLogVerbose(@"displayImage:%@ size:%@", image, NSStringFromCGSize(image.size));
    self.imageView.image = image;
    if (image) {
        self.imageHeightConstraint.constant = image.size.height;
        self.imageWidthConstraint.constant = image.size.width;
        [self resetZoom];
    } else {
        self.imageHeightConstraint.constant = 0;
        self.imageWidthConstraint.constant = 0;
    }
}

- (void)displayAsset:(ALAsset *)asset {
    CGImageRef cgImage = [[self.asset defaultRepresentation] fullResolutionImage];
    UIImage *image = [UIImage imageWithCGImage:cgImage];
    [self displayImage:image];
}

#pragma mark - UIScrollViewDelegate

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    return self.imageView;
}

- (void)scrollViewDidEndZooming:(UIScrollView *)scrollView withView:(UIView *)view atScale:(CGFloat)scale {
    
    // If we're zoomed out to the min zoom, enable gesture recognizers and disable scroll.
    // Otherwise, disable gesture recognizers and enable scroll.
    
    if (scale > scrollView.minimumZoomScale) {
        DDLogVerbose(@"Enabling scrolling");
        self.scrollView.scrollEnabled = YES;
    } else {
        DDLogVerbose(@"Disabling scrolling");
        self.scrollView.scrollEnabled = NO;
    }
}


@end
