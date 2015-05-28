// -*- Mode: ObjC -*-
//
// Copyright (C) 2011, Brad Howes. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString* kSettingsCloudStorageEnableKey;

@interface UserSettings : NSObject

+ (NSUserDefaults*)registerDefaults;
+ (NSUserDefaults*)validate;

+ (void)validateIntegerNamed:(NSString*)key minValue:(NSInteger)minValue maxValue:(NSInteger)maxValue;

+ (void)validateFloatNamed:(NSString*)key minValue:(double)minValue maxValue:(double)maxValue;

@end
