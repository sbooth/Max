//
//  GrowlApplicationTicket.h
//  Growl
//
//  Created by Karl Adam on Tue Apr 27 2004.
//  Copyright 2004-2005 The Growl Project. All rights reserved.
//
// This file is under the BSD License, refer to License.txt for details


#import <Foundation/Foundation.h>

@protocol GrowlDisplayPlugin;

@class GrowlApplicationNotification;

@interface GrowlApplicationTicket : NSObject {
	NSString		*appName;					// This app's name for display by notifications that want it
	NSString		*appPath;					// This app's location on disk (cached here and in saved tickets)
	NSImage			*icon;						// This app's icon for notifications and display methods that want it

	NSDictionary	*allNotifications;			// All the notifications possible for this app
	NSArray			*allNotificationNames;		// Keys of allNotifications, in the order in which they were originally passed

	NSArray			*defaultNotifications;		// The default notifications

	NSString		*displayPluginName;
	id <GrowlDisplayPlugin> displayPlugin;		// Non-nil if this ticket uses a custom display plugin

	BOOL			useDefaults;				// Flag for whether this ticket just uses default
	BOOL			ticketEnabled;
	BOOL			clickHandlersEnabled;		// Flag whether click handlers are enabled
}

+ (NSDictionary *) allSavedTickets;
+ (void) loadTicketsFromDirectory:(NSString *)srcDir intoDictionary:(NSMutableDictionary *)dict clobbering:(BOOL)clobber;

//these are specifically for auto-discovery tickets, hence the requirement of GROWL_TICKET_VERSION.
+ (BOOL) isValidTicketDictionary:(NSDictionary *)dict;
+ (BOOL) isKnownTicketVersion:(NSDictionary *)dict;

#pragma mark -

//designated initialiser.
+ (id) ticketWithDictionary:(NSDictionary *)ticketDict;
- (id) initWithDictionary:(NSDictionary *)dict;

- (id) initTicketFromPath:(NSString *) inPath;
- (id) initTicketForApplication: (NSString *) inApp;

- (void) saveTicket;
- (void) saveTicketToPath:(NSString *)destDir;
- (NSString *) path;
- (void) synchronize;

#pragma mark -

- (NSImage *) icon;
- (void) setIcon:(NSImage *) inIcon;

- (NSString *) applicationName;

- (BOOL) ticketEnabled;
- (void) setTicketEnabled:(BOOL)inEnabled;

- (BOOL) clickHandlersEnabled;
- (void) setClickHandlersEnabled:(BOOL)inEnabled;

- (BOOL) useDefaults;
- (void) setUseDefaults:(BOOL)flag;

- (NSString *) displayPluginName;
- (id <GrowlDisplayPlugin>) displayPlugin;
- (void) setDisplayPluginName: (NSString *)name;

#pragma mark -

- (void) reregisterWithAllNotifications:(NSArray *) inAllNotes
							   defaults:(id) inDefaults
								   icon:(NSImage *) inIcon;
- (void) reregisterWithDictionary:(NSDictionary *) dict;

- (NSArray *) allNotifications;
- (void) setAllNotifications:(NSArray *) inArray;

- (NSArray *) defaultNotifications;
- (void) setDefaultNotifications:(id) inObject;

- (NSArray *) allowedNotifications;
- (void) setAllowedNotifications:(NSArray *) inArray;
- (void) setAllowedNotificationsToDefault;

- (BOOL) isNotificationAllowed:(NSString *) name;

#pragma mark Notification accessors
- (NSArray *) notifications;
- (GrowlApplicationNotification *) notificationForName:(NSString *)name;
@end
