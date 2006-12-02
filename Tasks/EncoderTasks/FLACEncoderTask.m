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
#import "Track.h"
#import "UtilityFunctions.h"

#include <FLAC/metadata.h>
#include <FLAC/format.h>

@interface AudioMetadata (TagMappings)
+ (NSString *)			customizeFLACTag:(NSString *)tag;
@end

@implementation FLACEncoderTask

- (id) init
{
	if((self = [super init])) {
		_encoderClass = [FLACEncoder class];
		return self;
	}
	return nil;
}

- (void) writeTags
{
	AudioMetadata								*metadata				= [[self taskInfo] metadata];
	FLAC__Metadata_Chain						*chain					= NULL;
	FLAC__Metadata_Iterator						*iterator				= NULL;
	FLAC__StreamMetadata						*block					= NULL;
	FLAC__bool									result;
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
		NSAssert(NULL != chain, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));
		
		result = FLAC__metadata_chain_read(chain, [[self outputFilename] fileSystemRepresentation]);
		NSAssert(YES == result, NSLocalizedStringFromTable(@"Unable to open the output file for tagging.", @"Exceptions", @""));
		
		FLAC__metadata_chain_sort_padding(chain);
		
		iterator = FLAC__metadata_iterator_new();
		NSAssert(NULL != iterator, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));
		
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
			NSAssert(NULL != block, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));
			
			// Add our metadata
			result = FLAC__metadata_iterator_insert_block_after(iterator, block);
			NSAssert1(YES == result, @"FLAC__metadata_chain_status: %i", FLAC__metadata_chain_status(chain));
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
		if([[[[self taskInfo] settings] objectForKey:@"saveSettingsInComment"] boolValue]) {
			comment = (nil == comment ? [self encoderSettingsString] : [comment stringByAppendingString:[NSString stringWithFormat:@"\n%@", [self encoderSettingsString]]]);
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
		addVorbisComment(block, @"ENCODING", [self encoderSettingsString]);
		
		// Add album art if present
		if(nil != [metadata albumArt]) {
			
			FLAC__metadata_iterator_init(iterator, chain);
			
			// Seek to the picture block if it exists
			while(FLAC__METADATA_TYPE_PICTURE != FLAC__metadata_iterator_get_block_type(iterator)) {
				if(NO == FLAC__metadata_iterator_next(iterator)) {
					break; // Already at end
				}
			}
			
			// If there isn't a picture block add one
			if(FLAC__METADATA_TYPE_PICTURE != FLAC__metadata_iterator_get_block_type(iterator)) {
								
				block = FLAC__metadata_object_new(FLAC__METADATA_TYPE_PICTURE);
				NSAssert(NULL != block, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));
				
				// Add our metadata
				result = FLAC__metadata_iterator_insert_block_after(iterator, block);
				NSAssert1(YES == result, @"FLAC__metadata_chain_status: %i", FLAC__metadata_chain_status(chain));
			}
			else {
				block = FLAC__metadata_iterator_get_block(iterator);
			}
			
			NSImage				*image						= [metadata albumArt];
			NSEnumerator		*enumerator					= nil;
			NSImageRep			*currentRepresentation		= nil;
			NSBitmapImageRep	*bitmapRep					= nil;
			NSData				*imageData					= nil;
			FLAC__byte			*data						= NULL;
			NSSize				size;
			
			enumerator = [[image representations] objectEnumerator];
			while((currentRepresentation = [enumerator nextObject])) {
				if([currentRepresentation isKindOfClass:[NSBitmapImageRep class]]) {
					bitmapRep = (NSBitmapImageRep *)currentRepresentation;
				}
			}
			
			// Create a bitmap representation if one doesn't exist
			if(nil == bitmapRep) {
				size = [image size];
				[image lockFocus];
				bitmapRep = [[[NSBitmapImageRep alloc] initWithFocusedViewRect:NSMakeRect(0, 0, size.width, size.height)] autorelease];
				[image unlockFocus];
			}
			
			imageData	= [bitmapRep representationUsingType:NSPNGFileType properties:nil]; 			
			data		= (FLAC__byte *)calloc([imageData length], sizeof(FLAC__byte));
			NSAssert(NULL != data, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));
			[imageData getBytes:data];
			
			// Add the album art
			block->data.picture.type		= FLAC__STREAM_METADATA_PICTURE_TYPE_FRONT_COVER;
			block->data.picture.mime_type	= strdup("image/png");
			block->data.picture.width		= [bitmapRep size].width;
			block->data.picture.height		= [bitmapRep size].height;
			block->data.picture.depth		= [bitmapRep bitsPerPixel];
			block->data.picture.data		= data;
			block->data.picture.data_length	= [imageData length];
		}
		
		// Write the new metadata to the file
		result = FLAC__metadata_chain_write(chain, YES, NO);
		NSAssert1(YES == result, @"FLAC__metadata_chain_status: %i", FLAC__metadata_chain_status(chain));
	}

	@finally {
		FLAC__metadata_chain_delete(chain);
		FLAC__metadata_iterator_delete(iterator);
	}
}

