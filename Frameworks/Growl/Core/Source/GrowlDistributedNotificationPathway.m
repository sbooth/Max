//
//  GrowlDistributedNotificationPathway.m
//  Growl
//
//  Created by Mac-arena the Bored Zo on 2005-03-12.
//  Copyright 2005 The Growl Project. All rights reserved.
//

#import "GrowlDistributedNotificationPathway.h"
#import "GrowlDefines.h"

@implementation GrowlDistributedNotificationPathway

- (id) init {
	if ((self = [super init])) {
		NSDistributedNotificationCenter *dnc = [NSDistributedNotificationCenter defaultCenter];
		[dnc addObserver:self
				selector:@selector(gotGrowlRegistration:)
					name:GROWL_APP_REGISTRATION
				  object:nil];
		[dnc addObserver:self
				selector:@selector(gotGrowlNotification:)
					name:GROWL_NOTIFICATION
				  object:nil];
	}
	return self;
}
- (void) dealloc {
	[[NSDistributedNotificationCenter defaultCenter] removeObserver:self
															   name:nil
															 object:nil];
	[super dealloc];
}

#pragma mark -

- (void) gotGrowlRegistration:(NSNotification *)notification {
	[self registerApplicationWithDictionary:[notification userInfo]];
}

- (void) gotGrowlNotification:(NSNotification *)notification {
	[self postNotificationWithDictionary:[notification userInfo]];
}

@end
