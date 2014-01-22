//
//  SSChronologicalAssetsLibraryService.h
//  NovaCamera
//
//  Created by Mike Matz on 1/22/14.
//  Copyright (c) 2014 Sneaky Squid. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AssetsLibrary/AssetsLibrary.h>

static const NSString *SSChronologicalAssetsLibraryUpdatedNotification;

@interface SSChronologicalAssetsLibraryService : NSObject

@property (nonatomic, readonly) ALAssetsLibrary *assetsLibrary;
@property (nonatomic, readonly) NSUInteger numberOfAssets;
@property (nonatomic, readonly) BOOL enumeratingAssets;

+ (id)sharedService;
- (void)enumerateAssetsWithCompletion:(void (^)(NSUInteger numberOfAssets))completion;
- (void)assetAtIndex:(NSUInteger)index withCompletion:(void (^)(ALAsset *))completion;
- (void)assetForURL:(NSURL *)assetURL withCompletion:(void (^)(ALAsset *))completion;
- (NSURL *)assetURLAtIndex:(NSUInteger)index;
- (NSUInteger)indexOfAsset:(ALAsset *)asset;
- (NSUInteger)indexOfAssetWithURL:(NSURL *)assetURL;

///----------------------
/// @name Image retrieval
///----------------------

/**
 * Retrieve screen-sized image for specified asset
 */
- (void)fullScreenImageForAsset:(ALAsset *)asset withCompletion:(void (^)(UIImage *image))completion;

/**
 * Retrieve screen-sized image given an asset URL
 */
- (void)fullScreenImageForAssetWithURL:(NSURL *)assetURL withCompletion:(void (^)(UIImage *image))completion;

/**
 * Retrieve full resolution image for specified asset
 */
- (void)fullResolutionImageForAsset:(ALAsset *)asset withCompletion:(void (^)(UIImage *image))completion;

/**
 * Retrieve full resolution image given an asset URL
 */
- (void)fullResolutionImageForAssetWithURL:(NSURL *)assetURL withCompletion:(void (^)(UIImage *image))completion;

@end
