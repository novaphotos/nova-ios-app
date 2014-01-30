//
//  SSSettingsCell.m
//  NovaCamera
//
//  Created by Mike Matz on 1/30/14.
//  Copyright (c) 2014 Sneaky Squid. All rights reserved.
//

#import "SSSettingsCell.h"
#import "SSSettingsService.h"

@interface SSSettingsCell ()
- (IBAction)switchChangedValue:(id)sender;
@end

@implementation SSSettingsCell

- (void)dealloc {
    [self.valueSwitch removeTarget:self action:@selector(switchChangedValue:) forControlEvents:UIControlEventValueChanged];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if (self.settingsKey) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            BOOL on = [self.settingsService boolForKey:self.settingsKey];
            dispatch_async(dispatch_get_main_queue(), ^{
                self.valueSwitch.on = on;
            });
        });
    }
}

- (void)awakeFromNib {
    [self.valueSwitch addTarget:self action:@selector(switchChangedValue:) forControlEvents:UIControlEventValueChanged];
}

#pragma mark - Properties

- (SSSettingsService *)settingsService {
    if (!_settingsService) {
        _settingsService = [SSSettingsService sharedService];
    }
    return _settingsService;
}

#pragma mark - Private methods

- (IBAction)switchChangedValue:(id)sender {
    if (sender == self.valueSwitch) {
        [self.settingsService setBool:self.valueSwitch.on forKey:self.settingsKey];
    }
}

@end
