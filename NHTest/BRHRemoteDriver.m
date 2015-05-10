//
//  BRHRemoteDriver.m
//  NHTest
//
//  Created by Brad Howes on 2/13/15.
//  Copyright (c) 2015 Brad Howes. All rights reserved.
//

#import "BRHRemoteDriver.h"

@interface BRHRemoteDriver () <NSURLSessionDelegate, NSURLSessionTaskDelegate, NSURLSessionDataDelegate>
@property (nonatomic, strong) NSData* deviceToken;
@property (nonatomic, strong) NSURLSession* session;
@property (nonatomic, strong) NSString* host;
@property (nonatomic, assign) int port;
@property (nonatomic, copy) void (^savedCompletionHandler)(void);
@end

@implementation BRHRemoteDriver

- (id)initWithDeviceToken:(NSData*)deviceToken host:(NSString*)host port:(int)port
{
    self = [super init];
    if (self) {
        self.deviceToken = deviceToken;
        self.host = host;
        self.port = port;

        NSURLSessionConfiguration* sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
        sessionConfig.allowsCellularAccess = YES;
        sessionConfig.HTTPCookieStorage = nil;
        sessionConfig.HTTPCookieAcceptPolicy = NSHTTPCookieAcceptPolicyNever;
        sessionConfig.HTTPShouldSetCookies = NO;
        sessionConfig.sessionSendsLaunchEvents = NO;
        sessionConfig.discretionary = YES;

        self.session = [NSURLSession sessionWithConfiguration:sessionConfig delegate:self delegateQueue:[NSOperationQueue mainQueue]];
    }

    return self;
}

- (void)postRegistration
{
    NSLog(@"postRegistration");

    NSURL* url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@:%d/register", self.host, self.port]];
    NSLog(@"URL: %@", url);

    NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
    NSInteger interval = [settings integerForKey:@"emitInterval"];

    NSDictionary* dict = @{@"deviceToken": [self.deviceToken base64EncodedStringWithOptions:0],
                           @"interval": [NSNumber numberWithInteger:interval]};

    NSError* error = nil;
    NSData* body = [NSJSONSerialization dataWithJSONObject:dict options:0 error:&error];
    if (error) {
        NSLog(@"dataWithJSONObject: %@", [error description]);
        return;
    }

    NSLog(@"payload: %@", [[NSString alloc] initWithData:body encoding:NSUTF8StringEncoding]);

    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[NSString stringWithFormat:@"%ld", (unsigned long)[body length]] forHTTPHeaderField:@"Content-Length"];
    [request setHTTPBody:body];

    NSURLSessionUploadTask* task = [self.session uploadTaskWithRequest:request fromData:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSHTTPURLResponse* r = (NSHTTPURLResponse*)response;
        NSString* serverWhen = r.allHeaderFields[@"x-when"];
        self.serverWhen = [serverWhen doubleValue];
        self.deviceOffset = [[NSDate date] timeIntervalSince1970] - self.serverWhen;
    }];

    [task resume];
}

- (void)deleteRegistration
{
    NSLog(@"deleteRegistration");
    
    NSURL* url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@:%d/unregister", self.host, self.port]];
    NSLog(@"URL: %@", url);

    NSDictionary* dict = @{@"deviceToken": [self.deviceToken base64EncodedStringWithOptions:0]};
    
    NSError* error = nil;
    NSData* body = [NSJSONSerialization dataWithJSONObject:dict options:0 error:&error];
    if (error) {
        NSLog(@"dataWithJSONObject: %@", [error description]);
        return;
    }
    
    NSLog(@"payload: %@", [[NSString alloc] initWithData:body encoding:NSUTF8StringEncoding]);
    
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[NSString stringWithFormat:@"%ld", (unsigned long)[body length]] forHTTPHeaderField:@"Content-Length"];
    [request setHTTPBody:body];
    
    NSURLSessionUploadTask* task = [self.session uploadTaskWithRequest:request fromData:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSHTTPURLResponse* r = (NSHTTPURLResponse*)response;
        NSLog(@"response: %@", r);
    }];
    
    [task resume];
}

#pragma mark Delegates

- (void)URLSession:(NSURLSession *)session didBecomeInvalidWithError:(NSError *)error
{
    ;
}

- (void)URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential *))completionHandler
{
    completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
}

- (void)URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)session
{
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        self.savedCompletionHandler();
    }];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didSendBodyData:(int64_t)bytesSent totalBytesSent:(int64_t)totalBytesSent totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend
{
    ;
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
    ;
}

@end
