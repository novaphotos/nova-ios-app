//
//  SSLibraryViewController.m
//  NovaCamera
//
//  Created by Mike Matz on 1/15/14.
//  Copyright (c) 2014 Sneaky Squid. All rights reserved.
//

#import "SSLibraryViewController.h"
#import "SSChronologicalAssetsLibraryService.h"
#import "SSPhotoViewController.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import <AviarySDK/AFPhotoEditorController.h>
#import <BlocksKit/UIAlertView+BlocksKit.h>

@interface SSLibraryViewController () <AFPhotoEditorControllerDelegate, UIPageViewControllerDataSource, UIPageViewControllerDelegate> {
    
    BOOL _assetsLoaded;
    BOOL _viewWillAppear;
    BOOL _waitingToDisplayInsertedAsset;
}

/**
 * Asset library service; enumerates and tracks assets
 */
@property (nonatomic, strong) SSChronologicalAssetsLibraryService *libraryService;

/**
 * Aviary editor
 */
@property (nonatomic, strong) AFPhotoEditorController *photoEditorController;

/**
 * Aviary session, used for exporting hi-res images
 */
@property (nonatomic, strong) AFPhotoEditorSession *photoEditorSession;

/**
 * Instantiate a view controller for the specified asset URL
 */
- (SSPhotoViewController *)photoViewControllerForAssetURL:(NSURL *)assetURL markAsActive:(BOOL)isActive;

/**
 * Save hi-res image from Aviary editor
 */
- (void)saveHiResImage:(UIImage *)image;

/**
 * Respond to asset library changes: adding and removing assets
 */
- (void)assetLibraryUpdatedWithNotification:(NSNotification *)notification;

@end

@implementation SSLibraryViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
    }
    return self;
}

- (void)Dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:(NSString *)SSChronologicalAssetsLibraryUpdatedNotification object:self.libraryService];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Custom initialization
    self.libraryService = [SSChronologicalAssetsLibraryService sharedService];
    self.selectedIndex = NSNotFound;
    _assetsLoaded = NO;
    _viewWillAppear = NO;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(assetLibraryUpdatedWithNotification:) name:(NSString *)SSChronologicalAssetsLibraryUpdatedNotification object:self.libraryService];

    __block typeof(self) bSelf = self;
    
    [self.libraryService enumerateAssetsWithCompletion:^(NSUInteger numberOfAssets) {
        bSelf->_assetsLoaded = YES;
    }];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (self.selectedIndex == NSNotFound) {
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

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
    [self.pageViewController willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    [super didRotateFromInterfaceOrientation:fromInterfaceOrientation];
    [self.pageViewController didRotateFromInterfaceOrientation:fromInterfaceOrientation];
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
    [self.libraryService assetAtIndex:self.selectedIndex withCompletion:^(ALAsset *asset) {
        if (asset.editable) {
            [UIAlertView bk_showAlertViewWithTitle:@"Delete Photo" message:@"Are you sure?" cancelButtonTitle:@"Cancel" otherButtonTitles:@[@"Delete"] handler:^(UIAlertView *alertView, NSInteger buttonIndex) {
                if (buttonIndex == 1) {
                    [asset setImageData:nil metadata:nil completionBlock:^(NSURL *assetURL, NSError *error) {
                        if (error) {
                            DDLogError(@"Unable to delete asset. Error: %@", error);
                        } else {
                            DDLogVerbose(@"Asset deletion returned with assetURL: %@", assetURL);
                        }
                    }];
                }
            }];
        } else {
            NSString *msg = @"Unable to delete this photo because it was not created with the Nova app. Instead, try deleting the photo using the built-in Photos app.";
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:msg delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
            [alert show];
        }
    }];
}


// See: http://developers.aviary.com/docs/ios/setup-guide
- (IBAction)editPhoto:(id)sender {
    // TODO: Show loading
    __block typeof(self) bSelf = self;
    NSURL *assetURL = [self.libraryService assetURLAtIndex:self.selectedIndex];
    [self.libraryService fullResolutionImageForAssetWithURL:assetURL withCompletion:^(UIImage *image) {
        DDLogVerbose(@"Loading Aviary photo editor with image: %@", image);
        
        // Create editor
        bSelf.photoEditorController = [[AFPhotoEditorController alloc] initWithImage:image];
        [bSelf.photoEditorController setDelegate:bSelf];
        
        // Present editor
        [bSelf presentViewController:bSelf.photoEditorController animated:YES completion:nil];
        
        // Capture photo editor's session and capture a strong reference
        __block AFPhotoEditorSession *session = bSelf.photoEditorController.session;
        bSelf.photoEditorSession = session;
        
        // Create a context with maximum output resolution
        AFPhotoEditorContext *context = [session createContextWithImage:image];
        
        // Request that the context asynchronously replay the session's actions on its image.
        [context render:^(UIImage *result) {
            // `result` will be nil if the image was not modified in the session, or non-nil if the session was closed successfully
            if (result != nil) {
                DDLogVerbose(@"Photo editor context returned the modified hi-res image; saving");
                [bSelf saveHiResImage:result];
            } else {
                DDLogVerbose(@"Photo editor context returned nil; must not have been modified");
            }
            
            // Release session
            bSelf.photoEditorSession = nil;
        }];
    }];
}

- (IBAction)sharePhoto:(id)sender {
    __block typeof(self) bSelf = self;
    NSURL *assetURL = [self.libraryService assetURLAtIndex:self.selectedIndex];
    [self.libraryService fullResolutionImageForAssetWithURL:assetURL withCompletion:^(UIImage *image) {
        NSArray *activityItems = @[
                                   image,
                                   ];
        UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:activityItems applicationActivities:nil];
        activityVC.completionHandler = ^(NSString *activityType, BOOL completed) {
        };
        [bSelf presentViewController:activityVC animated:YES completion:nil];
    }];
}

