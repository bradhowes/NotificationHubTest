//
//  BRHRemoteDriver.m
//  NHTest
//
//  Created by Brad Howes on 2/13/15.
//  Copyright (c) 2015 Brad Howes. All rights reserved.
//

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

@interface NSURLSessionDataTask (BRH)
@property (copy, nonatomic) BRHFetchCompletionHandler fetchCompletionHandler;
@end

@implementation NSURLSessionDataTask (BRH)
@dynamic fetchCompletionHandler;
@end

@interface BRHRemoteDriver () <NSURLSessionDelegate, NSURLSessionTaskDelegate, NSURLSessionDataDelegate>
@property (strong, nonatomic) NSURL *url;
@property (strong, nonatomic) NSURLSession *foregroundSession;
@property (strong, nonatomic) NSURLSession *fetchSession;
@property (strong, nonatomic) NSString *deviceTokenAsString;
@property (copy, nonatomic) BRHBackgroundCompletionHandler savedBackgroundCompletionHandler;

@property (strong, nonatomic) NSDate *requestStartTime;

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

- (void)estimateClockOffset:(NSDictionary *)headers requestEndTime:(double )requestEndTime
{
    NSString *serverStartTimeString = headers[@"X-StartTime"];
    NSString *serverEndTimeString = headers[@"X-EndTime"];

    double serverStartTime = serverStartTimeString.doubleValue;
    double serverEndTime = serverEndTimeString.doubleValue;

    double requestStartTime = [self.requestStartTime timeIntervalSince1970];
    
    // Total time measured by request is Tr = requestEndTime - requestStartTime.
    // Total time taken by server processing request is Ts = serverEndTime - serverStartTime
    // Total network transit time is roughly calculated as Tn * 2 = Tr - Ts
    // Offset between server and phone clock is estimated as To = requestStartTime + Tn - serverStartTime

    double Tr = requestEndTime - requestStartTime;
    double Ts = serverEndTime - serverStartTime;
    double Tn = (Tr - Ts) / 2.0;
    double To = requestStartTime + Tn - serverStartTime;

    NSLog(@"estimateClockOffset - %f -- Tr: %f Ts: %f Tn: %f", To, Tr, Ts, Tn);

    [BRHLogger add:@"estimateClockOffset - %f -- Tr: %f Ts: %f Tn: %f", To, Tr, Ts, Tn];
    [BRHEventLog add:@"estimateClockOffset", @(To), serverStartTimeString, serverEndTimeString, @(requestStartTime), @(requestEndTime), nil];

    self.deviceServerDelta = To;
}

- (void)startEmitting:(NSNumber *)emitInterval completionBlock:(BRHNotificationDriverStartCompletionBlock )completionBlock
{
    [super startEmitting:emitInterval];

    NSURL *url = [NSURL URLWithString:@"/register" relativeToURL:self.url];
    NSLog(@"URL: %@", url.absoluteString);

    NSDictionary *dict = @{@"deviceToken": self.deviceTokenAsString, @"interval": emitInterval};
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

    NSURLSessionUploadTask *task = [self.foregroundSession uploadTaskWithRequest:request fromData:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            [BRHEventLog add:@"failedRegister", error.description, nil];
            [BRHLogger add:@"failed register - %@", error.description];
            completionBlock(NO);
            return;
        }

        double requestEndTime = [[NSDate date] timeIntervalSince1970];

        NSHTTPURLResponse *r = (NSHTTPURLResponse *)response;
        NSLog(@"response: %@", r);

        [self estimateClockOffset:r.allHeaderFields requestEndTime:requestEndTime];

        [BRHLogger add:@"registered"];
        [BRHEventLog add:@"registered", nil];

        completionBlock(YES);
    }];

    task.taskDescription = taskRegister;
    self.requestStartTime = [NSDate date];

    [task resume];
}

- (void)stopEmitting:(BRHNotificationDriverStopCompletionBlock )completionBlock
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

    NSURLSessionUploadTask *task = [self.foregroundSession uploadTaskWithRequest:request fromData:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            [BRHEventLog add:@"failedUnregister", error.description, nil];
            [BRHLogger add:@"failed unregister - %@", error.description];
            completionBlock(NO);
            return;
        }

        double requestEndTime = [[NSDate date] timeIntervalSince1970];

        NSHTTPURLResponse *r = (NSHTTPURLResponse *)response;
        NSLog(@"response: %@", r);

        [self estimateClockOffset:r.allHeaderFields requestEndTime:requestEndTime];

        [BRHLogger add:@"unregistered"];
        [BRHEventLog add:@"unregistered", nil];

        completionBlock(YES);
    }];

    task.taskDescription = taskUnregister;
    self.requestStartTime = [NSDate date];

    [task resume];
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

    NSURLSessionDataTask *task = [self.fetchSession dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        double requestEndTime = [[NSDate date] timeIntervalSince1970];
        if (error) {
            [BRHLogger add:@"failed fetch task - %@", error.description];
            [BRHEventLog add:@"failedTask", error.description, nil];
            completionHandler(UIBackgroundFetchResultFailed);
        }
        else {
            [BRHLogger add:@"completed fetch task"];
            [BRHEventLog add:@"finishedFetch", nil];
            NSHTTPURLResponse *r = (NSHTTPURLResponse *)response;
            NSLog(@"response: %@", r);
            [self estimateClockOffset:r.allHeaderFields requestEndTime:requestEndTime];
            completionHandler(UIBackgroundFetchResultNewData);
        }
    }];

    self.requestStartTime = [NSDate date];
    [task resume];
}

#pragma mark NSURLSession Delegate Methods

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

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didSendBodyData:(int64_t)bytesSent totalBytesSent:(int64_t)totalBytesSent totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend
{
    NSLog(@"task didSendBodyData - %lld", bytesSent);
    self.requestStartTime = [NSDate date];
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

@end
