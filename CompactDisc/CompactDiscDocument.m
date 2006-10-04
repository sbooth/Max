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
#import "CompactDiscDocumentSettingsSheet.h"
#import "Track.h"
#import "AudioMetadata.h"
#import "Genres.h"
#import "RipperController.h"
#import "PreferencesController.h"
#import "Encoder.h"
#import "MediaController.h"
#import "SelectEncodersSheet.h"

#import "MusicBrainzMatchSheet.h"

#import "MallocException.h"
#import "IOException.h"
#import "EmptySelectionException.h"
#import "MissingResourceException.h"

#import "AmazonAlbumArtSheet.h"
#import "UtilityFunctions.h"

@interface CompactDiscDocument (Private)
- (void)		displayExceptionAlert:(NSAlert *)alert;

- (void)		didEndSettingsSheet:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (void)		didEndSelectEncodersSheet:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (void)		didEndQueryMusicBrainzSheet:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (void)		openPanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;

- (void)		updateMetadataFromMusicBrainz:(unsigned)index;
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
		
		_tracks				= [[NSMutableArray alloc] init];		
		_settings			= [[[NSUserDefaults standardUserDefaults] dictionaryForKey:@"rippingSettings"] mutableCopy];
		
		return self;
	}
	return nil;
}

- (void) dealloc
{	
	[_disc release];					_disc = nil;

	[_mbHelper release];				_mbHelper = nil;

	[_title release];					_title = nil;
	[_artist release];					_artist = nil;
	[_genre release];					_genre = nil;
	[_composer release];				_composer = nil;
	[_comment release];					_comment = nil;

	[_albumArt release];				_albumArt = nil;
	[_albumArtDownloadDate release];	_albumArtDownloadDate = nil;

	[_MCN release];						_MCN = nil;
	
	[_tracks release];					_tracks = nil;
	
	[_settings release];				_settings = nil;
	
	[super dealloc];
}

- (void) awakeFromNib
{
	[_trackTable setAutosaveName:[NSString stringWithFormat: @"Tracks for %@", [self discID]]];
	[_trackTable setAutosaveTableColumns:YES];
	[_trackController setSortDescriptors:[NSArray arrayWithObjects:
		[[[NSSortDescriptor alloc] initWithKey:@"number" ascending:YES] autorelease],
		nil]];	
}

#pragma mark NSDocument overrides

- (BOOL) validateMenuItem:(NSMenuItem *)item
{
	BOOL result;
	
	switch([item tag]) {
		default:								result = [super validateMenuItem:item];			break;
		case kEncodeMenuItemTag:				result = [self encodeAllowed];					break;
		case kEncodeCustomMenuItemTag:			result = [self encodeAllowed];					break;
		case kQueryMusicBrainzMenuItemTag:		result = [self queryMusicBrainzAllowed];		break;
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
	[controller setWindowFrameAutosaveName:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Compact Disc %@", @"CompactDisc", @""), [self discID]]];
	
	NSToolbar *toolbar = [[CompactDiscDocumentToolbar alloc] initWithCompactDiscDocument:self];
    
    [toolbar setAllowsUserCustomization: YES];
    [toolbar setAutosavesConfiguration: YES];
    [toolbar setDisplayMode: NSToolbarDisplayModeIconAndLabel];
    
    [toolbar setDelegate:toolbar];
	
    [[controller window] setToolbar:[toolbar autorelease]];
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
		[result setObject:[self discID] forKey:@"discID"];
		
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
			
			[_title release];						_title = nil;
			[_artist release];						_artist = nil;
			[_genre release];						_genre = nil;
			[_composer release];					_composer = nil;
			[_comment release];						_comment = nil;
			
			[_albumArt release];					_albumArt = nil;
			[_albumArtDownloadDate release];		_albumArtDownloadDate = nil;
			
			[_MCN release];							_MCN = nil;
			
			_discID			= [dictionary valueForKey:@"discID"];

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

#pragma mark Disc Management

- (void) discEjected				{ [self setDisc:nil]; }

#pragma mark State

- (BOOL) encodeAllowed				{ return ([self discInDrive] && NO == [self emptySelection] && NO == [self ripInProgress] && NO == [self encodeInProgress]); }
- (BOOL) queryMusicBrainzAllowed	{ return [self discInDrive]; }
- (BOOL) ejectDiscAllowed			{ return [self discInDrive]; }
- (BOOL) emptySelection				{ return (0 == [[self selectedTracks] count]); }

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
	SelectEncodersSheet		*sheet	= nil;

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
		
		sheet = [[SelectEncodersSheet alloc] init];
		[[NSApplication sharedApplication] beginSheet:[sheet sheet] modalForWindow:[self windowForSheet] modalDelegate:self didEndSelector:@selector(didEndSelectEncodersSheet:returnCode:contextInfo:) contextInfo:sheet];
	}
	
	@catch(NSException *exception) {
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert addButtonWithTitle:NSLocalizedStringFromTable(@"OK", @"General", @"")];
		[alert setMessageText:[NSString stringWithFormat:NSLocalizedStringFromTable(@"An error occurred while ripping tracks from the disc \"%@\".", @"Exceptions", @""), (nil == [self title] ? [self discID] : [self title])]];
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
		[alert setMessageText:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Do you want to eject the disc \"%@\" while ripping is in progress?", @"CompactDisc", @""), (nil == [self title] ? [self discID] : [self title])]];
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

