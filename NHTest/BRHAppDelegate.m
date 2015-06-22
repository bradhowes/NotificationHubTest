//
//  BRHAppDelegate.m
//  HelloWorld
//
//  Created by Brad Howes on 12/21/13.
//  Copyright (c) 2013 Brad Howes. All rights reserved.
//

#import <DropboxSDK/DropboxSDK.h>

#import "BRHAppDelegate.h"
#import "BRHDropboxUploader.h"
#import "BRHEventLog.h"
#import "BRHLogger.h"
#import "BRHLoopNotificationDriver.h"
#import "BRHMainViewController.h"
#import "BRHLatencySample.h"
#import "BRHNotificationDriver.h"
#import "BRHRecordingInfo.h"
#import "BRHRecordingsViewController.h"
#import "BRHRunData.h"
#import "BRHRemoteDriver.h"
#import "BRHSimDriver.h"
#import "BRHUserSettings.h"

#import "dbconfig.h"
#import "Reachability.h"

static NSString* rootFolder = @"/NHTest";
static void* kKVOContext = &kKVOContext;

@interface BRHAppDelegate () <DBSessionDelegate>

@property (strong, nonatomic, readonly) NSManagedObjectModel *managedObjectModel;
@property (strong, nonatomic, readonly) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (strong, nonatomic, readonly) NSFetchedResultsController *fetchedResultsController;
@property (weak, nonatomic) BRHMainViewController *mainViewController;
@property (strong, nonatomic) BRHRecordingInfo *recordingInfo;
@property (strong, nonatomic) DBSession *session;
@property (strong, nonatomic) Reachability *reachability;

- (NSURL *)applicationDocumentsDirectory;
- (void)setupDropbox;
- (void)saveContext;
- (void)batteryStateChanged:(NSNotification *)notification;
- (NSString *)batteryStateString:(UIDeviceBatteryState)batteryState;

@end

@implementation BRHAppDelegate

@synthesize managedObjectModel=_managedObjectModel, managedObjectContext=_managedObjectContext, persistentStoreCoordinator=_persistentStoreCoordinator, fetchedResultsController=_fetchedResultsController;

- (NSURL *)applicationDocumentsDirectory
{
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if (_reachability) {
        [_reachability stopNotifier];
        _reachability = nil;
    }
}

#pragma mark - Dropbox Linking

- (void)setupDropbox
{
    NSLog(@"setupDropbox");

    if (! self.session) {
        self.session = [[DBSession alloc] initWithAppKey:DROPBOX_APP_KEY appSecret:DROPBOX_APP_SECRET root:kDBRootAppFolder];
        [DBSession setSharedSession:self.session];
        self.session.delegate = self;
    }

    BRHUserSettings *settings = [BRHUserSettings userSettings];

    if (settings.useDropbox && ! self.session.isLinked) {
        NSString *title = @"Link to Dropbox?";
        NSString *msg = @"Do you wish to link this app with your Dropbox for storage?";
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:msg preferredStyle:UIAlertControllerStyleAlert];

        UIAlertAction *linkAction = [UIAlertAction actionWithTitle:@"Link" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [self enableDropbox:YES];
        }];

        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
            [self enableDropbox:NO];
        }];

        [alert addAction:cancelAction];
        [alert addAction:linkAction];

        UIViewController *vc = [UIApplication sharedApplication].keyWindow.rootViewController;
        if (vc.presentedViewController) {
            vc = vc.presentedViewController;
        }

        [vc presentViewController:alert animated:YES completion:nil];
    }
    else if (! settings.useDropbox && self.session.isLinked) {
        
        // User must have toggled off the "Use Dropbox" setting in the Settings app. Honor it.
        //
        [self enableDropbox:NO];

        NSString *title = @"Unlinked";
        NSString *msg = @"This app is no longer linked to your Dropbox.";
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:msg preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            ;
        }];
        
        [alert addAction:okAction];
        UIViewController *vc = [UIApplication sharedApplication].keyWindow.rootViewController;
        if (vc.presentedViewController) {
            vc = vc.presentedViewController;
        }
        
        [vc presentViewController:alert animated:YES completion:nil];
    }
    else {
        [self enableDropbox:settings.useDropbox];
    }
}

