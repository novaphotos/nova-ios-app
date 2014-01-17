//
//  SSAssetsLibraryService.m
//  NovaCamera
//
//  Created by Mike Matz on 1/15/14.
//  Copyright (c) 2014 Sneaky Squid. All rights reserved.
//

#import "SSAssetsLibraryService.h"
#import <AssetsLibrary/AssetsLibrary.h>

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

@interface SSAssetsLibraryService () {
    BOOL _finishedEnumeration;
}
@end

@implementation SSAssetsLibraryService

@synthesize assetsLibrary=_assetsLibrary;
@synthesize assetURLs=_assetURLs;

- (id)init {
    self = [super init];
    if (self) {
        _assetsLibrary = [[ALAssetsLibrary alloc] init];
    }
    return self;
}

- (NSUInteger)indexOfAsset:(ALAsset *)asset {
    return [self.assetURLs indexOfObject:asset.defaultURL];
}

- (void)removeAssetURLAtIndex:(NSUInteger)index {
    NSMutableArray *mutableURLs = [self.assetURLs mutableCopy];
    [mutableURLs removeObjectAtIndex:index];
    [self willChangeValueForKey:@"assetURLs"];
    _assetURLs = [NSArray arrayWithArray:mutableURLs];
    [self didChangeValueForKey:@"assetURLs"];
}

- (void)addAssetURL:(NSURL *)assetURL {
    NSMutableArray *mutableURLs = [self.assetURLs mutableCopy];
    [mutableURLs addObject:assetURL];
    [self willChangeValueForKey:@"assetURLs"];
    _assetURLs = [NSArray arrayWithArray:mutableURLs];
    [self didChangeValueForKey:@"assetURLs"];
}

- (void)enumerateAllAssetsWithCompletion:(void (^)(NSArray *assetURLs, NSError *error))completion {
    _finishedEnumeration = NO;
    __block typeof(self) bSelf = self;
    __block NSMutableArray *mutableURLs = [NSMutableArray array];
    __block typeof(completion) bCompletion = completion;
    
    void (^finishedEnumerating)() = ^{
        [bSelf willChangeValueForKey:@"assetURLs"];
        if (mutableURLs.count) {
            bSelf->_assetURLs = [NSArray arrayWithArray:mutableURLs];
        } else {
            bSelf->_assetURLs = nil;
        }
        [bSelf didChangeValueForKey:@"assetURLs"];
        bSelf->_finishedEnumeration = YES;
        if (bCompletion) {
            bCompletion(bSelf->_assetURLs, nil);
        }
    };
    
    [self.assetsLibrary enumerateGroupsWithTypes:ALAssetsGroupAll usingBlock:^(ALAssetsGroup *group, BOOL *groupStop) {
        if (group) {
            [group enumerateAssetsWithOptions:NSEnumerationReverse usingBlock:^(ALAsset *result, NSUInteger index, BOOL *stop) {
                if (result) {
                    NSURL *url = result.defaultURL;
                    [mutableURLs addObject:url];
                }
                if (*stop && *groupStop) {
                    finishedEnumerating();
                }
            }];
        } else if (*groupStop) {
            // No results?
            finishedEnumerating();
        }
    } failureBlock:^(NSError *error) {
        if (completion) {
            completion(nil, error);
        }
    }];
}

- (void)assetForURL:(NSURL *)assetURL resultBlock:(void (^)(ALAsset *asset))result failureBlock:(void (^)(NSError *error))failure {
    [self.assetsLibrary assetForURL:assetURL resultBlock:result failureBlock:failure];
}

@end
