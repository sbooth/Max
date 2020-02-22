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

#import "AudioMetadata.h"

#import "UtilityFunctions.h"

#include <taglib/fileref.h>						// TagLib::FileRef
#include <taglib/mpegfile.h>					// TagLib::MPEG::File
#include <taglib/vorbisfile.h>					// TagLib::Ogg::Vorbis::File
#include <taglib/oggflacfile.h>					// TagLib::Ogg::FLAC::File
#include <taglib/speexfile.h>					// TagLib::Ogg::Speex::File
#include <taglib/id3v2tag.h>					// TagLib::ID3v2::Tag
#include <taglib/id3v2frame.h>					// TagLib::ID3v2::Frame
#include <taglib/attachedpictureframe.h>		// TagLib::ID3V2::AttachedPictureFrame
#include <taglib/textidentificationframe.h>		// TagLib::ID3v2::UserTextIdentificationFrame
#include <taglib/uniquefileidentifierframe.h>	// TagLib::ID3v2::UniqueFileIdentifierFrame
#include <taglib/xiphcomment.h>					// TagLib::Ogg::XiphComment
#include <taglib/tbytevector.h>					// TagLib::ByteVector
#include <taglib/mpcfile.h>						// TagLib::MPC::File
#include <taglib/aifffile.h>					// TagLib::RIFF:AIFF::File
#include <taglib/wavfile.h>						// TagLib::RIFF:WAVE::File

#include <mp4v2/mp4v2.h>						// MP4FileHandle

#include <mac/All.h>
#include <mac/MACLib.h>
#include <mac/APETag.h>
#include <mac/CharacterHelper.h>

#include <wavpack/wavpack.h>

@interface AudioMetadata (FileMetadata)
+ (AudioMetadata *)		metadataFromFLACFile:(NSString *)filename;
+ (AudioMetadata *)		metadataFromMP3File:(NSString *)filename;
+ (AudioMetadata *)		metadataFromMP4File:(NSString *)filename;
+ (AudioMetadata *)		metadataFromOggVorbisFile:(NSString *)filename;
+ (AudioMetadata *)		metadataFromOggFLACFile:(NSString *)filename;
+ (AudioMetadata *)		metadataFromOggSpeexFile:(NSString *)filename;
+ (AudioMetadata *)		metadataFromMonkeysAudioFile:(NSString *)filename;
+ (AudioMetadata *)		metadataFromWavPackFile:(NSString *)filename;
+ (AudioMetadata *)		metadataFromMusepackFile:(NSString *)filename;
+ (AudioMetadata *)		metadataFromAIFFFile:(NSString *)filename;
+ (AudioMetadata *)		metadataFromWAVEFile:(NSString *)filename;
@end

@interface AudioMetadata (TagMappings)
+ (NSString *)			customizeFLACTag:(NSString *)tag;
+ (TagLib::String)		customizeOggVorbisTag:(NSString *)tag;
+ (TagLib::String)		customizeOggFLACTag:(NSString *)tag;
+ (APE::str_utfn *)		customizeAPETag:(NSString *)tag;
+ (NSString *)			customizeWavPackTag:(NSString *)tag;
@end

@implementation AudioMetadata

+ (BOOL) accessInstanceVariablesDirectly { return NO; }

// Attempt to parse metadata from filename
+ (AudioMetadata *) metadataFromFile:(NSString *)filename
{
	NSString *extension = [[filename pathExtension] lowercaseString];
	
	if([extension isEqualToString:@"flac"])
		return [self metadataFromFLACFile:filename];
	else if([extension isEqualToString:@"mp3"])
		return [self metadataFromMP3File:filename];
	else if([extension isEqualToString:@"mp4"] || [extension isEqualToString:@"m4a"])
		return [self metadataFromMP4File:filename];
	else if([extension isEqualToString:@"ogg"] || [extension isEqualToString:@"oga"]) {
		
		// Determine the content type of the ogg stream
		AudioMetadata	*result		= nil;
		OggStreamType	type		= GetOggStreamType(filename);
		NSAssert(kOggStreamTypeInvalid != type, @"The file does not appear to be an Ogg file.");
		NSAssert(kOggStreamTypeUnknown != type, @"The Ogg file's data format was not recognized.");
		
		switch(type) {
			case kOggStreamTypeVorbis:		result = [self metadataFromOggVorbisFile:filename];			break;
			case kOggStreamTypeFLAC:		result = [self metadataFromOggFLACFile:filename];			break;
			case kOggStreamTypeSpeex:		result = [self metadataFromOggSpeexFile:filename];			break;
			default:						result = [[[AudioMetadata alloc] init] autorelease];		break;
		}

		return result;
	}
	else if([extension isEqualToString:@"oggflac"])
		return [self metadataFromOggFLACFile:filename];
	else if([extension isEqualToString:@"ape"] || [extension isEqualToString:@"apl"] || [extension isEqualToString:@"mac"])
		return [self metadataFromMonkeysAudioFile:filename];
	else if([extension isEqualToString:@"wv"])
		return [self metadataFromWavPackFile:filename];
	else if([extension isEqualToString:@"mpc"])
		return [self metadataFromMusepackFile:filename];
	else if([extension isEqualToString:@"spx"])
		return [self metadataFromOggSpeexFile:filename];
	else if([extension isEqualToString:@"aiff"] || [extension isEqualToString:@"aif"])
		return [self metadataFromAIFFFile:filename];
	else if([extension isEqualToString:@"wave"] || [extension isEqualToString:@"wav"])
		return [self metadataFromWAVEFile:filename];
	else
		return [[[AudioMetadata alloc] init] autorelease];
}

#pragma mark Class

- (void) dealloc
{
	[_trackNumber release];			_trackNumber = nil;
	[_trackTotal release];			_trackTotal = nil;
	[_trackTitle release];			_trackTitle = nil;
	[_trackArtist release];			_trackArtist = nil;
	[_trackComposer release];		_trackComposer = nil;
	[_trackDate release];			_trackDate = nil;
	[_trackGenre release];			_trackGenre = nil;
	[_trackComment release];		_trackComment = nil;
	
	[_albumTitle release];			_albumTitle = nil;
	[_albumArtist release];			_albumArtist = nil;
	[_albumComposer release];		_albumComposer = nil;
	[_albumDate release];			_albumDate = nil;
	[_albumGenre release];			_albumGenre = nil;
	[_albumComment release];		_albumComment = nil;

	[_compilation release];			_compilation = nil;
	[_discNumber release];			_discNumber = nil;
	[_discTotal release];			_discTotal = nil;

	[_length release];				_length = nil;

	[_albumArt release];			_albumArt = nil;
	
	[_discId release];				_discId = nil;
	[_MCN release];					_MCN = nil;
	[_ISRC release];				_ISRC = nil;

	[_musicbrainzTrackId release];	_musicbrainzTrackId = nil;
	[_musicbrainzArtistId release];	_musicbrainzArtistId = nil;
	[_musicbrainzAlbumId release];	_musicbrainzAlbumId = nil;
	[_musicbrainzAlbumArtistId release];	_musicbrainzAlbumArtistId = nil;

	[_playlist release];			_playlist = nil;
	
	[super dealloc];
}

- (NSString *) replaceKeywordsInString:(NSString *)namingScheme
{
	NSMutableString *customPath = [[NSMutableString alloc] init];
	
	// Get the elements needed for the substitutions
	NSNumber			*discNumber			= [self discNumber];
	NSNumber			*discTotal			= [self discTotal];
	NSString			*albumArtist		= [self albumArtist];
	NSString			*albumTitle			= [self albumTitle];
	NSString			*albumGenre			= [self albumGenre];
	NSString			*albumYear			= [self albumDate];
	NSString			*albumComposer		= [self albumComposer];
	NSString			*albumComment		= [self albumComment];
	NSNumber			*trackNumber		= [self trackNumber];
	NSNumber			*trackTotal			= [self trackTotal];
	NSString			*trackArtist		= [self trackArtist];
	NSString			*trackTitle			= [self trackTitle];
	NSString			*trackGenre			= [self trackGenre];
	NSString			*trackYear			= [self trackDate];
	NSString			*trackComposer		= [self trackComposer];
	NSString			*trackComment		= [self trackComment];
	
	NSParameterAssert(nil != namingScheme);
//		@throw [NSException exceptionWithName:@"NSObjectInaccessibleException" reason:@"The custom naming string appears to be invalid." userInfo:nil];
	[customPath setString:namingScheme];
	
	if(nil == discNumber)
		[customPath replaceOccurrencesOfString:@"{discNumber}" withString:@"" options:0 range:NSMakeRange(0, [customPath length])];
	else
		[customPath replaceOccurrencesOfString:@"{discNumber}" withString:[NSString stringWithFormat:@"%u", [discNumber intValue]] options:0 range:NSMakeRange(0, [customPath length])];					

	if(nil == discTotal)
		[customPath replaceOccurrencesOfString:@"{discTotal}" withString:@"" options:0 range:NSMakeRange(0, [customPath length])];
	else
		[customPath replaceOccurrencesOfString:@"{discTotal}" withString:[NSString stringWithFormat:@"%u", [discTotal intValue]] options:0 range:NSMakeRange(0, [customPath length])];					

	if(nil == albumArtist)
		[customPath replaceOccurrencesOfString:@"{albumArtist}" withString:NSLocalizedStringFromTable(@"Unknown Artist", @"CompactDisc", @"") options:0 range:NSMakeRange(0, [customPath length])];
	else
		[customPath replaceOccurrencesOfString:@"{albumArtist}" withString:MakeStringSafeForFilename(albumArtist) options:0 range:NSMakeRange(0, [customPath length])];					

	if(nil == albumTitle)
		[customPath replaceOccurrencesOfString:@"{albumTitle}" withString:@"Unknown Disc" options:0 range:NSMakeRange(0, [customPath length])];
	else
		[customPath replaceOccurrencesOfString:@"{albumTitle}" withString:MakeStringSafeForFilename(albumTitle) options:0 range:NSMakeRange(0, [customPath length])];

	if(nil == albumGenre)
		[customPath replaceOccurrencesOfString:@"{albumGenre}" withString:@"Unknown Genre" options:0 range:NSMakeRange(0, [customPath length])];
	else
		[customPath replaceOccurrencesOfString:@"{albumGenre}" withString:MakeStringSafeForFilename(albumGenre) options:0 range:NSMakeRange(0, [customPath length])];

	if(nil == albumYear)
		[customPath replaceOccurrencesOfString:@"{albumDate}" withString:@"Unknown Date" options:0 range:NSMakeRange(0, [customPath length])];
	else
		[customPath replaceOccurrencesOfString:@"{albumDate}" withString:MakeStringSafeForFilename(albumYear) options:0 range:NSMakeRange(0, [customPath length])];
	
	if(nil == albumComposer)
		[customPath replaceOccurrencesOfString:@"{albumComposer}" withString:@"Unknown Composer" options:0 range:NSMakeRange(0, [customPath length])];
	else
		[customPath replaceOccurrencesOfString:@"{albumComposer}" withString:MakeStringSafeForFilename(albumComposer) options:0 range:NSMakeRange(0, [customPath length])];

	if(nil == albumComment)
		[customPath replaceOccurrencesOfString:@"{albumComment}" withString:@"" options:0 range:NSMakeRange(0, [customPath length])];
	else
		[customPath replaceOccurrencesOfString:@"{albumComment}" withString:MakeStringSafeForFilename(albumComment) options:0 range:NSMakeRange(0, [customPath length])];

	if(nil == trackNumber)
		[customPath replaceOccurrencesOfString:@"{trackNumber}" withString:@"" options:0 range:NSMakeRange(0, [customPath length])];
	else
		[customPath replaceOccurrencesOfString:@"{trackNumber}" withString:[NSString stringWithFormat:@"%u", [trackNumber intValue]] options:0 range:NSMakeRange(0, [customPath length])];

	if(nil == trackTotal)
		[customPath replaceOccurrencesOfString:@"{trackTotal}" withString:@"" options:0 range:NSMakeRange(0, [customPath length])];
	else
		[customPath replaceOccurrencesOfString:@"{trackTotal}" withString:[NSString stringWithFormat:@"%u", [trackTotal intValue]] options:0 range:NSMakeRange(0, [customPath length])];

	if(nil == trackArtist)
		[customPath replaceOccurrencesOfString:@"{trackArtist}" withString:NSLocalizedStringFromTable(@"Unknown Artist", @"CompactDisc", @"") options:0 range:NSMakeRange(0, [customPath length])];
	else
		[customPath replaceOccurrencesOfString:@"{trackArtist}" withString:MakeStringSafeForFilename(trackArtist) options:0 range:NSMakeRange(0, [customPath length])];

	if(nil == trackTitle)
		[customPath replaceOccurrencesOfString:@"{trackTitle}" withString:NSLocalizedStringFromTable(@"Unknown Track", @"CompactDisc", @"") options:0 range:NSMakeRange(0, [customPath length])];
	else
		[customPath replaceOccurrencesOfString:@"{trackTitle}" withString:MakeStringSafeForFilename(trackTitle) options:0 range:NSMakeRange(0, [customPath length])];

	if(nil == trackGenre)
		[customPath replaceOccurrencesOfString:@"{trackGenre}" withString:@"Unknown Genre" options:0 range:NSMakeRange(0, [customPath length])];
	else
		[customPath replaceOccurrencesOfString:@"{trackGenre}" withString:MakeStringSafeForFilename(trackGenre) options:0 range:NSMakeRange(0, [customPath length])];

	if(nil == trackYear)
		[customPath replaceOccurrencesOfString:@"{trackDate}" withString:@"Unknown Date" options:0 range:NSMakeRange(0, [customPath length])];
	else
		[customPath replaceOccurrencesOfString:@"{trackDate}" withString:MakeStringSafeForFilename(trackYear) options:0 range:NSMakeRange(0, [customPath length])];

	if(nil == trackComposer)
		[customPath replaceOccurrencesOfString:@"{trackComposer}" withString:@"Unknown Composer" options:0 range:NSMakeRange(0, [customPath length])];
	else
		[customPath replaceOccurrencesOfString:@"{trackComposer}" withString:MakeStringSafeForFilename(trackComposer) options:0 range:NSMakeRange(0, [customPath length])];

	if(nil == trackComment)
		[customPath replaceOccurrencesOfString:@"{trackComment}" withString:@"" options:0 range:NSMakeRange(0, [customPath length])];
	else
		[customPath replaceOccurrencesOfString:@"{trackComment}" withString:MakeStringSafeForFilename(trackComment) options:0 range:NSMakeRange(0, [customPath length])];

	return [customPath autorelease];
}

