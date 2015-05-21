//
//  BRHEventLog.h
//  NotificationHubTest
//
//  Created by Brad Howes on 1/3/14.
//  Copyright (c) 2014 Brad Howes. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface BRHEventLog : NSObject

@property (nonatomic, strong) NSURL *logPath;
@property (nonatomic, strong) UITextView *textView;

+ (instancetype) sharedInstance;
+ (NSString *) add:(NSString*)format, ...;
+ (void)clear;

- (void)save;

@end
