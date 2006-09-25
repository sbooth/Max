//
//  GrowlNotificationCenter.m
//  Growl
//
//  Created by Ingmar Stein on 27.04.05.
//  Copyright 2005 The Growl Project. All rights reserved.
//

#import "GrowlNotificationCenter.h"

@implementation GrowlNotificationCenter
- (id) init {
	if ((self = [super init])) {
		observers = [[NSMutableArray alloc] init];
	}
	return self;
}

- (void) addObserver:(id<GrowlNotificationObserver>)observer {
	[observers addObject:observer];
}

- (void) removeObserver:(id<GrowlNotificationObserver>)observer {
	[observers removeObject:observer];
}

- (void) notifyObservers:(NSDictionary *)notificationDict {
	NSEnumerator *e = [observers objectEnumerator];
	id<GrowlNotificationObserver> observer;
	while ((observer = [e nextObject])) {
		@try {
			[observer notifyWithDictionary:notificationDict];
		} @catch(NSException *ex) {
			NSLog(@"Exception while notifying observer: %@", ex);
		}
	}
}

- (void) dealloc {
	[observers release];
	[super dealloc];
}
@end
