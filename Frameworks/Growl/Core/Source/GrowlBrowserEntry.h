//
//  GrowlBrowserEntry.h
//  Growl
//
//  Created by Ingmar Stein on 16.04.05.
//  Copyright 2005 The Growl Project. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class GrowlPref;

@interface GrowlBrowserEntry : NSObject {
	NSMutableDictionary *properties;
	GrowlPref			*owner;
}
- (id) initWithDictionary:(NSDictionary *)dict;
- (id) initWithComputerName:(NSString *)name netService:(NSNetService *)service;

- (BOOL) use;
- (void) setUse:(BOOL)flag;

- (NSString *) computerName;
- (void) setComputerName:(NSString *)name;

- (NSNetService *) netService;
- (void) setNetService:(NSNetService *)service;

- (NSString *) password;
- (void) setPassword:(NSString *)password;

- (NSDictionary *) properties;

- (void) setAddress:(NSData *)address;
- (void) setOwner:(GrowlPref *)pref;

@end