- (IBAction) queryMusicBrainz:(id)sender
{
	unsigned				matchCount	= 0;
	
	if(NO == [self queryMusicBrainzAllowed]) {
		return;
	}
	
	if(nil == _mbHelper) {
		_mbHelper	= [[MusicBrainzHelper alloc] initWithCompactDisc:[self disc]];
	}
	
	[_mbHelper performQuery:sender];
	
	matchCount	= [_mbHelper matchCount];

	if(0 == matchCount) {
		@throw [NSException exceptionWithName:@"MusicBrainzException" reason:NSLocalizedStringFromTable(@"No matching discs were found.", @"Exceptions", @"") userInfo:nil];
	}
	// If only match was found, update ourselves
	else if(1 == matchCount) {
		[self updateMetadataFromMusicBrainz:1];
	}
	else {
		MusicBrainzMatchSheet		*sheet		= nil;
		NSMutableArray				*matches	= nil;
		NSDictionary				*match		= nil;
		unsigned					i;
		
		sheet		= [[MusicBrainzMatchSheet alloc] init];
		matches		= [[NSMutableArray alloc] init];
		
		for(i = 1; i <= matchCount; ++i) {
			[_mbHelper selectMatch:i];
			
			match = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[_mbHelper albumTitle], [_mbHelper albumArtist], [NSNumber numberWithUnsignedInt:i], nil]
												forKeys:[NSArray arrayWithObjects:@"title", @"artist", @"index", nil]];
						
			[matches addObject:match];
		}
		
		[sheet setValue:[matches autorelease] forKey:@"matches"];
		[[NSApplication sharedApplication] beginSheet:[sheet sheet] modalForWindow:[self windowForSheet] modalDelegate:self didEndSelector:@selector(didEndQueryMusicBrainzSheet:returnCode:contextInfo:) contextInfo:sheet];
	}	
}

- (void) queryMusicBrainzNonInteractive
{
	if(NO == [self queryMusicBrainzAllowed]) {
		return;
	}
	
	if(nil == _mbHelper) {
		_mbHelper	= [[MusicBrainzHelper alloc] initWithCompactDisc:[self disc]];
	}
	
	[_mbHelper performQuery:self];
	
	if(1 <= [_mbHelper matchCount]) {
		[self updateMetadataFromMusicBrainz:1];
	}
}

- (IBAction) toggleTrackInformation:(id) sender				{ [_trackDrawer toggle:sender]; }
- (IBAction) toggleAlbumArt:(id) sender						{ [_artDrawer toggle:sender]; }
- (IBAction) selectNextTrack:(id)sender						{ [_trackController selectNext:sender]; }
- (IBAction) selectPreviousTrack:(id)sender					{ [_trackController selectPrevious:sender];	 }

