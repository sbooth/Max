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

#import "CompactDisc.h"

#import "CompactDiscController.h"
#import "Track.h"
#import "Track.h"
#import "FreeDB.h"
#import "FreeDBMatchSheet.h"
#import "Genres.h"
#import "TaskMaster.h"
#import "Encoder.h"
#import "Tagger.h"

#import "MallocException.h"
#import "IOException.h"
#import "FreeDBException.h"
#import "EmptySelectionException.h"
#import "MissingResourceException.h"

#import "UtilityFunctions.h"

#include "cddb/cddb_track.h"

#include <sys/param.h>		// MAXPATHLEN
#include <paths.h>			//_PATH_DEV


@implementation CompactDisc

+ (void) initialize
{
	NSString				*compactDiscDefaultsValuesPath;
    NSDictionary			*compactDiscDefaultsValuesDictionary;
	
	@try {
		// Set up defaults
		compactDiscDefaultsValuesPath = [[NSBundle mainBundle] pathForResource:@"CompactDiscDefaults" ofType:@"plist"];
		if(nil == compactDiscDefaultsValuesPath) {
			@throw [MissingResourceException exceptionWithReason:@"Unable to load CompactDiscDefaults.plist" userInfo:nil];
		}
		compactDiscDefaultsValuesDictionary = [NSDictionary dictionaryWithContentsOfFile:compactDiscDefaultsValuesPath];
		[[NSUserDefaults standardUserDefaults] registerDefaults:compactDiscDefaultsValuesDictionary];
		
	}
	@catch(NSException *exception) {
		displayExceptionAlert(exception);
	}
	@finally {
	}	
}

- (id) init
{
	NSLog(@"CompactDisc::init");
	if((self = [super init])) {
		_tracks			= [[NSMutableArray alloc] initWithCapacity:20];
		_drive			= NULL;
		_cddb_disc		= NULL;
		_length			= 0;
		
		return self;
	}
	else {
		return nil;
	}
}

- (void) setBSDName:(NSString *) bsdName
{
	unsigned			i;
	unsigned long		discLength	= 150;
	
	_drive = [[CDDrive alloc] initWithBSDName:bsdName];
	
	for(i = 1; i <= [_drive trackCount]; ++i) {
		Track			*track		= [[[Track alloc] init] autorelease];
		
		[track setValue:[NSNumber numberWithUnsignedInt:i] forKey:@"number"];
		[track setValue:[NSNumber numberWithUnsignedLong:[_drive firstSectorForTrack:i]] forKey:@"firstSector"];
		[track setValue:[NSNumber numberWithUnsignedLong:[_drive lastSectorForTrack:i]] forKey:@"lastSector"];
		
		[track setValue:[NSNumber numberWithUnsignedInt:[_drive channelsForTrack:i]] forKey:@"channels"];
		[track setValue:[NSNumber numberWithUnsignedInt:[_drive trackHasPreEmphasis:i]] forKey:@"preEmphasis"];
		[track setValue:[NSNumber numberWithUnsignedInt:[_drive trackAllowsDigitalCopy:i]] forKey:@"copyPermitted"];
		
		[_tracks addObject: track];
		
		discLength += [_drive lastSectorForTrack:i] - [_drive firstSectorForTrack:i] + 1;
	}
	
	// Setup libcddb data structures
	_cddb_disc	= cddb_disc_new();
	if(NULL == _cddb_disc) {
		@throw [MallocException exceptionWithReason:@"Unable to allocate memory" userInfo:nil];
	}
	
	_length = (unsigned) (60 * (discLength / (60 * 75))) + (unsigned)((discLength / 75) % 60);
	cddb_disc_set_length(_cddb_disc, _length);
	for(i = 1; i <= [_drive trackCount]; ++i) {
		cddb_track_t	*cddb_track	= cddb_track_new();
		if(NULL == cddb_track) {
			@throw [MallocException exceptionWithReason:@"Unable to allocate memory" userInfo:nil];
		}
		cddb_track_set_frame_offset(cddb_track, [_drive firstSectorForTrack:i] + 150);
		cddb_disc_add_track(_cddb_disc, cddb_track);
	}
	
	if(0 == cddb_disc_calc_discid(_cddb_disc)) {
		@throw [FreeDBException exceptionWithReason:@"Unable to calculate disc id" userInfo:nil];
	}
	
	
	[self showWindows];
}

