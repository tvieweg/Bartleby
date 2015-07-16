//
//  ConversationViewController.m
//  Bartleby
//
//  Created by Trevor Vieweg on 7/11/15.
//  Copyright (c) 2015 Trevor Vieweg. All rights reserved.
//

@import MultipeerConnectivity;

#import "ConversationViewController.h"
#import "DataSource.h"
#import "SessionContainer.h"
#import "PeerBrowserTableViewController.h"

@interface ConversationViewController () <UITableViewDataSource, UITableViewDelegate>

@end

@implementation ConversationViewController

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:YES];
    
    [self.tableView reloadData];
    [self checkEmptyTableView];
    
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    //Register for KVO on active conversations.
    [[DataSource sharedInstance] addObserver:self forKeyPath:@"activeConversations" options:0 context:nil];
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(didPressAddConversation)];
}


#pragma mark - Table view

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.

    return [DataSource sharedInstance].activeConversations.count;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"conversationCell" forIndexPath:indexPath];
    
    SessionContainer *conversation = [DataSource sharedInstance].activeConversations[indexPath.row];
    
    cell.textLabel.text = conversation.displayName;
    
    //cell.layer.cornerRadius = 10;
    //cell.layer.masksToBounds = YES;
    //cell.backgroundColor = [UIColor whiteColor];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [DataSource sharedInstance].currentConversation = [DataSource sharedInstance].activeConversations[indexPath.row];
    [self performSegueWithIdentifier:@"showChat" sender:self]; 
}

- (BOOL) tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void) tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (editingStyle == UITableViewCellEditingStyleDelete) {
         // Delete the row from the data source
         [[DataSource sharedInstance].activeConversations removeObjectAtIndex:indexPath.row];
         [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
         
         [self checkEmptyTableView]; 
     }
}

//Helper function to set table to single message if empty.
- (void) checkEmptyTableView {
    if ([DataSource sharedInstance].activeConversations.count == 0) {
        
        UILabel *nothingLabel = [[UILabel alloc] initWithFrame:self.tableView.frame];
        nothingLabel.text = NSLocalizedString(@"No conversations here. Start a new one by hitting the + above!", nil);
        nothingLabel.textAlignment = NSTextAlignmentCenter;
        nothingLabel.numberOfLines = 0;
        
        self.tableView.backgroundView = nothingLabel;
        self.tableView.separatorColor = [UIColor clearColor];
        
    } else {
        self.tableView.backgroundView = nil;
        self.tableView.separatorColor = [UIColor grayColor];
    }
}

#pragma mark - Add Conversations

- (void) didPressAddConversation {
    // Instantiate session and present the MCBrowserViewController
    [DataSource sharedInstance].currentConversation = [[DataSource sharedInstance] createNewSessionWithPeerID:[DataSource sharedInstance].userID];
    [DataSource sharedInstance].isNewConversation = YES; 
    
    [self performSegueWithIdentifier:@"showChat" sender:self];

}

#pragma mark - KVO

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (object == [DataSource sharedInstance] && [keyPath isEqualToString:@"activeConversations"]) {
        int kindOfChange = [change[NSKeyValueChangeKindKey] intValue];
        
        if (kindOfChange == NSKeyValueChangeSetting ||
            kindOfChange == NSKeyValueChangeInsertion ||
            kindOfChange == NSKeyValueChangeRemoval ||
            kindOfChange == NSKeyValueChangeReplacement) {

            [self checkEmptyTableView];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.tableView reloadData];
            });

            
        }
    }
}

- (void) dealloc {
    
    [[DataSource sharedInstance] removeObserver:self forKeyPath:@"activeConversations"];
    
}

@end
