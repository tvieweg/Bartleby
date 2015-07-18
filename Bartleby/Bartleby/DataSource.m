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
        
        self.availablePeers = [NSMutableArray new];

        //start advertiser on app start.
        self.advertiser = [[MCNearbyServiceAdvertiser alloc] initWithPeer:self.userID discoveryInfo:nil serviceType:self.serviceType];
        self.advertiser.delegate = self;
        [self.advertiser startAdvertisingPeer];
        
        //initialize browser. Will be used by PeerBrowserTableViewController
        self.browser = [[MCNearbyServiceBrowser alloc] initWithPeer:self.userID serviceType:self.serviceType];
        
        //read active conversation data, and if there is none, initialize array.
        [self readItemsForKey:@"activeConversations"];
        [self readItemsForKey:@"archivedConversations"]; 

        //Used by ConversationViewController to tell ChatViewController when user is creating a new conversation.
        self.isNewConversation = NO;
        
    }
    
    return self;
}

- (void) readItemsForKey:(NSString *)key {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *fullPath = [self pathForFilename:key];
        NSArray *storedConversationsForSelector = [NSKeyedUnarchiver unarchiveObjectWithFile:fullPath];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (storedConversationsForSelector.count > 0) {
                NSMutableArray *mutableConversationsForSelector = [storedConversationsForSelector mutableCopy];
                
                [self willChangeValueForKey:key];
                [self setValue:mutableConversationsForSelector forKey:key];
                [self didChangeValueForKey:key];
                
            } else {
                [self setValue:[NSMutableArray new] forKey:key];
            }
        });
    });

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
    
    BOOL noPreviousConversation = YES;
    
    BOOL accept = (buttonIndex != alertView.cancelButtonIndex) ? YES : NO;
    void (^invitationHandler)(BOOL, MCSession *) = [self.invitationHandler objectAtIndex:0];
    
    //check new session against existing sessions. If one already exists, replace it. If not, create new session.
    for (SessionContainer *activeConversation in self.activeConversations) {
        if ([activeConversation.displayName isEqualToString:self.invitationPeer.displayName]) {
            
            invitationHandler(accept, activeConversation.session);
            
            noPreviousConversation = NO;
        }
    }
    
    for (SessionContainer *archivedConversation in self.archivedConversations) {
        if ([archivedConversation.displayName isEqualToString:self.invitationPeer.displayName]) {
            
            [self.activeConversations insertObject:archivedConversation atIndex:0];
            [self.archivedConversations removeObject:archivedConversation];
            invitationHandler(accept, archivedConversation.session);
            
            noPreviousConversation = NO;
        }

    }
    
    if (noPreviousConversation) {
        
        SessionContainer *newSession = [[DataSource sharedInstance] createNewSessionWithPeerID:self.invitationPeer];
        self.ConvWithInitialConnectionInProgress = newSession;
        invitationHandler(accept, newSession.session);
        
    }


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
    [self saveConversationsToDisk];
}

- (void) removeObjectFromActiveConversationsAtIndex:(NSUInteger)index {
    [_activeConversations removeObjectAtIndex:index];
    [self saveConversationsToDisk];
}

- (void) replaceObjectInActiveConversationsAtIndex:(NSUInteger)index withObject:(id)object {
    [_activeConversations replaceObjectAtIndex:index withObject:object];
    [self saveConversationsToDisk];
}

-(void) deleteActiveConversation:(SessionContainer *)activeConversation {
    NSMutableArray *mutableArrayWithKVO = [self mutableArrayValueForKey:@"activeConversations"];
    [mutableArrayWithKVO removeObject:activeConversation];
    [self saveConversationsToDisk];
}

- (void) addActiveConversationsObject:(SessionContainer *)activeConversation {
    NSMutableArray *mutableArrayWithKVO = [self mutableArrayValueForKey:@"activeConversations"];
    [mutableArrayWithKVO addObject:activeConversation];
    [self saveConversationsToDisk];
}

#pragma mark - Keyed Archiver

- (NSString *) pathForFilename:(NSString *) filename {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths firstObject];
    NSString *dataPath = [documentsDirectory stringByAppendingPathComponent:filename];
    return dataPath;
}

- (void) saveConversationsToDisk {
    // Write active conversations to disk.
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSUInteger numberOfItemsToSave = MIN(self.activeConversations.count, 50);
        NSArray *activeConversationsToSave = [self.activeConversations subarrayWithRange:NSMakeRange(0, numberOfItemsToSave)];
        
        NSString *fullPath = [self pathForFilename:NSStringFromSelector(@selector(activeConversations))];
        NSData *activeConversationData = [NSKeyedArchiver archivedDataWithRootObject:activeConversationsToSave];
        
        NSError *dataError;
        BOOL wroteSuccessfully = [activeConversationData writeToFile:fullPath options:NSDataWritingAtomic | NSDataWritingFileProtectionCompleteUnlessOpen error:&dataError];
        
        if (!wroteSuccessfully) {
            NSLog(@"Couldn't write file: %@", dataError);
        }
    });
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSArray *archivedConversationsToSave = self.archivedConversations;
        
        NSString *fullPath = [self pathForFilename:NSStringFromSelector(@selector(archivedConversations))];
        NSData *archivedConversationData = [NSKeyedArchiver archivedDataWithRootObject:archivedConversationsToSave];
        
        NSError *dataError;
        BOOL wroteSuccessfully = [archivedConversationData writeToFile:fullPath options:NSDataWritingAtomic | NSDataWritingFileProtectionCompleteUnlessOpen error:&dataError];
        
        if (!wroteSuccessfully) {
            NSLog(@"Couldn't write file: %@", dataError);
        }
    });

}

@end