- (void) dealloc
{
	[_tracks release];
	[_drive release];
	
	cddb_disc_destroy(_cddb_disc);
	
	[super dealloc];
}

#pragma mark -
#pragma mark NSDocument overrides

- (void) makeWindowControllers
{
	NSLog(@"makeWindowControllers");
	CompactDiscController *controller = [[[CompactDiscController alloc] init] autorelease];
	[self addWindowController:controller];
}

- (void) windowControllerDidLoadNib:(NSWindowController *) controller
{
	NSLog(@"windowControllerDidLoadNib");
    [super windowControllerDidLoadNib:controller];
	
	[controller setWindowFrameAutosaveName:[NSString stringWithFormat: @"Compact Disc 0x%.8x", [self cddb_id]]];
	[[controller window] setRepresentedFilename:[NSString stringWithFormat:@"%@/0x%.8x.xml", getApplicationDataDirectory(), [self cddb_id]]];
}

- (NSData *) dataOfType:(NSString *) typeName error:(NSError **) outError
{	
	NSLog(@"dataOfType");
    return nil;
}

- (BOOL) readFromData:(NSData *) data ofType:(NSString *) typeName error:(NSError **) outError
{    
	NSLog(@"readFromData");
    return YES;
}

#pragma mark -
#pragma mark NSDrawer delegate methods

- (void) drawerDidClose:(NSNotification *)notification
{
	if([notification object] == _trackDrawer) {
		[_trackInfoButton setTitle:@"Show Track Info"];
	}
}

- (void) drawerDidOpen:(NSNotification *)notification
{
	if([notification object] == _trackDrawer) {
		[_trackInfoButton setTitle:@"Hide Track Info"];
	}
}

#pragma mark -
#pragma mark Exception Display

- (void) displayException:(NSException *)exception
{
	NSWindow *window = [self windowForSheet];
	if(nil == window) {
		displayExceptionAlert(exception);
	}
	else {
		displayExceptionSheet(exception, window, self, @selector(alertDidEnd:returnCode:contextInfo:), nil);
	}
}

- (void) alertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	// Nothing for now
}


#pragma mark -
#pragma mark Track Selection

- (NSArray *) selectedTracks
{
	NSMutableArray	*result			= [[NSMutableArray alloc] initWithCapacity:[_drive trackCount]];
	NSEnumerator	*enumerator		= [_tracks objectEnumerator];
	Track			*track;
	
	while((track = [enumerator nextObject])) {
		if([[track valueForKey:@"selected"] boolValue]) {
			[result addObject: track];
		}
	}
	
	return [[result retain] autorelease];
}

- (BOOL) emptySelection
{
	return (0 == [[self selectedTracks] count]);
}

- (IBAction) selectAll:(id) sender
{
	unsigned	i;
	
	for(i = 0; i < [_tracks count]; ++i) {
		if(NO == [[[_tracks objectAtIndex:i] valueForKey:@"ripInProgress"] boolValue]) {
			[[_tracks objectAtIndex:i] setValue:[NSNumber numberWithBool:YES] forKey:@"selected"];
		}
	}
}

- (IBAction) selectNone:(id) sender
{
	unsigned	i;
	
	for(i = 0; i < [_tracks count]; ++i) {
		if(NO == [[[_tracks objectAtIndex:i] valueForKey:@"ripInProgress"] boolValue]) {
			[[_tracks objectAtIndex:i] setValue:[NSNumber numberWithBool:NO] forKey:@"selected"];
		}
	}
}

#pragma mark -

