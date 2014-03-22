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
#import "SSStatsService.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import <AviarySDK/AFPhotoEditorController.h>
#import <MBProgressHUD/MBProgressHUD.h>

@interface SSLibraryViewController () <AFPhotoEditorControllerDelegate, UIPageViewControllerDataSource, UIPageViewControllerDelegate> {
    
    BOOL _assetsLoaded;
    BOOL _viewWillAppear;
    BOOL _waitingToDisplayInsertedAsset;
    BOOL _imagePickerCanceled;
    BOOL _didEditPhoto;
    
    UIAlertView *_confirmDeleteAlertView;
    ALAsset *_assetToDelete;
    
    NSURL *_lastAssetURL;
}

/**
 * Stats service
 */
@property (nonatomic, strong) SSStatsService *statsService;

/**
 * Aviary editor
 */
@property (nonatomic, strong) AFPhotoEditorController *photoEditorController;

/**
 * Aviary session, used for exporting hi-res images
 */
@property (nonatomic, strong) AFPhotoEditorSession *photoEditorSession;

/**
 * Reference currently displayed picker
 */
@property (nonatomic, strong) UIImagePickerController *imagePickerController;

/**
 * Instantiate a view controller for the specified asset URL
 */
- (SSPhotoViewController *)photoViewControllerForAssetURL:(NSURL *)assetURL markAsActive:(BOOL)isActive;

/**
 * Helper to launch the photo editor for specified asset
 */
- (void)launchEditorForAssetWithURL:(NSURL *)assetURL;

/**
 * Helper to launch photo editor
 */
- (void)launchEditorForCurrentAsset;

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

- (void)commonInit {
    self.selectedIndex = NSNotFound;
    _assetsLoaded = NO;
    _viewWillAppear = NO;
    _imagePickerCanceled = NO;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:(NSString *)SSChronologicalAssetsLibraryUpdatedNotification object:self.libraryService];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.statsService = [SSStatsService sharedService];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(assetLibraryUpdatedWithNotification:) name:(NSString *)SSChronologicalAssetsLibraryUpdatedNotification object:self.libraryService];
    
    // Enumerate assets
    __block typeof(self) bSelf = self;
    [self.libraryService enumerateAssetsWithGroupTypes:ALAssetsGroupSavedPhotos completion:^(NSUInteger numberOfAssets) {
        bSelf->_assetsLoaded = YES;
    }];

}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    if (self.prepareToDisplayAssetURL) {
        [self showAssetWithURL:self.prepareToDisplayAssetURL animated:NO];
        self.prepareToDisplayAssetURL = nil;
    }
    
    if (self.automaticallyEditPhoto) {
        DDLogVerbose(@"Automatically edit photo");
        [self launchEditorForCurrentAsset];
        self.automaticallyEditPhoto = NO;
    } else if (self.automaticallySharePhoto && !_didEditPhoto) {
        DDLogVerbose(@"Automatically share photo");
        [self sharePhoto:self];
        self.automaticallySharePhoto = NO;
    }
    
    if (!_lastAssetURL) {
        if (_imagePickerCanceled) {
            // User didn't pick an image; hide the library screen
            [self.presentingViewController dismissViewControllerAnimated:animated completion:nil];
        } else {
            // Show library
            [self showLibraryAnimated:animated sender:self];
        }
    }
    
    _didEditPhoto = NO;
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
    self.imagePickerController = [[UIImagePickerController alloc] init];
    self.imagePickerController.delegate = self;
    self.imagePickerController.sourceType = UIImagePickerControllerSourceTypeSavedPhotosAlbum;
    [self presentViewController:self.imagePickerController animated:animated completion:nil];
}

- (IBAction)showLibrary:(id)sender {
    [self showLibraryAnimated:YES sender:sender];
}

