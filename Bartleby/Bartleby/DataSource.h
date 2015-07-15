//
//  DataSource.h
//  Bartleby
//
//  Created by Trevor Vieweg on 7/11/15.
//  Copyright (c) 2015 Trevor Vieweg. All rights reserved.
//


@class SessionContainer;

#import <Foundation/Foundation.h>

@interface DataSource : NSObject

@property (nonatomic, strong) NSMutableArray *activeConversations;

@property (nonatomic, strong) NSMutableArray *archivedConversations;

@property (nonatomic, strong) NSString *serviceType;

@property (nonatomic, strong) NSString *userName;

@property (nonatomic, strong) SessionContainer *currentConversation; 

- (SessionContainer *) createNewSessionWithName:(NSString *)name; 

+ (instancetype) sharedInstance;

@end
