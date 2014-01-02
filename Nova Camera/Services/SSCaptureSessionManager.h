//
//  SSCaptureSessionManager.h
//  Nova Camera
//
//  Created by Mike Matz on 1/2/14.
//  Copyright (c) 2014 Sneaky Squid. All rights reserved.
//
//  Largely based on Apple's AVCam sample code

#import <Foundation/Foundation.h>

@class AVCaptureSession;
@class AVCaptureVideoPreviewLayer;

@interface SSCaptureSessionManager : NSObject

@property (nonatomic, readonly) AVCaptureSession *session;
@property (nonatomic, readonly) AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic, copy) NSString *videoGravity;

@property (nonatomic, assign, getter=isDeviceAuthorized) BOOL deviceAuthorized;
@property (nonatomic, readonly, getter=isSessionRunningAndDeviceAuthorized) BOOL sessionRunningAndDeviceAuthorized;

@property (nonatomic, readonly) BOOL canToggleCamera;

- (void)startSession;
- (void)stopSession;
- (void)checkDeviceAuthorizationWithCompletion:(void (^)(BOOL isAuthorized))completion;
- (void)resetFocus;
- (void)resetExposure;
- (void)resetFlash;
- (void)toggleCamera;
- (void)captureStillImageWithCompletionHandler:(void (^)(NSData *imageData, UIImage *image, NSError *error))completion shutterHandler:(void (^)())shutter;

@end