- (IBAction)showCamera:(id)sender {
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)deletePhoto:(id)sender {
    if (!_lastAssetURL) {
        DDLogError(@"Unable to delete asset with no _lastAsseURL");
        return;
    }
    [self.libraryService assetForURL:_lastAssetURL withCompletion:^(ALAsset *asset) {
        if (asset.editable) {
            [self.statsService report:@"Photo Delete"];
            _confirmDeleteAlertView = [[UIAlertView alloc] initWithTitle:@"Delete Photo" message:@"Are you sure?" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Delete", nil];
            _assetToDelete = asset;
            [_confirmDeleteAlertView show];
        } else {
            [self.statsService report:@"Photo Could Not Delete"];
            NSString *msg = @"Unable to delete this photo because it was not created with the Nova app. Instead, try deleting the photo using the built-in Photos app.";
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:msg delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
            [alert show];
        }
    }];
}


// See: http://developers.aviary.com/docs/ios/setup-guide
- (IBAction)editPhoto:(id)sender {
    // TODO: Show loading
    NSURL *assetURL = _lastAssetURL;
    if (!assetURL) {
        assetURL = [self.libraryService assetURLAtIndex:self.selectedIndex];
    }
    [self launchEditorForAssetWithURL:assetURL];
}

- (IBAction)sharePhoto:(id)sender {
    __block typeof(self) bSelf = self;
    
    NSURL *assetURL = _lastAssetURL;
    if (!assetURL) {
        assetURL = [self.libraryService assetURLAtIndex:self.selectedIndex];
    }
    [self.libraryService fullResolutionImageForAssetWithURL:assetURL withCompletion:^(UIImage *image) {
        NSArray *activityItems = @[
                                   image,
                                   ];
        [self.statsService report:@"Share Start"];
        UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:activityItems applicationActivities:nil];
        activityVC.completionHandler = ^(NSString *activityType, BOOL completed) {
            if (completed) {
                [self.statsService report:@"Share Success" properties:@{ @"Activity": activityType }];
            } else {
                [self.statsService report:@"Share Fail"];
            }
            
        };
        [bSelf presentViewController:activityVC animated:YES completion:nil];
    }];
}

- (void)showAssetWithURL:(NSURL *)assetURL animated:(BOOL)animated {
    _lastAssetURL = assetURL;
    SSPhotoViewController *photoVC = [self photoViewControllerForAssetURL:assetURL markAsActive:YES];
    NSUInteger idx = [self.libraryService indexOfAssetWithURL:assetURL];
    DDLogVerbose(@"showAssetWithURL:%@ asset idx: %d", assetURL, (int)idx);
    UIPageViewControllerNavigationDirection dir = UIPageViewControllerNavigationDirectionForward;
    if (NSNotFound == idx) {
        DDLogError(@"showAssetsWithURL:%@ can't find asset in our list", assetURL);
    }
    self.selectedIndex = idx;
    DDLogVerbose(@"Updated selectedIndex to %d", idx);
    [self.pageViewController setViewControllers:@[photoVC] direction:dir animated:animated completion:nil];
}

- (void)editAssetWithURL:(NSURL *)assetURL animated:(BOOL)animated {
    [self showAssetWithURL:assetURL animated:animated];
    [self launchEditorForAssetWithURL:assetURL];
}

#pragma mark - Properties

- (SSChronologicalAssetsLibraryService *)libraryService {
    if (!_libraryService) {
        _libraryService = [SSChronologicalAssetsLibraryService sharedService];
    }
    return _libraryService;
}

#pragma mark - Private methods

- (SSPhotoViewController *)photoViewControllerForAssetURL:(NSURL *)assetURL markAsActive:(BOOL)isActive {
    __block SSPhotoViewController *vc = [self.storyboard instantiateViewControllerWithIdentifier:@"photoViewController"];
    DDLogVerbose(@"photoViewControllerForAssetURL:%@ returning view controller and will populate asset afterwards", assetURL);
    vc.assetURL = assetURL;
    return vc;
}

- (void)launchEditorForAssetWithURL:(NSURL *)assetURL {
    __block typeof(self) bSelf = self;
    [self.statsService report:@"Aviary Launch"];
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
                [self.statsService report:@"Aviary Saved"];
                [bSelf saveHiResImage:result];
            } else {
                DDLogVerbose(@"Photo editor context returned nil; must not have been modified");
                [self.statsService report:@"Aviary Canceled"];
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    // Remove HUD
                    [MBProgressHUD hideAllHUDsForView:self.view animated:YES];
                    
                    // Set edit flag to no; edit will be triggered when view appears
                    _didEditPhoto = NO;
                });
            }
            
            // Release session
            bSelf.photoEditorSession = nil;
        }];
    }];
}

- (void)launchEditorForCurrentAsset {
    NSURL *assetURL = _lastAssetURL;
    if (!assetURL) {
        assetURL = [self.libraryService assetURLAtIndex:self.selectedIndex];
    }
    [self launchEditorForAssetWithURL:assetURL];
}

- (void)saveHiResImage:(UIImage *)image {
    // Save image to asset library, in background
    DDLogVerbose(@"Encoding & saving modified image to asset library, in background");
    __block typeof(self) bSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        NSData *imageData = UIImageJPEGRepresentation(image, 0.9);
        NSDictionary *metadata = @{};
        
        // Retrieve current asset to write modified image data to
        [self.libraryService assetForURL:_lastAssetURL withCompletion:^(ALAsset *asset) {
            [asset writeModifiedImageDataToSavedPhotosAlbum:imageData metadata:metadata completionBlock:^(NSURL *assetURL, NSError *error) {
                DDLogVerbose(@"Modified image saved to asset library: %@ (Error: %@)", assetURL, error);

                // Remove HUD
                [MBProgressHUD hideAllHUDsForView:self.view animated:YES];

                if (!error) {
                    // Load new asset
                    _waitingToDisplayInsertedAsset = YES;
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [bSelf showAssetWithURL:assetURL animated:NO];
                        // Share photo
                        if (self.automaticallySharePhoto) {
                            self.automaticallySharePhoto = NO;
                            [self sharePhoto:nil];
                        }
                    });
                }
            }];
        }];
    });
}

