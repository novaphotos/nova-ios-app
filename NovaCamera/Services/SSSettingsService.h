//
//  SSSettingsService.h
//  NovaCamera
//
//  Created by Mike Matz on 1/29/14.
//  Copyright (c) 2014 Sneaky Squid. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * Simple class managing Nova settings
 */
@interface SSSettingsService : NSObject

+ (id)sharedService;
- (void)initializeUserDefaults;
- (NSArray *)generalSettingsKeys;
- (NSArray *)generalSettingsLocalizedTitles;
- (NSString *)localizedTitleForKey:(NSString *)key;
- (BOOL)boolForKey:(NSString *)key;
- (void)setBool:(BOOL)value forKey:(NSString *)key;

@end
