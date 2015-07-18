//
//  PeerBrowserTableViewController.m
//  Bartleby
//
//  Created by Trevor Vieweg on 7/13/15.
//  Copyright (c) 2015 Trevor Vieweg. All rights reserved.
//

@import MultipeerConnectivity;

#import "PeerBrowserTableViewController.h"
#import "SessionContainer.h"
#import "DataSource.h"

@interface PeerBrowserTableViewController () <MCNearbyServiceBrowserDelegate>

@property (nonatomic, strong) MCPeerID *myUserID;
@property (nonatomic, strong) MCNearbyServiceBrowser *browser;
@property (nonatomic, strong) UINavigationBar *navBar;
@property (nonatomic, strong) NSMutableArray *availableUsers;

@end

@implementation PeerBrowserTableViewController

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:YES];
    
    self.availableUsers = [NSMutableArray new];
    [self availableUsersForConversation];
    [self.tableView reloadData];
    [self checkEmptyTableView];
    
    self.browser = [DataSource sharedInstance].browser;
    self.browser.delegate = self;
    [self.browser startBrowsingForPeers];
    
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:YES];
    [self.browser stopBrowsingForPeers];
    
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.myUserID = [DataSource sharedInstance].userID;
    
    self.navigationItem.title = @"Add Peers";
    self.navBar = [[UINavigationBar alloc] initWithFrame:CGRectZero];
    [self.view addSubview:self.navBar];
    [self.navBar pushNavigationItem:self.navigationItem animated:NO];
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(didPressDone)];
    
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(didPressCancel)];

}

-(void)layoutNavigationBar{
    self.navBar.frame = CGRectMake(0, self.tableView.contentOffset.y, self.tableView.frame.size.width, self.topLayoutGuide.length + 44);
    self.tableView.contentInset = UIEdgeInsetsMake(self.navBar.frame.size.height, 0, 0, 0);
}


- (void) checkEmptyTableView {
    if (self.availableUsers.count == 0) {
        
        UILabel *nothingLabel = [[UILabel alloc] initWithFrame:self.tableView.frame];
        nothingLabel.text = @"No one's around! Try moving locations or wait a while";
        nothingLabel.textAlignment = NSTextAlignmentCenter;
        nothingLabel.numberOfLines = 0;
        
        self.tableView.backgroundView = nothingLabel;
        self.tableView.separatorColor = [UIColor clearColor];
        
    } else {
        self.tableView.backgroundView = nil;
        self.tableView.separatorColor = [UIColor grayColor];
    }
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections (connected, available)
    return 1;
}



- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {

    return self.availableUsers.count;
    
}

- (void) availableUsersForConversation {
    [self.availableUsers removeAllObjects];
    for (MCPeerID *availableUser in [DataSource sharedInstance].availablePeers) {
        BOOL shouldIncludeUserInAvailableList = YES;
        
        for (MCPeerID *connectedPeer in [DataSource sharedInstance].currentConversation.session.connectedPeers) {
            if ([availableUser isEqual:connectedPeer]) {
                shouldIncludeUserInAvailableList = NO;
            }
        }
        
        if (shouldIncludeUserInAvailableList) {
            [self.availableUsers insertObject:availableUser atIndex:0];
        }

    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
    
    if ([cell isEqual:nil]) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                       reuseIdentifier:@"cell"];
    }
    
    MCPeerID *availableUser = self.availableUsers[indexPath.row];
    
    //Update later to show changes to availability. 
    cell.textLabel.text = availableUser.displayName;
    cell.detailTextLabel.text = @"Available";
    
    
    return cell;
}

#pragma mark - MCNearbyServiceBrowserDelegate

- (void) browser:(MCNearbyServiceBrowser *)browser foundPeer:(MCPeerID *)peerID withDiscoveryInfo:(NSDictionary *)info {
    
    //Check for duplicate lists.
    BOOL shouldBeAdded = YES;
    
    for (MCPeerID *previousFoundPeer in [DataSource sharedInstance].availablePeers) {
        if ([peerID isEqual:previousFoundPeer]) {
            shouldBeAdded = NO;
        }
    }
    
    if (shouldBeAdded) {
        
        //Update model
        [[DataSource sharedInstance].availablePeers insertObject:peerID atIndex:0];
        [self availableUsersForConversation];
        
        //Update view
        [self.tableView reloadData];
        [self checkEmptyTableView];

    }
    
}

- (void) browser:(MCNearbyServiceBrowser *)browser lostPeer:(MCPeerID *)peerID {
    
    //Update model
    [[DataSource sharedInstance].availablePeers removeObject:peerID];
    [self availableUsersForConversation];
    
    //Update view
    [self.tableView reloadData];
    [self checkEmptyTableView];

}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    MCPeerID *peerToConnect = [DataSource sharedInstance].availablePeers[indexPath.row];
    SessionContainer *sessionToMoveToActive;
    
    //check new session against existing sessions. If one already exists, replace it. If not, create new session.
    for (SessionContainer *activeConversation in [DataSource sharedInstance].activeConversations) {
        if ([activeConversation.displayName isEqualToString:peerToConnect.displayName]) {
            
            [DataSource sharedInstance].currentConversation = activeConversation;
            
        }
    }
    
    for (SessionContainer *archivedConversation in [DataSource sharedInstance].archivedConversations) {
        if ([archivedConversation.displayName isEqualToString:peerToConnect.displayName]) {
            
            //hold session here and move after enumeration.
            sessionToMoveToActive = archivedConversation;
            [DataSource sharedInstance].currentConversation = archivedConversation;
            
        }
        
    }
    
    if (sessionToMoveToActive) {
        [[DataSource sharedInstance].activeConversations insertObject:sessionToMoveToActive atIndex:0];
        [[DataSource sharedInstance].archivedConversations removeObject:sessionToMoveToActive];
        
        NSLog(@"Count of archived conversations is now %lu", [DataSource sharedInstance].archivedConversations.count); 
    }


    [self.browser invitePeer:peerToConnect toSession:[DataSource sharedInstance].currentConversation.session
                 withContext:nil
                     timeout:30];
        
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    [self dismissViewControllerAnimated:YES completion:nil]; 
    
}

#pragma mark - scroll layout

-(void)scrollViewDidScroll:(UIScrollView *)scrollView{
    //no need to call super
    [self layoutNavigationBar];
}

-(void)viewDidLayoutSubviews{
    [super viewDidLayoutSubviews];
    [self layoutNavigationBar];
}

- (void) didPressDone {
    [self dismissViewControllerAnimated:YES completion:nil]; 
}

- (void) didPressCancel {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
