//
//  NetworkNotifier.h
//  HardwareGrowler
//
//  Created by Ingmar Stein on 18.02.05.
//  Copyright 2005 The Growl Project. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class SCDynamicStore;

@interface NetworkNotifier : NSObject {
	id                  delegate;
	SCDynamicStore      *scNotificationManager;
	NSMutableDictionary *airportStatus;
}

- (id) initWithDelegate:(id)object;
@end

@interface NSObject(NetworkNotifierDelegate)
- (void) linkUp:(NSString *)description;
- (void) linkDown:(NSString *)description;
- (void) ipAcquired:(NSString *)ip;
- (void) ipReleased;
- (void) airportConnect:(NSString *)description;
- (void) airportDisconnect:(NSString *)description;
@end
