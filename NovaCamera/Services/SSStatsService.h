//
//  SSAnalytics.h
//  NovaCamera
//
//  Created by Joe Walnes on 3/10/14.
//  Copyright (c) 2014 Sneaky Squid. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * Records anonymous usage stats to help improve the app.
 */
@interface SSStatsService : NSObject

/**
 * Singleton accessor
 */
+ (id)sharedService;

/**
 * Report an event to server.
 */
- (void)report: (NSString *)eventName;

/**
 * Report an event to server with additional NSString->NSString k/v properties.
 */
- (void)report: (NSString *)eventName properties:(NSDictionary *)properties;

@end

