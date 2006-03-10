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

#import "CompactDiscDocument.h"

#import "CompactDiscDocumentToolbar.h"
#import "CompactDiscController.h"
#import "Track.h"
#import "AudioMetadata.h"
#import "FreeDB.h"
#import "FreeDBMatchSheet.h"
#import "Genres.h"
#import "TaskMaster.h"
#import "Encoder.h"
#import "MediaController.h"

#import "MallocException.h"
#import "IOException.h"
#import "FreeDBException.h"
#import "EmptySelectionException.h"
#import "MissingResourceException.h"

#import "AmazonAlbumArtSheet.h"
#import "UtilityFunctions.h"

#define kEncodeMenuItemTag					1
#define kTrackInfoMenuItemTag				2
#define kQueryFreeDBMenuItemTag				3
#define kEjectDiscMenuItemTag				4
#define kSubmitToFreeDBMenuItemTag			5
#define kSelectNextTrackMenuItemTag			6
#define kSelectPreviousTrackMenuItemTag		7

@interface CompactDiscDocument (Private)
- (void) updateAlbumArtImageRep;
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
			@throw [MissingResourceException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to load required resource", @"Exceptions", @"")
														userInfo:[NSDictionary dictionaryWithObject:@"CompactDiscDocumentDefaults.plist" forKey:@"filename"]];
		}
		compactDiscDocumentDefaultsValuesDictionary = [NSDictionary dictionaryWithContentsOfFile:compactDiscDocumentDefaultsValuesPath];
		[[NSUserDefaults standardUserDefaults] registerDefaults:compactDiscDocumentDefaultsValuesDictionary];
		
	}
	
	@catch(NSException *exception) {
		displayExceptionAlert(exception);
	}
}

+ (BOOL) accessInstanceVariablesDirectly	{ return NO; }

- (id) init
{
	if((self = [super init])) {

		_disc				= nil;
		_discInDrive		= NO;
		_discID				= 0;
		_freeDBQueryInProgress = NO;
		_freeDBQuerySuccessful = NO;
		
		_title				= nil;
		_artist				= nil;
		_year				= 0;
		_genre				= nil;
		_composer			= nil;
		_comment			= nil;
		_partOfSet			= NO;
		
		_albumArt			= nil;
		_albumArtBitmap		= nil;
		
		_discNumber			= 0;
		_discsInSet			= 0;
		_multiArtist		= NO;
		
		_MCN				= nil;
		
		_tracks				= [[NSMutableArray arrayWithCapacity:20] retain];
		
		return self;
	}
	return nil;
}

- (void) dealloc
{	
	[_disc release];

	[_title release];
	[_artist release];
	[_genre release];
	[_composer release];
	[_comment release];

	[_albumArt release];
	[_albumArtBitmap release];

	[_MCN release];
	
	[_tracks release];
	
	[super dealloc];
}

- (void) awakeFromNib
{
	[_trackTable setAutosaveName:[NSString stringWithFormat: @"Tracks for 0x%.8x", [self discID]]];
	[_trackTable setAutosaveTableColumns:YES];
}

#pragma mark NSDocument overrides

- (BOOL) validateMenuItem:(NSMenuItem *)item
{
	BOOL result;
	
	switch([item tag]) {
		default:								result = [super validateMenuItem:item];			break;
		case kEncodeMenuItemTag:				result = [self encodeAllowed];					break;
		case kQueryFreeDBMenuItemTag:			result = [self queryFreeDBAllowed];				break;
		case kSubmitToFreeDBMenuItemTag:		result = [self submitToFreeDBAllowed];			break;
		case kEjectDiscMenuItemTag:				result = [self ejectDiscAllowed];				break;
		case kSelectNextTrackMenuItemTag:		result = [_trackController canSelectNext];		break;
		case kSelectPreviousTrackMenuItemTag:	result = [_trackController canSelectPrevious];	break;
	}
	
	return result;
}

- (void) makeWindowControllers 
{
	CompactDiscController *controller = [[CompactDiscController alloc] initWithWindowNibName:@"CompactDiscDocument" owner:self];
	[self addObserver:controller forKeyPath:@"title" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:nil];
	[self addWindowController:[controller autorelease]];
}