- (NSString *) description
{
	if([[self compilation] boolValue]) {
		NSString	*artist		= (nil != [self trackArtist] ? [self trackArtist] : [self albumArtist]);
		NSString	*title		= [self trackTitle];
		
		if(nil != artist && nil != title)
			return [NSString stringWithFormat:@"%@ - %@", artist, title];			
		else if(nil != artist)
			return [[artist retain] autorelease];
		else if(nil != title)
			return [[title retain] autorelease];
		else
			return nil;
	}
	else if(nil != [self trackTitle])
		return [self trackTitle];
	else
		return nil;
}

- (BOOL) isEmpty
{
	return (
			nil		== [self trackNumber] &&
			nil		== [self trackTotal] &&
			nil		== [self trackTitle] &&
			nil		== [self trackArtist] &&
			nil		== [self trackComposer] &&
			nil		== [self trackDate] &&
			nil		== [self trackGenre] &&
			nil		== [self trackComment] &&
			nil		== [self albumTitle] &&
			nil		== [self albumArtist] &&
			nil		== [self albumComposer] &&
			nil		== [self albumDate] &&
			nil		== [self albumGenre] &&
			nil		== [self albumComment] &&
			nil		== [self compilation] &&
			nil		== [self discNumber] &&
			nil		== [self discTotal] &&
			nil		== [self length] &&
			nil		== [self albumArt] &&
			nil		== [self discId] &&
			nil		== [self MCN] &&
			nil		== [self ISRC] &&
			nil     == [self musicbrainzTrackId] &&
			nil     == [self musicbrainzArtistId] &&
			nil     == [self musicbrainzAlbumId] &&
			nil     == [self musicbrainzAlbumArtistId]
			);
}

#pragma mark Accessors

- (NSNumber *)	trackNumber					{ return [[_trackNumber retain] autorelease]; }
- (NSNumber *)	trackTotal					{ return [[_trackTotal retain] autorelease]; }
- (NSString *)	trackTitle					{ return [[_trackTitle retain] autorelease]; }
- (NSString *)	trackArtist					{ return [[_trackArtist retain] autorelease]; }
- (NSString	*)	trackComposer				{ return [[_trackComposer retain] autorelease]; }
- (NSString *)	trackDate					{ return [[_trackDate retain] autorelease]; }
- (NSString	*)	trackGenre					{ return [[_trackGenre retain] autorelease]; }
- (NSString	*)	trackComment				{ return [[_trackComment retain] autorelease]; }

- (NSString	*)	albumTitle					{ return [[_albumTitle retain] autorelease]; }
- (NSString	*)	albumArtist					{ return [[_albumArtist retain] autorelease]; }
- (NSString	*)	albumComposer				{ return [[_albumComposer retain] autorelease]; }
- (NSString *)	albumDate					{ return [[_albumDate retain] autorelease]; }
- (NSString	*)	albumGenre					{ return [[_albumGenre retain] autorelease]; }
- (NSString	*)	albumComment				{ return [[_albumComment retain] autorelease]; }

- (NSNumber *)	compilation					{ return [[_compilation retain] autorelease]; }
- (NSNumber *)	discNumber					{ return [[_discNumber retain] autorelease]; }
- (NSNumber *)	discTotal					{ return [[_discTotal retain] autorelease]; }

- (NSNumber *)	length						{ return [[_length retain] autorelease]; }

- (NSImage *)	albumArt					{ return [[_albumArt retain] autorelease]; }

- (NSString *)	MCN							{ return [[_MCN retain] autorelease]; }
- (NSString *)	ISRC						{ return [[_ISRC retain] autorelease]; }

- (NSString *)	discId						{ return [[_discId retain] autorelease]; }
- (NSString *)	musicbrainzTrackId			{ return [[_musicbrainzTrackId retain] autorelease]; }
- (NSString *)	musicbrainzArtistId			{ return [[_musicbrainzArtistId retain] autorelease]; }
- (NSString *)	musicbrainzAlbumId			{ return [[_musicbrainzAlbumId retain] autorelease]; }
- (NSString *)	musicbrainzAlbumArtistId    { return [[_musicbrainzAlbumArtistId retain] autorelease]; }

- (NSString *)	playlist					{ return [[_playlist retain] autorelease]; }

#pragma mark Mutators

- (void)		setTrackNumber:(NSNumber *)trackNumber			{ [_trackNumber release]; _trackNumber = [trackNumber retain]; }
- (void)		setTrackTotal:(NSNumber *)trackTotal			{ [_trackTotal release]; _trackTotal = [trackTotal retain]; }
- (void)		setTrackTitle:(NSString *)trackTitle			{ [_trackTitle release]; _trackTitle = [trackTitle retain]; }
- (void)		setTrackArtist:(NSString *)trackArtist			{ [_trackArtist release]; _trackArtist = [trackArtist retain]; }
- (void)		setTrackComposer:(NSString *)trackComposer		{ [_trackComposer release]; _trackComposer = [trackComposer retain]; }
- (void)		setTrackDate:(NSString*)trackDate				{ [_trackDate release]; _trackDate = [trackDate retain]; }
- (void)		setTrackGenre:(NSString *)trackGenre			{ [_trackGenre release]; _trackGenre = [trackGenre retain]; }
- (void)		setTrackComment:(NSString *)trackComment		{ [_trackComment release]; _trackComment = [trackComment retain]; }

- (void)		setAlbumTitle:(NSString *)albumTitle			{ [_albumTitle release]; _albumTitle = [albumTitle retain]; }
- (void)		setAlbumArtist:(NSString *)albumArtist			{ [_albumArtist release]; _albumArtist = [albumArtist retain]; }
- (void)		setAlbumComposer:(NSString *)albumComposer		{ [_albumComposer release]; _albumComposer = [albumComposer retain]; }
- (void)		setAlbumDate:(NSString *)albumDate				{ [_albumDate release]; _albumDate = [albumDate retain]; }
- (void)		setAlbumGenre:(NSString *)albumGenre			{ [_albumGenre release]; _albumGenre = [albumGenre retain]; }
- (void)		setAlbumComment:(NSString *)albumComment		{ [_albumComment release]; _albumComment = [albumComment retain]; }

- (void)		setCompilation:(NSNumber *)compilation			{ [_compilation release]; _compilation = [compilation retain]; }
- (void)		setDiscNumber:(NSNumber *)discNumber			{ [_discNumber release]; _discNumber = [discNumber retain]; }
- (void)		setDiscTotal:(NSNumber *)discTotal				{ [_discTotal release]; _discTotal = [discTotal retain]; }

- (void)		setLength:(NSNumber *)length					{ [_length release]; _length = [length retain]; }

- (void)		setAlbumArt:(NSImage *)albumArt					{ [_albumArt release]; _albumArt = [albumArt retain]; }

- (void)		setDiscId:(NSString *)discId					{ [_discId release]; _discId = [discId retain]; }
- (void)		setMCN:(NSString *)MCN							{ [_MCN release]; _MCN = [MCN retain]; }
- (void)		setISRC:(NSString *)ISRC						{ [_ISRC release]; _ISRC = [ISRC retain]; }

- (void)		setMusicbrainzTrackId:(NSString *)musicbrainzTrackId
                { [_musicbrainzTrackId release]; _musicbrainzTrackId = [musicbrainzTrackId retain]; }
- (void)		setMusicbrainzArtistId:(NSString *)musicbrainzArtistId
                { [_musicbrainzArtistId release]; _musicbrainzArtistId = [musicbrainzArtistId retain]; }
- (void)		setMusicbrainzAlbumId:(NSString *)musicbrainzAlbumId
                { [_musicbrainzAlbumId release]; _musicbrainzAlbumId = [musicbrainzAlbumId retain]; }
