//
//  SSPassThroughView.m
//  NovaCamera
//
//  Created by Mike Matz on 1/21/14.
//  Copyright (c) 2014 Sneaky Squid. All rights reserved.
//

#import "SSPassThroughView.h"

@implementation SSPassThroughView

-(BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    for (UIView *view in self.subviews) {
        if (!view.hidden && view.userInteractionEnabled && [view pointInside:[self convertPoint:point toView:view] withEvent:event])
            return YES;
    }
    return NO;
}

@end
