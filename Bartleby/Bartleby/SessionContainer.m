//
//  SessionContainer.m
//  Bartleby
//
//  Created by Trevor Vieweg on 7/11/15.
//  Copyright (c) 2015 Trevor Vieweg. All rights reserved.
//


@import MultipeerConnectivity;

#import "SessionContainer.h"
#import "Transcript.h"
#import "DataSource.h"

@interface SessionContainer()
// Framework UI class for handling incoming invitations
@property (nonatomic, strong) MCSession *session;

@end

@implementation SessionContainer

- (id)initWithPeerID:(MCPeerID *)peerID serviceType:(NSString *)serviceType
{
    if (self = [super init]) {
        
        self.peersConnectedToSession = [NSMutableArray new];
        // Create the session that peers will be invited/join into.
        self.session = [[MCSession alloc] initWithPeer:peerID securityIdentity:nil encryptionPreference:MCEncryptionRequired];
        self.session.delegate = self;
        // Create the advertiser assistant for managing incoming invitation
        _sessionTranscripts = [NSMutableArray new];
        self.displayName = peerID.displayName; 

    }
    return self;
}

// Helper method for human readable printing of MCSessionState.  This state is per peer.
- (NSString *)stringForPeerConnectionState:(MCSessionState)state
{
    switch (state) {
        case MCSessionStateConnected:
            return @"Connected";
            
        case MCSessionStateConnecting:
            return @"Connecting";

        case MCSessionStateNotConnected:
            return @"Not Connected";
    }
}

// Helper method to determine if peer should be added to total list of people who have connected to conversation.
- (void) addNewConnectedPeer:(NSString *)peerDisplayName {
    
    BOOL shouldAddPeer = YES;
    
    for (NSString *previousConnectedPeerDisplayName in self.peersConnectedToSession) {
        if ([peerDisplayName isEqualToString:previousConnectedPeerDisplayName]) {
            shouldAddPeer = NO;
        }
    }
    
    if (shouldAddPeer) {
        [self.peersConnectedToSession addObject:peerDisplayName];
        self.displayName = [self.peersConnectedToSession componentsJoinedByString:@", "]; 
    }
}

#pragma mark - Public methods

// Instance method for sending a string based text message to all remote peers
- (Transcript *)sendMessage:(NSString *)message
{
    // Convert the string into a UTF8 encoded data
    NSData *messageData = [message dataUsingEncoding:NSUTF8StringEncoding];
    // Send text message to all connected peers
    NSError *error;
    [self.session sendData:messageData toPeers:self.session.connectedPeers withMode:MCSessionSendDataReliable error:&error];
    // Check the error return to know if there was an issue sending data to peers.  Note any peers in the 'toPeers' array argument are not connected this will fail.
    if (error) {
        NSLog(@"Error sending message to peers [%@]", error);
        return nil;
    }
    else {
        // Create a new send transcript
        return [[Transcript alloc] initWithPeerID:_session.myPeerID message:message direction:TRANSCRIPT_DIRECTION_SEND];

    }
}

// Method for sending image resources to all connected remote peers.  Returns an progress type transcript for monitoring tranfer
- (Transcript *)sendImage:(NSURL *)imageUrl
{
    NSProgress *progress;
    // Loop on connected peers and send the image to each
    for (MCPeerID *peerID in _session.connectedPeers) {
        //imageUrl = [NSURL URLWithString:@"http://images.apple.com/home/images/promo_logic_pro.jpg"];
        // Send the resource to the remote peer.  The completion handler block will be called at the end of sending or if any errors occur
        progress = [self.session sendResourceAtURL:imageUrl withName:[imageUrl lastPathComponent] toPeer:peerID withCompletionHandler:^(NSError *error) {
            // Implement this block to know when the sending resource transfer completes and if there is an error.
            if (error) {
                NSLog(@"Send resource to peer [%@] completed with Error [%@]", peerID.displayName, error);
            }
            else {
                // Create an image transcript for this received image resource
                Transcript *transcript = [[Transcript alloc] initWithPeerID:_session.myPeerID imageUrl:imageUrl direction:TRANSCRIPT_DIRECTION_SEND];
                
                if (self.delegate != nil) {
                    [self.delegate updateTranscript:transcript];
                }
            }
        }];
    }
    // Create an outgoing progress transcript.  For simplicity we will monitor a single NSProgress.  However users can measure each NSProgress returned individually as needed
    Transcript *transcript = [[Transcript alloc] initWithPeerID:_session.myPeerID imageName:[imageUrl lastPathComponent] progress:progress direction:TRANSCRIPT_DIRECTION_SEND];
    
    return transcript;
}

#pragma mark - MCSessionDelegate methods