- (void)		setMusicbrainzAlbumArtistId:(NSString *)musicbrainzAlbumArtistId
                { [_musicbrainzAlbumArtistId release]; _musicbrainzAlbumArtistId = [musicbrainzAlbumArtistId retain]; }

- (void)		setPlaylist:(NSString *)playlist				{ [_playlist release]; _playlist = [playlist retain]; }

@end

@implementation AudioMetadata (FileMetadata)

+ (AudioMetadata *) metadataFromFLACFile:(NSString *)filename
{
	unsigned						i;
	char							*fieldName			= NULL;
	char							*fieldValue			= NULL;
	NSMutableDictionary				*metadataDictionary;
	NSString						*key, *value;
	NSImage							*picture;
	
	AudioMetadata *result = [[AudioMetadata alloc] init];

	FLAC__Metadata_Chain *chain = FLAC__metadata_chain_new();
	NSAssert(NULL != chain, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));
	
	if(NO == FLAC__metadata_chain_read(chain, [filename fileSystemRepresentation])) {
		FLAC__metadata_chain_delete(chain);
		return [result autorelease];
	}
	
	FLAC__Metadata_Iterator *iterator = FLAC__metadata_iterator_new();
	NSAssert(NULL != iterator, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));
	
	FLAC__metadata_iterator_init(iterator, chain);
	
	do {
		FLAC__StreamMetadata *block = FLAC__metadata_iterator_get_block(iterator);
		
		if(NULL == block)
			break;
		
		switch(block->type) {					
			case FLAC__METADATA_TYPE_VORBIS_COMMENT:				
				metadataDictionary = [NSMutableDictionary dictionary];
				
				for(i = 0; i < block->data.vorbis_comment.num_comments; ++i) {
										
					// Let FLAC parse the comment for us
					if(NO == FLAC__metadata_object_vorbiscomment_entry_to_name_value_pair(block->data.vorbis_comment.comments[i], &fieldName, &fieldValue)) {
						// Ignore malformed comments
						continue;
					}

					key		= [[NSString alloc] initWithBytesNoCopy:fieldName length:strlen(fieldName) encoding:NSASCIIStringEncoding freeWhenDone:YES];
					value	= [[NSString alloc] initWithBytesNoCopy:fieldValue length:strlen(fieldValue) encoding:NSUTF8StringEncoding freeWhenDone:YES];
								
					if(NSOrderedSame == [key caseInsensitiveCompare:[self customizeFLACTag:@"ALBUM"]])
						[result setAlbumTitle:value];
					else if(NSOrderedSame == [key caseInsensitiveCompare:[self customizeFLACTag:@"ARTIST"]])
					{
						[result setTrackArtist:value];
						if(nil == [result albumArtist])
							[result setAlbumArtist:value];
					}
					else if(NSOrderedSame == [key caseInsensitiveCompare:[self customizeFLACTag:@"COMPOSER"]])
						[result setAlbumComposer:value];
					else if(NSOrderedSame == [key caseInsensitiveCompare:[self customizeFLACTag:@"GENRE"]])
						[result setAlbumGenre:value];
					else if(NSOrderedSame == [key caseInsensitiveCompare:[self customizeFLACTag:@"DATE"]])
						[result setAlbumDate:value];
					else if(NSOrderedSame == [key caseInsensitiveCompare:[self customizeFLACTag:@"DESCRIPTION"]])
						[result setAlbumComment:value];
					else if(NSOrderedSame == [key caseInsensitiveCompare:[self customizeFLACTag:@"TITLE"]])
						[result setTrackTitle:value];
					else if(NSOrderedSame == [key caseInsensitiveCompare:[self customizeFLACTag:@"TRACKNUMBER"]])
						[result setTrackNumber:[NSNumber numberWithInt:[value intValue]]];
					else if(NSOrderedSame == [key caseInsensitiveCompare:[self customizeFLACTag:@"TRACKTOTAL"]])
						 [result setTrackTotal:[NSNumber numberWithInt:[value intValue]]];
					else if(NSOrderedSame == [key caseInsensitiveCompare:[self customizeFLACTag:@"COMPILATION"]])
						  [result setCompilation:[NSNumber numberWithBool:(BOOL)[value intValue]]];
					else if(NSOrderedSame == [key caseInsensitiveCompare:[self customizeFLACTag:@"DISCNUMBER"]])
						   [result setDiscNumber:[NSNumber numberWithInt:[value intValue]]];
					else if(NSOrderedSame == [key caseInsensitiveCompare:[self customizeFLACTag:@"DISCTOTAL"]])
							[result setDiscTotal:[NSNumber numberWithInt:[value intValue]]];
					else if(NSOrderedSame == [key caseInsensitiveCompare:[self customizeFLACTag:@"ISRC"]])
						[result setISRC:value];
					else if(NSOrderedSame == [key caseInsensitiveCompare:[self customizeFLACTag:@"MCN"]])
						[result setMCN:value];
					else if(NSOrderedSame == [key caseInsensitiveCompare:[self customizeFLACTag:@"ALBUMARTIST"]])
						[result setAlbumArtist:value];					
					else if(NSOrderedSame == [key caseInsensitiveCompare:@"MUSICBRAINZ_TRACKID"])
						[result setMusicbrainzTrackId:value];					
					else if(NSOrderedSame == [key caseInsensitiveCompare:@"MUSICBRAINZ_ALBUMID"])
						[result setMusicbrainzAlbumId:value];					
					else if(NSOrderedSame == [key caseInsensitiveCompare:@"MUSICBRAINZ_ARTISTID"])
						[result setMusicbrainzArtistId:value];					
					else if(NSOrderedSame == [key caseInsensitiveCompare:@"MUSICBRAINZ_ALBUMARTISTID"])
						[result setMusicbrainzAlbumArtistId:value];					
					else if(NSOrderedSame == [key caseInsensitiveCompare:@"MUSICBRAINZ_DISCID"])
						[result setDiscId:value];					

					// Maintain backwards compability for the following tags
					else if(NSOrderedSame == [key caseInsensitiveCompare:@"YEAR"] && nil == [result albumDate])
						[result setAlbumDate:value];
					else if(NSOrderedSame == [key caseInsensitiveCompare:@"COMMENT"] && nil == [result albumComment])
						[result setAlbumComment:value];
					else if(NSOrderedSame == [key caseInsensitiveCompare:@"TOTALTRACKS"] && nil == [result trackTotal])
						 [result setTrackTotal:[NSNumber numberWithInt:[value intValue]]];
					else if(NSOrderedSame == [key caseInsensitiveCompare:@"DISCSINSET"] && nil == [result discTotal])
						  [result setDiscTotal:[NSNumber numberWithInt:[value intValue]]];
					
					[key release];
					[value release];
					
					fieldName	= NULL;
					fieldValue	= NULL;
				}
				break;
				
			case FLAC__METADATA_TYPE_PICTURE:
				picture = [[NSImage alloc] initWithData:[NSData dataWithBytes:block->data.picture.data length:block->data.picture.data_length]];
				if(nil != picture) {
					[result setAlbumArt:picture];
					[picture release];
				}
				break;
				
			case FLAC__METADATA_TYPE_STREAMINFO:
				[result setLength:[NSNumber numberWithUnsignedLong:(block->data.stream_info.total_samples * block->data.stream_info.sample_rate)]];
				break;
				
			case FLAC__METADATA_TYPE_PADDING:						break;
			case FLAC__METADATA_TYPE_APPLICATION:					break;
			case FLAC__METADATA_TYPE_SEEKTABLE:						break;
			case FLAC__METADATA_TYPE_CUESHEET:						break;
			case FLAC__METADATA_TYPE_UNDEFINED:						break;
			default:												break;
		}
	} while(FLAC__metadata_iterator_next(iterator));
	
	FLAC__metadata_iterator_delete(iterator);
	FLAC__metadata_chain_delete(chain);	
	
	return [result autorelease];
}