- (IBAction) encode:(id) sender
{
	Track			*track;
	NSArray			*selectedTracks;
	NSEnumerator	*enumerator;
	NSString		*filename;
	NSString		*outputDirectory;
	
	@try {
		// Do nothing for empty selection
		if([self emptySelection]) {
			@throw [EmptySelectionException exceptionWithReason:@"Please select one or more tracks to encode." userInfo:nil];
		}
		
		// Iterate through the selected tracks and rip/encode them
		selectedTracks	= [self selectedTracks];
		enumerator		= [selectedTracks objectEnumerator];
		
		// Create output directory (should exist but could have been deleted/moved)
		outputDirectory = [[[NSUserDefaults standardUserDefaults] stringForKey:@"org.sbooth.Max.outputDirectory"] stringByExpandingTildeInPath];
		validateAndCreateDirectory(outputDirectory);
		
		while((track = [enumerator nextObject])) {
			
			// Use custom naming scheme
			if([[NSUserDefaults standardUserDefaults] boolForKey:@"org.sbooth.Max.useCustomNaming"]) {
				
				NSMutableString		*customPath			= [[NSMutableString alloc] initWithCapacity:100];
				NSString			*customNamingScheme = [[NSUserDefaults standardUserDefaults] stringForKey:@"org.sbooth.Max.customNamingScheme"];
				NSString			*path;
				
				// Get the elements needed to build the pathname
				NSNumber			*discNumber			= _discNumber;
				NSNumber			*discsInSet			= _discsInSet;
				NSString			*discArtist			= _artist;
				NSString			*discTitle			= _title;
				NSString			*discGenre			= _genre;
				NSNumber			*discYear			= _year;
				NSNumber			*trackNumber		= [track valueForKey:@"number"];
				NSString			*trackArtist		= [track valueForKey:@"artist"];
				NSString			*trackTitle			= [track valueForKey:@"title"];
				NSString			*trackGenre			= [track valueForKey:@"genre"];
				NSNumber			*trackYear			= [track valueForKey:@"year"];
				
				// Fallback to disc if specified in preferences
				if([[NSUserDefaults standardUserDefaults] boolForKey:@"org.sbooth.Max.customNamingUseFallback"]) {
					if(nil == trackArtist) {
						trackArtist = discArtist;
					}
					if(nil == trackGenre) {
						trackGenre = discGenre;
					}
					if(nil == trackYear) {
						trackYear = discYear;
					}
				}
				
				if(nil == customNamingScheme) {
					@throw [NSException exceptionWithName:@"NSObjectInaccessibleException" reason:@"Invalid custom naming string." userInfo:nil];
				}
				else {
					[customPath setString:customNamingScheme];
				}
				
				if(nil == discNumber) {
					[customPath replaceOccurrencesOfString:@"{discNumber}" withString:@"" options:nil range:NSMakeRange(0, [customPath length])];
				}
				else {
					[customPath replaceOccurrencesOfString:@"{discNumber}" withString:[discNumber stringValue] options:nil range:NSMakeRange(0, [customPath length])];					
				}
				if(nil == discsInSet) {
					[customPath replaceOccurrencesOfString:@"{discsInSet}" withString:@"" options:nil range:NSMakeRange(0, [customPath length])];
				}
				else {
					[customPath replaceOccurrencesOfString:@"{discsInSet}" withString:[discsInSet stringValue] options:nil range:NSMakeRange(0, [customPath length])];
				}
				if(nil == discArtist) {
					[customPath replaceOccurrencesOfString:@"{discArtist}" withString:@"" options:nil range:NSMakeRange(0, [customPath length])];
				}
				else {
					[customPath replaceOccurrencesOfString:@"{discArtist}" withString:makeStringSafeForFilename(discArtist) options:nil range:NSMakeRange(0, [customPath length])];					
				}
				if(nil == discTitle) {
					[customPath replaceOccurrencesOfString:@"{discTitle}" withString:@"" options:nil range:NSMakeRange(0, [customPath length])];
				}
				else {
					[customPath replaceOccurrencesOfString:@"{discTitle}" withString:makeStringSafeForFilename(discTitle) options:nil range:NSMakeRange(0, [customPath length])];
				}
				if(nil == discGenre) {
					[customPath replaceOccurrencesOfString:@"{discGenre}" withString:@"" options:nil range:NSMakeRange(0, [customPath length])];
				}
				else {
					[customPath replaceOccurrencesOfString:@"{discGenre}" withString:makeStringSafeForFilename(discGenre) options:nil range:NSMakeRange(0, [customPath length])];
				}
				if(nil == discYear) {
					[customPath replaceOccurrencesOfString:@"{discYear}" withString:@"" options:nil range:NSMakeRange(0, [customPath length])];
				}
				else {
					[customPath replaceOccurrencesOfString:@"{discYear}" withString:[discYear stringValue] options:nil range:NSMakeRange(0, [customPath length])];
				}
				if(nil == trackNumber) {
					[customPath replaceOccurrencesOfString:@"{trackNumber}" withString:@"" options:nil range:NSMakeRange(0, [customPath length])];
				}
				else {
					[customPath replaceOccurrencesOfString:@"{trackNumber}" withString:[trackNumber stringValue] options:nil range:NSMakeRange(0, [customPath length])];
				}
				if(nil == trackArtist) {
					[customPath replaceOccurrencesOfString:@"{trackArtist}" withString:@"" options:nil range:NSMakeRange(0, [customPath length])];
				}
				else {
					[customPath replaceOccurrencesOfString:@"{trackArtist}" withString:makeStringSafeForFilename(trackArtist) options:nil range:NSMakeRange(0, [customPath length])];
				}
				if(nil == trackTitle) {
					[customPath replaceOccurrencesOfString:@"{trackTitle}" withString:@"" options:nil range:NSMakeRange(0, [customPath length])];
				}
				else {
					[customPath replaceOccurrencesOfString:@"{trackTitle}" withString:makeStringSafeForFilename(trackTitle) options:nil range:NSMakeRange(0, [customPath length])];
				}
				if(nil == trackGenre) {
					[customPath replaceOccurrencesOfString:@"{trackGenre}" withString:@"" options:nil range:NSMakeRange(0, [customPath length])];
				}
				else {
					[customPath replaceOccurrencesOfString:@"{trackGenre}" withString:makeStringSafeForFilename(trackGenre) options:nil range:NSMakeRange(0, [customPath length])];
				}
				if(nil == trackYear) {
					[customPath replaceOccurrencesOfString:@"{trackYear}" withString:@"" options:nil range:NSMakeRange(0, [customPath length])];
				}
				else {
					[customPath replaceOccurrencesOfString:@"{trackYear}" withString:[trackYear stringValue] options:nil range:NSMakeRange(0, [customPath length])];
				}
				
				// Create the directory structure
				NSArray *pathComponents = [customPath pathComponents];
				
				// pathComponents will always contain at least 1 element since customNamingScheme was not nil
				path = [NSString stringWithFormat:@"%@/%@", outputDirectory, makeStringSafeForFilename([pathComponents objectAtIndex:0])]; 
				
				if(1 < [pathComponents count]) {
					int				i;
					int				directoryCount		= [pathComponents count] - 1;
					
					validateAndCreateDirectory(path);
					for(i = 1; i < directoryCount; ++i) {						
						path = [NSString stringWithFormat:@"%@/%@", path, makeStringSafeForFilename([pathComponents objectAtIndex:i])];
						validateAndCreateDirectory(path);
					}
					
					filename = [NSString stringWithFormat:@"%@/%@", path, makeStringSafeForFilename([pathComponents objectAtIndex:i])];
				}
				else {
					filename = path;
				}
				[customPath release];
				
				filename = [filename stringByAppendingString:@".mp3"];
			}
			// Use standard iTunes-style naming for compilations: "Compilations/Album/DiscNumber-TrackNumber TrackTitle.mp3"
			else if([_multiArtist boolValue]) {
				NSString			*path;
				
				NSString			*discTitle			= _title;
				NSString			*trackTitle			= [track valueForKey:@"title"];
				
				if(nil == discTitle) {
					discTitle = @"Unknown Album";
				}
				if(nil == trackTitle) {
					trackTitle = @"Unknown Track";
				}
				
				// Create the directory structure
				path = [NSString stringWithFormat:@"%@/Compilations", outputDirectory]; 
				validateAndCreateDirectory(path);
				
				path = [NSString stringWithFormat:@"%@/Compilations/%@", outputDirectory, makeStringSafeForFilename(discTitle)]; 
				validateAndCreateDirectory(path);
				
				if(nil == _discNumber) {
					filename = [NSString stringWithFormat:@"%@/%02u %@.mp3", path, [[track valueForKey:@"number"] unsignedIntValue], makeStringSafeForFilename(trackTitle)];
				}
				else {
					filename = [NSString stringWithFormat:@"%@/%i-%02u %@.mp3", path, [_discNumber intValue], [[track valueForKey:@"number"] unsignedIntValue], makeStringSafeForFilename(trackTitle)];
				}
			}
			// Use standard iTunes-style naming: "Artist/Album/DiscNumber-TrackNumber TrackTitle.mp3"
			else {
				NSString			*path;
				
				NSString			*discArtist			= _artist;
				NSString			*trackArtist		= [track valueForKey:@"artist"];
				NSString			*artist;
				NSString			*discTitle			= _title;
				NSString			*trackTitle			= [track valueForKey:@"title"];
				
				artist = trackArtist;
				if(nil == artist) {
					artist = discArtist;
					if(nil == artist) {
						artist = @"Unknown Artist";
					}
				}
				if(nil == discTitle) {
					discTitle = @"Unknown Album";
				}
				if(nil == trackTitle) {
					trackTitle = @"Unknown Track";
				}
				
				// Create the directory structure
				path = [NSString stringWithFormat:@"%@/%@", outputDirectory, makeStringSafeForFilename(artist)]; 
				validateAndCreateDirectory(path);
				
				path = [NSString stringWithFormat:@"%@/%@/%@", outputDirectory, makeStringSafeForFilename(artist), makeStringSafeForFilename(discTitle)]; 
				validateAndCreateDirectory(path);
				
				if(nil == _discNumber) {
					filename = [NSString stringWithFormat:@"%@/%02u %@.mp3", path, [[track valueForKey:@"number"] unsignedIntValue], makeStringSafeForFilename(trackTitle)];
				}
				else {
					filename = [NSString stringWithFormat:@"%@/%i-%02u %@.mp3", path, [_discNumber intValue], [[track valueForKey:@"number"] unsignedIntValue], makeStringSafeForFilename(trackTitle)];
				}
			}
			
			// Check if the output file exists
			if([[NSFileManager defaultManager] fileExistsAtPath:filename]) {
				NSAlert *alert = [[[NSAlert alloc] init] autorelease];
				[alert addButtonWithTitle:@"No"];
				[alert addButtonWithTitle:@"Yes"];
				[alert setMessageText:@"Overwrite existing file?"];
				[alert setInformativeText:[NSString stringWithFormat:@"The file '%@' already exists.  Do you wish to replace it?", filename]];
				[alert setAlertStyle:NSWarningAlertStyle];
				
				if(NSAlertSecondButtonReturn == [alert runModal]) {
					// Remove the file
					if(-1 == unlink([filename UTF8String])) {
						@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to delete output file (%i:%s)", errno, strerror(errno)] userInfo:nil];
					}
					
					// Create and run the task
					Task *task = [[[Task alloc] initWithDisc:self forTrack:track outputFilename:filename] autorelease];
					[[TaskMaster sharedController] runTask:task];
				}
			}
			else {
				// Create and run the task
				Task *task = [[[Task alloc] initWithDisc:self forTrack:track outputFilename:filename] autorelease];
				[[TaskMaster sharedController] runTask:task];
			}
		}
	}
	
	@catch(NSException *exception) {
		[self displayException:exception];
	}
	
	@finally {
		
	}
}

