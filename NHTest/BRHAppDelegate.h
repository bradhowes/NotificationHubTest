//  BRHAppDelegate.h
//  NHTest
//
//  Copyright (C) 2015 Brad Howes. All rights reserved.

#import <UIKit/UIKit.h>

@class BRHNotificationDriver;
@class BRHUserSettings;
@class BRHRunData;
@class BRHNotificationDriver;
@class BRHRecordingInfo;

/*!
 * @brief Application delegate for NHTest app.
 */
@interface BRHAppDelegate : UIResponder <UIApplicationDelegate>

/*!
 * @brief The main window of the app.
 */
@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) NSData *deviceToken;
@property (strong, nonatomic) BRHNotificationDriver *driver;
@property (strong, nonatomic) BRHRunData *runData;
@property (assign, nonatomic) BOOL running;

@property (strong, readonly, nonatomic) NSManagedObjectContext *managedObjectContext;

- (BRHRunData *)startRun;

- (void)stopRun;

- (void)deleteRecording:(BRHRecordingInfo *)recordingInfo;

- (void)selectRecording:(BRHRecordingInfo *)recordingInfo;

@end
