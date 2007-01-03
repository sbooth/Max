/*
 * $Id: SCDynamicStore.h 901 2004-12-18 19:53:59Z slamb $
 *
 * Copyright (C) 2004 Scott Lamb <slamb@slamb.org>
 * This file is part of NetGrowler, which is released under the MIT license.
 */

#import <Foundation/Foundation.h>
#import <SystemConfiguration/SystemConfiguration.h>

/**
 * An AppKit-style wrapper around the Foundation-style SystemConfiguration framework's dynamic stores.
 * Provides access to the SystemConfiguration keys.
 * Both simple queries and change notifications are supported.
 */
@interface SCDynamicStore : NSObject {
	/** A reference to the SystemConfiguration dynamic store. */
	SCDynamicStoreRef dynStore;

	/** Our run loop source for notification. */
	CFRunLoopSourceRef rlSrc;

	/** Dictionary of watched key names (NSString) to observers (internal Observer class). */
	NSMutableDictionary *watchedKeysDict;
}

/**
 * Retrieves the value of the specified key.
 * @return The key's dictionary of values, or null if the key is not found.
 */
- (NSDictionary *) valueForKey:(NSString *)aKey;

/**
 * Monitors a single key for changes.
 */
- (void) addObserver:(id)anObserver selector:(SEL)aSelector forKey:(NSString *)aKey;

@end
