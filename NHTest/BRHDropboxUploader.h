// BRHDropboxUploader.h
// NHTest
//
// Copyright (C) 2015 Brad Howes. All rights reserved.

#import <Foundation/Foundation.h>

@class BRHDropboxUploader;
@class BRHRecordingInfo;

/*!
 @brief Monitor protocol for BRHDropboxUploader.
 
 For proper operation fo BRHDropbox, there must be a monitor which will provide BRHDropboxUploader with the next
 BRHRecordingInfo instance to upload to the application's Dropbox folder.
 */
@protocol BRHDropboxUploaderMonitor
@required

/*!
 @brief Notification from BRHDropboxUploader that it finished processing a BRHRecordingInfo instance.
 
 @param dropboxUploader the BRHDropboxUploader instance being monitored
 @param recordingInfo the BRHRecodingInfo instance that was processed
 */
- (void)dropboxUploader:(BRHDropboxUploader *)dropboxUploader monitorFinishedWith:(BRHRecordingInfo *)recordingInfo;

/*!
 @brief Request from BRHDropboxUploader for the next BRHRecordingInfo instance to upload.
 
 @param dropboxUploader the BRHDropboxUploader instance being monitored
 
 @return the next BRHRecordingInfo instance to upload. May be nil.
 */
- (BRHRecordingInfo *)dropboxUploaderReadyToUpload:(BRHDropboxUploader *)dropboxUploader;

@end

/*!
 @brief Interface to Drobox SDK
 
 Uploads the contents of folders created during test runs.
 */
@interface BRHDropboxUploader : NSObject

/*!
 @brief The monitor to interact with.
 */
@property (weak, nonatomic) NSObject<BRHDropboxUploaderMonitor> *monitor;

/*!
 @brief The BRHRecordingInfo instance being processed
 */
@property (strong, nonatomic) BRHRecordingInfo *uploadingFile;

- (void)cancelUpload;

@end
