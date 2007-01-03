//
//  JKServiceManager.m
//  Rawr-endezvous
//
//  Created by Jeremy Knope on 9/17/04.
//  Copyright 2004 Jeremy Knope. All rights reserved.
//

#import "JKServiceManager.h"
#import "JKPreferencesController.h"
#import <Growl/Growl.h>

@implementation JKServiceManager
/*
+ (JKServiceManager *) serviceManagerForProtocols:(NSArray *)protos {
	return [[[JKServiceManager alloc] initWithProtocols:protos] autorelease];
}
*/
+ (JKServiceManager *) serviceManagerForPreferences:(JKPreferencesController *)newPrefs {
	return [[[JKServiceManager alloc] initWithPreferences:newPrefs] autorelease];
}

- (id) initWithPreferences:(JKPreferencesController *)newPrefs {
	if ((self = [super init])) {
		prefs = [newPrefs retain];
		serviceBrowserLinks = [[NSMutableDictionary alloc] init];
		foundServices = [[NSMutableDictionary alloc] init];
		[self setProtocols:[prefs getServices]];
	}
	return self;
}
/*
- (id)initWithProtocols:(NSArray *)protos {
	[super init];
	serviceBrowserLinks = [[NSMutableDictionary alloc] init];
	foundServices = [[NSMutableDictionary alloc] init];
	[self setProtocols:protos];

	return self;
}
*/
- (id) init {
	if ((self = [super init])) {
		serviceBrowserLinks = [[NSMutableDictionary alloc] init];
		foundServices = [[NSMutableDictionary alloc] init];
	}
	return self;
}

- (void) dealloc {
	[protocolNames       release];
	[serviceBrowserLinks release];
	[foundServices       release];
	[super dealloc];
}

- (void) setProtocols:(NSArray *)protos {
	if (protos != protocolNames) {
		[protocolNames release];
		protocolNames = [protos retain];
	}
	[self refreshServices];
}

- (NSDictionary *) getProtocolNames {
	NSMutableDictionary *temp;
	id aProtocol;
	NSEnumerator *en = [[prefs getServices] objectEnumerator];
	temp = [NSMutableDictionary dictionaryWithCapacity:1U];
	while ((aProtocol = [en nextObject]))
		[temp setObject:aProtocol forKey:[aProtocol objectForKey:@"service"]];
	return temp;
}

- (void) refreshServices {
	NSDictionary *aProtocol;
	//id aBrowser;
	NSNetServiceBrowser *newBrowser;

	//[browsers makeObjectsPerformSelector:@selector(stop)];
	//[browsers removeAllObjects];
	//NSEnumerator * enumerator = [protocolNames objectEnumerator];
	NSEnumerator *enumerator = [[prefs getServices] objectEnumerator];

	while ((aProtocol = [enumerator nextObject])) {
		if (![serviceBrowserLinks objectForKey:[aProtocol objectForKey:@"service"]]) {
			newBrowser = [[NSNetServiceBrowser alloc] init];
			[newBrowser setDelegate:self];
			[newBrowser searchForServicesOfType:[aProtocol objectForKey:@"service"] inDomain:@""];
			[serviceBrowserLinks setObject:newBrowser forKey:[aProtocol objectForKey:@"service"]];
			[browsers addObject:newBrowser];
		} // else already have a browser for that service...
	}
	// find removed services
	NSEnumerator *en = [serviceBrowserLinks keyEnumerator];
	id aKey;
	BOOL foundKey;

	while ((aKey = [en nextObject])) { // for every key, a service type...
		foundKey = NO;
		// every damn protcol name...
		enumerator = [[prefs getServices] objectEnumerator];
		while ((aProtocol = [enumerator nextObject])) {
			if ([aKey isEqualToString:[aProtocol objectForKey:@"service"]]) {
				foundKey = YES;
				break;
			}
		}
		if (!foundKey) {
			[(NSNetServiceBrowser *)[serviceBrowserLinks objectForKey:aKey] stop];
			[serviceBrowserLinks removeObjectForKey:aKey];
			// we need to loop thru and send out removals for each service of said type
			NSEnumerator *serviceEnum = [[foundServices objectForKey:aKey] objectEnumerator];
			NSNetService *service;
			NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
			while ((service = [serviceEnum nextObject]))
				[nc postNotificationName:@"RawrEndezvousRemoveService" object:service];
			[foundServices removeObjectForKey:aKey];
		}
	}
}

// This object is the delegate of its NSNetServiceBrowser object. We're only interested in services-related methods, so that's what we'll call.
- (void) netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didFindService:(NSNetService *)aNetService moreComing:(BOOL)moreComing {
#pragma unused(aNetServiceBrowser, moreComing)
	if (DEBUG)
		NSLog(@"JKServiceManager:: Found service: %@ of type: %@",[aNetService name],[aNetService type]);

	NSString *type = [aNetService type];
	NSMutableArray *serviceEntry = [foundServices objectForKey:type];
	if (!serviceEntry) {
		serviceEntry = [[NSMutableArray alloc] initWithCapacity:1U];
		[foundServices setObject:serviceEntry forKey:type];
		[serviceEntry release];
	}

	[serviceEntry addObject:aNetService];

	[[NSNotificationCenter defaultCenter] postNotificationName:@"RawrEndezvousNewService" object:aNetService];
}


- (void) netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didRemoveService:(NSNetService *)aNetService moreComing:(BOOL)moreComing {
#pragma unused(aNetServiceBrowser, moreComing)
	// This case is slightly more complicated. We need to find the object in the list and remove it.
	//NSLog(@"JKServiceManager:: Removing service: %@",[aNetService name]);
	NSMutableArray *serviceEntry = [foundServices objectForKey:[aNetService type]];
	if (serviceEntry)
		[serviceEntry removeObject:aNetService];

	[[NSNotificationCenter defaultCenter] postNotificationName:@"RawrEndezvousRemoveService" object:aNetService];
	/*
	NSEnumerator * enumerator = [services objectEnumerator];
	NSNetService * currentNetService;

	while ((currentNetService = [enumerator nextObject])) {
		if ([currentNetService isEqual:aNetService]) {
			[services removeObject:currentNetService];
			break;
		}
	}
	// ** notify app of gone service

	//[theMain removeService:aNetService];

	if (serviceBeingResolved && [serviceBeingResolved isEqual:aNetService]) {
		[serviceBeingResolved stop];
		[serviceBeingResolved release];
		serviceBeingResolved = nil;
	}
	*/
}

@end