- (void) windowControllerDidLoadNib:(NSWindowController *)controller
{
	[controller setShouldCascadeWindows:NO];
	[controller setWindowFrameAutosaveName:[NSString stringWithFormat: NSLocalizedStringFromTable(@"Compact Disc 0x%.8x", @"CompactDisc", @""), [self discID]]];
	
	NSToolbar *toolbar = [[[CompactDiscDocumentToolbar alloc] initWithCompactDiscDocument:self] autorelease];
    
    [toolbar setAllowsUserCustomization: YES];
    [toolbar setAutosavesConfiguration: YES];
    [toolbar setDisplayMode: NSToolbarDisplayModeIconAndLabel];
    
    [toolbar setDelegate:toolbar];
	
    [[controller window] setToolbar:toolbar];
}

- (NSData *) dataOfType:(NSString *)typeName error:(NSError **)outError
{
	if([typeName isEqualToString:@"Max CD Information"]) {
		NSData					*data;
		NSString				*error;
		
		data = [NSPropertyListSerialization dataFromPropertyList:[self getDictionary] format:NSPropertyListXMLFormat_v1_0 errorDescription:&error];
		if(nil != data) {
			return data;
		}
		else {
			*outError = [NSError errorWithDomain:NSCocoaErrorDomain code:-1 userInfo:[NSDictionary dictionaryWithObject:[error autorelease] forKey:NSLocalizedFailureReasonErrorKey]];
		}
	}
	return nil;
}

- (BOOL) readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError
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
//	[self updateChangeCount:NSChangeDone];
}

- (NSUndoManager *) windowWillReturnUndoManager:(NSWindow *)sender
{
	return [self undoManager];
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
	return ([self discInDrive] ? [_disc discID] : [_discID intValue]);
}

- (BOOL) discInDrive
{
	return _discInDrive;
}

- (void) discEjected
{
	[self setDisc:nil];
}

- (CompactDisc *) disc
{
	return _disc;
}

- (void) setDisc:(CompactDisc *) disc
{
	unsigned			i;
	
	[_disc release];

	if(nil == disc) {
		[self setValue:[NSNumber numberWithBool:NO] forKey:@"discInDrive"];
		return;
	}
	
	_disc			= [disc retain];

	[self setValue:[NSNumber numberWithBool:YES] forKey:@"discInDrive"];
	
	[self setValue:[_disc MCN] forKey:@"MCN"];
	
	[self willChangeValueForKey:@"tracks"];
	if(0 == [_tracks count]) {
		for(i = 0; i < [_disc trackCount]; ++i) {
			Track *track = [[Track alloc] init];
			[track setValue:self forKey:@"disc"];
			[_tracks addObject:[[track retain] autorelease]];
		}
	}
	[self didChangeValueForKey:@"tracks"];
	
	for(i = 0; i < [_disc trackCount]; ++i) {
		Track			*track		= [_tracks objectAtIndex:i];
		
		[track setValue:[NSNumber numberWithUnsignedInt:i + 1] forKey:@"number"];
		[track setValue:[NSNumber numberWithUnsignedLong:[_disc firstSectorForTrack:i]] forKey:@"firstSector"];
		[track setValue:[NSNumber numberWithUnsignedLong:[_disc lastSectorForTrack:i]] forKey:@"lastSector"];
		
		[track setValue:[NSNumber numberWithUnsignedInt:[_disc channelsForTrack:i]] forKey:@"channels"];
		[track setValue:[NSNumber numberWithUnsignedInt:[_disc trackHasPreEmphasis:i]] forKey:@"preEmphasis"];
		[track setValue:[NSNumber numberWithUnsignedInt:[_disc trackAllowsDigitalCopy:i]] forKey:@"copyPermitted"];
		[track setValue:[_disc ISRC:i] forKey:@"ISRC"];
	}
}

#pragma mark Track information

- (BOOL) ripInProgress
{
	NSEnumerator	*enumerator		= [_tracks objectEnumerator];
	Track			*track;
	
	while((track = [enumerator nextObject])) {
		if([[track valueForKey:@"ripInProgress"] boolValue]) {
			return YES;
		}
	}
	
	return NO;
}

- (BOOL) encodeInProgress
{
	NSEnumerator	*enumerator		= [_tracks objectEnumerator];
	Track			*track;
	
	while((track = [enumerator nextObject])) {
		if([[track valueForKey:@"encodeInProgress"] boolValue]) {
			return YES;
		}
	}
	
	return NO;
}

