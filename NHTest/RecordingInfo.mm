// -*- Mode: ObjC -*-
//
// Copyright (C) 2011, Brad Howes. All rights reserved.
//

#import "RecordingInfo.h"
#import "UserSettings.h"

static NSString *kRecordingInfoProgressKey = @"progress";
static NSString *kRecordingInfoUploadedKey = @"uploaded";
static NSString *kRecordingInfoUploadingKey = @"uploading";

@interface RecordingInfo (PrimitiveAccessors)

- (NSNumber*)primitiveProgress;
- (void)setPrimitiveProgress:(NSNumber*)value;

- (NSNumber*)primitiveUploaded;
- (void)setPrimitiveUploaded:(NSNumber*)value;

- (NSNumber*)primitiveUploading;
- (void)setPrimitiveUploading:(NSNumber*)value;

@end

@implementation RecordingInfo

@dynamic filePath;
@dynamic name;
@dynamic progress;
@dynamic size;
@dynamic uploaded;
@dynamic uploading;

- (float)progress
{
    NSNumber* tmpValue;
    [self willAccessValueForKey:kRecordingInfoProgressKey];
    tmpValue = [self primitiveProgress];
    [self didAccessValueForKey:kRecordingInfoProgressKey];
    return [tmpValue floatValue];
}

- (void)setProgress:(float)value
{
    [self willChangeValueForKey:kRecordingInfoProgressKey];
    [self setPrimitiveProgress:[NSNumber numberWithFloat:value]];
    [self didChangeValueForKey:kRecordingInfoProgressKey];
}

- (BOOL)uploaded
{
    NSNumber* tmpValue;
    [self willAccessValueForKey:kRecordingInfoUploadedKey];
    tmpValue = [self primitiveUploaded];
    [self didAccessValueForKey:kRecordingInfoUploadedKey];
    return [tmpValue boolValue];
}

- (void)setUploaded:(BOOL)value
{
    [self willChangeValueForKey:kRecordingInfoUploadedKey];
    [self setPrimitiveUploaded:[NSNumber numberWithBool:value]];
    [self didChangeValueForKey:kRecordingInfoUploadedKey];
}

- (BOOL)uploading
{
    NSNumber* tmpValue;
    [self willAccessValueForKey:kRecordingInfoUploadingKey];
    tmpValue = [self primitiveUploading];
    [self didAccessValueForKey:kRecordingInfoUploadingKey];
    return [tmpValue boolValue];
}

- (void)setUploading:(BOOL)value
{
    [self willChangeValueForKey:kRecordingInfoUploadingKey];
    [self setPrimitiveUploading:[NSNumber numberWithBool:value]];
    [self didChangeValueForKey:kRecordingInfoUploadingKey];
}

+ (NSString*)niceSizeOfFileString:(NSInteger)bytes
{
    if (bytes<1024)
        return [NSString stringWithFormat: NSLocalizedString(@"%d bytes", "@Format for size in bytes"), bytes];
    else if (bytes<1048576)
        return [NSString stringWithFormat: NSLocalizedString(@"%dKB", "@Format for size in kilobytes"), (bytes/1024)];
    else
        return [NSString stringWithFormat: NSLocalizedString(@"%.2fMB", @"Format for size in megabytes"),
                ((float)bytes/1048576)];
}

+ (NSString*)generateRecordingPath
{
    NSDateFormatter* dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyyMMddHHmmss"];
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *path = [documentsDirectory stringByAppendingPathComponent:@"Recordings"];
    NSFileManager* fileManager = [[NSFileManager alloc] init];
    if ([fileManager fileExistsAtPath:path] == NO) {
        NSError* err = nil;
        if ([fileManager createDirectoryAtPath:path
                   withIntermediateDirectories:YES
                                    attributes:nil
                                         error:&err] == NO) {;
            NSLog(@"RecordingInfo.generateRecordingPath: failed to create Recordings directory! - %@", err);
            path = nil;
        }
    }

    NSString *name = [dateFormatter stringFromDate:[NSDate date]];
    path = [path stringByAppendingPathComponent:name];

    return path;
}

- (void)awakeFromFetch
{
    [super awakeFromFetch];
    if ([[self primitiveUploading] boolValue] == YES) {
        self.uploading = NO;
    }

    if ([[self primitiveProgress] floatValue] != 0.0) {
        self.progress = 0.0;
    }
}

- (void)initialize
{
    NSString *path = [RecordingInfo generateRecordingPath];
    self.filePath = path;
    NSURL *fileUrl = [NSURL fileURLWithPath:path];
    self.name = [fileUrl lastPathComponent];
    self.size = [RecordingInfo niceSizeOfFileString:0];
    self.uploaded = NO;
    self.uploading = NO;
    self.progress = 0.0;
}

- (void)updateSizeWith:(NSInteger)size
{
    self.size = [RecordingInfo niceSizeOfFileString:size];
}

- (void)finalizeSize
{
    NSString *path = self.filePath;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *err;
    NSDictionary *attr = [fileManager attributesOfItemAtPath:path error:&err];
    self.size = [RecordingInfo niceSizeOfFileString:attr.fileSize];
}

@end
