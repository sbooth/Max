//
//  GrowlApplicationNotification.h
//  Growl
//
//  Created by Karl Adam on 01.10.05.
//  Copyright 2005 matrixPointer. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class GrowlApplicationTicket;

typedef enum GrowlPriority {
	GP_unset		= -1000,
	GP_verylow		= -2,
	GP_low			= -1,
	GP_normal		=  0,
	GP_high			=  1,
	GP_emergency	=  2
} GrowlPriority;

@interface GrowlApplicationNotification : NSObject {
	NSString				*name;
	GrowlPriority			priority;
	BOOL					enabled;
	int						sticky;
	NSString				*displayPluginName;
	GrowlApplicationTicket	*ticket;		// Our owner
	id <GrowlDisplayPlugin> displayPlugin;	// Non-nil if this notification uses a custom display plugin
}

+ (GrowlApplicationNotification *) notificationWithName:(NSString *)name;
+ (GrowlApplicationNotification *) notificationFromDict:(NSDictionary *)dict;
- (GrowlApplicationNotification *) initWithName:(NSString *)name;
- (GrowlApplicationNotification *) initWithDict:(NSDictionary *)dict;
- (GrowlApplicationNotification *) initWithName:(NSString *)name priority:(GrowlPriority)priority enabled:(BOOL)enabled sticky:(int)sticky displayPlugin:(NSString *)display;
- (NSDictionary *) notificationAsDict;

#pragma mark -

- (NSString *) name;

- (GrowlPriority) priority;
- (void) setPriority:(GrowlPriority)newPriority;

- (BOOL) enabled;
- (void) setEnabled:(BOOL)flag;

- (void) enable;
- (void) disable;

- (int) sticky;
- (void) setSticky:(int)sticky;

- (GrowlApplicationTicket *) ticket;
- (void) setTicket:(GrowlApplicationTicket *)owner;

- (NSString *)displayPluginName;
- (id <GrowlDisplayPlugin>) displayPlugin;
- (void) setDisplayPluginName: (NSString *)name;
@end
