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
    
    /**
     * Points to the currently displayed image's index within the asset
     * library
     */
    NSUInteger _currentAssetLibraryIndex;
}

/**
 * Reference to a single assets library
 */
@property (nonatomic, strong) ALAssetsLibrary *assetsLibrary;

/**
 * ALAsset for currently displayed image
 */
@property (nonatomic, strong) ALAsset *asset;

/**
 * All assets in photo library, sorted by date modified (newest first)
 */
@property (nonatomic, strong) NSMutableArray *allLibraryAssetURLs;

/**
 * Aviary photo editor controller
 */
@property (nonatomic, strong) AFPhotoEditorController *photoEditorController;

/**
 * Aviary photo editor session, used to export hi-res image
 */
@property (nonatomic, strong) AFPhotoEditorSession *photoEditorSession;

/**
 * Load asset at the given URL. assetURL must point to a valid local file
 * URL that is present in the ALAssetsLibrary.
 *
 * Side effect: clears self.asset and self.fullResolutionImage
 */
- (void)loadAssetForURL:(NSURL *)assetURL;

/**
 * Enumerate assets library, building up self.allLibraryAssets array.
 */
- (void)enumerateAssetLibrary;

/**
 * Scan our copy of the asset library for the current asset
 */
- (void)updateCurrentAssetLibraryIndex;

/**
 * Display the specified image. Called from -loadAssetForURL:
 */
- (void)displayImage:(UIImage *)image;

/**
 * Reset zoom, fitting the current image if larger than the screen, but
 * not zooming beyind 1x.
 */
- (void)resetZoom;

/**
 * Save hi-res image from Aviary editor
 */
- (void)saveHiResImage:(UIImage *)image;

@end

/**
 * Simple ALAsset category to add -defaultURL
 */
@interface ALAsset (defaultURL)
- (NSURL *)defaultURL;
@end

@implementation ALAsset (defaultURL)
- (NSURL *)defaultURL {
    return self.defaultRepresentation.url;
}
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
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        [self enumerateAssetLibrary];
    });
    
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.imageView.translatesAutoresizingMaskIntoConstraints = NO;
}

- (void)viewWillAppear:(BOOL)animated {
    if (self.photoURL && !self.imageView.image) {
        [self loadAssetForURL:self.photoURL];
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
    if (self.asset.editable) {
        ALAsset *assetToDelete = self.asset;
        __block typeof(self) bSelf = self;
        
        // Find the next photo to show (should be the previous item in the library)
        NSURL *nextAssetURL = nil;
        DDLogVerbose(@"1");
        NSURL *currentAssetURL = self.asset.defaultURL;
        __block NSMutableArray *newLibraryAssetURLs = [self.allLibraryAssetURLs mutableCopy];
        [newLibraryAssetURLs removeObject:currentAssetURL];
        if (_currentAssetLibraryIndex == 0 || _currentAssetLibraryIndex == NSNotFound) {
            nextAssetURL = [newLibraryAssetURLs firstObject];
        } else if (newLibraryAssetURLs.count > _currentAssetLibraryIndex) {
            nextAssetURL = newLibraryAssetURLs[_currentAssetLibraryIndex];
        } else {
            nextAssetURL = [newLibraryAssetURLs lastObject];
        }
        
        // Display next asset
        if (nextAssetURL) {
            DDLogVerbose(@"Showing next asset prior to deletion. New asset: %@", nextAssetURL);
            [self loadAssetForURL:nextAssetURL];
        } else {
            // No more assets to show
            DDLogVerbose(@"Deleted last asset; no more assets to show");
            
        }
        
        DDLogVerbose(@"Calling setImageData:metadata:completionBlock: on self.asset %@", assetToDelete);
        [assetToDelete setImageData:nil metadata:nil completionBlock:^(NSURL *assetURL, NSError *error) {
            
            if (error) {
                DDLogError(@"Unable to delete asset. Error: %@", error);
            } else {
                DDLogVerbose(@"Asset deletion returned with assetURL: %@", assetURL);
            }
            
            // Switch out the asset URL list
            bSelf.allLibraryAssetURLs = newLibraryAssetURLs;
        }];
    } else {
        NSString *msg = @"Unable to delete this photo because it was not created with the Nova app. Instead, try deleting the photo using the built-in Photos app.";
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:msg delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
        [alert show];
    }
}


// See: http://developers.aviary.com/docs/ios/setup-guide
- (IBAction)editPhoto:(id)sender {
    UIImage *image = self.fullResolutionImage;
    
    DDLogVerbose(@"Loading Aviary photo editor with image: %@", image);

    // Create editor
    self.photoEditorController = [[AFPhotoEditorController alloc] initWithImage:image];
    [self.photoEditorController setDelegate:self];
    
    // Present editor
    [self presentViewController:self.photoEditorController animated:YES completion:nil];
    
    // Capture photo editor's session and capture a strong reference
    __block AFPhotoEditorSession *session = self.photoEditorController.session;
    self.photoEditorSession = session;
    
    // Create a context with maximum output resolution
    AFPhotoEditorContext *context = [session createContextWithImage:image];
    
    // Request that the context asynchronously replay the session's actions on its image.
    [context render:^(UIImage *result) {
        // `result` will be nil if the image was not modified in the session, or non-nil if the session was closed successfully
        if (result != nil) {
            DDLogVerbose(@"Photo editor context returned the modified hi-res image; saving");
            [self saveHiResImage:result];
        } else {
            DDLogVerbose(@"Photo editor context returned nil; must not have been modified");
        }
        
        // Release session
        self.photoEditorSession = nil;
    }];
}

- (IBAction)sharePhoto:(id)sender {
    NSArray *activityItems = @[
                               self.fullResolutionImage,
                               ];
    UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:activityItems applicationActivities:nil];
    activityVC.completionHandler = ^(NSString *activityType, BOOL completed) {
    };
    [self presentViewController:activityVC animated:YES completion:nil];
}