- (IBAction)getCDInformation:(id)sender
{
	FreeDB				*freeDB				= nil;
	NSArray				*matches			= nil;
	FreeDBMatchSheet	*sheet				= nil;
	
	@try {
		freeDB = [[FreeDB alloc] init];
		[freeDB setValue:self forKey:@"disc"];
		
		matches = [freeDB fetchMatches];
		
		if(0 == [matches count]) {
			@throw [FreeDBException exceptionWithReason:@"No matches found for this disc." userInfo:nil];
		}
		else if(1 == [matches count]) {
			[self updateDiscFromFreeDB:[matches objectAtIndex:0]];
		}
		else {
			sheet = [[[FreeDBMatchSheet alloc] init] autorelease];
			[sheet setValue:matches forKey:@"matches"];
			[sheet setValue:self forKey:@"controller"];
			[sheet showFreeDBMatches];
		}
	}
	
	@catch(NSException *exception) {
		[self displayException:exception];
	}
	
	@finally {
		[freeDB release];
	}
}

- (void) updateDiscFromFreeDB:(FreeDBMatch *)info
{
	FreeDB *freeDB;
	
	@try {
		freeDB = [[FreeDB alloc] init];
		[freeDB setValue:self forKey:@"disc"];
		
		[freeDB updateDisc:info];
	}
	
	@catch(NSException *exception) {
		[self displayException:exception];
	}
	
	@finally {
		[freeDB release];		
	}
	
}


