//
//  SSCameraPreviewView.m
//  Nova Camera
//
//  Created by Mike Matz on 12/20/13.
//  Copyright (c) 2013 Sneaky Squid. All rights reserved.
//
//  Largely based on Apple's AVCam sample code


#import "SSCameraPreviewView.h"
#import <AVFoundation/AVFoundation.h>

@implementation SSCameraPreviewView

+ (Class)layerClass {
    return [AVCaptureVideoPreviewLayer class];
}

- (AVCaptureSession *)session {
    AVCaptureVideoPreviewLayer *layer = (AVCaptureVideoPreviewLayer *)self.layer;
    return layer.session;
}

- (void)setSession:(AVCaptureSession *)session {
    AVCaptureVideoPreviewLayer *layer = (AVCaptureVideoPreviewLayer *)self.layer;
    layer.session = session;
    layer.videoGravity = AVLayerVideoGravityResizeAspectFill;
}

@end
