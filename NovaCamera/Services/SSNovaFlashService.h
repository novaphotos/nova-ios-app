//
//  SSNovaFlashService.h
//  NovaCamera
//
//  Created by Mike Matz on 1/28/14.
//  Copyright (c) 2014 Sneaky Squid. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * Different modes of flash, including the three built-in modes, off and custom.
 */
typedef enum {
    SSFlashModeOff = 0,
    SSFlashModeGentle,
    SSFlashModeWarm,
    SSFlashModeBright,
    SSFlashModeCustom,
    SSFlashModeUnknown = -1,
} SSFlashMode;

/**
 * Struct combining all flash settings: mode, color temp and brightness.
 */
typedef struct {
    SSFlashMode flashMode;
    double flashColorTemperature;
    double flashBrightness;
} SSFlashSettings;

static const SSFlashSettings SSFlashSettingsGentle = { SSFlashModeGentle, 0.5, 0.25 };
static const SSFlashSettings SSFlashSettingsWarm = { SSFlashModeWarm, 1.0, 0.75 };
static const SSFlashSettings SSFlashSettingsBright = { SSFlashModeBright, 0.5, 1.0 };
static const SSFlashSettings SSFlashSettingsCustomDefault = { SSFlashModeCustom, 0.5, 0.5 };

@interface SSNovaFlashService : NSObject

@property (nonatomic, assign) SSFlashSettings flashSettings;

@end