- (void)enableDropbox:(BOOL)value
{
    NSLog(@"enableDropbox - %d", value);
    [BRHUserSettings userSettings].useDropbox = value;
    if (value) {
        if (! self.session.isLinked) {
            NSLog(@"not linked - showing link request");
            UIViewController *vc = [UIApplication sharedApplication].keyWindow.rootViewController;
            if (vc.presentedViewController) {
                vc = vc.presentedViewController;
            }
            [self.session linkFromController:vc];
        }
        else if (! self.mainViewController.dropboxUploader){
            NSLog(@"linked - creating BRHDropboxUploader");
            self.mainViewController.dropboxUploader = [BRHDropboxUploader new];
        }
    }
    else {
        if (self.session.isLinked) {
            [self.session unlinkAll];
        }
        self.mainViewController.dropboxUploader = nil;
    }
}

#pragma mark - DBSessionDelegate methods

- (void)sessionDidReceiveAuthorizationFailure:(DBSession *)session userId:(NSString *)userId
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Dropbox Session Ended"
                                                                   message:@"Do you want to relink?"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"Relink"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction* action) {
                                                [_session linkUserId:userId fromController:[UIApplication sharedApplication].keyWindow.rootViewController];
                                            }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                              style:UIAlertActionStyleCancel
                                            handler:^(UIAlertAction* action) {}]];
    
    UIViewController *vc = [UIApplication sharedApplication].keyWindow.rootViewController;
    if (vc.presentedViewController) {
        vc = vc.presentedViewController;
    }
    
    [vc presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Core Data Management

- (BRHRecordingInfo *)makeRecordingInfo
{
    BRHRecordingInfo *recordingInfo = [NSEntityDescription insertNewObjectForEntityForName:BRHRecordingInfoDataModelName
                                                                    inManagedObjectContext:self.managedObjectContext];
    [recordingInfo initialize];
    return recordingInfo;
}

- (void)saveContext
{
    if (! self.managedObjectContext) return;
    if (! self.managedObjectContext.hasChanges) return;
    NSError *error;
    if (! [self.managedObjectContext save:&error]) {
        [BRHLogger add:@"Failed to save to data store: %@", error.localizedDescription];
        NSArray* detailedErrors = [error.userInfo objectForKey:NSDetailedErrorsKey];
        if (detailedErrors) {
            for (NSError* detailedError in detailedErrors) {
                [BRHLogger add:@"  DetailedError: %@", detailedError.userInfo];
            }
        }
        else {
            [BRHLogger add:@"  %@", [error userInfo]];
        }
    }
}

- (NSManagedObjectContext *) managedObjectContext
{
    if (_managedObjectContext != nil) {
        return _managedObjectContext;
    }

    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator != nil) {
        _managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        [_managedObjectContext setPersistentStoreCoordinator: coordinator];
    }

    return _managedObjectContext;
}

- (NSManagedObjectModel *)managedObjectModel
{
    if (_managedObjectModel != nil) {
        return _managedObjectModel;
    }

    _managedObjectModel = [NSManagedObjectModel mergedModelFromBundles:nil];
    return _managedObjectModel;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    if (_persistentStoreCoordinator != nil) return _persistentStoreCoordinator;

    NSURL *storeUrl = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:@"Recordings.sqlite"];
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithBool:YES], NSMigratePersistentStoresAutomaticallyOption,
                             [NSNumber numberWithBool:YES], NSInferMappingModelAutomaticallyOption,
                             nil];
    _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:self.managedObjectModel];

    NSError *error;
    if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
                                                   configuration:nil
                                                             URL:storeUrl
                                                         options:options
                                                           error:&error]) {
        // Update to handle the error appropriately.
        NSLog(@"persistentStoreCoordinator failure - %@", error.description);
        exit(-1);  // Fail
    }
    
    return _persistentStoreCoordinator;
}

- (NSFetchedResultsController *)fetchedResultsController
{
    if (_fetchedResultsController != nil) return _fetchedResultsController;
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:BRHRecordingInfoDataModelName
                                              inManagedObjectContext:self.managedObjectContext];
    [fetchRequest setEntity:entity];
    
    NSSortDescriptor *nameDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"name" ascending:NO];
    [fetchRequest setSortDescriptors:[NSArray arrayWithObject:nameDescriptor]];
    
    _fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
                                                                    managedObjectContext:self.managedObjectContext
                                                                      sectionNameKeyPath:nil
                                                                               cacheName:nil];
    return _fetchedResultsController;
}

#pragma mark - Run Management

