//
//  GSWebBookmark.m
//  GrowlSafari
//
//  Created by Johan Persson on 2005.14.05.
//  Copyright 2005 Johan Persson. All rights reserved.
//

#import "GSWebBookmark.h"
#import "GrowlSafari.h"

@implementation GSWebBookmark

- (void) setUnreadRSSCount:(int)newUnreadCount  {
	int oldRSSCount = [self unreadRSSCount];
	[super setUnreadRSSCount:newUnreadCount];
	
	if ([self isRSSBookmark] && [[self URLString] hasPrefix:@"feed:"] && oldRSSCount < newUnreadCount) {
		[GrowlSafari notifyRSSUpdate:self newEntries:newUnreadCount - oldRSSCount];
	}
}

@end