- (NSArray *)	tracks					{ return _tracks; }

- (NSArray *) selectedTracks
{
	NSMutableArray	*result			= [NSMutableArray arrayWithCapacity:[_disc trackCount]];
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
		if(NO == [[[_tracks objectAtIndex:i] valueForKey:@"ripInProgress"] boolValue] && NO == [[[_tracks objectAtIndex:i] valueForKey:@"encodeInProgress"] boolValue]) {
			[[_tracks objectAtIndex:i] setValue:[NSNumber numberWithBool:YES] forKey:@"selected"];
		}
	}
}

- (IBAction) selectNone:(id) sender
{
	unsigned	i;
	
	for(i = 0; i < [_tracks count]; ++i) {
		if(NO == [[[_tracks objectAtIndex:i] valueForKey:@"ripInProgress"] boolValue] && NO == [[[_tracks objectAtIndex:i] valueForKey:@"encodeInProgress"] boolValue]) {
			[[_tracks objectAtIndex:i] setValue:[NSNumber numberWithBool:NO] forKey:@"selected"];
		}
	}
}

#pragma mark State

- (BOOL) encodeAllowed
{
	return ([self discInDrive] && (NO == [self emptySelection]) && (NO == [self ripInProgress]) && (NO == [self encodeInProgress]));
}

- (BOOL) queryFreeDBAllowed
{
	return [self discInDrive];
}

- (BOOL) submitToFreeDBAllowed
{
	NSEnumerator	*enumerator				= [_tracks objectEnumerator];
	Track			*track;
	BOOL			trackTitlesValid		= YES;
	
	while((track = [enumerator nextObject])) {
		if(nil == [track valueForKey:@"title"]) {
			trackTitlesValid = NO;
			break;
		}
	}
	
	return ([self discInDrive] && (nil != _title) && (nil != _artist) && (nil != _genre) && trackTitlesValid);
}

- (BOOL) ejectDiscAllowed
{
	return [self discInDrive];	
}

#pragma mark Actions

- (IBAction) encode:(id) sender
{
	Track			*track;
	NSArray			*selectedTracks;
	NSEnumerator	*enumerator;
	
	@try {
		// Do nothing if the disc isn't in the drive, the selection is empty, or a rip/encode is in progress
		if(NO == [self discInDrive]) {
			return;
		}
		else if([self emptySelection]) {
			@throw [EmptySelectionException exceptionWithReason:NSLocalizedStringFromTable(@"Please select one or more tracks to encode", @"Exceptions", @"") userInfo:nil];
		}
		else if([self ripInProgress] || [self encodeInProgress]) {
			@throw [NSException exceptionWithName:@"ActiveTaskException" reason:NSLocalizedStringFromTable(@"A rip or encode operation is already in progress", @"Exceptions", @"") userInfo:nil];
		}
		
		// Iterate through the selected tracks and rip/encode them
		selectedTracks	= [self selectedTracks];
		
		// Create one single file for more than one track
		if([[NSUserDefaults standardUserDefaults] boolForKey:@"singleFileOutput"] && 1 < [selectedTracks count]) {
			
			AudioMetadata *metadata = [[selectedTracks objectAtIndex:0] metadata];
			
			[metadata setValue:[NSNumber numberWithInt:0] forKey:@"trackNumber"];
			[metadata setValue:NSLocalizedStringFromTable(@"Multiple Tracks", @"CompactDisc", @"") forKey:@"trackTitle"];
			[metadata setValue:nil forKey:@"trackArtist"];
			[metadata setValue:nil forKey:@"trackGenre"];
			[metadata setValue:nil forKey:@"trackYear"];
						
			[[TaskMaster sharedController] encodeTracks:selectedTracks metadata:metadata];
		}
		// Create one file per track
		else {			
			enumerator		= [selectedTracks objectEnumerator];
			
			while((track = [enumerator nextObject])) {
				[[TaskMaster sharedController] encodeTrack:track];
			}
		}
	}
	
	@catch(NSException *exception) {
		[self displayException:exception];
	}
}