- (void)startRun
{
    BRHUserSettings *settings = [BRHUserSettings userSettings];

    self.recordingInfo = [self makeRecordingInfo];
    self.runData = [[BRHRunData alloc] initWithName:self.recordingInfo.name];
    [self.runData start];

    [BRHLogger sharedInstance].logPath = self.recordingInfo.folderURL;
    [BRHEventLog sharedInstance].logPath = self.recordingInfo.folderURL;
    
    [BRHLogger add:@"Version: %@", [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"]];
    [BRHEventLog add:@"version", [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"], nil];
    
    NSString *driverTag = settings.notificationDriver;
    if ([driverTag isEqualToString:@"remote"]) {
        self.driver = [BRHRemoteDriver new];
    }
    else if ([driverTag isEqualToString:@"sim"]) {
        self.driver = [BRHSimDriver new];
    }
    else {
        self.driver = [BRHLoopNotificationDriver new];
    }

    [self reachabilityChanged:nil];
    [self batteryStateChanged:nil];

    self.driver.deviceToken = self.deviceToken;
    [self.driver startEmitting:[NSNumber numberWithInteger:settings.emitInterval] completionBlock:^(BOOL isRunning) {
        if (! isRunning) {
            [BRHEventLog add:@"failed to start", nil];
            self.recordingInfo = nil;
            [self.mainViewController startStop:nil];
        }
        else {
            self.running = YES;
            [self.mainViewController setRunData:self.runData];
        }
    }];
}

- (void)stopRun
{
    if (! self.running) return;

    self.running = NO;
    [self.runData stop];
    self.recordingInfo.recording = NO;

    [self.driver stopEmitting];
    
    NSURL *runDataArchive = [self.recordingInfo.folderURL URLByAppendingPathComponent:@"runData.archive"];
    NSData *archiveData = [NSKeyedArchiver archivedDataWithRootObject:self.runData];
    NSLog(@"archiveData size: %lu", (unsigned long)archiveData.length);
        
    NSError *error;
    if (![archiveData writeToURL:runDataArchive options:0 error:&error]) {
        NSLog(@"failed to write archive: %@", error.description);
    }
    
    [self.recordingInfo updateSize];
    [self saveContext];
    
    //        [self selectRecording:self.recordingInfo];
    
    if (self.mainViewController.dropboxUploader) {
        self.mainViewController.dropboxUploader.uploadingFile = self.recordingInfo;
    }
    
    self.recordingInfo = nil;
}

- (void)selectRecording:(BRHRecordingInfo *)recordingInfo
{
    NSURL *runDataArchive = [recordingInfo.folderURL URLByAppendingPathComponent:@"runData.archive"];
    NSData *archiveData = [NSData dataWithContentsOfURL:runDataArchive];
    if (archiveData) {
        NSLog(@"archiveData size: %lu", (unsigned long)archiveData.length);
        self.runData = [NSKeyedUnarchiver unarchiveObjectWithData:archiveData];
        [self.mainViewController setRunData:self.runData];
    }

    [[BRHLogger sharedInstance] save];
    [BRHLogger sharedInstance].logPath = recordingInfo.folderURL;
    
    [[BRHEventLog sharedInstance] save];
    [BRHEventLog sharedInstance].logPath = recordingInfo.folderURL;
}

- (void)deleteRecording:(BRHRecordingInfo *)recordingInfo
{
    if (self.recordingInfo && self.recordingInfo.filePath == recordingInfo.filePath) {
        self.recordingInfo = nil;
        self.runData = [[BRHRunData alloc] initWithName:@"Received Notifications"];
        [self.mainViewController setRunData:self.runData];
    }

    NSError *error;
    NSLog(@"deleting %@", recordingInfo.name);

    if (! [[NSFileManager defaultManager] removeItemAtPath:recordingInfo.folderURL.path error:&error]) {
        NSLog(@"failed to remove file at '%@' - %@, %@", recordingInfo.filePath, error, [error userInfo]);
    }

    [self.managedObjectContext deleteObject:recordingInfo];
    [self saveContext];
}

- (void)batteryStateChanged:(NSNotification *)notification
{
    UIDevice *device = [UIDevice currentDevice];
    UIDeviceBatteryState batteryState = device.batteryState;
    [BRHEventLog add:@"batteryState", [self batteryStateString:batteryState], nil];
}

- (void)reachabilityChanged:(NSNotification *)notification
{
    static int last = -1;
    NetworkStatus status = [self.reachability currentReachabilityStatus];
    if (! notification || last != status) {
        last = status;
        switch (status) {
            case NotReachable: [BRHEventLog add:@"networkState,None", nil]; break;
            case ReachableViaWiFi: [BRHEventLog add:@"networkState,WIFI", nil]; break;
            case ReachableViaWWAN: [BRHEventLog add:@"networkState,Mobile", nil]; break;
            default: break;
        }
    }
}

- (NSString *)batteryStateString:(UIDeviceBatteryState)batteryState
{
    switch (batteryState) {
        case UIDeviceBatteryStateUnplugged: return @"unplugged";
        case UIDeviceBatteryStateCharging: return @"charging";
        case UIDeviceBatteryStateFull: return @"full";
        case UIDeviceBatteryStateUnknown:
        default: return @"unknown";
    }
}

#pragma mark - Application Lifecycle

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [UIDevice currentDevice].batteryMonitoringEnabled = YES;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(batteryStateChanged:)
                                                 name:UIDeviceBatteryStateDidChangeNotification object:nil];

    self.mainViewController = (BRHMainViewController *)self.window.rootViewController;
    self.runData = [[BRHRunData alloc] initWithName:@"Received Notifications"];
    self.driver = nil;
    self.running = NO;

    self.reachability = [Reachability reachabilityForInternetConnection];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reachabilityChanged:) name:kReachabilityChangedNotification object:nil];
    [self.reachability startNotifier];

    [application setStatusBarStyle:UIStatusBarStyleLightContent];
    [application setMinimumBackgroundFetchInterval:UIApplicationBackgroundFetchIntervalMinimum];
    
    [application registerUserNotificationSettings:[UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeBadge|UIUserNotificationTypeSound|UIUserNotificationTypeAlert
                                                                                    categories:nil]];
    [application registerForRemoteNotifications];

    return YES;
}

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url sourceApplication:(NSString *)source annotation:(id)annotation
{
    if ([[DBSession sharedSession] handleOpenURL:url]) {
        if ([[DBSession sharedSession] isLinked]) {
            NSLog(@"Dropbox linked!");
            [self enableDropbox:YES];
        }
        return YES;
    }
    // Add whatever other url handling code your app requires here
    return NO;
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error
{
    [BRHEventLog add:@"failedPushRegistration", nil];
    [BRHLogger add:@"failed to register notifications: %@", [error description]];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Push Notifications"
                                                                   message:@"Failed to register for push notifications."
                                                            preferredStyle:UIAlertControllerStyleAlert];

    [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction* action) {}]];
