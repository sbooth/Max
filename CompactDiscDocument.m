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

#import "CompactDiscDocument.h"

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


@interface CompactDiscDocument (Private)
- (NSString *) basenameForTrack:(Track *)track;
@end

@implementation CompactDiscDocument

+ (void) initialize
{
	NSString				*compactDiscDocumentDefaultsValuesPath;
    NSDictionary			*compactDiscDocumentDefaultsValuesDictionary;
	
	@try {
		// Set up defaults
		compactDiscDocumentDefaultsValuesPath = [[NSBundle mainBundle] pathForResource:@"CompactDiscDocumentDefaults" ofType:@"plist"];
		if(nil == compactDiscDocumentDefaultsValuesPath) {
			@throw [MissingResourceException exceptionWithReason:@"Unable to load CompactDiscDocumentDefaults.plist" userInfo:nil];
		}
		compactDiscDocumentDefaultsValuesDictionary = [NSDictionary dictionaryWithContentsOfFile:compactDiscDocumentDefaultsValuesPath];
		[[NSUserDefaults standardUserDefaults] registerDefaults:compactDiscDocumentDefaultsValuesDictionary];
		
	}
	@catch(NSException *exception) {
		displayExceptionAlert(exception);
	}
	@finally {
	}	
}

- (id) init
{
	if((self = [super init])) {
		_tracks			= [[NSMutableArray alloc] initWithCapacity:20];
		_discInDrive	= NO;
		_disc			= nil;
		
		return self;
	}
	return nil;
}

- (void) dealloc
{	
	[_tracks removeAllObjects];
	[_tracks release];
	
	if(nil != _disc) {
		[_disc release];
	}
	
	[super dealloc];
}

#pragma mark NSDocument overrides

- (void) makeWindowControllers 
{
	CompactDiscController *controller = [[CompactDiscController alloc] initWithWindowNibName:@"CompactDiscDocument" owner:self];
	[self addObserver:controller forKeyPath:@"title" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:nil];
	[self addWindowController:[controller autorelease]];
}

- (void) windowControllerDidLoadNib:(NSWindowController *)controller
{
	[controller setShouldCascadeWindows:NO];
	[controller setWindowFrameAutosaveName:[NSString stringWithFormat: @"Compact Disc 0x%.8x", [self discID]]];
}

- (NSData *) dataOfType:(NSString *) typeName error:(NSError **) outError
{
	if([typeName isEqualToString:@"Max CD Information"]) {
		NSData					*data;
		NSString				*error;
		
		data = [NSPropertyListSerialization dataFromPropertyList:[self getDictionary] format:NSPropertyListXMLFormat_v1_0 errorDescription:&error];
		if(nil != data) {
			return data;
		}
		else {
			[error release];
		}
	}
	return nil;
}

- (BOOL) readFromData:(NSData *) data 
			   ofType:(NSString *) typeName 
				error:(NSError **) outError
{    
	if([typeName isEqualToString:@"Max CD Information"]) {
		NSDictionary			*dictionary;
		NSPropertyListFormat	format;
		NSString				*error;
		
		dictionary = [NSPropertyListSerialization propertyListFromData:data mutabilityOption:NSPropertyListImmutable format:&format errorDescription:&error];
		if(nil != dictionary) {
			[self setPropertiesFromDictionary:dictionary];
		}
		else {
			[error release];
		}
		return YES;
	}
    return NO;
}

#pragma mark Delegate methods

- (void) windowWillClose:(NSNotification *)notification
{
	NSArray *controllers = [self windowControllers];
	if(0 != [controllers count]) {
		[self removeObserver:[controllers objectAtIndex:0] forKeyPath:@"title"];
	}
}

- (void) controlTextDidEndEditing:(NSNotification *)notification
{
	[self updateChangeCount:NSChangeDone];
}

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

#pragma mark Disc Management

- (int) discID
{
	if([self discInDrive]) {
		return [_disc discID];
	}
	else {
		return [_discID intValue];
	}
}

