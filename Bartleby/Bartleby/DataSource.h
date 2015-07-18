//
//  DataSource.h
//  Bartleby
//
//  Created by Trevor Vieweg on 7/11/15.
//  Copyright (c) 2015 Trevor Vieweg. All rights reserved.
//

@import MultipeerConnectivity;

@class SessionContainer;

#import <Foundation/Foundation.h>

@protocol DataSourceDelegate <NSObject>

- (void) userAcceptedNewConversationRequest; 

@end

@interface DataSource : NSObject

//user ID, service type and advertiser set at initialization
@property (nonatomic, strong) MCPeerID *userID;
@property (nonatomic, strong) NSString *serviceType;
@property (retain, nonatomic) MCNearbyServiceAdvertiser *advertiser;
@property (retain, nonatomic) MCNearbyServiceBrowser *browser; 

//Used
@property (nonatomic, strong) NSMutableArray *availablePeers;

@property (nonatomic, strong) NSMutableArray *activeConversations;
@property (nonatomic, strong) NSMutableArray *archivedConversations; 

@property (nonatomic, assign) BOOL isNewConversation; 

@property (nonatomic, strong) SessionContainer *currentConversation;

//Used to temporarily store conversation while connecting to session.
@property (nonatomic, strong) SessionContainer *ConvWithInitialConnectionInProgress;

+ (instancetype) sharedInstance;

- (SessionContainer *) createNewSessionWithPeerID:(MCPeerID *)peerID;

//Save active conversations property to disk. Use whenever activeConversations is updated. 
- (void) saveConversationsToDisk;

//KVO methods - made public since changes are made to Active Conversations by SessionContainer during connections
- (NSUInteger) countOfActiveConversations;
- (id) objectInActiveConversationsAtIndex:(NSUInteger)index;
- (NSArray *) activeConversationsAtIndexes:(NSIndexSet *)indexes;
- (void) insertObject:(SessionContainer *)object inActiveConversationsAtIndex:(NSUInteger)index;
- (void) removeObjectFromActiveConversationsAtIndex:(NSUInteger)index;
- (void) replaceObjectInActiveConversationsAtIndex:(NSUInteger)index withObject:(id)object;
- (void) deleteActiveConversation:(SessionContainer *)activeConversation;
- (void) addActiveConversationsObject:(SessionContainer *)activeConversation;

@end
