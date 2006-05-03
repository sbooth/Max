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
#import "RipperController.h"
#import "Encoder.h"
#import "MediaController.h"
#import "GetPlaylistNameSheet.h"

#import "MallocException.h"
#import "IOException.h"
#import "FreeDBException.h"
#import "EmptySelectionException.h"
#import "MissingResourceException.h"

#import "AmazonAlbumArtSheet.h"
#import "UtilityFunctions.h"

enum {
	kEncodeMenuItemTag					= 1,
	kTrackInfoMenuItemTag				= 2,
	kQueryFreeDBMenuItemTag				= 3,
	kEjectDiscMenuItemTag				= 4,
	kSubmitToFreeDBMenuItemTag			= 5,
	kSelectNextTrackMenuItemTag			= 6,
	kSelectPreviousTrackMenuItemTag		= 7
};

@interface CompactDiscDocument (Private)
- (void)			setPropertiesFromDictionary:(NSDictionary *)properties;
- (void)			updateAlbumArtImageRep;
- (void)			displayExceptionAlert:(NSAlert *)alert;
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
			@throw [MissingResourceException exceptionWithReason:NSLocalizedStringFromTable(@"Your installation of Max appears to be incomplete.", @"Exceptions", @"")
														userInfo:[NSDictionary dictionaryWithObject:@"CompactDiscDocumentDefaults.plist" forKey:@"filename"]];
		}
		compactDiscDocumentDefaultsValuesDictionary = [NSDictionary dictionaryWithContentsOfFile:compactDiscDocumentDefaultsValuesPath];
		[[NSUserDefaults standardUserDefaults] registerDefaults:compactDiscDocumentDefaultsValuesDictionary];
	
		[self setKeys:[NSArray arrayWithObject:@"albumArt"] triggerChangeNotificationsForDependentKey:@"albumArtWidth"];
		[self setKeys:[NSArray arrayWithObject:@"albumArt"] triggerChangeNotificationsForDependentKey:@"albumArtHeight"];
	}
	
	@catch(NSException *exception) {
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert addButtonWithTitle:NSLocalizedStringFromTable(@"OK", @"General", @"")];
		[alert setMessageText:[NSString stringWithFormat:NSLocalizedStringFromTable(@"An error occurred while initializing the %@ class.", @"Exceptions", @""), @"CompactDiscDocument"]];
		[alert setInformativeText:[exception reason]];
		[alert setAlertStyle:NSWarningAlertStyle];		
		[alert runModal];
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
		
		_albumArt			= nil;
		_albumArtDownloadDate = nil;
		
		_discNumber			= 0;
		_discTotal			= 0;
		_compilation		= NO;
		
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
	[_albumArtDownloadDate release];

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
		NSData					*data					= nil;
		NSString				*error					= nil;
		NSMutableDictionary		*result					= [NSMutableDictionary dictionaryWithCapacity:10];
		NSMutableArray			*tracks					= [NSMutableArray arrayWithCapacity:[self countOfTracks]];
		unsigned				i;
		
		[result setValue:[self title] forKey:@"title"];
		[result setValue:[self artist] forKey:@"artist"];
		[result setObject:[NSNumber numberWithUnsignedInt:[self year]] forKey:@"year"];
		[result setValue:[self genre] forKey:@"genre"];
		[result setValue:[self composer] forKey:@"composer"];
		[result setValue:[self comment] forKey:@"comment"];
		[result setObject:[NSNumber numberWithUnsignedInt:[self discNumber]] forKey:@"discNumber"];
		[result setObject:[NSNumber numberWithUnsignedInt:[self discTotal]] forKey:@"discTotal"];
		[result setObject:[NSNumber numberWithBool:[self compilation]] forKey:@"compilation"];
		[result setValue:[self MCN] forKey:@"MCN"];
		[result setObject:[NSNumber numberWithInt:[self discID]] forKey:@"discID"];
		
		data = getPNGDataForImage([self albumArt]); 
		[result setValue:data forKey:@"albumArt"];
		[result setValue:[self albumArtDownloadDate] forKey:@"albumArtDownloadDate"];
		
		for(i = 0; i < [self countOfTracks]; ++i) {
			[tracks addObject:[[self objectInTracksAtIndex:i] getDictionary]];
		}
		
		[result setObject:tracks forKey:@"tracks"];

		data = [NSPropertyListSerialization dataFromPropertyList:result format:NSPropertyListXMLFormat_v1_0 errorDescription:&error];
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
			unsigned				i;
			NSArray					*tracks			= [dictionary valueForKey:@"tracks"];
			
			if([self discInDrive] && [tracks count] != [self countOfTracks]) {
				@throw [NSException exceptionWithName:@"NSInternalInconsistencyException" reason:@"Track count mismatch between the disc and the saved document." userInfo:nil];
			}
			else if(0 == [self countOfTracks]) {
				for(i = 0; i < [tracks count]; ++i) {
					Track *track = [[[Track alloc] init] autorelease];
					[track setDocument:self];
					[track setPropertiesFromDictionary:[tracks objectAtIndex:i]];
					[self insertObject:track inTracksAtIndex:i];
				}
			}
			
			[_title release];
			[_artist release];
			[_genre release];
			[_composer release];
			[_comment release];
			
			[_albumArt release];
			[_albumArtDownloadDate release];
			
			[_MCN release];
			
			_discID			= [[dictionary valueForKey:@"discID"] intValue];

			_title			= [[dictionary valueForKey:@"title"] retain];
			_artist			= [[dictionary valueForKey:@"artist"] retain];
			_year			= [[dictionary valueForKey:@"year"] unsignedIntValue];
			_genre			= [[dictionary valueForKey:@"genre"] retain];
			_composer		= [[dictionary valueForKey:@"composer"] retain];
			_comment		= [[dictionary valueForKey:@"comment"] retain];

			_discNumber		= [[dictionary valueForKey:@"discNumber"] unsignedIntValue];
			_discTotal		= [[dictionary valueForKey:@"discTotal"] unsignedIntValue];
			_compilation	= [[dictionary valueForKey:@"compilation"] boolValue];	

			_MCN			= [[dictionary valueForKey:@"MCN"] retain];

			// Convert PNG data to an NSImage
			_albumArt		= [[NSImage alloc] initWithData:[dictionary valueForKey:@"albumArt"]];
			_albumArtDownloadDate = [[dictionary valueForKey:@"albumArtDownloadDate"] retain];
			
			// Album art downloaded from amazon can only be kept for 30 days
			if(nil != [self albumArtDownloadDate] && (NSTimeInterval)(-30 * 24 * 60 * 60) >= [[self albumArtDownloadDate] timeIntervalSinceNow]) {
				_albumArt				= nil;
				_albumArtDownloadDate	= nil;
				
				[self saveDocument:self];
			}	
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

