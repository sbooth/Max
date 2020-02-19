/*
 *  Copyright (C) 2005 - 2020 Stephen F. Booth <me@sbooth.org>
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#import "FormatsController.h"
#import "PreferencesController.h"

static FormatsController			*sharedController						= nil;

@implementation FormatsController

+ (FormatsController *) sharedController
{
	@synchronized(self) {
		if(nil == sharedController)
			[[self alloc] init];
	}
	return sharedController;
}

+ (id) allocWithZone:(NSZone *)zone
{
    @synchronized(self) {
        if(nil == sharedController) {
            sharedController = [super allocWithZone:zone];
			return sharedController;
		}
    }
    return nil;
}

- (id) init
{
	if((self = [super initWithWindowNibName:@"Formats"])) {
	}
	return self;
}

- (void) awakeFromNib
{
	[_encodersController setSortDescriptors:[NSArray arrayWithObjects:
		[[[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES] autorelease],
		[[[NSSortDescriptor alloc] initWithKey:@"nickname" ascending:YES] autorelease],
		nil]];
}

- (void) windowDidLoad
{
	[self setShouldCascadeWindows:NO];
	[self setWindowFrameAutosaveName:@"Formats"];
	[[self window] setExcludedFromWindowsMenu:YES];
}

- (id)			copyWithZone:(NSZone *)zone						{ return self; }
- (id)			retain											{ return self; }
- (NSUInteger)	retainCount										{ return UINT_MAX;  /* denotes an object that cannot be released */ }
- (oneway void)	release											{ /* do nothing */ }
- (id)			autorelease										{ return self; }

- (NSArray *) selectedFormats
{
	NSArray *outputFormats = [[NSUserDefaults standardUserDefaults] arrayForKey:@"outputFormats"];
	return [outputFormats filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"selected == 1"]];
}

- (IBAction) setupEncoders:(id)sender
{
	[[PreferencesController sharedPreferences] selectPreferencePane:FormatsPreferencesToolbarItemIdentifier];
	[[PreferencesController sharedPreferences] showWindow:self];
}

@end
