//
//  GrowlApplicationBridgePathway.m
//  Growl
//
//  Created by Karl Adam on 3/10/05.
//  Copyright 2005 The Growl Project. All rights reserved.
//

#import "GrowlApplicationBridgePathway.h"

static GrowlApplicationBridgePathway *_theOneTrueGrowlApplicationBridgePathway;

@implementation GrowlApplicationBridgePathway

+ (GrowlApplicationBridgePathway *) standardPathway {
	if (!_theOneTrueGrowlApplicationBridgePathway) {
		_theOneTrueGrowlApplicationBridgePathway = [[GrowlApplicationBridgePathway alloc] init];
	}

	return _theOneTrueGrowlApplicationBridgePathway;
}

- (id) init {
	if (_theOneTrueGrowlApplicationBridgePathway) {
		[self release];
		return _theOneTrueGrowlApplicationBridgePathway;
	}

	if ((self = [super init])) {
		/*This uses the default connection since it's assumed that we need to
		 *	talk to apps, hence making this connection more important than the rest
		 */
		NSConnection *aConnection = [NSConnection defaultConnection];
		[aConnection setRootObject:self];

		if (![aConnection registerName:@"GrowlApplicationBridgePathway"]) {
			/*Considering how important this is, if we are unable to gain this
			 *	we can assume that another instance of Growl is running and
			 *	terminate
			 */
			NSLog( @"%@", @"It appears that at least one other instance of Growl is running. This one will quit." );
			[self release];
			[NSApp terminate:self];
		}

		_theOneTrueGrowlApplicationBridgePathway = self;
	}

	return self;
}

@end