+ (AudioMetadata *) metadataFromMP3File:(NSString *)filename
{
	TagLib::MPEG::File						f						([filename fileSystemRepresentation], false);
	TagLib::ID3v2::AttachedPictureFrame		*picture				= NULL;
	TagLib::String							s;
	TagLib::ID3v2::Tag						*id3v2tag;
	NSString								*trackString, *trackNum, *totalTracks;
	NSString								*discString, *discNum, *totalDiscs;
	NSRange									range;
	
	
	AudioMetadata *result = [[AudioMetadata alloc] init];
	
	if(f.isValid()) {
		
		// Album title
		s = f.tag()->album();
		if(!s.isEmpty())
			[result setAlbumTitle:[NSString stringWithUTF8String:s.toCString(true)]];
		
		// Artist
		s = f.tag()->artist();
		if(!s.isEmpty())
			[result setAlbumArtist:[NSString stringWithUTF8String:s.toCString(true)]];
		
		// Genre
		s = f.tag()->genre();
		if(!s.isEmpty())
			[result setAlbumGenre:[NSString stringWithUTF8String:s.toCString(true)]];
		
		// Year
		if(0 != f.tag()->year())
			[result setAlbumDate:[NSString stringWithFormat:@"%i", f.tag()->year()]];
		
		// Comment
		s = f.tag()->comment();
		if(!s.isEmpty())
			[result setAlbumComment:[NSString stringWithUTF8String:s.toCString(true)]];
		
		// Track title
		s = f.tag()->title();
		if(!s.isEmpty())
			[result setTrackTitle:[NSString stringWithUTF8String:s.toCString(true)]];
		
		// Track number
		if(0 != f.tag()->track())
			[result setTrackNumber:[NSNumber numberWithInt:f.tag()->track()]];
		
		// Length
		if(NULL != f.audioProperties() && 0 != f.audioProperties()->lengthInSeconds())
			[result setLength:[NSNumber numberWithInt:f.audioProperties()->lengthInSeconds()]];
		
		id3v2tag = f.ID3v2Tag();
		
		if(NULL != id3v2tag) {
			
			// Extract composer if present
			TagLib::ID3v2::FrameList frameList = id3v2tag->frameListMap()["TCOM"];
			if(NO == frameList.isEmpty())
				[result setAlbumComposer:[NSString stringWithUTF8String:frameList.front()->toString().toCString(true)]];
			
			// Extract total tracks if present
			frameList = id3v2tag->frameListMap()["TRCK"];
			if(NO == frameList.isEmpty()) {
				// Split the tracks at '/'
				trackString		= [NSString stringWithUTF8String:frameList.front()->toString().toCString(true)];
				range			= [trackString rangeOfString:@"/" options:NSLiteralSearch];
				
				if(NSNotFound != range.location && 0 != range.length) {
					trackNum		= [trackString substringToIndex:range.location];
					totalTracks		= [trackString substringFromIndex:range.location + 1];
					
					[result setTrackNumber:[NSNumber numberWithInt:[trackNum intValue]]];
					[result setTrackTotal:[NSNumber numberWithInt:[totalTracks intValue]]];
				}
				else
					[result setTrackNumber:[NSNumber numberWithInt:[trackString intValue]]];
			}
			
			// Extract track length if present
			frameList = id3v2tag->frameListMap()["TLEN"];
			if(NO == frameList.isEmpty()) {
				NSString *value = [NSString stringWithUTF8String:frameList.front()->toString().toCString(true)];
				[result setLength:[NSNumber numberWithInt:([value intValue] / 1000)]];
			}			
			
			// Extract disc number and total discs
			frameList = id3v2tag->frameListMap()["TPOS"];
			if(NO == frameList.isEmpty()) {
				// Split the tracks at '/'
				discString		= [NSString stringWithUTF8String:frameList.front()->toString().toCString(true)];
				range			= [discString rangeOfString:@"/" options:NSLiteralSearch];
				
				if(NSNotFound != range.location && 0 != range.length) {
					discNum			= [discString substringToIndex:range.location];
					totalDiscs		= [discString substringFromIndex:range.location + 1];
					
					[result setDiscNumber:[NSNumber numberWithInt:[discNum intValue]]];
					[result setDiscTotal:[NSNumber numberWithInt:[totalDiscs intValue]]];
				}
				else
					[result setDiscNumber:[NSNumber numberWithInt:[discString intValue]]];
			}

			// Extract album art if present
			frameList = id3v2tag->frameListMap()["APIC"];
			if(NO == frameList.isEmpty() && NULL != (picture = dynamic_cast<TagLib::ID3v2::AttachedPictureFrame *>(frameList.front()))) {
				TagLib::ByteVector bv = picture->picture();
				[result setAlbumArt:[[[NSImage alloc] initWithData:[NSData dataWithBytes:bv.data() length:bv.size()]] autorelease]];
			}
			
			// Extract compilation if present (iTunes TCMP tag)
			if([[NSUserDefaults standardUserDefaults] boolForKey:@"useiTunesWorkarounds"]) {
				frameList = id3v2tag->frameListMap()["TCMP"];
				// It seems that the presence of this frame indicates a compilation
				if(NO == frameList.isEmpty())
					[result setCompilation:[NSNumber numberWithBool:YES]];
			}

			// Extract ISRC if present
			frameList = id3v2tag->frameListMap()["TSRC"];
			if(NO == frameList.isEmpty()) {
				NSString *value = [NSString stringWithUTF8String:frameList.front()->toString().toCString(true)];
				[result setISRC:value];
			}			

			
			// MusicBrainz artist and album identifiers
			frameList = id3v2tag->frameList("TXXX");
			for(TagLib::ID3v2::FrameList::Iterator it = frameList.begin(); it != frameList.end(); ++it)
			{
				TagLib::ID3v2::UserTextIdentificationFrame *frame = (TagLib::ID3v2::UserTextIdentificationFrame *)(*it);
				const char* text = frame->fieldList().back().toCString(true);
				if (frame->description() == "MCN")
					[result setMCN: [NSString stringWithUTF8String:text]];
				else if (frame->description() == "MusicBrainz Artist Id")
					[result setMusicbrainzArtistId: [NSString stringWithUTF8String:text]];
				else if (frame->description() == "MusicBrainz Album Id")
					 [result setMusicbrainzAlbumId: [NSString stringWithUTF8String:text]];
				else if (frame->description() == "MusicBrainz Album Artist Id")
					  [result setMusicbrainzAlbumArtistId: [NSString stringWithUTF8String:text]];
				else if (frame->description() == "MusicBrainz Disc Id")
					[result setDiscId: [NSString stringWithUTF8String:text]];
			}
			
			// Unique file identifier (MusicBrainz track ID)
			frameList = id3v2tag->frameList("UFID");
			for(TagLib::ID3v2::FrameList::Iterator it = frameList.begin(); it != frameList.end(); ++it)
			{
				TagLib::ID3v2::UniqueFileIdentifierFrame *frame = (TagLib::ID3v2::UniqueFileIdentifierFrame *)(*it);
				if (frame->owner() == "http://musicbrainz.org") {
					s = TagLib::String(frame->identifier());
					[result setMusicbrainzTrackId: [NSString stringWithUTF8String:s.toCString(true)]];
				}
			}
		}
	}
	
	return [result autorelease];
}

+ (AudioMetadata *) metadataFromMP4File:(NSString *)filename
{
	AudioMetadata		*result			= [[AudioMetadata alloc] init];
	MP4FileHandle		mp4FileHandle	= MP4Read([filename fileSystemRepresentation]);
	
	if(MP4_INVALID_FILE_HANDLE != mp4FileHandle) {
		// Read the tags
		const MP4Tags *tags = MP4TagsAlloc();
		if(NULL == tags) {
			[result release];
			MP4Close(mp4FileHandle);		
			return nil;
		}
		
		MP4TagsFetch(tags, mp4FileHandle);

		// Album title
		if(tags->album)
			[result setAlbumTitle:[NSString stringWithUTF8String:tags->album]];

		// Artist
		if(tags->albumArtist)
			[result setAlbumArtist:[NSString stringWithUTF8String:tags->albumArtist]];
		else if(tags->artist)
			[result setAlbumArtist:[NSString stringWithUTF8String:tags->artist]];
		
		// Genre
		if(tags->genre)
			[result setAlbumGenre:[NSString stringWithUTF8String:tags->genre]];
		
		// Year
		if(tags->releaseDate)
			[result setAlbumDate:[NSString stringWithUTF8String:tags->releaseDate]];
		
		// Composer
		if(tags->composer)
			[result setAlbumComposer:[NSString stringWithUTF8String:tags->composer]];
		
		// Comment
		if(tags->comments)
			[result setAlbumComment:[NSString stringWithUTF8String:tags->comments]];
		
		// Track title
		if(tags->name)
			[result setTrackTitle:[NSString stringWithUTF8String:tags->name]];
		
		// Track number
		if(tags->track) {			
			if(tags->track->index)
				[result setTrackNumber:[NSNumber numberWithUnsignedShort:tags->track->index]];
			if(tags->track->total)
				[result setTrackTotal:[NSNumber numberWithUnsignedShort:tags->track->total]];
		}
		
		// Disc number
		if(tags->disk) {
			if(tags->disk->index)
				[result setDiscNumber:[NSNumber numberWithUnsignedShort:tags->disk->index]];
			if(tags->disk->total)
				[result setDiscTotal:[NSNumber numberWithUnsignedShort:tags->disk->total]];
		}
		
		// Compilation
		if(tags->compilation)
			[result setCompilation:[NSNumber numberWithBool:*(tags->compilation)]];
		
		// Length
		MP4Duration duration = MP4GetDuration(mp4FileHandle);
		uint32_t timeScale = MP4GetTimeScale(mp4FileHandle);
		if(duration)
			[result setLength:[NSNumber numberWithUnsignedLong:(duration / timeScale)]];
		
		// Album art
		if(tags->artworkCount) {
			MP4TagArtwork artwork = (tags->artwork)[0];
			NSData *artworkData = [NSData dataWithBytes:artwork.data length:artwork.size];
			[result setAlbumArt:[[[NSImage alloc] initWithData:artworkData] autorelease]];
		}
		
		MP4TagsFree(tags);
		MP4Close(mp4FileHandle);
	}
	
	return [result autorelease];
}

+ (AudioMetadata *)	metadataFromOggVorbisFile:(NSString *)filename
{
	AudioMetadata							*result;
	TagLib::Ogg::Vorbis::File				f						([filename fileSystemRepresentation], false);
	TagLib::String							s;
	TagLib::Ogg::XiphComment				*xiphComment;
	
	
	result = [[AudioMetadata alloc] init];
	
	if(f.isValid()) {
		
		xiphComment = f.tag();
		
		if(NULL != xiphComment) {
			TagLib::Ogg::FieldListMap		fieldList	= xiphComment->fieldListMap();
			NSString						*value		= nil;
			TagLib::String					tag;
			
			tag = [self customizeOggVorbisTag:@"ALBUM"];
			if(fieldList.contains(tag)) {
				value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
				[result setAlbumTitle:value];
			}
			
			tag = [self customizeOggVorbisTag:@"ARTIST"];
			if(fieldList.contains(tag)) {
				value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
				[result setAlbumArtist:value];
			}
			
			tag = [self customizeOggVorbisTag:@"GENRE"];
			if(fieldList.contains(tag)) {
				value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
				[result setAlbumGenre:value];
			}
			
			tag = [self customizeOggVorbisTag:@"DATE"];
			if(fieldList.contains(tag)) {
				value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
				[result setAlbumDate:value];
			}
			
			tag = [self customizeOggVorbisTag:@"DESCRIPTION"];
			if(fieldList.contains(tag)) {
				value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
				[result setAlbumComment:value];
			}
			
			tag = [self customizeOggVorbisTag:@"TITLE"];
			if(fieldList.contains(tag)) {
				value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
				[result setTrackTitle:value];
			}
			
			tag = [self customizeOggVorbisTag:@"TRACKNUMBER"];
			if(fieldList.contains(tag)) {
				value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
				[result setTrackNumber:[NSNumber numberWithInt:[value intValue]]];
			}
			
			tag = [self customizeOggVorbisTag:@"COMPOSER"];
			if(fieldList.contains(tag)) {
				value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
				[result setAlbumComposer:value];
			}
			
			tag = [self customizeOggVorbisTag:@"TRACKTOTAL"];
			if(fieldList.contains(tag)) {
				value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
				[result setTrackTotal:[NSNumber numberWithInt:[value intValue]]];
			}
			
			tag = [self customizeOggVorbisTag:@"DISCNUMBER"];
			if(fieldList.contains(tag)) {
				value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
				[result setDiscNumber:[NSNumber numberWithInt:[value intValue]]];
			}
			
			tag = [self customizeOggVorbisTag:@"DISCTOTAL"];
			if(fieldList.contains(tag)) {
				value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
				[result setDiscTotal:[NSNumber numberWithInt:[value intValue]]];
			}
			
			tag = [self customizeOggVorbisTag:@"COMPILATION"];
			if(fieldList.contains(tag)) {
				value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
				[result setCompilation:[NSNumber numberWithBool:(BOOL)[value intValue]]];
			}
			
			tag = [self customizeOggVorbisTag:@"ISRC"];
			if(fieldList.contains(tag)) {
				value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
				[result setISRC:value];
			}					
			
			tag = [self customizeOggVorbisTag:@"MCN"];
			if(fieldList.contains(tag)) {
				value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
				[result setMCN:value];
			}					
			
			if(fieldList.contains("MUSICBRAINZ_TRACKID")) {
				value = [NSString stringWithUTF8String:fieldList["MUSICBRAINZ_TRACKID"].toString().toCString(true)];
				[result setMusicbrainzTrackId:value];
			}					
			
			if(fieldList.contains("MUSICBRAINZ_ALBUMID")) {
				value = [NSString stringWithUTF8String:fieldList["MUSICBRAINZ_ALBUMID"].toString().toCString(true)];
				[result setMusicbrainzTrackId:value];
			}					
			
			if(fieldList.contains("MUSICBRAINZ_ARTISTID")) {
				value = [NSString stringWithUTF8String:fieldList["MUSICBRAINZ_ARTISTID"].toString().toCString(true)];
				[result setMusicbrainzArtistId:value];
			}					
			
			if(fieldList.contains("MUSICBRAINZ_ALBUMARTISTID")) {
				value = [NSString stringWithUTF8String:fieldList["MUSICBRAINZ_ALBUMARTISTID"].toString().toCString(true)];
				[result setMusicbrainzAlbumArtistId:value];
			}					
			
			if(fieldList.contains("MUSICBRAINZ_DISCID")) {
				value = [NSString stringWithUTF8String:fieldList["MUSICBRAINZ_DISCID"].toString().toCString(true)];
				[result setDiscId:value];
			}					
			
			// Maintain backwards compatibility for the following tags
			if(fieldList.contains("DISCSINSET") && 0 == [result discTotal]) {
				value = [NSString stringWithUTF8String:fieldList["DISCSINSET"].toString().toCString(true)];
				[result setDiscTotal:[NSNumber numberWithInt:[value intValue]]];
			}
			if(fieldList.contains("YEAR") && nil == [result albumDate]) {
				value = [NSString stringWithUTF8String:fieldList["YEAR"].toString().toCString(true)];
				[result setAlbumDate:value];
			}
			if(fieldList.contains("COMMENT") && nil == [result albumComment]) {
				value = [NSString stringWithUTF8String:fieldList["COMMENT"].toString().toCString(true)];
				[result setAlbumComment:value];
			}
		}
		
		// Length
		if(NULL != f.audioProperties() && 0 != f.audioProperties()->lengthInSeconds())
			[result setLength:[NSNumber numberWithInt:f.audioProperties()->lengthInSeconds()]];
	}
	
	return [result autorelease];
}

