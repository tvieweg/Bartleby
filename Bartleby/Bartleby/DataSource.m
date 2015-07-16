//
//  DataSource.m
//  Bartleby
//
//  Created by Trevor Vieweg on 7/11/15.
//  Copyright (c) 2015 Trevor Vieweg. All rights reserved.
//

#import "DataSource.h"
#import "SessionContainer.h"

NSString *const kDSServiceType = @"bartleby-chat";

@interface DataSource () <MCNearbyServiceAdvertiserDelegate, UIAlertViewDelegate> {
    NSMutableArray *_activeConversations;
}

//Used to store parameters when accepting invitations.
@property (nonatomic, strong) NSArray *invitationHandler;
@property (nonatomic, strong) MCPeerID *invitationPeer;

@end

@implementation DataSource

+ (instancetype) sharedInstance {
    static dispatch_once_t once;
    static id sharedInstance;
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype) init {
    self = [super init];
    
    if (self) {
        
        //set userID and service type.
        self.serviceType = kDSServiceType;
        self.userID = [[MCPeerID alloc] initWithDisplayName:[[UIDevice currentDevice] name]];
        
        //start advertiser on app start.
        self.advertiser = [[MCNearbyServiceAdvertiser alloc] initWithPeer:self.userID discoveryInfo:nil serviceType:self.serviceType];
        self.advertiser.delegate = self;
        [self.advertiser startAdvertisingPeer];
        
        //initialize arrays
        self.activeConversations = [NSMutableArray new];
        self.availablePeers = [NSMutableArray new];
        self.connectedPeers = [NSMutableArray new];
        
        //Used by ConversationViewController to tell ChatViewController when user is creating a new conversation. 
        self.isNewConversation = NO;
        
    }
    
    return self;
}

#pragma mark - Session Creation

- (SessionContainer *) createNewSessionWithPeerID:(MCPeerID *)peerID {
    
    SessionContainer *newSession = [[SessionContainer alloc] initWithPeerID:self.userID serviceType:self.serviceType];
    return newSession;
}


#pragma mark - Advertiser Delegate

- (void)advertiser:(MCNearbyServiceAdvertiser *)advertiser didReceiveInvitationFromPeer:(MCPeerID *)peerID withContext:(NSData *)context invitationHandler:(void(^)(BOOL accept, MCSession *session))invitationHandler {
    
    self.invitationHandler = [NSArray arrayWithObject:invitationHandler];
    self.invitationPeer = peerID;
    
    NSString *title = [NSString stringWithFormat:@"%@", self.invitationPeer.displayName];
    
    NSString *message = [NSString stringWithFormat:@"%@ wants to connect", self.invitationPeer.displayName];
    
    
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title
                                                        message:message
                                                       delegate:self
                                              cancelButtonTitle:@"Decline"
                                              otherButtonTitles:@"Accept", nil];
    
    [alertView show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    
    BOOL accept = (buttonIndex != alertView.cancelButtonIndex) ? YES : NO;
    
    SessionContainer *newSession = [[DataSource sharedInstance] createNewSessionWithPeerID:self.invitationPeer];
    self.ConvWithInitialConnectionInProgress = newSession;
    void (^invitationHandler)(BOOL, MCSession *) = [self.invitationHandler objectAtIndex:0];
    
    invitationHandler(accept, newSession.session);
    
}


- (void) dealloc {
    [self.advertiser stopAdvertisingPeer];
}

#pragma mark - KVO for activeConversations

- (NSUInteger) countOfActiveConversations {
    return self.activeConversations.count;
}

- (id) objectInActiveConversationsAtIndex:(NSUInteger)index {
    return [self.activeConversations objectAtIndex:index];
}

- (NSArray *) activeConversationsAtIndexes:(NSIndexSet *)indexes {
    return [self.activeConversations objectsAtIndexes:indexes];
}

- (void) insertObject:(SessionContainer *)object inActiveConversationsAtIndex:(NSUInteger)index {
    [_activeConversations insertObject:object atIndex:index];
}

- (void) removeObjectFromActiveConversationsAtIndex:(NSUInteger)index {
    [_activeConversations removeObjectAtIndex:index];
}

- (void) replaceObjectInActiveConversationsAtIndex:(NSUInteger)index withObject:(id)object {
    [_activeConversations replaceObjectAtIndex:index withObject:object];
}

-(void) deleteActiveConversation:(SessionContainer *)activeConversation {
    NSMutableArray *mutableArrayWithKVO = [self mutableArrayValueForKey:@"activeConversations"];
    [mutableArrayWithKVO removeObject:activeConversation];
}

- (void) addActiveConversationsObject:(SessionContainer *)activeConversation {
    NSMutableArray *mutableArrayWithKVO = [self mutableArrayValueForKey:@"activeConversations"];
    [mutableArrayWithKVO addObject:activeConversation];
}

@end