- (BOOL) discInDrive
{
	return [_discInDrive boolValue];
}

- (void) discEjected
{
	[self setDisc:nil];
}

- (CompactDisc *) getDisc
{
	return _disc;
}

- (void) setDisc:(CompactDisc *) disc
{
	unsigned			i;
	
	if(nil != _disc) {
		[_disc release];
		_disc = nil;
	}

	if(nil == disc) {
		[self setValue:[NSNumber numberWithBool:NO] forKey:@"discInDrive"];
		return;
	}
	
	_disc			= [disc retain];

	[self setValue:[NSNumber numberWithBool:YES] forKey:@"discInDrive"];
	
	[self willChangeValueForKey:@"tracks"];
	if(0 == [_tracks count]) {
		for(i = 0; i < [_disc trackCount]; ++i) {
			Track *track = [[Track alloc] init];
			[track setValue:self forKey:@"disc"];
			[_tracks addObject:[[track retain] autorelease]];
		}
	}
	[self didChangeValueForKey:@"tracks"];
	
	for(i = 1; i <= [_disc trackCount]; ++i) {
		Track			*track		= [_tracks objectAtIndex:i - 1];
		
		[track setValue:[NSNumber numberWithUnsignedInt:i] forKey:@"number"];
		[track setValue:[NSNumber numberWithUnsignedLong:[_disc firstSectorForTrack:i]] forKey:@"firstSector"];
		[track setValue:[NSNumber numberWithUnsignedLong:[_disc lastSectorForTrack:i]] forKey:@"lastSector"];
		
		[track setValue:[NSNumber numberWithUnsignedInt:[_disc channelsForTrack:i]] forKey:@"channels"];
		[track setValue:[NSNumber numberWithUnsignedInt:[_disc trackHasPreEmphasis:i]] forKey:@"preEmphasis"];
		[track setValue:[NSNumber numberWithUnsignedInt:[_disc trackAllowsDigitalCopy:i]] forKey:@"copyPermitted"];
	}
}

#pragma mark Track selection

