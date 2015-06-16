//
//  BRHSettingsStore.m
//  NHTest
//
//  Copyright (c) 2015 Brad Howes. All rights reserved.

#import "BRHAppDelegate.h"
#import "BRHMainViewController.h"
#import "BRHSettingsViewDelegate.h"
#import "BRHUserSettings.h"

@implementation BRHSettingsViewDelegate

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
        BRHAppDelegate *delegate = [UIApplication sharedApplication].delegate;
        [delegate enableDropbox:YES];
        return;
    }
    
    NSString *title = @"Dropbox";
    NSString *msg = @"Are you sure you want to unlink from Dropbox? This will prevent the app from saving future recordings to your Drobox folder.";
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:msg preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel"
                                                           style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction *action){
                                                         }];
    
    UIAlertAction *unlinkAction = [UIAlertAction actionWithTitle:@"Confirm"
                                                           style:UIAlertActionStyleDestructive
                                                         handler:^(UIAlertAction *action) {
                                                             BRHAppDelegate *delegate = [UIApplication sharedApplication].delegate;
                                                             [delegate enableDropbox:NO];
                                                         }];
    [alert addAction:cancelAction];
    [alert addAction:unlinkAction];
    
    [self.mainWindowController.presentedViewController presentViewController:alert animated:YES completion:^(){
        [self.settingsViewController.tableView reloadData];
    }];
}

/*!
 * @brief Delegate method called when the view is dismissed and the settings have been saved.
 *
 * @param sender the view that is no longer around
 */
- (void)settingsViewControllerDidEnd:(IASKAppSettingsViewController *)sender {
    NSLog(@"BRHSettingsViewController settingsViewControllerDidEnd:");
    [[BRHUserSettings userSettings] readPreferences];
    [self.mainWindowController dismissViewControllerAnimated:YES completion:nil];
}

@end
