//
//  SSSettingsCell.h
//  NovaCamera
//
//  Created by Mike Matz on 1/30/14.
//  Copyright (c) 2014 Sneaky Squid. All rights reserved.
//

#import <UIKit/UIKit.h>

@class SSSettingsService;

@interface SSSettingsCell : UITableViewCell

@property (nonatomic, strong) IBOutlet UILabel *titleLabel;
@property (nonatomic, strong) IBOutlet UISwitch *valueSwitch;
@property (nonatomic, strong) NSString *settingsKey;
@property (nonatomic, weak) SSSettingsService *settingsService;

@end
