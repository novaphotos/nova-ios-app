//
//  ALAsset+FilteredImage.m
//  NovaCamera
//
//  Created by Mike Matz on 1/22/14.
//  Copyright (c) 2014 Sneaky Squid. All rights reserved.
//

#import "ALAsset+FilteredImage.h"

@implementation ALAsset (FilteredImage)

- (UIImage *)defaultRepresentationFullSizeFilteredImage {
    ALAssetRepresentation *assetRepresentation = [self defaultRepresentation];
    CGImageRef fullResImage = [assetRepresentation fullResolutionImage];
    NSString *adjustment = [[assetRepresentation metadata] objectForKey:@"AdjustmentXMP"];
    if (adjustment) {
        NSData *xmpData = [adjustment dataUsingEncoding:NSUTF8StringEncoding];
        CIImage *image = [CIImage imageWithCGImage:fullResImage];
        
        NSError *error = nil;
        NSArray *filterArray = [CIFilter filterArrayFromSerializedXMP:xmpData
                                                     inputImageExtent:image.extent
                                                                error:&error];
        CIContext *context = [CIContext contextWithOptions:nil];
        if (filterArray && !error) {
            for (CIFilter *filter in filterArray) {
                [filter setValue:image forKey:kCIInputImageKey];
                image = [filter outputImage];
            }
            fullResImage = [context createCGImage:image fromRect:[image extent]];
        }
    }
    UIImage *result = [UIImage imageWithCGImage:fullResImage scale:[assetRepresentation scale] orientation:(UIImageOrientation)[assetRepresentation orientation]];
    return result;
}

@end