- (void)assetLibraryUpdatedWithNotification:(NSNotification *)notification {
    NSIndexSet *insertedIndexes = notification.userInfo[SSChronologicalAssetsLibraryInsertedAssetIndexesKey];
    NSIndexSet *deletedIndexes = notification.userInfo[SSChronologicalAssetsLibraryDeletedAssetIndexesKey];
    
    DDLogVerbose(@"assetLibraryUpdatedWithNotification: inserted %d deleted %d", insertedIndexes.count, deletedIndexes.count);
    
    void (^showAssetAtIndex)(NSUInteger index) = ^(NSUInteger index) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showAssetWithURL:[self.libraryService assetURLAtIndex:index] animated:YES];
        });
    };
    
    NSUInteger newIndex = NSNotFound;
    if (_lastAssetURL) {
        newIndex = [self.libraryService indexOfAssetWithURL:_lastAssetURL];
    }
    
    DDLogVerbose(@"Before update logic; self.selectedIndex=%d newIndex=%d _lastAssetURL=%@", self.selectedIndex, newIndex, _lastAssetURL);
    
    if (_waitingToDisplayInsertedAsset) {
        // Hopefully this means our asset is now displayed
        DDLogVerbose(@"Asset library updated while waiting to display inserted asset. (Number of inserted assets in notification: %d)", insertedIndexes.count);
        if (newIndex != NSNotFound) {
            DDLogVerbose(@"Setting new index: %d", newIndex);
            _waitingToDisplayInsertedAsset = NO;
            self.selectedIndex = newIndex;
        } else {
            DDLogVerbose(@"Didn't find our new asset. Guess we're still waiting?");
        }
    } else if (newIndex == NSNotFound) {
        // Deleted our current asset; determine which to show next
        DDLogVerbose(@"Don't have an index for the current asset.");
        if (self.selectedIndex == NSNotFound) {
            DDLogVerbose(@"Didn't have an index before either.");
        } else if (self.selectedIndex > 0) {
            DDLogVerbose(@"Previous index was %d. Going to display the previous one.", self.selectedIndex);
            showAssetAtIndex(self.selectedIndex - 1);
        } else {
            DDLogVerbose(@"Previous index was 0.");
            if (self.libraryService.numberOfAssets > 0) {
                DDLogVerbose(@"Going to show the first asset.");
                showAssetAtIndex(0);
            } else {
                DDLogVerbose(@"Don't actually have any assets to show. What to do?");
            }
        }
    } else {
        // Index may need to change
        if (newIndex != self.selectedIndex) {
            DDLogVerbose(@"Need to change selectedIndex from %d to %d", self.selectedIndex, newIndex);
            self.selectedIndex = newIndex;
        } else {
            DDLogVerbose(@"Didn't need to change selectedIndex (%d)", self.selectedIndex);
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
    _didEditPhoto = YES;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        hud.labelText = @"Processing image";
        [self dismissViewControllerAnimated:YES completion:nil];
        self.photoEditorController = nil;
    });
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
        [self showAssetWithURL:mediaURL animated:YES];
        [self dismissViewControllerAnimated:YES completion:^{
            self.imagePickerController = nil;
        }];
    });
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [self dismissViewControllerAnimated:YES completion:^{
        self.imagePickerController = nil;
    }];
    _imagePickerCanceled = YES;
}

#pragma mark UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView willDismissWithButtonIndex:(NSInteger)buttonIndex {
    if (alertView == _confirmDeleteAlertView) {
        if (buttonIndex == 1) {
            [_assetToDelete setImageData:nil metadata:nil completionBlock:^(NSURL *assetURL, NSError *error) {
                if (error) {
                    DDLogError(@"Unable to delete asset. Error: %@", error);
                } else {
                    DDLogVerbose(@"Asset deletion returned with assetURL: %@", assetURL);
                }
            }];
        }
        _assetToDelete = nil;
    }
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if (alertView == _confirmDeleteAlertView) {
        _confirmDeleteAlertView = nil;
        _assetToDelete = nil;
    }
}

- (void)alertViewCancel:(UIAlertView *)alertView {
    if (alertView == _confirmDeleteAlertView) {
        _confirmDeleteAlertView = nil;
        _assetToDelete = nil;
    }
}

@end
