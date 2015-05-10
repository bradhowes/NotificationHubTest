//
//  BRHAppDelegate.h
//  HelloWorld
//
//  Created by Brad Howes on 12/21/13.
//  Copyright (c) 2013 Brad Howes. All rights reserved.
//

#import <UIKit/UIKit.h>

@class BRHNotificationDriver;

@interface BRHAppDelegate : UIResponder <UIApplicationDelegate>

@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) BRHNotificationDriver *notificationDriver;

@end
