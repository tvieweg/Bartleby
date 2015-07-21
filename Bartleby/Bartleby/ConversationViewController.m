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
#import "MCSwipeTableViewCell.h"
#import "Transcript.h"

@interface ConversationViewController () <UITableViewDataSource, UITableViewDelegate, MCSwipeTableViewCellDelegate>

@end

@implementation ConversationViewController

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:YES];
    
    if (![PFUser currentUser]) {
        [self.navigationController popToRootViewControllerAnimated:YES]; 
    }
    
    //Start datasource if not previously loaded.
    [DataSource sharedInstance];
    
    //Reset toolbar. Fixes bug where toolbar would sit in wrong position if user left keyboard open before segue. 
    [self.navigationController.toolbar setFrame:CGRectMake(self.navigationController.toolbar.frame.origin.x, CGRectGetMaxY(self.tableView.frame), self.navigationController.toolbar.frame.size.width, self.navigationController.toolbar.frame.size.height)];

    [self.tableView reloadData];
    [self checkEmptyTableView];
    
    self.navigationItem.hidesBackButton = YES;
    self.navigationController.navigationBarHidden = NO;
    self.navigationController.toolbarHidden = NO;


    
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    //Register for KVO on active conversations.
    [[DataSource sharedInstance] addObserver:self forKeyPath:@"activeConversations" options:0 context:nil];
    
    
    UIColor *navigationBarColor = [UIColor whiteColor];
    UIColor *textColor = [UIColor blackColor];
    
    self.navigationController.navigationBar.barTintColor = navigationBarColor;
    self.navigationController.toolbar.barTintColor = navigationBarColor;
    self.navigationController.navigationBar.tintColor = textColor;
    self.navigationController.toolbar.tintColor = textColor;
    self.navigationController.navigationBar.titleTextAttributes = @{NSForegroundColorAttributeName : textColor};
    
    self.tableView.backgroundColor = [UIColor colorWithRed:100/255.0 green:100/255.0 blue:120/255.0 alpha:1.0];
    
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone; 


    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(didPressAddConversation)];
    
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"user"] style:UIBarButtonItemStylePlain target:self action:@selector(didPressProfileButton)];
    
    [self.tableView reloadData]; 
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
    
    static NSString *cellIdentifier = @"cell";

    MCSwipeTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    
    SessionContainer *conversation = [DataSource sharedInstance].activeConversations[indexPath.row];

    [self configureCell:cell forRowAtIndexPath:indexPath];

    cell.conversationLabel.text = conversation.displayName;
    Transcript *lastMessage = [conversation.sessionTranscripts lastObject];
    
    if (lastMessage.message != nil) {
        cell.conversationPreview.text = lastMessage.message;
    } else {
        cell.conversationPreview.text = @"";
    }
    
    return cell;
}

