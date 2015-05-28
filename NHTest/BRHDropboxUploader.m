// -*- Mode: ObjC -*-
//
// Copyright (C) 2011, Brad Howes. All rights reserved.
//

#import <DropboxSDK/DropboxSDK.h>
#import "Reachability.h"

#import "BRHDropboxUploader.h"

@interface DropboxUploader () <DBRestClientDelegate>

@property (nonatomic, strong) DBSession *session;
@property (nonatomic, assign) BOOL warnedUser;
@property (nonatomic, strong) UIAlertView *postedAlert;
@property (nonatomic, strong) DBRestClient *restClient;
@property (nonatomic, strong) NSURL *uploadingFile;
@property (nonatomic, strong) Reachability *serverReachability;

- (void)startReachabilityService;
- (void)networkReachabilityChanged:(NSNotification*)notification;
- (void)startRestClient;
- (void)warnNetworkAvailable;
- (void)stopRestClient;
- (void)warnNetworkUnavailable;
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex;
- (void)readyToUpload;
- (void)attemptLoadAccountInfo:(NSTimer*)timer;
- (void)attemptCreateRemoteFolder:(NSTimer*)timer;

@end

@implementation DropboxUploader

- (id)init
{
    if (self = [super init]) {
        self.session = [DBSession sharedSession];
        self.warnedUser = NO;
        self.postedAlert = nil;
        self.uploadingFile = nil;
    }
    
    return self;
}

- (void)startReachabilityService
{
    self.serverReachability = [Reachability reachabilityWithHostname:@"dropbox.coom"];
    self.serverReachability.reachableBlock = ^(Reachability *reachability) {
    };
    self.serverReachability.unreachableBlock = ^(Reachability *reachability) {
    };
    [self.serverReachability startNotifier];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    self.postedAlert = nil;
}

- (void)cancelUpload
{
    if (self.restClient != nil && self.uploadingFile != nil) {
        [self.restClient cancelFileUpload:@"/Datac"];
        [self.restClient cancelFileUpload:self.uploadingFile.absoluteString];
    }
}

- (void)startRestClient
{
    self.restClient = [[DBRestClient alloc] initWithSession:self.session];
    self.restClient.delegate = self;
    [self.restClient loadAccountInfo];
}

- (void)attemptLoadAccountInfo:(NSTimer*)timer
{
    [self.restClient loadAccountInfo];
}

- (void)restClient:(DBRestClient*)client loadedAccountInfo:(DBAccountInfo*)info
{
    [self attemptCreateRemoteFolder:nil];
}

- (void)restClient:(DBRestClient*)client loadAccountInfoFailedWithError:(NSError*)error
{
    LOG(@"DropboxUploader.restClient:loadAccountInfoFailedWithError: %@, %@", error, [error userInfo]);
    [NSTimer scheduledTimerWithTimeInterval:10.0 target:self selector:@selector(attemptLoadAccountInfo:) userInfo:nil
                                    repeats:NO];
}

- (void)attemptCreateRemoteFolder:(NSTimer*)timer
{
    [self.restClient createFolder:@"/Datac"];
}

- (void)restClient:(DBRestClient*)client createdFolder:(DBMetadata*)folder
{
    LOG(@"DropboxUploader.restClient:createdFolder:");
    [self readyToUpload];
}

- (void)restClient:(DBRestClient*)client createFolderFailedWithError:(NSError*)error
{
    LOG(@"DropboxUploader.restClient:createFolderFailedWithError: %@, %@", error, [error userInfo]);
    if (error.code == 403) {
        [self readyToUpload];
    }
    else {
        [NSTimer scheduledTimerWithTimeInterval:10.0 target:self selector:@selector(attemptCreateRemoteFolder:) userInfo:nil
                                        repeats:NO];
    }
}

- (void)stopRestClient
{
    if (self.restClient) {
        [self cancelUpload];
        self.restClient = nil;
    }
    
    if (self.uploadingFile != nil) {
        self.uploadingFile.uploading = NO;
        uploadingFile.progress = 0.0;
        uploadingFile = nil;
    }
    
    self.networkActivityIndicator = nil;
}

- (void)setPostedAlert:(UIAlertView *)alert
{
    if (postedAlert) {
        [postedAlert dismissWithClickedButtonIndex:0 animated:NO];
        postedAlert = nil;
    }
	
    postedAlert = alert;
    [postedAlert show];
}

- (void)warnNetworkAvailable
{
    if (warnedUser == YES) {
        self.postedAlert = [[UIAlertView alloc] initWithTitle:@"Network Available"
                                                       message:@"Uploading files to Dropbox account."
                                                      delegate:self
                                             cancelButtonTitle:@"OK"
                                             otherButtonTitles:nil];
        warnedUser = NO;
    }
}

- (void)warnNetworkUnavailable
{
    if (warnedUser == NO) {
        self.postedAlert = [[UIAlertView alloc] initWithTitle:@"Network Unavailable"
                                                       message:@"Unable to upload files to Dropbox account."
                                                      delegate:nil
                                             cancelButtonTitle:@"OK"
                                             otherButtonTitles:nil];
        warnedUser = YES;
    }
}

- (void)networkReachabilityChanged:(NSNotification *)notification
{
    ReachabilityState state = [serverReachability currentReachabilityState];
    LOG(@"DropboxUploader.networkReachabilityChanged: %d", state);
    if (state == kNotReachable) {
        if (restClient != nil) {
            [self stopRestClient];
            [self warnNetworkUnavailable];
        }
    }
    else {
        if (restClient == nil) {
            [self startRestClient];
            [self warnNetworkAvailable];
        }
    }
}

- (void)setUploadingFile:(RecordingInfo*)recording
{
    if (restClient == nil) return;
    if (uploadingFile != nil) return;

    uploadingFile = recording;
    uploadingFile.uploading = YES;

    LOG(@"DropboxUploader - uploading file: %@", uploadingFile.filePath);
    
    [restClient uploadFile:[uploadingFile.filePath lastPathComponent]
                    toPath:@"/Datac" withParentRev:nil fromPath:uploadingFile.filePath];
    
    self.networkActivityIndicator = [NetworkActivityIndicator create];
}

- (void)restClient:(DBRestClient*)client uploadProgress:(CGFloat)progress
           forFile:(NSString*)destPath from:(NSString*)srcPath;
{
    // LOG(@"DropboxUploader.restClient:uploadProgress");
    uploadingFile.progress = progress;
}

- (void)restClient:(DBRestClient*)client uploadedFile:(NSString*)destPath from:(NSString*)srcPath
{
    LOG(@"DropboxUploader.restClient:uploadedFile");
    uploadingFile.uploaded = YES;
    uploadingFile.progress = 0.0;
    [self readyToUpload];
}

- (void)restClient:(DBRestClient*)client uploadFileFailedWithError:(NSError*)error
{
    LOG(@"DropboxUploader.restClient:uploadFileFailedWithError: - %@, %@", error, [error userInfo]);
    uploadingFile.progress = error.code * -1.0;
    [self readyToUpload];
}

- (void)readyToUpload
{
    if (uploadingFile != nil) {
        uploadingFile.uploading = NO;
        uploadingFile = nil;
    }
    
    self.networkActivityIndicator = nil;
    
    [monitor readyToUpload];
}

@end
