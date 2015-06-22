// BRHRecordingsViewController.m
// NHTest
//
// Copyright (C) 2015 Brad Howes. All rights reserved.

#import <CoreData/CoreData.h>
#import <DropboxSDK/DropboxSDK.h>

#import "BRHAppDelegate.h"
#import "BRHDropboxUploader.h"
#import "BRHLogger.h"
#import "BRHMainViewController.h"
#import "BRHRecordingInfo.h"
#import "BRHRecordingsViewController.h"
#import "BRHTimeFormatter.h"
#import "BRHUserSettings.h"
#import "MACircleProgressIndicator.h"

@interface BRHRecordingsViewController () <NSFetchedResultsControllerDelegate, BRHDropboxUploaderMonitor, UIGestureRecognizerDelegate>

@property (strong, nonatomic) IBOutlet UIBarButtonItem *editButton;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *cancelButton;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *deleteButton;

@property (weak, nonatomic) BRHAppDelegate *delegate;
@property (strong, nonatomic) NSFetchedResultsController *fetchedResultsController;
@property (strong, nonatomic) BRHTimeFormatter *durationFormatter;

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath;
- (void)updateButtonsToMatchTableState;
- (void)updateDeleteButtonTitle;
- (void)saveContext;

@end

@implementation BRHRecordingsViewController

#pragma mark - View Lifecycle

- (instancetype)initWithCoder:(NSCoder *)decoder
{
    NSLog(@"BRHRecordingsViewController.initWithCoder");
    if (self = [super initWithCoder:decoder]) {
        _managedObjectContext = nil;
        _fetchedResultsController = nil;
        _dropboxUploader = nil;
    }

    return self;
}

- (void)viewDidLoad {
    NSLog(@"BRHRecordingsViewController.viewDidLoad");
    [super viewDidLoad];

    self.tableView.allowsSelection = YES;
    self.tableView.allowsSelectionDuringEditing = YES;

    UITapGestureRecognizer* doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(doubleTap:)];
    doubleTap.delegate = self;
    doubleTap.numberOfTapsRequired = 2;
    doubleTap.numberOfTouchesRequired = 1;

    NSArray *grs = self.tableView.gestureRecognizers;
    for (UIGestureRecognizer *gr in grs) {
        if (!gr.delegate) gr.delegate = self;
    }

    [self.tableView addGestureRecognizer:doubleTap];

    self.delegate = [UIApplication sharedApplication].delegate;
    self.managedObjectContext = self.delegate.managedObjectContext;
    self.durationFormatter = [BRHTimeFormatter new];

    doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(doubleTap:)];
    doubleTap.delegate = self;
    doubleTap.numberOfTapsRequired = 2;
    doubleTap.numberOfTouchesRequired = 1;
    [self.navigationController.navigationBar addGestureRecognizer:doubleTap];

    NSError *error;
    if (![[self fetchedResultsController] performFetch:&error]) {
        /*
         Replace this implementation with code to handle the error appropriately.
         
         abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
         */
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }
    
    [self updateButtonsToMatchTableState];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

#pragma mark - Action Methods

- (IBAction)editAction:(id)sender
{
    NSLog(@"editAction");
    [self.tableView setEditing:YES animated:YES];
    [self updateButtonsToMatchTableState];
}

- (IBAction)cancelAction:(id)sender
{
    NSLog(@"cancelAction");

    [self.tableView setEditing:NO animated:YES];
    [self updateButtonsToMatchTableState];
}

