/*
 *  Copyright (C) 2005 - 2007 Stephen F. Booth <me@sbooth.org>
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

@implementation EncoderSettingsSheet

+ (NSDictionary *) defaultSettings { return [NSDictionary dictionary]; }

- (id) initWithNibName:(NSString *)nibName settings:(NSDictionary *)settings;
{
	if((self = [super init])) {
		BOOL	result;
		
		// Setup the settings before loading the nib
		_settings		= [[NSMutableDictionary alloc] init];
		[_settings addEntriesFromDictionary:settings];
		
		result = [NSBundle loadNibNamed:nibName owner:self];
		NSAssert1(YES == result, NSLocalizedStringFromTable(@"Your installation of Max appears to be incomplete.", @"Exceptions", @""), [nibName stringByAppendingString:@".nib"]);
		
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
- (void)			setSettings:(NSDictionary *)settings		{ [_settings release]; _settings = [settings mutableCopy]; }

- (NSWindow *)		sheet										{ return [[_sheet retain] autorelease]; }

- (IBAction) ok:(id)sender
{
	NSMutableArray			*formats		= nil;
	NSMutableDictionary		*newFormat		= nil;
	NSUInteger				index			= NSNotFound;

	// Swap out the userInfo object in this format's dictionary with the modified one
	formats		= [[[NSUserDefaults standardUserDefaults] arrayForKey:@"outputFormats"] mutableCopy];
	index		= [formats indexOfObject:[self searchKey]];
	
	if(NSNotFound != index) {
		newFormat	= [[self searchKey] mutableCopy];
		
		// Special case for Core Audio and Libsndfile subclasses
		if([self respondsToSelector:@selector(formatName)]) {
			[newFormat setObject:[self formatName] forKey:@"name"];
		}
		
		[newFormat setObject:[self settings] forKey:@"settings"];
		[formats replaceObjectAtIndex:index withObject:newFormat];
		
		// Save changes
		[[NSUserDefaults standardUserDefaults] setObject:formats forKey:@"outputFormats"];
	}
	
	// Clean up
	[formats release];

	// We're finished
	[[NSApplication sharedApplication] endSheet:[self sheet] returnCode:NSOKButton];
}

@end
