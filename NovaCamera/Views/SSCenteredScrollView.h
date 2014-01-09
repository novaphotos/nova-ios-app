//
//  SSCenteredScrollView.h
//  NovaCamera
//
//  Created by Mike Matz on 1/14/14.
//  Copyright (c) 2014 Sneaky Squid. All rights reserved.
//

#import <UIKit/UIKit.h>

/**
 * UIScrollView subclass that ensures its content view remains centered
 * when zoomed out sufficiently that there are margins between the
 * content frame and the scroll view bounds.
 *
 * Technique adopted from Matt Neuburg's "Programming iOS 7"
 */
@interface SSCenteredScrollView : UIScrollView

@end