- (IBAction) fetchAlbumArt:(id) sender
{	
	AmazonAlbumArtSheet *art = [[[AmazonAlbumArtSheet alloc] initWithSource:self] autorelease];
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

- (CompactDisc *)	disc								{ return [[_disc retain] autorelease]; }
- (BOOL)			discInDrive							{ return _discInDrive; }
- (NSString *)		discID								{ return ([self discInDrive] ? [[self disc] discID] : _discID); }

- (NSString *)		title								{ return [[_title retain] autorelease]; }
- (NSString *)		artist								{ return [[_artist retain] autorelease]; }
- (unsigned)		year								{ return _year; }
- (NSString *)		genre								{ return [[_genre retain] autorelease]; }
- (NSString *)		composer							{ return [[_composer retain] autorelease]; }
- (NSString *)		comment								{ return [[_comment retain] autorelease]; }

- (NSImage *)		albumArt							{ return [[_albumArt retain] autorelease]; }
- (NSDate *)		albumArtDownloadDate				{ return [[_albumArtDownloadDate retain] autorelease]; }
- (unsigned)		albumArtWidth						{ return (unsigned)[[self albumArt] size].width; }
- (unsigned)		albumArtHeight						{ return (unsigned)[[self albumArt] size].height; }

- (unsigned)		discNumber							{ return _discNumber; }
- (unsigned)		discTotal							{ return _discTotal; }
- (BOOL)			compilation							{ return _compilation; }

- (NSString *)		MCN									{ return [[_MCN retain] autorelease]; }

- (unsigned)		countOfTracks						{ return [_tracks count]; }
- (Track *)			objectInTracksAtIndex:(unsigned)idx { return [_tracks objectAtIndex:idx]; }

#pragma mark Mutators

- (void) setDisc:(CompactDisc *)disc
{
	unsigned			i;

	if(NO == [[self disc] isEqual:disc]) {

		[_disc release];
		_disc = [disc retain];
		
		if(nil == disc) {
			[self setDiscInDrive:NO];
			return;
		}
		
		[self setDiscInDrive:YES];
		
		[self setMCN:[_disc MCN]];
		
		if(0 == [self countOfTracks]) {
			for(i = 0; i < [[self disc] countOfTracks]; ++i) {
				Track *track = [[Track alloc] init];
				[track setDocument:self];
				[_tracks addObject:[track autorelease]];
			}
		}
		
		for(i = 0; i < [[self disc] countOfTracks]; ++i) {
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
- (void) setDiscID:(NSString *)discID							{ [_discID release]; _discID = [discID retain]; }
- (void) setAlbumArtDownloadDate:(NSDate *)albumArtDownloadDate { [_albumArtDownloadDate release]; _albumArtDownloadDate = [albumArtDownloadDate retain]; }

- (void) setTitle:(NSString *)title
{
	if(NO == [[self title] isEqualToString:title]) {
		[[self undoManager] registerUndoWithTarget:self selector:@selector(setTitle:) object:_title];
		[[self undoManager] setActionName:NSLocalizedStringFromTable(@"Album Title", @"UndoRedo", @"")];
		[_title release];
		_title = [title retain];
	}
}

- (void) setArtist:(NSString *)artist
{
	if(NO == [[self artist] isEqualToString:artist]) {
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
	if(NO == [[self genre] isEqualToString:genre]) {
		[[self undoManager] registerUndoWithTarget:self selector:@selector(setGenre:) object:_genre];
		[[self undoManager] setActionName:NSLocalizedStringFromTable(@"Album Genre", @"UndoRedo", @"")];
		[_genre release];
		_genre = [genre retain];
	}
}

- (void) setComposer:(NSString *)composer
{
	if(NO == [[self composer] isEqualToString:composer]) {
		[[self undoManager] registerUndoWithTarget:self selector:@selector(setComposer:) object:_composer];
		[[self undoManager] setActionName:NSLocalizedStringFromTable(@"Album Composer", @"UndoRedo", @"")];
		[_composer release];
		_composer = [composer retain];
	}
}

- (void) setComment:(NSString *)comment
{
	if(NO == [[self comment] isEqualToString:comment]) {
		[[self undoManager] registerUndoWithTarget:self selector:@selector(setComment:) object:_comment];
		[[self undoManager] setActionName:NSLocalizedStringFromTable(@"Album Comment", @"UndoRedo", @"")];
		[_comment release];
		_comment = [comment retain];
	}
}

- (void) setAlbumArt:(NSImage *)albumArt
{
	if(NO == [[self albumArt] isEqual:albumArt]) {
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
		[[self undoManager] setActionName:NSLocalizedStringFromTable(@"Disc Number", @"UndoRedo", @"")];
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

- (IBAction )		editSettings:(id)sender
{
	CompactDiscDocumentSettingsSheet *sheet = [[CompactDiscDocumentSettingsSheet alloc] initWithSettings:_settings];
    [[NSApplication sharedApplication] beginSheet:[sheet sheet] modalForWindow:[self windowForSheet] modalDelegate:self didEndSelector:@selector(didEndSettingsSheet:returnCode:contextInfo:) contextInfo:nil];
}

@end

@implementation CompactDiscDocument (ScriptingAdditions)

- (id) handleEncodeScriptCommand:(NSScriptCommand *)command				{ [self encode:command]; return nil; }
- (id) handleEjectDiscScriptCommand:(NSScriptCommand *)command			{ [self ejectDisc:command]; return nil; }
- (id) handleQueryMusicBrainzScriptCommand:(NSScriptCommand *)command	{ [self queryMusicBrainz:command]; return nil; }
- (id) handleToggleTrackInformationScriptCommand:(NSScriptCommand *)command { [self toggleTrackInformation:command]; return nil; }
- (id) handleToggleAlbumArtScriptCommand:(NSScriptCommand *)command		{ [self toggleAlbumArt:command]; return nil; }
- (id) handleFetchAlbumArtScriptCommand:(NSScriptCommand *)command		{ [self fetchAlbumArt:command]; return nil; }

@end

@implementation CompactDiscDocument (Private)

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

- (void) didEndSettingsSheet:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    [sheet orderOut:self];
	[[NSUserDefaults standardUserDefaults] setValue:_settings forKey:@"rippingSettings"];
}

- (void) didEndSelectEncodersSheet:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	SelectEncodersSheet		*selectEncodersSheet	= (SelectEncodersSheet *)contextInfo;

	[sheet orderOut:self];

	if(NSOKButton == returnCode) {
		NSMutableDictionary		*settings				= nil;
		NSMutableDictionary		*postProcessingOptions	= nil;
		NSArray					*applications;
		NSMutableArray			*postProcessingApplications;
		unsigned				i;
		
		[[NSUserDefaults standardUserDefaults] setValue:_settings forKey:@"rippingSettings"];

		settings			= [NSMutableDictionary dictionary];
		
		// Encoders
		[settings setValue:[selectEncodersSheet selectedEncoders] forKey:@"encoders"];
		
		// File locations
		[settings setValue:[[_settings objectForKey:@"temporaryDirectory"] stringByExpandingTildeInPath] forKey:@"temporaryDirectory"];
		[settings setValue:[[_settings objectForKey:@"outputDirectory"] stringByExpandingTildeInPath] forKey:@"outputDirectory"];
		
		// Conversion parameters
//		[settings setValue:[_settings objectForKey:@"deleteSourceFiles"] forKey:@"deleteSourceFiles"];
		[settings setValue:[_settings objectForKey:@"overwriteOutputFiles"] forKey:@"overwriteOutputFiles"];
		
		if([[_settings objectForKey:@"overwriteOutputFiles"] boolValue]) {
			[settings setValue:[_settings objectForKey:@"promptBeforeOverwritingOutputFiles"] forKey:@"promptBeforeOverwritingOutputFiles"];
		}
		
		// Output file naming
		if([[_settings objectForKey:@"useCustomOutputFileNaming"] boolValue]) {
			NSMutableDictionary		*fileNamingFormat = [NSMutableDictionary dictionary];
			
			[fileNamingFormat setValue:[_settings objectForKey:@"fileNamingFormat"] forKey:@"formatString"];
			[fileNamingFormat setValue:[_settings objectForKey:@"useTwoDigitTrackNumbers"] forKey:@"useTwoDigitTrackNumbers"];
			[fileNamingFormat setValue:[_settings objectForKey:@"useNamingFallback"] forKey:@"useNamingFallback"];
			
			[settings setValue:fileNamingFormat forKey:@"outputFileNaming"];
		}
		
		// Post-processing options
		postProcessingOptions = [NSMutableDictionary dictionary];
		
		[postProcessingOptions setValue:[_settings objectForKey:@"addToiTunes"] forKey:@"addToiTunes"];
		if([[_settings objectForKey:@"addToiTunes"] boolValue]) {
			
			[postProcessingOptions setValue:[_settings objectForKey:@"addToiTunesPlaylist"] forKey:@"addToiTunesPlaylist"];
			
			if([[_settings objectForKey:@"addToiTunesPlaylist"] boolValue]) {
				[postProcessingOptions setValue:[_settings objectForKey:@"iTunesPlaylistName"] forKey:@"iTunesPlaylistName"];
			}		
		}
		
		applications					= [_settings objectForKey:@"postProcessingApplications"];
		postProcessingApplications		= [NSMutableArray arrayWithCapacity:[applications count]];
		
		for(i = 0; i < [applications count]; ++i) {
			[postProcessingApplications addObject:[[applications objectAtIndex:i] objectForKey:@"path"]];
		}
		
		if(0 != [postProcessingApplications count]) {
			[postProcessingOptions setValue:postProcessingApplications forKey:@"postProcessingApplications"];
		}
		
		if(0 != [postProcessingOptions count]) {
			[settings setValue:postProcessingOptions forKey:@"postProcessingOptions"];
		}
		
		// Album art
		if([[_settings objectForKey:@"saveAlbumArt"] boolValue]) {
			NSMutableDictionary		*albumArt = [NSMutableDictionary dictionary];
			
			[albumArt setValue:[_settings objectForKey:@"albumArtFileExtension"] forKey:@"extension"];
			[albumArt setValue:[_settings objectForKey:@"albumArtFileNamingFormat"] forKey:@"formatString"];
			
			[settings setValue:albumArt forKey:@"albumArt"];
		}

		// Rip the tracks
		[[RipperController sharedController] ripTracks:[self selectedTracks] settings:settings];
	}
	
	[selectEncodersSheet release];
}

- (void) didEndQueryMusicBrainzSheet:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	MusicBrainzMatchSheet	*musicBrainzMatchSheet	= (MusicBrainzMatchSheet *)contextInfo;

	[sheet orderOut:self];
	
	if(NSOKButton == returnCode) {
		[self updateMetadataFromMusicBrainz:[musicBrainzMatchSheet selectedAlbumIndex]];
	}

	[musicBrainzMatchSheet release];
}

- (void) openPanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    if(NSOKButton == returnCode) {
		NSArray		*filesToOpen	= [sheet filenames];
		unsigned	count			= [filesToOpen count];
		unsigned	i;
		NSImage		*image			= nil;
		
		for(i = 0; i < count; ++i) {
			image = [[NSImage alloc] initWithContentsOfFile:[filesToOpen objectAtIndex:i]];
			if(nil != image) {
				[self setAlbumArt:[image autorelease]];
			}
		}
	}	
}

- (void) updateMetadataFromMusicBrainz:(unsigned)index
{
	Track						*track		= nil;
	NSString					*trackArtist = nil;
	unsigned					i;
	
	[_mbHelper selectMatch:index];
	
	[[self undoManager] beginUndoGrouping];
		
	[self setTitle:[_mbHelper albumTitle]];
	[self setArtist:[_mbHelper albumArtist]];
				
	for(i = 1; i <= [_mbHelper trackCount]; ++i) {
		
		track			= [self objectInTracksAtIndex:i - 1];
		trackArtist		= [_mbHelper trackArtist:i];
		
		[track setTitle:[_mbHelper trackTitle:i]];
		
		if(NO == [trackArtist isEqualToString:[self artist]]) {
			[track setArtist:trackArtist];
		}
	}
	
	[self updateChangeCount:NSChangeReadOtherContents];
	
	[[self undoManager] setActionName:NSLocalizedStringFromTable(@"MusicBrainz", @"UndoRedo", @"")];
	[[self undoManager] endUndoGrouping];
	
}

@end
