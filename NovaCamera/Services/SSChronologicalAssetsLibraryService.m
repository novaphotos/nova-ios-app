//
//  SSChronologicalAssetsLibraryService.m
//  NovaCamera
//
//  Created by Mike Matz on 1/22/14.
//  Copyright (c) 2014 Sneaky Squid. All rights reserved.
//

#import "SSChronologicalAssetsLibraryService.h"
#import "ALAsset+FilteredImage.h"

NSString * const SSChronologicalAssetsLibraryUpdatedNotification = @"SSChronologicalAssetsLibraryUpdatedNotification";
NSString * const SSChronologicalAssetsLibraryInsertedAssetIndexesKey = @"SSChronologicalAssetsLibraryInsertedAssetIndexesKey";
NSString * const SSChronologicalAssetsLibraryDeletedAssetIndexesKey = @"SSChronologicalAssetsLibraryDeletedAssetIndexesKey";

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

@interface SSChronologicalAssetsLibraryService ()
@property (nonatomic, strong) NSMutableArray *assetURLs;
- (void)assetsChangedWithNotification:(NSNotification *)notification;
@end

@implementation SSChronologicalAssetsLibraryService

@synthesize assetsLibrary=_assetsLibrary;
@synthesize enumeratingAssets=_enumeratingAssets;

- (id)init {
    self = [super init];
    if (self) {
        _assetsLibrary = [[ALAssetsLibrary alloc] init];
        self.assetURLs = [NSMutableArray array];
        //self.fullResolutionImagesByURL = [NSMutableDictionary dictionary];
        
        // Observe changes to assets library
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(assetsChangedWithNotification:) name:ALAssetsLibraryChangedNotification object:_assetsLibrary];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:ALAssetsLibraryChangedNotification object:_assetsLibrary];
}

+ (id)sharedService {
    static id _sharedService;
    static dispatch_once_t once;
    
    dispatch_once(&once, ^{
        _sharedService = [[self alloc] init];
    });
    
    return _sharedService;
}

#pragma mark - Public methods

- (void)enumerateAssetsWithGroupTypes:(ALAssetsGroupType)types completion:(void (^)(NSUInteger numberOfAssets))completion {
    __block typeof(self) bSelf = self;
    __block NSMutableArray *mutableURLs = [NSMutableArray array];
    __block typeof(completion) bCompletion = completion;
    _enumeratingAssets = YES;
    
    void (^finishedEnumerating)() = ^{
        DDLogVerbose(@"finishedEnumerating");
        bSelf.assetURLs = mutableURLs;
        bSelf->_enumeratingAssets = NO;
        if (bCompletion) {
            bCompletion(mutableURLs.count);
        }
    };
    
    DDLogVerbose(@"Starting enumeration");
    
    [self.assetsLibrary enumerateGroupsWithTypes:types usingBlock:^(ALAssetsGroup *group, BOOL *groupStop) {
        DDLogVerbose(@"Enumerating group");
        if (group) {
            [group enumerateAssetsWithOptions:NSEnumerationReverse usingBlock:^(ALAsset *result, NSUInteger index, BOOL *stop) {
                DDLogVerbose(@"Enumerating item");
                if (result) {
                    NSURL *url = result.defaultURL;
                    [mutableURLs addObject:url];
                }
            }];
        } else {
            finishedEnumerating();
        }
    } failureBlock:^(NSError *error) {
        if (completion) {
            completion(0);
        }
    }];
}

- (void)enumerateAssetsWithCompletion:(void (^)(NSUInteger numberOfAssets))completion {
    [self enumerateAssetsWithGroupTypes:ALAssetsGroupAll completion:completion];
}

- (void)assetAtIndex:(NSUInteger)index withCompletion:(void (^)(ALAsset *))completion {
    NSURL *assetURL = self.assetURLs[index];
    [self assetForURL:assetURL withCompletion:completion];
}

- (void)assetForURL:(NSURL *)assetURL withCompletion:(void (^)(ALAsset *))completion {
    [self.assetsLibrary assetForURL:assetURL resultBlock:^(ALAsset *asset) {
        if (completion) {
            completion(asset);
        }
    } failureBlock:^(NSError *error) {
        DDLogError(@"Error loading asset with URL %@: %@", assetURL, error);
        if (completion) {
            completion(nil);
        }
    }];
}

