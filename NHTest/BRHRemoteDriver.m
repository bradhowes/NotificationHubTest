//
//  BRHRemoteDriver.m
//  NHTest
//
//  Created by Brad Howes on 2/13/15.
//  Copyright (c) 2015 Brad Howes. All rights reserved.
//

#import <objc/runtime.h>

#import "BRHEventLog.h"
#import "BRHLatencySample.h"
#import "BRHLogger.h"
#import "BRHRemoteDriver.h"
#import "BRHUserSettings.h"

typedef void (^BRHBackgroundCompletionHandler)(void);
typedef void (^BRHFetchCompletionHandler)(UIBackgroundFetchResult);

static NSString *taskRegister = @"register";
static NSString *taskUnregister = @"unregister";
static NSString *taskFetch = @"fetch";

@interface BRHRemoteDriver () <NSURLSessionDelegate, NSURLSessionTaskDelegate, NSURLSessionDataDelegate, NSURLSessionDownloadDelegate>

@property (strong, nonatomic) NSURL *url;
@property (strong, nonatomic) NSURLSession *foregroundSession;
@property (strong, nonatomic) NSURLSession *fetchSession;
@property (strong, nonatomic) NSString *deviceTokenAsString;
@property (copy, nonatomic) BRHBackgroundCompletionHandler savedBackgroundCompletionHandler;
@property (copy, nonatomic) BRHFetchCompletionHandler savedFetchCompletionHandler;

- (void)estimateClockOffset:(NSData *)response requestStartTime:(double )requestStartTime requestEndTime:(double )requestEndTime;

@end

@implementation BRHRemoteDriver

- (instancetype)init
{
    self = [super init];
    if (self) {
        _url = [BRHUserSettings userSettings].remoteServerURL;
        _foregroundSession = nil;
        _fetchSession = nil;
        _deviceTokenAsString = nil;
        _savedBackgroundCompletionHandler = nil;
    }

    return self;
}

- (NSString *)deviceTokenAsString
{
    if (! _deviceTokenAsString && self.deviceToken) {
        _deviceTokenAsString = [self.deviceToken base64EncodedStringWithOptions:0];
    }
    
    return _deviceTokenAsString;
}

- (NSURLSession *)foregroundSession
{
    if (! _foregroundSession) {
        NSURLSessionConfiguration *sessionConfig = [NSURLSessionConfiguration ephemeralSessionConfiguration];
        NSOperationQueue *queue = [NSOperationQueue mainQueue];
        _foregroundSession = [NSURLSession sessionWithConfiguration:sessionConfig delegate:self delegateQueue:queue];
    }

    return _foregroundSession;
}

- (NSURLSession *)fetchSession
{
    if (! _fetchSession) {
        NSURLSessionConfiguration *sessionConfig = [NSURLSessionConfiguration ephemeralSessionConfiguration];
        sessionConfig.timeoutIntervalForRequest = 25;
        _fetchSession = [NSURLSession sessionWithConfiguration:sessionConfig delegate:self delegateQueue:nil];
    }
    
    return _fetchSession;
}

- (void)estimateClockOffset:(NSData *)response requestStartTime:(double )requestStartTime requestEndTime:(double )requestEndTime
{
    NSError *error = nil;
    NSString *body = [[NSString alloc] initWithData:response encoding:NSUTF8StringEncoding];
    NSLog(@"estimateClockOfset - body: %@", body);

    NSDictionary *timing = [NSJSONSerialization JSONObjectWithData:response options:kNilOptions error:&error];
    if (error) {
        NSLog(@"failed to process body for JSON - %@", body);
        NSLog(@"error: %@", error.description);
        return;
    }

    // Total time measured by request is Tr = requestEndTime - requestStartTime.
    // Total time taken by server processing request is Ts = serverEndTime - serverStartTime
    // Total network transit time is roughly calculated as Tn * 2 = Tr - Ts
    // Offset between server and phone clock is estimated as To = requestStartTime + Tn - serverStartTime

    NSLog(@"requestStartTime: %f", requestStartTime);
    NSLog(@"requestEndTime: %f", requestEndTime);
    double Tr = requestEndTime - requestStartTime;
    NSLog(@"delta request: %f", Tr);

    double serverStartTime = ((NSNumber *)timing[@"startTime"]).doubleValue;
    NSLog(@"severStartTime: %f", serverStartTime);
        double serverEndTime = ((NSNumber *)timing[@"endTime"]).doubleValue;
    NSLog(@"severEndTime: %f", serverEndTime);
    
    double Ts = serverEndTime - serverStartTime;
    NSLog(@"delta server: %f", Ts);

    double Tn = (Tr - Ts) / 2.0;
    NSLog(@".5 network: %f", Tn);

    double To = requestStartTime + Tn - serverStartTime;
    NSLog(@"To: %f", To);

    [BRHLogger add:@"estimateClockOffset - %f -- Tr: %f Ts: %f Tn: %f", To, Tr, Ts, Tn];
    [BRHEventLog add:@"estimateClockOffset", @(To), @(serverStartTime), @(serverEndTime), @(requestStartTime), @(requestEndTime), nil];

    self.deviceServerDelta = To;
}

