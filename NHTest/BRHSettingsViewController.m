//
//  BRHSettingsViewController.m
//  NHTest
//
//  Created by Brad Howes on 4/12/14.
//  Copyright (c) 2014 Brad Howes. All rights reserved.
//

#import "BRHSettingsViewController.h"
#import "BRHAppDelegate.h"
#import "BRHNotificationDriver.h"
#import "BRHUserSettings.h"

@interface SettingsStore : IASKAbstractSettingsStore

@property (strong, nonatomic) BRHUserSettings *settings;

@end

@implementation SettingsStore

- (instancetype)init
{
    self = [super init];
    if (self) {
        _settings = [BRHUserSettings userSettings];
    }
    
    return self;
}

- (void)setObject:(id)value forKey:(NSString *)key
{
    [_settings setValue:value forKey:key];
}

- (id)objectForKey:(NSString *)key {
    id obj = [_settings valueForKey:key];
    return obj;
}

- (BOOL)synchronize {
    [_settings writePreferences];
    return YES;
}

@end
@implementation BRHSettingsViewController

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    NSLog(@"BRHSettingsViewController initWithCoder");
    self = [super initWithCoder:aDecoder];
    if (self) {
        self.delegate = self;
        self.settingsStore = [SettingsStore new];
    }
    return self;
}

- (void)viewWillAppear:(BOOL)animated
{
    BRHUserSettings *settings = [BRHUserSettings userSettings];
    //settings.blockingNotifications = YES;
    
    NSLog(@"dropboxLinkButtonTextSetting - %@", settings.dropboxLinkButtonTextSetting);
    NSLog(@"dropboxLinkButtonTextSetting - %@", [[NSUserDefaults standardUserDefaults] objectForKey:@"dropboxLinkButtonTextSetting"]);
    
    [super viewWillAppear:animated];
}

- (IBAction)dismiss:(id)sender {

    // NOTE: order here is a bit magical. The key is to get the latest values into NSUserDefaults and then
    // flag the changes with KVO updates.
    //
    [self dismissViewControllerAnimated:YES completion:nil];
    BRHUserSettings *settings = [BRHUserSettings userSettings];
    settings.blockingNotifications = NO;

    // This is supposed to update settings from InAppSettingsKit view
    //
    [super dismiss:sender];
    
    // But this seems to do the trick.
    //
    [settings readPreferences];
}

- (void)settingsViewController:(id)sender buttonTappedForSpecifier:(IASKSpecifier *)specifier
{
    NSLog(@"buttonTappedForSpecifier - %@", specifier.key);
    if ([specifier.key isEqualToString:@"dropboxLinkButtonTextSetting"]) {
        BRHUserSettings *settings = [BRHUserSettings userSettings];
        if (settings.useDropbox) {
            NSString *msg = @"Are you sure you want to unlink from Dropbox?";
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:msg message:nil preferredStyle:UIAlertControllerStyleActionSheet];
            
            UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
            }];
            
            UIAlertAction *unlinkAction = [UIAlertAction actionWithTitle:@"Unlink" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
                settings.useDropbox = NO;
                [self.tableView reloadData];
            }];
            [alert addAction:cancelAction];
            [alert addAction:unlinkAction];
            [self presentViewController:alert animated:YES completion:nil];
        }
        else {
            settings.useDropbox = YES;
            [self.tableView reloadData];
        }
    }
}

- (void)settingsViewController:(id<IASKViewController>)settingsViewController mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
    ;
}

- (void)settingsViewControllerDidEnd:(IASKAppSettingsViewController *)sender
{
    NSLog(@"settingsViewControllerDidEnd");
}

@end