- (NSURL *)assetURLAtIndex:(NSUInteger)index {
    return self.assetURLs[index];
}

- (NSUInteger)indexOfAsset:(ALAsset *)asset {
    return [self indexOfAssetWithURL:asset.defaultURL];
}

- (NSUInteger)indexOfAssetWithURL:(NSURL *)assetURL {
    return [self.assetURLs indexOfObject:assetURL];
}

- (void)fullScreenImageForAsset:(ALAsset *)asset withCompletion:(void (^)(UIImage *image))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        UIImage *image = [UIImage imageWithCGImage:asset.defaultRepresentation.fullScreenImage];
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(image);
            });
        }
    });
}

- (void)fullScreenImageForAssetWithURL:(NSURL *)assetURL withCompletion:(void (^)(UIImage *image))completion {
    [self assetForURL:assetURL withCompletion:^(ALAsset *asset) {
        [self fullScreenImageForAsset:asset withCompletion:completion];
    }];
}

- (void)fullResolutionImageForAsset:(ALAsset *)asset withCompletion:(void (^)(UIImage *))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        UIImage *image = [asset defaultRepresentationFullSizeFilteredImage];
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(image);
            });
        }
    });
}

- (void)fullResolutionImageForAssetWithURL:(NSURL *)assetURL withCompletion:(void (^)(UIImage *))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        // Look up ALAsset, then call our -fullResolutionImageForAsset:withCompletion: method
        // to retrieve and cache the full resolution image
        [self.assetsLibrary assetForURL:assetURL resultBlock:^(ALAsset *asset) {
            [self fullResolutionImageForAsset:asset withCompletion:completion];
        } failureBlock:^(NSError *error) {
            DDLogError(@"Unable to retrieve asset for URL: %@", assetURL);
            if (completion) {
                completion(nil);
            }
        }];
    });
}

#pragma mark - Properties

- (NSUInteger)numberOfAssets {
    return self.assetURLs.count;
}

#pragma mark - Private methods

- (void)assetsChangedWithNotification:(NSNotification *)notification {
    DDLogVerbose(@"Assets changed! Notification: %@", notification);
    
    if (_enumeratingAssets) {
        DDLogVerbose(@"Already enumerating; skipping");
        return;
    }
    
    NSDictionary *userInfo = notification.userInfo;
    NSSet *updatedAssets = userInfo[ALAssetLibraryUpdatedAssetsKey];
    if (!updatedAssets.count) {
        DDLogVerbose(@"No updated assets; skipping");
        return;
    }
    
    __block typeof(self) bSelf = self;
    __block NSArray *previousAssetURLs = [NSArray arrayWithArray:self.assetURLs];
    [self enumerateAssetsWithCompletion:^(NSUInteger numberOfAssets) {
        DDLogVerbose(@"Enumeration finished (triggered by assets changed notification)");
        
        // Compare old and new asset URLs; track which indexes have been added and removed
        NSMutableSet *oldAssetURLs = [NSMutableSet setWithArray:previousAssetURLs];
        NSMutableSet *newAssetURLs = [NSMutableSet set];
        for (NSURL *url in self.assetURLs) {
            if ([oldAssetURLs containsObject:url]) {
                [oldAssetURLs removeObject:url];
            } else {
                [newAssetURLs addObject:url];
            }
        }
        
        NSMutableIndexSet *addedAssetIndexes = [NSMutableIndexSet indexSet];
        for (NSURL *addedURL in newAssetURLs) {
            [addedAssetIndexes addIndex:[bSelf.assetURLs indexOfObject:addedURL]];
        }
        
        NSMutableIndexSet *removedAssetIndexes = [NSMutableIndexSet indexSet];
        for (NSURL *removedURL in oldAssetURLs) {
            [removedAssetIndexes addIndex:[previousAssetURLs indexOfObject:removedURL]];
        }
        
        NSDictionary *userInfo = @{
                                   SSChronologicalAssetsLibraryInsertedAssetIndexesKey: addedAssetIndexes,
                                   SSChronologicalAssetsLibraryDeletedAssetIndexesKey: removedAssetIndexes,
                                   };
        [[NSNotificationCenter defaultCenter] postNotificationName:SSChronologicalAssetsLibraryUpdatedNotification object:self userInfo:userInfo];
    }];
}

@end
