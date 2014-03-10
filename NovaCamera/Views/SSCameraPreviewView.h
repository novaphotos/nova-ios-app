//
//  SSCameraPreviewView.h
//  NovaCamera
//
//  Created by Mike Matz on 12/20/13.
//  Copyright (c) 2013 Sneaky Squid. All rights reserved.
//
//  Largely based on Apple's AVCam sample code

#import <UIKit/UIKit.h>

@class AVCaptureSession;

@interface SSCameraPreviewView : UIView

@property (nonatomic, strong) AVCaptureSession *session;

@end
