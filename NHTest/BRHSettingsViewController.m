//
//  BRHSettingsViewController.m
//  NHTest
//
//  Created by Brad Howes on 4/12/14.
//  Copyright (c) 2014 Brad Howes. All rights reserved.
//

#import "BRHSettingsViewController.h"
#import "BRHAppDelegate.h"
#import "BRHNotificationDriver.h"

@interface BRHSettingsViewController ()

@end

@implementation BRHSettingsViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{

    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        self.delegate = self;
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)viewDidAppear:(BOOL)animated
{
    BRHAppDelegate *delegate = [[UIApplication sharedApplication] delegate];
    [delegate.notificationDriver editingSettings:true];
    [super viewDidAppear:animated];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)dismiss:(id)sender
{
    BRHAppDelegate *delegate = [[UIApplication sharedApplication] delegate];
    [delegate.notificationDriver editingSettings:false];
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
