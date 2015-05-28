// -*- Mode: ObjC -*-
//
// Copyright (C) 2011, Brad Howes. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RecordingInfo;

@protocol DropboxUploaderMonitor
@required

- (void)readyToUpload;

@end

@interface DropboxUploader : NSObject

@property (nonatomic, weak) NSObject<DropboxUploaderMonitor> *monitor;
@property (nonatomic, strong) RecordingInfo *uploadingFile;

+ (id)createWithSession:(DBSession*)session;

- (id)initWithSession:(DBSession*)session;

- (void)cancelUpload;

@end
