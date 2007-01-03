//
//  VolumeNotifier.m
//  HardwareGrowler
//
//  Created by Diggory Laycock on 10/02/2005.
//  Copyright 2005 The Growl Project. All rights reserved.
//

#import "VolumeNotifier.h"

@implementation VolumeNotifier

- (id) initWithDelegate:(id)object {
	if ((self = [super init])) {
		delegate = object;

		NSNotificationCenter *nc = [[NSWorkspace sharedWorkspace] notificationCenter];

		[nc addObserver:self
			   selector:@selector(volumeDidMount:)
				   name:NSWorkspaceDidMountNotification
				 object:nil];

		[nc addObserver:self
			   selector:@selector(volumeDidUnmount:)
				   name:NSWorkspaceDidUnmountNotification
				 object:nil];
	}

	return self;
}

- (void) dealloc {
	[[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self
																  name:nil
																object:nil];

	[super dealloc];
}

- (void) volumeDidMount:(NSNotification *)note {
//	NSLog(@"mount.");

	[delegate volumeDidMount:[[note userInfo] objectForKey:@"NSDevicePath"]];
}

- (void) volumeDidUnmount:(NSNotification *)note {
//	NSLog(@"unmount.");

	[delegate volumeDidUnmount:[[note userInfo] objectForKey:@"NSDevicePath"]];
}

@end
