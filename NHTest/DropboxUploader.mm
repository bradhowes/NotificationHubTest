// -*- Mode: ObjC -*-
//
// Copyright (C) 2011, Brad Howes. All rights reserved.
//

#import <DropboxSDK/DropboxSDK.h>

#import "DropboxUploader.h"
#import "NetworkActivityIndicator.h"
#import "Reachability.h"
#import "RecordingInfo.h"

@interface DropboxUploader () <DBRestClientDelegate>

@property (nonatomic, strong) Reachability *serverReachability;
@property (nonatomic, strong) DBSession *session;
@property (nonatomic, strong) DBRestClient *restClient;
@property (nonatomic, assign) BOOL warnedUser;
@property (nonatomic, strong) UIAlertView *postedAlert;
@property (nonatomic, strong) NetworkActivityIndicator *networkActivityIndicator;

- (void)startReachabilityService;
- (void)networkReachabilityChanged:(BOOL)active;
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

+ (id)createWithSession:(DBSession*)session
{
    return [[DropboxUploader alloc] initWithSession:session];
}

- (id)initWithSession:(DBSession *)theSession
{
    if (self = [super init]) {
        self.session = theSession;
        self.warnedUser = NO;
        self.postedAlert = nil;
        self.monitor = nil;
        self.uploadingFile = nil;
        self.networkActivityIndicator = nil;
        [NSTimer scheduledTimerWithTimeInterval:3.0 target:self selector:@selector(startReachabilityService)
                                       userInfo:nil repeats:NO];
    }

    return self;
}

- (void)startReachabilityService
{
    __weak DropboxUploader *wself = self;
    self.serverReachability = [Reachability reachabilityWithHostname:@"dropbox.com"];
    self.serverReachability.reachableBlock = ^(Reachability *obj) {
        if (wself) [wself networkReachabilityChanged:YES];
    };
    
    self.serverReachability.unreachableBlock = ^(Reachability *obj) {
        if (wself) [wself networkReachabilityChanged:NO];
    };

    [self.serverReachability startNotifier];
    [self networkReachabilityChanged:YES];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    self.postedAlert = nil;
}

- (void)cancelUpload
{
    if (self.restClient != nil && self.uploadingFile != nil) {
        [self.restClient cancelFileUpload:@"/Datac"];
        [self.restClient cancelFileUpload:self.uploadingFile.filePath];
        self.networkActivityIndicator = nil;
    }
}

- (void)startRestClient
{
    self.restClient = [[DBRestClient alloc] initWithSession:self.session];
    self.restClient.delegate = self;
    [self attemptLoadAccountInfo:nil];
}

- (void)attemptLoadAccountInfo:(NSTimer*)timer
{
    [self.restClient loadAccountInfo];
}

- (void)restClient:(DBRestClient*)client loadedAccountInfo:(DBAccountInfo*)info
{
    self.networkActivityIndicator = [NetworkActivityIndicator new];
    [self attemptCreateRemoteFolder:nil];
}

- (void)restClient:(DBRestClient*)client loadAccountInfoFailedWithError:(NSError*)error
{
    [NSTimer scheduledTimerWithTimeInterval:10.0
                                     target:self
                                   selector:@selector(attemptLoadAccountInfo:)
                                   userInfo:nil
                                    repeats:NO];
}

- (void)attemptCreateRemoteFolder:(NSTimer*)timer
{
    [self.restClient createFolder:@"/NHTest"];
}

- (void)restClient:(DBRestClient*)client createdFolder:(DBMetadata*)folder
{
    [self readyToUpload];
}

- (void)restClient:(DBRestClient*)client createFolderFailedWithError:(NSError*)error
{
    if (error.code == 403) {
        [self readyToUpload];
    }
    else {
        [NSTimer scheduledTimerWithTimeInterval:10.0
                                         target:self
                                       selector:@selector(attemptCreateRemoteFolder:)
                                       userInfo:nil
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
        self.uploadingFile.progress = 0.0;
        self.uploadingFile = nil;
    }

    self.networkActivityIndicator = nil;
}

- (void)setPostedAlert:(UIAlertView *)alert
{
    if (self.postedAlert) {
        [self.postedAlert dismissWithClickedButtonIndex:0 animated:NO];
        self.postedAlert = nil;
    }
	
    self.postedAlert = alert;
    [self.postedAlert show];
}

- (void)warnNetworkAvailable
{
    if (self.warnedUser == YES) {
        self.postedAlert = [[UIAlertView alloc] initWithTitle:@"Network Available"
                                                       message:@"Uploading files to Dropbox account."
                                                      delegate:self
                                             cancelButtonTitle:@"OK"
                                             otherButtonTitles:nil];
        self.warnedUser = NO;
    }
}

- (void)warnNetworkUnavailable
{
    if (self.warnedUser == NO) {
        self.postedAlert = [[UIAlertView alloc] initWithTitle:@"Network Unavailable"
                                                      message:@"Unable to upload files to Dropbox account."
                                                     delegate:nil
                                            cancelButtonTitle:@"OK"
                                            otherButtonTitles:nil];
        self.warnedUser = YES;
    }
}

- (void)networkReachabilityChanged:(BOOL)available
{
    NetworkStatus state = [self.serverReachability currentReachabilityStatus];
    if (state == NotReachable) {
        if (self.restClient != nil) {
            [self stopRestClient];
            [self warnNetworkUnavailable];
        }
    }
    else {
        if (self.restClient == nil) {
            [self startRestClient];
            [self warnNetworkAvailable];
        }
    }
}

- (void)setUploadingFile:(RecordingInfo*)recording
{
    if (self.restClient == nil) return;
    if (self.uploadingFile != nil) return;

    self.uploadingFile = recording;
    self.uploadingFile.uploading = YES;

    [self.restClient uploadFile:[self.uploadingFile.filePath lastPathComponent]
                         toPath:@"/NHTest"
                  withParentRev:nil
                       fromPath:self.uploadingFile.filePath];
    
    self.networkActivityIndicator = [NetworkActivityIndicator new];
}

- (void)restClient:(DBRestClient*)client uploadProgress:(CGFloat)progress
           forFile:(NSString*)destPath from:(NSString*)srcPath;
{
    // LOG(@"DropboxUploader.restClient:uploadProgress");
    self.uploadingFile.progress = progress;
}

- (void)restClient:(DBRestClient*)client uploadedFile:(NSString*)destPath from:(NSString*)srcPath
{
    self.uploadingFile.uploaded = YES;
    self.uploadingFile.progress = 0.0;
    [self readyToUpload];
}

- (void)restClient:(DBRestClient*)client uploadFileFailedWithError:(NSError*)error
{
    self.uploadingFile.progress = error.code * -1.0;
    [self readyToUpload];
}

- (void)readyToUpload
{
    if (self.uploadingFile != nil) {
        self.uploadingFile.uploading = NO;
        self.uploadingFile = nil;
    }
    
    self.networkActivityIndicator = nil;
    
    [self.monitor readyToUpload];
}

@end
