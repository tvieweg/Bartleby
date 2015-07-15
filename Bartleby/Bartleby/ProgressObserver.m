//
//  ProgressObserver.m
//  Bartleby
//
//  Created by Trevor Vieweg on 7/11/15.
//  Copyright (c) 2015 Trevor Vieweg. All rights reserved.
//

#import "ProgressObserver.h"

// KVO path strings for observing changes to properties of NSProgress
static NSString * const kProgressCancelledKeyPath          = @"cancelled";
static NSString * const kProgressCompletedUnitCountKeyPath = @"completedUnitCount";

// This class implement KVO on the NSProgress class so that we can track the progress of the incoming or outgoing resource transfer
@implementation ProgressObserver

- (id)initWithName:(NSString *)name progress:(NSProgress *)progress
{
    if ((self = [super init])) {
        _name = [name copy];
        _progress = progress;
        // Add KVO observer for the cancelled and completed unit count properties of NSProgress
        [_progress addObserver:self forKeyPath:kProgressCancelledKeyPath options:NSKeyValueObservingOptionNew context:NULL];
        [_progress addObserver:self forKeyPath:kProgressCompletedUnitCountKeyPath options:NSKeyValueObservingOptionNew context:NULL];
    }
    return self;
}

- (void)dealloc
{
    // stop KVO
    [_progress removeObserver:self forKeyPath:kProgressCancelledKeyPath];
    [_progress removeObserver:self forKeyPath:kProgressCompletedUnitCountKeyPath];
    _progress = nil;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    NSProgress *progress = object;

    // Check which KVO key change has fired
    if ([keyPath isEqualToString:kProgressCancelledKeyPath]) {
        // Notify the delegate that the progress was cancelled
        [self.delegate observerDidCancel:self];
    }
    else if ([keyPath isEqualToString:kProgressCompletedUnitCountKeyPath]) {
        // Notify the delegate of our progress change
        [self.delegate observerDidChange:self];
        if (progress.completedUnitCount == progress.totalUnitCount) {
            // Progress completed, notify delegate
            [self.delegate observerDidComplete:self];
        }
    }
}

@end