- (NSUndoManager *) windowWillReturnUndoManager:(NSWindow *)sender
{
	return [self undoManager];
}

#pragma mark Exception Display

- (void) displayExceptionAlert:(NSAlert *)alert
{
	NSWindow *window = [self windowForSheet];
	if(nil == window) {
		[alert runModal];
	}
	else {
		[alert beginSheetModalForWindow:window modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:NULL];
	}
}

- (void) alertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	// Nothing for now
}

#pragma mark Disc Management

- (void) discEjected			{ [self setDisc:nil]; }

#pragma mark State

- (BOOL) encodeAllowed			{ return ([self discInDrive] && NO == [self emptySelection] && NO == [self ripInProgress] && NO == [self encodeInProgress]); }
- (BOOL) queryFreeDBAllowed		{ return [self discInDrive]; }
- (BOOL) ejectDiscAllowed		{ return [self discInDrive]; }
- (BOOL) emptySelection			{ return (0 == [[self selectedTracks] count]); }

- (BOOL) submitToFreeDBAllowed
{
	unsigned i;

	for(i = 0; i < [self countOfTracks]; ++i) {
		if(nil == [[self objectInTracksAtIndex:i] title]) {
			return NO;
		}
	}
	
	return ([self discInDrive] && nil != [self title] && nil != [self artist] && nil != [self genre]);
}

