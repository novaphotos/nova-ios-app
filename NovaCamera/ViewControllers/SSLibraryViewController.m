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

@interface SSLibraryViewController () <AFPhotoEditorControllerDelegate, UIPageViewControllerDataSource, UIPageViewControllerDelegate> {
}
@property (nonatomic, strong) SSAssetsLibraryService *assetsLibraryService;
@property (nonatomic, strong) NSMutableArray *assetURLs;
@property (nonatomic, strong) ALAsset *asset;
@property (nonatomic, assign) NSUInteger selectedIndex;
- (SSPhotoViewController *)photoViewControllerForAssetURL:(NSURL *)assetURL;
@end

@implementation SSLibraryViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        self.assetsLibraryService = [[SSAssetsLibraryService alloc] init];
        self.delegate = self;
        self.dataSource = self;
        self.selectedIndex = NSNotFound;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    __block typeof(self) bSelf = nil;
    
    [self.assetsLibraryService enumerateAllAssetsWithCompletion:^(NSArray *assetURLs, NSError *error) {
        DDLogVerbose(@"assetsLibraryService finished enumerating; got %d assets. (error: %@)", assetURLs.count, error);
    }];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
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

#pragma mark - Private methods

- (SSPhotoViewController *)photoViewControllerForAssetURL:(NSURL *)assetURL {
    __block SSPhotoViewController *vc = [self.storyboard instantiateViewControllerWithIdentifier:@"photoViewController"];
    [self.assetsLibraryService assetForURL:assetURL resultBlock:^(ALAsset *asset) {
        vc.asset = asset;
    } failureBlock:^(NSError *error) {
        DDLogError(@"Error retrieving asset for URL %@: %@", assetURL, error);
    }];
    return vc;
}

#pragma mark - UIPageViewControllerDataSource

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerBeforeViewController:(UIViewController *)viewController {
    UIViewController *vc = nil;
    SSPhotoViewController *oldVC = (SSPhotoViewController *)viewController;
    NSUInteger oldIdx = [self.assetsLibraryService indexOfAsset:oldVC.asset];
    if (oldIdx > 0 && oldIdx != NSNotFound) {
        NSURL *newURL = self.assetsLibraryService.assetURLs[oldIdx - 1];
        vc = [self photoViewControllerForAssetURL:newURL];
    }
    return vc;
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerAfterViewController:(UIViewController *)viewController {
    UIViewController *vc = nil;
    SSPhotoViewController *oldVC = (SSPhotoViewController *)viewController;
    NSUInteger oldIdx = [self.assetsLibraryService indexOfAsset:oldVC.asset];
    if (oldIdx + 1 < self.assetsLibraryService.assetURLs.count && oldIdx != NSNotFound) {
        NSURL *newURL = self.assetsLibraryService.assetURLs[oldIdx + 1];
        vc = [self photoViewControllerForAssetURL:newURL];
    }
    return vc;
}

#pragma mark - UIPageViewControllerDelegate

@end
