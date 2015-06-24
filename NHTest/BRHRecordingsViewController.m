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
#import "MGSwipeTableCell.h"
#import "MGSwipeButton.h"

static void *kKVOContext = &kKVOContext;

@interface BRHRecordingsViewController () <NSFetchedResultsControllerDelegate, BRHDropboxUploaderMonitor, UIGestureRecognizerDelegate>

@property (strong, nonatomic) IBOutlet UIBarButtonItem *editButton;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *cancelButton;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *deleteButton;

@property (strong, nonatomic) MGSwipeButton *dropboxUploadButton;
@property (strong, nonatomic) MGSwipeButton *shareButton;
@property (strong, nonatomic) MGSwipeButton *swipeDeleteButton;

@property (weak, nonatomic) BRHAppDelegate *delegate;
@property (strong, nonatomic) NSFetchedResultsController *fetchedResultsController;
@property (strong, nonatomic) BRHTimeFormatter *durationFormatter;

- (void)configureCell:(MGSwipeTableCell *)cell atIndexPath:(NSIndexPath *)indexPath;
- (void)updateRowFor:(BRHRecordingInfo *)recordingInfo;
- (void)updateButtonsToMatchTableState;
- (void)updateDeleteButtonTitle;

@end

@implementation BRHRecordingsViewController

#pragma mark - View Lifecycle

- (instancetype)initWithCoder:(NSCoder *)decoder
{
    NSLog(@"BRHRecordingsViewController.initWithCoder");
    if (self = [super initWithCoder:decoder]) {
        _fetchedResultsController = nil;
        _dropboxUploader = nil;
    }

    return self;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == kKVOContext) {
        if ([keyPath isEqualToString:@"progress"]) {
            [self updateRowFor:object];
        }
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)viewDidLoad {
    NSLog(@"BRHRecordingsViewController.viewDidLoad");
    [super viewDidLoad];

    self.tableView.allowsSelection = YES;
    self.tableView.allowsSelectionDuringEditing = YES;
    self.delegate = [UIApplication sharedApplication].delegate;
    self.durationFormatter = [BRHTimeFormatter new];

    // Allow a double-tap on the navbar to hide this view
    //
    UITapGestureRecognizer* doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(doubleTap:)];
    doubleTap.delegate = self;
    doubleTap.numberOfTapsRequired = 2;
    doubleTap.numberOfTouchesRequired = 1;
    [self.navigationController.navigationBar addGestureRecognizer:doubleTap];

    // Allow a double-tap on a cell to show the entry and hide this view
    //
    doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(doubleTap:)];
    doubleTap.delegate = self;
    doubleTap.numberOfTapsRequired = 2;
    doubleTap.numberOfTouchesRequired = 1;
    [self.tableView addGestureRecognizer:doubleTap];

    // Fetch any previous recordings to show
    //
    NSError *error;
    if (![[self fetchedResultsController] performFetch:&error]) {
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }
    
    [self updateButtonsToMatchTableState];
}

- (void)updateRowFor:(BRHRecordingInfo *)recordingInfo
{
    NSIndexPath *indexPath = [self.fetchedResultsController indexPathForObject:recordingInfo];
    [self configureCell:(MGSwipeTableCell *)[self.tableView cellForRowAtIndexPath:indexPath] atIndexPath:indexPath];
}

- (NSArray *)createLeftButtons
{
    UIImage *dropboxImage = [UIImage imageNamed:@"dropbox"];
    UIImage *shareImage = [UIImage imageNamed:@"share"];
    
    return @[
             [MGSwipeButton buttonWithTitle:@"" icon:dropboxImage backgroundColor:[UIColor whiteColor] padding:10 callback:^BOOL(MGSwipeTableCell *sender) {
                 NSIndexPath *path = [self.tableView indexPathForCell:sender];
                 BRHRecordingInfo *recordingInfo = [self.fetchedResultsController objectAtIndexPath:path];
                 if (_dropboxUploader) {
                     recordingInfo.uploaded = NO;
                     recordingInfo.awaitingUpload = YES;
                     NSIndexPath *indexPath = [self.fetchedResultsController indexPathForObject:recordingInfo];
                     [self configureCell:(MGSwipeTableCell *)[self.tableView cellForRowAtIndexPath:indexPath] atIndexPath:indexPath];
                     _dropboxUploader.uploadingFile = recordingInfo;
                 }
                 return YES;
             }],
             [MGSwipeButton buttonWithTitle:@"" icon:shareImage backgroundColor:[UIColor whiteColor] padding:10 callback:^BOOL(MGSwipeTableCell *sender) {
                 return YES;
             }]
             ];
}

- (NSArray *)createRightButtons
{
    return @[
             [MGSwipeButton buttonWithTitle:@"Delete" backgroundColor:[UIColor redColor] callback:^BOOL(MGSwipeTableCell *sender) {
                 NSIndexPath *path = [self.tableView indexPathForCell:sender];
                 NSLog(@"path: %@", path.description);
                 BRHRecordingInfo *recordingInfo = [self.fetchedResultsController objectAtIndexPath:path];
                 [self.delegate deleteRecording:recordingInfo];
                 return NO;
             }]
             ];
}

