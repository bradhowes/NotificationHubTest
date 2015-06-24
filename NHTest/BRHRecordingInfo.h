// BRHRecordingInfo.h
// NHTest
//
// Copyright (C) 2015 Brad Howes. All rights reserved.

#import <CoreData/CoreData.h>
#import <Foundation/Foundation.h>

extern NSString *BRHRecordingInfoDataModelName;

@class BRHRunData;

@interface BRHRecordingInfo : NSManagedObject

// These properties *are* managed
@property (strong, nonatomic) NSDate *startTime;
@property (strong, nonatomic) NSDate *endTime;
@property (copy, nonatomic) NSString *filePath;
@property (copy, nonatomic) NSString *name;
@property (copy, nonatomic) NSString *size;
@property (assign, nonatomic) NSInteger errorCode;
@property (assign, nonatomic) BOOL awaitingUpload;
@property (assign, nonatomic) BOOL uploaded;

// These properties are *not* managed
@property (strong, readonly, nonatomic) BRHRunData *runData;
@property (strong, readonly, nonatomic) NSURL *folderURL;
@property (assign, readonly, nonatomic) BOOL recordingNow;
@property (assign, readonly, nonatomic) BOOL wasRecorded;
@property (assign, nonatomic) BOOL uploading;
@property (assign, nonatomic) float progress;

- (void)initialize;

- (void)updateSize;

- (NSURL *)folderURL;

- (unsigned long long int)folderSize;

- (NSString *)durationString;

/*!
 * @brief Clear all data and record the start time of the run
 */
- (void)start;

- (void)stop;

@end
