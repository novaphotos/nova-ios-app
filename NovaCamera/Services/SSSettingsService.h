//
//  SSSettingsService.h
//  NovaCamera
//
//  Created by Mike Matz on 1/29/14.
//  Copyright (c) 2014 Sneaky Squid. All rights reserved.
//

#import <Foundation/Foundation.h>


// General settings presented to user
extern NSString *kSettingsServicePreviewAfterCaptureKey;
extern NSString *kSettingsServiceEditAfterCaptureKey;
extern NSString *kSettingsServiceShareAfterCaptureKey;
extern NSString *kSettingsServiceShowGridLinesKey;
extern NSString *kSettingsServiceSquarePhotosKey;
extern NSString *kSettingsServiceMultipleNovasKey;
extern NSString *kSettingsServiceOptOutStatsKey;
extern NSString *kSettingsServiceEnableVolumeButtonTriggerKey;
extern NSString *kSettingsServiceLightBoostKey;

// Private settings that are never shown to user
extern NSString *kSettingsServiceOneTimeAskedOptOutQuestion;

/**
 * Simple class managing general Nova settings.
 */
@interface SSSettingsService : NSObject

/**
 * Singleton accessor
 */
+ (id)sharedService;

/**
 * Initialize NSUserDefaults with the default values for
 * supported settings, if they are not already set.
 * If this method is not called, all calls to boolForKey:
 * will return NO until another value is set.
 */
- (void)initializeUserDefaults;

/**
 * Retrieve sorted list of keys used for general settings presented to user
 */
- (NSArray *)generalSettingsKeys;

/**
 * Retrieve sorted list of localized titles used for general settings
 */
- (NSArray *)generalSettingsLocalizedTitles;

/**
 * Look up the localized title of the given key
 */
- (NSString *)localizedTitleForKey:(NSString *)key;

/**
 * Determine if given key has been set
 */
- (BOOL)isKeySet:(NSString *)key;

/**
 * Clear any previously set value for key
 */
- (void)clearKey:(NSString *)key;

/**
 * Retrieve the value of the given key
 */
- (BOOL)boolForKey:(NSString *)key;

/**
 * Set the value for the given key
 */
- (void)setBool:(BOOL)value forKey:(NSString *)key;

@end
