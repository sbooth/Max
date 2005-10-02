/*
 *  $Id$
 *
 *  Copyright (C) 2005 Stephen F. Booth <me@sbooth.org>
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

#import "PreferencesController.h"

#import "CDDB.h"
#import "CDDBSite.h"
#import "MissingResourceException.h"

#import "UtilityFunctions.h"

#define kDiscNumberButton		0
#define kDiscsInSetButton		1
#define kDiscArtistButton		2
#define kDiscTitleButton		3
#define kDiscGenreButton		4
#define kDiscYearButton			5
#define kTrackNumberButton		6
#define kTrackArtistButton		7
#define kTrackTitleButton		8
#define kTrackGenreButton		9
#define kTrackYearButton		10

static PreferencesController *sharedPreferences = nil;

@implementation PreferencesController

// Set up initial defaults
+ (void) initialize
{
	NSString				*defaultsPath;
    NSMutableDictionary		*defaultsDictionary;
    NSDictionary			*initialValuesDictionary;
    NSArray					*resettableUserDefaultsKeys;
	NSArray					*defaultFiles;
	int						i;

	@try {
		defaultsDictionary	= [[[NSMutableDictionary alloc] initWithCapacity:20] autorelease];
		defaultFiles		= [NSArray arrayWithObjects:@"CDDBDefaults", @"CompactDiscControllerDefaults", @"LAMEDefaults", @"TrackDefaults", nil];
		// Add the default values as resettable
		for(i = 0; i < [defaultFiles count]; ++i) {
			defaultsPath = [[NSBundle mainBundle] pathForResource:[defaultFiles objectAtIndex:i] ofType:@"plist"];
			if(nil == defaultsPath) {
				@throw [MissingResourceException exceptionWithReason:[NSString stringWithFormat:@"Unable to load %@.plist  Some preferences may not display correctly.", [defaultFiles objectAtIndex:i]] userInfo:nil];
			}
			[defaultsDictionary addEntriesFromDictionary:[NSDictionary dictionaryWithContentsOfFile:defaultsPath]];
		}
	    
		resettableUserDefaultsKeys = [NSArray arrayWithObjects:@"org.sbooth.Max.customNamingUseFallback", @"org.sbooth.Max.customTrackColor", 
			@"org.sbooth.Max.freeDBPort", @"org.sbooth.Max.freeDBProtocol", @"org.sbooth.Max.freeDBServer", 
			@"org.sbooth.Max.lameBitrate", @"org.sbooth.Max.lameEncodingEngineQuality", @"org.sbooth.Max.lameMonoEncoding", 
			@"org.sbooth.Max.lameQuality",@"org.sbooth.Max.lameTarget", @"org.sbooth.Max.lameUseConstantBitrate", 
			@"org.sbooth.Max.lameVBRQuality", @"org.sbooth.Max.lameVariableBitrateMode", 
			@"org.sbooth.Max.outputDirectory", @"org.sbooth.Max.useCustomNaming", nil];
		initialValuesDictionary = [defaultsDictionary dictionaryWithValuesForKeys:resettableUserDefaultsKeys];
		
		[[NSUserDefaultsController sharedUserDefaultsController] setInitialValues:initialValuesDictionary];
	}
	@catch(NSException *exception) {
		displayExceptionAlert(exception);
	}
	@finally {
	}
}

+ (PreferencesController *) sharedPreferences
{
	@synchronized(self) {
		if(nil == sharedPreferences) {
			sharedPreferences = [[[self alloc] init] autorelease];
		}
	}
	return sharedPreferences;
}

+ (id) allocWithZone:(NSZone *)zone
{
    @synchronized(self) {
        if(nil == sharedPreferences) {
            return [super allocWithZone:zone];
        }
    }
    return sharedPreferences;
}

- (id)init
{
	if(self = [super init]) {
		
		@try {
			if(NO == [NSBundle loadNibNamed:@"Preferences" owner:self])  {
				@throw [MissingResourceException exceptionWithReason:@"Unable to load Preferences.nib" userInfo:nil];
			}

			// Update the example track text field
			[self controlTextDidChange:nil];

			// Get mirror list
			CDDB *cddb = [[[CDDB alloc] init] autorelease];
			[self setValue:[cddb fetchSites] forKey:@"cddbMirrors"];
		}
		
		@catch(NSException *exception) {
			displayExceptionAlert(exception);
		}
		
		@finally {
		}
	}
	return self;
}

- (void) dealloc
{
	if(nil != _cddbMirrors) {
		[_cddbMirrors release];
	}
	[super dealloc];
}

- (id) copyWithZone:(NSZone *)zone								{ return self; }
- (id) retain													{ return self; }
- (unsigned) retainCount										{ return UINT_MAX;  /* denotes an object that cannot be released */ }
- (void) release												{ /* do nothing */ }
- (id) autorelease												{ return self; }

- (void)showPreferencesWindow
{
	[_window makeKeyAndOrderFront:self];
}