#if ! TARGET_IPHONE_SIMULATOR
    UIViewController *vc = [UIApplication sharedApplication].keyWindow.rootViewController;
    if (vc.presentedViewController) {
        vc = vc.presentedViewController;
    }
    
    [vc presentViewController:alert animated:YES completion:nil];
#else
    self.deviceToken = [NSData dataWithBytes:"12345678901234567890123456789012" length:32];
#endif
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    [BRHLogger add:@"registered for notifications"];
    self.deviceToken = deviceToken;
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
    [BRHLogger add:@"didReceiveRemoteNotification"];
    if (self.running) {
        BRHLatencySample *sample = [self.driver receivedNotification:userInfo at:[NSDate date] fetchCompletionHandler:completionHandler];
        if (sample) {
            [self.runData recordLatency:sample];
        }
    }
    else {
        completionHandler(UIBackgroundFetchResultNoData);
    }
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    NSLog(@"applicationWillResignActive");
    [BRHEventLog add:@"resignActive", nil];
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    NSLog(@"applicationDidEnterBackground");
    [BRHEventLog add:@"didEnterBackground", nil];
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    NSLog(@"applicationWillEnterForeground");
    [BRHEventLog add:@"willEnterForeground", nil];
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    NSLog(@"applicationDidBecomeActive");
    [BRHEventLog add:@"didBecomeActive", nil];
    [self setupDropbox];
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    [BRHEventLog add:@"willTerminate", nil];
    if (self.running) {
        [self.mainViewController startStop:nil];
    }
    [[BRHLogger sharedInstance] save];
    [[BRHEventLog sharedInstance] save];
}

- (void)application:(UIApplication *)application performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
    [BRHLogger add:@"performFetchWithCompletionHandler"];
    if (self.driver) {
        [self.driver performFetchWithCompletionHandler:completionHandler];
    }
    else {
        
        // Stale notification coming in as we are starting up. Just ignore it.
        completionHandler(UIBackgroundFetchResultFailed);
    }
}

- (void)application:(UIApplication *)application handleEventsForBackgroundURLSession:(NSString *)identifier completionHandler:(void (^)())completionHandler
{
    [BRHLogger add:@"handleEventsForBackgroundURLSession - %@", identifier];
    [self.driver handleEventsForBackgroundURLSession:identifier completionHandler:completionHandler];
}

@end
