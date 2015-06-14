// BRHDropboxUploader.h
// NHTest
//
// Copyright (C) 2015 Brad Howes. All rights reserved.

#import <DropboxSDK/DropboxSDK.h>

#import "BRHDropboxUploader.h"
#import "BRHNetworkActivityIndicator.h"
#import "Reachability.h"
#import "BRHRecordingInfo.h"

@interface BRHDropboxUploader () <DBRestClientDelegate>

@property (strong, nonatomic) Reachability *serverReachability;
@property (strong, nonatomic) DBRestClient *restClient;
@property (assign, nonatomic) CGFloat totalProgress;
@property (assign, nonatomic) BOOL networkActivityIndicator;

- (void)startReachabilityService:(NSTimer *)timer;
- (void)networkReachabilityChanged:(BOOL)active;
- (void)startRestClient;
- (void)stopRestClient;
- (void)readyToUpload;

@end

@implementation BRHDropboxUploader

- (instancetype)init
{
    if (self = [super init]) {
        _monitor = nil;
        _uploadingFile = nil;
        _totalProgress = 0.0;

        [NSTimer scheduledTimerWithTimeInterval:3.0 target:self selector:@selector(startReachabilityService:)
                                       userInfo:nil repeats:NO];
    }

    return self;
}

- (void)setNetworkActivityIndicator:(BOOL)onOrOff
{
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:onOrOff];
}

#pragma mark - Network Reachability Detection

- (void)startReachabilityService:(NSTimer *)timer
{
    NSLog(@"startReachabilityService");

    __weak BRHDropboxUploader* wself = self;
    self.serverReachability = [Reachability reachabilityWithHostname:@"dropbox.com"];
    self.serverReachability.reachableBlock = ^(Reachability* obj) {
        if (wself) [wself networkReachabilityChanged:YES];
    };
    
    self.serverReachability.unreachableBlock = ^(Reachability* obj) {
        if (wself) [wself networkReachabilityChanged:NO];
    };

    [self.serverReachability startNotifier];
}

- (void)networkReachabilityChanged:(BOOL)available
{
    NSLog(@"networkReachabilityChanged - available: %d", available);
    if (available) {
        if (self.restClient == nil) {
            [self startRestClient];
        }
    }
    else {
        if (self.restClient != nil) {
            [self stopRestClient];
        }
    }
}

- (void)cancelUpload
{
    if (self.restClient != nil && self.uploadingFile != nil) {
        [self.restClient cancelFileUpload:self.uploadingFile.filePath];
        self.networkActivityIndicator = NO;
    }
}

#pragma mark - Rest Client Processing

- (void)startRestClient
{
    NSLog(@"startRestClient");
    self.restClient = [[DBRestClient alloc] initWithSession:[DBSession sharedSession]];
    self.restClient.delegate = self;
    [self readyToUpload];
}

- (void)stopRestClient
{
    if (self.restClient) {
        [self cancelUpload];
        self.restClient = nil;
    }
    
    if (self.uploadingFile != nil) {
        self.uploadingFile.uploading = NO;
        self.uploadingFile.progress = 0.0;
        self.uploadingFile = nil;
    }
    
    self.networkActivityIndicator = NO;
}

- (void)readyToUpload
{
    NSLog(@"readyToUpload");

    if (_uploadingFile != nil) {
        _uploadingFile.uploading = NO;
        _uploadingFile = nil;
    }

    self.networkActivityIndicator = NO;
    self.uploadingFile = [self.monitor dropboxUploaderReadyToUpload:self];
}

- (void)setUploadingFile:(BRHRecordingInfo *)recording
{
    NSLog(@"setUploadingFile - %@", recording.filePath);
    if (! self.restClient) {
        NSLog(@"no rest client");
        return;
    }
    
    if (self.uploadingFile) {
        NSLog(@"already have a file uploading - %@", recording.filePath);
        return;
    }

    if (! recording) return;

    _uploadingFile = recording;
    _uploadingFile.uploading = YES;
    _totalProgress = 0.0;

    self.networkActivityIndicator = YES;

    [self checkForFolder:nil];
}

- (void)checkForFolder:(NSTimer *)timer
{
    NSLog(@"checkForFolder - %@", _uploadingFile.filePath);

    [self.restClient loadMetadata:_uploadingFile.filePath];
}

- (void)restClient:(DBRestClient *)client loadMetadataFailedWithError:(NSError *)error
{
    NSLog(@"loadMetadataFailedWithError - %@", error.description);
    [NSTimer scheduledTimerWithTimeInterval:5.0 target:self selector:@selector(checkForFolder:) userInfo:nil
                                    repeats:NO];
}

- (void)restClient:(DBRestClient*)client loadedMetadata:(DBMetadata*)metadata
{
    for (DBMetadata* child in metadata.contents) {
        if (child.isDirectory && [child.filename isEqualToString:_uploadingFile.filePath]) {
            [self uploadFile:@"events.csv"];
        }
        else {
            [self createFolder:nil];
        }
    }
}

- (void)createFolder:(NSTimer *)timer
{
    NSLog(@"createFolder - %@", _uploadingFile.filePath);
    [self.restClient createFolder:_uploadingFile.filePath];
}

- (void)restClient:(DBRestClient *)client createdFolder:(DBMetadata *)folder
{
    NSLog(@"createFolder OK - %@", _uploadingFile.filePath);
    [self uploadFile:@"events.csv"];
}

- (void)restClient:(DBRestClient *)client createFolderFailedWithError:(NSError *)error
{
    if (error.code == 403) {
        [self restClient:client createdFolder:nil];
        return;
    }

    NSLog(@"createFolder FAILED - %ld", (long)error.code);
    [NSTimer scheduledTimerWithTimeInterval:10.0 target:self selector:@selector(createFolder:) userInfo:nil repeats:NO];
}

- (void)uploadFile:(NSString *)filename
{
    NSLog(@"uploadFile - %@", filename);
    [self.restClient uploadFile:filename
                         toPath:[@"/" stringByAppendingString:self.uploadingFile.filePath]
                  withParentRev:nil
                       fromPath:[self.uploadingFile.folderURL URLByAppendingPathComponent:filename].path];
}

- (void)restClient:(DBRestClient *)client uploadProgress:(CGFloat)progress
           forFile:(NSString *)destPath from:(NSString *)srcPath;
{
    NSLog(@"uploadProgress - %@ %f", destPath, progress);
    self.uploadingFile.progress = self.totalProgress + progress / 3.0;
}

- (void)restClient:(DBRestClient *)client uploadedFile:(NSString *)destPath from:(NSString *)srcPath
{
    self.totalProgress += 1.0/3.0;

    if ([[srcPath lastPathComponent] isEqualToString:@"events.csv"]) {
        [self uploadFile:@"log.txt"];
    }
    else if ([[srcPath lastPathComponent] isEqualToString:@"log.txt"]) {
        [self uploadFile:@"runData.archive"];
    }
    else {
        self.uploadingFile.uploaded = YES;
        [self.monitor dropboxUploader:self monitorFinishedWith:self.uploadingFile];
        [self readyToUpload];
    }
}

- (void)restClient:(DBRestClient *)client uploadFileFailedWithError:(NSError *)error
{
    self.uploadingFile.progress = error.code * -1.0;
    [self readyToUpload];
}

@end
