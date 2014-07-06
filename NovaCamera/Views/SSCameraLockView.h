//
// Created by Joe Walnes on 6/28/14.
// Copyright (c) 2014 Sneaky Squid. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * Shows the focus/exposure/whitebalance lock overlay
 */
@interface SSCameraLockView : UIControl

- (void)show:(CGPoint)point;

@property (nonatomic, assign) BOOL adjusting;

- (void)hide;

- (void)transformContents:(CGAffineTransform)transform;

@end

@interface SSCameraFocusLockView : SSCameraLockView
+ (id)view;
@end

@interface SSCameraExposureLockView : SSCameraLockView
+ (id)view;
@end
