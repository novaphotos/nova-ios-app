//
//  SSNovaFlashService.m
//  NovaCamera
//
//  Created by Mike Matz on 1/28/14.
//  Copyright (c) 2014 Sneaky Squid. All rights reserved.
//

#import "SSNovaFlashService.h"
#import "SSSettingsService.h"
#import <NovaSDK/NVFlashService.h>

static const NSString *SSNovaFlashServiceStatusChanged = @"SSNovaFlashServiceStatusChanged";

static const NSString *kLastFlashSettingsUserDefaultsPrefix = @"lastFlashSettings_";

@interface SSNovaFlashService () {
    BOOL _temporarilyEnabled;
}
+ (SSNovaFlashStatus)novaFlashStatusForNVFlashServiceStatus:(NVFlashServiceStatus)nvFlashServiceStatus;
+ (NVFlashSettings *)nvFlashSettingsForNovaFlashSettings:(SSFlashSettings)settings;
- (void)setupFlash;
- (void)teardownFlash;
- (void)saveToUserDefaults;
- (void)restoreFromUserDefaults;
@end

@implementation SSNovaFlashService

- (id)init {
    self = [super init];
    if (self) {
        _temporarilyEnabled = NO;
        _allowCustomFlashMode = NO;
        
        // Load previous values from NSUserDefaults
        [self restoreFromUserDefaults];
        
        [self setupFlash];
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

#pragma mark - Public methods

- (void)configureFlash {
    // Flash sync mode setting
    if (self.useMultipleNovas) {
        self.nvFlashService.autoPairMode = NVAutoPairAll;
    } else {
        self.nvFlashService.autoPairMode = NVAutoPairClosest;
    }
    
    if (self.flashSettings.flashMode == SSFlashModeOff) {
        [self disableFlash];
    } else {
        [self enableFlash];
    }
}

- (void)enableFlash {
    [self.nvFlashService enable];
}

- (void)enableFlashIfNeeded {
    if (self.flashSettings.flashMode != SSFlashModeOff
        && self.status == SSNovaFlashStatusDisabled) {
        [self enableFlash];
    }
}

- (void)disableFlash {
    [self.nvFlashService disable];
}

- (void)refreshFlash {
    [self.nvFlashService refresh];
}

- (void)temporaryEnableFlashIfDisabled {
    if (self.flashSettings.flashMode == SSFlashModeOff && !_temporarilyEnabled) {
        _temporarilyEnabled = YES;
        [self enableFlash];
    }
}

- (void)endTemporaryEnableFlash {
    if (self.flashSettings.flashMode == SSFlashModeOff && _temporarilyEnabled) {
        _temporarilyEnabled = NO;
        [self disableFlash];
    }
}

- (void)beginFlashWithSettings:(SSFlashSettings)flashSettings callback:(void (^)(BOOL status))callback {
    NVFlashSettings *nvFlashSettings = [[self class] nvFlashSettingsForNovaFlashSettings:flashSettings];
    DDLogVerbose(@"Calling nvFlashService beginFlash with settings %@", nvFlashSettings);
    [self.nvFlashService beginFlash:nvFlashSettings withCallback:^(BOOL status) {
        DDLogVerbose(@"NVFlashService beginFlash:withCallback: callback fired with status %d", status);
        if (callback) {
            dispatch_async(dispatch_get_main_queue(), ^{
                callback(status);
            });
        }
    }];
}

- (void)beginFlashWithCallback:(void (^)(BOOL))callback {
    return [self beginFlashWithSettings:self.flashSettings callback:callback];
}

- (void)endFlashWithCallback:(void (^)(BOOL status))callback {
    [self.nvFlashService endFlashWithCallback:^(BOOL status) {
        DDLogVerbose(@"NVFlashService endFlashWithCallback: callback fired with status %d", status);
        if (callback) {
            dispatch_async(dispatch_get_main_queue(), ^{
                callback(status);
            });
        }
    }];
}

#pragma - Properties

- (void)setFlashSettings:(SSFlashSettings)flashSettings {
    // Don't allow setting custom flash mode
    if (self.allowCustomFlashMode || (flashSettings.flashMode != SSFlashModeCustom)) {
        [self willChangeValueForKey:@"flashSettings"];
        _flashSettings = flashSettings;
        [self configureFlash];
        [self saveToUserDefaults];
        [self didChangeValueForKey:@"flashSettings"];
    }
}

- (void)setUseMultipleNovas:(BOOL)useMultipleNovas {
    [self willChangeValueForKey:@"useMultipleNovas"];
    _useMultipleNovas = useMultipleNovas;
    [self didChangeValueForKey:@"useMultipleNovas"];
    [self configureFlash];
}

#pragma mark - Private methods

+ (SSNovaFlashStatus)novaFlashStatusForNVFlashServiceStatus:(NVFlashServiceStatus)nvFlashServiceStatus {
    SSNovaFlashStatus status;
    switch (nvFlashServiceStatus) {
        case NVFlashServiceDisabled:
            status = SSNovaFlashStatusDisabled;
            break;
        case NVFlashServiceIdle:
            status = SSNovaFlashStatusUnknown;
            break;
        case NVFlashServiceConnecting:
            status = SSNovaFlashStatusSearching;
            break;
        case NVFlashServiceScanning:
            status = SSNovaFlashStatusSearching;
            break;
        case NVFlashServiceReady:
            status = SSNovaFlashStatusOK;
            break;
        default:
            status = SSNovaFlashStatusUnknown;
            break;
    }
    return status;
}

+ (NVFlashSettings *)nvFlashSettingsForNovaFlashSettings:(SSFlashSettings)settings {
    NVFlashSettings *nvFlashSettings;
    switch (settings.flashMode) {
        default:
            DDLogError(@"Unknown flash mode %d", settings.flashMode);
        case SSFlashModeOff:
            nvFlashSettings = [NVFlashSettings off];
            break;
        case SSFlashModeBright:
            nvFlashSettings = [NVFlashSettings bright];
            break;
        case SSFlashModeGentle:
            nvFlashSettings = [NVFlashSettings gentle];
            break;
        case SSFlashModeWarm:
            nvFlashSettings = [NVFlashSettings warm];
            break;
        case SSFlashModeCustom:
        {
            // Convert a "temperature" from 0 to 1.0 to individual warm and cool components
            double pctWarm = settings.flashColorTemperature;
            double pctCool = 1.0 - pctWarm;
            
            // Normalize such that MAX(pctWarm, pctCool) == 1.0
            if (pctWarm > 0.5) {
                pctWarm = 1.0;
                pctCool /= pctWarm;
            } else {
                pctCool = 1.0;
                pctWarm /= pctCool;
            }
            
            // Scale down according to brightness setting(
            pctWarm *= settings.flashBrightness;
            pctCool *= settings.flashBrightness;
            
            // Convert to 8bit
            uint8_t warm = (uint8_t)(pctWarm * 255.0);
            uint8_t cool = (uint8_t)(pctCool * 255.0);
            
            nvFlashSettings = [NVFlashSettings customWarm:warm cool:cool];
            break;
        }
    }
    return nvFlashSettings;
}

- (void)setupFlash {
    // Initialize NVFlashService
    self.nvFlashService = [NVFlashService new];
    [self.nvFlashService addObserver:self forKeyPath:@"status" options:0 context:nil];
    [self configureFlash];
}

- (void)teardownFlash {
    self.nvFlashService = nil;
}

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
    if (!self.allowCustomFlashMode && _flashSettings.flashMode == SSFlashModeCustom) {
        DDLogError(@"Setting flash mode to off because mode in user defaults was custom and we are disabling custom flash mode");
        _flashSettings.flashMode = SSFlashModeOff;
    }
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"status"]) {
        [self willChangeValueForKey:@"status"];
        _status = [[self class] novaFlashStatusForNVFlashServiceStatus:self.nvFlashService.status];
        DDLogVerbose(@"Nova flash status changed to %d", _status);
        [self didChangeValueForKey:@"status"];
    }
}

@end