- (IBAction) ejectDisc:(id) sender
{
	if(NO == [self discInDrive]) {
		return;
	}
	
	if([self ripInProgress]) {
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert addButtonWithTitle:NSLocalizedStringFromTable(@"OK", @"General", @"")];
		[alert addButtonWithTitle:NSLocalizedStringFromTable(@"Cancel", @"General", @"")];
		[alert setMessageText:NSLocalizedStringFromTable(@"Really eject the disc?", @"CompactDisc", @"")];
		[alert setInformativeText:NSLocalizedStringFromTable(@"There are active ripping tasks", @"CompactDisc", @"")];
		[alert setAlertStyle:NSWarningAlertStyle];
		
		if(NSAlertSecondButtonReturn == [alert runModal]) {
			return;
		}
		// Stop all associated rip tasks
		else {
			[[TaskMaster sharedController] stopRippingTasksForCompactDiscDocument:self];
		}
	}
	
	[[MediaController sharedController] ejectDiscForCompactDiscDocument:self];
}

- (IBAction) selectNextTrack:(id) sender
{
	[_trackController selectNext:sender];
}

- (IBAction) selectPreviousTrack:(id) sender
{
	[_trackController selectPrevious:sender];	
}

- (IBAction) selectAlbumArt:(id) sender
{
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	
	[panel setAllowsMultipleSelection:NO];
	[panel setCanChooseDirectories:NO];
	[panel setCanChooseFiles:YES];
	
	[panel beginSheetForDirectory:nil file:nil types:[NSImage imageFileTypes] modalForWindow:[self windowForSheet] modalDelegate:self didEndSelector:@selector(openPanelDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

- (void) openPanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    if(NSOKButton == returnCode) {
		NSArray		*filesToOpen	= [sheet filenames];
		int			count			= [filesToOpen count];
		int			i;
		NSImage		*image			= nil;
		
		for(i = 0; i < count; ++i) {
			image = [[NSImage alloc] initWithContentsOfFile:[filesToOpen objectAtIndex:i]];
			if(nil != image) {
				[self setValue:[image autorelease] forKey:@"albumArt"];
				[self albumArtUpdated:self];
			}
		}
	}	
}

- (IBAction) albumArtUpdated:(id) sender
{
	[self updateChangeCount:NSChangeDone];
	[self updateAlbumArtImageRep];
}

- (void) updateAlbumArtImageRep
{
	NSEnumerator		*enumerator;
	NSImageRep			*currentRepresentation		= nil;
	NSBitmapImageRep	*bitmapRep					= nil;
	
	if(nil == _albumArt) {
		[self setValue:nil forKey:@"albumArtBitmap"];
		return;
	}
	
	enumerator = [[_albumArt representations] objectEnumerator];
	while((currentRepresentation = [enumerator nextObject])) {
		if([currentRepresentation isKindOfClass:[NSBitmapImageRep class]]) {
			bitmapRep = (NSBitmapImageRep *)currentRepresentation;
			break;
		}
	}
	
	// Create a bitmap representation if one doesn't exist
	if(nil == bitmapRep) {
		NSSize size = [_albumArt size];
		[_albumArt lockFocus];
		bitmapRep = [[[NSBitmapImageRep alloc] initWithFocusedViewRect:NSMakeRect(0, 0, size.width, size.height)] autorelease];
		[_albumArt unlockFocus];
	}
	
	[self setValue:bitmapRep forKey:@"albumArtBitmap"];
}

- (IBAction) fetchAlbumArt:(id) sender
{	
	AmazonAlbumArtSheet *art = [[[AmazonAlbumArtSheet alloc] initWithCompactDiscDocument:self] autorelease];
	[art showAlbumArtMatches];
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

- (IBAction) queryFreeDB:(id)sender
{
	FreeDB				*freeDB				= nil;
	NSArray				*matches			= nil;
	FreeDBMatchSheet	*sheet				= nil;
	
	if(NO == [self queryFreeDBAllowed]) {
		return;
	}

	@try {
		[self setValue:[NSNumber numberWithBool:YES] forKey:@"freeDBQueryInProgress"];
		[self setValue:[NSNumber numberWithBool:NO] forKey:@"freeDBQuerySuccessful"];

		freeDB = [[FreeDB alloc] initWithCompactDiscDocument:self];
		
		matches = [freeDB fetchMatches];
		
		if(0 == [matches count]) {
			@throw [FreeDBException exceptionWithReason:NSLocalizedStringFromTable(@"No matches found for this disc", @"Exceptions", @"") userInfo:nil];
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
		[self setValue:[NSNumber numberWithBool:NO] forKey:@"freeDBQueryInProgress"];
		[self displayException:exception];
	}
	
	@finally {
		[freeDB release];
	}
}

- (IBAction) submitToFreeDB:(id) sender
{
	FreeDB				*freeDB				= nil;
	
	if(NO == [self submitToFreeDBAllowed]) {
		return;
	}

	@try {
		freeDB = [[FreeDB alloc] initWithCompactDiscDocument:self];		
		[freeDB submitDisc];
	}
	
	@catch(NSException *exception) {
		[self displayException:exception];
	}
	
	@finally {
		[freeDB release];
	}
}

- (void) updateDiscFromFreeDB:(NSDictionary *)info
{
	FreeDB *freeDB;
	
	@try {
		freeDB = [[FreeDB alloc] initWithCompactDiscDocument:self];
	
		[self updateChangeCount:NSChangeReadOtherContents];
		[self clearFreeDBData];
		
		[freeDB updateDisc:info];
		
		[self setValue:[NSNumber numberWithBool:YES] forKey:@"freeDBQuerySuccessful"];
	}
	
	@catch(NSException *exception) {
		[self displayException:exception];
	}
	
	@finally {
		[self setValue:[NSNumber numberWithBool:NO] forKey:@"freeDBQueryInProgress"];
		[freeDB release];		
	}
	
}

#pragma mark Miscellaneous

- (IBAction) toggleTrackInformation:(id) sender
{
	[_trackDrawer toggle:sender];
}

- (IBAction) toggleAlbumArt:(id) sender
{
	[_artDrawer toggle:sender];
}

- (NSString *)		length			{ return [NSString stringWithFormat:@"%u:%.02u", [_disc length] / 60, [_disc length] % 60]; }

- (NSArray *) genres
{
	return [Genres sharedGenres];
}

#pragma mark Save/Restore

- (NSDictionary *) getDictionary
{
	unsigned				i;
	NSMutableDictionary		*result					= [[NSMutableDictionary alloc] init];
	NSMutableArray			*tracks					= [NSMutableArray arrayWithCapacity:[_tracks count]];
	NSData					*data					= nil;
	
	[result setValue:_title forKey:@"title"];
	[result setValue:_artist forKey:@"artist"];
	[result setValue:_year forKey:@"year"];
	[result setValue:_genre forKey:@"genre"];
	[result setValue:_composer forKey:@"composer"];
	[result setValue:_comment forKey:@"comment"];
	[result setValue:_discNumber forKey:@"discNumber"];
	[result setValue:_discsInSet forKey:@"discsInSet"];
	[result setValue:_multiArtist forKey:@"multiArtist"];				
	[result setValue:_MCN forKey:@"MCN"];
	[result setValue:[NSNumber numberWithInt:[self discID]] forKey:@"discID"];

	data = [_albumArtBitmap representationUsingType:NSPNGFileType properties:nil]; 
	[result setValue:data forKey:@"albumArt"];
	
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
	NSImage					*image			= nil;
	
	if([self discInDrive] && [tracks count] != [_tracks count]) {
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
	
	[_title release];
	[_artist release];
	[_year release];
	[_genre release];
	[_composer release];
	[_comment release];
	[_discNumber release];
	[_discsInSet release];
	[_multiArtist release];
	[_MCN release];

	_title			= [[properties valueForKey:@"title"] retain];
	_artist			= [[properties valueForKey:@"artist"] retain];
	_year			= [[properties valueForKey:@"year"] retain];
	_genre			= [[properties valueForKey:@"genre"] retain];
	_composer		= [[properties valueForKey:@"composer"] retain];
	_comment		= [[properties valueForKey:@"comment"] retain];
	_discNumber		= [[properties valueForKey:@"discNumber"] retain];
	_discsInSet		= [[properties valueForKey:@"discsInSet"] retain];
	_multiArtist	= [[properties valueForKey:@"multiArtist"] retain];	
	_MCN			= [[properties valueForKey:@"MCN"] retain];
	
	[self setValue:[properties valueForKey:@"discID"] forKey:@"discID"];	
	
	// Convert PNG data to an NSImage
	image = [[NSImage alloc] initWithData:[properties valueForKey:@"albumArt"]];
	[self setValue:(nil != image ? [image autorelease] : nil) forKey:@"albumArt"];
	[self updateAlbumArtImageRep];
}

#pragma mark Accessors

- (NSString *)	title								{ return _title; }
- (NSString *)	artist								{ return _artist; }
- (unsigned)	year								{ return _year; }
- (NSString *)	genre								{ return _genre; }
- (NSString *)	composer							{ return _composer; }
- (NSString *)	comment								{ return _comment; }
- (BOOL)		partOfSet							{ return _partOfSet; }
- (unsigned)	discNumber							{ return _discNumber; }
- (unsigned)	discsInSet							{ return _discsInSet; }
- (BOOL)		multiArtist							{ return _multiArtist; }
- (NSString *)	MCN									{ return _MCN; }

#pragma mark Mutators

- (void) setTitle:(NSString *)title
{
	if(NO == [_title isEqualToString:title]) {
		[[self undoManager] registerUndoWithTarget:self selector:@selector(setTitle:) object:_title];
		[[self undoManager] setActionName:@"Album Title"];
		[_title release];
		_title = [title retain];
	}
}

- (void) setArtist:(NSString *)artist
{
	if(NO == [_artist isEqualToString:artist]) {
		[[self undoManager] registerUndoWithTarget:self selector:@selector(setArtist:) object:_artist];
		[[self undoManager] setActionName:@"Album Artist"];
		[_artist release];
		_artist = [artist retain];
	}
}

- (void) setYear:(unsigned)year
{
	if(_year != year) {
		[[self undoManager] registerUndoWithTarget:self selector:@selector(setYear:) object:_year];
		[[self undoManager] setActionName:@"Album Year"];
		_year = year;
	}
}

- (void) setGenre:(NSString *)genre
{
	if(NO == [_genre isEqualToString:genre]) {
		[[self undoManager] registerUndoWithTarget:self selector:@selector(setGenre:) object:_genre];
		[[self undoManager] setActionName:@"Album Genre"];
		[_genre release];
		_genre = [genre retain];
	}
}

- (void) setComposer:(NSString *)composer
{
	if(NO == [_composer isEqualToString:composer]) {
		[[self undoManager] registerUndoWithTarget:self selector:@selector(setComposer:) object:_composer];
		[[self undoManager] setActionName:@"Album Composer"];
		[_composer release];
		_composer = [composer retain];
	}
}

- (void) setComment:(NSString *)comment
{
	if(NO == [_comment isEqualToString:comment]) {
		[[self undoManager] registerUndoWithTarget:self selector:@selector(setComment:) object:_comment];
		[[self undoManager] setActionName:@"Album Comment"];
		[_comment release];
		_comment = [comment retain];
	}
}

- (void) setPartOfSet:(BOOL)partOfSet
{
	if(_partOfSet != partOfSet) {
		[[self undoManager] registerUndoWithTarget:self selector:@selector(setPartOfSet:) object:_partOfSet];
		[[self undoManager] setActionName:@"Album partOfSet"];
		_partOfSet = partOfSet retain;
	}
}

- (void) setDiscNumber:(unsigned)discNumber
{
	if(_discNumber != discNumber) {
		[[self undoManager] registerUndoWithTarget:self selector:@selector(setDiscNumber:) object:_discNumber];
		[[self undoManager] setActionName:@"Total Discs"];
		_discNumber = discNumber;
	}
}

- (void) setDiscsInSet:(unsigned)discsInSet
{
	if(_discsInSet != discsInSet) {
		[[self undoManager] registerUndoWithTarget:self selector:@selector(setDiscsInSet:) object:_discsInSet];
		[[self undoManager] setActionName:@"Total Discs"];
		_discsInSet = discsInSet;
	}
}

- (void) setMultiArtist:(BOOL)multiArtist
{
	if(_multiArtist != multiArtist) {
		[[self undoManager] registerUndoWithTarget:self selector:@selector(setMultiArtist:) object:_multiArtist];
		[[self undoManager] setActionName:@"Compilation"];
		_multiArtist = multiArtist;
	}
}

- (void) setMCN:(NSString *)MCN
{
	if(NO == [_MCN isEqualToString:MCN]) {
		[[self undoManager] registerUndoWithTarget:self selector:@selector(setMCN:) object:_MCN];
		[[self undoManager] setActionName:@"Album MCN"];
		[_MCN release];
		_MCN = [MCN retain];
	}
}

@end