- (void)startEmitting:(NSNumber *)emitInterval completionBlock:(BRHNotificationDriverStartCompletionBlock )completionBlock
{
    [super startEmitting:emitInterval];

    NSURL *url = [NSURL URLWithString:@"/register" relativeToURL:self.url];
    NSLog(@"URL: %@", url.absoluteString);

    BRHUserSettings *settings = [BRHUserSettings userSettings];
    NSDictionary *dict = @{@"deviceToken": self.deviceTokenAsString, @"interval": emitInterval,
                           @"retryUntilFetched":settings.retryUntilFetched};
    NSLog(@"dict: %@", dict);

    NSError *error = nil;
    NSData *body = [NSJSONSerialization dataWithJSONObject:dict options:0 error:&error];
    if (error) {
        NSLog(@"dataWithJSONObject: %@", [error description]);
        completionBlock(NO);
        return;
    }

    [BRHLogger add:@"payload: %@", [[NSString alloc] initWithData:body encoding:NSUTF8StringEncoding]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url.absoluteURL];

    request.HTTPMethod = @"POST";
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[NSString stringWithFormat:@"%ld", (unsigned long)[body length]] forHTTPHeaderField:@"Content-Length"];
    request.HTTPBody = body;

    [BRHEventLog add:@"registering", [dict objectForKey:@"interval"], nil];

    double requestStartTime = [[NSDate date] timeIntervalSince1970];
    NSURLSessionUploadTask *task = [self.foregroundSession uploadTaskWithRequest:request fromData:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            [BRHEventLog add:@"failedRegister", error.description, nil];
            [BRHLogger add:@"failed to register - %@", error.description];
            completionBlock(NO);
            return;
        }

        double requestEndTime = [[NSDate date] timeIntervalSince1970];
        NSHTTPURLResponse *r = (NSHTTPURLResponse *)response;
        NSLog(@"response: %@", r);
        [self estimateClockOffset:data requestStartTime:requestStartTime requestEndTime:requestEndTime];
        [BRHLogger add:@"registered"];
        [BRHEventLog add:@"registered", nil];
        completionBlock(YES);
    }];

    [task resume];
}

- (void)sendStopEmittingRequest
{
    NSURL *url = [NSURL URLWithString:@"/unregister" relativeToURL:self.url];
    NSLog(@"URL: %@", url.absoluteString);

    NSDictionary *dict = @{@"deviceToken":self.deviceTokenAsString};
    
    NSError *error = nil;
    NSData *body = [NSJSONSerialization dataWithJSONObject:dict options:0 error:&error];
    if (error) {
        NSLog(@"dataWithJSONObject: %@", [error description]);
        return;
    }

    NSLog(@"payload: %@", [[NSString alloc] initWithData:body encoding:NSUTF8StringEncoding]);
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url.absoluteURL];
    request.HTTPMethod = @"POST";
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[NSString stringWithFormat:@"%ld", (unsigned long)[body length]] forHTTPHeaderField:@"Content-Length"];
    request.HTTPBody = body;
    
    [BRHEventLog add:@"unregistering", nil];
    
    double requestStartTime = [[NSDate date] timeIntervalSince1970];
    NSURLSessionUploadTask *task = [self.foregroundSession uploadTaskWithRequest:request fromData:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            [BRHEventLog add:@"failedUnregister", error.description, nil];
            [BRHLogger add:@"failed unregister - %@", error.description];
            [self sendStopEmittingRequest];
            return;
        }

        double requestEndTime = [[NSDate date] timeIntervalSince1970];
        NSHTTPURLResponse *r = (NSHTTPURLResponse *)response;
        NSLog(@"response: %@", r);
        [self estimateClockOffset:data requestStartTime:requestStartTime requestEndTime:requestEndTime];
        [BRHLogger add:@"unregistered"];
        [BRHEventLog add:@"unregistered", nil];
    }];
    
    [task resume];
}