+ (AudioMetadata *)	metadataFromOggFLACFile:(NSString *)filename
{
	AudioMetadata							*result;
	TagLib::Ogg::FLAC::File					f						([filename fileSystemRepresentation], false);
	TagLib::String							s;
	TagLib::Ogg::XiphComment				*xiphComment;
	
	
	result = [[AudioMetadata alloc] init];
	
	if(f.isValid()) {
		
		xiphComment = f.tag();
		
		if(NULL != xiphComment) {
			TagLib::Ogg::FieldListMap		fieldList	= xiphComment->fieldListMap();
			NSString						*value		= nil;
			TagLib::String					tag;
			
			tag = [self customizeOggFLACTag:@"ALBUM"];
			if(fieldList.contains(tag)) {
				value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
				[result setAlbumTitle:value];
			}
			
			tag = [self customizeOggFLACTag:@"ARTIST"];
			if(fieldList.contains(tag)) {
				value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
				[result setAlbumArtist:value];
			}
			
			tag = [self customizeOggFLACTag:@"GENRE"];
			if(fieldList.contains(tag)) {
				value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
				[result setAlbumGenre:value];
			}
			
			tag = [self customizeOggFLACTag:@"DATE"];
			if(fieldList.contains(tag)) {
				value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
				[result setAlbumDate:value];
			}
			
			tag = [self customizeOggFLACTag:@"DESCRIPTION"];
			if(fieldList.contains(tag)) {
				value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
				[result setAlbumComment:value];
			}
			
			tag = [self customizeOggFLACTag:@"TITLE"];
			if(fieldList.contains(tag)) {
				value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
				[result setTrackTitle:value];
			}
			
			tag = [self customizeOggFLACTag:@"TRACKNUMBER"];
			if(fieldList.contains(tag)) {
				value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
				[result setTrackNumber:[NSNumber numberWithInt:[value intValue]]];
			}
			
			tag = [self customizeOggFLACTag:@"COMPOSER"];
			if(fieldList.contains(tag)) {
				value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
				[result setAlbumComposer:value];
			}
			
			tag = [self customizeOggFLACTag:@"TRACKTOTAL"];
			if(fieldList.contains(tag)) {
				value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
				[result setTrackTotal:[NSNumber numberWithInt:[value intValue]]];
			}
			
			tag = [self customizeOggFLACTag:@"DISCNUMBER"];
			if(fieldList.contains(tag)) {
				value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
				[result setDiscNumber:[NSNumber numberWithInt:[value intValue]]];
			}
			
			tag = [self customizeOggFLACTag:@"DISCTOTAL"];
			if(fieldList.contains(tag)) {
				value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
				[result setDiscTotal:[NSNumber numberWithInt:[value intValue]]];
			}
			
			tag = [self customizeOggFLACTag:@"COMPILATION"];
			if(fieldList.contains(tag)) {
				value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
				[result setCompilation:[NSNumber numberWithBool:(BOOL)[value intValue]]];
			}
			
			tag = [self customizeOggFLACTag:@"ISRC"];
			if(fieldList.contains(tag)) {
				value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
				[result setISRC:value];
			}					
			
			tag = [self customizeOggFLACTag:@"MCN"];
			if(fieldList.contains(tag)) {
				value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
				[result setMCN:value];
			}					
			
			if(fieldList.contains("MUSICBRAINZ_TRACKID")) {
				value = [NSString stringWithUTF8String:fieldList["MUSICBRAINZ_TRACKID"].toString().toCString(true)];
				[result setMusicbrainzTrackId:value];
			}					
			
			if(fieldList.contains("MUSICBRAINZ_ALBUMID")) {
				value = [NSString stringWithUTF8String:fieldList["MUSICBRAINZ_ALBUMID"].toString().toCString(true)];
				[result setMusicbrainzTrackId:value];
			}					
			
			if(fieldList.contains("MUSICBRAINZ_ARTISTID")) {
				value = [NSString stringWithUTF8String:fieldList["MUSICBRAINZ_ARTISTID"].toString().toCString(true)];
				[result setMusicbrainzArtistId:value];
			}					
			
			if(fieldList.contains("MUSICBRAINZ_ALBUMARTISTID")) {
				value = [NSString stringWithUTF8String:fieldList["MUSICBRAINZ_ALBUMARTISTID"].toString().toCString(true)];
				[result setMusicbrainzAlbumArtistId:value];
			}					
			
			if(fieldList.contains("MUSICBRAINZ_DISCID")) {
				value = [NSString stringWithUTF8String:fieldList["MUSICBRAINZ_DISCID"].toString().toCString(true)];
				[result setDiscId:value];
			}					
			
			// Maintain backwards compatibility for the following tags
			if(fieldList.contains("DISCSINSET") && nil == [result discTotal]) {
				value = [NSString stringWithUTF8String:fieldList["DISCSINSET"].toString().toCString(true)];
				[result setDiscTotal:[NSNumber numberWithInt:[value intValue]]];
			}
			if(fieldList.contains("YEAR") && nil == [result albumDate]) {
				value = [NSString stringWithUTF8String:fieldList["YEAR"].toString().toCString(true)];
				[result setAlbumDate:value];
			}
			if(fieldList.contains("COMMENT") && nil == [result albumComment]) {
				value = [NSString stringWithUTF8String:fieldList["COMMENT"].toString().toCString(true)];
				[result setAlbumComment:value];
			}
		}
		
		// Length
		if(NULL != f.audioProperties() && 0 != f.audioProperties()->lengthInSeconds())
			[result setLength:[NSNumber numberWithInt:f.audioProperties()->lengthInSeconds()]];
	}
	
	return [result autorelease];
}

+ (AudioMetadata *)	metadataFromOggSpeexFile:(NSString *)filename
{
	AudioMetadata							*result;
	TagLib::Ogg::Speex::File				f						([filename fileSystemRepresentation], false);
	TagLib::String							s;
	TagLib::Ogg::XiphComment				*xiphComment;
	
	
	result = [[AudioMetadata alloc] init];
	
	if(f.isValid()) {
		
		xiphComment = f.tag();
		
		if(NULL != xiphComment) {
			TagLib::Ogg::FieldListMap		fieldList	= xiphComment->fieldListMap();
			NSString						*value		= nil;
			TagLib::String					tag;
			
			tag = [self customizeOggFLACTag:@"ALBUM"];
			if(fieldList.contains(tag)) {
				value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
				[result setAlbumTitle:value];
			}
			
			tag = [self customizeOggFLACTag:@"ARTIST"];
			if(fieldList.contains(tag)) {
				value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
				[result setAlbumArtist:value];
			}
			
			tag = [self customizeOggFLACTag:@"GENRE"];
			if(fieldList.contains(tag)) {
				value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
				[result setAlbumGenre:value];
			}
			
			tag = [self customizeOggFLACTag:@"DATE"];
			if(fieldList.contains(tag)) {
				value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
				[result setAlbumDate:value];
			}
			
			tag = [self customizeOggFLACTag:@"DESCRIPTION"];
			if(fieldList.contains(tag)) {
				value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
				[result setAlbumComment:value];
			}
			
			tag = [self customizeOggFLACTag:@"TITLE"];
			if(fieldList.contains(tag)) {
				value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
				[result setTrackTitle:value];
			}
			
			tag = [self customizeOggFLACTag:@"TRACKNUMBER"];
			if(fieldList.contains(tag)) {
				value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
				[result setTrackNumber:[NSNumber numberWithInt:[value intValue]]];
			}
			
			tag = [self customizeOggFLACTag:@"COMPOSER"];
			if(fieldList.contains(tag)) {
				value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
				[result setAlbumComposer:value];
			}
			
			tag = [self customizeOggFLACTag:@"TRACKTOTAL"];
			if(fieldList.contains(tag)) {
				value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
				[result setTrackTotal:[NSNumber numberWithInt:[value intValue]]];
			}
			
			tag = [self customizeOggFLACTag:@"DISCNUMBER"];
			if(fieldList.contains(tag)) {
				value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
				[result setDiscNumber:[NSNumber numberWithInt:[value intValue]]];
			}
			
			tag = [self customizeOggFLACTag:@"DISCTOTAL"];
			if(fieldList.contains(tag)) {
				value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
				[result setDiscTotal:[NSNumber numberWithInt:[value intValue]]];
			}
			
			tag = [self customizeOggFLACTag:@"COMPILATION"];
			if(fieldList.contains(tag)) {
				value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
				[result setCompilation:[NSNumber numberWithBool:(BOOL)[value intValue]]];
			}
			
			tag = [self customizeOggFLACTag:@"ISRC"];
			if(fieldList.contains(tag)) {
				value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
				[result setISRC:value];
			}					
			
			tag = [self customizeOggFLACTag:@"MCN"];
			if(fieldList.contains(tag)) {
				value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
				[result setMCN:value];
			}					
			
			if(fieldList.contains("MUSICBRAINZ_TRACKID")) {
				value = [NSString stringWithUTF8String:fieldList["MUSICBRAINZ_TRACKID"].toString().toCString(true)];
				[result setMusicbrainzTrackId:value];
			}					
			
			if(fieldList.contains("MUSICBRAINZ_ALBUMID")) {
				value = [NSString stringWithUTF8String:fieldList["MUSICBRAINZ_ALBUMID"].toString().toCString(true)];
				[result setMusicbrainzTrackId:value];
			}					
			
			if(fieldList.contains("MUSICBRAINZ_ARTISTID")) {
				value = [NSString stringWithUTF8String:fieldList["MUSICBRAINZ_ARTISTID"].toString().toCString(true)];
				[result setMusicbrainzArtistId:value];
			}					
			
			if(fieldList.contains("MUSICBRAINZ_ALBUMARTISTID")) {
				value = [NSString stringWithUTF8String:fieldList["MUSICBRAINZ_ALBUMARTISTID"].toString().toCString(true)];
				[result setMusicbrainzAlbumArtistId:value];
			}					
			
			if(fieldList.contains("MUSICBRAINZ_DISCID")) {
				value = [NSString stringWithUTF8String:fieldList["MUSICBRAINZ_DISCID"].toString().toCString(true)];
				[result setDiscId:value];
			}					
			
			// Maintain backwards compatibility for the following tags
			if(fieldList.contains("DISCSINSET") && nil == [result discTotal]) {
				value = [NSString stringWithUTF8String:fieldList["DISCSINSET"].toString().toCString(true)];
				[result setDiscTotal:[NSNumber numberWithInt:[value intValue]]];
			}
			if(fieldList.contains("YEAR") && nil == [result albumDate]) {
				value = [NSString stringWithUTF8String:fieldList["YEAR"].toString().toCString(true)];
				[result setAlbumDate:value];
			}
			if(fieldList.contains("COMMENT") && nil == [result albumComment]) {
				value = [NSString stringWithUTF8String:fieldList["COMMENT"].toString().toCString(true)];
				[result setAlbumComment:value];
			}
		}
		
		// Length
		if(NULL != f.audioProperties() && 0 != f.audioProperties()->lengthInSeconds())
			[result setLength:[NSNumber numberWithInt:f.audioProperties()->lengthInSeconds()]];
	}
	
	return [result autorelease];
}

