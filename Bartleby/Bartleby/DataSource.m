//
//  DataSource.m
//  Bartleby
//
//  Created by Trevor Vieweg on 7/11/15.
//  Copyright (c) 2015 Trevor Vieweg. All rights reserved.
//

#import "DataSource.h"
#import "SessionContainer.h"

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
        self.serviceType = @"bartleby-chat";
        self.userName = [[UIDevice currentDevice] name];
        self.activeConversations = [NSMutableArray new];
        //[self addRandomData];
        
    }
    
    return self;
}

- (void) addRandomData {
    
    for (int i = 1; i < 10; i++) {
        
        SessionContainer *newSession = [self randomSession];
        
        [self.activeConversations addObject:newSession];
        
    }
    
}

- (SessionContainer *) randomSession {
    
    NSString *userName = [self randomStringOfLength:(arc4random_uniform(6) + 4)];

    SessionContainer *randomsesh = [[SessionContainer alloc] initWithDisplayName:userName serviceType:self.serviceType];
    
    return randomsesh;
}

- (SessionContainer *) createNewSessionWithName:(NSString *)name {
    
    SessionContainer *newSession = [[SessionContainer alloc] initWithDisplayName:name serviceType:self.serviceType];
    [self.activeConversations addObject:newSession];
    return newSession;
}


- (NSString *) randomStringOfLength:(NSUInteger) len {
    NSString *alphabet = @"abcdefghijklmnopqrstuvwxyz";
    
    NSMutableString *s = [NSMutableString string];
    for (NSUInteger i = 0; i < len; i++) {
        u_int32_t r = arc4random_uniform((u_int32_t)[alphabet length]);
        unichar c = [alphabet characterAtIndex:r];
        [s appendFormat:@"%C", c];
    }
    return [NSString stringWithString:s];
}


@end