- (BOOL) ripInProgress
{
	unsigned i;
	
	for(i = 0; i < [self countOfTracks]; ++i) {
		if([[self objectInTracksAtIndex:i] ripInProgress]) {
			return YES;
		}
	}
	
	return NO;
}

- (BOOL) encodeInProgress
{
	unsigned i;
	
	for(i = 0; i < [self countOfTracks]; ++i) {
		if([[self objectInTracksAtIndex:i] encodeInProgress]) {
			return YES;
		}
	}
	
	return NO;
}

#pragma mark Action Methods

- (IBAction) selectAll:(id)sender
{
	unsigned i;
	
	for(i = 0; i < [self countOfTracks]; ++i) {
		[[self objectInTracksAtIndex:i] setSelected:YES];
	}
}

- (IBAction) selectNone:(id)sender
{
	unsigned i;
	
	for(i = 0; i < [self countOfTracks]; ++i) {
		[[self objectInTracksAtIndex:i] setSelected:NO];
	}
}

- (IBAction) encode:(id)sender
{
	@try {
		// Do nothing if the disc isn't in the drive, the selection is empty, or a rip/encode is in progress
		if(NO == [self discInDrive]) {
			return;
		}
		else if([self emptySelection]) {
			@throw [EmptySelectionException exceptionWithReason:NSLocalizedStringFromTable(@"No tracks are selected for encoding.", @"Exceptions", @"") userInfo:nil];
		}
		else if([self ripInProgress] || [self encodeInProgress]) {
			@throw [NSException exceptionWithName:@"ActiveTaskException" reason:NSLocalizedStringFromTable(@"A ripping or encoding operation is already in progress.", @"Exceptions", @"") userInfo:nil];
		}
		
		if([[NSUserDefaults standardUserDefaults] boolForKey:@"automaticallyAddToiTunes"] && [[NSUserDefaults standardUserDefaults] boolForKey:@"createiTunesAlbumPlaylist"]) {
			GetPlaylistNameSheet *sheet = [[GetPlaylistNameSheet alloc] initWithCompactDiscDocument:self];
			[sheet showSheet];
		}
		else {
			[self encodeToPlaylist:nil];
		}
	}
	
	@catch(NSException *exception) {
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert addButtonWithTitle:NSLocalizedStringFromTable(@"OK", @"General", @"")];
		[alert setMessageText:[NSString stringWithFormat:NSLocalizedStringFromTable(@"An error occurred while ripping tracks from the disc \"%@\".", @"Exceptions", @""), [self title]]];
		[alert setInformativeText:[exception reason]];
		[alert setAlertStyle:NSWarningAlertStyle];		
		[self displayExceptionAlert:alert];
	}
}

