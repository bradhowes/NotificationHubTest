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

@interface BRHAppDelegate ()

@end

@implementation BRHAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [application setStatusBarStyle:UIStatusBarStyleLightContent];

    [DDLog addLogger:[DDTTYLogger sharedInstance]];
    DDFileLogger* fileLogger = [[DDFileLogger alloc] init];
    [DDLog addLogger:fileLogger];

    DDLogDebug(@"launchOptions: %@", [launchOptions description]);

    [[NSUserDefaults standardUserDefaults] registerDefaults:@{@"prodCertFileName":@"apn-nhtest-prod.p12",
                                                              @"prodCertPassword":@"",
                                                              @"sandboxCertFileName":@"apn-nhtest-dev.p12",
                                                              @"sandboxCertPassword":@"",
                                                              @"useSandbox":@"1",
                                                              @"emitInterval":@"60",
                                                              @"maxBin":@"60",
                                                              @"useRemoteServer":@"0",
                                                              @"remoteServerName":@"emitter-bradhowes.c9.io",
                                                              @"remoteServerPort":@"80"
                                                              }];

    self.notificationDriver = [[BRHNotificationDriver alloc] init];

    UIUserNotificationSettings* settings = [UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeBadge|UIUserNotificationTypeSound|UIUserNotificationTypeAlert
                                                                             categories:nil];
    [application registerUserNotificationSettings:settings];
    [application registerForRemoteNotifications];
    // [application setIdleTimerDisabled:YES];

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
    completionHandler(UIBackgroundFetchResultNoData);
    [self.notificationDriver received:userInfo[@"aps"][@"id"] timeOfArrival:[NSDate date] contents:userInfo[@"aps"]];
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo
{
    [self.notificationDriver received:userInfo[@"aps"][@"id"] timeOfArrival:[NSDate date] contents:userInfo[@"aps"]];
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

@end
