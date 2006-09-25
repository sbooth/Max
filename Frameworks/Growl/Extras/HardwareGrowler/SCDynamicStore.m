/*
 * $Id: SCDynamicStore.m 901 2004-12-18 19:53:59Z slamb $
 *
 * Copyright (C) 2004 Scott Lamb <slamb@slamb.org>
 * This file is part of NetGrowler, which is released under the MIT license.
 */

#import <CoreFoundation/CoreFoundation.h>
#import <CoreFoundation/CFArray.h>
#import "SCDynamicStore.h"

@interface SCDynamicStore (PRIVATE)
- (void)notificationOfChangedKeys:(NSArray*)changedKeys;
@end

@interface SLObserver : NSObject
{
	id observer;
	SEL selector;
}

+ (id)observer:(id)anObserver withSelector:(SEL)aSelector;
- (id)observer;
- (SEL)selector;

@end

@implementation SLObserver
+ (id) observer:(id)anObserver withSelector:(SEL)aSelector {
	SLObserver *o = [[SLObserver alloc] init];
	o->observer = anObserver;
	o->selector = aSelector;
	return [o autorelease];
}

- (id)observer {
	return observer;
}

- (SEL)selector {
	return selector;
}

@end

static void scCallback(SCDynamicStoreRef dynStore, CFArrayRef changedKeys, void *info) {
	[(SCDynamicStore*) info notificationOfChangedKeys:(NSArray*) changedKeys];
}

@implementation SCDynamicStore

- (void) notificationOfChangedKeys:(NSArray*)changedKeys {
	NSEnumerator *keysE = [changedKeys objectEnumerator];
	NSString *key = nil;

	while ((key = [keysE nextObject])) {
		NSEnumerator *observers = [[self->watchedKeysDict objectForKey:key] objectEnumerator];
		SLObserver *o = nil;
		NSDictionary *newValue = [(NSDictionary*) SCDynamicStoreCopyValue(dynStore, (CFStringRef) key) autorelease];

		while ((o = [observers nextObject]))
			[[o observer] performSelector:[o selector] withObject:newValue];
	}
}


- (id) init {
	self = [super init];
	watchedKeysDict = [[NSMutableDictionary alloc] init];

	SCDynamicStoreContext context = {
		.version			= 0,
		.info				= self,
		.retain				= NULL,
		.release			= NULL,
		.copyDescription	= NULL
	};

	dynStore = SCDynamicStoreCreate(
		NULL,
		(CFStringRef) [[NSBundle mainBundle] bundleIdentifier],
		scCallback,
		&context
	);

	rlSrc = SCDynamicStoreCreateRunLoopSource(NULL, dynStore, 0);
	CFRunLoopAddSource(CFRunLoopGetCurrent(), rlSrc, kCFRunLoopCommonModes);

	return self;
}

- (NSDictionary *) valueForKey:(NSString*)aKey {
	CFPropertyListRef dict = SCDynamicStoreCopyValue(dynStore, (CFStringRef) aKey);
	return [(NSDictionary*) dict autorelease];
}

- (void) addObserver:(id)anObserver selector:(SEL)aSelector forKey:(NSString *)aKey {
	NSMutableArray *observers = [self->watchedKeysDict objectForKey:aKey];
	if (!observers)
		observers = [NSMutableArray array];

	[observers addObject:[SLObserver observer:anObserver withSelector:aSelector]];
	[watchedKeysDict setObject:observers forKey:aKey];
	SCDynamicStoreSetNotificationKeys(dynStore,
									  (CFArrayRef) [watchedKeysDict allKeys],
									  NULL);
}

- (void) dealloc {
	CFRunLoopRemoveSource(CFRunLoopGetCurrent(), rlSrc, kCFRunLoopCommonModes);

	CFRelease(rlSrc);
	CFRelease(dynStore);

	[watchedKeysDict release];
	[super dealloc];
}

@end
