// BRHDropboxUploader.h
// NHTest
//
// Copyright (C) 2015 Brad Howes. All rights reserved.

#import <DropboxSDK/DropboxSDK.h>
#import "Reachability.h"

#import "BRHDropboxUploader.h"
#import "BRHLogger.h"
#import "BRHNetworkActivityIndicator.h"
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
- (void)readyToUploadNextFile;

- (void)finishedUploading;
- (void)failedUploading:(NSError *)error;

@end

@implementation BRHDropboxUploader

- (instancetype)init
{
    if (self = [super init]) {
        _monitor = nil;
        _uploadingFile = nil;
        _totalProgress = 0.0;
        [NSTimer scheduledTimerWithTimeInterval:5.0 target:self selector:@selector(startReachabilityService:)
                                       userInfo:nil repeats:NO];
    }

    return self;
}

- (void)dealloc
{
    [self stopRestClient];
    if (_serverReachability) [_serverReachability stopNotifier];
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
    
    // Dropbox DBRestClient must run on the main thread. Reachability does not guarantee that.
    //
    _serverReachability = [Reachability reachabilityWithHostname:@"dropbox.com"];
    _serverReachability.reachableBlock = ^(Reachability* obj) {
        dispatch_queue_t q = dispatch_get_main_queue();
        dispatch_async(q, ^() {
            [wself networkReachabilityChanged:YES];
        });
    };

    _serverReachability.unreachableBlock = ^(Reachability* obj) {
        dispatch_queue_t q = dispatch_get_main_queue();
        dispatch_async(q, ^() {
            [wself networkReachabilityChanged:NO];
        });
    };

    [_serverReachability startNotifier];
    [self startRestClient];
}

- (void)networkReachabilityChanged:(BOOL)available
{
    [BRHLogger add:@"BRHDropboxUploader - networkReachabilityChanged - available: %d", available];
    if (available) {
        if (_restClient == nil) {
            [self startRestClient];
        }
    }
    else {
        if (_restClient != nil) {
            [self stopRestClient];
        }
    }
}

- (void)cancelUpload
{
    NSLog(@"BRHDropboxUploader cancelUpload");
    if (_restClient && _uploadingFile) {
        [_restClient cancelFileUpload:_uploadingFile.filePath];
        self.networkActivityIndicator = NO;
    }
}

#pragma mark - Rest Client Processing

- (void)startRestClient
{
    NSLog(@"startRestClient");
    _restClient = [[DBRestClient alloc] initWithSession:[DBSession sharedSession]];
    _restClient.delegate = self;
    [self readyToUploadNextFile];
}

- (void)stopRestClient
{
    if (_restClient) {
        [self cancelUpload];
        _restClient = nil;
    }
    
    if (_uploadingFile != nil) {
        _uploadingFile.uploading = NO;
        _uploadingFile.progress = 0.0;
        self.uploadingFile = nil;
    }

    self.networkActivityIndicator = NO;
}

- (void)readyToUploadNextFile
{
    NSLog(@"BRHDropboxUploader readyToUploadNextFile");
    if (_uploadingFile) {
        self.networkActivityIndicator = NO;
        _uploadingFile.uploading = NO;
        [_monitor dropboxUploader:self monitorFinishedWith:_uploadingFile];
        _uploadingFile = nil;
    }

    self.uploadingFile = [_monitor dropboxUploaderReadyToUpload:self];
}

- (void)setUploadingFile:(BRHRecordingInfo *)recording
{
    NSLog(@"setUploadingFile - %@", recording.filePath);
    if (! _restClient) {
        NSLog(@"no rest client");
        return;
    }

    if (_uploadingFile) {
        NSLog(@"already have a file uploading - %@", _uploadingFile.filePath);
        return;
    }

    if (! recording) return;

    _uploadingFile = recording;
    _uploadingFile.uploading = YES;
    _totalProgress = 0.0;

    self.networkActivityIndicator = YES;

    // First step in the upload process is to create the folder
    [self createFolder:nil];
}

- (void)createFolder:(NSTimer *)timer
{
    NSLog(@"createFolder - %@", _uploadingFile.filePath);
    [_restClient createFolder:_uploadingFile.filePath];
}

- (void)restClient:(DBRestClient *)client createFolderFailedWithError:(NSError *)error
{
    // Failed to create the folder -- accept as a success if the error indicates that the folder already exists
    if (error.code == 403) {
        [self restClient:client createdFolder:nil];
        return;
    }
    else if (error.code >= 500) {
        
        // Retry if the service is unavailable
        NSLog(@"createFolder FAILED - %ld", (long)error.code);
        [NSTimer scheduledTimerWithTimeInterval:10.0 target:self selector:@selector(createFolder:) userInfo:nil
                                        repeats:NO];
    }
    else {
        
        // Unrecoverable error
        [self failedUploading:error];
    }
}

- (void)restClient:(DBRestClient *)client createdFolder:(DBMetadata *)folder
{
    // Next step - upload events.csv file
    NSLog(@"createFolder OK - %@", _uploadingFile.filePath);
    [self uploadFile:@"events.csv"];
}

- (void)uploadFile:(NSString *)filename
{
    NSLog(@"uploadFile - %@", filename);
    [_restClient uploadFile:filename toPath:[@"/" stringByAppendingString:_uploadingFile.filePath]
              withParentRev:nil fromPath:[_uploadingFile.folderURL URLByAppendingPathComponent:filename].path];
}

- (void)restClient:(DBRestClient *)client uploadProgress:(CGFloat)progress forFile:(NSString *)destPath
              from:(NSString *)srcPath;
{
    NSLog(@"uploadProgress - %@ %f", destPath, progress);
    _uploadingFile.progress = _totalProgress + progress / 3.0;
    NSLog(@"totalProgress: %f", _uploadingFile.progress);
}

- (void)restClient:(DBRestClient *)client uploadedFile:(NSString *)destPath from:(NSString *)srcPath
{
    // Finished uploading a file. Handle the others
    _totalProgress += 1.0/3.0;
    _uploadingFile.progress = _totalProgress;
    if ([[srcPath lastPathComponent] isEqualToString:@"events.csv"]) {
        [self uploadFile:@"log.txt"];
    }
    else if ([[srcPath lastPathComponent] isEqualToString:@"log.txt"]) {
        [self uploadFile:@"runData.archive"];
    }
    else {
        [self finishedUploading];
    }
}

- (void)restClient:(DBRestClient *)client uploadFileFailedWithError:(NSError *)error
{
    [self failedUploading:error];
}

- (void)finishedUploading
{
    [BRHLogger add:@"finished uploading %@", _uploadingFile.filePath];
    _uploadingFile.uploaded = YES;
    [self readyToUploadNextFile];
}

- (void)failedUploading:(NSError *)error
{
    [BRHLogger add:@"failed to upload recording - %@", error.description];
    _uploadingFile.errorCode = error.code;
    [self readyToUploadNextFile];
}

@end
