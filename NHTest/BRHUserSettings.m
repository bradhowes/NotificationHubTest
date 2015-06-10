// -*- Mode: ObjC -*-
//
// Copyright (C) 2011, Brad Howes. All rights reserved.
//

#import "BRHAppDelegate.h"
#import "BRHUserSettings.h"

@implementation BRHUserSettings

+ (instancetype)userSettings
{
    static BRHUserSettings *singleton = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        singleton = [BRHUserSettings new];
    });
    return singleton;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self setUseDropbox:_useDropbox];
    }
    
    return self;
}

- (void)setDefaultPreferences
{
    self.notificationDriver = @"loop";

    self.remoteServerName = @"emitter-bradhowes.c9.io";
    self.remoteServerPort = 80;
    
    self.apnsDevCertFileName = @"apn-nhtest-dev.p12";
    self.apnsDevCertPassword = @"";
    self.apnsProdCertFileName = @"apn-nhtest-prod.p12";
    self.apnsProdCertPassword = @"";

    self.useDropbox = NO;

    self.maxHistogramBin = 30;
    self.emitInterval = 15;
}

- (void)setRemoteServerPort:(NSUInteger)remoteServerPort
{
    self.remoteServerPortSetting = [NSString stringWithFormat:@"%lu", (unsigned long)remoteServerPort];
}

- (void)setMaxHistogramBin:(NSUInteger)maxHistogramBin
{
    self.maxHistogramBinSetting = [NSString stringWithFormat:@"%lu", (unsigned long)maxHistogramBin];
}

- (void)setEmitInterval:(NSUInteger)emitInterval
{
    self.emitIntervalSetting = [NSString stringWithFormat:@"%lu", (unsigned long)emitInterval];
}

- (void)setUseDropbox:(BOOL)useDropbox
{
    _useDropbox = useDropbox;
    
    // !!! Need this to cause IASK to update the button value.
    //[[NSUserDefaults standardUserDefaults] setObject:self.dropboxLinkButtonTextSetting forKey:@"dropboxLinkButtonTextSetting"];
}

- (NSUInteger)remoteServerPort
{
    return self.remoteServerPortSetting.integerValue;
}

- (NSUInteger)maxHistogramBin
{
    return self.maxHistogramBinSetting.integerValue;
}

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
