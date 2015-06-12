//  BRHAPNsClient.h
//  NHTest
//
//  Copyright (C) 2015 Brad Howes. All rights reserved.

#import <Foundation/Foundation.h>

/*!
 @brief Delegate definition for BRHAPNsClient class
 */
@protocol BRHAPNsClientDelegate

/*!
 @brief Notify the delegate after sending a push notification to APNs.
 
 @param identifier the unique identifier of the push notification
 */
- (void)sentNotification:(NSInteger)identifier;

@end

/*!
 @brief Generates push notifications payloads for APNs
 */
@interface BRHAPNsClient : NSObject

/*!
 @brief The delegate assigned to the instance.
 */
@property (weak, nonatomic) id <BRHAPNsClientDelegate> delegate;

/*!
 @brief True if using the APNs sandbox environment instead of production
 */
@property (assign, getter = isSandbox, nonatomic) BOOL sandbox;

/*!
 @brief Class method to obtain the APNs host name
 
 @param inSandbox if YES return the sandbox host
 
 @result host name
 */
+ (NSString *)host:(BOOL)inSandbox;

/*!
 @brief Instance initializer
 
 @param theIdentity the certificate to use when communicating with APNs
 @param deviceToken the APNs device token to use when sending push notifications
 @param sandbox if True, use the APNs sandbox environment instead of production
 
 @result initialized instance
 */

- (instancetype)initWithIdentity:(SecIdentityRef)theIdentity deviceToken:(NSData *)deviceToken sandbox:(BOOL)sandbox;

/*!
 @brief Emit an APNs push notification with the given payload and message identifier
 
 @param payload the contents of the message to push (must be valid JSON)
 @param identifier the unique identifier for this notification
 */
- (void)pushPayload:(NSString *)payload identifier:(NSInteger)identifier;

@end
