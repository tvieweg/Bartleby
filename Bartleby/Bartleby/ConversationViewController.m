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

@interface ConversationViewController () <UITableViewDataSource, UITableViewDelegate, MCBrowserViewControllerDelegate>

@property (nonatomic, strong) NSMutableArray *conversations;
@property (nonatomic, strong) SessionContainer *addedSession;

@end

@implementation ConversationViewController

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:YES];
    [self.tableView reloadData];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
    
    //self.tableView.backgroundColor = [UIColor blueColor];
    //self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(didPressAddConversation)];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
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
    NSMutableString *conversationTitle = [NSMutableString stringWithString:@"Chat with "];
    for (MCPeerID *connectedPeer in conversation.session.connectedPeers) {
        [conversationTitle appendString:connectedPeer.displayName];
        
    }
    NSLog(@"%@", conversationTitle);
    
    conversation.conversationDisplayName = conversationTitle;
    
    cell.textLabel.text = conversation.conversationDisplayName;
    
    //cell.layer.cornerRadius = 10;
    //cell.layer.masksToBounds = YES;
    //cell.backgroundColor = [UIColor whiteColor];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [DataSource sharedInstance].currentConversation = [DataSource sharedInstance].activeConversations[indexPath.row];
    [self performSegueWithIdentifier:@"showChat" sender:self]; 
}
/*
 // Override to support conditional editing of the table view.
 - (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
 // Return NO if you do not want the specified item to be editable.
 return YES;
 }
 */

/*
 // Override to support editing the table view.
 - (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
 if (editingStyle == UITableViewCellEditingStyleDelete) {
 // Delete the row from the data source
 [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
 } else if (editingStyle == UITableViewCellEditingStyleInsert) {
 // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
 }
 }
 */

/*
 // Override to support rearranging the table view.
 - (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
 }
 */

/*
 // Override to support conditional rearranging of the table view.
 - (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
 // Return NO if you do not want the item to be re-orderable.
 return YES;
 }
 */


 #pragma mark - Navigation
 
 // In a storyboard-based application, you will often want to do a little preparation before navigation
 - (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
 // Get the new view controller using [segue destinationViewController].
 // Pass the selected object to the new view controller.
 }





#pragma mark - Add Conversation

- (void) didPressAddConversation {
    // Instantiate and present the MCBrowserViewController
    
    self.addedSession = [[DataSource sharedInstance] createNewSessionWithName:[DataSource sharedInstance].userName];
    
    MCBrowserViewController *browserViewController = [[MCBrowserViewController alloc] initWithServiceType:[DataSource sharedInstance].serviceType session:self.addedSession.session];
    
    browserViewController.delegate = self;
    browserViewController.minimumNumberOfPeers = kMCSessionMinimumNumberOfPeers;
    browserViewController.maximumNumberOfPeers = kMCSessionMaximumNumberOfPeers;
    
    [self presentViewController:browserViewController animated:YES completion:nil];
}

#pragma mark - MCBrowserViewControllerDelegate methods

// Override this method to filter out peers based on application specific needs
- (BOOL)browserViewController:(MCBrowserViewController *)browserViewController shouldPresentNearbyPeer:(MCPeerID *)peerID withDiscoveryInfo:(NSDictionary *)info
{
    return YES;
}

// Override this to know when the user has pressed the "done" button in the MCBrowserViewController
- (void)browserViewControllerDidFinish:(MCBrowserViewController *)browserViewController
{
    if (self.addedSession.session.connectedPeers.count < 1) {
        [[DataSource sharedInstance].activeConversations removeObject:self.addedSession];
    }
    
    [browserViewController dismissViewControllerAnimated:YES completion:nil];
}

// Override this to know when the user has pressed the "cancel" button in the MCBrowserViewController
- (void)browserViewControllerWasCancelled:(MCBrowserViewController *)browserViewController
{
    
    if (self.addedSession.session.connectedPeers.count < 1) {
        [[DataSource sharedInstance].activeConversations removeObject:self.addedSession];
    }
    
    [browserViewController dismissViewControllerAnimated:YES completion:nil];
}


@end