+ (AudioMetadata *) metadataFromMonkeysAudioFile:(NSString *)filename
{
	AudioMetadata					*result					= [[AudioMetadata alloc] init];
	APE::str_utfn					*chars					= NULL;
	APE::str_utfn					*tagName				= NULL;
	APE::CAPETag					*f						= NULL;
	APE::CAPETagField				*tag					= NULL;
	
	@try {
		chars = APE::CAPECharacterHelper::GetUTF16FromANSI([filename fileSystemRepresentation]);
		NSAssert(NULL != chars, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));

		f = new APE::CAPETag(chars);
		NSAssert(NULL != f, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));
		
		// Album title
		tagName = [self customizeAPETag:@"ALBUM"];
		tag = f->GetTagField(tagName);
		if(NULL != tag && tag->GetIsUTF8Text())
			[result setAlbumTitle:[NSString stringWithUTF8String:tag->GetFieldValue()]];
		free(tagName);
		
		// Artist
		tagName = [self customizeAPETag:@"ARTIST"];
		tag = f->GetTagField(tagName);
		if(NULL != tag && tag->GetIsUTF8Text())
			[result setAlbumArtist:[NSString stringWithUTF8String:tag->GetFieldValue()]];
		free(tagName);
		
		// Composer
		tagName = [self customizeAPETag:@"COMPOSER"];
		tag = f->GetTagField(tagName);
		if(NULL != tag && tag->GetIsUTF8Text())
			[result setAlbumComposer:[NSString stringWithUTF8String:tag->GetFieldValue()]];
		free(tagName);
		
		// Genre
		tagName = [self customizeAPETag:@"GENRE"];
		tag = f->GetTagField(tagName);
		if(NULL != tag && tag->GetIsUTF8Text())
			[result setAlbumGenre:[NSString stringWithUTF8String:tag->GetFieldValue()]];
		free(tagName);
		
		// Year
		tagName = [self customizeAPETag:@"YEAR"];
		tag = f->GetTagField(tagName);
		if(NULL != tag && tag->GetIsUTF8Text())
			[result setAlbumDate:[NSString stringWithUTF8String:tag->GetFieldValue()]];
		free(tagName);
		
		// Comment
		tagName = [self customizeAPETag:@"COMMENT"];
		tag = f->GetTagField(tagName);
		if(NULL != tag && tag->GetIsUTF8Text())
			[result setAlbumComment:[NSString stringWithUTF8String:tag->GetFieldValue()]];
		free(tagName);
		
		// Track title
		tagName = [self customizeAPETag:@"TITLE"];
		tag = f->GetTagField(tagName);
		if(NULL != tag && tag->GetIsUTF8Text()) {
			[result setTrackTitle:[NSString stringWithUTF8String:tag->GetFieldValue()]];
		}
		free(tagName);
		
		// Track number
		tagName = [self customizeAPETag:@"TRACK"];
		tag = f->GetTagField(tagName);
		if(NULL != tag && tag->GetIsUTF8Text())
			[result setTrackNumber:[NSNumber numberWithInt:[[NSString stringWithUTF8String:tag->GetFieldValue()] intValue]]];
		free(tagName);
		
		// Track total
		tagName = [self customizeAPETag:@"TRACKTOTAL"];
		tag = f->GetTagField(tagName);
		if(NULL != tag && tag->GetIsUTF8Text())
			[result setTrackTotal:[NSNumber numberWithInt:[[NSString stringWithUTF8String:tag->GetFieldValue()] intValue]]];
		free(tagName);
		
		// Disc number
		tagName = [self customizeAPETag:@"DISCNUMBER"];
		tag = f->GetTagField(tagName);
		if(NULL != tag && tag->GetIsUTF8Text())
			[result setDiscNumber:[NSNumber numberWithInt:[[NSString stringWithUTF8String:tag->GetFieldValue()] intValue]]];
		free(tagName);
		
		// Discs in set
		tagName = [self customizeAPETag:@"DISCTOTAL"];
		tag = f->GetTagField(tagName);
		if(NULL != tag && tag->GetIsUTF8Text())
			[result setDiscTotal:[NSNumber numberWithInt:[[NSString stringWithUTF8String:tag->GetFieldValue()] intValue]]];
		free(tagName);
		
		// Compilation
		tagName = [self customizeAPETag:@"COMPILATION"];
		tag = f->GetTagField(tagName);
		if(NULL != tag && tag->GetIsUTF8Text())
			[result setCompilation:[NSNumber numberWithBool:(BOOL)[[NSString stringWithUTF8String:tag->GetFieldValue()] intValue]]];
		free(tagName);
		
		// ISRC
		tagName = [self customizeAPETag:@"ISRC"];
		tag = f->GetTagField(tagName);
		if(NULL != tag && tag->GetIsUTF8Text())
			[result setISRC:[NSString stringWithUTF8String:tag->GetFieldValue()]];
		free(tagName);
		
		// MCN
		tagName = [self customizeAPETag:@"MCN"];
		tag = f->GetTagField(tagName);
		if(NULL != tag && tag->GetIsUTF8Text())
			[result setMCN:[NSString stringWithUTF8String:tag->GetFieldValue()]];
		free(tagName);
		
	}
	
	@finally {
		delete f;
		free(chars);
	}
	
	return [result autorelease];
}

+ (AudioMetadata *) metadataFromWavPackFile:(NSString *)filename
{
	AudioMetadata					*result					= [[AudioMetadata alloc] init];
	char							error [80];
	const char						*tagName				= NULL;
	char							*tagValue				= NULL;
    WavpackContext					*wpc					= NULL;
	int								len;
	
	@try {
		wpc = WavpackOpenFileInput([filename fileSystemRepresentation], error, OPEN_TAGS, 0);
		NSAssert(NULL != wpc, NSLocalizedStringFromTable(@"Unable to open the input file.", @"Exceptions", @""));
		
		// Album title
		tagName		= [[self customizeWavPackTag:@"ALBUM"] cStringUsingEncoding:NSASCIIStringEncoding];
		len			= WavpackGetTagItem(wpc, tagName, NULL, 0);
		if(0 != len) {
			tagValue = (char *)calloc(len + 1, sizeof(char));
			NSAssert(NULL != tagValue, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));

			WavpackGetTagItem(wpc, tagName, tagValue, len + 1);
			[result setAlbumTitle:[NSString stringWithUTF8String:tagValue]];
			free(tagValue);
		}
		
		// Artist
		tagName		= [[self customizeWavPackTag:@"ARTIST"] cStringUsingEncoding:NSASCIIStringEncoding];
		len			= WavpackGetTagItem(wpc, tagName, NULL, 0);
		if(0 != len) {
			tagValue = (char *)calloc(len + 1, sizeof(char));
			NSAssert(NULL != tagValue, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));

			WavpackGetTagItem(wpc, tagName, tagValue, len + 1);
			[result setAlbumArtist:[NSString stringWithUTF8String:tagValue]];
			free(tagValue);
		}
		
		// Composer
		tagName		= [[self customizeWavPackTag:@"COMPOSER"] cStringUsingEncoding:NSASCIIStringEncoding];
		len			= WavpackGetTagItem(wpc, tagName, NULL, 0);
		if(0 != len) {
			tagValue = (char *)calloc(len + 1, sizeof(char));
			NSAssert(NULL != tagValue, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));

			WavpackGetTagItem(wpc, tagName, tagValue, len + 1);
			[result setAlbumComposer:[NSString stringWithUTF8String:tagValue]];
			free(tagValue);
		}
		
		// Genre
		tagName		= [[self customizeWavPackTag:@"GENRE"] cStringUsingEncoding:NSASCIIStringEncoding];
		len			= WavpackGetTagItem(wpc, tagName, NULL, 0);
		if(0 != len) {
			tagValue = (char *)calloc(len + 1, sizeof(char));
			NSAssert(NULL != tagValue, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));

			WavpackGetTagItem(wpc, tagName, tagValue, len + 1);
			[result setAlbumGenre:[NSString stringWithUTF8String:tagValue]];
			free(tagValue);
		}
		
		// Year
		tagName		= [[self customizeWavPackTag:@"YEAR"] cStringUsingEncoding:NSASCIIStringEncoding];
		len			= WavpackGetTagItem(wpc, tagName, NULL, 0);
		if(0 != len) {
			tagValue = (char *)calloc(len + 1, sizeof(char));
			NSAssert(NULL != tagValue, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));

			WavpackGetTagItem(wpc, tagName, tagValue, len + 1);
			[result setAlbumDate:[NSString stringWithUTF8String:tagValue]];
			free(tagValue);
		}
		
		// Comment
		tagName		= [[self customizeWavPackTag:@"COMMENT"] cStringUsingEncoding:NSASCIIStringEncoding];
		len			= WavpackGetTagItem(wpc, tagName, NULL, 0);
		if(0 != len) {
			tagValue = (char *)calloc(len + 1, sizeof(char));
			NSAssert(NULL != tagValue, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));

			WavpackGetTagItem(wpc, tagName, tagValue, len + 1);
			[result setAlbumComment:[NSString stringWithUTF8String:tagValue]];
			free(tagValue);
		}
		
		// Track title
		tagName		= [[self customizeWavPackTag:@"TITLE"] cStringUsingEncoding:NSASCIIStringEncoding];
		len			= WavpackGetTagItem(wpc, tagName, NULL, 0);
		if(0 != len) {
			tagValue = (char *)calloc(len + 1, sizeof(char));
			NSAssert(NULL != tagValue, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));

			WavpackGetTagItem(wpc, tagName, tagValue, len + 1);
			[result setTrackTitle:[NSString stringWithUTF8String:tagValue]];
			free(tagValue);
		}
		
		// Track number
		tagName		= [[self customizeWavPackTag:@"TRACK"] cStringUsingEncoding:NSASCIIStringEncoding];
		len			= WavpackGetTagItem(wpc, tagName, NULL, 0);
		if(0 != len) {
			tagValue = (char *)calloc(len + 1, sizeof(char));
			NSAssert(NULL != tagValue, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));

			WavpackGetTagItem(wpc, tagName, tagValue, len + 1);
			[result setTrackNumber:[NSNumber numberWithInt:[[NSString stringWithUTF8String:tagValue] intValue]]];
			free(tagValue);
		}
		
		// Total tracks
		tagName		= [[self customizeWavPackTag:@"TRACKTOTAL"] cStringUsingEncoding:NSASCIIStringEncoding];
		len			= WavpackGetTagItem(wpc, tagName, NULL, 0);
		if(0 != len) {
			tagValue = (char *)calloc(len + 1, sizeof(char));
			NSAssert(NULL != tagValue, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));

			WavpackGetTagItem(wpc, tagName, tagValue, len + 1);
			[result setTrackTotal:[NSNumber numberWithInt:[[NSString stringWithUTF8String:tagValue] intValue]]];
			free(tagValue);
		}
		
		// Disc number
		tagName		= [[self customizeWavPackTag:@"DISCNUMBER"] cStringUsingEncoding:NSASCIIStringEncoding];
		len			= WavpackGetTagItem(wpc, tagName, NULL, 0);
		if(0 != len) {
			tagValue = (char *)calloc(len + 1, sizeof(char));
			NSAssert(NULL != tagValue, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));

			WavpackGetTagItem(wpc, tagName, tagValue, len + 1);
			[result setDiscNumber:[NSNumber numberWithInt:[[NSString stringWithUTF8String:tagValue] intValue]]];
			free(tagValue);
		}
		
		// Discs in set
		tagName		= [[self customizeWavPackTag:@"DISCTOTAL"] cStringUsingEncoding:NSASCIIStringEncoding];
		len			= WavpackGetTagItem(wpc, tagName, NULL, 0);
		if(0 != len) {
			tagValue = (char *)calloc(len + 1, sizeof(char));
			NSAssert(NULL != tagValue, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));

			WavpackGetTagItem(wpc, tagName, tagValue, len + 1);
			[result setDiscTotal:[NSNumber numberWithInt:[[NSString stringWithUTF8String:tagValue] intValue]]];
			free(tagValue);
		}
		
		// Compilation
		tagName		= [[self customizeWavPackTag:@"COMPILATION"] cStringUsingEncoding:NSASCIIStringEncoding];
		len			= WavpackGetTagItem(wpc, tagName, NULL, 0);
		if(0 != len) {
			tagValue = (char *)calloc(len + 1, sizeof(char));
			NSAssert(NULL != tagValue, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));

			WavpackGetTagItem(wpc, tagName, tagValue, len + 1);
			[result setCompilation:[NSNumber numberWithBool:(BOOL)[[NSString stringWithUTF8String:tagValue] intValue]]];
			free(tagValue);
		}
		
		// MCN
		tagName		= [[self customizeWavPackTag:@"MCN"] cStringUsingEncoding:NSASCIIStringEncoding];
		len			= WavpackGetTagItem(wpc, tagName, NULL, 0);
		if(0 != len) {
			tagValue = (char *)calloc(len + 1, sizeof(char));
			NSAssert(NULL != tagValue, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));

			WavpackGetTagItem(wpc, tagName, tagValue, len + 1);
			[result setMCN:[NSString stringWithUTF8String:tagValue]];
			free(tagValue);
		}
		
		// ISRC
		tagName		= [[self customizeWavPackTag:@"ISRC"] cStringUsingEncoding:NSASCIIStringEncoding];
		len			= WavpackGetTagItem(wpc, tagName, NULL, 0);
		if(0 != len) {
			tagValue = (char *)calloc(len + 1, sizeof(char));
			NSAssert(NULL != tagValue, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));

			WavpackGetTagItem(wpc, tagName, tagValue, len + 1);
			[result setISRC:[NSString stringWithUTF8String:tagValue]];
			free(tagValue);
		}
	}
	
	@finally {
		WavpackCloseFile(wpc);
	}
	
	return [result autorelease];
}