- (void) encodeToPlaylist:(NSString *)playlist
{
	Track			*track;
	NSArray			*selectedTracks;
	NSEnumerator	*enumerator;
	AudioMetadata	*metadata;
	
	@try {
		// Iterate through the selected tracks and rip/encode them
		selectedTracks	= [self selectedTracks];
		
		// Create one single file for more than one track
		if([[NSUserDefaults standardUserDefaults] boolForKey:@"singleFileOutput"] && 1 < [selectedTracks count]) {
			
			metadata = [[selectedTracks objectAtIndex:0] metadata];
			
			[metadata setTrackNumber:0];
			[metadata setTrackTitle:NSLocalizedStringFromTable(@"Multiple Tracks", @"CompactDisc", @"")];
			[metadata setTrackArtist:nil];
			[metadata setTrackGenre:nil];
			[metadata setTrackComposer:nil];
			[metadata setTrackYear:0];
			[metadata setISRC:nil];

			[metadata setPlaylist:playlist];
			
			[[RipperController sharedController] ripTracks:selectedTracks metadata:metadata];
		}
		// Create one file per track
		else {			
			enumerator		= [selectedTracks objectEnumerator];
			
			while((track = [enumerator nextObject])) {
				metadata = [track metadata];
				[metadata setPlaylist:playlist];
				
				[[RipperController sharedController] ripTracks:[NSArray arrayWithObject:track] metadata:metadata];
			}
		}
	}
	
	@catch(NSException *exception) {
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert addButtonWithTitle:NSLocalizedStringFromTable(@"OK", @"General", @"")];
		[alert setMessageText:[NSString stringWithFormat:NSLocalizedStringFromTable(@"An error occurred while ripping tracks from the disc \"%@\".", @"Exceptions", @""), [self title]]];
		[alert setInformativeText:[exception reason]];
		[alert setAlertStyle:NSWarningAlertStyle];		
		[self displayExceptionAlert:alert];
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
		[alert setMessageText:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Do you want to eject the disc \"%@\" while ripping is in progress?", @"CompactDisc", @""), [self title]]];
		[alert setInformativeText:NSLocalizedStringFromTable(@"Your incomplete rips will be lost.", @"CompactDisc", @"")];
		[alert setAlertStyle:NSWarningAlertStyle];
		
		if(NSAlertSecondButtonReturn == [alert runModal]) {
			return;
		}
		// Stop all associated rip tasks
		else {
			[[RipperController sharedController] stopRipperTasksForDocument:self];
		}
	}
	
	[[MediaController sharedController] ejectDiscForDocument:self];
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
		[self setFreeDBQuerySuccessful:NO];
		[self setFreeDBQueryInProgress:YES];
		
		freeDB = [[FreeDB alloc] initWithCompactDiscDocument:self];
		
		matches = [freeDB fetchMatches];
		
		if(0 == [matches count]) {
			@throw [FreeDBException exceptionWithReason:NSLocalizedStringFromTable(@"No matching discs were found.", @"Exceptions", @"") userInfo:nil];
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
		NSAlert				*alert				= nil;
		
		[self setFreeDBQueryInProgress:NO];
		alert = [[[NSAlert alloc] init] autorelease];
		[alert addButtonWithTitle:NSLocalizedStringFromTable(@"OK", @"General", @"")];
		[alert setMessageText:[NSString stringWithFormat:NSLocalizedStringFromTable(@"An error occurred while querying FreeDB for the disc \"%@\".", @"Exceptions", @""), [self title]]];
		[alert setInformativeText:[exception reason]];
		[alert setAlertStyle:NSWarningAlertStyle];		
		[self displayExceptionAlert:alert];
	}
	
	@finally {
		[freeDB release];
	}
}

- (IBAction) submitToFreeDB:(id) sender
{
	FreeDB				*freeDB				= nil;
	NSAlert				*alert				= nil;
	
	if(NO == [self submitToFreeDBAllowed]) {
		return;
	}
	
	@try {
		freeDB = [[FreeDB alloc] initWithCompactDiscDocument:self];		
		[freeDB submitDisc];
		alert = [[[NSAlert alloc] init] autorelease];
		[alert addButtonWithTitle: NSLocalizedStringFromTable(@"OK", @"General", @"")];
		[alert setMessageText: [NSString stringWithFormat:NSLocalizedStringFromTable(@"The information for the disc \"%@\" has been successfully submitted to FreeDB.", @"General", @""), [self title]]];
		[alert setInformativeText: NSLocalizedStringFromTable(@"Thank you for using FreeDB!", @"General", @"")];
		
		[alert setAlertStyle: NSInformationalAlertStyle];
		
		[alert beginSheetModalForWindow:[self windowForSheet] modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:nil];
	}
	
	@catch(NSException *exception) {
		alert = [[[NSAlert alloc] init] autorelease];
		[alert addButtonWithTitle:NSLocalizedStringFromTable(@"OK", @"General", @"")];
		[alert setMessageText:[NSString stringWithFormat:NSLocalizedStringFromTable(@"An error occurred while submitting information for the disc \"%@\" to FreeDB.", @"Exceptions", @""), [self title]]];
		[alert setInformativeText:[exception reason]];
		[alert setAlertStyle:NSWarningAlertStyle];		
		[self displayExceptionAlert:alert];
	}
	
	@finally {
		[freeDB release];
	}
}

