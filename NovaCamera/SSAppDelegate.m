//
//  SSAppDelegate.m
//  NovaCamera
//
//  Created by Mike Matz on 12/20/13.
//  Copyright (c) 2013 Sneaky Squid. All rights reserved.
//

#import "SSAppDelegate.h"
#import "SSTheme.h"
#import "SSSettingsService.h"
#import "SSNovaFlashService.h"
#import "SSStatsService.h"
#import "SSCaptureSessionManager.h"
#import <CocoaLumberjack/DDTTYLogger.h>
#import <Crashlytics/Crashlytics.h>
#import <CrashlyticsLumberjack/CrashlyticsLogger.h>

static void * SettingsServiceUseMultipleNovasChangedContext = &SettingsServiceUseMultipleNovasChangedContext;
static void * SettingsServiceLightBoostChangedContext = &SettingsServiceLightBoostChangedContext;
static void * SettingsServiceResetFocusOnSceneChangeContext = &SettingsServiceResetFocusOnSceneChangeContext;

@implementation SSAppDelegate {
    SSSettingsService *_settingsService;
    SSCaptureSessionManager *_captureSessionManager;
    SSNovaFlashService *_flashService;
    SSStatsService *_statsService;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // CocoaLumberjack logging setup
    // Xcode console logging
    [DDLog addLogger:[DDTTYLogger sharedInstance]];

    // Setup general settings
    _settingsService = [SSSettingsService sharedService];
    [_settingsService initializeUserDefaults];

    // Setup camera capture
    _captureSessionManager = [SSCaptureSessionManager sharedService];
    _captureSessionManager.shouldAutoFocusAndAutoExposeOnDeviceAreaChange = [_settingsService boolForKey:kSettingsServiceResetFocusOnSceneChangeKey];

    // Setup theme
    [[SSTheme currentTheme] styleAppearanceProxies];

    // Subscribe to KVO notifications for multiple novas flag changes
    [_settingsService addObserver:self forKeyPath:kSettingsServiceMultipleNovasKey options:0 context:SettingsServiceUseMultipleNovasChangedContext];
    [_settingsService addObserver:self forKeyPath:kSettingsServiceLightBoostKey options:0 context:SettingsServiceLightBoostChangedContext];
    [_settingsService addObserver:self forKeyPath:kSettingsServiceResetFocusOnSceneChangeKey options:0 context:SettingsServiceResetFocusOnSceneChangeContext];

    // Setup flash service
    _flashService = [SSNovaFlashService sharedService];
    _flashService.useMultipleNovas = [_settingsService boolForKey:kSettingsServiceMultipleNovasKey];

    // Uncomment this in development to force one time question below to be asked every time.
    // [_settingsService clearKey:kSettingsServiceOneTimeAskedOptOutQuestion];   // DON'T CHECK IN WITH THIS LINE ENABLED!

    if (![_settingsService isKeySet:kSettingsServiceOneTimeAskedOptOutQuestion]) {
        // One time: Ask user stats opt-out question.
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Help improve Nova"
                                                        message:@"Would you like to help improve Nova by reporting anonymous statistics to us?"
                                                       delegate:self
                                              cancelButtonTitle:@"Sure - I'll help!"
                                              otherButtonTitles:@"Nope", nil];
        [alert show];
    }

    if (![_settingsService boolForKey:kSettingsServiceOptOutStatsKey]) {
        [self startAnonStatsCapture];
    }

    return YES;
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {

    BOOL optIn = (buttonIndex == 0);
    DDLogVerbose(optIn ? @"User opted IN to anon stats" : @"User opted OUT of anon stats");

    [_settingsService setBool:!optIn forKey:kSettingsServiceOptOutStatsKey];
    [_settingsService setBool:YES forKey:kSettingsServiceOneTimeAskedOptOutQuestion];

    if (optIn) {
        [self startAnonStatsCapture];
    }
}

- (void)startAnonStatsCapture {
    DDLogInfo(@"Enabled anonymous stats collection");

    // Anonymous stats service
    _statsService = [SSStatsService sharedService];

#ifdef CRASHLYTICS_API_KEY
    NSString *crashlyticsAPIKey = CRASHLYTICS_API_KEY;
#else
    NSString *crashlyticsAPIKey = nil;
#endif

    //bool optOutStats = [_settingsService boolForKey:kSettingsServiceOptOutStatsKey];
    
    if (crashlyticsAPIKey && crashlyticsAPIKey.length > 0) {
        // Log warnings to Crashlytics
        [DDLog addLogger:[CrashlyticsLogger sharedInstance] withLogLevel:LOG_LEVEL_WARN];

        // Crashlytics crash reporting service. This should be the last thing in this method.
        [Crashlytics startWithAPIKey:crashlyticsAPIKey];
    }
}
							
- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    
    // Turn off flash when going into background
    [_flashService disableFlash];
    [_statsService report:@"Application Leave"];
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    
    // Re-enable the flash if appropriate
    [_flashService enableFlashIfNeeded];
    [_statsService report:@"Application Enter"];
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    
    // Turn off flash when terminating
    [_flashService disableFlash];
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == SettingsServiceUseMultipleNovasChangedContext) {
        _flashService.useMultipleNovas = [_settingsService boolForKey:kSettingsServiceMultipleNovasKey];
    }
    if (context == SettingsServiceLightBoostChangedContext) {
        _captureSessionManager.lightBoostEnabled = [_settingsService boolForKey:kSettingsServiceLightBoostKey];
    }
    if (context == SettingsServiceResetFocusOnSceneChangeContext) {
        _captureSessionManager.shouldAutoFocusAndAutoExposeOnDeviceAreaChange = [_settingsService boolForKey:kSettingsServiceResetFocusOnSceneChangeKey];
    }
}

@end
