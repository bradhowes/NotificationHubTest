// BRHRecordingInfo.m
// NHTest
//
// Copyright (C) 2015 Brad Howes. All rights reserved.

#import "BRHRecordingInfo.h"
#import "BRHUserSettings.h"

NSString *BRHRecordingInfoDataModelName = @"BRHRecordingInfo";

static NSString *kRecordingInfoProgressKey = @"progress";
static NSString *kRecordingInfoUploadedKey = @"uploaded";
static NSString *kRecordingInfoUploadingKey = @"uploading";
static NSString *kRecordingInfoRecordingKey = @"recording";

@interface BRHRecordingInfo (PrimitiveAccessors)

- (NSNumber *)primitiveProgress;
- (void)setPrimitiveProgress:(NSNumber *)value;

- (NSNumber *)primitiveUploaded;
- (void)setPrimitiveUploaded:(NSNumber *)value;

- (NSNumber *)primitiveUploading;
- (void)setPrimitiveUploading:(NSNumber *)value;

- (NSNumber *)primitiveRecording;
- (void)setPrimitiveRecording:(NSNumber *)value;

@end

@implementation BRHRecordingInfo

@dynamic filePath;
@dynamic name;
@dynamic progress;
@dynamic size;
@dynamic uploaded;
@dynamic uploading;
@dynamic recording;
@synthesize folderURL = _folderURL;

- (float)progress
{
    NSNumber *tmpValue;
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
    NSNumber *tmpValue;
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
    NSNumber *tmpValue;
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

- (BOOL)recording
{
    NSNumber *tmpValue;
    [self willAccessValueForKey:kRecordingInfoRecordingKey];
    tmpValue = [self primitiveRecording];
    [self didAccessValueForKey:kRecordingInfoRecordingKey];
    return [tmpValue boolValue];
}

- (void)setRecording:(BOOL)value
{
    [self willChangeValueForKey:kRecordingInfoRecordingKey];
    [self setPrimitiveRecording:[NSNumber numberWithBool:value]];
    [self didChangeValueForKey:kRecordingInfoRecordingKey];
}

- (void)awakeFromFetch
{
    [super awakeFromFetch];

    if (self.primitiveUploading.boolValue) {
        self.uploading = NO;
    }

    if (self.primitiveProgress.floatValue != 0.0) {
        self.progress = 0.0;
    }

    if (self.primitiveRecording.boolValue)
        self.recording = NO;

    if (self.size.length == 0) {
        [self updateSize];
    }

    _folderURL = nil;
}

- (NSString *)recordingDirectory:(NSDate *)when
{
    static NSDateFormatter *dateFormatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"yyyy-MM-dd HH.mm.ss"];
    });

    return [dateFormatter stringFromDate:when];
}

- (void)createRecordingDirectory
{
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    NSError *err = nil;
    NSURL *dir = self.folderURL;
    if (! [fileManager createDirectoryAtURL:dir withIntermediateDirectories:YES attributes:nil error:&err]) {
        NSLog(@"failed to create dir: %@ err: %@", dir, [err description]);
    }

    NSLog(@"recordingDir: %@", dir);
}

- (NSString *)recordingName:(NSDate *)when
{
    static NSDateFormatter *dateFormatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dateFormatter = [[NSDateFormatter alloc] init];
        dateFormatter.formatterBehavior = NSDateFormatterBehaviorDefault;
        dateFormatter.dateStyle = NSDateIntervalFormatterMediumStyle;
        dateFormatter.timeStyle = NSDateIntervalFormatterMediumStyle;
    });

    return [dateFormatter stringFromDate:when];
}

- (NSURL *)folderURL
{
    if (! _folderURL) {
        NSURL *documentDirectory = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
        _folderURL = [documentDirectory URLByAppendingPathComponent:self.filePath];
    }

    return _folderURL;
}

- (void)initialize
{
    NSDate *now = [NSDate date];

    self.filePath = [self recordingDirectory:now];
    self.name = [self recordingName:now];
    self.uploaded = NO;
    self.uploading = NO;
    self.progress = 0.0;
    self.size = @"";
    self.recording = YES;
    _folderURL = nil;

    [self createRecordingDirectory];
}

- (void)updateSize
{
    self.size = [NSByteCountFormatter stringFromByteCount:[self folderSize] countStyle:NSByteCountFormatterCountStyleFile];
}

- (unsigned long long int)folderSize
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error;
    NSString *path = self.folderURL.path;
    NSLog(@"folderSize path: %@", path);

    NSArray *filesArray = [fileManager subpathsOfDirectoryAtPath:path error:&error];
    unsigned long long int fileSize = 0;

    if (! filesArray) {
        NSLog(@"path: %@", path);
        NSLog(@"failed subpathsOfDirectoryAtPath - %@", error.description);
        return fileSize;
    }

    for(NSString* fileName in filesArray) {
        error = nil;
        NSDictionary *fileDictionary = [fileManager attributesOfItemAtPath:[path stringByAppendingPathComponent:fileName] error:&error];
        if (! fileDictionary) {
            NSLog(@"fileName: %@", fileName);
            NSLog(@"failed attributesOfItemAtPath - %@", error.description);
            continue;
        }

        fileSize += [fileDictionary fileSize];
    }

    NSLog(@"fileSize: %llu", fileSize);

    return fileSize;
}

@end
