/*
 *  Copyright (C) 2005 - 2020 Stephen F. Booth <me@sbooth.org>
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
#import "MusicBrainzMatchSheet.h"
#import "MusicBrainzHelper.h"
#import "UtilityFunctions.h"

#include <discid/discid.h>

#include <cuetools/cd.h>
#include <cuetools/cue.h>

#include <FLAC/metadata.h>

@interface CueSheetDocument (Private)
- (void) readFromCDInfoFileIfPresent;
- (void) updateMetadataFromMusicBrainz:(NSDictionary *)releaseDictionary;
@end

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
	[_title release];					_title = nil;
	[_artist release];					_artist = nil;
	[_date release];					_date = nil;
	[_genre release];					_genre = nil;
	[_composer release];				_composer = nil;
	[_comment release];					_comment = nil;

	[_albumArt release];				_albumArt = nil;

	[_discNumber release];				_discNumber = nil;
	[_discTotal release];				_discTotal = nil;
	[_compilation release];				_compilation = nil;

	[_MCN release];						_MCN = nil;

	[_tracks release];					_tracks = nil;

	[super dealloc];
}

- (void) awakeFromNib
{
	// Set number formatters	
	NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
	[numberFormatter setNumberStyle:NSNumberFormatterDecimalStyle];

	[_discNumberTextField setFormatter:numberFormatter];
	[_discTotalTextField setFormatter:numberFormatter];
	[numberFormatter release];

//	[_trackTable setAutosaveName:[NSString stringWithFormat: @"Tracks for %@", [self discID]]];
	[_trackTable setAutosaveTableColumns:YES];
	[_trackController setSortDescriptors:[NSArray arrayWithObjects:
		[[[NSSortDescriptor alloc] initWithKey:@"number" ascending:YES] autorelease],
		nil]];	
}

#pragma mark NSDocument overrides

- (BOOL) validateMenuItem:(NSMenuItem *)item
{
	if([item action] == @selector(encode:)) {
		[item setTitle:NSLocalizedStringFromTable(@"Convert Selected Tracks", @"Menus", @"")];
		return [self encodeAllowed];
	}
	else if([item action] == @selector(queryMusicBrainz:))
		return [self queryMusicBrainzAllowed];
	else if([item action] == @selector(selectNextTrack:))
		return [_trackController canSelectNext];
	else if([item action] == @selector(selectPreviousTrack:))
		return [_trackController canSelectPrevious];
	else if([item action] == @selector(toggleMetadataInspectorPanel:)) {
		if([_metadataPanel isVisible])
			[item setTitle:NSLocalizedStringFromTable(@"Hide Track Inspector", @"Menus", @"")];
		else
			[item setTitle:NSLocalizedStringFromTable(@"Show Track Inspector", @"Menus", @"")];

		return YES;
	}
	else
		return [super validateMenuItem:item];
}

- (void) windowControllerDidLoadNib:(NSWindowController *)controller
{
	[controller setShouldCascadeWindows:NO];
//	[controller setWindowFrameAutosaveName:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Compact Disc %@", @"CompactDisc", @""), [self discID]]];	

	CueSheetDocumentToolbar *toolbar = [[CueSheetDocumentToolbar alloc] initWithCueSheetDocument:self];

	[toolbar setAllowsUserCustomization:YES];
	[toolbar setAutosavesConfiguration:YES];
	[toolbar setDisplayMode:NSToolbarDisplayModeIconAndLabel];

	[toolbar setDelegate:toolbar];

	[[controller window] setToolbar:[toolbar autorelease]];	
}

- (NSString *) windowNibName { return @"CueSheetDocument"; }

- (BOOL) writeToURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError
{
    if(NULL != outError)
		*outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:unimpErr userInfo:NULL];

	return NO;
}

// TODO: Replace with cue sheet parser from Play
- (BOOL) readFromURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError
{
	if([absoluteURL isFileURL] && [[[[absoluteURL path] pathExtension] lowercaseString] isEqualToString:@"cue"]) {
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
			_MCN = [[NSString stringWithCString:cd_get_catalog(cd) encoding:NSUTF8StringEncoding] retain];
		
		Cdtext *cdtext = cd_get_cdtext(cd);
		if(NULL != cdtext) {
			char *value = cdtext_get(PTI_TITLE, cdtext);
			if(NULL != value)
				_title = [[NSString stringWithCString:value encoding:NSUTF8StringEncoding] retain];

			value = cdtext_get(PTI_PERFORMER, cdtext);
			if(NULL != value)
				_artist = [[NSString stringWithCString:value encoding:NSUTF8StringEncoding] retain];

//			value = cdtext_get(PTI_SONGWRITER, cdtext);
//			if(NULL != value)
//				[self setSongwriter:[NSString stringWithCString:value encoding:NSUTF8StringEncoding]];

			value = cdtext_get(PTI_COMPOSER, cdtext);
			if(NULL != value)
				_composer = [[NSString stringWithCString:value encoding:NSUTF8StringEncoding] retain];

//			value = cdtext_get(PTI_ARRANGER, cdtext);
//			if(NULL != value)
//				[self setArranger:[NSString stringWithCString:value encoding:NSUTF8StringEncoding]];

			value = cdtext_get(PTI_UPC_ISRC, cdtext);
			if(NULL != value)
				_MCN = [[NSString stringWithCString:value encoding:NSUTF8StringEncoding] retain];
		}
		
		// Parse each track
		int i;
		for(i = 1; i <= cd_get_ntrack(cd); ++i) {
			
			struct Track	*track			= cd_get_track(cd, i);			
			CueSheetTrack	*newTrack		= [[CueSheetTrack alloc] init]; 

			[newTrack setNumber:i];

			char *filename = track_get_filename(track);
			if(NULL != filename) {
				NSString *relativePath	= [NSString stringWithCString:filename encoding:NSUTF8StringEncoding];
				NSString *cueSheetPath	= [[absoluteURL path] stringByDeletingLastPathComponent];
				NSString *filenamePath	= [cueSheetPath stringByAppendingPathComponent:relativePath];
				
				[newTrack setFilename:filenamePath];
			}
						
			[newTrack setPreGap:track_get_zero_pre(track)];
			[newTrack setPostGap:track_get_zero_post(track)];

			@try {
				// TODO: Merge with AudioDecoders from Play and remove this
				Decoder *decoder = [Decoder decoderWithFilename:[newTrack filename]];
				
				if(nil == decoder)
					continue;
				
				[newTrack setSampleRate:[decoder pcmFormat].mSampleRate];
				[newTrack setStartingFrame:(track_get_start(track) / (float)75) * [decoder pcmFormat].mSampleRate];
				
				if(0 != track_get_length(track))
					[newTrack setFrameCount:(track_get_length(track) / (float)75) * [decoder pcmFormat].mSampleRate];
				else
					[newTrack setFrameCount:(UInt32)([decoder totalFrames] - [newTrack startingFrame])];
			}

			@catch(NSException *exception) {
				NSLog(@"Caught an exception: %@", exception);
				continue;
			}				
			
//			if(track_is_set_flag(track, FLAG_PRE_EMPHASIS))
//				[newTrack setPreEmphasis:YES];

//			if(track_is_set_flag(track, FLAG_COPY_PERMITTED))
//				[newTrack setCopyPermitted:YES];

//			if(track_is_set_flag(track, FLAG_DATA))
//				[newTrack setDataTrack:YES];

			char *isrc = track_get_isrc(track);
			if(NULL != isrc)
				[newTrack setISRC:[NSString stringWithCString:isrc encoding:NSUTF8StringEncoding]];

			cdtext = track_get_cdtext(track);
			if(NULL != cdtext) {
				char *value = cdtext_get(PTI_TITLE, cdtext);
				if(NULL != value)
					[newTrack setTitle:[NSString stringWithCString:value encoding:NSUTF8StringEncoding]];

				value = cdtext_get(PTI_PERFORMER, cdtext);
				if(NULL != value)
					[newTrack setArtist:[NSString stringWithCString:value encoding:NSUTF8StringEncoding]];

//				value = cdtext_get(PTI_SONGWRITER, cdtext);
//				if(NULL != value)
//					[dictionary setObject:[NSString stringWithCString:value encoding:NSUTF8StringEncoding] forKey:@"songwriter"];

				value = cdtext_get(PTI_COMPOSER, cdtext);
				if(NULL != value)
					[newTrack setComposer:[NSString stringWithCString:value encoding:NSUTF8StringEncoding]];

//				value = cdtext_get(PTI_ARRANGER, cdtext);
//				if(NULL != value)
//					[dictionary setObject:[NSString stringWithCString:value encoding:NSUTF8StringEncoding] forKey:@"arranger"];

				value = cdtext_get(PTI_UPC_ISRC, cdtext);
				if(NULL != value)
					[newTrack setISRC:[NSString stringWithCString:value encoding:NSUTF8StringEncoding]];
			}

			// Do this here to avoid registering for undo information
			[newTrack setDocument:self];
			[self insertObject:[newTrack autorelease] inTracksAtIndex:(i - 1)];
		}
				
		//cd_delete(cd);
		free(cd);
		fclose(f);

		[self updateChangeCount:NSChangeCleared];
		[self readFromCDInfoFileIfPresent];
		
		return YES;
	}
	else if([absoluteURL isFileURL] && [[[[absoluteURL path] pathExtension] lowercaseString] isEqualToString:@"flac"]) {
		NSString					*path		= [absoluteURL path];
		FLAC__Metadata_Chain		*chain		= NULL;
		FLAC__Metadata_Iterator		*iterator	= NULL;
		FLAC__StreamMetadata		*block		= NULL;

		// Read the file's metadata
		AudioMetadata *metadata = [AudioMetadata metadataFromFile:path];
		if(nil != metadata) {
			_title = [[metadata albumTitle] retain];
			_artist = [[metadata albumArtist] retain];
			_composer = [[metadata albumComposer] retain];
			_date = [[metadata albumDate] retain];
			_genre = [[metadata albumGenre] retain];
			_comment = [[metadata albumComment] retain];
			_MCN = [[metadata MCN] retain];
			_compilation = [[metadata compilation] retain];
			_discNumber = [[metadata discNumber] retain];
			_discTotal = [[metadata discTotal] retain];
		}
		
		chain = FLAC__metadata_chain_new();
		NSAssert(NULL != chain, @"Unable to allocate memory.");
		
		if(NO == FLAC__metadata_chain_read(chain, [path fileSystemRepresentation])) {
			if(NULL != outError) {
				NSMutableDictionary *errorDictionary = [NSMutableDictionary dictionary];
				
				switch(FLAC__metadata_chain_status(chain)) {
					case FLAC__METADATA_CHAIN_STATUS_NOT_A_FLAC_FILE:
						[errorDictionary setObject:NSLocalizedStringFromTable(@"The file is not a valid FLAC file.", @"Exceptions", @"") forKey:NSLocalizedRecoverySuggestionErrorKey];
						break;
						
					case FLAC__METADATA_CHAIN_STATUS_BAD_METADATA:
						[errorDictionary setObject:NSLocalizedStringFromTable(@"The file contains bad metadata.", @"Exceptions", @"") forKey:NSLocalizedRecoverySuggestionErrorKey];
						break;
						
					default:
						[errorDictionary setObject:NSLocalizedStringFromTable(@"The file is not a valid FLAC file.", @"Exceptions", @"") forKey:NSLocalizedRecoverySuggestionErrorKey];
						break;
				}
				
				*outError = [NSError errorWithDomain:NSCocoaErrorDomain 
												code:-1 
											userInfo:errorDictionary];
			}
			
			FLAC__metadata_chain_delete(chain);
			
			return NO;
		}
		
		iterator = FLAC__metadata_iterator_new();
		NSAssert(NULL != iterator, @"Unable to allocate memory.");
		
		FLAC__metadata_iterator_init(iterator, chain);
		
		NSUInteger i;
		FLAC__StreamMetadata_StreamInfo streamInfo;
		
		do {
			block = FLAC__metadata_iterator_get_block(iterator);
			
			if(NULL == block)
				break;
			
			switch(block->type) {					
				case FLAC__METADATA_TYPE_STREAMINFO:
					streamInfo = block->data.stream_info;
					break;
					
				case FLAC__METADATA_TYPE_CUESHEET:
					_MCN = [[NSString stringWithUTF8String:block->data.cue_sheet.media_catalog_number] retain];
					
					// Iterate through each track in the cue sheet and process each one
					for(i = 0; i < block->data.cue_sheet.num_tracks; ++i) {						
						// Only process audio tracks
						// 0 is audio, 1 is non-audio
						if(0 == block->data.cue_sheet.tracks[i].type && 1 <= block->data.cue_sheet.tracks[i].number && 99 >= block->data.cue_sheet.tracks[i].number) {
							CueSheetTrack *newTrack = [[CueSheetTrack alloc] init]; 
							
							[newTrack setFilename:path];
							[newTrack setSampleRate:streamInfo.sample_rate];
							[newTrack setISRC:[NSString stringWithUTF8String:block->data.cue_sheet.tracks[i].isrc]];
							[newTrack setNumber:block->data.cue_sheet.tracks[i].number];
							[newTrack setStartingFrame:block->data.cue_sheet.tracks[i].offset];
							
							// Fill in frame counts
							if(0 < i) {
								NSUInteger frameCount = (block->data.cue_sheet.tracks[i].offset - 1) - block->data.cue_sheet.tracks[i - 1].offset;
								[[self objectInTracksAtIndex:(i - 1)] setFrameCount:(UInt32)frameCount];
							}
							
							// Special handling for the last audio track
							// FIXME: Is it safe the assume the lead out will always be the final track in the cue sheet?
							if(i == block->data.cue_sheet.num_tracks - 1 - 1) {
								NSUInteger frameCount = streamInfo.total_samples - block->data.cue_sheet.tracks[i].offset + 1;
								[newTrack setFrameCount:(UInt32)frameCount];
							}
							
							// Do this here to avoid registering for undo information
							[newTrack setDocument:self];
							[self insertObject:[newTrack autorelease] inTracksAtIndex:i];
						}
					}
					break;
					
					case FLAC__METADATA_TYPE_VORBIS_COMMENT:				break;
					case FLAC__METADATA_TYPE_PICTURE:						break;
					case FLAC__METADATA_TYPE_PADDING:						break;
					case FLAC__METADATA_TYPE_APPLICATION:					break;
					case FLAC__METADATA_TYPE_SEEKTABLE:						break;
					case FLAC__METADATA_TYPE_UNDEFINED:						break;
					default:												break;
			}
		} while(FLAC__metadata_iterator_next(iterator));
		
		FLAC__metadata_iterator_delete(iterator);
		FLAC__metadata_chain_delete(chain);

		// No cue sheet found
		if(0 == [self countOfTracks]) {
			if(NULL != outError) {
				NSMutableDictionary *errorDictionary = [NSMutableDictionary dictionary];

				[errorDictionary setObject:NSLocalizedStringFromTable(@"The file does not contain an embedded cue sheet.", @"Exceptions", @"") forKey:NSLocalizedRecoverySuggestionErrorKey];
				
				*outError = [NSError errorWithDomain:NSCocoaErrorDomain 
												code:-1 
											userInfo:errorDictionary];
			}
			
			return NO;
		}

		[self updateChangeCount:NSChangeCleared];
		[self readFromCDInfoFileIfPresent];
		
		return YES;
	}
	
    if(NULL != outError)
		*outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:unimpErr userInfo:NULL];

    return NO;
}

#pragma mark State

- (BOOL) encodeAllowed				{ return (NO == [self emptySelection]); }
- (BOOL) queryMusicBrainzAllowed	{ return (0 != [self countOfTracks]); }

- (BOOL) emptySelection				{ return (0 == [[self selectedTracks] count]); }

#pragma mark Action Methods

- (IBAction) selectAll:(id)sender
{
	NSUInteger i;
	for(i = 0; i < [self countOfTracks]; ++i)
		[[self objectInTracksAtIndex:i] setSelected:YES];
}

- (IBAction) selectNone:(id)sender
{
	NSUInteger i;
	for(i = 0; i < [self countOfTracks]; ++i)
		[[self objectInTracksAtIndex:i] setSelected:NO];
}

- (IBAction) encode:(id)sender
{
	NSMutableDictionary		*postProcessingOptions	= nil;
	NSArray					*applicationPaths		= nil;
	NSUInteger				i;
	
	// Do nothing if the selection is empty
	NSAssert(NO == [self emptySelection], NSLocalizedStringFromTable(@"No tracks are selected for encoding.", @"Exceptions", @""));
	
	// Encoders
	NSArray *encoders = [[FormatsController sharedController] selectedFormats];

	// Verify at least one output format is selected
	if(0 == [encoders count]) {
		NSInteger		result;
		
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
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"saveAlbumArt"]) {
		NSMutableDictionary *albumArt = [NSMutableDictionary dictionary];
		
		[albumArt setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"albumArtFileExtension"] forKey:@"extension"];
		[albumArt setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"albumArtFileNamingFormat"] forKey:@"formatString"];
		
		[settings setValue:albumArt forKey:@"albumArt"];
	}

	NSArray *selectedTracks = [self selectedTracks];
	for(i = 0; i < [selectedTracks count]; ++i) {
		CueSheetTrack *currentTrack = [selectedTracks objectAtIndex:i];
		
		NSString				*filename			= [currentTrack filename];
		AudioMetadata			*metadata			= [currentTrack metadata];
		NSMutableDictionary		*framesToConvert	= [NSMutableDictionary dictionary];
		NSMutableDictionary		*trackSettings		= [NSMutableDictionary dictionary];
		
		[framesToConvert setValue:[NSNumber numberWithLongLong:[currentTrack startingFrame]] forKey:@"startingFrame"];
		[framesToConvert setValue:[NSNumber numberWithUnsignedInt:[currentTrack frameCount]] forKey:@"frameCount"];
		
		[trackSettings setValue:framesToConvert forKey:@"framesToConvert"];
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

- (IBAction) queryMusicBrainz:(id)sender
{
	if(![self queryMusicBrainzAllowed]) {
		return;
	}

	PerformMusicBrainzQuery([self discID], ^(NSArray *results, NSError *error) {
		if(nil == results) {
			if(nil != error) {
				NSAlert *alert = [NSAlert alertWithError:error];
				[alert beginSheetModalForWindow:[self windowForSheet] completionHandler:^(NSModalResponse returnCode) {
				}];
			}
		}
		else if(0 == [results count]) {
			NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedStringFromTable(@"No matches.", @"CompactDisc", @"") defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:NSLocalizedStringFromTable(@"No releases matching this disc were found in MusicBrainz.", @"CompactDisc", @"")];
			[alert beginSheetModalForWindow:[self windowForSheet] completionHandler:^(NSModalResponse returnCode) {
			}];
		}
		// If only match was found, update ourselves
		else if(1 == [results count]) {
			NSDictionary *release = [results firstObject];
			[self updateMetadataFromMusicBrainz:release];
			[self downloadAlbumArt:sender];
		}
		else {
			MusicBrainzMatchSheet	*sheet		= [[MusicBrainzMatchSheet alloc] init];
			[sheet setValue:results forKey:@"matches"];
			[[self windowForSheet] beginSheet:[sheet sheet] completionHandler:^(NSModalResponse returnCode) {
				if(NSOKButton == returnCode) {
					NSDictionary *release = [sheet selectedRelease];
					[self updateMetadataFromMusicBrainz:release];
					[self downloadAlbumArt:sender];
				}
			}];
			[sheet release];
		}
	});
}

- (void) queryMusicBrainzNonInteractive
{
	if(NO == [self queryMusicBrainzAllowed]) {
		return;
	}
	
	PerformMusicBrainzQuery([self discID], ^(NSArray *results, NSError *error) {
		if(0 < [results count]) {
			NSDictionary *release = [results firstObject];
			[self updateMetadataFromMusicBrainz:release];
			NSString *releaseID = [release objectForKey:@"albumId"];
			PerformCoverArtArchiveQuery(releaseID, ^(NSImage *image, NSError *error) {
				if(nil != image) {
					[self setAlbumArt:image];
				}
			});
		}
	});
}

- (IBAction) toggleMetadataInspectorPanel:(id)sender
{
	if(![_metadataPanel isVisible]) {
		[_metadataPanel orderFront:sender];
	}
	else {
		[_metadataPanel orderOut:sender];
	}
}

- (IBAction) selectNextTrack:(id)sender						{ [_trackController selectNext:sender]; }
- (IBAction) selectPreviousTrack:(id)sender					{ [_trackController selectPrevious:sender];	 }

- (IBAction) downloadAlbumArt:(id)sender
{
	if(![self queryMusicBrainzAllowed]) {
		return;
	}

	PerformMusicBrainzQuery([self discID], ^(NSArray *results, NSError *error) {
		if(nil == results) {
			if(nil != error) {
				NSAlert *alert = [NSAlert alertWithError:error];
				[alert beginSheetModalForWindow:[self windowForSheet] completionHandler:^(NSModalResponse returnCode) {
				}];
			}
		}
		else if(0 == [results count]) {
			NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedStringFromTable(@"No matches.", @"CompactDisc", @"") defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:NSLocalizedStringFromTable(@"No releases matching this disc were found in MusicBrainz.", @"CompactDisc", @"")];
			[alert beginSheetModalForWindow:[self windowForSheet] completionHandler:^(NSModalResponse returnCode) {
			}];
		}
		else {
			NSDictionary *release = [results firstObject];
			[self updateMetadataFromMusicBrainz:release];
			NSString *releaseID = [release objectForKey:@"albumId"];
			PerformCoverArtArchiveQuery(releaseID, ^(NSImage *image, NSError *error) {
				if(nil != error) {
					NSAlert *alert = [NSAlert alertWithError:error];
					[alert beginSheetModalForWindow:[self windowForSheet] completionHandler:^(NSModalResponse returnCode) {
					}];
				}
				else if(nil == image) {
					NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedStringFromTable(@"No album art.", @"CompactDisc", @"") defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:NSLocalizedStringFromTable(@"No front cover art matching this disc was found.", @"CompactDisc", @"")];
					[alert beginSheetModalForWindow:[self windowForSheet] completionHandler:^(NSModalResponse returnCode) {
					}];
				}
				else {
					[self setAlbumArt:image];
				}
			});
		}
	});
}

- (IBAction) selectAlbumArt:(id) sender
{
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	
	[panel setAllowsMultipleSelection:NO];
	[panel setCanChooseDirectories:NO];
	[panel setCanChooseFiles:YES];
	[panel setAllowedFileTypes:[NSImage imageFileTypes]];
	
	[panel beginSheetModalForWindow:[self windowForSheet] completionHandler:^(NSModalResponse result) {
		if(NSOKButton == result) {
			for(NSURL *url in [panel URLs]) {
				NSImage *image = [[NSImage alloc] initWithContentsOfURL:url];
				if(nil != image)
					[self setAlbumArt:[image autorelease]];
			}
		}
	}];
}

- (NSArray *)		genres								{ return [Genres sharedGenres]; }

- (NSArray *) selectedTracks
{
	NSUInteger		i;
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
- (NSString *)		date								{ return [[_date retain] autorelease]; }
- (NSString *)		genre								{ return [[_genre retain] autorelease]; }
- (NSString *)		composer							{ return [[_composer retain] autorelease]; }
- (NSString *)		comment								{ return [[_comment retain] autorelease]; }

- (NSImage *)		albumArt							{ return [[_albumArt retain] autorelease]; }

- (NSNumber *)		discNumber							{ return [[_discNumber retain] autorelease]; }
- (NSNumber *)		discTotal							{ return [[_discTotal retain] autorelease]; }
- (NSNumber *)		compilation							{ return [[_compilation retain] autorelease]; }

- (NSString *)		MCN									{ return [[_MCN retain] autorelease]; }

- (NSUInteger)		countOfTracks						{ return [_tracks count]; }
- (CueSheetTrack *)	objectInTracksAtIndex:(NSUInteger)idx { return [_tracks objectAtIndex:idx]; }

- (NSString *) discID
{
	NSString *musicBrainzDiscID = nil;
	
	DiscId *discID = discid_new();
	if(NULL == discID)
		return nil;
	
	int offsets[100];
	
	NSUInteger i;
	for(i = 0; i < [self countOfTracks]; ++i) {
		CueSheetTrack *track = [self objectInTracksAtIndex:i];
		UInt32 firstSector = [track startingFrame] / ([track sampleRate] / 75);
		offsets[1 + i] = firstSector + 150;
		
		// Use the sector immediately following the last track's last sector for lead out
		if(1 + i == [self countOfTracks]) {
			UInt32 sectorCount = [track frameCount] / ((NSUInteger)[track sampleRate] / 75);
			offsets[0] = offsets[1 + i] + sectorCount;
		}
	}
	
	int result = discid_put(discID, 1, (int)[self countOfTracks], offsets);
	if(result)
		musicBrainzDiscID = [NSString stringWithCString:discid_get_id(discID) encoding:NSUTF8StringEncoding];
	
	discid_free(discID);
	return [[musicBrainzDiscID retain] autorelease];
}

#pragma mark Mutators

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

- (void) setDate:(NSString *)date
{
	if(_date != date) {
		[[self undoManager] registerUndoWithTarget:self selector:@selector(setDate:) object:_date];
		[[self undoManager] setActionName:NSLocalizedStringFromTable(@"Album Date", @"UndoRedo", @"")];
		[_date release];
		_date = [date retain];
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
		[[self undoManager] setActionName:NSLocalizedStringFromTable(@"Album Art", @"UndoRedo", @"")];
		[[self undoManager] endUndoGrouping];
		[_albumArt release];
		_albumArt = [albumArt retain];
	}
}

- (void) setDiscNumber:(NSNumber *)discNumber
{
	if(_discNumber != discNumber) {
		[[self undoManager] registerUndoWithTarget:self selector:@selector(setDiscNumber:) object:_discNumber];
		[[self undoManager] setActionName:NSLocalizedStringFromTable(@"Disc Number", @"UndoRedo", @"")];
		[_discNumber release];
		_discNumber = [discNumber retain];
	}
}

- (void) setDiscTotal:(NSNumber *)discTotal
{
	if(_discTotal != discTotal) {
		[[self undoManager] registerUndoWithTarget:self selector:@selector(setDiscTotal:) object:_discTotal];
		[[self undoManager] setActionName:NSLocalizedStringFromTable(@"Total Discs", @"UndoRedo", @"")];
		[_discTotal release];
		_discTotal = [discTotal retain];
	}
}

- (void) setCompilation:(NSNumber *)compilation
{
	if(_compilation != compilation) {
		[[self undoManager] registerUndoWithTarget:self selector:@selector(setCompilation:) object:_compilation];
		[[self undoManager] setActionName:NSLocalizedStringFromTable(@"Compilation", @"UndoRedo", @"")];
		[_compilation release];
		_compilation = [compilation retain];
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

- (void) insertObject:(CueSheetTrack *)track inTracksAtIndex:(NSUInteger)idx	{ [_tracks insertObject:track atIndex:idx]; }
- (void) removeObjectFromTracksAtIndex:(NSUInteger)idx					{ [_tracks removeObjectAtIndex:idx]; }

@end

@implementation CueSheetDocument (Private)

- (void) readFromCDInfoFileIfPresent
{    	
	NSString *filename = [NSString stringWithFormat:@"%@/%@.cdinfo", GetApplicationDataDirectory(), [self discID]];
	NSDictionary *dictionary = [NSDictionary dictionaryWithContentsOfFile:filename];
	if(nil != dictionary) {
		NSUInteger i;
		
		NSArray *tracks = [dictionary valueForKey:@"tracks"];
		for(i = 0; i < [tracks count]; ++i) {
			NSDictionary *properties = [tracks objectAtIndex:i];
			
			// Match tracks by track number
			CueSheetTrack *track = nil;
			NSUInteger j;
			for(j = 0; j < [self countOfTracks]; ++j) {
				track = [self objectInTracksAtIndex:j];
				if([track number] == [[properties objectForKey:@"number"] unsignedIntValue])
					break;
			}
			
			// Skip this track if it isn't in the image
			if(nil == track)
				continue;
			
			if([properties objectForKey:@"title"])
				[track setTitle:[properties objectForKey:@"title"]];
			if([properties objectForKey:@"artist"])
				[track setArtist:[properties objectForKey:@"artist"]];
			if([properties objectForKey:@"date"])
				[track setDate:[properties objectForKey:@"date"]];
			if([properties objectForKey:@"genre"])
				[track setGenre:[properties objectForKey:@"genre"]];
			if([properties objectForKey:@"composer"])
				[track setComposer:[properties objectForKey:@"composer"]];
			if([properties objectForKey:@"comment"])
				[track setComment:[properties objectForKey:@"comment"]];
			if([properties objectForKey:@"ISRC"])
				[track setISRC:[properties objectForKey:@"ISRC"]];
			
			// Maintain backwards compatibility
			if(nil == [track date] && nil != [properties objectForKey:@"year"] && 0 != [[properties objectForKey:@"year"] intValue])
				[track setDate:[[properties objectForKey:@"year"] stringValue]];
		}
		
		if([dictionary objectForKey:@"title"])
			[self setTitle:[dictionary objectForKey:@"title"]];
		if([dictionary objectForKey:@"artist"])
			[self setArtist:[dictionary objectForKey:@"artist"]];
		if([dictionary objectForKey:@"date"])
			[self setDate:[dictionary objectForKey:@"date"]];
		if([dictionary objectForKey:@"genre"])
			[self setGenre:[dictionary objectForKey:@"genre"]];
		if([dictionary objectForKey:@"composer"])
			[self setComposer:[dictionary objectForKey:@"composer"]];
		if([dictionary objectForKey:@"comment"])
			[self setComment:[dictionary objectForKey:@"comment"]];
		
		if([dictionary objectForKey:@"discNumber"])
			[self setDiscNumber:[dictionary objectForKey:@"discNumber"]];
		if([dictionary objectForKey:@"discTotal"])
			[self setDiscTotal:[dictionary objectForKey:@"discTotal"]];
		if([dictionary objectForKey:@"compilation"])
			[self setCompilation:[dictionary objectForKey:@"compilation"]];
		
		if([dictionary objectForKey:@"MCN"])
			[self setMCN:[dictionary objectForKey:@"MCN"]];
		
		// Maintain backwards compatibility
		if(nil == [self date] && nil != [dictionary objectForKey:@"year"] && 0 != [[dictionary objectForKey:@"year"] intValue])
			[self setDate:[[dictionary objectForKey:@"year"] stringValue]];
		
		// Convert PNG data to an NSImage
		if([dictionary objectForKey:@"albumArt"])
			[self setAlbumArt:[[NSImage alloc] initWithData:[dictionary objectForKey:@"albumArt"]]];
	}
}

- (void) updateMetadataFromMusicBrainz:(NSDictionary *)releaseDictionary
{
	[[self undoManager] beginUndoGrouping];
	
	[self setTitle:[releaseDictionary valueForKey:@"title"]];
	[self setArtist:[releaseDictionary valueForKey:@"artist"]];
	[self setComposer:[releaseDictionary valueForKey:@"composer"]];
	[self setDate:[releaseDictionary valueForKey:@"date"]];
	
	NSArray *tracksArray = [releaseDictionary valueForKey:@"tracks"];
	
	NSUInteger i;
	for(i = 0; i < [tracksArray count]; ++i) {
		NSDictionary *trackDictionary = [tracksArray objectAtIndex:i];
		CueSheetTrack *track = [self objectInTracksAtIndex:i];
		
		[track setTitle:[trackDictionary valueForKey:@"title"]];
		[track setArtist:[trackDictionary valueForKey:@"artist"]];
		[track setComposer:[trackDictionary valueForKey:@"composer"]];
	}
	
	[self updateChangeCount:NSChangeReadOtherContents];
	
	[[self undoManager] setActionName:NSLocalizedStringFromTable(@"MusicBrainz", @"UndoRedo", @"")];
	[[self undoManager] endUndoGrouping];
	
}

@end
