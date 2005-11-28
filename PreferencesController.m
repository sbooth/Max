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

#import "FreeDB.h"
#import "FreeDBSite.h"
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
	unsigned				i;

	@try {
		defaultsDictionary	= [[[NSMutableDictionary alloc] initWithCapacity:20] autorelease];
		defaultFiles		= [NSArray arrayWithObjects:@"FreeDBDefaults", @"CompactDiscDocumentDefaults", @"ParanoiaDefaults", @"LAMEDefaults", @"TrackDefaults", @"TaskMasterDefaults", nil];
		// Add the default values as resettable
		for(i = 0; i < [defaultFiles count]; ++i) {
			defaultsPath = [[NSBundle mainBundle] pathForResource:[defaultFiles objectAtIndex:i] ofType:@"plist"];
			if(nil == defaultsPath) {
				@throw [MissingResourceException exceptionWithReason:[NSString stringWithFormat:@"Unable to load %@.plist  Some preferences may not display correctly.", [defaultFiles objectAtIndex:i]] userInfo:nil];
			}
			[defaultsDictionary addEntriesFromDictionary:[NSDictionary dictionaryWithContentsOfFile:defaultsPath]];
		}
	    
		resettableUserDefaultsKeys = [NSArray arrayWithObjects:@"customNamingUseFallback", @"customTrackColor", 
			@"outputMP3", @"outputFLAC", @"outputOgg",
			@"freeDBPort", @"freeDBProtocol", @"freeDBServer", 
			@"paranoiaEnable", @"paranoiaLevel", @"paranoiaNeverSkip", @"paranoiaMaximumRetries",
			@"lameBitrate", @"lameEncodingEngineQuality", @"lameMonoEncoding", 
			@"lameQuality",@"lameTarget", @"lameUseConstantBitrate", 
			@"lameVBRQuality", @"lameVariableBitrateMode", 
			@"outputDirectory", @"useCustomNaming", @"customNamingScheme", 
			@"maximumEncoderThreads", nil];
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
			sharedPreferences = [[self alloc] init];
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
	if((self = [super initWithWindowNibName:@"Preferences"])) {

		@try {
			[self setShouldCascadeWindows:NO];
			[self setWindowFrameAutosaveName:@"Preferences"];	

			// Update the example track text field
			[self controlTextDidChange:nil];
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
	if(nil != _freeDBMirrors) {
		[_freeDBMirrors release];
	}
	[super dealloc];
}

- (id) copyWithZone:(NSZone *)zone								{ return self; }
- (id) retain													{ return self; }
- (unsigned) retainCount										{ return UINT_MAX;  /* denotes an object that cannot be released */ }
- (void) release												{ /* do nothing */ }
- (id) autorelease												{ return self; }


- (IBAction)setFreeDBMirror:(id)sender
{
	NSArray *selectedObjects = [_freeDBMirrorsController selectedObjects];
	if(0 < [selectedObjects count]) {
		FreeDBSite					*mirror					= [selectedObjects objectAtIndex:0];
		NSUserDefaultsController	*defaultsController		= [NSUserDefaultsController sharedUserDefaultsController];
		[[defaultsController values] setValue:[mirror valueForKey:@"address"] forKey:@"freeDBServer"];
		[[defaultsController values] setValue:[mirror valueForKey:@"port"] forKey:@"freeDBPort"];
		[[defaultsController values] setValue:[mirror valueForKey:@"protocol"] forKey:@"freeDBProtocol"];
	}
}

- (IBAction)refreshFreeDBMirrorList:(id)sender
{
	@try {
		// Get mirror list
		FreeDB *freeDB = [[[FreeDB alloc] init] autorelease];
		[self setValue:[freeDB fetchSites] forKey:@"freeDBMirrors"];
	}
	
	@catch(NSException *exception) {
		displayExceptionAlert(exception);
	}
	
	@finally {
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
	
	[panel beginSheetForDirectory:nil file:nil types:nil modalForWindow:[self window] modalDelegate:self didEndSelector:@selector(openPanelDidEnd:returnCode:contextInfo:) contextInfo:nil];
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
			[[[NSUserDefaultsController sharedUserDefaultsController] values] setValue:aFile forKey:@"outputDirectory"];
		}
	}	
}

#pragma mark Delegate methods

- (void) controlTextDidChange:(NSNotification *)aNotification
{
	NSString *scheme = [_customNameTextField stringValue];
	if(nil == scheme) {
		scheme = [[NSUserDefaults standardUserDefaults] stringForKey:@"customNamingScheme"];
	}
	// No love
	if(nil == scheme) {
		return;
	}
	
	NSMutableString *sample = [[[NSMutableString alloc] initWithCapacity:[scheme length]] autorelease];
	[sample setString:scheme];		
	
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
