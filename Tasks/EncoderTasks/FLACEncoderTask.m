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

#import "FLACEncoderTask.h"
#import "FLACEncoder.h"
#import "IOException.h"
#import "MallocException.h"
#import "FLACException.h"
#import "UtilityFunctions.h"

#include <FLAC/metadata.h>
#include <FLAC/format.h>

@interface AudioMetadata (TagMappings)
+ (NSString *)			customizeFLACTag:(NSString *)tag;
@end

@implementation FLACEncoderTask

- (id) initWithTask:(PCMGeneratingTask *)task
{
	if((self = [super initWithTask:task])) {
		_encoderClass = [FLACEncoder class];
		return self;
	}
	return nil;
}

- (void) writeTags
{
	AudioMetadata								*metadata				= [self metadata];
	FLAC__Metadata_Chain						*chain					= NULL;
	FLAC__Metadata_Iterator						*iterator				= NULL;
	FLAC__StreamMetadata						*block					= NULL;
	NSString									*bundleVersion			= nil;
	NSString									*versionString			= nil;
	unsigned									trackNumber				= 0;
	unsigned									trackTotal				= 0;
	NSString									*album					= nil;
	NSString									*artist					= nil;
	NSString									*composer				= nil;
	NSString									*title					= nil;
	unsigned									year					= 0;
	NSString									*genre					= nil;
	NSString									*comment				= nil;
	NSString									*trackComment			= nil;
	unsigned									discNumber				= 0;
	unsigned									discTotal				= 0;
	BOOL										compilation				= NO;
	NSString									*isrc					= nil;
	NSString									*mcn					= nil;
	
	
	@try  {
		chain = FLAC__metadata_chain_new();
		if(NULL == chain) {
			@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @"") userInfo:nil];
		}
		
		if(NO == FLAC__metadata_chain_read(chain, [_outputFilename fileSystemRepresentation])) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to open the output file for tagging.", @"Exceptions", @"") userInfo:nil];
		}
		
		FLAC__metadata_chain_sort_padding(chain);
		
		iterator = FLAC__metadata_iterator_new();
		if(NULL == iterator) {
			@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @"") userInfo:nil];
		}
		
		FLAC__metadata_iterator_init(iterator, chain);

		// Seek to the vorbis comment block if it exists
		while(FLAC__METADATA_TYPE_VORBIS_COMMENT != FLAC__metadata_iterator_get_block_type(iterator)) {
			if(NO == FLAC__metadata_iterator_next(iterator)) {
				break; // Already at end
			}
		}
		
		// If there isn't a vorbis comment block add one
		if(FLAC__METADATA_TYPE_VORBIS_COMMENT != FLAC__metadata_iterator_get_block_type(iterator)) {

			// The padding block will be the last block if it exists; add the comment block before it
			if(FLAC__METADATA_TYPE_PADDING == FLAC__metadata_iterator_get_block_type(iterator)) {
				FLAC__metadata_iterator_prev(iterator);
			}
			
			block = FLAC__metadata_object_new(FLAC__METADATA_TYPE_VORBIS_COMMENT);
			if(NULL == block) {
				@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @"") userInfo:nil];
			}
			
			// Add our metadata
			if(NO == FLAC__metadata_iterator_insert_block_after(iterator, block)) {
				@throw [FLACException exceptionWithReason:[NSString stringWithFormat:@"%i", FLAC__metadata_chain_status(chain)] userInfo:nil];
			}
		}
		else {
			block = FLAC__metadata_iterator_get_block(iterator);
		}

		// Album title
		album = [metadata albumTitle];
		if(nil != album) {
			addVorbisComment(block, [AudioMetadata customizeFLACTag:@"ALBUM"], album);
		}
		
		// Artist
		artist = [metadata trackArtist];
		if(nil == artist) {
			artist = [metadata albumArtist];
		}
		if(nil != artist) {
			addVorbisComment(block, [AudioMetadata customizeFLACTag:@"ARTIST"], artist);
		}

		// Composer
		composer = [metadata trackComposer];
		if(nil == composer) {
			composer = [metadata albumComposer];
		}
		if(nil != composer) {
			addVorbisComment(block, [AudioMetadata customizeFLACTag:@"COMPOSER"], composer);
		}
		
		// Genre
		genre = [metadata trackGenre];
		if(nil == genre) {
			genre = [metadata albumGenre];
		}
		if(nil != genre) {
			addVorbisComment(block, [AudioMetadata customizeFLACTag:@"GENRE"], genre);
		}
		
		// Year
		year = [metadata trackYear];
		if(0 == year) {
			year = [metadata albumYear];
		}
		if(0 != year) {
			addVorbisComment(block, [AudioMetadata customizeFLACTag:@"DATE"], [NSString stringWithFormat:@"%u", year]);
		}
		
		// Comment
		comment			= [metadata albumComment];
		trackComment	= [metadata trackComment];
		if(nil != trackComment) {
			comment = (nil == comment ? trackComment : [NSString stringWithFormat:@"%@\n%@", trackComment, comment]);
		}
		if(_writeSettingsToComment) {
			comment = (nil == comment ? [self settings] : [comment stringByAppendingString:[NSString stringWithFormat:@"\n%@", [self settings]]]);
		}
		if(nil != comment) {
			addVorbisComment(block, [AudioMetadata customizeFLACTag:@"DESCRIPTION"], comment);
		}
		
		// Track title
		title = [metadata trackTitle];
		if(nil != title) {
			addVorbisComment(block, [AudioMetadata customizeFLACTag:@"TITLE"], title);
		}
		
		// Track number
		trackNumber = [metadata trackNumber];
		if(0 != trackNumber) {
			addVorbisComment(block, [AudioMetadata customizeFLACTag:@"TRACKNUMBER"], [NSString stringWithFormat:@"%u", trackNumber]);
		}

		// Total tracks
		trackTotal = [metadata trackTotal];
		if(0 != trackTotal) {
			addVorbisComment(block, [AudioMetadata customizeFLACTag:@"TRACKTOTAL"], [NSString stringWithFormat:@"%u", trackTotal]);
		}

		// Compilation
		compilation = [metadata compilation];
		if(compilation) {
			addVorbisComment(block, [AudioMetadata customizeFLACTag:@"COMPILATION"], @"1");
		}
		
		// Disc number
		discNumber = [metadata discNumber];
		if(0 != discNumber) {
			addVorbisComment(block, [AudioMetadata customizeFLACTag:@"DISCNUMBER"], [NSString stringWithFormat:@"%u", discNumber]);
		}
		
		// Discs in set
		discTotal = [metadata discTotal];
		if(0 != discTotal) {
			addVorbisComment(block, [AudioMetadata customizeFLACTag:@"DISCTOTAL"], [NSString stringWithFormat:@"%u", discTotal]);
		}
		
		// ISRC
		isrc = [metadata ISRC];
		if(nil != isrc) {
			addVorbisComment(block, [AudioMetadata customizeFLACTag:@"ISRC"], isrc);
		}

		// MCN
		mcn = [metadata MCN];
		if(nil != mcn) {
			addVorbisComment(block, [AudioMetadata customizeFLACTag:@"MCN"], mcn);
		}
		
		// Encoded by
		bundleVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
		versionString = [NSString stringWithFormat:@"Max %@", bundleVersion];
		addVorbisComment(block, @"ENCODER", versionString);

		// Encoder settings
		addVorbisComment(block, @"ENCODING", [self settings]);
		
		// Write the new metadata to the file
		if(NO == FLAC__metadata_chain_write(chain, YES, NO)) {
			@throw [FLACException exceptionWithReason:[NSString stringWithFormat:@"%i", FLAC__metadata_chain_status(chain)] userInfo:nil];
		}
	}

	@finally {
		FLAC__metadata_chain_delete(chain);
		FLAC__metadata_iterator_delete(iterator);
	}
}

