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
- (void)linkDropbox;
- (void)saveContext;

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
    self.session = [[DBSession alloc] initWithAppKey:DROPBOX_APP_KEY appSecret:DROPBOX_APP_SECRET root:kDBRootAppFolder];
    [DBSession setSharedSession:self.session];
    self.session.delegate = self;
    
    BRHUserSettings *settings = [BRHUserSettings userSettings];
    [settings addObserver:self forKeyPath:@"useDropBox" options:NSKeyValueObservingOptionNew context:kKVOContext];
    if (settings.useDropbox) {
        [self linkDropbox];
    }
}

- (void)linkDropbox
{
    if (! [self.session isLinked]) {
        [self.session linkFromController:self.window.rootViewController];
    }
    else {
        self.mainViewController.dropboxUploader = [BRHDropboxUploader new];
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
    
    [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
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
        NSLog(@"saveContext - unresolved error %@", error.description);
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

- (BRHRunData *)startRun
{
    self.running = YES;
    self.recordingInfo = [self makeRecordingInfo];

    [BRHLogger sharedInstance].logPath = self.recordingInfo.folderURL;
    [BRHEventLog sharedInstance].logPath = self.recordingInfo.folderURL;

    BRHUserSettings *settings = [BRHUserSettings userSettings];
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

    self.driver.deviceToken = self.deviceToken;

    self.runData = [[BRHRunData alloc] initWithName:self.recordingInfo.name];
    [self.runData start];

    if (! [self.driver startEmitting:[NSNumber numberWithInteger:settings.emitInterval]]) {
        [BRHEventLog add:@"failed to start", nil];
        self.recordingInfo = nil;
        [self.mainViewController startStop:nil];
    }

    return self.runData;
}

- (void)stopRun
{
    self.running = NO;
    [self.driver stopEmitting];
    [self.runData stop];

#if 0
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Save the run?" message:@""
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    [alert addAction:[UIAlertAction actionWithTitle:@"Save" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
#endif
        
        NSURL *runDataArchive = [self.recordingInfo.folderURL URLByAppendingPathComponent:@"runData.archive"];
        NSData *archiveData = [NSKeyedArchiver archivedDataWithRootObject:self.runData];
        NSLog(@"archiveData size: %lu", (unsigned long)archiveData.length);
        
        NSError *error;
        if (![archiveData writeToURL:runDataArchive options:0 error:&error]) {
            NSLog(@"failed to write archive: %@", error.description);
        }
        
        [self.recordingInfo updateSize];
        [self saveContext];

        self.recordingInfo.recording = NO;
        [self selectRecording:self.recordingInfo];
        
        if (self.mainViewController.dropboxUploader) {
            self.mainViewController.dropboxUploader.uploadingFile = self.recordingInfo;
            self.recordingInfo = nil;
            [self.mainViewController setRunData:self.runData];
        }
#if 0
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"Discard" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        self.recordingInfo = nil;
    }]];

    [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
#endif
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

    [BRHLogger sharedInstance].logPath = recordingInfo.folderURL;
    [BRHEventLog sharedInstance].logPath = recordingInfo.folderURL;
    
    // [self.mainViewController showHideRecordingsView:nil];
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

- (void)reachabilityChanged:(NSNotification *)notification
{
    static int last = -1;
    NetworkStatus status = [self.reachability currentReachabilityStatus];
    if (last != status) {
        last = status;
        switch (status) {
            case NotReachable: [BRHEventLog add:@"networkState,None", nil]; break;
            case ReachableViaWiFi: [BRHEventLog add:@"networkState,WIFI", nil]; break;
            case ReachableViaWWAN: [BRHEventLog add:@"networkState,Mobile", nil]; break;
            default: break;
        }
    }
}

#pragma mark - Application Lifecycle

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [DDLog addLogger:[DDTTYLogger sharedInstance]];
    DDFileLogger *fileLogger = [[DDFileLogger alloc] init];
    [DDLog addLogger:fileLogger];
    DDLogDebug(@"launchOptions: %@", [launchOptions description]);

    self.mainViewController = (BRHMainViewController *)self.window.rootViewController;
    self.runData = [[BRHRunData alloc] initWithName:@"Received Notifications"];
    self.driver = nil;
    self.running = NO;

    self.reachability = [Reachability reachabilityForInternetConnection];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reachabilityChanged:) name:kReachabilityChangedNotification object:nil];
    [self.reachability startNotifier];

    [self setupDropbox];

    [application setStatusBarStyle:UIStatusBarStyleLightContent];
    [application setMinimumBackgroundFetchInterval:UIApplicationBackgroundFetchIntervalMinimum];
    
    [application registerUserNotificationSettings:[UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeBadge|UIUserNotificationTypeSound|UIUserNotificationTypeAlert
                                                                                    categories:nil]];
    [application registerForRemoteNotifications];

    return YES;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == kKVOContext) {
        if ([keyPath isEqualToString:@"useDropbox"]) {
            if (((NSNumber *)change[NSKeyValueChangeNewKey]).boolValue) {
                [self linkDropbox];
            }
            else if (self.mainViewController.dropboxUploader) {
                self.mainViewController.dropboxUploader = nil;
            }
        }
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url sourceApplication:(NSString *)source annotation:(id)annotation
{
    if ([[DBSession sharedSession] handleOpenURL:url]) {
        if ([[DBSession sharedSession] isLinked]) {
            NSLog(@"App linked successfully!");
            [self linkDropbox];
        }
        return YES;
    }
    // Add whatever other url handling code your app requires here
    return NO;
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error
{
    [BRHLogger add:@"failed to register notifications: %@", [error description]];
    // !!!: post alert here
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    [BRHLogger add:@"registered for notifications"];
    self.deviceToken = deviceToken;
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
    if (self.running) {
        BRHLatencySample *sample = [self.driver receivedNotification:userInfo at:[NSDate date] fetchCompletionHandler:completionHandler];
        [self.runData recordLatency:sample];
    }
    else {
        completionHandler(UIBackgroundFetchResultNoData);
    }
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    [BRHEventLog add:@"resignActive", nil];
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    [BRHEventLog add:@"didEnterBackground", nil];
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    [BRHEventLog add:@"willEnterForeground", nil];
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    [BRHEventLog add:@"didBecomeActive", nil];
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
    [self.driver updateWithCompletionHandler:completionHandler];
}

- (void)application:(UIApplication *)application handleEventsForBackgroundURLSession:(NSString *)identifier completionHandler:(void (^)())completionHandler
{
    [BRHLogger add:@"handleEventsForBackgroundURLSession"];
    [self.driver handleEventsForBackgroundURLSession:identifier completionHandler:completionHandler];
}

@end