- (IBAction) toggleTrackInformation:(id) sender				{ [_trackDrawer toggle:sender]; }
- (IBAction) toggleAlbumArt:(id) sender						{ [_artDrawer toggle:sender]; }
- (IBAction) selectNextTrack:(id)sender						{ [_trackController selectNext:sender]; }
- (IBAction) selectPreviousTrack:(id)sender					{ [_trackController selectPrevious:sender];	 }

- (IBAction) fetchAlbumArt:(id) sender
{	
	AmazonAlbumArtSheet *art = [[[AmazonAlbumArtSheet alloc] initWithCompactDiscDocument:self] autorelease];
	[art showAlbumArtMatches];
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
				[self setAlbumArt:[image autorelease]];
			}
		}
	}	
}

#pragma mark FreeDB

- (void) clearFreeDBData
{
	unsigned	i;
	Track		*track;
	
	[self setTitle:nil];
	[self setArtist:nil];
	[self setYear:0];
	[self setGenre:nil];
	[self setComment:nil];
	[self setDiscNumber:0];
	[self setDiscTotal:0];
	[self setCompilation:NO];
	
	for(i = 0; i < [self countOfTracks]; ++i) {
		track = [self objectInTracksAtIndex:i];
		if(NO == [track ripInProgress] && NO == [track encodeInProgress]) {
			[track clearFreeDBData];
		}
	}
}

- (void) updateDiscFromFreeDB:(NSDictionary *)info
{
	FreeDB *freeDB;
	
	@try {
		freeDB = [[FreeDB alloc] initWithCompactDiscDocument:self];
		
		[[self undoManager] beginUndoGrouping];
		[self clearFreeDBData];
		[freeDB updateDisc:info];
		[[self undoManager] setActionName:NSLocalizedStringFromTable(@"FreeDB", @"UndoRedo", @"")];
		[[self undoManager] endUndoGrouping];
		
		[self updateChangeCount:NSChangeReadOtherContents];
		
		[self setFreeDBQuerySuccessful:YES];
	}
	
	@catch(NSException *exception) {
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert addButtonWithTitle:NSLocalizedStringFromTable(@"OK", @"General", @"")];
		[alert setMessageText:[NSString stringWithFormat:NSLocalizedStringFromTable(@"An error occurred while retrieving information for the disc \"%@\" from FreeDB.", @"Exceptions", @""), [self title]]];
		[alert setInformativeText:[exception reason]];
		[alert setAlertStyle:NSWarningAlertStyle];		
		[self displayExceptionAlert:alert];
	}
	
	@finally {
		[self setFreeDBQueryInProgress:NO];
		[freeDB release];		
	}	
}

#pragma mark Miscellaneous

- (NSString *)		length								{ return [NSString stringWithFormat:@"%u:%.02u", [[self disc] length] / 60, [[self disc] length] % 60]; }
- (NSArray *)		genres								{ return [Genres sharedGenres]; }

- (NSArray *) selectedTracks
{
	unsigned		i;
	NSMutableArray	*result			= [NSMutableArray arrayWithCapacity:[self countOfTracks]];
	Track			*track;
	
	for(i = 0; i < [self countOfTracks]; ++i) {
		track = [self objectInTracksAtIndex:i];
		if([track selected]) {
			[result addObject:track];
		}
	}

	return [[result retain] autorelease];
}

#pragma mark Accessors

- (CompactDisc *)	disc								{ return _disc; }
- (BOOL)			discInDrive							{ return _discInDrive; }
- (int)				discID								{ return ([self discInDrive] ? [_disc discID] : _discID); }
- (BOOL)			freeDBQueryInProgress				{ return _freeDBQueryInProgress; }
- (BOOL)			freeDBQuerySuccessful				{ return _freeDBQuerySuccessful; }

- (NSString *)		title								{ return _title; }
- (NSString *)		artist								{ return _artist; }
- (unsigned)		year								{ return _year; }
- (NSString *)		genre								{ return _genre; }
- (NSString *)		composer							{ return _composer; }
- (NSString *)		comment								{ return _comment; }

