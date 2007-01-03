//
//  JKServiceBrowserDelegate.m
//  Rawr-endezvous
//
//  Created by Jeremy Knope on 9/25/04.
//  Copyright 2004 Jeremy Knope. All rights reserved.
//

#import "JKServiceBrowserDelegate.h"
#include "CFGrowlAdditions.h"
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>

@interface NSNetService(PantherCompatibility)
+ (NSDictionary *)dictionaryFromTXTRecordData:(NSData *)txtData;
- (NSData *)TXTRecordData;
- (void) resolveWithTimeout:(NSTimeInterval)timeout;
@end

@implementation JKServiceBrowserDelegate
- (void) awakeFromNib {
	services = [[NSMutableArray alloc] initWithCapacity:1U];
	serviceTypes = [[NSMutableDictionary alloc] initWithCapacity:1U];
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self selector:@selector(addService:) name:@"RawrEndezvousNewService" object:nil];
	[nc addObserver:self selector:@selector(removeService:) name:@"RawrEndezvousRemoveService" object:nil];
}

- (void) dealloc {
	[serviceTypes release];
	[services     release];
	[super dealloc];
}

- (void) addService:(NSNotification *)note {
	//NSLog(@"Adding service to browser...");
	NSNetService *service = [note object];
	NSString *type = [service type];
	NSDictionary *entry = [serviceTypes objectForKey:type];

	if (entry) {
		// Add actual service to service type entry
		//NSLog(@"Adding service to type's array");
		[[entry objectForKey:@"contents"] addObject:service];
	} else {
		//NSLog(@"Creating entry");
		NSMutableArray *contents = [[NSMutableArray alloc] initWithObjects:service, nil];
		entry = [[NSDictionary alloc] initWithObjectsAndKeys:
			type,     @"name",
			contents, @"contents",
			nil];
		[contents release];
		[services addObject:entry];
		[serviceTypes setObject:entry forKey:type];
		[serviceBrowser reloadColumn:0];
		[entry release];
	}

}

- (void) removeService:(NSNotification *)note {
	NSNetService *service = [note object];
	NSMutableArray *contents = [[serviceTypes objectForKey:[service type]] objectForKey:@"contents"];
	[contents removeObject:service];
	if (![contents count]) {
		//NSLog(@"No more services of this type: %@",[service type]);
		[services removeObject:[serviceTypes objectForKey:[service type]]];
		[serviceTypes removeObjectForKey:[service type]];
		[serviceBrowser reloadColumn:0];
	}
}

- (int) browser:(NSBrowser *)sender numberOfRowsInColumn:(int)column {
	//NSLog(@"Counting for browser");
	switch (column) {
		case 0:
			return [services count];
		case 1:
			return [[[services objectAtIndex:[sender selectedRowInColumn:0]] objectForKey:@"contents"] count];
		case 2:
			return [sender selectedRowInColumn:1] >= 0 ? 3 : 0;
		default:
			return 0;
	}
}

- (void) browser:(NSBrowser *)sender willDisplayCell:(id)cell atRow:(int)row column:(int)column {
	//NSLog(@"Display for browser");
	NSNetService *serv;
	NSString *name = nil;
	switch (column) {
		case 0:
			name = [[services objectAtIndex:row] objectForKey:@"name"];
			break;
		case 1:
			if (row >= 0) {
				serv = [[[services objectAtIndex:[sender selectedRowInColumn:0]] objectForKey:@"contents"] objectAtIndex:row];
				name = [serv name];
			} else
				name = @"Error";
			//[cell setLeaf:YES];
			break;
		case 2:
			serv = [[[services objectAtIndex:[sender selectedRowInColumn:0]] objectForKey:@"contents"] objectAtIndex:[sender selectedRowInColumn:1]];
			if (![[serv addresses] count]) {
				[serv setDelegate:self];
				if ([serv respondsToSelector:@selector(resolveWithTimeout:)])
					[serv resolveWithTimeout:5.0];
				else
					[serv resolve];
			}
			switch (row) {
				case 0:
					//name = @"Name here";
					name = [serv name];
					break;
				case 1:
					name = [JKServiceBrowserDelegate stringForService:serv];
					if (!name)
						name = @"No addresses yet";
					break;
				case 2:
					if ([serv respondsToSelector:@selector(TXTRecordData)]) {
						NSData *txtData = [serv TXTRecordData];
						if (txtData)
							name = [[NSNetService dictionaryFromTXTRecordData:txtData] description];
						else
							name = @"";
					} else
						name = [serv protocolSpecificInformation];
					if (!name)
						name = @"";
					break;
				default:
					name = @"Invalid row";
					break;
			}
			[cell setLeaf:YES];
			break;
	}

	[cell setStringValue:name];
}

+ (NSString *) stringForService:(NSNetService *)service {
	NSEnumerator *addrEnum = [[service addresses] objectEnumerator];
	NSData *address;
	while ((address = [addrEnum nextObject])) {
		struct sockaddr *socketAddress;
		socketAddress = (struct sockaddr *)[address bytes];
		
		if (socketAddress->sa_len == sizeof(struct sockaddr_in) || socketAddress->sa_len == sizeof(struct sockaddr_in6))
			return [(NSString *) createStringWithAddressData(address) autorelease];
	}

	return nil;
}

- (void) netServiceDidResolveAddress:(NSNetService *)sender {
	//NSLog(@"Did resolve!");
	NSData *address;
	// Iterate through addresses until we find an IPv4 or IPv6 address
	NSEnumerator *addrEnum = [[sender addresses] objectEnumerator];
	while ((address = [addrEnum nextObject])) {
		struct sockaddr *socketAddress;
		socketAddress = (struct sockaddr *)[address bytes];

		if (socketAddress->sa_len == sizeof(struct sockaddr_in) || socketAddress->sa_len == sizeof(struct sockaddr_in6)) {
			// Cancel the resolve now
			[sender stop];
			[serviceBrowser reloadColumn:2];
			break;
		}
	}
}
@end