- (NSArray *) selectedTracks
{
	NSMutableArray	*result			= [[NSMutableArray alloc] initWithCapacity:[_disc trackCount]];
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

#pragma mark Actions

- (NSString *) basenameForTrack:(Track *)track
{
	NSString		*basename;
	NSString		*outputDirectory;

	
	// Create output directory (should exist but could have been deleted/moved)
	outputDirectory = [[[NSUserDefaults standardUserDefaults] stringForKey:@"outputDirectory"] stringByExpandingTildeInPath];
	
	// Use custom naming scheme
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"useCustomNaming"]) {
		
		NSMutableString		*customPath			= [[NSMutableString alloc] initWithCapacity:100];
		NSString			*customNamingScheme = [[NSUserDefaults standardUserDefaults] stringForKey:@"customNamingScheme"];
		
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
		if([[NSUserDefaults standardUserDefaults] boolForKey:@"customNamingUseFallback"]) {
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
			[customPath replaceOccurrencesOfString:@"{discArtist}" withString:@"Unknown Artist" options:nil range:NSMakeRange(0, [customPath length])];
		}
		else {
			[customPath replaceOccurrencesOfString:@"{discArtist}" withString:makeStringSafeForFilename(discArtist) options:nil range:NSMakeRange(0, [customPath length])];					
		}
		if(nil == discTitle) {
			[customPath replaceOccurrencesOfString:@"{discTitle}" withString:@"Unknown Disc" options:nil range:NSMakeRange(0, [customPath length])];
		}
		else {
			[customPath replaceOccurrencesOfString:@"{discTitle}" withString:makeStringSafeForFilename(discTitle) options:nil range:NSMakeRange(0, [customPath length])];
		}
		if(nil == discGenre) {
			[customPath replaceOccurrencesOfString:@"{discGenre}" withString:@"Unknown Genre" options:nil range:NSMakeRange(0, [customPath length])];
		}
		else {
			[customPath replaceOccurrencesOfString:@"{discGenre}" withString:makeStringSafeForFilename(discGenre) options:nil range:NSMakeRange(0, [customPath length])];
		}
		if(nil == discYear) {
			[customPath replaceOccurrencesOfString:@"{discYear}" withString:@"Unknown Year" options:nil range:NSMakeRange(0, [customPath length])];
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
			[customPath replaceOccurrencesOfString:@"{trackArtist}" withString:@"Unknown Artist" options:nil range:NSMakeRange(0, [customPath length])];
		}
		else {
			[customPath replaceOccurrencesOfString:@"{trackArtist}" withString:makeStringSafeForFilename(trackArtist) options:nil range:NSMakeRange(0, [customPath length])];
		}
		if(nil == trackTitle) {
			[customPath replaceOccurrencesOfString:@"{trackTitle}" withString:@"Unknown Track" options:nil range:NSMakeRange(0, [customPath length])];
		}
		else {
			[customPath replaceOccurrencesOfString:@"{trackTitle}" withString:makeStringSafeForFilename(trackTitle) options:nil range:NSMakeRange(0, [customPath length])];
		}
		if(nil == trackGenre) {
			[customPath replaceOccurrencesOfString:@"{trackGenre}" withString:@"Unknown Genre" options:nil range:NSMakeRange(0, [customPath length])];
		}
		else {
			[customPath replaceOccurrencesOfString:@"{trackGenre}" withString:makeStringSafeForFilename(trackGenre) options:nil range:NSMakeRange(0, [customPath length])];
		}
		if(nil == trackYear) {
			[customPath replaceOccurrencesOfString:@"{trackYear}" withString:@"Unknown Year" options:nil range:NSMakeRange(0, [customPath length])];
		}
		else {
			[customPath replaceOccurrencesOfString:@"{trackYear}" withString:[trackYear stringValue] options:nil range:NSMakeRange(0, [customPath length])];
		}
		
		basename = [NSString stringWithFormat:@"%@/%@", outputDirectory, customPath];
		[customPath release];
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
		
		path = [NSString stringWithFormat:@"%@/Compilations/%@", outputDirectory, makeStringSafeForFilename(discTitle)]; 

		if(nil == _discNumber) {
			basename = [NSString stringWithFormat:@"%@/%02u %@", path, [[track valueForKey:@"number"] unsignedIntValue], makeStringSafeForFilename(trackTitle)];
		}
		else {
			basename = [NSString stringWithFormat:@"%@/%i-%02u %@", path, [_discNumber intValue], [[track valueForKey:@"number"] unsignedIntValue], makeStringSafeForFilename(trackTitle)];
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
				
		path = [NSString stringWithFormat:@"%@/%@/%@", outputDirectory, makeStringSafeForFilename(artist), makeStringSafeForFilename(discTitle)]; 
		
		if(nil == _discNumber) {
			basename = [NSString stringWithFormat:@"%@/%02u %@", path, [[track valueForKey:@"number"] unsignedIntValue], makeStringSafeForFilename(trackTitle)];
		}
		else {
			basename = [NSString stringWithFormat:@"%@/%i-%02u %@", path, [_discNumber intValue], [[track valueForKey:@"number"] unsignedIntValue], makeStringSafeForFilename(trackTitle)];
		}
	}
	
	return basename;
}

- (IBAction) encode:(id) sender
{
	Track			*track;
	NSArray			*selectedTracks;
	NSEnumerator	*enumerator;
	NSString		*basename;
	NSString		*filename;
	
	@try {
		// Do nothing for empty selection
		if([self emptySelection]) {
			@throw [EmptySelectionException exceptionWithReason:@"Please select one or more tracks to encode." userInfo:nil];
		}
		
		// Iterate through the selected tracks and rip/encode them
		selectedTracks	= [self selectedTracks];
		enumerator		= [selectedTracks objectEnumerator];
		
		while((track = [enumerator nextObject])) {
			
			basename = [self basenameForTrack:track];			
			createDirectoryStructure(basename);
			
			[[TaskMaster sharedController] encodeTrack:track outputBasename:basename];
		}
	}
	
	@catch(NSException *exception) {
		[self displayException:exception];
	}
	
	@finally {
		
	}
}

