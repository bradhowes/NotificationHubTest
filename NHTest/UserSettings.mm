// -*- Mode: ObjC -*-
//
// Copyright (C) 2011, Brad Howes. All rights reserved.
//

#import "UserSettings.h"

NSString* kSettingsCloudStorageEnableKey = @"CLOUD_STORAGE_ENABLE";

@implementation UserSettings

+ (NSUserDefaults*)registerDefaults
{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:
                                [NSNumber numberWithBool:YES], kSettingsCloudStorageEnableKey,
                                nil]];
    return defaults;
}

+ (void)validateFloatNamed:(NSString*)key minValue:(double)minValue maxValue:(double)maxValue
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    double	value = [defaults doubleForKey:key];
    if (value < minValue) {
        value = minValue;
    }
    else if	(value > maxValue) {
        value = maxValue;
    }
    [defaults setDouble:value forKey:key];
}

+ (void)validateIntegerNamed:(NSString*)key minValue:(NSInteger)minValue maxValue:(NSInteger)maxValue
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSInteger value = [defaults integerForKey:key];
    if (value < minValue) {
        value = minValue;
    }
    else if	(value > maxValue) {
        value = maxValue;
    }

    [defaults setInteger:value forKey:key];
}

+ (NSUserDefaults*)validate
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults synchronize];
    return defaults;
}

@end