- (NSImage *)		albumArt							{ return _albumArt; }
- (NSDate *)		albumArtDownloadDate				{ return _albumArtDownloadDate; }
- (unsigned)		albumArtWidth						{ return (unsigned)[[self albumArt] size].width; }
- (unsigned)		albumArtHeight						{ return (unsigned)[[self albumArt] size].height; }

- (unsigned)		discNumber							{ return _discNumber; }
- (unsigned)		discTotal							{ return _discTotal; }
- (BOOL)			compilation							{ return _compilation; }

- (NSString *)		MCN									{ return _MCN; }

- (unsigned)		countOfTracks						{ return [_tracks count]; }
- (Track *)			objectInTracksAtIndex:(unsigned)idx { return [_tracks objectAtIndex:idx]; }

#pragma mark Mutators

- (void) setDisc:(CompactDisc *)disc
{
	unsigned			i;

	if(NO == [_disc isEqual:disc]) {

		[_disc release];
		_disc = [disc retain];
		
		if(nil == disc) {
			[self setDiscInDrive:NO];
			return;
		}
		
		[self setDiscInDrive:YES];
		
		[self setMCN:[_disc MCN]];
		
		if(0 == [self countOfTracks]) {
			for(i = 0; i < [_disc countOfTracks]; ++i) {
				Track *track = [[Track alloc] init];
				[track setDocument:self];
				[_tracks addObject:[track autorelease]];
			}
		}
		
		for(i = 0; i < [_disc countOfTracks]; ++i) {
			Track			*track		= [_tracks objectAtIndex:i];
			
			[track setNumber:i + 1];
			[track setFirstSector:[_disc firstSectorForTrack:i]];
			[track setLastSector:[_disc lastSectorForTrack:i]];
			
			[track setChannels:[_disc channelsForTrack:i]];
			[track setPreEmphasis:[_disc trackHasPreEmphasis:i]];
			[track setCopyPermitted:[_disc trackAllowsDigitalCopy:i]];
			[track setISRC:[_disc ISRCForTrack:i]];
		}
	}
}

- (void) setDiscInDrive:(BOOL)discInDrive						{ _discInDrive = discInDrive; }
- (void) setDiscID:(int)discID									{ _discID = discID; }
- (void) setFreeDBQueryInProgress:(BOOL)freeDBQueryInProgress	{ _freeDBQueryInProgress = freeDBQueryInProgress; }
- (void) setFreeDBQuerySuccessful:(BOOL)freeDBQuerySuccessful	{ _freeDBQuerySuccessful = freeDBQuerySuccessful; }
- (void) setAlbumArtDownloadDate:(NSDate *)albumArtDownloadDate { [_albumArtDownloadDate release]; _albumArtDownloadDate = [albumArtDownloadDate retain]; }

- (void) setTitle:(NSString *)title
{
	if(NO == [_title isEqualToString:title]) {
		[[self undoManager] registerUndoWithTarget:self selector:@selector(setTitle:) object:_title];
		[[self undoManager] setActionName:NSLocalizedStringFromTable(@"Album Title", @"UndoRedo", @"")];
		[_title release];
		_title = [title retain];
	}
}

- (void) setArtist:(NSString *)artist
{
	if(NO == [_artist isEqualToString:artist]) {
		[[self undoManager] registerUndoWithTarget:self selector:@selector(setArtist:) object:_artist];
		[[self undoManager] setActionName:NSLocalizedStringFromTable(@"Album Artist", @"UndoRedo", @"")];
		[_artist release];
		_artist = [artist retain];
	}
}

- (void) setYear:(unsigned)year
{
	if(_year != year) {
		[[[self undoManager] prepareWithInvocationTarget:self] setYear:_year];
		[[self undoManager] setActionName:NSLocalizedStringFromTable(@"Album Year", @"UndoRedo", @"")];
		_year = year;
	}
}

- (void) setGenre:(NSString *)genre
{
	if(NO == [_genre isEqualToString:genre]) {
		[[self undoManager] registerUndoWithTarget:self selector:@selector(setGenre:) object:_genre];
		[[self undoManager] setActionName:NSLocalizedStringFromTable(@"Album Genre", @"UndoRedo", @"")];
		[_genre release];
		_genre = [genre retain];
	}
}

