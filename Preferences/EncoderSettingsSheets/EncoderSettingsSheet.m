/*
 *  $Id$
 *
 *  Copyright (C) 2005, 2006 Stephen F. Booth <me@sbooth.org>
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

#import "EncoderSettingsSheet.h"
#import "PreferencesController.h"
#import "MissingResourceException.h"

@interface EncoderSettingsSheet (Private)
- (void)	didEndSheet:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
@end

@implementation EncoderSettingsSheet

+ (NSDictionary *) defaultSettings { return [NSDictionary dictionary]; }

- (id) initWithNibName:(NSString *)nibName settings:(NSDictionary *)settings;
{
	if((self = [super init])) {
		
		// Setup the settings before loading the nib
		_settings		= [[NSMutableDictionary alloc] init];
		[_settings addEntriesFromDictionary:settings];
		
		if(NO == [NSBundle loadNibNamed:nibName owner:self])  {
			@throw [MissingResourceException exceptionWithReason:NSLocalizedStringFromTable(@"Your installation of Max appears to be incomplete.", @"Exceptions", @"")
														userInfo:[NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"%@.nib", nibName] forKey:@"filename"]];
		}
		
		return self;
	}
	return nil;
}

- (void) dealloc
{
	[_settings release];	_settings = nil;
	[_searchKey release];	_searchKey = nil;
	
	[super dealloc];
}

- (NSDictionary *)	searchKey									{ return [[_searchKey retain] autorelease]; }
- (void)			setSearchKey:(NSDictionary *)searchKey		{ [_searchKey release]; _searchKey = [searchKey retain]; }

- (NSDictionary *)	settings									{ return [[_settings retain] autorelease]; }
- (void)			setSettings:(NSDictionary *)settings		{ [_settings release]; _settings = [settings retain]; }

- (IBAction) editSettings:(id)sender;
{
    [[NSApplication sharedApplication] beginSheet:_sheet modalForWindow:[[PreferencesController sharedPreferences] window] modalDelegate:self didEndSelector:@selector(didEndSheet:returnCode:contextInfo:) contextInfo:nil];
}

- (IBAction) ok:(id)sender
{
	NSMutableArray			*formats		= nil;
	NSMutableDictionary		*newFormat		= nil;
	unsigned				index			= NSNotFound;

	// Swap out the userInfo object in this format's dictionary with the modified one
	formats		= [[[NSUserDefaults standardUserDefaults] arrayForKey:@"outputFormats"] mutableCopy];
	index		= [formats indexOfObject:[self searchKey]];
	
	if(NSNotFound != index) {
		newFormat	= [[self searchKey] mutableCopy];
		
		[newFormat setObject:_settings forKey:@"settings"];
		[formats replaceObjectAtIndex:index withObject:newFormat];
		
		// Save changes
		[[NSUserDefaults standardUserDefaults] setObject:formats forKey:@"outputFormats"];
	}

	// We're finished
    [[NSApplication sharedApplication] endSheet:_sheet];
}

- (void) didEndSheet:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    [sheet orderOut:self];
}

@end
