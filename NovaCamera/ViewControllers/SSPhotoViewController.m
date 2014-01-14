//
//  SSPhotoViewController.m
//  NovaCamera
//
//  Created by Mike Matz on 1/9/14.
//  Copyright (c) 2014 Sneaky Squid. All rights reserved.
//

#import "SSPhotoViewController.h"
#import <AssetsLibrary/AssetsLibrary.h>

@interface SSPhotoViewController ()
@property (nonatomic, strong) ALAssetsLibrary *assetsLibrary;
- (void)displayImageFromAsset:(ALAsset *)asset;
- (void)resetZoom;
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
    self.assetsLibrary = [[ALAssetsLibrary alloc] init];
    
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.imageView.translatesAutoresizingMaskIntoConstraints = NO;
}

- (void)viewWillAppear:(BOOL)animated {
    if (self.photoURL) {
        [self.assetsLibrary assetForURL:self.photoURL resultBlock:^(ALAsset *asset) {
            [self displayImageFromAsset:asset];
        } failureBlock:^(NSError *error) {
            DDLogError(@"Unable to load asset from URL %@: %@", self.photoURL, error);
        }];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    if (!self.photoURL) {
        [self showLibraryAnimated:YES sender:nil];
    }
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

- (void)showLibraryAnimated:(BOOL)animated sender:(id)sender {
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.delegate = self;
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    [self presentViewController:picker animated:animated completion:nil];
}

- (IBAction)showLibrary:(id)sender {
    [self showLibraryAnimated:YES sender:sender];
}

- (IBAction)showCamera:(id)sender {
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)deletePhoto:(id)sender {
}

- (IBAction)editPhoto:(id)sender {
}

- (IBAction)sharePhoto:(id)sender {
}

#pragma mark - Private methods

- (void)displayImageFromAsset:(ALAsset *)asset {
    CGImageRef cgImage = [[asset defaultRepresentation] fullResolutionImage];
    UIImage *image = [UIImage imageWithCGImage:cgImage];
    dispatch_async(dispatch_get_main_queue(), ^{
        self.imageView.image = image;
        
        // Update imageview constraints
        self.imageHeightConstraint.constant = image.size.height;
        self.imageWidthConstraint.constant = image.size.width;
        
        [self resetZoom];
    });
}

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
    
    // Ensure scrollview updates its layout
    [self.scrollView setNeedsLayout];
}

#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    DDLogVerbose(@"Picked media with info: %@", info);
    NSURL *mediaURL = info[UIImagePickerControllerReferenceURL];
    
    DDLogVerbose(@"Looking up asset by URL: %@", mediaURL);
    [[[ALAssetsLibrary alloc] init] assetForURL:mediaURL resultBlock:^(ALAsset *asset) {
        DDLogVerbose(@"Found asset: %@", asset);
        DDLogVerbose(@"Editable? %d", asset.editable);
    } failureBlock:^(NSError *error) {
        DDLogVerbose(@"Error retrieving asset: %@", error);
    }];
    
    self.photoURL = mediaURL;
    self.imageView.image = nil;
    self.imageWidthConstraint.constant = 0;
    self.imageHeightConstraint.constant = 0;
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [self dismissViewControllerAnimated:YES completion:nil];
    if (!self.photoURL) {
        [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
    }
}

#pragma mark - UIScrollViewDelegate

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    return self.imageView;
}

@end
