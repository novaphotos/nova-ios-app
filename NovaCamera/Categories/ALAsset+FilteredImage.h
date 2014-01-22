//
//  ALAsset+FilteredImage.h
//  NovaCamera
//
//  Created by Mike Matz on 1/22/14.
//  Copyright (c) 2014 Sneaky Squid. All rights reserved.
//

#import <AssetsLibrary/AssetsLibrary.h>

@interface ALAsset (FilteredImage)

/**
 * Retrieve full resolution image and apply any filters.
 * Based on http://stackoverflow.com/a/19510626/72
 */
- (UIImage *)defaultRepresentationFullSizeFilteredImage;

@end
