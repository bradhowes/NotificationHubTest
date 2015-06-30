// BRHRecordingInfo.m
// NHTest
//
// Copyright (C) 2015 Brad Howes. All rights reserved.

#import "BRHEventLog.h"
#import "BRHLogger.h"
#import "BRHRecordingInfo.h"
#import "BRHRunData.h"
#import "BRHTimeFormatter.h"

NSString *BRHRecordingInfoDataModelName = @"BRHRecordingInfo";

@interface BRHRecordingInfo (PrimitiveAccessors)

- (NSNumber *)primitiveUploaded;
- (void)setPrimitiveUploaded:(NSNumber *)value;

- (NSNumber *)primitiveAwaitingUpload;
- (void)setPrimitiveAwaitingUpload:(NSNumber *)value;

@end

@implementation BRHRecordingInfo

@dynamic awaitingUpload;
@dynamic endTime;
@dynamic errorCode;
@dynamic filePath;
@dynamic name;
@dynamic size;
@dynamic startTime;
@dynamic uploaded;

@synthesize recordingNow = _recordingNow;
@synthesize uploading = _uploading;
@synthesize folderURL = _folderURL;
@synthesize progress = _progress;
@synthesize runData = _runData;
@synthesize wasRecorded = _wasRecorded;

- (BOOL)uploaded
{
    NSNumber *tmpValue;
    [self willAccessValueForKey:@"uploaded"];
    tmpValue = self.primitiveUploaded;
    [self didAccessValueForKey:@"uploaded"];
    return tmpValue.boolValue;
}

- (void)setUploaded:(BOOL)value
{
    [self willChangeValueForKey:@"uploaded"];
    [self setPrimitiveUploaded:[NSNumber numberWithBool:value]];
    [self didChangeValueForKey:@"uploaded"];
}

- (BOOL)awaitingUpload
{
    NSNumber *tmpValue;
    [self willAccessValueForKey:@"awaitingUpload"];
    tmpValue = self.primitiveAwaitingUpload;
    [self didAccessValueForKey:@"awaitingUpload"];
    return tmpValue.boolValue;
}

- (void)setAwaitingUpload:(BOOL)value
{
    [self willChangeValueForKey:@"awaitingUpload"];
    [self setPrimitiveAwaitingUpload:[NSNumber numberWithBool:value]];
    [self didChangeValueForKey:@"awaitingUpload"];
}

- (void)awakeFromFetch
{
    [super awakeFromFetch];
    if (self.size.length < 2) {
        [self updateSize];
    }

    _runData = nil;
    _folderURL = nil;
    _recordingNow = NO;
    _uploading = NO;
    _wasRecorded = self.name.length > 1;
    _uploading = NO;
    _progress = 0.0;
}

- (void)initialize
{
    NSDate *now = [NSDate date];
    self.startTime = now;
    self.endTime = now;
    self.filePath = @"-";
    self.name = @"-";
    self.size = @"-";
    self.awaitingUpload = NO;
    self.uploaded = NO;
    self.errorCode = 0;

    _runData = [[BRHRunData alloc] initWithName:self.name];
    _folderURL = nil;
    _recordingNow = NO;
    _wasRecorded = NO;
    _uploading = NO;
    _progress = 0.0;
}

- (NSString *)recordingDirectoryName:(NSDate *)when
{
    static NSDateFormatter *dateFormatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"yyyy-MM-dd HH.mm.ss"];
    });

    return [dateFormatter stringFromDate:when];
}

- (NSString *)recordingDisplayName:(NSDate *)when
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

- (BRHRunData *)runData
{
    // When reanimated from Core Data, _runData is nil so we reconstitute it using previously-saved archive file.
    //
    if (! _runData) {
        NSURL *runDataArchive = [self.folderURL URLByAppendingPathComponent:@"runData.archive"];
        NSData *archiveData = [NSData dataWithContentsOfURL:runDataArchive];
        if (archiveData) {
            NSLog(@"archiveData size: %lu", (unsigned long)archiveData.length);
            _runData = [NSKeyedUnarchiver unarchiveObjectWithData:archiveData];
        }
    }

    return _runData;
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

- (NSString *)durationString
{
    if (! self.startTime || ! self.endTime) return @"--";
    NSTimeInterval duration = round([self.endTime timeIntervalSinceDate:self.startTime]);
    return [[BRHTimeFormatter sharedTimeFormatter] stringFromNumber:[NSNumber numberWithDouble:duration]];
}

- (void)setRecordingNow:(BOOL)recording
{
    if (recording) {

        // Update Core Data entity with recording info
        //
        NSDate *now = [NSDate date];
        self.startTime = now;
        self.endTime = now;
        self.name = [self recordingDisplayName:now];
        self.filePath = [self recordingDirectoryName:now];

        // Create folder to hold the recording data
        //
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSError *err = nil;
        NSURL *documentDirectory = [[fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
        _folderURL = [documentDirectory URLByAppendingPathComponent:self.filePath];
        if (! [fileManager createDirectoryAtURL:_folderURL withIntermediateDirectories:YES attributes:nil error:&err]) {
            NSLog(@"failed to create dir: %@ err: %@", _folderURL, [err description]);
            _folderURL = nil;
        }

        // Have the loggers record into the recording directory
        //
        NSLog(@"recordingDir: %@", _folderURL);
        [BRHLogger sharedInstance].logPath = _folderURL;
        [BRHEventLog sharedInstance].logPath = _folderURL;
    }
    else if (_recordingNow) {

        // Stop recording and archive what we measured.
        //
        self.endTime = [NSDate date];
        if (_folderURL) {
            NSURL *runDataArchive = [_folderURL URLByAppendingPathComponent:@"runData.archive"];
            NSData *archiveData = [NSKeyedArchiver archivedDataWithRootObject:self.runData];
            NSLog(@"archiveData size: %lu", (unsigned long)archiveData.length);
            NSError *error;
            if (![archiveData writeToURL:runDataArchive options:0 error:&error]) {
                NSLog(@"failed to write archive: %@", error.description);
            }
        }

        [self updateSize];
        _wasRecorded = YES;
    }

    _recordingNow = recording;
}

- (void)start
{
    self.recordingNow = YES;
}

- (void)stop
{
    self.recordingNow = NO;
}

@end