+ (AudioMetadata *) metadataFromMusepackFile:(NSString *)filename
{
	AudioMetadata							*result;
	TagLib::MPC::File						f						([filename fileSystemRepresentation], false);
	TagLib::String							s;
	TagLib::ID3v1::Tag						*id3v1Tag;
	TagLib::APE::Tag						*apeTag;
	
	result = [[AudioMetadata alloc] init];
	
	if(f.isValid()) {
		
		// Album title
		s = f.tag()->album();
		if(!s.isEmpty())
			[result setAlbumTitle:[NSString stringWithUTF8String:s.toCString(true)]];
		
		// Artist
		s = f.tag()->artist();
		if(!s.isEmpty())
			[result setAlbumArtist:[NSString stringWithUTF8String:s.toCString(true)]];
		
		// Genre
		s = f.tag()->genre();
		if(!s.isEmpty())
			[result setAlbumGenre:[NSString stringWithUTF8String:s.toCString(true)]];
		
		// Year
		if(0 != f.tag()->year())
			[result setAlbumDate:[NSString stringWithFormat:@"%i", f.tag()->year()]];
		
		// Comment
		s = f.tag()->comment();
		if(!s.isEmpty())
			[result setAlbumComment:[NSString stringWithUTF8String:s.toCString(true)]];
		
		// Track title
		s = f.tag()->title();
		if(!s.isEmpty())
			[result setTrackTitle:[NSString stringWithUTF8String:s.toCString(true)]];
		
		// Track number
		if(0 != f.tag()->track())
			[result setTrackNumber:[NSNumber numberWithInt:f.tag()->track()]];
		
		// Length
		if(NULL != f.audioProperties() && 0 != f.audioProperties()->lengthInSeconds())
			[result setLength:[NSNumber numberWithInt:f.audioProperties()->lengthInSeconds()]];
		
		id3v1Tag = f.ID3v1Tag();
		if(NULL != id3v1Tag) {
			
		}
		
		apeTag = f.APETag();
		if(NULL != apeTag) {
			
		}
	}
	
	return [result autorelease];
}

+ (AudioMetadata *) metadataFromAIFFFile:(NSString *)filename
{
	TagLib::RIFF::AIFF::File				f						([filename fileSystemRepresentation], false);
	TagLib::ID3v2::AttachedPictureFrame		*picture				= NULL;
	TagLib::String							s;
	NSString								*trackString, *trackNum, *totalTracks;
	NSString								*discString, *discNum, *totalDiscs;
	NSRange									range;
	
	
	AudioMetadata *result = [[AudioMetadata alloc] init];
	
	if(f.isValid()) {
		
		// Album title
		s = f.tag()->album();
		if(!s.isEmpty())
			[result setAlbumTitle:[NSString stringWithUTF8String:s.toCString(true)]];
		
		// Artist
		s = f.tag()->artist();
		if(!s.isEmpty())
			[result setAlbumArtist:[NSString stringWithUTF8String:s.toCString(true)]];
		
		// Genre
		s = f.tag()->genre();
		if(!s.isEmpty())
			[result setAlbumGenre:[NSString stringWithUTF8String:s.toCString(true)]];
		
		// Year
		if(0 != f.tag()->year())
			[result setAlbumDate:[NSString stringWithFormat:@"%i", f.tag()->year()]];
		
		// Comment
		s = f.tag()->comment();
		if(!s.isEmpty())
			[result setAlbumComment:[NSString stringWithUTF8String:s.toCString(true)]];
		
		// Track title
		s = f.tag()->title();
		if(!s.isEmpty())
			[result setTrackTitle:[NSString stringWithUTF8String:s.toCString(true)]];
		
		// Track number
		if(0 != f.tag()->track())
			[result setTrackNumber:[NSNumber numberWithInt:f.tag()->track()]];
		
		// Length
		if(NULL != f.audioProperties() && 0 != f.audioProperties()->lengthInSeconds())
			[result setLength:[NSNumber numberWithInt:f.audioProperties()->lengthInSeconds()]];
		
		// Extract composer if present
		TagLib::ID3v2::FrameList frameList = f.tag()->frameListMap()["TCOM"];
		if(NO == frameList.isEmpty())
			[result setAlbumComposer:[NSString stringWithUTF8String:frameList.front()->toString().toCString(true)]];
		
		// Extract total tracks if present
		frameList = f.tag()->frameListMap()["TRCK"];
		if(NO == frameList.isEmpty()) {
			// Split the tracks at '/'
			trackString		= [NSString stringWithUTF8String:frameList.front()->toString().toCString(true)];
			range			= [trackString rangeOfString:@"/" options:NSLiteralSearch];
			
			if(NSNotFound != range.location && 0 != range.length) {
				trackNum		= [trackString substringToIndex:range.location];
				totalTracks		= [trackString substringFromIndex:range.location + 1];
				
				[result setTrackNumber:[NSNumber numberWithInt:[trackNum intValue]]];
				[result setTrackTotal:[NSNumber numberWithInt:[totalTracks intValue]]];
			}
			else
				[result setTrackNumber:[NSNumber numberWithInt:[trackString intValue]]];
		}
		
		// Extract track length if present
		frameList = f.tag()->frameListMap()["TLEN"];
		if(NO == frameList.isEmpty()) {
			NSString *value = [NSString stringWithUTF8String:frameList.front()->toString().toCString(true)];
			[result setLength:[NSNumber numberWithInt:([value intValue] / 1000)]];
		}			
		
		// Extract disc number and total discs
		frameList = f.tag()->frameListMap()["TPOS"];
		if(NO == frameList.isEmpty()) {
			// Split the tracks at '/'
			discString		= [NSString stringWithUTF8String:frameList.front()->toString().toCString(true)];
			range			= [discString rangeOfString:@"/" options:NSLiteralSearch];
			
			if(NSNotFound != range.location && 0 != range.length) {
				discNum			= [discString substringToIndex:range.location];
				totalDiscs		= [discString substringFromIndex:range.location + 1];
				
				[result setDiscNumber:[NSNumber numberWithInt:[discNum intValue]]];
				[result setDiscTotal:[NSNumber numberWithInt:[totalDiscs intValue]]];
			}
			else
				[result setDiscNumber:[NSNumber numberWithInt:[discString intValue]]];
		}
		
		// Extract album art if present
		frameList = f.tag()->frameListMap()["APIC"];
		if(NO == frameList.isEmpty() && NULL != (picture = dynamic_cast<TagLib::ID3v2::AttachedPictureFrame *>(frameList.front()))) {
			TagLib::ByteVector bv = picture->picture();
			[result setAlbumArt:[[[NSImage alloc] initWithData:[NSData dataWithBytes:bv.data() length:bv.size()]] autorelease]];
		}
		
		// Extract compilation if present (iTunes TCMP tag)
		if([[NSUserDefaults standardUserDefaults] boolForKey:@"useiTunesWorkarounds"]) {
			frameList = f.tag()->frameListMap()["TCMP"];
			// It seems that the presence of this frame indicates a compilation
			if(NO == frameList.isEmpty())
				[result setCompilation:[NSNumber numberWithBool:YES]];
		}
		
		// Extract ISRC if present
		frameList = f.tag()->frameListMap()["TSRC"];
		if(NO == frameList.isEmpty()) {
			NSString *value = [NSString stringWithUTF8String:frameList.front()->toString().toCString(true)];
			[result setISRC:value];
		}			
		
		
		// MusicBrainz artist and album identifiers
		frameList = f.tag()->frameList("TXXX");
		for(TagLib::ID3v2::FrameList::Iterator it = frameList.begin(); it != frameList.end(); ++it)
		{
			TagLib::ID3v2::UserTextIdentificationFrame *frame = (TagLib::ID3v2::UserTextIdentificationFrame *)(*it);
			const char* text = frame->fieldList().back().toCString(true);
			if (frame->description() == "MCN")
				[result setMCN: [NSString stringWithUTF8String:text]];
			else if (frame->description() == "MusicBrainz Artist Id")
				[result setMusicbrainzArtistId: [NSString stringWithUTF8String:text]];
			else if (frame->description() == "MusicBrainz Album Id")
				[result setMusicbrainzAlbumId: [NSString stringWithUTF8String:text]];
			else if (frame->description() == "MusicBrainz Album Artist Id")
				[result setMusicbrainzAlbumArtistId: [NSString stringWithUTF8String:text]];
			else if (frame->description() == "MusicBrainz Disc Id")
				[result setDiscId: [NSString stringWithUTF8String:text]];
		}
		
		// Unique file identifier (MusicBrainz track ID)
		frameList = f.tag()->frameList("UFID");
		for(TagLib::ID3v2::FrameList::Iterator it = frameList.begin(); it != frameList.end(); ++it)
		{
			TagLib::ID3v2::UniqueFileIdentifierFrame *frame = (TagLib::ID3v2::UniqueFileIdentifierFrame *)(*it);
			if (frame->owner() == "http://musicbrainz.org") {
				s = TagLib::String(frame->identifier());
				[result setMusicbrainzTrackId: [NSString stringWithUTF8String:s.toCString(true)]];
			}
		}
	}
	
	return [result autorelease];
}