// Override this method to handle changes to peer session state
- (void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state
{
    NSLog(@"Peer [%@] changed state to %@", peerID.displayName, [self stringForPeerConnectionState:state]);

    NSString *adminMessage = [NSString stringWithFormat:@"'%@' is %@", peerID.displayName, [self stringForPeerConnectionState:state]];
    // Create an local transcript
    Transcript *transcript = [[Transcript alloc] initWithPeerID:peerID message:adminMessage direction:TRANSCRIPT_DIRECTION_LOCAL];
    
    if (state == MCSessionStateConnected) {
        [self addNewConnectedPeer:peerID.displayName];
        
        if (![[DataSource sharedInstance].activeConversations containsObject:self]) {
            [[DataSource sharedInstance] insertObject:self inActiveConversationsAtIndex:0];
        }
        
        if (self.delegate != nil) {
            [self.delegate session:self peerDidConnect:peerID];
        }
    }
    
    // Notify the delegate that we have received a new chunk of data from a peer
    if (self.delegate != nil) {
        [self.delegate receivedTranscript:transcript];
    } else {
        //Local notification when not in chat view. Phone vibrates (see App Delegate)
        UILocalNotification *localNotif = [[UILocalNotification alloc] init];
        
        localNotif.timeZone = [NSTimeZone defaultTimeZone];
        
        localNotif.alertTitle = [NSString stringWithFormat:@"%@", transcript.peerID.displayName];
        localNotif.alertAction = NSLocalizedString(@"View", nil);
        localNotif.alertBody = [NSString stringWithFormat:@"%@", transcript.message];
        
        localNotif.soundName = UILocalNotificationDefaultSoundName;
        
        [[UIApplication sharedApplication] presentLocalNotificationNow:localNotif];
    }

}

// MCSession Delegate callback when receiving data from a peer in a given session
- (void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID
{
    // Decode the incoming data to a UTF8 encoded string
    NSString *receivedMessage = [[NSString alloc] initWithData:data encoding: NSUTF8StringEncoding];
    // Create an received transcript
    Transcript *transcript = [[Transcript alloc] initWithPeerID:peerID message:receivedMessage direction:TRANSCRIPT_DIRECTION_RECEIVE];
    
    // Notify the delegate that we have received a new chunk of data from a peer
    if (self.delegate != nil) {
        [self.delegate receivedTranscript:transcript];
    } else {
        //The delegate is not available and we need to add this transcript to our datasource.
        [self.sessionTranscripts addObject:transcript];

        //Local notification when not in chat view. Phone vibrates (see App Delegate)
        UILocalNotification *localNotif = [[UILocalNotification alloc] init];
        
        localNotif.timeZone = [NSTimeZone defaultTimeZone];
        
        localNotif.alertTitle = [NSString stringWithFormat:@"%@", transcript.peerID.displayName];
        localNotif.alertAction = NSLocalizedString(@"View", nil);
        localNotif.alertBody = [NSString stringWithFormat:@"%@", transcript.message];
        
        localNotif.soundName = UILocalNotificationDefaultSoundName;
        
        [[UIApplication sharedApplication] presentLocalNotificationNow:localNotif];

    }
    
    
}

// MCSession delegate callback when we start to receive a resource from a peer in a given session
- (void)session:(MCSession *)session didStartReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID withProgress:(NSProgress *)progress
{
    NSLog(@"Start receiving resource [%@] from peer %@ with progress [%@]", resourceName, peerID.displayName, progress);
    // Create a resource progress transcript
    Transcript *transcript = [[Transcript alloc] initWithPeerID:peerID imageName:resourceName progress:progress direction:TRANSCRIPT_DIRECTION_RECEIVE];
    // Notify the UI delegate
    if (self.delegate != nil) {
        [self.delegate receivedTranscript:transcript];
    }
}

// MCSession delegate callback when a incoming resource transfer ends (possibly with error)
- (void)session:(MCSession *)session didFinishReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID atURL:(NSURL *)localURL withError:(NSError *)error
{
    // If error is not nil something went wrong
    if (error)
    {
        NSLog(@"Error [%@] receiving resource from peer %@ ", [error localizedDescription], peerID.displayName);
    }
    else
    {
        // No error so this is a completed transfer.  The resources is located in a temporary location and should be copied to a permanent locatation immediately.
        // Write to documents directory
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *copyPath = [NSString stringWithFormat:@"%@/%@", [paths objectAtIndex:0], resourceName];
        if (![[NSFileManager defaultManager] copyItemAtPath:[localURL path] toPath:copyPath error:nil])
        {
            NSLog(@"Error copying resource to documents directory");
        }
        else {
            // Get a URL for the path we just copied the resource to
            NSURL *imageUrl = [NSURL fileURLWithPath:copyPath];
            // Create an image transcript for this received image resource
            Transcript *transcript = [[Transcript alloc] initWithPeerID:peerID imageUrl:imageUrl direction:TRANSCRIPT_DIRECTION_RECEIVE];
            
            if (self.delegate != nil) {
                [self.delegate updateTranscript:transcript];
            }
        }
    }
}

// Streaming API not utilized in this sample code
- (void)session:(MCSession *)session didReceiveStream:(NSInputStream *)stream withName:(NSString *)streamName fromPeer:(MCPeerID *)peerID
{
    NSLog(@"Received data over stream with name %@ from peer %@", streamName, peerID.displayName);
}

#pragma mark - NSCoding

- (instancetype) initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    
    if (self) {
        self.sessionTranscripts = [aDecoder decodeObjectForKey:NSStringFromSelector(@selector(sessionTranscripts))];
        self.displayName = [aDecoder decodeObjectForKey:NSStringFromSelector(@selector(displayName))];
        self.peersConnectedToSession = [aDecoder decodeObjectForKey:NSStringFromSelector(@selector(peersConnectedToSession))];
        
        //reinitialize session
        self.session = [[MCSession alloc] initWithPeer:[DataSource sharedInstance].userID securityIdentity:nil encryptionPreference:MCEncryptionRequired];
        self.session.delegate = self;
        
        
    }
    
    return self;
}

- (void) encodeWithCoder:(NSCoder *)aCoder {
    
    //session not saved. Reinitialize when initializing from coder.
    [aCoder encodeObject:self.sessionTranscripts forKey:NSStringFromSelector(@selector(sessionTranscripts))];
    [aCoder encodeObject:self.displayName forKey:NSStringFromSelector(@selector(displayName))];
    [aCoder encodeObject:self.peersConnectedToSession forKey:NSStringFromSelector(@selector(peersConnectedToSession))];
    
}

@end
