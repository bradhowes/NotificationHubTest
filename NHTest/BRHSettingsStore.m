//
//  BRHSettingsViewController.m
//  NHTest
//
//  Created by Brad Howes on 4/12/14.
//  Copyright (c) 2014 Brad Howes. All rights reserved.
//

#import "BRHSettingsStore.h"
#import "BRHUserSettings.h"

@implementation BRHSettingsStore

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
    if (value && key) {
        [_settings setValue:value forKey:key];
    }
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