- (IBAction)deleteAction:(id)sender
{
    NSString *msg;
    if (([[self.tableView indexPathsForSelectedRows] count] == 1)) {
        msg = @"Are you sure you want to remove this item?";
    }
    else {
        msg = @"Are you sure you want to remove these items?";
    }

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:msg message:nil preferredStyle:UIAlertControllerStyleActionSheet];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        [self.tableView setEditing:NO animated:YES];
        [self updateButtonsToMatchTableState];
    }];

    UIAlertAction *deleteAction = [UIAlertAction actionWithTitle:@"Delete" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        NSArray *selectedRows = [self.tableView indexPathsForSelectedRows];
        BOOL deleteSpecificRows = selectedRows.count > 0;
        if (deleteSpecificRows) {
            NSMutableArray *recordings = [NSMutableArray new];
            for (NSIndexPath *selectionIndex in selectedRows) {
                BRHRecordingInfo *recordingInfo = [self.fetchedResultsController objectAtIndexPath:selectionIndex];
                [recordings addObject:recordingInfo];
            }
            
            for (BRHRecordingInfo *recordingInfo in recordings) {
                [self.delegate deleteRecording:recordingInfo];
            }
        }
        else {
            NSError *error;
            if (! [[self fetchedResultsController] performFetch:&error]) {
                ;
            }
            else {
                for (BRHRecordingInfo *recordingInfo in [self.fetchedResultsController fetchedObjects]) {
                    [self.delegate deleteRecording:recordingInfo];
                }
            }
        }

        [self.tableView setEditing:NO animated:YES];
        [self updateButtonsToMatchTableState];
    }];

    [alert addAction:cancelAction];
    [alert addAction:deleteAction];

    UIPopoverPresentationController *popover = alert.popoverPresentationController;
    if (popover) {
        UIView *button = [self.navigationItem.leftBarButtonItem valueForKey:@"view"];
        popover.sourceView = button;
        popover.sourceRect = button.bounds;
        popover.permittedArrowDirections = UIPopoverArrowDirectionAny;
    }

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)updateButtonsToMatchTableState
{
    if (self.tableView.editing) {
        self.navigationItem.rightBarButtonItem = self.cancelButton;
        [self updateDeleteButtonTitle];
        self.navigationItem.leftBarButtonItem = self.deleteButton;
    }
    else {
        NSUInteger count = [self.tableView numberOfRowsInSection:0];
        self.navigationItem.leftBarButtonItem = nil;
        if (count > 1 || (count == 1 && ! ((BRHRecordingInfo *)[self.fetchedResultsController fetchedObjects].firstObject).recording)) {
            // self.navigationItem.rightBarButtonItem = self.editButtonItem;
            self.editButton.enabled = YES;
        }
        else {
            // self.navigationItem.rightBarButtonItem = nil;
            self.editButton.enabled = NO;
        }
        self.navigationItem.rightBarButtonItem = self.editButton;
    }
}

- (void)updateDeleteButtonTitle
{
    // Update the delete button's title, based on how many items are selected
    NSArray *selectedRows = [self.tableView indexPathsForSelectedRows];
    BOOL allItemsAreSelected = selectedRows.count == [self.tableView numberOfRowsInSection:0];
    BOOL noItemsAreSelected = selectedRows.count == 0;
    
    if (allItemsAreSelected || noItemsAreSelected) {
        self.deleteButton.title = @"Delete All";
    }
    else {
        self.deleteButton.title = [NSString stringWithFormat:@"Delete (%lu)", (unsigned long)selectedRows.count];
    }
}

- (void)setButtonItem:(UIBarButtonItem *)buttonItem
{
    _buttonItem = buttonItem;
    // [self updateBadge];
}

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller
{
    if (self.isViewLoaded) {
        [self.tableView beginUpdates];
    }
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type newIndexPath:(NSIndexPath *)newIndexPath
{
    if (! self.isViewLoaded) return;
    UITableView *tableView = self.tableView;
    
    switch(type) {
        case NSFetchedResultsChangeInsert:
            [tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
            break;
            
        case NSFetchedResultsChangeDelete:
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
            break;
            
        case NSFetchedResultsChangeUpdate:
            [self configureCell:[tableView cellForRowAtIndexPath:indexPath] atIndexPath:indexPath];
            break;
            
        default:
            break;
    }
}

- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type
{
    if (! self.isViewLoaded) return;
    
    switch(type) {
        case NSFetchedResultsChangeInsert:
            [self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationAutomatic];
            break;
        case NSFetchedResultsChangeDelete:
            [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationAutomatic];
            break;
            
        default:
            break;
    }
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

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    if (! self.isViewLoaded) return;
    [self.tableView endUpdates];
    [self updateButtonsToMatchTableState];
    [self saveContext];
}

#pragma mark - UITableViewDataSource Methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [[self.fetchedResultsController sections] count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    id <NSFetchedResultsSectionInfo> sectionInfo = [[self.fetchedResultsController sections] objectAtIndex:section];
    return [sectionInfo numberOfObjects];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString* kCellIdentifier = @"BRHRecordingInfoCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellIdentifier];
    if (! cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:kCellIdentifier];
    }
    
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    BRHRecordingInfo *recordingInfo = [self.fetchedResultsController objectAtIndexPath:indexPath];
    return ! recordingInfo.recording;
}

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
    BRHRecordingInfo *recordingInfo = [self.fetchedResultsController objectAtIndexPath:indexPath];

    cell.textLabel.text = recordingInfo.name;

    NSString *status;
    UIColor *statusColor = [UIColor blackColor];

    if (recordingInfo.recording) {
        status = @"Recording";
        statusColor = [UIColor redColor];
    }
    else if (recordingInfo.uploaded) {
        status = @"Uploaded";
        statusColor = [UIColor colorWithRed:0.0 green:0.5 blue:0.0 alpha:1.0];
    }
    else if (recordingInfo.uploading) {
        status = @"Uploading";
        statusColor = [UIColor magentaColor];
    }
    else if (recordingInfo.progress < 0.0) {
        if (recordingInfo.progress == -1001.0) {
            status = @"Missing";
            statusColor = [UIColor redColor];
        }
        else {
            status = @"Failed";
            statusColor = [UIColor redColor];
        }
    }
    else {
        status = @"Not uploaded";
    }

    cell.detailTextLabel.textColor = statusColor;
    if (recordingInfo.size.length > 0) {
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ • %@ - %@", recordingInfo.durationString,
                                     recordingInfo.size, status];
    }
    else {
        cell.detailTextLabel.text = status;
    }

    if (! recordingInfo.uploaded && recordingInfo.uploading) {

        MACircleProgressIndicator *accessoryView = (MACircleProgressIndicator *)[cell accessoryView];
        if (accessoryView == nil) {
            // accessoryView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
            accessoryView = [[MACircleProgressIndicator alloc] initWithFrame:CGRectMake(0.0, 0.0, 25.0, 25.0)];
            accessoryView.color = [UIColor blueColor];
            accessoryView.backgroundColor = [UIColor whiteColor];
            [cell setAccessoryView:accessoryView];
        }
        //[accessoryView setProgress:recordingInfo.progress];
        accessoryView.value = recordingInfo.progress;
    }
    else {
        [cell setAccessoryView:nil];
    }
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        BRHRecordingInfo *recordingInfo = [self.fetchedResultsController objectAtIndexPath:indexPath];
        [self.delegate deleteRecording:recordingInfo];
        if ([tableView numberOfRowsInSection:0] == 0) {
            [self setEditing:NO animated:YES];
            [self updateButtonsToMatchTableState];
        }
    }
}

