//
//  PeerBrowserCell.m
//  Bartleby
//
//  Created by Trevor Vieweg on 7/18/15.
//  Copyright (c) 2015 Trevor Vieweg. All rights reserved.
//

#import "PeerBrowserCell.h"

@implementation PeerBrowserCell

- (void)awakeFromNib {
    // Initialization code
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (void)setFrame:(CGRect)frame {
    
    CGFloat horizontalInset = 10;
    CGFloat verticalInset = 10;
    
    frame.origin.x += horizontalInset;
    frame.size.width -= 2 * horizontalInset;
    
    frame.origin.y += verticalInset;
    frame.size.height -= 2 *verticalInset;
    
    [super setFrame:frame];
        
    self.layer.cornerRadius = 5;
    self.layer.masksToBounds = YES;
    
}

@end
