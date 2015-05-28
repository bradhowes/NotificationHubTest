// -*- Mode: ObjC -*-
//
// Copyright (C) 2011, Brad Howes. All rights reserved.
//

#import <CoreData/CoreData.h>
#import <Foundation/Foundation.h>

@interface RecordingInfo : NSManagedObject

@property (nonatomic, strong) NSString* filePath;
@property (nonatomic, strong) NSString* name;
@property (nonatomic, assign) float progress;
@property (nonatomic, strong) NSString* size;
@property (nonatomic, assign) BOOL uploaded;
@property (nonatomic, assign) BOOL uploading;

+ (NSString*)generateRecordingPath;

+ (NSString*)niceSizeOfFileString:(NSInteger)bytes;

- (void)initialize;

- (void)updateSizeWith:(NSInteger)size;

- (void)finalizeSize;

@end