#pragma mark -UITableViewDelegate Methods

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSLog(@"BRHRecordingsViewController.didSelectRow: %ld", (unsigned long)[indexPath indexAtPosition:1]);
    if (! self.tableView.editing) {
        BRHRecordingInfo *recordingInfo = [self.fetchedResultsController objectAtIndexPath:indexPath];
        [self.delegate selectRecording:recordingInfo];
    }

    [self updateButtonsToMatchTableState];
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSLog(@"BRHRecordingsViewController.didDeselectRow: %ld", (unsigned long)[indexPath indexAtPosition:1]);
    [self updateButtonsToMatchTableState];
}

#pragma mark - Double Tap Gesture

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldBeRequiredToFailByGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return YES;
}

- (void)doubleTap:(UITapGestureRecognizer *)gesture
{
    if (self.tableView.editing) return;

    if (gesture.state == UIGestureRecognizerStateEnded) {
        
        if (gesture.view == self.tableView) {
            CGPoint p = [gesture locationInView:gesture.view];
            NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:p];
            BRHRecordingInfo *recordingInfo = [self.fetchedResultsController objectAtIndexPath:indexPath];
            [self.delegate selectRecording:recordingInfo];
        }

        BRHMainViewController* mvc = (BRHMainViewController *)[UIApplication sharedApplication].keyWindow.rootViewController;
        [mvc showHideRecordingsView:nil];
    }
}

#pragma mark - CoreData

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
    _fetchedResultsController.delegate = self;
    return _fetchedResultsController;
}

#pragma mark - Dropbox Uploader Integration

- (void)setDropboxUploader:(BRHDropboxUploader *)dropboxUploader
{
    if (_dropboxUploader) {
        [_dropboxUploader cancelUpload];
        _dropboxUploader = nil;
    }

    _dropboxUploader = dropboxUploader;
    
    if (_dropboxUploader) {
        _dropboxUploader.monitor = self;
    }
}

- (BRHRecordingInfo *)nextToUpload
{
    NSArray* recordings = [self.fetchedResultsController fetchedObjects];
    BRHRecordingInfo* retry = nil;
    for (BRHRecordingInfo *recordingInfo in recordings) {
        if (! recordingInfo.uploaded && ! recordingInfo.recording) {
            if (recordingInfo.progress >= 0.0) {
                NSLog(@"nextToUpload: %@", recordingInfo.name);
                return recordingInfo;
            }
            else if (!retry) {
                retry = recordingInfo;
            }
        }
    }
    
    return retry;
}

- (BRHRecordingInfo *)dropboxUploaderReadyToUpload:(BRHDropboxUploader *)dropboxUploader
{
    return [self nextToUpload];
}

- (void)dropboxUploader:(BRHDropboxUploader *)dropboxUploader monitorFinishedWith:(BRHRecordingInfo *)recordingInfo
{
    [self saveContext];
}

@end