- (void) setComposer:(NSString *)composer
{
	if(NO == [_composer isEqualToString:composer]) {
		[[self undoManager] registerUndoWithTarget:self selector:@selector(setComposer:) object:_composer];
		[[self undoManager] setActionName:NSLocalizedStringFromTable(@"Album Composer", @"UndoRedo", @"")];
		[_composer release];
		_composer = [composer retain];
	}
}

- (void) setComment:(NSString *)comment
{
	if(NO == [_comment isEqualToString:comment]) {
		[[self undoManager] registerUndoWithTarget:self selector:@selector(setComment:) object:_comment];
		[[self undoManager] setActionName:NSLocalizedStringFromTable(@"Album Comment", @"UndoRedo", @"")];
		[_comment release];
		_comment = [comment retain];
	}
}

- (void) setAlbumArt:(NSImage *)albumArt
{
	if(NO == [_albumArt isEqual:albumArt]) {
		[[self undoManager] beginUndoGrouping];
		[[self undoManager] registerUndoWithTarget:self selector:@selector(setAlbumArt:) object:_albumArt];
		[[self undoManager] registerUndoWithTarget:self selector:@selector(setAlbumArtDownloadDate:) object:_albumArtDownloadDate];
		[[self undoManager] setActionName:NSLocalizedStringFromTable(@"Album Art", @"UndoRedo", @"")];
		[[self undoManager] endUndoGrouping];
		[_albumArt release];
		_albumArt = [albumArt retain];
		[self setAlbumArtDownloadDate:nil];
	}
}

- (void) setDiscNumber:(unsigned)discNumber
{
	if(_discNumber != discNumber) {
		[[[self undoManager] prepareWithInvocationTarget:self] setDiscNumber:_discNumber];
		[[self undoManager] setActionName:NSLocalizedStringFromTable(@"Total Discs", @"UndoRedo", @"")];
		_discNumber = discNumber;
	}
}

- (void) setDiscTotal:(unsigned)discTotal
{
	if(_discTotal != discTotal) {
		[[[self undoManager] prepareWithInvocationTarget:self] setDiscTotal:_discTotal];
		[[self undoManager] setActionName:NSLocalizedStringFromTable(@"Total Discs", @"UndoRedo", @"")];
		_discTotal = discTotal;
	}
}

- (void) setCompilation:(BOOL)compilation
{
	if(_compilation != compilation) {
		[[[self undoManager] prepareWithInvocationTarget:self] setCompilation:_compilation];
		[[self undoManager] setActionName:NSLocalizedStringFromTable(@"Compilation", @"UndoRedo", @"")];
		_compilation = compilation;
	}
}

- (void) setMCN:(NSString *)MCN { [_MCN release]; _MCN = [MCN retain]; }

- (void) insertObject:(Track *)track inTracksAtIndex:(unsigned)idx		{ [_tracks insertObject:track atIndex:idx]; }
- (void) removeObjectFromTracksAtIndex:(unsigned)idx					{ [_tracks removeObjectAtIndex:idx]; }

#pragma mark Scripting Additions

- (id) handleEncodeScriptCommand:(NSScriptCommand *)command				{ [self encode:command]; return nil; }
- (id) handleEjectDiscScriptCommand:(NSScriptCommand *)command			{ [self ejectDisc:command]; return nil; }
- (id) handleQueryFreeDBScriptCommand:(NSScriptCommand *)command		{ [self queryFreeDB:command]; return nil; }
- (id) handleSubmitToFreeDBScriptCommand:(NSScriptCommand *)command		{ [self submitToFreeDB:command]; return nil; }
- (id) handleToggleTrackInformationScriptCommand:(NSScriptCommand *)command { [self toggleTrackInformation:command]; return nil; }
- (id) handleToggleAlbumArtScriptCommand:(NSScriptCommand *)command		{ [self toggleAlbumArt:command]; return nil; }
- (id) handleFetchAlbumArtScriptCommand:(NSScriptCommand *)command		{ [self fetchAlbumArt:command]; return nil; }

@end