- (void)showAssetWithURL:(NSURL *)assetURL {
    SSPhotoViewController *photoVC = [self photoViewControllerForAssetURL:assetURL markAsActive:YES];
    NSUInteger idx = [self.libraryService indexOfAssetWithURL:assetURL];
    DDLogVerbose(@"showAssetWithURL:%@ asset idx: %d", assetURL, (int)idx);
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
    vc.assetURL = assetURL;
    return vc;
}

- (void)saveHiResImage:(UIImage *)image {
    // Save image to asset library, in background
    DDLogVerbose(@"Encoding & saving modified image to asset library, in background");
    __block typeof(self) bSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        NSData *imageData = UIImageJPEGRepresentation(image, 0.9);
        NSDictionary *metadata = @{};
        
        // Retrieve current asset to write modified image data to
        [self.libraryService assetAtIndex:self.selectedIndex withCompletion:^(ALAsset *asset) {
            [asset writeModifiedImageDataToSavedPhotosAlbum:imageData metadata:metadata completionBlock:^(NSURL *assetURL, NSError *error) {
                DDLogVerbose(@"Modified image saved to asset library: %@ (Error: %@)", assetURL, error);
                
                DDLogVerbose(@"Has the asset changed notification fired yet?");
                
                if (!error) {
                    // Load new asset
                    _waitingToDisplayInsertedAsset = YES;
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [bSelf showAssetWithURL:assetURL];
                    });
                }
            }];
        }];
    });
}

