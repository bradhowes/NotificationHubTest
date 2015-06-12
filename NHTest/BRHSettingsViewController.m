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

/*!
 * @brief Implementation of IASKAbstractSettingsStore that works with our BRHUserSettings object.
 */
@interface SettingsStore : IASKAbstractSettingsStore

@property (strong, nonatomic) BRHUserSettings *settings;

@end

@implementation SettingsStore

/*!
 * @brief Initialize instance
 *
 * @return <#return value description#>
 */
- (instancetype)init {
    self = [super init];
    if (self) {
        _settings = [BRHUserSettings userSettings];
    }

    return self;
}

/*!
 * @brief Set a user setting
 *
 * @param value the value for the setting
 * @param key the name of the setting
 */
- (void)setObject:(id)value forKey:(NSString *)key {
    [_settings setValue:value forKey:key];
}

/*!
 * @brief Fetch a use setting
 *
 * @param key the name of the setting
 *
 * @return the setting value
 */
- (id)objectForKey:(NSString *)key {
    id obj = [_settings valueForKey:key];
    return obj;
}

/*!
 * @brief Save any changed configuration settings
 *
 * @return YES always
 */
- (BOOL)synchronize {
    [_settings writePreferences];
    return YES;
}

@end
@implementation BRHSettingsViewController

/*!
 * @brief Initialize insance from a given NSCoder
 *
 * We don't restore anything. Create everything from scratch.
 *
 * @param aDecoder the object to read from
 *
 * @return initiated instance
 */
- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    NSLog(@"BRHSettingsViewController initWithCoder");
    self = [super initWithCoder:aDecoder];
    if (self) {
        self.delegate = self;
        self.settingsStore = [SettingsStore new];
        self.showDoneButton = YES;
    }
    return self;
}

/*!
 * @brief Override of IASKAppSettingsViewController
 *
 * Necessary to invoke dismissViewController:completion:. Otherwise the view stays around.
 *
 * @param sender Done button
 */
- (IBAction)dismiss:(id)sender {

    // NOTE: order here is a bit magical. The key is to get the latest values into NSUserDefaults and then
    // flag the changes with KVO updates.
    //
    [self dismissViewControllerAnimated:YES completion:nil];

    // Save the settings and then invoke deleget method settingsViewControllerDidEnd
    //
    [super dismiss:sender];
}

/*!
 * @brief Delegate method called when user clicks on button in view.
 *
 * @note: For this to work on iPad devices, we need the view to have a lastButton attribute defined. This is a hack of the IASK source code.
 *
 * @param sender the view (us) -- sort of meaningless here
 * @param specifier definition of the setting values
 */
- (void)settingsViewController:(id)sender buttonTappedForSpecifier:(IASKSpecifier *)specifier {
    NSLog(@"buttonTappedForSpecifier - %@", specifier.key);
    if (![specifier.key isEqualToString:@"dropboxLinkButtonTextSetting"]) {
        return;
    }

    BRHUserSettings *settings = [BRHUserSettings userSettings];
    if (! settings.useDropbox) {
        settings.useDropbox = YES;
        [self.tableView reloadData];
        return;
    }

    NSString *title = @"Dropbox";
    NSString *msg = @"Are you sure you want to unlink from Dropbox? This will prevent the app from saving future recordings to your Drobox folder.";
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:msg preferredStyle:UIAlertControllerStyleActionSheet];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel"
                                                           style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction *action){
                                                         }];
    
    UIAlertAction *unlinkAction = [UIAlertAction actionWithTitle:@"Confirm"
                                                           style:UIAlertActionStyleDestructive
                                                         handler:^(UIAlertAction *action) {
                                                             settings.useDropbox = NO;
                                                             [self.tableView reloadData];
                                                         }];
    [alert addAction:cancelAction];
    [alert addAction:unlinkAction];
    
    UIPopoverPresentationController *popover = alert.popoverPresentationController;
    if (popover) {
        popover.sourceView = self.lastButton;
        popover.sourceRect = self.lastButton.bounds;
        popover.permittedArrowDirections = UIPopoverArrowDirectionAny;
    }
    
    [self presentViewController:alert animated:YES completion:nil];
}

/*!
 * @brief Delegate method called when the view is dismissed and the settings have been saved.
 *
 * @param sender the view that is no longer around
 */
- (void)settingsViewControllerDidEnd:(IASKAppSettingsViewController *)sender {
    [[BRHUserSettings userSettings] readPreferences];
}

@end
