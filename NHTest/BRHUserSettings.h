// -*- Mode: ObjC -*-
//
// Copyright (C) 2011, Brad Howes. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "DDGPreferences.h"
#import "InAppSettingsKit/IASKSettingsStore.h"

@interface BRHUserSettings : DDGPreferences <DDGPreferences>

@property (copy, nonatomic) NSString *notificationDriver;
@property (copy, nonatomic) NSString *remoteServerName;
@property (copy, nonatomic) NSString *remoteServerPortSetting;

@property (copy, nonatomic) NSString *apnsDevCertFileName;
@property (copy, nonatomic) NSString *apnsDevCertPassword;
@property (copy, nonatomic) NSString *apnsProdCertFileName;
@property (copy, nonatomic) NSString *apnsProdCertPassword;
@property (assign, nonatomic) BOOL useAPNsSandbox;

@property (copy, nonatomic) NSString *maxHistogramBinSetting;
@property (copy, nonatomic) NSString *emitIntervalSetting;

@property (assign, nonatomic) NSUInteger remoteServerPort;
@property (assign, nonatomic) NSUInteger maxHistogramBin;
@property (assign, nonatomic) NSUInteger emitInterval;

@property (assign, nonatomic) BOOL useDropbox;

+ (instancetype)userSettings;

- (void)setRemoteServerPort:(NSUInteger)remoteServerPort;
- (void)setMaxHistogramBin:(NSUInteger)maxHistogramBin;
- (void)setEmitInterval:(NSUInteger)emitInterval;

- (NSUInteger)remoteServerPort;
- (NSUInteger)maxHistogramBin;
- (NSUInteger)emitInterval;

- (NSURL *)remoteServerURL;

- (NSString *)dropboxLinkButtonTextSetting;

@end