- (void)configureCell:(MGSwipeTableCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
    BRHRecordingInfo *recordingInfo = [self.fetchedResultsController objectAtIndexPath:indexPath];
    NSLog(@"configureCell - %@", recordingInfo);
    
    cell.textLabel.text = recordingInfo.name;
    
    cell.leftSwipeSettings.transition = MGSwipeTransitionStatic;
    cell.leftButtons = [self createLeftButtons];
    
    cell.rightSwipeSettings.transition = MGSwipeTransitionStatic;
    cell.rightButtons = [self createRightButtons];
    
    cell.allowsMultipleSwipe = NO;
    
    NSString *status;
    UIColor *statusColor = [UIColor blackColor];
    
    if (recordingInfo.recordingNow) {
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
    else if (recordingInfo.errorCode) {
        statusColor = [UIColor redColor];
        status = [NSString stringWithFormat:@"Failed (%d)", recordingInfo.errorCode];
    }
    else if (recordingInfo.awaitingUpload){
        status = @"Awaiting upload";
    }
    else {
        status = @"Not uploaded";
    }
    
    cell.detailTextLabel.textColor = statusColor;
    if (recordingInfo.size.length > 1) {
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ • %@ - %@", recordingInfo.durationString,
                                     recordingInfo.size, status];
    }
    else {
        cell.detailTextLabel.text = status;
    }
    
    if (! recordingInfo.uploaded && recordingInfo.uploading) {
        MACircleProgressIndicator *accessoryView = (MACircleProgressIndicator *)[cell accessoryView];
        if (accessoryView == nil) {
            accessoryView = [[MACircleProgressIndicator alloc] initWithFrame:CGRectMake(0.0, 0.0, 25.0, 25.0)];
            accessoryView.color = [UIColor blueColor];
            accessoryView.backgroundColor = [UIColor whiteColor];
            [cell setAccessoryView:accessoryView];
            [recordingInfo addObserver:self forKeyPath:@"progress" options:NSKeyValueObservingOptionNew context:kKVOContext];
        }
        
        NSLog(@"configureCell - progress: %f", recordingInfo.progress);
        accessoryView.value = recordingInfo.progress;
    }
    else {
        [cell setAccessoryView:nil];
    }
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
        if (count > 1 || (count == 1 && ! ((BRHRecordingInfo *)[self.fetchedResultsController fetchedObjects].firstObject).recordingNow)) {
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

#pragma mark - UITableViewDataSource Methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [[self.fetchedResultsController sections] count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    id <NSFetchedResultsSectionInfo> sectionInfo = [[self.fetchedResultsController sections] objectAtIndex:section];
    return [sectionInfo numberOfObjects];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString* kCellIdentifier = @"swipeCell";
    MGSwipeTableCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellIdentifier];
    if (! cell) {
        cell = [[MGSwipeTableCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:kCellIdentifier];
    }
    
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    BRHRecordingInfo *recordingInfo = [self.fetchedResultsController objectAtIndexPath:indexPath];
    return ! recordingInfo.recordingNow;
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

#pragma mark - UITableViewDelegate Methods

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

#if 1

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

#endif

#pragma mark - Core Data / UITableView Interaction

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
            [self configureCell:(MGSwipeTableCell *)[tableView cellForRowAtIndexPath:indexPath] atIndexPath:indexPath];
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

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    if (! self.isViewLoaded) return;
    [self.tableView endUpdates];
    [self updateButtonsToMatchTableState];
    [_delegate saveContext];
}

- (NSFetchedResultsController *)fetchedResultsController
{
    if (_fetchedResultsController != nil) return _fetchedResultsController;

    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:BRHRecordingInfoDataModelName
                                              inManagedObjectContext:_delegate.managedObjectContext];
    [fetchRequest setEntity:entity];

    NSSortDescriptor *nameDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"name" ascending:NO];
    [fetchRequest setSortDescriptors:[NSArray arrayWithObject:nameDescriptor]];
    [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"NOT name MATCHES %@", @"-"]];

    _fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
                                                                    managedObjectContext:_delegate.managedObjectContext
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
    for (BRHRecordingInfo *recordingInfo in recordings) {
        if (! recordingInfo.uploaded && ! recordingInfo.recordingNow && ! recordingInfo.errorCode && recordingInfo.awaitingUpload) {
            recordingInfo.uploading = YES;
            [self updateRowFor:recordingInfo];
            NSLog(@"nextToUpload - %@", recordingInfo);
            return recordingInfo;
        }
    }
    
    return nil;
}

- (BRHRecordingInfo *)dropboxUploaderReadyToUpload:(BRHDropboxUploader *)dropboxUploader
{
    return [self nextToUpload];
}

- (void)dropboxUploader:(BRHDropboxUploader *)dropboxUploader monitorFinishedWith:(BRHRecordingInfo *)recordingInfo
{
    NSLog(@"dropboxUploader:monitorFinishedWith: %@", recordingInfo);
    [recordingInfo removeObserver:self forKeyPath:@"progress"];
    [_delegate saveContext];
}

@end
