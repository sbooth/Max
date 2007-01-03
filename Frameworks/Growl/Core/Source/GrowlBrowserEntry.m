//
//  GrowlBrowserEntry.m
//  Growl
//
//  Created by Ingmar Stein on 16.04.05.
//  Copyright 2005 The Growl Project. All rights reserved.
//

#import "GrowlBrowserEntry.h"
#import "GrowlPref.h"

@implementation GrowlBrowserEntry

- (id) initWithDictionary:(NSDictionary *)dict {
	if ((self = [super init])) {
		properties = [dict mutableCopy];
	}

	return self;
}

- (id) initWithComputerName:(NSString *)name netService:(NSNetService *)service {
	if ((self = [super init])) {
		NSNumber *useValue = [[NSNumber alloc] initWithBool:NO];
		properties = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
			name,     @"computer",
			service,  @"netservice",
			useValue, @"use",
			nil];
		[useValue release];
	}

	return self;
}

- (BOOL) use {
	return [[properties objectForKey:@"use"] boolValue];
}

- (void) setUse:(BOOL)flag {
	NSNumber *value = [[NSNumber alloc] initWithBool:flag];
	[properties setObject:value forKey:@"use"];
	[value release];
	[owner writeForwardDestinations];
}

- (NSString *) computerName {
	return [properties objectForKey:@"computer"];
}

- (void) setComputerName:(NSString *)name {
	[properties setObject:name forKey:@"computer"];
	[owner writeForwardDestinations];
}

- (NSNetService *) netService {
	return [properties objectForKey:@"netservice"];
}

- (void) setNetService:(NSNetService *)service {
	[properties setObject:service forKey:@"netservice"];
}

- (NSString *) password {
	return [properties objectForKey:@"password"];
}

- (void) setPassword:(NSString *)password {
	if (password) {
		[properties setObject:password forKey:@"password"];
	} else {
		[properties removeObjectForKey:@"password"];
	}
	[owner writeForwardDestinations];
}

- (void) setAddress:(NSData *)address {
	[properties setObject:address forKey:@"address"];
	[properties removeObjectForKey:@"netservice"];
	[owner writeForwardDestinations];
}

- (void) setOwner:(GrowlPref *)pref {
	owner = pref;
}

- (NSDictionary *) properties {
	return properties;
}

- (void) dealloc {
	[properties release];
	[super dealloc];
}

@end
