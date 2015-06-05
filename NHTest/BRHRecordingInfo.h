// BRHRecordingInfo.h
// NHTest
//
// Copyright (C) 2015 Brad Howes. All rights reserved.

#import <CoreData/CoreData.h>
#import <Foundation/Foundation.h>

extern NSString *BRHRecordingInfoDataModelName;

@interface BRHRecordingInfo : NSManagedObject

@property (copy, nonatomic) NSString *filePath;
@property (copy, nonatomic) NSString *name;
@property (assign, nonatomic) float progress;
@property (copy, nonatomic) NSString *size;
@property (assign, nonatomic) BOOL uploaded;
@property (assign, nonatomic) BOOL uploading;
@property (assign, nonatomic) BOOL recording;

@property (strong, readonly, nonatomic) NSURL *folderURL;

- (void)initialize;

- (void)updateSize;

- (NSURL *)folderURL;

- (unsigned long long int)folderSize;

@end
