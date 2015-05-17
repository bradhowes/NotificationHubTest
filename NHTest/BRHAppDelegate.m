//
//  BRHAppDelegate.m
//  HelloWorld
//
//  Created by Brad Howes on 12/21/13.
//  Copyright (c) 2013 Brad Howes. All rights reserved.
//


#import "DDFileLogger.h"
#import "DDTTYLogger.h"
#import "Reachability.h"

#import "BRHAppDelegate.h"
#import "BRHLogger.h"
#import "BRHMainViewController.h"
#import "BRHNotificationDriver.h"
#import "BRHRemoteDriver.h"

@interface BRHAppDelegate ()

@end

@implementation BRHAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [application setStatusBarStyle:UIStatusBarStyleLightContent];
    [application setMinimumBackgroundFetchInterval:UIApplicationBackgroundFetchIntervalMinimum];

    [DDLog addLogger:[DDTTYLogger sharedInstance]];
    DDFileLogger* fileLogger = [[DDFileLogger alloc] init];
    [DDLog addLogger:fileLogger];
    DDLogDebug(@"launchOptions: %@", [launchOptions description]);

    if (application.applicationState != UIApplicationStateBackground) {
        [[NSUserDefaults standardUserDefaults] registerDefaults:@{@"prodCertFileName":@"apn-nhtest-prod.p12",
                                                                  @"prodCertPassword":@"",
                                                                  @"sandboxCertFileName":@"apn-nhtest-dev.p12",
                                                                  @"sandboxCertPassword":@"",
                                                                  @"useSandbox":@"1",
                                                                  @"emitInterval":@"15",
                                                                  @"maxBin":@"30",
                                                                  @"useRemoteServer":@"0",
                                                                  @"remoteServerName":@"emitter-bradhowes.c9.io",
                                                                  @"remoteServerPort":@"80",
                                                                  @"sim":@"0"
                                                                  }];
    }

    self.notificationDriver = [[BRHNotificationDriver alloc] init];

    UIUserNotificationSettings* settings = [UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeBadge|UIUserNotificationTypeSound|UIUserNotificationTypeAlert
                                                                             categories:nil];
    [application registerUserNotificationSettings:settings];
    [application registerForRemoteNotifications];

    return YES;
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error
{
    [BRHLogger add:@"failed to register notifications: %@", [error description]];
#if TARGET_IPHONE_SIMULATOR
    self.notificationDriver.sim = YES;
#endif
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    [BRHLogger add:@"registered for notifications"];
    [BRHLogger add:@"device token: %@", [deviceToken description]];
    self.notificationDriver.deviceToken = deviceToken;
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
    [self.notificationDriver received:userInfo[@"id"] timeOfArrival:[NSDate date] contents:userInfo];
    if (self.notificationDriver.remoteDriver) {
        [self.notificationDriver.remoteDriver fetchMessage:[userInfo[@"id"]integerValue] withCompletionHandler:^(BOOL success, BOOL updated) {
            if (success) {
                if (updated) {
                    completionHandler(UIBackgroundFetchResultNewData);
                }
                else {
                    completionHandler(UIBackgroundFetchResultNoData);
                }
            }
            else {
                completionHandler(UIBackgroundFetchResultFailed);
            }
        }];
    }
    else {
        completionHandler(UIBackgroundFetchResultNoData);
    }
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    DDLogInfo(@"applicationWillResignActive");
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    DDLogInfo(@"applicationDidEnterBackground");
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    DDLogInfo(@"applicationWillEnterForeground");
    
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    DDLogInfo(@"applicationDidBecomeActive");
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    DDLogInfo(@"applicationWillTerminate");
    [self.notificationDriver stop];
    [[BRHLogger sharedInstance] save];
}

- (void)application:(UIApplication *)application performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
    if (self.notificationDriver.remoteDriver) {
        [self.notificationDriver.remoteDriver updateWithCompletionHandler:^(BOOL success, BOOL updated) {
            if (success) {
                if (updated) {
                    completionHandler(UIBackgroundFetchResultNewData);
                }
                else {
                    completionHandler(UIBackgroundFetchResultNoData);
                }
            }
            else {
                completionHandler(UIBackgroundFetchResultFailed);
            }
        }];
    }
}

- (void)application:(UIApplication *)application handleEventsForBackgroundURLSession:(NSString *)identifier completionHandler:(void (^)())completionHandler
{
    if (self.notificationDriver.remoteDriver) {
        [self.notificationDriver.remoteDriver handleEventsForBackgroundURLSession:identifier completionHandler:completionHandler];
    }
}

@end
