//
//  SSLibraryViewController.m
//  NovaCamera
//
//  Created by Mike Matz on 1/15/14.
//  Copyright (c) 2014 Sneaky Squid. All rights reserved.
//

#import "SSLibraryViewController.h"
#import "SSAssetsLibraryService.h"
#import "SSPhotoViewController.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import <AviarySDK/AFPhotoEditorController.h>
#import <BlocksKit/UIAlertView+BlocksKit.h>

@interface SSLibraryViewController () <AFPhotoEditorControllerDelegate, UIPageViewControllerDataSource, UIPageViewControllerDelegate> {
    
    BOOL _assetsLoaded;
    BOOL _viewWillAppear;
}

/**
 * Asset library service; enumerates and tracks assets
 */
@property (nonatomic, strong) SSAssetsLibraryService *assetsLibraryService;

/**
 * Aviary editor
 */
@property (nonatomic, strong) AFPhotoEditorController *photoEditorController;

/**
 * Aviary session, used for exporting hi-res images
 */
@property (nonatomic, strong) AFPhotoEditorSession *photoEditorSession;

/**
 * Reference to current ALAsset object
 */
@property (nonatomic, strong) ALAsset *asset;

/**
 * Indicates whether we're currently looking up an asset, set in
 * lookupAssetFromURL:markAsActive:completion: when looking up an "active" asset.
 * Useful for managing UI state.
 */
@property (nonatomic, assign) BOOL retrievingAsset;

/**
 * Instantiate a view controller for the specified asset URL
 */
- (SSPhotoViewController *)photoViewControllerForAssetURL:(NSURL *)assetURL markAsActive:(BOOL)isActive;

/**
 * Retrieve asset from URL; activate, and call completion block
 */
- (void)lookupAssetFromURL:(NSURL *)assetURL markAsActive:(BOOL)isActive completion:(void (^)(ALAsset *asset))completion;

/**
 * Save hi-res image from Aviary editor
 */
- (void)saveHiResImage:(UIImage *)image;

@end

@implementation SSLibraryViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Custom initialization
    self.assetsLibraryService = [[SSAssetsLibraryService alloc] init];
    self.selectedIndex = NSNotFound;
    _assetsLoaded = NO;
    _viewWillAppear = NO;

    __block typeof(self) bSelf = self;
    
    [self.assetsLibraryService enumerateAllAssetsWithCompletion:^(NSArray *assetURLs, NSError *error) {
        bSelf->_assetsLoaded = YES;
    }];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (!self.asset && !self.retrievingAsset) {
        // Show library
        [self showLibraryAnimated:YES sender:self];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.destinationViewController isKindOfClass:[UIPageViewController class]]) {
        // Capture reference to UIPageViewController so that we can later setViewControllers:direction:animated:
        self.pageViewController = (UIPageViewController *)segue.destinationViewController;
        self.pageViewController.delegate = self;
        self.pageViewController.dataSource = self;
    }
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
        __block typeof(self) bSelf = self;
        
        void (^deleteAsset)(ALAsset *assetToDelete) = ^(ALAsset *assetToDelete) {
            int numAssets = bSelf.assetsLibraryService.assetURLs.count;
            int nextIndex = 0;
            if (bSelf.selectedIndex > 0 && bSelf.selectedIndex < numAssets) {
                nextIndex = bSelf.selectedIndex - 1;
            }
            
            [bSelf.assetsLibraryService removeAssetURLAtIndex:self.selectedIndex];
            if (bSelf.assetsLibraryService.assetURLs.count) {
                bSelf.selectedIndex = nextIndex;
                dispatch_async(dispatch_get_main_queue(), ^{
                    [bSelf showAssetWithURL:bSelf.assetsLibraryService.assetURLs[self.selectedIndex]];
                });
            }
            
            [assetToDelete setImageData:nil metadata:nil completionBlock:^(NSURL *assetURL, NSError *error) {
                if (error) {
                    DDLogError(@"Unable to delete asset. Error: %@", error);
                } else {
                    DDLogVerbose(@"Asset deletion returned with assetURL: %@", assetURL);
                }
            }];
        };
        
        [UIAlertView bk_showAlertViewWithTitle:@"Delete Photo" message:@"Are you sure?" cancelButtonTitle:@"Cancel" otherButtonTitles:@[@"Delete"] handler:^(UIAlertView *alertView, NSInteger buttonIndex) {
            DDLogVerbose(@"Alert modal.. pressed button idx %d", buttonIndex);
            if (buttonIndex == 1) {
                deleteAsset(bSelf.asset);
            }
        }];
        
    } else {
        NSString *msg = @"Unable to delete this photo because it was not created with the Nova app. Instead, try deleting the photo using the built-in Photos app.";
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:msg delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
        [alert show];
    }
}


// See: http://developers.aviary.com/docs/ios/setup-guide
- (IBAction)editPhoto:(id)sender {
    /*
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
     */
}

- (IBAction)sharePhoto:(id)sender {
    /*
    NSArray *activityItems = @[
                               self.fullResolutionImage,
                               ];
    UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:activityItems applicationActivities:nil];
    activityVC.completionHandler = ^(NSString *activityType, BOOL completed) {
    };
    [self presentViewController:activityVC animated:YES completion:nil];
     */
}

