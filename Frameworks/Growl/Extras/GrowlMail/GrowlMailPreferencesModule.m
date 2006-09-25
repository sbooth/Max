/*
 Copyright (c) The Growl Project, 2004-2005
 All rights reserved.

 Redistribution and use in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 2. Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 3. Neither the name of Growl nor the names of its contributors
 may be used to endorse or promote products derived from this software
 without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 OF THE POSSIBILITY OF SUCH DAMAGE.
*/
//
//  GrowlMailPreferencesModule.m
//  GrowlMail
//
//  Created by Ingmar Stein on 29.10.04.
//

#import "GrowlMailPreferencesModule.h"
#import "GrowlMail.h"

@interface MailAccount(GrowlMail)
+ (NSArray *) remoteMailAccounts;
@end

@implementation MailAccount(GrowlMail)
+ (NSArray *) remoteMailAccounts; {
	NSArray *mailAccounts = [MailAccount mailAccounts];
	NSMutableArray *remoteAccounts = [NSMutableArray arrayWithCapacity:[mailAccounts count]];
	NSEnumerator *enumerator = [mailAccounts objectEnumerator];
	id account;
	Class localAccountClass = [LocalAccount class];
	while ((account = [enumerator nextObject])) {
		if (![account isKindOfClass:localAccountClass]) {
			[remoteAccounts addObject:account];
		}
	}

	return remoteAccounts;
}
@end

@implementation GrowlMailPreferencesModule
- (void) awakeFromNib {
	NSTableColumn *activeColumn = [accountsView tableColumnWithIdentifier:@"active"];
	[[activeColumn dataCell] setImagePosition:NSImageOnly]; // center the checkbox
}

- (NSString *) preferencesNibName {
	return @"GrowlMailPreferencesPanel";
}

- (id) viewForPreferenceNamed:(NSString *)aName {
#pragma unused(aName)
	if (!_preferencesView) {
		[NSBundle loadNibNamed:[self preferencesNibName] owner:self];
	}
	return _preferencesView;
}

- (NSString *) titleForIdentifier:(NSString *)aName {
#pragma unused(aName)
	return @"GrowlMail";
}

- (NSImage *) imageForPreferenceNamed:(NSString *)aName {
#pragma unused(aName)
	return [NSImage imageNamed:@"GrowlMail"];
}

- (NSSize) minSize {
	return NSMakeSize( 298.0f, 215.0f );
}

- (int) numberOfRowsInTableView:(NSTableView *)aTableView {
#pragma unused(aTableView)
	return [[MailAccount remoteMailAccounts] count];
}

- (id) tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex {
#pragma unused(aTableView)
	MailAccount *account = [[MailAccount remoteMailAccounts] objectAtIndex:rowIndex];
	if ([[aTableColumn identifier] isEqualToString:@"active"]) {
		return [NSNumber numberWithBool:[[GrowlMail sharedInstance] isAccountEnabled:[account path]]];
	} else {
		return [account displayName];
	}
}

- (void) tableView:(NSTableView *)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex {
#pragma unused(aTableView)
#pragma unused(aTableColumn)
	MailAccount *account = [[MailAccount remoteMailAccounts] objectAtIndex:rowIndex];
	[[GrowlMail sharedInstance] setAccountEnabled:[anObject boolValue] path:[account path]];
}

@end
