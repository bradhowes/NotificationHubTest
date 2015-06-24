// -*- Mode: ObjC -*-
//
// Copyright (C) 2011, Brad Howes. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "DDGPreferences.h"
#import "InAppSettingsKit/IASKSettingsStore.h"

/*!
 @brief Collection of user-modifiable settings.
 
 The attributes of this class take their values from NSUserDefaults and changes made to them will be written to the
 same.
 */
@interface BRHUserSettings : DDGPreferences <DDGPreferences>
/*!
 @brief The driver to use for generating notifications to the device under test.
 */
@property (copy, nonatomic) NSString *notificationDriver;
/*!
 @brief The remote server to talk to when using the BRHRemoteDriver driver.
 */
@property (copy, nonatomic) NSString *remoteServerName;
/*!
 @brief The port of the remote server to talk to when using the BRHRemoteDriver driver.
 */
@property (copy, nonatomic) NSString *remoteServerPortSetting;
/*!
 @brief The APNs sandbox certificate to load when using the BRHLoopNotificationDriver driver.
 */
@property (copy, nonatomic) NSString *apnsDevCertFileName;
/*!
 @brief The password for the APNs sandbox certificate when using the BRHLoopNotificationDriver driver.
 */
@property (copy, nonatomic) NSString *apnsDevCertPassword;
/*!
 @brief The APNs production certificate to load when using the BRHLoopNotificationDriver driver.
 */
@property (copy, nonatomic) NSString *apnsProdCertFileName;
/*!
 @brief The password for the production APNs certificate when using the BRHLoopNotificationDriver driver.
 */
@property (copy, nonatomic) NSString *apnsProdCertPassword;
/*!
 @brief The number of bins to show in the latency histgram graph.
 */
@property (copy, nonatomic) NSString *maxHistogramBinSetting;
/*!
 @brief The number of seconds to pause in between notifications to the device under test.
 
 @note too-small of a value may result in being banned by Apple!
 */
@property (copy, nonatomic) NSString *emitIntervalSetting;
/*!
 @brief The integral value of the remoteServerPortString setting above.
 */
@property (assign, nonatomic) NSUInteger remoteServerPort;
/*!
 @brief The integral value of the maxHistogramBinSetting above.
 */
@property (assign, nonatomic) NSUInteger maxHistogramBin;
/*!
 @brief The integral value of the emitIntervalSetting above.
 */
@property (assign, nonatomic) NSUInteger emitInterval;
/*!
 @brief If YES, link to a Dropbox account and upload recordings to it.
 */
@property (assign, nonatomic) BOOL useDropbox;

@property (assign, nonatomic) BOOL resendUntilFetched;

@property (assign, nonatomic) BOOL uploadAutomatically;

/*!
 @brief Obtain the global BRHUserSettings instance
 
 @return BRHUserSettings instance
 */
+ (instancetype)userSettings;

/*!
 @brief Generate a NSURL using the current remoteServerName and remoteServerPort settings
 
 @return NSURL object
 */
- (NSURL *)remoteServerURL;

/*!
 @brief Obtain the text to use for the Dropbox link button in the setting screen
 
 @return button text
 */
- (NSString *)dropboxLinkButtonTextSetting;

@end
