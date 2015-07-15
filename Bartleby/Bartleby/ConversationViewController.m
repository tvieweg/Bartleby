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

@property (nonatomic, strong) NSMutableArray *conversations;

@end

@implementation ConversationViewController

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:YES];
    [self.tableView reloadData];
    [self checkEmptyTableView];

    
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [[DataSource sharedInstance] addObserver:self forKeyPath:@"activeConversations" options:0 context:nil];
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(didPressAddConversation)];
}

- (void) checkEmptyTableView {
    
    UILabel *nothingLabel = [[UILabel alloc] initWithFrame:self.tableView.frame];

    if ([DataSource sharedInstance].activeConversations.count == 0) {
        
        nothingLabel.text = @"No conversations here. Start a new one by hitting the + above!";
        nothingLabel.textAlignment = NSTextAlignmentCenter;
        nothingLabel.numberOfLines = 0;
        
        self.tableView.backgroundView = nothingLabel;
        self.tableView.separatorColor = [UIColor clearColor];
        
    } else {
        self.tableView.backgroundView = nil;
        self.tableView.separatorColor = [UIColor grayColor];
    }
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
    
    cell.textLabel.text = [conversation.peersConnectedToSession componentsJoinedByString:@", "];
    
    //cell.layer.cornerRadius = 10;
    //cell.layer.masksToBounds = YES;
    //cell.backgroundColor = [UIColor whiteColor];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [DataSource sharedInstance].currentConversation = [DataSource sharedInstance].activeConversations[indexPath.row];
    [self performSegueWithIdentifier:@"showChat" sender:self]; 
}

 // Override to support conditional editing of the table view.
 - (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
 // Return NO if you do not want the specified item to be editable.
 return YES;
 }

 // Override to support editing the table view.
 - (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
     if (editingStyle == UITableViewCellEditingStyleDelete) {
         // Delete the row from the data source
         [[DataSource sharedInstance].activeConversations removeObjectAtIndex:indexPath.row];
         [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
         
         [self checkEmptyTableView]; 
     }
 }

 #pragma mark - Navigation
 
 // In a storyboard-based application, you will often want to do a little preparation before navigation
 - (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
 // Get the new view controller using [segue destinationViewController].
 // Pass the selected object to the new view controller.
 }

#pragma mark - Add Conversation

- (void) didPressAddConversation {
    // Instantiate session and present the MCBrowserViewController
    [DataSource sharedInstance].currentConversation = [[DataSource sharedInstance] createNewSessionWithPeerID:[DataSource sharedInstance].userID];
    
    [self performSegueWithIdentifier:@"showChat" sender:self];

}

#pragma KVO

- (void) dealloc {
    
    [[DataSource sharedInstance] removeObserver:self forKeyPath:@"activeConversations"];

}

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

@end