#pragma mark - Properties

- (void)setPhotoURL:(NSURL *)photoURL {
    DDLogVerbose(@"setPhotoURL:%@", photoURL);
    // Remove existing asset and full resolution image
    [self willChangeValueForKey:@"fullResolutionImage"];
    self.asset = nil;
    _fullResolutionImage = nil;
    _currentAssetLibraryIndex = [self.allLibraryAssetURLs indexOfObject:photoURL];
    if (_currentAssetLibraryIndex == NSNotFound) {
        DDLogVerbose(@"URL not found in current asset library");
    }
    
    // Update photo URL
    [self willChangeValueForKey:@"photoURL"];
    _photoURL = photoURL;
    
    [self didChangeValueForKey:@"photoURL"];
    [self didChangeValueForKey:@"fullResolutionImage"];
}

- (UIImage *)fullResolutionImage {
    if (!_fullResolutionImage && self.asset) {
        [self willChangeValueForKey:@"fullResolutionImage"];
        CGImageRef cgImage = [[self.asset defaultRepresentation] fullResolutionImage];
        _fullResolutionImage = [UIImage imageWithCGImage:cgImage];
        [self didChangeValueForKey:@"fullResolutionImage"];
    }
    return _fullResolutionImage;
}

#pragma mark - Private methods

- (void)loadAssetForURL:(NSURL *)assetURL {
    self.photoURL = assetURL;
    [self.assetsLibrary assetForURL:self.photoURL resultBlock:^(ALAsset *asset) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.asset = asset;
            UIImage *newImage = self.fullResolutionImage;
            [self displayImage:newImage];
        });
    } failureBlock:^(NSError *error) {
        DDLogError(@"Unable to load asset from URL %@: %@", self.photoURL, error);
    }];
}

- (void)enumerateAssetLibrary {
    self.allLibraryAssetURLs = [NSMutableArray array];
    _currentAssetLibraryIndex = NSNotFound;
    __block NSURL *currentAssetURL = self.asset.defaultURL;
    
    [self.assetsLibrary enumerateGroupsWithTypes:ALAssetsGroupAll usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
        DDLogVerbose(@"enumerateGroupsWithTypes:usingBlock: executing with group %@" , group);
        if (group) {
            [group enumerateAssetsWithOptions:NSEnumerationReverse usingBlock:^(ALAsset *result, NSUInteger index, BOOL *stop) {
                DDLogVerbose(@"enumerateAssetsWithOptions:usingBlock: executing with result=%@ index=%d", result, index);
                if (result) {
                    NSURL *url = result.defaultURL;
                    [self.allLibraryAssetURLs addObject:url];
                    DDLogVerbose(@"Adding asset URL: %@", url);
                    if ([url isEqual:currentAssetURL]) {
                        _currentAssetLibraryIndex = self.allLibraryAssetURLs.count - 1;
                    }
                    DDLogVerbose(@"Added asset: %@", result);
                }
            }];
        }
    } failureBlock:^(NSError *error) {
        DDLogError(@"Unable to enumerate assets library: %@", error);
    }];
}

- (void)updateCurrentAssetLibraryIndex {
    DDLogVerbose(@"4");
    NSURL *currentAssetURL = self.asset.defaultURL;
    _currentAssetLibraryIndex = [self.allLibraryAssetURLs indexOfObject:currentAssetURL];
    DDLogVerbose(@"updateCurrentAssetLibraryIndex, found current asset at index %d", _currentAssetLibraryIndex);
}

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

- (void)saveHiResImage:(UIImage *)image {
    // Save image to asset library, in background
    DDLogVerbose(@"Encoding & saving modified image to asset library, in background");
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        NSData *imageData = UIImageJPEGRepresentation(image, 0.9);
        NSDictionary *metadata = @{};
        [self.asset writeModifiedImageDataToSavedPhotosAlbum:imageData metadata:metadata completionBlock:^(NSURL *assetURL, NSError *error) {
            DDLogVerbose(@"Modified image saved to asset library: %@ (Error: %@)", assetURL, error);
            if (!error) {
                // Load new asset
                [self loadAssetForURL:assetURL];
            }
        }];
    });
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

#pragma mark - AFPhotoEditorControllerDelegate

- (void)photoEditor:(AFPhotoEditorController *)editor finishedWithImage:(UIImage *)image {
    DDLogVerbose(@"photoEditor:%@ finishedWithImage:%@", editor, image);
    DDLogVerbose(@"Displaying low-res image now; should get hi-res image later");
    [self displayImage:image];
    [self dismissViewControllerAnimated:YES completion:nil];
    self.photoEditorController = nil;
}

- (void)photoEditorCanceled:(AFPhotoEditorController *)editor {
    DDLogVerbose(@"photoEditorCanceled:%@", editor);
    [self dismissViewControllerAnimated:YES completion:nil];
    self.photoEditorController = nil;
}

@end