#pragma mark -

- (unsigned long)	cddb_id			{ return cddb_disc_get_discid(_cddb_disc); }
- (cddb_disc_t *)	cddb_disc		{ return _cddb_disc; }
- (NSString *)		length			{ return [NSString stringWithFormat:@"%u:%.02u", _length / 60, _length % 60]; }

- (NSArray *) genres
{
	return [Genres sharedGenres];
}

#pragma mark -
#pragma mark Save/Restore

- (NSDictionary *) getDictionary
{
	unsigned				i;
	NSMutableDictionary		*result		= [[[NSMutableDictionary alloc] init] autorelease];
	NSMutableArray			*tracks		= [[[NSMutableArray alloc] initWithCapacity:[_tracks count]] autorelease];
		
	[result setValue:_title forKey:@"title"];
	[result setValue:_artist forKey:@"artist"];
	[result setValue:_year forKey:@"year"];
	[result setValue:_genre forKey:@"genre"];
	[result setValue:_comment forKey:@"comment"];
	[result setValue:_discNumber forKey:@"discNumber"];
	[result setValue:_discsInSet forKey:@"discsInSet"];
	[result setValue:_multiArtist forKey:@"multiArtist"];
	
	for(i = 0; i < [_tracks count]; ++i) {
		[tracks addObject:[[_tracks objectAtIndex:i] getDictionary]];
	}
	
	[result setValue:tracks forKey:@"tracks"];
	
	return result;
}

- (void) setPropertiesFromDictionary:(NSDictionary *) properties
{
	unsigned				i;
	NSArray					*tracks			= [properties valueForKey:@"tracks"];
	
	if([tracks count] != [_tracks count]) {
		@throw [NSException exceptionWithName:@"NSInternalInconsistencyException" reason:@"Track count mismatch" userInfo:nil];
	}

	for(i = 0; i < [tracks count]; ++i) {
		[[_tracks objectAtIndex:i] setPropertiesFromDictionary:[tracks objectAtIndex:i]];
	}
	
	[self setValue:[properties valueForKey:@"title"] forKey:@"title"];
	[self setValue:[properties valueForKey:@"artist"] forKey:@"artist"];
	[self setValue:[properties valueForKey:@"year"] forKey:@"year"];
	[self setValue:[properties valueForKey:@"genre"] forKey:@"genre"];
	[self setValue:[properties valueForKey:@"comment"] forKey:@"comment"];
	[self setValue:[properties valueForKey:@"discNumber"] forKey:@"discNumber"];
	[self setValue:[properties valueForKey:@"discsInSet"] forKey:@"discsInSet"];
	[self setValue:[properties valueForKey:@"multiArtist"] forKey:@"multiArtist"];
}

@end
