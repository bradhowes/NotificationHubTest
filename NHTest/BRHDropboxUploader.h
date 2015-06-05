// BRHDropboxUploader.h
// NHTest
//
// Copyright (C) 2015 Brad Howes. All rights reserved.

#import <Foundation/Foundation.h>

@class BRHDropboxUploader;
@class BRHRecordingInfo;

@protocol BRHDropboxUploaderMonitor
@required

- (void)dropboxUploader:(BRHDropboxUploader *)dropboxUploader monitorFinishedWith:(BRHRecordingInfo *)recordingInfo;
- (BRHRecordingInfo *)dropboxUploaderReadyToUpload:(BRHDropboxUploader *)dropboxUploader;

@end

@interface BRHDropboxUploader : NSObject

@property (weak, nonatomic) NSObject<BRHDropboxUploaderMonitor> *monitor;
@property (strong, nonatomic) BRHRecordingInfo *uploadingFile;

- (void)cancelUpload;

@end