#pragma mark FreeDB Functionality

- (void) clearFreeDBData
{
	unsigned i;
	
	[self setValue:nil forKey:@"title"];
	[self setValue:nil forKey:@"artist"];
	[self setValue:nil forKey:@"year"];
	[self setValue:nil forKey:@"genre"];
	[self setValue:nil forKey:@"comment"];
	[self setValue:nil forKey:@"discNumber"];
	[self setValue:nil forKey:@"discsInSet"];
	[self setValue:[NSNumber numberWithBool:NO] forKey:@"multiArtist"];
	
	for(i = 0; i < [_tracks count]; ++i) {
		[[_tracks objectAtIndex:i] clearFreeDBData];
	}
}

- (IBAction)getCDInformation:(id)sender
{
	FreeDB				*freeDB				= nil;
	NSArray				*matches			= nil;
	FreeDBMatchSheet	*sheet				= nil;
	
	@try {
		freeDB = [[FreeDB alloc] initWithCompactDiscDocument:self];
		
		matches = [freeDB fetchMatches];
		
		if(0 == [matches count]) {
			@throw [FreeDBException exceptionWithReason:@"No matches found for this disc." userInfo:nil];
		}
		else if(1 == [matches count]) {
			[self updateDiscFromFreeDB:[matches objectAtIndex:0]];
		}
		else {
			sheet = [[[FreeDBMatchSheet alloc] initWithCompactDiscDocument:self] autorelease];
			[sheet setValue:matches forKey:@"matches"];
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
		freeDB = [[FreeDB alloc] initWithCompactDiscDocument:self];
	
		[self updateChangeCount:NSChangeReadOtherContents];
		[self clearFreeDBData];
		
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

- (NSString *)		length			{ return [NSString stringWithFormat:@"%u:%.02u", [_disc length] / 60, [_disc length] % 60]; }

- (NSArray *) genres
{
	return [Genres sharedGenres];
}

#pragma mark Save/Restore

- (NSDictionary *) getDictionary
{
	unsigned				i;
	NSMutableDictionary		*result		= [[NSMutableDictionary alloc] init];
	NSMutableArray			*tracks		= [[[NSMutableArray alloc] initWithCapacity:[_tracks count]] autorelease];
		
	[result setValue:_title forKey:@"title"];
	[result setValue:_artist forKey:@"artist"];
	[result setValue:_year forKey:@"year"];
	[result setValue:_genre forKey:@"genre"];
	[result setValue:_comment forKey:@"comment"];
	[result setValue:_discNumber forKey:@"discNumber"];
	[result setValue:_discsInSet forKey:@"discsInSet"];
	[result setValue:_multiArtist forKey:@"multiArtist"];
	[result setValue:[NSNumber numberWithInt:[self discID]] forKey:@"discID"];
	
	for(i = 0; i < [_tracks count]; ++i) {
		[tracks addObject:[[_tracks objectAtIndex:i] getDictionary]];
	}
	
	[result setValue:tracks forKey:@"tracks"];
	
	return [[result retain] autorelease];
}

- (void) setPropertiesFromDictionary:(NSDictionary *) properties
{
	unsigned				i;
	NSArray					*tracks			= [properties valueForKey:@"tracks"];
	
	if(_discInDrive && [tracks count] != [_tracks count]) {
		@throw [NSException exceptionWithName:@"NSInternalInconsistencyException" reason:@"Track count mismatch" userInfo:nil];
	}
	else if(0 == [_tracks count]) {
		[self willChangeValueForKey:@"tracks"];
		for(i = 0; i < [tracks count]; ++i) {
			Track *track = [[Track alloc] init];
			[track setValue:self forKey:@"disc"];
			[_tracks addObject:[[track retain] autorelease]];
		}
		[self didChangeValueForKey:@"tracks"];
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
	[self setValue:[properties valueForKey:@"discID"] forKey:@"discID"];
}

@end
