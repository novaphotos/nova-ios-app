//
//  SSSettingsViewController.h
//  NovaCamera
//
//  Created by Mike Matz on 1/29/14.
//  Copyright (c) 2014 Sneaky Squid. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MessageUI/MFMailComposeViewController.h>

@class SSSettingsService;
@class SSStatsService;

/**
 * Simple UITableViewController subclass that displays settings as
 * defined in SSSettingsService
 */
@interface SSSettingsViewController : UITableViewController <MFMailComposeViewControllerDelegate>

@property (nonatomic, strong) SSSettingsService *settingsService;
@property (nonatomic, copy) NSArray *settingsItems;
@property (nonatomic, strong) SSStatsService *statsService;

@end
