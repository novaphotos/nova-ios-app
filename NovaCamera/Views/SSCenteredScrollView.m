//
//  SSCenteredScrollView.m
//  NovaCamera
//
//  Created by Mike Matz on 1/14/14.
//  Copyright (c) 2014 Sneaky Squid. All rights reserved.
//

#import "SSCenteredScrollView.h"

@implementation SSCenteredScrollView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    UIView *contentView = [self.delegate viewForZoomingInScrollView:self];
    if (contentView) {
        CGRect contentFrame = contentView.frame;
        CGFloat svWidth = self.bounds.size.width;
        CGFloat svHeight = self.bounds.size.height;
        CGFloat contentWidth = contentFrame.size.width;
        CGFloat contentHeight = contentFrame.size.height;
        if (contentWidth < svWidth) {
            contentFrame.origin.x = (svWidth - contentWidth) / 2.0;
        } else {
            contentFrame.origin.x = 0;
        }
        if (contentHeight < svHeight) {
            contentFrame.origin.y = (svHeight - contentHeight) / 2.0;
        } else {
            contentFrame.origin.y = 0;
        }
        contentView.frame = contentFrame;
    }
}

@end
