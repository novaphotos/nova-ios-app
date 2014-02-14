//
//  SSSettingsService.m
//  NovaCamera
//
//  Created by Mike Matz on 1/29/14.
//  Copyright (c) 2014 Sneaky Squid. All rights reserved.
//

#import "SSSettingsService.h"

const NSString *kSettingsServiceEditAfterCaptureKey = @"SettingsServiceEditAfterCaptureKey";
const NSString *kSettingsServiceShareAfterCaptureKey = @"SettingsServiceShareAfterCaptureKey";
const NSString *kSettingsServiceShowGridLinesKey = @"SettingsServiceShowGridLinesKey";
const NSString *kSettingsServiceSquarePhotosKey = @"SettingsServiceSquarePhotosKey";
const NSString *kSettingsServiceMultipleNovasKey = @"SettingsServiceMultipleNovasKey";

@implementation SSSettingsService

- (id)init {
    self = [super init];
    if (self) {
    }
    return self;
}

+ (id)sharedService {
    static id _sharedService;
    static dispatch_once_t once;
    
    dispatch_once(&once, ^{
        _sharedService = [[self alloc] init];
    });
    
    return _sharedService;
}

- (void)initializeUserDefaults {
    NSArray *defaults = @[
                          @NO,
                          @NO,
                          @NO,
                          @NO,
                          @NO,
                          ];
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSArray *keys = [self generalSettingsKeys];
    for (int idx = 0; idx < defaults.count; idx++) {
        NSString *key = keys[idx];
        if ([userDefaults objectForKey:key] == nil) {
            BOOL val = [defaults[idx] boolValue];
            DDLogVerbose(@"Setting NSUserDefaults key %@ to %d", key, val);
            [userDefaults setBool:val forKey:key];
        }
    }
    [userDefaults synchronize];
}

- (NSArray *)generalSettingsKeys {
    return @[
             kSettingsServiceEditAfterCaptureKey,
             kSettingsServiceShareAfterCaptureKey,
             kSettingsServiceShowGridLinesKey,
             kSettingsServiceSquarePhotosKey,
             kSettingsServiceMultipleNovasKey,
             ];
}

- (NSArray *)generalSettingsLocalizedTitles {
    return @[
             @"Ask to edit after taking",
             @"Ask to share after taking",
             @"Show grid lines",
             @"Square shaped photos",
             @"Use multiple Novas",
             ];
}

- (NSString *)localizedTitleForKey:(NSString *)key {
    NSUInteger idx = [[self generalSettingsKeys] indexOfObject:key];
    NSString *title = nil;
    if (NSNotFound != idx) {
        title = [[self generalSettingsLocalizedTitles] objectAtIndex:idx];
    }
    return title;
}

- (BOOL)boolForKey:(NSString *)key {
    return [[NSUserDefaults standardUserDefaults] boolForKey:key];
}

- (void)setBool:(BOOL)value forKey:(NSString *)key {
    [self willChangeValueForKey:key];
    [[NSUserDefaults standardUserDefaults] setBool:value forKey:key];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        [[NSUserDefaults standardUserDefaults] synchronize];
        [self didChangeValueForKey:key];
    });
}

@end
