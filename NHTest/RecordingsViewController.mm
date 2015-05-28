// -*- Mode: ObjC -*-
//
// Copyright (C) 2011, Brad Howes. All rights reserved.
//

#import <CoreData/CoreData.h>
#import <DropboxSDK/DropboxSDK.h>

#import "DropboxUploader.h"
#import "RecordingInfo.h"
#import "RecordingsViewController.h"
#import "UserSettings.h"

@interface RecordingsViewController () <NSFetchedResultsControllerDelegate, DropboxUploaderMonitor>

@property (nonatomic, strong) NSManagedObjectModel *managedObjectModel;
@property (nonatomic, strong) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, strong) NSPersistentStoreCoordinator* persistentStoreCoordinator;
@property (nonatomic, strong) NSFetchedResultsController* fetchedResultsController;
@property (nonatomic, strong) DropboxUploader* uploader;
@property (nonatomic, strong) RecordingInfo* activeRecording;

- (void)configureCell:(UITableViewCell*)cell withRecordingInfo:(RecordingInfo*)recordingInfo;
- (RecordingInfo*)nextToUpload;

@end

@implementation RecordingsViewController

#pragma mark -
#pragma mark View lifecycle

- (id)initWithCoder:(NSCoder*)decoder
{
    NSLog(@"RecordingsViewController.initWithCoder");
    if (self = [super initWithCoder:decoder]) {
        self.managedObjectModel = nil;
        self.managedObjectContext = nil;
        self.persistentStoreCoordinator = nil;
        self.fetchedResultsController = nil;
        self.activeRecording = nil;
        [NSTimer scheduledTimerWithTimeInterval:5.0 target:self selector:@selector(updateFromSettings) userInfo:nil repeats:NO];
        [self nextToUpload];
    }

    return self;
}

- (void)viewDidLoad {
    NSLog(@"RecordingsViewController.viewDidLoad");
    self.tableView.allowsSelection = NO;
    [super viewDidLoad];
}

- (void)viewDidUnload
{
    NSLog(@"RecordingsViewController.viewDidUnload");
}

- (void)viewWillAppear:(BOOL)animated
{
    if ([self.tableView numberOfRowsInSection:0] > 0) {
        self.navigationItem.rightBarButtonItem = self.editButtonItem;
    }
    else {
        self.navigationItem.rightBarButtonItem = nil;
    }
    
    [super viewWillAppear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}

- (void)updateFromSettings
{
    DBSession *dropboxSession = [DBSession sharedSession];
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kSettingsCloudStorageEnableKey] == YES &&
        [dropboxSession isLinked] == YES) {
        if (self.uploader == nil) {
            self.uploader = [DropboxUploader createWithSession:dropboxSession];
            self.uploader.monitor = self;
        }
    }
    else {
        self.uploader = nil;
    }
}

- (void)readyToUpload
{
    RecordingInfo* recordingInfo = [self nextToUpload];
    if (recordingInfo != nil) {
        self.uploader.uploadingFile = recordingInfo;
    }
}

- (void)controllerWillChangeContent:(NSFetchedResultsController*)controller
{
    if (self.isViewLoaded) {
        [self.tableView beginUpdates];
    }
}

- (void)controller:(NSFetchedResultsController*)controller didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath*)indexPath
     forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath*)newIndexPath
{
    if (self.isViewLoaded == NO) return;
    UITableView *tableView = self.tableView;

    switch(type) {
        case NSFetchedResultsChangeInsert:
            [tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath]
                             withRowAnimation:UITableViewRowAnimationNone];
            [self configureCell:[tableView cellForRowAtIndexPath:newIndexPath]
              withRecordingInfo:anObject];
            break;
            
        case NSFetchedResultsChangeDelete:
            [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
                             withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeUpdate:
            if (self.tableView.editing == NO) {
                [self configureCell:[tableView cellForRowAtIndexPath:indexPath] withRecordingInfo:anObject];
            }
            
        default:
            break;
    }
}

