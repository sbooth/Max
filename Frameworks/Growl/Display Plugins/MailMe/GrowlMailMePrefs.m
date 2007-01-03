//
//  GrowlMailMePrefs.m
//  Display Plugins
//
//  Copyright 2004 Mac-arena the Bored Zo. All rights reserved.
//

#import "GrowlMailMePrefs.h"
#import <GrowlDefinesInternal.h>

#define destAddressKey @"MailMe - Recipient address"

@implementation GrowlMailMePrefs

- (NSString *) mainNibName {
	return @"GrowlMailMePrefs";
}

- (void) didSelect {
	SYNCHRONIZE_GROWL_PREFS();
}

#pragma mark -

- (NSString *) getDestAddress {
	NSString *value = nil;
	READ_GROWL_PREF_VALUE(destAddressKey, @"com.Growl.MailMe", NSString *, &value);
	return [value autorelease];
}

- (void) setDestAddress:(NSString *)value {
	if (!value) {
		value = @"";
	}
	WRITE_GROWL_PREF_VALUE(destAddressKey, value, @"com.Growl.MailMe");
	UPDATE_GROWL_PREFS();
}

@end
