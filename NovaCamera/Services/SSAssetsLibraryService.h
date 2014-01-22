//
//  SSAssetsLibraryService.h
//  NovaCamera
//
//  Created by Mike Matz on 1/15/14.
//  Copyright (c) 2014 Sneaky Squid. All rights reserved.
//

#import <Foundation/Foundation.h>

@class ALAsset;
@class ALAssetsLibrary;


@interface SSAssetsLibraryService : NSObject

@property (nonatomic, readonly) NSArray *assetURLs;
@property (nonatomic, readonly) ALAssetsLibrary *assetsLibrary;

- (NSUInteger)indexOfAsset:(ALAsset *)asset;
- (NSUInteger)indexOfAssetWithURL:(NSURL *)assetURL;
- (void)removeAssetURLAtIndex:(NSUInteger)index;
- (void)insertAssetURL:(NSURL *)assetURL;
- (void)enumerateAllAssetsWithCompletion:(void (^)(NSArray *assetURLs, NSError *error))completion;
- (void)assetForURL:(NSURL *)assetURL resultBlock:(void (^)(ALAsset *asset))result failureBlock:(void (^)(NSError *error))failure;

@end
