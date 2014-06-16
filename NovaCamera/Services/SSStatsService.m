//
//  SSAnalytics.m
//  NovaCamera
//
//  Created by Joe Walnes on 3/10/14.
//  Copyright (c) 2014 Sneaky Squid. All rights reserved.
//

#import "SSStatsService.h"
#import "SSSettingsService.h"
#import <Mixpanel/Mixpanel.h>

@implementation SSStatsService

+ (id)sharedService {
    static id _sharedService;
    static dispatch_once_t once;
    
    dispatch_once(&once, ^{
        _sharedService = [[self alloc] init];
        Mixpanel *mixpanel = [Mixpanel sharedInstanceWithToken:MIXPANEL_TOKEN];
        [mixpanel identify:mixpanel.distinctId];
        DDLogVerbose(@"Mixpanel distinctId: %@", mixpanel.distinctId);
    });
    
    return _sharedService;
}

- (void)report: (NSString *)eventName {
    if ([[SSSettingsService sharedService] boolForKey:kSettingsServiceOptOutStatsKey]) {
        return;
    }
    
    DDLogVerbose(@"Stat reported: %@", eventName);
    dispatch_async(dispatch_get_main_queue(), ^{
        Mixpanel *mixpanel = [Mixpanel sharedInstance];
        [mixpanel track:eventName];
        [mixpanel.people increment:eventName by:[NSNumber numberWithInt:1]];
    });
}

- (void)report: (NSString *)eventName properties:(NSDictionary *)properties {
    if ([[SSSettingsService sharedService] boolForKey:kSettingsServiceOptOutStatsKey]) {
        return;
    }
    
    DDLogVerbose(@"Stat reported: %@ %@", eventName, properties);
    dispatch_async(dispatch_get_main_queue(), ^{
        Mixpanel *mixpanel = [Mixpanel sharedInstance];
        [mixpanel track:eventName properties:properties];
        [mixpanel.people increment:eventName by:[NSNumber numberWithInt:1]];
    });
}

@end
