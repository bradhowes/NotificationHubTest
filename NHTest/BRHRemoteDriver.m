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

typedef void (^BRHCompletionHandler)(void);
typedef void (^BRHRemoteDriverFetchCompletionHandler)(BOOL, BOOL);

@interface BRHRemoteDriver () <NSURLSessionDelegate, NSURLSessionTaskDelegate, NSURLSessionDataDelegate>
@property (strong, nonatomic) NSURL *url;
@property (strong, nonatomic) NSURLSession *session;
@property (strong, nonatomic) NSString *deviceTokenAsString;
@property (copy, nonatomic) BRHCompletionHandler savedCompletionHandler;

@end

@implementation BRHRemoteDriver

- (instancetype)init
{
    self = [super init];
    if (self) {
        _url = [BRHUserSettings userSettings].remoteServerURL;
        _session = nil;
        _deviceTokenAsString = nil;
        _savedCompletionHandler = NULL;
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

- (NSURLSession *)session
{
    if (! _session) {
        NSURLSessionConfiguration *sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
        sessionConfig.allowsCellularAccess = YES;
        sessionConfig.HTTPCookieStorage = nil;
        sessionConfig.HTTPCookieAcceptPolicy = NSHTTPCookieAcceptPolicyNever;
        sessionConfig.HTTPShouldSetCookies = NO;
        sessionConfig.sessionSendsLaunchEvents = NO;
        sessionConfig.discretionary = YES;
        _session = [NSURLSession sessionWithConfiguration:sessionConfig delegate:self delegateQueue:[NSOperationQueue mainQueue]];
    }

    return _session;
}

- (BOOL)startEmitting:(NSNumber *)emitInterval
{
    if (! [super startEmitting:emitInterval]) return NO;

    NSURL *url = [NSURL URLWithString:@"/register" relativeToURL:self.url];
    NSLog(@"URL: %@", url.absoluteString);

    NSDictionary *dict = @{@"deviceToken": self.deviceTokenAsString, @"interval": emitInterval};
    NSLog(@"dict: %@", dict);

    NSError *error = nil;
    NSData *body = [NSJSONSerialization dataWithJSONObject:dict options:0 error:&error];
    if (error) {
        NSLog(@"dataWithJSONObject: %@", [error description]);
        return NO;
    }

    [BRHLogger add:@"payload: %@", [[NSString alloc] initWithData:body encoding:NSUTF8StringEncoding]];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url.absoluteURL];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[NSString stringWithFormat:@"%ld", (unsigned long)[body length]] forHTTPHeaderField:@"Content-Length"];
    [request setHTTPBody:body];

    [BRHEventLog add:@"registering", [dict objectForKey:@"interval"], nil];

    NSURLSessionUploadTask *task = [self.session uploadTaskWithRequest:request fromData:body completionHandler:^(NSData* data, NSURLResponse* response, NSError* error) {
        if (error) {
            [BRHEventLog add:@"registering failed", [error description], nil];
            NSLog(@"failed: %@", error);
        }
        else {
            NSDate *now = [NSDate date];
            NSHTTPURLResponse *r = (NSHTTPURLResponse *)response;
            NSLog(@"response: %@", r);
            NSString *serverWhen = r.allHeaderFields[@"x-when"];
            self.serverWhen = [serverWhen doubleValue];
            self.deviceServerDelta = [now timeIntervalSince1970] - self.serverWhen;
            NSLog(@"deviceServerDelta: %lf", self.deviceServerDelta);
            [BRHEventLog add:@"regsitered", serverWhen, @(self.deviceServerDelta), nil];
        }
    }];

    [task resume];
    
    return YES;
}

- (void)stopEmitting
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
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[NSString stringWithFormat:@"%ld", (unsigned long)[body length]] forHTTPHeaderField:@"Content-Length"];
    [request setHTTPBody:body];
    
    [BRHEventLog add:@"unregistering", nil];
    NSURLSessionUploadTask *task = [self.session uploadTaskWithRequest:request fromData:body completionHandler:^(NSData* data, NSURLResponse* response, NSError* error) {
        if (error) {
            [BRHEventLog add:@"unregistering failed", [error description], nil];
            NSLog(@"failed: %@", error);
        }
        else {
            NSHTTPURLResponse *r = (NSHTTPURLResponse *)response;
            NSLog(@"response: %@", r);
            [BRHEventLog add:@"unregsitered", nil];
        }
    }];
    
    [task resume];

    [super stopEmitting];
}

- (BRHLatencySample *)receivedNotification:(NSDictionary *)userInfo at:(NSDate *)when fetchCompletionHandler:(void (^)(UIBackgroundFetchResult) )completionHandler
{
    BRHLatencySample *sample = [super receivedNotification:userInfo at:when fetchCompletionHandler:completionHandler];
    return sample;
}

- (void)calculateLatency:(BRHLatencySample *)sample
{
    [super calculateLatency:sample];
    sample.latency = [NSNumber numberWithDouble:(sample.latency.doubleValue - self.deviceServerDelta)];
}

- (void)fetchUpdate:(NSDictionary *)notification fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
    [BRHLogger add:@"fetchUpdate"];

    NSNumber* identifier = notification[@"id"];
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"/fetch/%@/%lu", self.deviceTokenAsString, (unsigned long)identifier.integerValue] relativeToURL:self.url];
    NSLog(@"URL: %@", url);

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];

    [BRHEventLog add:@"fetching", identifier, nil];
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request completionHandler:^(NSData* data, NSURLResponse* response, NSError* error) {
        NSHTTPURLResponse *r = (NSHTTPURLResponse *)response;
        [BRHLogger add:@"%@ - %@", url.absoluteString, r];
        if (r.statusCode == 200) {
            NSDictionary *payload = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
            NSString *msg = [payload objectForKey:@"msg"];
            [BRHEventLog add:@"fetched", msg, nil];
            completionHandler(msg ? UIBackgroundFetchResultNewData : UIBackgroundFetchResultNoData);
        }
        else {
            [BRHEventLog add:@"fetch failed", @(r.statusCode), nil];
            completionHandler(UIBackgroundFetchResultFailed);
        }
    }];

    [task resume];
}

#pragma mark Delegates

- (void)URLSession:(NSURLSession *)session didBecomeInvalidWithError:(NSError *)error
{
    NSLog(@"didBecomeInvalidWithError: %@", error);
    self.session = nil;
}

- (void)URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential *))completionHandler
{
    completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
}

- (void)URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)session
{
    [BRHLogger add:@"URLSessionDidFinishEventsForBackgroundURLSession"];
    BRHCompletionHandler handler = _savedCompletionHandler;
    _savedCompletionHandler = NULL;
    if (handler) {
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            handler();
         }];
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didSendBodyData:(int64_t)bytesSent totalBytesSent:(int64_t)totalBytesSent totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend
{
    ;
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
    ;
}

- (void)handleEventsForBackgroundURLSession:(NSString *)identifier completionHandler:(void (^)())completionHandler
{
    [BRHLogger add:@"handleEventsForBackgroundURLSession - %@", identifier];
    _savedCompletionHandler = completionHandler;
}

@end
