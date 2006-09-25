//
//  GrowlNotificationCenter.h
//  Growl
//
//  Created by Ingmar Stein on 27.04.05.
//  Copyright 2005 The Growl Project. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@protocol GrowlNotificationObserver
- (void) notifyWithDictionary:(NSDictionary *)dict;
@end

@protocol GrowlNotificationCenterProtocol
- (oneway void) addObserver:(byref id<GrowlNotificationObserver>)observer;
- (oneway void) removeObserver:(byref id<GrowlNotificationObserver>)observer;
@end

@interface GrowlNotificationCenter : NSObject <GrowlNotificationCenterProtocol> {
	NSMutableArray *observers;
}
- (void) addObserver:(id<GrowlNotificationObserver>)observer;
- (void) removeObserver:(id<GrowlNotificationObserver>)observer;
- (void) notifyObservers:(NSDictionary *)dict;
@end