- (BOOL)			formatLegalForCueSheet			{ return YES; }
- (NSString *)		extension						{ return @"flac"; }
- (NSString *)		outputFormat					{ return NSLocalizedStringFromTable(@"FLAC", @"General", @""); }

- (void) generateCueSheet
{
	FLAC__Metadata_Chain						*chain					= NULL;
	FLAC__Metadata_Iterator						*iterator				= NULL;
	FLAC__StreamMetadata						*block					= NULL;
	FLAC__StreamMetadata_CueSheet_Track			*track					= NULL;
	Track										*currentTrack			= nil;
	NSString									*mcn					= nil;
	NSString									*isrc					= nil;
	unsigned									i;
	unsigned									m						= 0;
	unsigned									s						= 0;
	unsigned									f						= 0;
	
	
	if(nil == _tracks) {
		return;
	}

	@try  {
		chain = FLAC__metadata_chain_new();
		if(NULL == chain) {
			@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @"") userInfo:nil];
		}
		
		if(NO == FLAC__metadata_chain_read(chain, [_outputFilename fileSystemRepresentation])) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to open the output file for tagging.", @"Exceptions", @"") userInfo:nil];
		}
		
		FLAC__metadata_chain_sort_padding(chain);
		
		iterator = FLAC__metadata_iterator_new();
		if(NULL == iterator) {
			@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @"") userInfo:nil];
		}
		
		FLAC__metadata_iterator_init(iterator, chain);
		
		// Seek to the cuesheet block if it exists
		while(FLAC__METADATA_TYPE_CUESHEET != FLAC__metadata_iterator_get_block_type(iterator)) {
			if(NO == FLAC__metadata_iterator_next(iterator)) {
				break; // Already at end
			}
		}
		
		// If there isn't a cuesheet block add one
		if(FLAC__METADATA_TYPE_CUESHEET != FLAC__metadata_iterator_get_block_type(iterator)) {
			
			// The padding block will be the last block if it exists; add the cuesheet block before it
			if(FLAC__METADATA_TYPE_PADDING == FLAC__metadata_iterator_get_block_type(iterator)) {
				FLAC__metadata_iterator_prev(iterator);
			}
			
			block = FLAC__metadata_object_new(FLAC__METADATA_TYPE_CUESHEET);
			if(NULL == block) {
				@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @"") userInfo:nil];
			}
			
			// Add our metadata
			if(NO == FLAC__metadata_iterator_insert_block_after(iterator, block)) {
				@throw [FLACException exceptionWithReason:[NSString stringWithFormat:@"%i", FLAC__metadata_chain_status(chain)] userInfo:nil];
			}
		}
		else {
			block = FLAC__metadata_iterator_get_block(iterator);
		}
		
		// MCN
		mcn = [[[_tracks objectAtIndex:0] document] MCN];
		if(nil != mcn) {
			strncpy(block->data.cue_sheet.media_catalog_number, [mcn UTF8String], sizeof(block->data.cue_sheet.media_catalog_number));
		}
		
		block->data.cue_sheet.lead_in	= 2 * 44100;
		block->data.cue_sheet.is_cd		= YES;
		
		// Iterate through tracks
		for(i = 0; i < [_tracks count]; ++i) {
			currentTrack	= [_tracks objectAtIndex:i];
			track			= FLAC__metadata_object_cuesheet_track_new();
			if(NULL == track) {
				@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @"") userInfo:nil];
			}
			
			track->number		= [currentTrack number];
			track->type			= 0;
			track->pre_emphasis	= [currentTrack preEmphasis];
			
			isrc = [currentTrack ISRC];
			if(nil != isrc) {
				strncpy(track->isrc, [isrc UTF8String], sizeof(track->isrc));
			}
			
			// 44.1 kHz
			track->offset = (((60 * m) + s) * 44100) + (f * 588);
			
			// Update times
			f += [currentTrack frame];
			while(75 < f) {
				f /= 75;
				++s;
			}
			
			s += [currentTrack second];
			while(60 < s) {
				s /= 60;
				++m;
			}
			
			m += [currentTrack minute];

			if(NO == FLAC__metadata_object_cuesheet_insert_track(block, i, track, NO)) {
				@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @"") userInfo:nil];
			}
			
			if(NO == FLAC__metadata_object_cuesheet_track_insert_blank_index(block, i, 0)) {
				@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @"") userInfo:nil];
			}			
		}
		
		// Lead-out
		track = FLAC__metadata_object_cuesheet_track_new();
		if(NULL == track) {
			@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @"") userInfo:nil];
		}
		
		track->number		= 0xAA;
		track->type			= 1;
		track->num_indices	= 0;
		track->indices		= NULL;

		if(NO == FLAC__metadata_object_cuesheet_insert_track(block, i, track, NO)) {
			@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @"") userInfo:nil];
		}			
		
		// Write the new metadata to the file
		if(NO == FLAC__metadata_chain_write(chain, YES, NO)) {
			@throw [FLACException exceptionWithReason:[NSString stringWithFormat:@"%i", FLAC__metadata_chain_status(chain)] userInfo:nil];
		}
	}
	
	@finally {
		FLAC__metadata_chain_delete(chain);
		FLAC__metadata_iterator_delete(iterator);
	}
}

@end
