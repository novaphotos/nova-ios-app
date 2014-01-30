//
//  SSNovaFlashService.m
//  NovaCamera
//
//  Created by Mike Matz on 1/28/14.
//  Copyright (c) 2014 Sneaky Squid. All rights reserved.
//

#import "SSNovaFlashService.h"

static const NSString *kLastFlashSettingsUserDefaultsPrefix = @"lastFlashSettings_";

@interface SSNovaFlashService ()
- (void)saveToUserDefaults;
- (void)restoreFromUserDefaults;
@end

@implementation SSNovaFlashService

- (id)init {
    self = [super init];
    if (self) {
        // Load previous values from NSUserDefaults
        [self restoreFromUserDefaults];
    }
    return self;
}

#pragma - Properties

- (void)setFlashSettings:(SSFlashSettings)flashSettings {
    _flashSettings = flashSettings;
    [self saveToUserDefaults];
}

#pragma mark - Private methods

- (void)saveToUserDefaults {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setInteger:self.flashSettings.flashMode forKey:[kLastFlashSettingsUserDefaultsPrefix stringByAppendingString:@"mode"]];
    [defaults setFloat:self.flashSettings.flashBrightness forKey:[kLastFlashSettingsUserDefaultsPrefix stringByAppendingString:@"brightness"]];
    [defaults setFloat:self.flashSettings.flashColorTemperature forKey:[kLastFlashSettingsUserDefaultsPrefix stringByAppendingString:@"colorTemperature"]];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        [defaults synchronize];
    });
    DDLogVerbose(@"Wrote flash settings to user defaults");
    DDLogVerbose(@"color temp: %g", _flashSettings.flashColorTemperature);
}

- (void)restoreFromUserDefaults {
    [self willChangeValueForKey:@"flashSettings"];
    _flashSettings = SSFlashSettingsWarm;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults objectForKey:[kLastFlashSettingsUserDefaultsPrefix stringByAppendingString:@"mode"]] != nil) {
        // Update flash settings from user defaults
        _flashSettings.flashMode = (SSFlashMode)[defaults integerForKey:[kLastFlashSettingsUserDefaultsPrefix stringByAppendingString:@"mode"]];
        _flashSettings.flashBrightness = [defaults floatForKey:[kLastFlashSettingsUserDefaultsPrefix stringByAppendingString:@"brightness"]];
        _flashSettings.flashColorTemperature = [defaults floatForKey:[kLastFlashSettingsUserDefaultsPrefix stringByAppendingString:@"colorTemperature"]];
        DDLogVerbose(@"Read flash settings from user defaults");
        DDLogVerbose(@"color temp: %g", _flashSettings.flashColorTemperature);
    }
}

@end
