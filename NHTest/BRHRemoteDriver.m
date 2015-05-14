//
//  BRHRemoteDriver.m
//  NHTest
//
//  Created by Brad Howes on 2/13/15.
//  Copyright (c) 2015 Brad Howes. All rights reserved.
//

#import "BRHLogger.h"
#import "BRHRemoteDriver.h"

typedef void (^BRHCompletionHandler)(void);

@interface BRHRemoteDriver () <NSURLSessionDelegate, NSURLSessionTaskDelegate, NSURLSessionDataDelegate>
@property (nonatomic, strong) NSURL *url;
@property (nonatomic, strong) NSString *deviceToken;
@property (nonatomic, strong, getter=getSession) NSURLSession *session;
@property (nonatomic, copy) BRHCompletionHandler savedCompletionHandler;
@end

@implementation BRHRemoteDriver

- (id)initWithURL:(NSURL*)url deviceToken:(NSString*)deviceToken
{
    self = [super init];
    if (self) {
        _url = url;
        _deviceToken = deviceToken;
        _session = nil;
        _savedCompletionHandler = NULL;
    }

    return self;
}

- (NSURLSession*)getSession
{
    if (! _session) {
        NSURLSessionConfiguration* sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
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

- (void)postRegistration
{
    NSLog(@"postRegistration");

    NSURL *url = [NSURL URLWithString:@"/register" relativeToURL:self.url];
    NSLog(@"URL: %@", url.absoluteString);

    NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
    NSInteger interval = [settings integerForKey:@"emitInterval"];

    NSDictionary* dict = @{@"deviceToken": self.deviceToken,
                           @"interval": [NSNumber numberWithInteger:interval]};

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

    NSURLSessionUploadTask *task = [self.session uploadTaskWithRequest:request fromData:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            NSLog(@"failed: %@", error);
        }
        else {
            NSHTTPURLResponse *r = (NSHTTPURLResponse*)response;
            NSLog(@"response: %@", r);
            NSString *serverWhen = r.allHeaderFields[@"x-when"];
            self.serverWhen = [serverWhen doubleValue];
            self.deviceOffset = [[NSDate date] timeIntervalSince1970] - self.serverWhen;
            NSLog(@"deviceOffset: %f", self.deviceOffset);
        }
    }];

    [task resume];
}

- (void)deleteRegistration
{
    NSLog(@"deleteRegistration");

    NSURL *url = [NSURL URLWithString:@"/unregister" relativeToURL:self.url];
    NSLog(@"URL: %@", url.absoluteString);

    NSDictionary *dict = @{@"deviceToken": self.deviceToken};

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
    
    NSURLSessionUploadTask *task = [self.session uploadTaskWithRequest:request fromData:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSHTTPURLResponse *r = (NSHTTPURLResponse*)response;
        NSLog(@"response: %@", r);
    }];
    
    [task resume];
}

- (void)fetchMessage:(NSInteger)msgId withCompletionHandler:(BRHRemoteDriverFetchCompletionBlock)completionHandler
{
    NSLog(@"fetchMessage");
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"/fetch/%@/%ld", self.deviceToken, (long)msgId] relativeToURL:self.url];
    NSLog(@"URL: %@", url);

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSHTTPURLResponse *r = (NSHTTPURLResponse*)response;
        NSLog(@"response: %@", r);
        if (r.statusCode == 200) {
            NSDictionary *payload = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
            NSString* msg = [payload objectForKey:@"msg"];
            completionHandler(true, msg != nil);
        }
        else {
            completionHandler(false, false);
        }
    }];

    [task resume];
}

- (void)updateWithCompletionHandler:(BRHRemoteDriverFetchCompletionBlock)completionHandler
{
    NSLog(@"updateWithMessage");
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"/update/%@", self.deviceToken] relativeToURL:self.url];
    NSLog(@"URL: %@", url);

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSHTTPURLResponse *r = (NSHTTPURLResponse*)response;
        NSLog(@"response: %@", r);
        if (r.statusCode == 200) {
            NSArray *updates = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
            NSString* msg = nil;
            for (msg in updates) NSLog(@"%@", msg);
            completionHandler(true, msg != nil);
        }
        else {
            completionHandler(false, false);
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
    _savedCompletionHandler = completionHandler;
}

@end
