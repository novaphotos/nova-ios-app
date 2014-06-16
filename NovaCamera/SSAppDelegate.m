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
#import <CocoaLumberjack/DDTTYLogger.h>
#import <Crashlytics/Crashlytics.h>
#import <CrashlyticsLumberjack/CrashlyticsLogger.h>

@implementation SSAppDelegate {
    SSSettingsService *_settingsService;
    SSNovaFlashService *_flashService;
    SSStatsService *_statsService;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    
#ifdef CRASHLYTICS_API_KEY
    NSString *crashlyticsAPIKey = CRASHLYTICS_API_KEY;
#else
    NSString *crashlyticsAPIKey = nil;
#endif
    
    // CocoaLumberjack logging setup
    // Xcode console logging
    [DDLog addLogger:[DDTTYLogger sharedInstance]];
    
    bool optOutStats = [[SSSettingsService sharedService] boolForKey:kSettingsServiceOptOutStatsKey];
    
    if (!optOutStats && crashlyticsAPIKey && crashlyticsAPIKey.length > 0) {
        // Log warnings to Crashlytics
        [DDLog addLogger:[CrashlyticsLogger sharedInstance] withLogLevel:LOG_LEVEL_WARN];
    }
    
    // Setup theme
    [[SSTheme currentTheme] styleAppearanceProxies];
    
    // Setup general settings
    _settingsService = [SSSettingsService sharedService];
    [_settingsService initializeUserDefaults];
    // Subscribe to KVO notifications for multiple novas flag changes
    [_settingsService addObserver:self forKeyPath:kSettingsServiceMultipleNovasKey options:0 context:nil];
    
    // Setup flash service
    _flashService = [SSNovaFlashService sharedService];
    _flashService.useMultipleNovas = [_settingsService boolForKey:kSettingsServiceMultipleNovasKey];

    // Anonymous stats service
    _statsService = [SSStatsService sharedService];

    if (!optOutStats && crashlyticsAPIKey && crashlyticsAPIKey.length > 0) {
        // Crashlytics crash reporting service. This should be the last thing in this method.
        [Crashlytics startWithAPIKey:crashlyticsAPIKey];
    }
    
    return YES;
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
    if (object == _settingsService && [keyPath isEqualToString:kSettingsServiceMultipleNovasKey]) {
        DDLogVerbose(@"App delegate forwarding useMultipleNovas setting from settings to flash service");
        _flashService.useMultipleNovas = [_settingsService boolForKey:kSettingsServiceMultipleNovasKey];
    }
}

@end
