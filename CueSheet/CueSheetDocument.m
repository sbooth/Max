/*
 *  $Id$
 *
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

#import "CueSheetDocument.h"
#import "CueSheetDocumentToolbar.h"
#import "EncoderController.h"
#import "FormatsController.h"
#import "PreferencesController.h"
#import "Decoder.h"
#import "Genres.h"

#include <cuetools/cd.h>
#include <cuetools/cue.h>

@implementation CueSheetDocument

- (id) init
{
	if((self = [super init])) {
		_tracks = [[NSMutableArray alloc] init];
	}
	return self;
}

- (void) dealloc
{
	[_title release],					_title = nil;
	[_artist release],					_artist = nil;
	[_genre release],					_genre = nil;
	[_composer release],				_composer = nil;
	[_comment release],					_comment = nil;
	
	[_albumArt release],				_albumArt = nil;
	[_albumArtDownloadDate release],	_albumArtDownloadDate = nil;
	
	[_MCN release],						_MCN = nil;
	
	[_tracks release],					_tracks = nil;
	
	[super dealloc];
}

- (void) awakeFromNib
{
//	[_trackTable setAutosaveName:[NSString stringWithFormat: @"Tracks for %@", [self discID]]];
	[_trackTable setAutosaveTableColumns:YES];
	[_trackController setSortDescriptors:[NSArray arrayWithObjects:
		[[[NSSortDescriptor alloc] initWithKey:@"number" ascending:YES] autorelease],
		nil]];	
}

#pragma mark NSDocument overrides

- (BOOL) validateMenuItem:(NSMenuItem *)item
{
	if([item action] == @selector(encode:))
		return [self encodeAllowed];
	else if([item action] == @selector(queryMusicBrainz:))
		return [self queryMusicBrainzAllowed];
	else if([item action] == @selector(selectNextTrack:))
		return [_trackController canSelectNext];
	else if([item action] == @selector(selectPreviousTrack:))
		return [_trackController canSelectPrevious];
	else
		return [super validateMenuItem:item];
}

- (void) windowControllerDidLoadNib:(NSWindowController *)controller
{
	[controller setShouldCascadeWindows:NO];
//	[controller setWindowFrameAutosaveName:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Compact Disc %@", @"CompactDisc", @""), [self discID]]];	

	NSToolbar *toolbar = [[CueSheetDocumentToolbar alloc] initWithCueSheetDocument:self];

	[toolbar setAllowsUserCustomization:YES];
	[toolbar setAutosavesConfiguration:YES];
	[toolbar setDisplayMode:NSToolbarDisplayModeIconAndLabel];

	[toolbar setDelegate:toolbar];

	[[controller window] setToolbar:[toolbar autorelease]];	
}

- (NSString *) windowNibName { return @"CueSheetDocument"; }

- (BOOL) writeToURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError
{
	if([typeName isEqualToString:@"CD Cue Sheet"]) {
		return YES;
	}
	return NO;
}

- (BOOL) readFromURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError
{
	if([typeName isEqualToString:@"CD Cue Sheet"] && [absoluteURL isFileURL]) {
		FILE *f = fopen([[absoluteURL path] fileSystemRepresentation], "r");
		if(NULL == f) {
			*outError = [NSError errorWithDomain:NSPOSIXErrorDomain 
											code:errno 
										userInfo:[NSDictionary dictionaryWithObject:NSLocalizedStringFromTable(@"Unable to open the input file.", @"Exceptions", @"") forKey:NSLocalizedFailureReasonErrorKey]];
			return NO;
		}
		
		Cd *cd = cue_parse(f);
		if(NULL == cd) {
			fclose(f);
			*outError = [NSError errorWithDomain:NSPOSIXErrorDomain 
											code:errno 
										userInfo:[NSDictionary dictionaryWithObject:NSLocalizedStringFromTable(@"Unable to open the input file.", @"Exceptions", @"") forKey:NSLocalizedFailureReasonErrorKey]];
			return NO;
		}
		
//		[self setMode:cd_get_mode(cd)];
		
		if(NULL != cd_get_catalog(cd))
			_MCN = [[NSString stringWithCString:cd_get_catalog(cd) encoding:NSASCIIStringEncoding] retain];
		
		Cdtext *cdtext = cd_get_cdtext(cd);
		if(NULL != cdtext) {
			char *value = cdtext_get(PTI_TITLE, cdtext);
			if(NULL != value)
				_title = [[NSString stringWithCString:value encoding:NSASCIIStringEncoding] retain];

			value = cdtext_get(PTI_PERFORMER, cdtext);
			if(NULL != value)
				_artist = [[NSString stringWithCString:value encoding:NSASCIIStringEncoding] retain];

//			value = cdtext_get(PTI_SONGWRITER, cdtext);
//			if(NULL != value)
//				[self setSongwriter:[NSString stringWithCString:value encoding:NSASCIIStringEncoding]];

			value = cdtext_get(PTI_COMPOSER, cdtext);
			if(NULL != value)
				_composer = [[NSString stringWithCString:value encoding:NSASCIIStringEncoding] retain];

//			value = cdtext_get(PTI_ARRANGER, cdtext);
//			if(NULL != value)
//				[self setArranger:[NSString stringWithCString:value encoding:NSASCIIStringEncoding]];

			value = cdtext_get(PTI_UPC_ISRC, cdtext);
			if(NULL != value)
				_MCN = [[NSString stringWithCString:value encoding:NSASCIIStringEncoding] retain];
		}
		
		// Parse each track
		int i;
		for(i = 1; i <= cd_get_ntrack(cd); ++i) {
			
			struct Track	*track			= cd_get_track(cd, i);			
			CueSheetTrack	*newTrack		= [[CueSheetTrack alloc] init]; 

			[newTrack setNumber:i];

			char *filename = track_get_filename(track);
			if(NULL != filename) {
				NSString *relativePath	= [NSString stringWithCString:filename encoding:NSASCIIStringEncoding];
				NSString *cueSheetPath	= [[absoluteURL path] stringByDeletingLastPathComponent];
				NSString *filenamePath	= [cueSheetPath stringByAppendingPathComponent:relativePath];
				
				[newTrack setFilename:filenamePath];
			}
						
			[newTrack setPreGap:track_get_zero_pre(track)];
			[newTrack setPostGap:track_get_zero_post(track)];

			[newTrack setFirstSector:track_get_start(track)];
			
			if(0 != track_get_length(track))
				[newTrack setLastSector:([newTrack firstSector] + track_get_length(track))];
			else {
				
				@try {
					// TODO: Merge with AudioDecoders from Play and remove this
					Decoder *decoder = [Decoder decoderForFilename:[newTrack filename]];

					if(nil == decoder)
						continue;
					
					[decoder finalizeSetup];
					
					unsigned lastSector = ([decoder totalFrames] / [decoder pcmFormat].mSampleRate) * 75;
					[newTrack setLastSector:lastSector];
				}
				
				@catch(NSException *exception) {
					NSLog(@"Caught an exception: %@", exception);
					continue;
				}				
			}
			
			if(track_is_set_flag(track, FLAG_PRE_EMPHASIS))
				[newTrack setPreEmphasis:YES];

			if(track_is_set_flag(track, FLAG_COPY_PERMITTED))
				[newTrack setCopyPermitted:YES];

			if(track_is_set_flag(track, FLAG_DATA))
				[newTrack setDataTrack:YES];

			char *isrc = track_get_isrc(track);
			if(NULL != isrc)
				[newTrack setISRC:[NSString stringWithCString:isrc encoding:NSASCIIStringEncoding]];

			cdtext = track_get_cdtext(track);
			if(NULL != cdtext) {
				char *value = cdtext_get(PTI_TITLE, cdtext);
				if(NULL != value)
					[newTrack setTitle:[NSString stringWithCString:value encoding:NSASCIIStringEncoding]];

				value = cdtext_get(PTI_PERFORMER, cdtext);
				if(NULL != value)
					[newTrack setArtist:[NSString stringWithCString:value encoding:NSASCIIStringEncoding]];

//				value = cdtext_get(PTI_SONGWRITER, cdtext);
//				if(NULL != value)
//					[dictionary setObject:[NSString stringWithCString:value encoding:NSASCIIStringEncoding] forKey:@"songwriter"];

				value = cdtext_get(PTI_COMPOSER, cdtext);
				if(NULL != value)
					[newTrack setComposer:[NSString stringWithCString:value encoding:NSASCIIStringEncoding]];

//				value = cdtext_get(PTI_ARRANGER, cdtext);
//				if(NULL != value)
//					[dictionary setObject:[NSString stringWithCString:value encoding:NSASCIIStringEncoding] forKey:@"arranger"];

				value = cdtext_get(PTI_UPC_ISRC, cdtext);
				if(NULL != value)
					[newTrack setISRC:[NSString stringWithCString:value encoding:NSASCIIStringEncoding]];
			}

			// Do this here to avoid registering for undo information
			[newTrack setDocument:self];
			[self insertObject:[newTrack autorelease] inTracksAtIndex:(i - 1)];
		}
				
		cd_delete(cd);
		fclose(f);

		[self updateChangeCount:NSChangeCleared];
		
		return YES;
	}
    return NO;
}

#pragma mark State

- (BOOL) encodeAllowed				{ return (NO == [self emptySelection]); }
- (BOOL) queryMusicBrainzAllowed	{ return NO; }

- (BOOL) emptySelection				{ return (0 == [[self selectedTracks] count]); }

#pragma mark Action Methods

- (IBAction) selectAll:(id)sender
{
	unsigned i;
	for(i = 0; i < [self countOfTracks]; ++i)
		[[self objectInTracksAtIndex:i] setSelected:YES];
}

- (IBAction) selectNone:(id)sender
{
	unsigned i;
	for(i = 0; i < [self countOfTracks]; ++i)
		[[self objectInTracksAtIndex:i] setSelected:NO];
}

- (IBAction) encode:(id)sender
{
	NSMutableDictionary		*postProcessingOptions	= nil;
	NSArray					*applicationPaths		= nil;
	unsigned				i;
	
	// Do nothing if the selection is empty
	NSAssert(NO == [self emptySelection], NSLocalizedStringFromTable(@"No tracks are selected for encoding.", @"Exceptions", @""));
	
	// Encoders
	NSArray *encoders = [[FormatsController sharedController] selectedFormats];

	// Verify at least one output format is selected
	if(0 == [encoders count]) {
		int		result;
		
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert addButtonWithTitle: NSLocalizedStringFromTable(@"OK", @"General", @"")];
		[alert addButtonWithTitle: NSLocalizedStringFromTable(@"Show Preferences", @"General", @"")];
		[alert setMessageText:NSLocalizedStringFromTable(@"No output formats are selected.", @"General", @"")];
		[alert setInformativeText:NSLocalizedStringFromTable(@"Please select one or more output formats.", @"General", @"")];
		[alert setAlertStyle: NSWarningAlertStyle];
		
		result = [alert runModal];
		
		if(NSAlertFirstButtonReturn == result) {
			// do nothing
		}
		else if(NSAlertSecondButtonReturn == result) {
			[[PreferencesController sharedPreferences] selectPreferencePane:FormatsPreferencesToolbarItemIdentifier];
			[[PreferencesController sharedPreferences] showWindow:self];
		}
		
		return;
	}
	
	NSMutableDictionary *settings = [NSMutableDictionary dictionary];
	[settings setValue:encoders forKey:@"encoders"];
	
	// File locations
	[settings setValue:[[[NSUserDefaults standardUserDefaults] stringForKey:@"outputDirectory"] stringByExpandingTildeInPath] forKey:@"outputDirectory"];
	[settings setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"convertInPlace"] forKey:@"convertInPlace"];
	[settings setValue:[[[NSUserDefaults standardUserDefaults] stringForKey:@"temporaryDirectory"] stringByExpandingTildeInPath] forKey:@"temporaryDirectory"];
	
	// Conversion parameters
	[settings setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"saveSettingsInComment"] forKey:@"saveSettingsInComment"];
//		[settings setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"deleteSourceFiles"] forKey:@"deleteSourceFiles"];
	[settings setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"overwriteOutputFiles"] forKey:@"overwriteOutputFiles"];
	
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"overwriteOutputFiles"])
		[settings setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"promptBeforeOverwritingOutputFiles"] forKey:@"promptBeforeOverwritingOutputFiles"];
	
	// Output file naming
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"useCustomOutputFileNaming"]) {
		NSMutableDictionary		*fileNamingFormat = [NSMutableDictionary dictionary];
		
		[fileNamingFormat setValue:[[NSUserDefaults standardUserDefaults] stringForKey:@"fileNamingFormat"] forKey:@"formatString"];
		[fileNamingFormat setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"useTwoDigitTrackNumbers"] forKey:@"useTwoDigitTrackNumbers"];
		[fileNamingFormat setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"useNamingFallback"] forKey:@"useNamingFallback"];
		
		[settings setValue:fileNamingFormat forKey:@"outputFileNaming"];
	}
	
	// Post-processing options
	postProcessingOptions = [NSMutableDictionary dictionary];
	
	[postProcessingOptions setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"addToiTunes"] forKey:@"addToiTunes"];
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"addToiTunes"]) {
		
		[postProcessingOptions setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"addToiTunesPlaylist"] forKey:@"addToiTunesPlaylist"];
		
		if([[NSUserDefaults standardUserDefaults] boolForKey:@"addToiTunesPlaylist"])
			[postProcessingOptions setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"iTunesPlaylistName"] forKey:@"iTunesPlaylistName"];
	}
	
	applicationPaths = [[NSUserDefaults standardUserDefaults] objectForKey:@"postProcessingApplications"];
	
	if(0 != [applicationPaths count])
		[postProcessingOptions setValue:applicationPaths forKey:@"postProcessingApplications"];
	
	if(0 != [postProcessingOptions count])
		[settings setValue:postProcessingOptions forKey:@"postProcessingOptions"];
	
	// Album art
	if([[NSUserDefaults standardUserDefaults] objectForKey:@"saveAlbumArt"]) {
		NSMutableDictionary *albumArt = [NSMutableDictionary dictionary];
		
		[albumArt setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"albumArtFileExtension"] forKey:@"extension"];
		[albumArt setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"albumArtFileNamingFormat"] forKey:@"formatString"];
		
		[settings setValue:albumArt forKey:@"albumArt"];
	}

	NSArray *selectedTracks = [self selectedTracks];
	for(i = 0; i < [selectedTracks count]; ++i) {
		
		CueSheetTrack *currentTrack = [selectedTracks objectAtIndex:i];
		
		NSLog(@"%@", currentTrack);
		
		NSString				*filename			= [currentTrack filename];
		AudioMetadata			*metadata			= [currentTrack metadata];
		NSMutableDictionary		*sectorsToConvert	= [NSMutableDictionary dictionary];
		NSMutableDictionary		*trackSettings		= [NSMutableDictionary dictionary];
		
		[sectorsToConvert setValue:[NSNumber numberWithUnsignedInt:[currentTrack firstSector]] forKey:@"firstSector"];
		[sectorsToConvert setValue:[NSNumber numberWithUnsignedInt:[currentTrack lastSector]] forKey:@"lastSector"];
		
		[trackSettings setValue:sectorsToConvert forKey:@"sectorsToConvert"];
		[trackSettings addEntriesFromDictionary:settings];
		
		@try {
			[[EncoderController sharedController] encodeFile:filename metadata:metadata settings:trackSettings];
		}
		
		@catch(NSException *exception) {
			NSAlert *alert = [[[NSAlert alloc] init] autorelease];
			[alert addButtonWithTitle:NSLocalizedStringFromTable(@"OK", @"General", @"")];
			[alert setMessageText:[NSString stringWithFormat:NSLocalizedStringFromTable(@"An error occurred while converting the file \"%@\".", @"Exceptions", @""), [[NSFileManager defaultManager] displayNameAtPath:filename]]];
			[alert setInformativeText:[exception reason]];
			[alert setAlertStyle:NSWarningAlertStyle];		
			[alert runModal];
		}			
	}
	
}

- (IBAction) toggleTrackInformation:(id)sender				{ [_trackDrawer toggle:sender]; }
- (IBAction) toggleAlbumArt:(id)sender						{ [_artDrawer toggle:sender]; }
- (IBAction) selectNextTrack:(id)sender						{ [_trackController selectNext:sender]; }
- (IBAction) selectPreviousTrack:(id)sender					{ [_trackController selectPrevious:sender];	 }

- (NSArray *)		genres								{ return [Genres sharedGenres]; }

- (NSArray *) selectedTracks
{
	unsigned		i;
	NSMutableArray	*result			= [NSMutableArray arrayWithCapacity:[self countOfTracks]];
	
	for(i = 0; i < [self countOfTracks]; ++i) {
		CueSheetTrack *track = [self objectInTracksAtIndex:i];
		if([track selected])
			[result addObject:track];
	}
	
	return [[result retain] autorelease];
}

#pragma mark Accessors

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
- (CueSheetTrack *)	objectInTracksAtIndex:(unsigned)idx { return [_tracks objectAtIndex:idx]; }

#pragma mark Mutators

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

- (void) setMCN:(NSString *)MCN
{
	if(NO == [[self MCN] isEqualToString:MCN]) {
		[[self undoManager] registerUndoWithTarget:self selector:@selector(setMCN:) object:_MCN];
		[[self undoManager] setActionName:NSLocalizedStringFromTable(@"Album MCN", @"UndoRedo", @"")];
		[_MCN release];
		_MCN = [MCN retain];
	}
}

- (void) insertObject:(CueSheetTrack *)track inTracksAtIndex:(unsigned)idx	{ [_tracks insertObject:track atIndex:idx]; }
- (void) removeObjectFromTracksAtIndex:(unsigned)idx					{ [_tracks removeObjectAtIndex:idx]; }

@end
