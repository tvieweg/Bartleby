//
//  Transcript.m
//  Bartleby
//
//  Created by Trevor Vieweg on 7/11/15.
//  Copyright (c) 2015 Trevor Vieweg. All rights reserved.
//

@import MultipeerConnectivity;

#import "Transcript.h"

@implementation Transcript

// Designated initializer with all properties
- (id)initWithPeerID:(MCPeerID *)peerID message:(NSString *)message imageName:(NSString *)imageName imageUrl:(NSURL *)imageUrl progress:(NSProgress *)progress direction:(TranscriptDirection)direction
{
    if (self = [super init]) {
        _peerID = peerID;
        _message = message;
        _direction = direction;
        _imageUrl = imageUrl;
        _progress = progress;
        _imageName = imageName;
    }
    return self;
}

// Initializer used for sent/received text messages
- (id)initWithPeerID:(MCPeerID *)peerID message:(NSString *)message direction:(TranscriptDirection)direction
{
    return [self initWithPeerID:peerID message:message imageName:nil imageUrl:nil progress:nil direction:direction];
}

// Initializer used for sent/received images resources
- (id)initWithPeerID:(MCPeerID *)peerID imageUrl:(NSURL *)imageUrl direction:(TranscriptDirection)direction
{
    return [self initWithPeerID:peerID message:nil imageName:[imageUrl lastPathComponent] imageUrl:imageUrl progress:nil direction:direction];
}

- (id)initWithPeerID:(MCPeerID *)peerID imageName:(NSString *)imageName progress:(NSProgress *)progress direction:(TranscriptDirection)direction
{
    return [self initWithPeerID:peerID message:nil imageName:imageName imageUrl:nil progress:progress direction:direction];
}

#pragma mark - NSCoding

- (instancetype) initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    
    if (self) {
        _peerID = [aDecoder decodeObjectForKey:NSStringFromSelector(@selector(peerID))];
        _direction = [aDecoder decodeIntForKey:NSStringFromSelector(@selector(direction))];
        _message = [aDecoder decodeObjectForKey:NSStringFromSelector(@selector(message))];
        _imageName = [aDecoder decodeObjectForKey:NSStringFromSelector(@selector(imageName))];
        _imageUrl = [aDecoder decodeObjectForKey:NSStringFromSelector(@selector(imageName))];
        
    }
    
    return self;
}

- (void) encodeWithCoder:(NSCoder *)aCoder {
    
    //session not saved. Reinitialize when initializing from coder.
    [aCoder encodeInt:self.direction forKey:NSStringFromSelector(@selector(direction))];
    [aCoder encodeObject:self.peerID forKey:NSStringFromSelector(@selector(peerID))];
    [aCoder encodeObject:self.message forKey:NSStringFromSelector(@selector(message))];
    [aCoder encodeObject:self.imageName forKey:NSStringFromSelector(@selector(imageName))];
    [aCoder encodeObject:self.imageUrl forKey:NSStringFromSelector(@selector(imageUrl))];
    
}


@end
