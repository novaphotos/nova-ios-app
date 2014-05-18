//
//  SSCameraPreviewView.m
//  NovaCamera
//
//  Created by Mike Matz on 12/20/13.
//  Copyright (c) 2013 Sneaky Squid. All rights reserved.
//
//  Largely based on Apple's AVCam sample code


#import "SSCameraPreviewView.h"
#import <AVFoundation/AVFoundation.h>

@interface SSCameraPreviewView ()
- (void)commonInit;
- (void)didRotate:(NSNotification *)notification;
@end

@implementation SSCameraPreviewView

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (id)init {
    self = [super init];
    if (self) {
        [self commonInit];
    }
    return self;
}

+ (Class)layerClass {
    return [AVCaptureVideoPreviewLayer class];
}

// Don't use autolayout
- (BOOL)translatesAutoresizingMaskIntoConstraints {
    return YES;
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

#pragma mark - Private methods

- (void)commonInit {
    // Listen to device orientation notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didRotate:) name:UIDeviceOrientationDidChangeNotification object:nil];
}

- (void)didRotate:(NSNotification *)notification {
    DDLogVerbose(@"SSCameraPreviewView didRotate:%@", notification);
    UIDeviceOrientation orientation = [[UIDevice currentDevice] orientation];
    if (UIDeviceOrientationIsPortrait(orientation) || UIDeviceOrientationIsLandscape(orientation)) {
        AVCaptureVideoPreviewLayer *previewLayer = (AVCaptureVideoPreviewLayer *)self.layer;
        AVCaptureConnection *connection = previewLayer.connection;
        connection.videoOrientation = (AVCaptureVideoOrientation)orientation;
    }
}

@end