- (void)controller:(NSFetchedResultsController*)controller
  didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex
     forChangeType:(NSFetchedResultsChangeType)type
{
    if (self.isViewLoaded == NO) return;

    switch(type) {
        case NSFetchedResultsChangeInsert:
            [self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex]
                          withRowAnimation:UITableViewRowAnimationNone];
            break;
        case NSFetchedResultsChangeDelete:
            [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex]
                          withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        default:
            break;
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController*)controller
{
    if (self.isViewLoaded == NO) return;
    [self.tableView endUpdates];
}

#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [[self.fetchedResultsController sections] count];
}

- (NSInteger)tableView:(UITableView*)tableView numberOfRowsInSection:(NSInteger)section {
    id <NSFetchedResultsSectionInfo> sectionInfo = [[self.fetchedResultsController sections] objectAtIndex:section];
    return [sectionInfo numberOfObjects];
}

- (UITableViewCell*)tableView:(UITableView*)tableView cellForRowAtIndexPath:(NSIndexPath*)indexPath {
    static NSString* kCellIdentifier = @"RecordingInfoCell";
    UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:kCellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                        reuseIdentifier:kCellIdentifier];
    }
    
    RecordingInfo* recording = [self.fetchedResultsController objectAtIndexPath:indexPath];
    [self configureCell:cell withRecordingInfo:recording];
    
    return cell;
}

- (void)configureCell:(UITableViewCell*)cell withRecordingInfo:(RecordingInfo*)recording
{
    cell.textLabel.text = recording.name;
    NSString* status;
    
    if (recording.uploaded == YES) {
        status = @"uploaded";
    }
    else if (recording.uploading == YES) {
        status = @"uploading";
    }
    else if (recording == self.activeRecording) {
        status = @"recording";
    }
    else if (recording.progress < 0.0) {
        if (recording.progress == -1001.0) {
            status = @"missing";
        }
        else {
            status = @"failed";
        }
    }
    else {
        status = @"not uploaded";
    }
    
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ - %@", recording.size, status];
    
    //
    // If this RecordingInfo object is being uploaded, show an activity indicator.
    //
    if (recording.uploaded == NO && recording.uploading == YES) {
        UIProgressView* accessoryView = (UIProgressView*)[cell accessoryView];
        if (accessoryView == nil) {
            accessoryView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
            CGRect bounds = accessoryView.bounds;
            bounds.size.width = 100;
            accessoryView.bounds = bounds;
            [cell setAccessoryView:accessoryView];
        }
        [accessoryView setProgress:recording.progress];
    }
    else {
        [cell setAccessoryView:nil];
    }
}

- (void)tableView:(UITableView*)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        RecordingInfo *recordingInfo = [self.fetchedResultsController objectAtIndexPath:indexPath];
        NSLog(@"deleting file '%@'", recordingInfo.filePath);
        
        // [appDelegate recordingDeleted:recordingInfo];
        if (self.uploader != nil && self.uploader.uploadingFile == recordingInfo)
            [self.uploader cancelUpload];
        
        NSError* error;
        if ([[NSFileManager defaultManager] removeItemAtPath:recordingInfo.filePath error:&error] == NO) {
            NSLog(@"failed to remove file at '%@' - %@, %@", recordingInfo.filePath, error, [error userInfo]);
        }
        
        [self.managedObjectContext deleteObject:recordingInfo];
        if (![self.managedObjectContext save:&error]) {
            // Update to handle the error appropriately.
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        }
        
        if ([tableView numberOfRowsInSection:0] == 0) {
            [self setEditing:NO animated:YES];
            self.navigationItem.rightBarButtonItem = nil;
        }
    }
}

#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSLog(@"RecordingsViewController.didSelectRow: %ld", [indexPath indexAtPosition:1]);
}

#pragma mark -
#pragma mark CoreData

- (NSManagedObjectModel*)managedObjectModel
{
    if (self.managedObjectModel != nil) return self.managedObjectModel;
    self.managedObjectModel = [NSManagedObjectModel mergedModelFromBundles:nil];
    return self.managedObjectModel;
}

