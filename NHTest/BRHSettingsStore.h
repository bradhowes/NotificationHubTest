//
//  BRHSettingsStore.m
//  NHTest
//
//  Copyright (c) 2015 Brad Howes. All rights reserved.

#import "InAppSettingsKit/IASKSettingsStore.h"

@class BRHUserSettings;

/*!
 * @brief Implementation of IASKAbstractSettingsStore that works with our BRHUserSettings object.
 */
@interface BRHSettingsStore : IASKAbstractSettingsStore

@property (strong, nonatomic) BRHUserSettings *settings;

@end