- (void)stopEmitting
{
    [self sendStopEmittingRequest];
    [super stopEmitting];
}

/*!
 *    @brief Revise latency calculaton by taking into account any offset between remote server clock and our own.
 *
 *    @param sample the data to work with and manipulate
 */
- (NSTimeInterval)calculateLatency:(BRHLatencySample *)sample
{
    return [super calculateLatency:sample] - self.deviceServerDelta;
}

/*!
 *    @brief  Fetch info from remote server related to the last notification we received.
 *
 *    @param notification the notification contents
 *    @param completionHandler the handler to invoke when the fetch is complete
 */
- (void)fetchUpdate:(NSDictionary *)notification fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
    [BRHLogger add:@"fetchUpdate"];

    NSNumber* identifier = notification[@"id"];
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"/fetch/%@/%lu", self.deviceTokenAsString, (unsigned long)identifier.integerValue] relativeToURL:self.url];
    NSLog(@"URL: %@", url);

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url.absoluteURL];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];

    [BRHEventLog add:@"fetchUpdate", identifier, nil];

    double requestStartTime = [[NSDate date] timeIntervalSince1970];
    NSURLSessionDataTask *task = [self.fetchSession dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            [BRHLogger add:@"failed fetch task - %@", error.description];
            [BRHEventLog add:@"failedTask", error.description, nil];
            completionHandler(UIBackgroundFetchResultFailed);
        }
        else {
            double requestEndTime = [[NSDate date] timeIntervalSince1970];
            NSHTTPURLResponse *r = (NSHTTPURLResponse *)response;
            NSLog(@"response: %@", r);
            [self estimateClockOffset:data requestStartTime:requestStartTime requestEndTime:requestEndTime];
            [BRHLogger add:@"completed fetch task"];
            [BRHEventLog add:@"finishedFetch", nil];
            completionHandler(UIBackgroundFetchResultNewData);
        }
    }];

    [task resume];
}

- (void)handleEventsForBackgroundURLSession:(NSString *)identifier completionHandler:(void (^)())completionHandler
{
    if ([identifier isEqualToString:@"fetchSession"]) {
        [self fetchSession];
        _savedBackgroundCompletionHandler = completionHandler;
    }
    else {
        completionHandler();
    }
}

- (void)URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)session
{
    NSLog(@"URLSessionDidFinishEventsForBackgroundURLSession");
    [BRHLogger add:@"URLSessionDidFinishEventsForBackgroundURLSession"];
    BRHBackgroundCompletionHandler handler = _savedBackgroundCompletionHandler;
    _savedBackgroundCompletionHandler = NULL;
    if (handler) {
        [[NSOperationQueue mainQueue] addOperationWithBlock:handler];
    }
}

#pragma mark - Session Delegate Methods

- (void)URLSession:(NSURLSession *)session didBecomeInvalidWithError:(NSError *)error
{
    [BRHLogger add:@"didBecomeInvalidWithError - %@", error];
    if (session == _fetchSession) {
        self.fetchSession = nil;
    }
    
    if (session == _foregroundSession) {
        self.foregroundSession = nil;
    }
}

- (void)URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential *))completionHandler
{
    completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
}

#pragma mark - Task Delegate Methods

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didSendBodyData:(int64_t)bytesSent totalBytesSent:(int64_t)totalBytesSent totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend
{
    NSLog(@"task didSendBodyData - %lld", bytesSent);
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    [BRHLogger add:@"task didCompleteWithError: %@", error ? error.description : @"None"];
    BRHFetchCompletionHandler handler = _savedFetchCompletionHandler;
    _savedFetchCompletionHandler = NULL;
    if (error && handler) {
        [BRHLogger add:@"failed fetch task - %@", error.description];
        [BRHEventLog add:@"failedTask", error.description, nil];
        handler(UIBackgroundFetchResultFailed);
    }
}

# pragma mark - Download Task Delegate Methods

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didResumeAtOffset:(int64_t)fileOffset expectedTotalBytes:(int64_t)expectedTotalBytes
{
    [BRHLogger add:@"downloadTask didResume"];
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
    [BRHLogger add:@"downloadTask didWriteData"];
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location
{
    [BRHLogger add:@"downloadTask didFinishDownloadingToURL: %@", location.absoluteString];
    BRHFetchCompletionHandler handler = _savedFetchCompletionHandler;
    _savedFetchCompletionHandler = NULL;
    if (handler) {
        handler(UIBackgroundFetchResultNewData);
    }
}

@end