- (NSPersistentStoreCoordinator*)persistentStoreCoordinator
{
    if (self.persistentStoreCoordinator != nil) return self.persistentStoreCoordinator;
    
    NSArray* paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString* basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    
    NSString* storePath = [basePath stringByAppendingPathComponent: @"Recordings.sqlite"];
    NSURL* storeUrl = [NSURL fileURLWithPath:storePath];
    NSDictionary* options = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithBool:YES], NSMigratePersistentStoresAutomaticallyOption,
                             [NSNumber numberWithBool:YES], NSInferMappingModelAutomaticallyOption,
                             nil];
    self.persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:self.managedObjectModel];
    NSError* error;
    if (![self.persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
                                                       configuration:nil
                                                                 URL:storeUrl
                                                             options:options
                                                               error:&error]) {
        // Update to handle the error appropriately.
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        exit(-1);  // Fail
    }
    
    return self.persistentStoreCoordinator;
}

- (NSManagedObjectContext*)managedObjectContext
{
    if (self.managedObjectContext != nil) return self.managedObjectContext;
    
    NSPersistentStoreCoordinator* coordinator = self.persistentStoreCoordinator;
    if (coordinator != nil) {
        self.managedObjectContext = [[NSManagedObjectContext alloc] init];
        [self.managedObjectContext setPersistentStoreCoordinator: coordinator];
    }
    
    return self.managedObjectContext;
}

- (NSFetchedResultsController*)fetchedResultsController
{
    if (self.fetchedResultsController != nil) return self.fetchedResultsController;
    
    NSFetchRequest* fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"RecordingInfo"
                                              inManagedObjectContext:self.managedObjectContext];
    [fetchRequest setEntity:entity];
    
    NSSortDescriptor* nameDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES];
    [fetchRequest setSortDescriptors:[NSArray arrayWithObject:nameDescriptor]];
    
    self.fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
                                                                        managedObjectContext:self.managedObjectContext
                                                                          sectionNameKeyPath:nil
                                                                                   cacheName:@"RecordingInfo"];
    self.fetchedResultsController.delegate = self;
    
    NSError* error;
    if (![self.fetchedResultsController performFetch:&error]) {
        NSLog(@"unresolved error %@, %@", error, [error userInfo]);
    }
    
    return self.fetchedResultsController;
}

- (RecordingInfo*)startRecording
{
    RecordingInfo* recording = [NSEntityDescription insertNewObjectForEntityForName:@"RecordingInfo"
                                                             inManagedObjectContext:self.managedObjectContext];
    [recording initialize];
    self.activeRecording = recording;
    return recording;
}

- (void)stopRecording
{
    if (self.activeRecording != nil) {
        RecordingInfo* recording = self.activeRecording;
        self.activeRecording = nil;
        [recording finalizeSize];
        [self saveContext];
        if (self.uploader != nil && self.uploader.uploadingFile == nil) {
            RecordingInfo* recording = [self nextToUpload];
            self.uploader.uploadingFile = recording;
        }
    }
}

- (void)saveContext
{
    NSError* error;
    if (self.managedObjectContext != nil && [self.managedObjectContext hasChanges] && [self.managedObjectContext save:&error] != YES) {
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
    }
}

- (RecordingInfo*)nextToUpload
{
    NSArray* recordings = [self.fetchedResultsController fetchedObjects];
    NSUInteger count = [recordings count];
    NSUInteger pending = 0;
    RecordingInfo* next = nil;
    RecordingInfo* retry = nil;
    
    for (int index = 0; index < count; ++index) {
        RecordingInfo *recording = [recordings objectAtIndex:index];
        if (recording.uploaded == NO && recording != self.activeRecording) {
            ++pending;
            if (recording.progress >= 0.0) {
                if (next == nil) {
                    NSLog(@"nextToUpload: %@", recording.name);
                    recording.progress = 0.0;
                    next = recording;
                }
            }
            else {
                if (retry == nil) {
                    NSLog(@"nextToUpload: retrying %@", recording.name);
                    retry = recording;
                }
            }
        }
    }

#if 0
    if (pending) {
        tabItem.badgeValue = [NSString stringWithFormat:@"%ld", pending, nil];
    }
    else {
        tabItem.badgeValue = nil;
    }
#endif
    
    if (next) return next;
    return retry;
}

@end
