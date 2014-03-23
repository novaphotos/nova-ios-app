//
//  SSChronologicalAssetsLibraryService.h
//  NovaCamera
//
//  Created by Mike Matz on 1/22/14.
//  Copyright (c) 2014 Sneaky Squid. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AssetsLibrary/AssetsLibrary.h>

NSString * const SSChronologicalAssetsLibraryUpdatedNotification;
NSString * const SSChronologicalAssetsLibraryInsertedAssetIndexesKey;
NSString * const SSChronologicalAssetsLibraryDeletedAssetIndexesKey;

/**
 * Abstraction layer on ALAssetesLibraryService, providing simplified access to
 * all available assets on device in chronological order. Responds to
 * ALAssetsLibrary notifications, updates its own contents, and sends its own
 * notifications containing a list of affected asset indexes.
 */
@interface SSChronologicalAssetsLibraryService : NSObject

/**
 * Underlying ALAssetsLibrary object
 */
@property (nonatomic, readonly) ALAssetsLibrary *assetsLibrary;

/**
 * Total number of assets available
 */
@property (nonatomic, readonly) NSUInteger numberOfAssets;

/**
 * Flag set to YES when assets are being enumerated
 */
@property (nonatomic, readonly) BOOL enumeratingAssets;

/**
 * Singleton accessor
 */
+ (id)sharedService;

/**
 * Trigger enumeration of assets. Completion called with the total number of assets found.
 */
- (void)enumerateAssetsWithCompletion:(void (^)(NSUInteger numberOfAssets))completion;

/**
 * Retrieve asset at specified index using callback
 */
- (void)assetAtIndex:(NSUInteger)index withCompletion:(void (^)(ALAsset *))completion;

/**
 * Retrieve asset with specified URL, using callback
 */
- (void)assetForURL:(NSURL *)assetURL withCompletion:(void (^)(ALAsset *))completion;

/**
 * Retrieve asset URL at specified index (synchronous)
 */
- (NSURL *)assetURLAtIndex:(NSUInteger)index;

/**
 * Find index of specified asset. Returns NSNotFound if the asset does not exist.
 */
- (NSUInteger)indexOfAsset:(ALAsset *)asset;

/**
 * Find index of specified asset URL. Returns NSNOtFound if the asset URL does not exist.
 */
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