- (void)configureCell:(MCSwipeTableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    
    UIView *crossView = [self viewWithImageName:@"cross"];
    UIColor *redColor = [UIColor colorWithRed:232.0 / 255.0 green:61.0 / 255.0 blue:14.0 / 255.0 alpha:1.0];
    
    UIView *listView = [self viewWithImageName:@"list"];
    UIColor *blueColor = [UIColor colorWithRed:25.0 / 255.0 green:40.0 / 255.0 blue:154.0 / 255.0 alpha:1.0];
    
    // Setting the default inactive state color to the tableView background color
    [cell setDefaultColor:self.tableView.backgroundView.backgroundColor];
    
    [cell setDelegate:self];
    
    [cell setSwipeGestureWithView:listView color:blueColor mode:MCSwipeTableViewCellModeExit state:MCSwipeTableViewCellState3 completionBlock:^(MCSwipeTableViewCell *cell, MCSwipeTableViewCellState state, MCSwipeTableViewCellMode mode) {
        
        NSLog(@"Did swipe \"list\" cell");
        
        //move conversation to archive and update table view.
        SessionContainer *archiveConversation = [[DataSource sharedInstance].activeConversations objectAtIndex:indexPath.row];
        [[DataSource sharedInstance].archivedConversations addObject:archiveConversation];
        [[DataSource sharedInstance].activeConversations removeObject:archiveConversation];
        
        [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
        [self checkEmptyTableView];
        
        NSLog(@"Count of archived conversations is now %lu", (unsigned long)[DataSource sharedInstance].archivedConversations.count);
    }];
    
    [cell setSwipeGestureWithView:crossView color:redColor mode:MCSwipeTableViewCellModeExit state:MCSwipeTableViewCellState4 completionBlock:^(MCSwipeTableViewCell *cell, MCSwipeTableViewCellState state, MCSwipeTableViewCellMode mode) {
        NSLog(@"Did swipe \"cross\" cell");
        [[DataSource sharedInstance].activeConversations removeObjectAtIndex:indexPath.row];
        
        [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
        
        [self checkEmptyTableView];

    }];
}


- (UIView *)viewWithImageName:(NSString *)imageName {
    UIImage *image = [UIImage imageNamed:imageName];
    UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
    imageView.contentMode = UIViewContentModeCenter;
    return imageView;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [DataSource sharedInstance].currentConversation = [DataSource sharedInstance].activeConversations[indexPath.row];
    [self performSegueWithIdentifier:@"showChat" sender:self]; 
}

- (BOOL) tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

//Helper function to set table to single message if empty.
- (void) checkEmptyTableView {
    if ([DataSource sharedInstance].activeConversations.count == 0) {
        
        UILabel *nothingLabel = [[UILabel alloc] initWithFrame:self.tableView.frame];
        nothingLabel.text = NSLocalizedString(@"No conversations here. Start a new one by hitting the + above!", nil);
        nothingLabel.textAlignment = NSTextAlignmentCenter;
        nothingLabel.numberOfLines = 0;
        nothingLabel.textColor = [UIColor whiteColor]; 
        
        self.tableView.backgroundView = nothingLabel;
        self.tableView.separatorColor = [UIColor clearColor];
        
    } else {
        self.tableView.backgroundView = nil;
        self.tableView.separatorColor = [UIColor grayColor];
    }
}

#pragma mark - MCSwipeTableViewCellDelegate


// When the user starts swiping the cell this method is called
- (void)swipeTableViewCellDidStartSwiping:(MCSwipeTableViewCell *)cell {
    // NSLog(@"Did start swiping the cell!");
}

// When the user ends swiping the cell this method is called
- (void)swipeTableViewCellDidEndSwiping:(MCSwipeTableViewCell *)cell {
    // NSLog(@"Did end swiping the cell!");
}

// When the user is dragging, this method is called and return the dragged percentage from the border
- (void)swipeTableViewCell:(MCSwipeTableViewCell *)cell didSwipeWithPercentage:(CGFloat)percentage {
    // NSLog(@"Did swipe with percentage : %f", percentage);
}


#pragma mark - Add Conversations

- (void) didPressAddConversation {
    // Instantiate session and present the MCBrowserViewController
    [DataSource sharedInstance].currentConversation = [[DataSource sharedInstance] createNewSessionWithPeerID:[DataSource sharedInstance].userID];
    [DataSource sharedInstance].isNewConversation = YES; 
    
    [self performSegueWithIdentifier:@"showChat" sender:self];

}

- (void) didPressProfileButton {
    [self performSegueWithIdentifier:@"showProfile" sender:self]; 
}

#pragma mark - KVO

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (object == [DataSource sharedInstance] && [keyPath isEqualToString:@"activeConversations"]) {
        int kindOfChange = [change[NSKeyValueChangeKindKey] intValue];
        
        if (kindOfChange == NSKeyValueChangeSetting ||
            kindOfChange == NSKeyValueChangeInsertion ||
            kindOfChange == NSKeyValueChangeRemoval ||
            kindOfChange == NSKeyValueChangeReplacement) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.tableView reloadData];
            });
            [self checkEmptyTableView];
            
            

            
        }
    }
}

- (void) dealloc {
    @try{
        [[DataSource sharedInstance] removeObserver:self forKeyPath:@"activeConversations"];
    }@catch(id exception){
        return;
    }
    
}

@end
