//
//  SSCaptureSessionManager.h
//  NovaCamera
//
//  Created by Mike Matz on 1/2/14.
//  Copyright (c) 2014 Sneaky Squid. All rights reserved.
//
//  Largely based on Apple's AVCam sample code

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

/**
 * `SSCaptureSessionManager` provides a simple interface to `AVCaptureSession` and related functionality.
 */
@interface SSCaptureSessionManager : NSObject

/**
 * Singleton accessor
 */
+ (id)sharedService;

/**
 * Flag determining whether light boost will be enabled in the dark
 */
@property (nonatomic, assign) BOOL lightBoostEnabled;

/**
 * Capture session, instantiated when SSCaptureSessionManager is instantiated
 */
@property (nonatomic, readonly) AVCaptureSession *session;

/**
 * Preview layer; can be manually added to a layer hierarchy
 */
@property (nonatomic, readonly) AVCaptureVideoPreviewLayer *previewLayer;

/**
 * Scale and crop factor
 * Sets videoScaleAndCropFactor on AVCaptureConnection
 */
@property (nonatomic, assign) CGFloat videoScaleAndCropFactor;

/**
 * Specify whether the device should autofocus and autoexpose when the device detects a subject area change (default YES)
 */
@property (nonatomic, assign) BOOL shouldAutoFocusAndAutoExposeOnDeviceAreaChange;

/**
 * Video gravity; default is `AVLayerVideoGravityResizeAspectFill`
 */
@property (nonatomic, copy) NSString *videoGravity;

/**
 * Has the device been authorized to capture live video & images?
 */
@property (nonatomic, assign, getter=isDeviceAuthorized) BOOL deviceAuthorized;

/**
 * Determine if video can be captured: the session must be running and the device must
 * be authorized to capture live video. Useful for key-value observation.
 */
@property (nonatomic, readonly, getter=isSessionRunningAndDeviceAuthorized) BOOL sessionRunningAndDeviceAuthorized;

/**
 * Boolean describing whether multiple cameras are available
 */
@property (nonatomic, readonly) BOOL canToggleCamera;

/**
 * Whether it's possible to acquire a focus lock on the current camera.
 */
@property (nonatomic, readonly) BOOL focusLockAvailable;

/**
* Whether the focus is currently locked on a position. If so, the coordinates are avalailable from focusLockPosition
*/
@property (nonatomic, readonly) BOOL focusLockActive;

/**
 * The current focus lock position (in device coordinates). Only valid if focusLockActive == YES
 */
@property (nonatomic, readonly) CGPoint focusLockDevicePoint;

/**
 * Whether the focus is currently working on adjusting itself
 */
@property (nonatomic, readonly) BOOL focusLockAdjusting;

/**
 * Whether it's possible to acquire a exposure lock on the current camera.
 */
@property (nonatomic, readonly) BOOL exposureLockAvailable;

/**
 * Whether the exposure is currently locked on a position. If so, the coordinates are available from exposureLockPosition
 */
@property (nonatomic, readonly) BOOL exposureLockActive;

/**
 * The current exposure lock position (in device coordinates). Only valid if exposureLockActive == YES
 */
@property (nonatomic, readonly) CGPoint exposureLockDevicePoint;

/**
 * Whether the exposure is currently adjusting itself.
 */
@property (nonatomic, readonly) BOOL exposureLockAdjusting;


///------------------------
/// @name Session lifecycle
///------------------------

/**
 * Start capture session. Call from -viewWillAppear or when the capture session should be initiated.
 */
- (void)startSession;

/**
 * End the capture session. Call from -viewDidDisappear or when the capture session is no longer needed.
 */
- (void)stopSession;

///--------------------
/// @name Authorization
///--------------------

/**
 * Check authorization for video capture Call this any time after the application starts. If authorization 
 * is not successful, the value of `granted` will be `NO`, at which time a message should be displayed
 * indicating that the user will need to adjust their settings to allow image capture.
 *
 * @param completion Block to execute upon completion; authorization status in `granted` param
 */
- (void)checkDeviceAuthorizationWithCompletion:(void (^)(BOOL granted))completion;

///-------------------------
/// @name Camera interaction
///-------------------------

/**
 * Focus at specified point
 */
- (void)focusOnDevicePoint:(CGPoint)devicePoint;

/**
 * Expose at specified point
 */
- (void)exposeOnDevicePoint:(CGPoint)devicePoint;

/**
 * Stop focusing on a specific point and return to continuous focus in the center.
 */
- (void)focusReset;

/**
 * Stop exposing on a specific point and return to continuous focus in the center.
 */
- (void)exposeReset;

/**
 * Toggle between front and back camera (if available).
 */
- (void)toggleCamera;

/**
 * Initiate image capture.
 *
 * @param completion Block to call after an image has been captured and includes the raw image
 * data as `NSData` as well as a JPEG `UIImage`. If `error` is non-nil, an error has occurred.
 *
 * @param shutter Block to call at the moment the actual image capture begins and can be used to fire a 
 * shutter animation.
 */
- (void)captureStillImageWithCompletionHandler:(void (^)(NSData *imageData, UIImage *image, NSError *error))completion shutterHandler:(void (^)(int shutterCurtain))shutter;

@end
