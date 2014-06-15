//
//  SSSettingsViewController.m
//  NovaCamera
//
//  Created by Mike Matz on 1/29/14.
//  Copyright (c) 2014 Sneaky Squid. All rights reserved.
//

#import "SSSettingsViewController.h"
#import "SSSettingsService.h"
#import "SSSettingsCell.h"
#import "SSTheme.h"

static const CGFloat kTableViewHeaderSpacing = 6;

@interface SSSettingsItem : NSObject
@property (nonatomic, strong) NSString *title;
@property (nonatomic, copy) void (^action)();
- (id)initWithTitle:(NSString *)title andAction:(void (^)(id sender))action;
@end

@implementation SSSettingsItem
- (id)initWithTitle:(NSString *)title andAction:(void (^)(id sender))action {
    self = [super init];
    if (self) {
        self.title = title;
        self.action = action;
    }
    return self;
}
@end

@implementation SSSettingsViewController

@synthesize settingsService=_settingsService;

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder: aDecoder];
    if (self) {
        
        // Ensures that "<" back button on the next screen does not show label.
        self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@""
                                                                                 style:self.navigationItem.backBarButtonItem.style
                                                                                target:nil
                                                                                action:nil];
        
        self.settingsItems = @[
                               [[SSSettingsItem alloc] initWithTitle: @"About Nova"
                                                           andAction: ^(id sender) {
                                                               [self navigateToUrl: @"https://wantnova.com/?utm_campaign=app&utm_medium=ios&utm_source=app"];
                                                           }],
                               [[SSSettingsItem alloc] initWithTitle: @"Help, support, feedback"
                                                           andAction: ^(id sender) {
                                                               [self navigateToUrl: @"https://wantnova.com/help/?utm_campaign=app&utm_medium=ios&utm_source=app"];
                                                           }],
                               [[SSSettingsItem alloc] initWithTitle: @"Privacy policy"
                                                           andAction: ^(id sender) {
                                                               [self performSegueWithIdentifier:@"showPrivacyPolicy" sender:nil];
                                                           }],
                               [[SSSettingsItem alloc] initWithTitle: @"Terms and conditions"
                                                           andAction: ^(id sender) {
                                                               [self navigateToUrl: @"https://wantnova.com/tos/?utm_campaign=app&utm_medium=ios&utm_source=app"];
                                                           }]
                               ];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
 
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

#pragma mark - Properties

- (SSSettingsService *)settingsService {
    if (!_settingsService) {
        _settingsService = [SSSettingsService sharedService];
    }
    return _settingsService;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [[self.settingsService generalSettingsLocalizedTitles] count] + [[self settingsItems] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    SSSettingsCell *cell;
    NSString *cellIdentifier;
    NSString *title;
    BOOL value = NO;
    NSString *key = nil;
    
    if (indexPath.row < [[self.settingsService generalSettingsLocalizedTitles] count]) {
        // Settings - switch
        cellIdentifier = @"SettingsSwitchCell";
        key = [[self.settingsService generalSettingsKeys] objectAtIndex:indexPath.row];
        title = [self.settingsService localizedTitleForKey:key];
        value = [self.settingsService boolForKey:key];
    } else {
        cellIdentifier = @"SettingsTextCell";
        SSSettingsItem *item = [[self settingsItems] objectAtIndex:(indexPath.row - [[self.settingsService generalSettingsLocalizedTitles] count])];
        
        title = item.title;
    }
    
    cell = (SSSettingsCell *)[tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) {
        cell = [[SSSettingsCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
    }
    
    cell.titleLabel.text = title;
//    cell.valueSwitch.on = value;
    cell.settingsKey = key;
    cell.settingsService = self.settingsService;
    
    return cell;
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row < [[self.settingsService generalSettingsLocalizedTitles] count]) {
        return nil;
    }
    return indexPath;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSAssert(indexPath.row >= [[self.settingsService generalSettingsLocalizedTitles] count], @"Should not select generalSettings");
    SSSettingsItem *item = [[self settingsItems] objectAtIndex:(indexPath.row - [[self.settingsService generalSettingsLocalizedTitles] count])];
    [item action](tableView);
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {

    // Fix fonts
    [[SSTheme currentTheme] updateFontsInView:cell includeSubviews:YES];
    
    // Fix switch corner radius
    SSSettingsCell *settingsCell = (SSSettingsCell *)cell;
    [[SSTheme currentTheme] styleSwitch:settingsCell.valueSwitch];
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    UIView *view = [[UIView alloc] init];
    view.backgroundColor = [UIColor clearColor];
    view.opaque = NO;
    return view;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return kTableViewHeaderSpacing;
}

#pragma mark - Settings actions

- (void)navigateToUrl:(NSString *)url {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
}
     
@end
