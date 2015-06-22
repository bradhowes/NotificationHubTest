// -*- Mode: ObjC -*-
//
// Copyright (C) 2011, Brad Howes. All rights reserved.
//

#import "BRHAppDelegate.h"
#import "BRHUserSettings.h"

@implementation BRHUserSettings

@synthesize resendUntilFetched = _resendUntilFetched;

+ (instancetype)userSettings
{
    static BRHUserSettings *singleton = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        singleton = [BRHUserSettings new];
    });
    return singleton;
}

/*!
 @brief Set the default values for the user settings.
 */
- (void)setDefaultPreferences
{
    self.notificationDriver = @"remote";
    self.remoteServerName = @"brhemitter.azurewebsites.net";
    self.remoteServerPort = 80;
    self.apnsDevCertFileName = @"apn-nhtest-dev.p12";
    self.apnsDevCertPassword = @"";
    self.apnsProdCertFileName = @"apn-nhtest-prod.p12";
    self.apnsProdCertPassword = @"";
    self.useDropbox = NO;
    self.maxHistogramBin = 30;
    self.emitInterval = 60;
    self.resendUntilFetched = NO;
}

/*!
 @brief Setter for the remoteServerPort setting

 Updates the "real" remoteServerPortSetting setting.
 
 @param remoteServerPort new value to use
 */
- (void)setRemoteServerPort:(NSUInteger)remoteServerPort
{
    self.remoteServerPortSetting = [NSString stringWithFormat:@"%lu", (unsigned long)remoteServerPort];
}

/*!
 @brief Setter for the maxHistogramBin setting
 
 Updates the "real" maxHistogramBinSetting setting.
 
 @param maxHistogramBin new value to use
 */
- (void)setMaxHistogramBin:(NSUInteger)maxHistogramBin
{
    self.maxHistogramBinSetting = [NSString stringWithFormat:@"%lu", (unsigned long)maxHistogramBin];
}

/*!
 @brief Setter for the emitInterval setting
 
 Updates the "real" emitIntervalSetting setting.
 
 @param emitInterval new value to use
 */
- (void)setEmitInterval:(NSUInteger)emitInterval
{
    self.emitIntervalSetting = [NSString stringWithFormat:@"%lu", (unsigned long)emitInterval];
}

/*!
 @brief Getter for the remoteServerPort setting
 
 Returns value from the "real" remoteServerPortSetting setting.
 
 @return port value
 */
- (NSUInteger)remoteServerPort
{
    return self.remoteServerPortSetting.integerValue;
}

/*!
 @brief Getter for the maxHistogramBin setting
 
 Returns value from the "real" maxHistogramBinSetting setting.
 
 @return bin count
 */
- (NSUInteger)maxHistogramBin
{
    return self.maxHistogramBinSetting.integerValue;
}

/*!
 @brief Getter for the emitInterval setting
 
 Returns value from the "real" emitIntervalSetting setting.
 
 @return interval in seconds
 */
- (NSUInteger)emitInterval
{
    return self.emitIntervalSetting.integerValue;
}

- (NSURL *)remoteServerURL
{
    return [NSURL URLWithString:[NSString stringWithFormat:@"http://%@:%lu", self.remoteServerName, (unsigned long)self.remoteServerPort]];
}

- (NSString *)dropboxLinkButtonTextSetting
{
    return _useDropbox ? @"Unlink from Dropbox" : @"Link to Dropbox";
}

@end
