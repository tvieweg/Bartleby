//
//  User.m
//  Bartleby
//
//  Created by Trevor Vieweg on 7/11/15.
//  Copyright (c) 2015 Trevor Vieweg. All rights reserved.
//

#import "User.h"

@implementation User

- (instancetype) initWithUserName:(NSString *)userName {
    self = [super init];
    
    if (self) {
        _userName = userName;
    }
    
    return self;
}

@end