- (IBAction)setFreeDBMirror:(id)sender
{
	NSArray *selectedObjects = [_cddbMirrorsController selectedObjects];
	if(0 < [selectedObjects count]) {
		CDDBSite					*mirror					= [selectedObjects objectAtIndex:0];
		NSUserDefaultsController	*defaultsController		= [NSUserDefaultsController sharedUserDefaultsController];
		[[defaultsController values] setValue:[mirror valueForKey:@"address"] forKey:@"org.sbooth.Max.freeDBServer"];
		[[defaultsController values] setValue:[mirror valueForKey:@"port"] forKey:@"org.sbooth.Max.freeDBPort"];
		[[defaultsController values] setValue:[mirror valueForKey:@"protocol"] forKey:@"org.sbooth.Max.freeDBProtocol"];
	}
}

- (IBAction)customNamingButtonAction:(id)sender
{
	NSString *string;
	switch([(NSButton *)sender tag]) {
		case kDiscNumberButton:			string = @"{discNumber}";		break;
		case kDiscsInSetButton:			string = @"{discsInSet}";		break;
		case kDiscArtistButton:			string = @"{discArtist}";		break;
		case kDiscTitleButton:			string = @"{discTitle}";		break;
		case kDiscGenreButton:			string = @"{discGenre}";		break;
		case kDiscYearButton:			string = @"{discYear}";			break;
		case kTrackNumberButton:		string = @"{trackNumber}";		break;
		case kTrackArtistButton:		string = @"{trackArtist}";		break;
		case kTrackTitleButton:			string = @"{trackTitle}";		break;
		case kTrackGenreButton:			string = @"{trackGenre}";		break;
		case kTrackYearButton:			string = @"{trackYear}";		break;
	}
	
	NSText *fieldEditor = [_customNameTextField currentEditor];
	if(nil == fieldEditor) {
		[_customNameTextField setStringValue:string];
	}
	else {
		if([_customNameTextField textShouldBeginEditing:fieldEditor]) {
			[fieldEditor replaceCharactersInRange:[fieldEditor selectedRange] withString:string];
			[_customNameTextField textShouldEndEditing:fieldEditor];
			[self controlTextDidChange:nil];
		}
	}
}

- (IBAction)selectOutputDirectory:(id)sender
{
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	[panel setAllowsMultipleSelection:NO];
	[panel setCanChooseDirectories:YES];
	[panel setCanChooseFiles:NO];
	
	[panel beginSheetForDirectory:nil file:nil types:nil modalForWindow:_window modalDelegate:self didEndSelector:@selector(openPanelDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

- (IBAction)restoreDefaults:(id)sender
{
	[[NSUserDefaultsController sharedUserDefaultsController] revertToInitialValues:nil];
}

- (void)openPanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    if(NSOKButton == returnCode) {
		NSArray *filesToOpen = [sheet filenames];
		int i, count = [filesToOpen count];
		for (i=0; i<count; i++) {
			NSString *aFile = [filesToOpen objectAtIndex:i];
			[[[NSUserDefaultsController sharedUserDefaultsController] values] setValue:aFile forKey:@"org.sbooth.Max.outputDirectory"];
		}
	}	
}

#pragma mark NSTextField Delegate methods

- (void)controlTextDidChange:(NSNotification *)aNotification
{
	NSMutableString *sample = [[[NSMutableString alloc] initWithCapacity:[[_customNameTextField stringValue] length]] autorelease];

	[sample setString:[_customNameTextField stringValue]];
	
	[sample replaceOccurrencesOfString:@"{discNumber}"		withString:@"" options:nil range:NSMakeRange(0, [sample length])];
	[sample replaceOccurrencesOfString:@"{discsInSet}"		withString:@"" options:nil range:NSMakeRange(0, [sample length])];
	[sample replaceOccurrencesOfString:@"{discArtist}"		withString:@"Nirvana" options:nil range:NSMakeRange(0, [sample length])];
	[sample replaceOccurrencesOfString:@"{discTitle}"		withString:@"MTV Unplugged in New York" options:nil range:NSMakeRange(0, [sample length])];
	[sample replaceOccurrencesOfString:@"{discGenre}"		withString:@"Grunge" options:nil range:NSMakeRange(0, [sample length])];
	[sample replaceOccurrencesOfString:@"{discYear}"		withString:@"1994" options:nil range:NSMakeRange(0, [sample length])];
	[sample replaceOccurrencesOfString:@"{trackNumber}"		withString:@"4" options:nil range:NSMakeRange(0, [sample length])];
	[sample replaceOccurrencesOfString:@"{trackArtist}"		withString:@"" options:nil range:NSMakeRange(0, [sample length])];
	[sample replaceOccurrencesOfString:@"{trackTitle}"		withString:@"The Man Who Sold the World" options:nil range:NSMakeRange(0, [sample length])];
	[sample replaceOccurrencesOfString:@"{trackGenre}"		withString:@"" options:nil range:NSMakeRange(0, [sample length])];
	[sample replaceOccurrencesOfString:@"{trackYear}"		withString:@"" options:nil range:NSMakeRange(0, [sample length])];
	
	[self setValue:sample forKey:@"customNameExample"];
}

@end