- (NSString *)		fileExtension					{ return @"flac"; }
- (NSString *)		outputFormatName				{ return NSLocalizedStringFromTable(@"FLAC", @"General", @""); }

@end

@implementation FLACEncoderTask (CueSheetAdditions)

- (BOOL)			formatIsValidForCueSheet			{ return YES; }

- (void) generateCueSheet
{
	FLAC__Metadata_Chain						*chain					= NULL;
	FLAC__Metadata_Iterator						*iterator				= NULL;
	FLAC__StreamMetadata						*block					= NULL;
	FLAC__StreamMetadata_CueSheet_Track			*track					= NULL;
	FLAC__bool									result;
	Track										*currentTrack			= nil;
	NSString									*mcn					= nil;
	NSString									*isrc					= nil;
	unsigned									i;
	unsigned									m						= 0;
	unsigned									s						= 0;
	unsigned									f						= 0;
	
	
	if(nil == [[self taskInfo] inputTracks]) {
		return;
	}
	
	@try  {
		chain = FLAC__metadata_chain_new();
		NSAssert(NULL != chain, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));
		
		result = FLAC__metadata_chain_read(chain, [[self outputFilename] fileSystemRepresentation]);
		NSAssert(YES == result, NSLocalizedStringFromTable(@"Unable to open the output file for tagging.", @"Exceptions", @""));
		
		FLAC__metadata_chain_sort_padding(chain);
		
		iterator = FLAC__metadata_iterator_new();
		NSAssert(NULL != iterator, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));
		
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
			NSAssert(NULL != block, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));
			
			// Add our metadata
			result = FLAC__metadata_iterator_insert_block_after(iterator, block);
			NSAssert1(YES == result, @"FLAC__metadata_chain_status: %i", FLAC__metadata_chain_status(chain));
		}
		else {
			block = FLAC__metadata_iterator_get_block(iterator);
		}
		
		// MCN
		mcn = [[[[[self taskInfo] inputTracks] objectAtIndex:0] document] MCN];
		if(nil != mcn) {
			strncpy(block->data.cue_sheet.media_catalog_number, [mcn UTF8String], sizeof(block->data.cue_sheet.media_catalog_number));
		}
		
		block->data.cue_sheet.lead_in	= 2 * 44100;
		block->data.cue_sheet.is_cd		= YES;
		
		// Iterate through tracks
		for(i = 0; i < [[[self taskInfo] inputTracks] count]; ++i) {
			currentTrack	= [[[self taskInfo] inputTracks] objectAtIndex:i];
			track			= FLAC__metadata_object_cuesheet_track_new();
			NSAssert(NULL != track, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));
			
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
			
			result = FLAC__metadata_object_cuesheet_insert_track(block, i, track, NO);
			NSAssert(YES == result, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));
			
			result = FLAC__metadata_object_cuesheet_track_insert_blank_index(block, i, 0);
			NSAssert(YES == result, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));
		}
		
		// Lead-out
		track = FLAC__metadata_object_cuesheet_track_new();
		NSAssert(NULL != track, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));
		
		track->number		= 0xAA;
		track->type			= 1;
		track->num_indices	= 0;
		track->indices		= NULL;
		
		result = FLAC__metadata_object_cuesheet_insert_track(block, i, track, NO);
		NSAssert(YES == result, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));
		
		// Write the new metadata to the file
		result = FLAC__metadata_chain_write(chain, YES, NO);
		NSAssert1(YES == result, @"FLAC__metadata_chain_status: %i", FLAC__metadata_chain_status(chain));
	}
	
	@finally {
		FLAC__metadata_chain_delete(chain);
		FLAC__metadata_iterator_delete(iterator);
	}
}

@end
