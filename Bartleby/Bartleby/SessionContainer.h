//
//  SessionContainer.h
//  Bartleby
//
//  Created by Trevor Vieweg on 7/11/15.
//  Copyright (c) 2015 Trevor Vieweg. All rights reserved.
//

#import <MultipeerConnectivity/MultipeerConnectivity.h>
#import <Foundation/Foundation.h>

@class Transcript;

@protocol SessionContainerDelegate;

// Container utility class for managing MCSession state, API calls, and it's delegate callbacks
@interface SessionContainer : NSObject <MCSessionDelegate>

@property (nonatomic, readonly) MCSession *session;
@property (nonatomic, assign) id<SessionContainerDelegate> delegate;
@property (nonatomic, strong) NSMutableArray *sessionTranscripts;

//Used to track any peers that have ever been connected to the session
@property (nonatomic, strong) NSMutableArray *peersConnectedToSession;

// Designated initializers
- (id)initWithDisplayName:(NSString *)displayName serviceType:(NSString *)serviceType;

- (id)initWithPeerID:(MCPeerID *)peerID serviceType:(NSString *)serviceType;
// Method for sending text messages to all connected remote peers.  Returna a message type transcript
- (Transcript *)sendMessage:(NSString *)message;
// Method for sending image resources to all connected remote peers.  Returns an progress type transcript for monitoring tranfer
- (Transcript *)sendImage:(NSURL *)imageUrl;

@end

// Delegate protocol for updating UI when we receive data or resources from peers.
@protocol SessionContainerDelegate <NSObject>

// Method used to signal to UI an initial message, incoming image resource has been received
- (void)receivedTranscript:(Transcript *)transcript;
// Method used to signal to UI an image resource transfer (send or receive) has completed
- (void)updateTranscript:(Transcript *)transcript;

@end