- (void)showAssetWithURL:(NSURL *)assetURL {
    SSPhotoViewController *photoVC = [self photoViewControllerForAssetURL:assetURL markAsActive:YES];
    NSUInteger idx = [self.assetsLibraryService indexOfAssetWithURL:assetURL];
    DDLogVerbose(@"showAssetWithURL:%@ asset idx: %d", assetURL, idx);
    UIPageViewControllerNavigationDirection dir = UIPageViewControllerNavigationDirectionForward;
    if (NSNotFound == idx) {
        DDLogError(@"showAssetsWithURL:%@ can't find asset in our list", assetURL);
    }
    self.selectedIndex = idx;
    [self.pageViewController setViewControllers:@[photoVC] direction:dir animated:NO completion:nil];
}

#pragma mark - Private methods

- (SSPhotoViewController *)photoViewControllerForAssetURL:(NSURL *)assetURL markAsActive:(BOOL)isActive {
    __block SSPhotoViewController *vc = [self.storyboard instantiateViewControllerWithIdentifier:@"photoViewController"];
    DDLogVerbose(@"photoViewControllerForAssetURL:%@ returning view controller and will populate asset afterwards", assetURL);
    
    [self lookupAssetFromURL:assetURL markAsActive:isActive completion:^(ALAsset *asset) {
        DDLogVerbose(@"Populating asset: %@ for VC: %@", assetURL, vc);
        vc.asset = asset;
    }];
    
    return vc;
}

- (void)lookupAssetFromURL:(NSURL *)assetURL markAsActive:(BOOL)isActive completion:(void (^)(ALAsset *asset))completion {
    __block BOOL bIsActive = isActive;
    __block typeof(self) bSelf = self;
    self.retrievingAsset = YES;
    [self.assetsLibraryService assetForURL:assetURL resultBlock:^(ALAsset *asset) {
        if (bIsActive) {
            bSelf.retrievingAsset = NO;
            bSelf.asset = asset;
        }
        if (completion) {
            completion(asset);
        }
    } failureBlock:^(NSError *error) {
        if (bIsActive) {
            bSelf.retrievingAsset = NO;
            bSelf->_asset = nil;
        }
        if (completion) {
            completion(nil);
        }
    }];
}

- (void)saveHiResImage:(UIImage *)image {
    /*
    // Save image to asset library, in background
    DDLogVerbose(@"Encoding & saving modified image to asset library, in background");
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        NSData *imageData = UIImageJPEGRepresentation(image, 0.9);
        NSDictionary *metadata = @{};
        [_asset writeModifiedImageDataToSavedPhotosAlbum:imageData metadata:metadata completionBlock:^(NSURL *assetURL, NSError *error) {
            DDLogVerbose(@"Modified image saved to asset library: %@ (Error: %@)", assetURL, error);
            if (!error) {
                // Load new asset
                
                [self loadAssetForURL:assetURL];
            }
        }];
    });
     */
}

#pragma mark - UIPageViewControllerDataSource

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerBeforeViewController:(UIViewController *)viewController {
    UIViewController *vc = nil;
    SSPhotoViewController *oldVC = (SSPhotoViewController *)viewController;
    NSUInteger oldIdx = [self.assetsLibraryService indexOfAsset:oldVC.asset];
    if (oldIdx + 1 < self.assetsLibraryService.assetURLs.count && oldIdx != NSNotFound) {
        NSURL *newURL = self.assetsLibraryService.assetURLs[oldIdx + 1];
        vc = [self photoViewControllerForAssetURL:newURL markAsActive:NO];
    }
    return vc;
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerAfterViewController:(UIViewController *)viewController {
    UIViewController *vc = nil;
    SSPhotoViewController *oldVC = (SSPhotoViewController *)viewController;
    NSUInteger oldIdx = [self.assetsLibraryService indexOfAsset:oldVC.asset];
    if (oldIdx > 0 && oldIdx != NSNotFound) {
        NSURL *newURL = self.assetsLibraryService.assetURLs[oldIdx - 1];
        vc = [self photoViewControllerForAssetURL:newURL markAsActive:NO];
    }
    return vc;
}

#pragma mark - UIPageViewControllerDelegate

- (void)pageViewController:(UIPageViewController *)pageViewController willTransitionToViewControllers:(NSArray *)pendingViewControllers {
    // Update selected index
    SSPhotoViewController *vc = [pendingViewControllers firstObject];
    self.asset = vc.asset;
    self.selectedIndex = [self.assetsLibraryService indexOfAsset:self.asset];
}

#pragma mark - AFPhotoEditorControllerDelegate
/*
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
 */

#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    DDLogVerbose(@"Picked media with info: %@", info);
    dispatch_async(dispatch_get_main_queue(), ^{
        NSURL *mediaURL = info[UIImagePickerControllerReferenceURL];
        [self showAssetWithURL:mediaURL];
        [self dismissViewControllerAnimated:YES completion:^{
            DDLogVerbose(@"Finished dismissing imagePickerController");
            double delayInSeconds = 2.0;
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
            dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                dispatch_async(dispatch_get_main_queue(), ^{
                    DDLogVerbose(@"View hierarchy from library: %@", [self.view recursiveDescription]);
                });
            });
        }];
    });
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [self dismissViewControllerAnimated:YES completion:nil];
}


@end