+ (AudioMetadata *) metadataFromWAVEFile:(NSString *)filename
{
	TagLib::RIFF::WAV::File					f						([filename fileSystemRepresentation], false);
	TagLib::ID3v2::AttachedPictureFrame		*picture				= NULL;
	TagLib::String							s;
	NSString								*trackString, *trackNum, *totalTracks;
	NSString								*discString, *discNum, *totalDiscs;
	NSRange									range;
	
	
	AudioMetadata *result = [[AudioMetadata alloc] init];
	
	if(f.isValid()) {
		
		// Album title
		s = f.tag()->album();
		if(!s.isEmpty())
			[result setAlbumTitle:[NSString stringWithUTF8String:s.toCString(true)]];
		
		// Artist
		s = f.tag()->artist();
		if(!s.isEmpty())
			[result setAlbumArtist:[NSString stringWithUTF8String:s.toCString(true)]];
		
		// Genre
		s = f.tag()->genre();
		if(!s.isEmpty())
			[result setAlbumGenre:[NSString stringWithUTF8String:s.toCString(true)]];
		
		// Year
		if(0 != f.tag()->year())
			[result setAlbumDate:[NSString stringWithFormat:@"%i", f.tag()->year()]];
		
		// Comment
		s = f.tag()->comment();
		if(!s.isEmpty())
			[result setAlbumComment:[NSString stringWithUTF8String:s.toCString(true)]];
		
		// Track title
		s = f.tag()->title();
		if(!s.isEmpty())
			[result setTrackTitle:[NSString stringWithUTF8String:s.toCString(true)]];
		
		// Track number
		if(0 != f.tag()->track())
			[result setTrackNumber:[NSNumber numberWithInt:f.tag()->track()]];
		
		// Length
		if(NULL != f.audioProperties() && 0 != f.audioProperties()->lengthInSeconds())
			[result setLength:[NSNumber numberWithInt:f.audioProperties()->lengthInSeconds()]];
		
		// Extract composer if present
		TagLib::ID3v2::FrameList frameList = f.tag()->frameListMap()["TCOM"];
		if(NO == frameList.isEmpty())
			[result setAlbumComposer:[NSString stringWithUTF8String:frameList.front()->toString().toCString(true)]];
		
		// Extract total tracks if present
		frameList = f.tag()->frameListMap()["TRCK"];
		if(NO == frameList.isEmpty()) {
			// Split the tracks at '/'
			trackString		= [NSString stringWithUTF8String:frameList.front()->toString().toCString(true)];
			range			= [trackString rangeOfString:@"/" options:NSLiteralSearch];
			
			if(NSNotFound != range.location && 0 != range.length) {
				trackNum		= [trackString substringToIndex:range.location];
				totalTracks		= [trackString substringFromIndex:range.location + 1];
				
				[result setTrackNumber:[NSNumber numberWithInt:[trackNum intValue]]];
				[result setTrackTotal:[NSNumber numberWithInt:[totalTracks intValue]]];
			}
			else
				[result setTrackNumber:[NSNumber numberWithInt:[trackString intValue]]];
		}
		
		// Extract track length if present
		frameList = f.tag()->frameListMap()["TLEN"];
		if(NO == frameList.isEmpty()) {
			NSString *value = [NSString stringWithUTF8String:frameList.front()->toString().toCString(true)];
			[result setLength:[NSNumber numberWithInt:([value intValue] / 1000)]];
		}			
		
		// Extract disc number and total discs
		frameList = f.tag()->frameListMap()["TPOS"];
		if(NO == frameList.isEmpty()) {
			// Split the tracks at '/'
			discString		= [NSString stringWithUTF8String:frameList.front()->toString().toCString(true)];
			range			= [discString rangeOfString:@"/" options:NSLiteralSearch];
			
			if(NSNotFound != range.location && 0 != range.length) {
				discNum			= [discString substringToIndex:range.location];
				totalDiscs		= [discString substringFromIndex:range.location + 1];
				
				[result setDiscNumber:[NSNumber numberWithInt:[discNum intValue]]];
				[result setDiscTotal:[NSNumber numberWithInt:[totalDiscs intValue]]];
			}
			else
				[result setDiscNumber:[NSNumber numberWithInt:[discString intValue]]];
		}
		
		// Extract album art if present
		frameList = f.tag()->frameListMap()["APIC"];
		if(NO == frameList.isEmpty() && NULL != (picture = dynamic_cast<TagLib::ID3v2::AttachedPictureFrame *>(frameList.front()))) {
			TagLib::ByteVector bv = picture->picture();
			[result setAlbumArt:[[[NSImage alloc] initWithData:[NSData dataWithBytes:bv.data() length:bv.size()]] autorelease]];
		}
		
		// Extract compilation if present (iTunes TCMP tag)
		if([[NSUserDefaults standardUserDefaults] boolForKey:@"useiTunesWorkarounds"]) {
			frameList = f.tag()->frameListMap()["TCMP"];
			// It seems that the presence of this frame indicates a compilation
			if(NO == frameList.isEmpty())
				[result setCompilation:[NSNumber numberWithBool:YES]];
		}
		
		// Extract ISRC if present
		frameList = f.tag()->frameListMap()["TSRC"];
		if(NO == frameList.isEmpty()) {
			NSString *value = [NSString stringWithUTF8String:frameList.front()->toString().toCString(true)];
			[result setISRC:value];
		}			
		
		
		// MusicBrainz artist and album identifiers
		frameList = f.tag()->frameList("TXXX");
		for(TagLib::ID3v2::FrameList::Iterator it = frameList.begin(); it != frameList.end(); ++it)
		{
			TagLib::ID3v2::UserTextIdentificationFrame *frame = (TagLib::ID3v2::UserTextIdentificationFrame *)(*it);
			const char* text = frame->fieldList().back().toCString(true);
			if (frame->description() == "MCN")
				[result setMCN: [NSString stringWithUTF8String:text]];
			else if (frame->description() == "MusicBrainz Artist Id")
				[result setMusicbrainzArtistId: [NSString stringWithUTF8String:text]];
			else if (frame->description() == "MusicBrainz Album Id")
				[result setMusicbrainzAlbumId: [NSString stringWithUTF8String:text]];
			else if (frame->description() == "MusicBrainz Album Artist Id")
				[result setMusicbrainzAlbumArtistId: [NSString stringWithUTF8String:text]];
			else if (frame->description() == "MusicBrainz Disc Id")
				[result setDiscId: [NSString stringWithUTF8String:text]];
		}
		
		// Unique file identifier (MusicBrainz track ID)
		frameList = f.tag()->frameList("UFID");
		for(TagLib::ID3v2::FrameList::Iterator it = frameList.begin(); it != frameList.end(); ++it)
		{
			TagLib::ID3v2::UniqueFileIdentifierFrame *frame = (TagLib::ID3v2::UniqueFileIdentifierFrame *)(*it);
			if (frame->owner() == "http://musicbrainz.org") {
				s = TagLib::String(frame->identifier());
				[result setMusicbrainzTrackId: [NSString stringWithUTF8String:s.toCString(true)]];
			}
		}
	}
	
	return [result autorelease];
}

@end

@implementation AudioMetadata (TagMappings)

+ (NSString *) customizeFLACTag:(NSString *)tag
{
	NSString *customTag;
	
	customTag = [[NSUserDefaults standardUserDefaults] stringForKey:[NSString stringWithFormat:@"FLACTag_%@", tag]];
	return (nil == customTag ? tag : customTag);
}

+ (TagLib::String) customizeOggVorbisTag:(NSString *)tag
{
	NSString *customTag;
	
	customTag = [[NSUserDefaults standardUserDefaults] stringForKey:[NSString stringWithFormat:@"OggVorbisTag_%@", tag]];
	return (nil == customTag ? TagLib::String([tag UTF8String], TagLib::String::UTF8) : TagLib::String([customTag UTF8String], TagLib::String::UTF8));
}

+ (TagLib::String) customizeOggFLACTag:(NSString *)tag
{
	NSString *customTag;
	
	customTag = [[NSUserDefaults standardUserDefaults] stringForKey:[NSString stringWithFormat:@"FLACTag_%@", tag]];
	return (nil == customTag ? TagLib::String([tag UTF8String], TagLib::String::UTF8) : TagLib::String([customTag UTF8String], TagLib::String::UTF8));
}

+ (APE::str_utfn *) customizeAPETag:(NSString *)tag
{
	NSString		*customTag		= nil;
	APE::str_utfn	*result			= NULL;
	
	customTag	= [[NSUserDefaults standardUserDefaults] stringForKey:[NSString stringWithFormat:@"APETag_%@", tag]];
	result		= APE::CAPECharacterHelper::GetUTF16FromUTF8((const unsigned char *)[(nil == customTag ? tag : customTag) UTF8String]);
	NSAssert(NULL != result, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));
	
	return result;
}

+ (NSString *) customizeWavPackTag:(NSString *)tag
{
	NSString *customTag;
	
	customTag = [[NSUserDefaults standardUserDefaults] stringForKey:[NSString stringWithFormat:@"WavPackTag_%@", tag]];
	return (nil == customTag ? tag : customTag);
}

@end
