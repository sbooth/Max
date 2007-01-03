//
//  JKServiceManager.h
//  Rawr-endezvous
//
//  Created by Jeremy Knope on 9/17/04.
//  Copyright 2004 Jeremy Knope. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class JKPreferencesController;

@interface JKServiceManager : NSObject {
	NSMutableArray			*browsers; // array of browsers for services
	NSArray		            *protocolNames;
    NSMutableDictionary		*foundServices; // for holding menu->service relations i hope
	NSMutableDictionary		*serviceBrowserLinks;	// holds service type -> browser object links to find them easier
    JKPreferencesController *prefs;
}
//+ (JKServiceManager *) serviceManagerForProtocols:(NSArray *)protos;
+ (JKServiceManager *) serviceManagerForPreferences:(JKPreferencesController *)newPrefs;
//- (id) initWithProtocols:(NSArray *)protos;
- (id) initWithPreferences:(JKPreferencesController *)newPrefs;

//- (void) searchForServiceProtocol:(NSString *)proto;
//- (void) getURLForServiceAtIndex:(int)anIndex;
- (void) setProtocols:(NSArray *)protos;
- (NSDictionary *) getProtocolNames;
- (void) refreshServices;
@end