- (void)assetLibraryUpdatedWithNotification:(NSNotification *)notification {
    NSIndexSet *insertedIndexes = notification.userInfo[SSChronologicalAssetsLibraryInsertedAssetIndexesKey];
    NSIndexSet *deletedIndexes = notification.userInfo[SSChronologicalAssetsLibraryDeletedAssetIndexesKey];
    
    void (^showAssetAtIndex)(NSUInteger index) = ^(NSUInteger index) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showAssetWithURL:[self.libraryService assetURLAtIndex:index]];
        });
    };
    
    if (_waitingToDisplayInsertedAsset && insertedIndexes.count) {
        _waitingToDisplayInsertedAsset = NO;
        showAssetAtIndex([insertedIndexes firstIndex]);
    } else if ([deletedIndexes containsIndex:self.selectedIndex]) {
        // Deleted our current asset; determine which to show next
        DDLogVerbose(@"Deleted current asset");
        if (self.selectedIndex > 0) {
            showAssetAtIndex(self.selectedIndex - 1);
        } else {
            if (self.libraryService.numberOfAssets > 0) {
                showAssetAtIndex(self.selectedIndex);
            } else {
                // No more assets!
                DDLogError(@"No more assets to show");
            }
        }
    } else {
        if (self.pageViewController.viewControllers.count > 0) {
            // Current index may need to change..
            SSPhotoViewController *vc = (SSPhotoViewController *)self.pageViewController.viewControllers[0];
            self.selectedIndex = [self.libraryService indexOfAssetWithURL:vc.assetURL];
        }
    }
}

#pragma mark - UIPageViewControllerDataSource

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerBeforeViewController:(UIViewController *)viewController {
    UIViewController *vc = nil;
    SSPhotoViewController *oldVC = (SSPhotoViewController *)viewController;
    NSUInteger oldIdx = [self.libraryService indexOfAssetWithURL:oldVC.assetURL];
    if (oldIdx + 1 < self.libraryService.numberOfAssets && oldIdx != NSNotFound) {
        NSURL *newURL = [self.libraryService assetURLAtIndex:(oldIdx + 1)];
        vc = [self photoViewControllerForAssetURL:newURL markAsActive:NO];
    }
    return vc;
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerAfterViewController:(UIViewController *)viewController {
    UIViewController *vc = nil;
    SSPhotoViewController *oldVC = (SSPhotoViewController *)viewController;
    NSUInteger oldIdx = [self.libraryService indexOfAssetWithURL:oldVC.assetURL];
    if (oldIdx > 0 && oldIdx != NSNotFound) {
        NSURL *newURL = [self.libraryService assetURLAtIndex:(oldIdx - 1)];
        vc = [self photoViewControllerForAssetURL:newURL markAsActive:NO];
    }
    return vc;
}

#pragma mark - UIPageViewControllerDelegate

- (void)pageViewController:(UIPageViewController *)pageViewController willTransitionToViewControllers:(NSArray *)pendingViewControllers {
    // Update selected index
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        SSPhotoViewController *vc = [pendingViewControllers firstObject];
        self.selectedIndex = [self.libraryService indexOfAssetWithURL:vc.assetURL];
        
        DDLogVerbose(@"Updated selectedIndex to %d", self.selectedIndex);
        if (self.selectedIndex == NSNotFound) {
            DDLogVerbose(@"asset URL not found: %@", vc.assetURL);
        }
    });
}

#pragma mark - AFPhotoEditorControllerDelegate

- (void)photoEditor:(AFPhotoEditorController *)editor finishedWithImage:(UIImage *)image {
    DDLogVerbose(@"photoEditor:%@ finishedWithImage:%@", editor, image);
    // TODO: Show an activity indicator while the hi-res photo loads
    [self dismissViewControllerAnimated:YES completion:nil];
    self.photoEditorController = nil;
}

- (void)photoEditorCanceled:(AFPhotoEditorController *)editor {
    DDLogVerbose(@"photoEditorCanceled:%@", editor);
    [self dismissViewControllerAnimated:YES completion:nil];
    self.photoEditorController = nil;
}

#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    DDLogVerbose(@"Picked media with info: %@", info);
    dispatch_async(dispatch_get_main_queue(), ^{
        NSURL *mediaURL = info[UIImagePickerControllerReferenceURL];
        [self showAssetWithURL:mediaURL];
        [self dismissViewControllerAnimated:YES completion:nil];
    });
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [self dismissViewControllerAnimated:YES completion:nil];
}


@end
