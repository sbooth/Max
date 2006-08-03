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

#import "AudioMetadata.h"
#import "MallocException.h"
#import "IOException.h"
#import "UtilityFunctions.h"

#include <TagLib/fileref.h>					// TagLib::FileRef
#include <TagLib/mpegfile.h>				// TagLib::MPEG::File
#include <TagLib/vorbisfile.h>				// TagLib::Ogg::Vorbis::File
#include <TagLib/oggflacfile.h>				// TagLib::Ogg::FLAC::File
#include <TagLib/id3v2tag.h>				// TagLib::ID3v2::Tag
#include <TagLib/id3v2frame.h>				// TagLib::ID3v2::Frame
#include <TagLib/attachedpictureframe.h>	// TagLib::ID3V2::AttachedPictureFrame
#include <TagLib/xiphcomment.h>				// TagLib::Ogg::XiphComment
#include <TagLib/tbytevector.h>				// TagLib::ByteVector

#include <mp4v2/mp4.h>						// MP4FileHandle

#include <MAC/All.h>
#include <MAC/MACLib.h>
#include <MAC/APETag.h>
#include <MAC/CharacterHelper.h>

#include <WavPack/wputils.h>

@interface AudioMetadata (Private)
+ (AudioMetadata *)		metadataFromFLACFile:(NSString *)filename;
+ (AudioMetadata *)		metadataFromMP3File:(NSString *)filename;
+ (AudioMetadata *)		metadataFromMP4File:(NSString *)filename;
+ (AudioMetadata *)		metadataFromOggVorbisFile:(NSString *)filename;
+ (AudioMetadata *)		metadataFromOggFLACFile:(NSString *)filename;
+ (AudioMetadata *)		metadataFromMonkeysAudioFile:(NSString *)filename;
+ (AudioMetadata *)		metadataFromWavPackFile:(NSString *)filename;
@end

@interface AudioMetadata (TagMappings)
+ (NSString *)			customizeFLACTag:(NSString *)tag;
+ (TagLib::String)		customizeOggVorbisTag:(NSString *)tag;
+ (TagLib::String)		customizeOggFLACTag:(NSString *)tag;
+ (str_utf16 *)			customizeAPETag:(NSString *)tag;
+ (NSString *)			customizeWavPackTag:(NSString *)tag;
@end

@implementation AudioMetadata

+ (BOOL) accessInstanceVariablesDirectly { return NO; }

// Attempt to parse metadata from filename
+ (AudioMetadata *) metadataFromFile:(NSString *)filename
{
	NSString *extension = [filename pathExtension];
	
	if([extension isEqualToString:@"flac"]) {
		return [self metadataFromFLACFile:filename];
	}
	else if([extension isEqualToString:@"mp3"]) {
		return [self metadataFromMP3File:filename];
	}
	else if([extension isEqualToString:@"mp4"] || [extension isEqualToString:@"m4a"]) {
		return [self metadataFromMP4File:filename];
	}
	else if([extension isEqualToString:@"ogg"]) {
		return [self metadataFromOggVorbisFile:filename];
	}
	else if([extension isEqualToString:@"oggflac"]) {
		return [self metadataFromOggFLACFile:filename];
	}
	else if([extension isEqualToString:@"ape"] || [extension isEqualToString:@"apl"] || [extension isEqualToString:@"mac"]) {
		return [self metadataFromMonkeysAudioFile:filename];
	}
	else if([extension isEqualToString:@"wv"]) {
		return [self metadataFromWavPackFile:filename];
	}
	else {
		return [[[AudioMetadata alloc] init] autorelease];
	}
}

+ (AudioMetadata *) metadataFromFLACFile:(NSString *)filename
{
	AudioMetadata								*result;
	FLAC__StreamMetadata						*tags, *currentTag, streaminfo;
	FLAC__StreamMetadata_VorbisComment_Entry	*comments;
	unsigned									i;
	NSString									*commentString, *key, *value;
	NSRange										range;
	
	result = [[AudioMetadata alloc] init];
	
	if(FLAC__metadata_get_tags([filename fileSystemRepresentation], &tags)) {
		
		currentTag = tags;
		
		for(;;) {
			
			switch(currentTag->type) {
				case FLAC__METADATA_TYPE_VORBIS_COMMENT:
					comments = currentTag->data.vorbis_comment.comments;
					
					for(i = 0; i < currentTag->data.vorbis_comment.num_comments; ++i) {
						
						// Split the comment at '='
						commentString	= [NSString stringWithUTF8String:(const char *)currentTag->data.vorbis_comment.comments[i].entry];
						range			= [commentString rangeOfString:@"=" options:NSLiteralSearch];
						
						// Sanity check (comments should be well-formed)
						if(NSNotFound != range.location && 0 != range.length) {
							key		= [commentString substringToIndex:range.location];
							value	= [commentString substringFromIndex:range.location + 1];
							
							if(NSOrderedSame == [key caseInsensitiveCompare:[self customizeFLACTag:@"ALBUM"]]) {
								[result setAlbumTitle:value];
							}
							else if(NSOrderedSame == [key caseInsensitiveCompare:[self customizeFLACTag:@"ARTIST"]]) {
								[result setAlbumArtist:value];
							}
							else if(NSOrderedSame == [key caseInsensitiveCompare:[self customizeFLACTag:@"COMPOSER"]]) {
								[result setAlbumComposer:value];
							}
							else if(NSOrderedSame == [key caseInsensitiveCompare:[self customizeFLACTag:@"GENRE"]]) {
								[result setAlbumGenre:value];
							}
							else if(NSOrderedSame == [key caseInsensitiveCompare:[self customizeFLACTag:@"DATE"]]) {
								[result setAlbumYear:[value intValue]];
							}
							else if(NSOrderedSame == [key caseInsensitiveCompare:[self customizeFLACTag:@"DESCRIPTION"]]) {
								[result setAlbumComment:value];
							}
							else if(NSOrderedSame == [key caseInsensitiveCompare:[self customizeFLACTag:@"TITLE"]]) {
								[result setTrackTitle:value];
							}
							else if(NSOrderedSame == [key caseInsensitiveCompare:[self customizeFLACTag:@"TRACKNUMBER"]]) {
								[result setTrackNumber:[value intValue]];
							}
							else if(NSOrderedSame == [key caseInsensitiveCompare:[self customizeFLACTag:@"TRACKTOTAL"]]) {
								[result setAlbumTrackCount:[value intValue]];
							}
							else if(NSOrderedSame == [key caseInsensitiveCompare:[self customizeFLACTag:@"COMPILATION"]]) {
								[result setCompilation:[value intValue]];
							}
							else if(NSOrderedSame == [key caseInsensitiveCompare:[self customizeFLACTag:@"DISCNUMBER"]]) {
								[result setDiscNumber:[value intValue]];
							}
							else if(NSOrderedSame == [key caseInsensitiveCompare:[self customizeFLACTag:@"DISCTOTAL"]]) {
								[result setDiscTotal:[value intValue]];
							}
							else if(NSOrderedSame == [key caseInsensitiveCompare:[self customizeFLACTag:@"ISRC"]]) {
								[result setISRC:value];
							}
							else if(NSOrderedSame == [key caseInsensitiveCompare:[self customizeFLACTag:@"MCN"]]) {
								[result setMCN:value];
							}
							
							// Maintain backwards compability for the following tags
							else if(NSOrderedSame == [key caseInsensitiveCompare:@"YEAR"] && 0 == [result albumYear]) {
								[result setAlbumYear:[value intValue]];
							}
							else if(NSOrderedSame == [key caseInsensitiveCompare:@"COMMENT"] && nil == [result albumComment]) {
								[result setAlbumComment:value];
							}
							else if(NSOrderedSame == [key caseInsensitiveCompare:@"TOTALTRACKS"] && 0 == [result albumTrackCount]) {
								[result setAlbumTrackCount:[value intValue]];
							}
							else if(NSOrderedSame == [key caseInsensitiveCompare:@"DISCSINSET"] && 0 == [result discTotal]) {
								[result setDiscTotal:[value intValue]];
							}
						}							
					}
						break;
					
				default:
					break;
			}
			
			if(currentTag->is_last) {
				break;
			}
			else {
				++currentTag;
			}
		}
		
		FLAC__metadata_object_delete(tags);
	}
	
	// Get length
	if(FLAC__metadata_get_streaminfo([filename fileSystemRepresentation], &streaminfo) && FLAC__METADATA_TYPE_STREAMINFO == streaminfo.type) {
		[result setLength:(streaminfo.data.stream_info.total_samples * streaminfo.data.stream_info.sample_rate)];
	}
	
	return [result autorelease];
}

+ (AudioMetadata *) metadataFromMP3File:(NSString *)filename
{
	AudioMetadata							*result;
	TagLib::MPEG::File						f						([filename fileSystemRepresentation], false);
	TagLib::ID3v2::AttachedPictureFrame		*picture				= NULL;
	TagLib::String							s;
	TagLib::ID3v2::Tag						*id3v2tag;
	NSString								*trackString, *trackNum, *totalTracks;
	NSRange									range;
	
	
	result = [[AudioMetadata alloc] init];

	if(f.isValid()) {
			
		// Album title
		s = f.tag()->album();
		if(false == s.isNull()) {
			[result setAlbumTitle:[NSString stringWithUTF8String:s.toCString(true)]];
		}
		
		// Artist
		s = f.tag()->artist();
		if(false == s.isNull()) {
			[result setAlbumArtist:[NSString stringWithUTF8String:s.toCString(true)]];
		}
		
		// Genre
		s = f.tag()->genre();
		if(false == s.isNull()) {
			[result setAlbumGenre:[NSString stringWithUTF8String:s.toCString(true)]];
		}
		
		// Year
		if(0 != f.tag()->year()) {
			[result setAlbumYear:f.tag()->year()];
		}
		
		// Comment
		s = f.tag()->comment();
		if(false == s.isNull()) {
			[result setAlbumComment:[NSString stringWithUTF8String:s.toCString(true)]];
		}
		
		// Track title
		s = f.tag()->title();
		if(false == s.isNull()) {
			[result setTrackTitle:[NSString stringWithUTF8String:s.toCString(true)]];
		}
		
		// Track number
		if(0 != f.tag()->track()) {
			[result setTrackNumber:f.tag()->track()];
		}
		
		// Length
		if(NULL != f.audioProperties() && 0 != f.audioProperties()->length()) {
			[result setLength:f.audioProperties()->length()];
		}
		
		id3v2tag = f.ID3v2Tag();
		
		if(NULL != id3v2tag) {
			
			// Extract composer if present
			TagLib::ID3v2::FrameList frameList = id3v2tag->frameListMap()["TCOM"];
			if(NO == frameList.isEmpty()) {
				[result setAlbumComposer:[NSString stringWithUTF8String:frameList.front()->toString().toCString(true)]];
			}
			
			// Extract total tracks if present
			frameList = id3v2tag->frameListMap()["TRCK"];
			if(NO == frameList.isEmpty()) {
				// Split the tracks at '/'
				trackString		= [NSString stringWithUTF8String:frameList.front()->toString().toCString(true)];
				range			= [trackString rangeOfString:@"/" options:NSLiteralSearch];
				
				if(NSNotFound != range.location && 0 != range.length) {
					trackNum		= [trackString substringToIndex:range.location];
					totalTracks		= [trackString substringFromIndex:range.location + 1];
					
					[result setTrackNumber:[trackNum intValue]];
					[result setAlbumTrackCount:[totalTracks intValue]];
				}
				else {
					[result setTrackNumber:[trackString intValue]];
				}
			}
			
			// Extract track length if present
			frameList = id3v2tag->frameListMap()["TLEN"];
			if(NO == frameList.isEmpty()) {
				NSString *value = [NSString stringWithUTF8String:frameList.front()->toString().toCString(true)];
				[result setLength:([value intValue] / 1000)];
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
				if(NO == frameList.isEmpty()) {
					// Is it safe to assume this will only be 0 or 1?  (Probably not, it never is)
					NSString *value = [NSString stringWithUTF8String:frameList.front()->toString().toCString(true)];
					[result setCompilation:(BOOL)[value intValue]];
				}			
			}
		}
	}

	return [result autorelease];
}

+ (AudioMetadata *) metadataFromMP4File:(NSString *)filename
{
	AudioMetadata		*result			= [[AudioMetadata alloc] init];
	MP4FileHandle		mp4FileHandle	= MP4Read([filename fileSystemRepresentation], 0);

	if(MP4_INVALID_FILE_HANDLE != mp4FileHandle) {
		char			*s									= NULL;
		u_int16_t		trackNumber, totalTracks;
		u_int16_t		discNumber, discTotal;
		u_int8_t		compilation;
		u_int64_t		duration;
		u_int32_t		artCount;
		u_int8_t		*bytes								= NULL;
		u_int32_t		length								= 0;
		
		// Album title
		MP4GetMetadataAlbum(mp4FileHandle, &s);
		if(NULL != s) {
			[result setAlbumTitle:[NSString stringWithUTF8String:s]];
		}
		
		// Artist
		MP4GetMetadataArtist(mp4FileHandle, &s);
		if(NULL != s) {
			[result setAlbumArtist:[NSString stringWithUTF8String:s]];
		}
		
		// Genre
		MP4GetMetadataGenre(mp4FileHandle, &s);
		if(NULL != s) {
			[result setAlbumGenre:[NSString stringWithUTF8String:s]];
		}
		
		// Year
		MP4GetMetadataYear(mp4FileHandle, &s);
		if(NULL != s) {
			// Avoid atoi()
			[result setAlbumYear:[[NSString stringWithUTF8String:s] intValue]];
		}
		
		// Composer
		MP4GetMetadataWriter(mp4FileHandle, &s);
		if(NULL != s) {
			[result setAlbumComposer:[NSString stringWithUTF8String:s]];
		}

		// Comment
		MP4GetMetadataComment(mp4FileHandle, &s);
		if(NULL != s) {
			[result setAlbumComment:[NSString stringWithUTF8String:s]];
		}
		
		// Track title
		MP4GetMetadataName(mp4FileHandle, &s);
		if(NULL != s) {
			[result setTrackTitle:[NSString stringWithUTF8String:s]];
		}
		
		// Track number
		MP4GetMetadataTrack(mp4FileHandle, &trackNumber, &totalTracks);
		if(0 != trackNumber) {
			[result setTrackNumber:trackNumber];
		}
		if(0 != totalTracks) {
			[result setAlbumTrackCount:totalTracks];
		}
		
		// Disc number
		MP4GetMetadataDisk(mp4FileHandle, &discNumber, &discTotal);
		if(0 != discNumber) {
			[result setDiscNumber:discNumber];
		}
		if(0 != discTotal) {
			[result setDiscTotal:discTotal];
		}
		
		// Compilation
		MP4GetMetadataCompilation(mp4FileHandle, &compilation);
		if(compilation) {
			[result setCompilation:YES];
		}
		
		// Length
		duration = MP4GetDuration(mp4FileHandle);
		if(0 != duration) {
			[result setLength:(duration / MP4GetTimeScale(mp4FileHandle))];
		}
		
		// Album art
		artCount = MP4GetMetadataCoverArtCount(mp4FileHandle);
		if(0 < artCount) {
			MP4GetMetadataCoverArt(mp4FileHandle, &bytes, &length);
			[result setAlbumArt:[[[NSImage alloc] initWithData:[NSData dataWithBytes:bytes length:length]] autorelease]];
		}
		
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
				[result setAlbumYear:[value intValue]];
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
				[result setTrackNumber:[value intValue]];
			}
			
			tag = [self customizeOggVorbisTag:@"COMPOSER"];
			if(fieldList.contains(tag)) {
				value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
				[result setAlbumComposer:value];
			}
			
			tag = [self customizeOggVorbisTag:@"TRACKTOTAL"];
			if(fieldList.contains(tag)) {
				value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
				[result setAlbumTrackCount:[value intValue]];
			}
			
			tag = [self customizeOggVorbisTag:@"DISCNUMBER"];
			if(fieldList.contains(tag)) {
				value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
				[result setDiscNumber:[value intValue]];
			}
			
			tag = [self customizeOggVorbisTag:@"DISCTOTAL"];
			if(fieldList.contains(tag)) {
				value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
				[result setDiscTotal:[value intValue]];
			}
			
			tag = [self customizeOggVorbisTag:@"COMPILATION"];
			if(fieldList.contains(tag)) {
				value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
				[result setCompilation:(BOOL)[value intValue]];
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

			// Maintain backwards compatibility for the following tags
			if(fieldList.contains("DISCSINSET") && 0 == [result discTotal]) {
				value = [NSString stringWithUTF8String:fieldList["DISCSINSET"].toString().toCString(true)];
				[result setDiscTotal:[value intValue]];
			}
			if(fieldList.contains("YEAR") && 0 == [result albumYear]) {
				value = [NSString stringWithUTF8String:fieldList["YEAR"].toString().toCString(true)];
				[result setAlbumYear:[value intValue]];
			}
			if(fieldList.contains("COMMENT") && nil == [result albumComment]) {
				value = [NSString stringWithUTF8String:fieldList["COMMENT"].toString().toCString(true)];
				[result setAlbumComment:value];
			}
		}
		
		// Length
		if(NULL !=f.audioProperties() && 0 != f.audioProperties()->length()) {
			[result setLength:f.audioProperties()->length()];
		}
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
				[result setAlbumYear:[value intValue]];
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
				[result setTrackNumber:[value intValue]];
			}
			
			tag = [self customizeOggFLACTag:@"COMPOSER"];
			if(fieldList.contains(tag)) {
				value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
				[result setAlbumComposer:value];
			}
			
			tag = [self customizeOggFLACTag:@"TRACKTOTAL"];
			if(fieldList.contains(tag)) {
				value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
				[result setAlbumTrackCount:[value intValue]];
			}
			
			tag = [self customizeOggFLACTag:@"DISCNUMBER"];
			if(fieldList.contains(tag)) {
				value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
				[result setDiscNumber:[value intValue]];
			}
			
			tag = [self customizeOggFLACTag:@"DISCTOTAL"];
			if(fieldList.contains(tag)) {
				value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
				[result setDiscTotal:[value intValue]];
			}
			
			tag = [self customizeOggFLACTag:@"COMPILATION"];
			if(fieldList.contains(tag)) {
				value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
				[result setCompilation:(BOOL)[value intValue]];
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
			
			// Maintain backwards compatibility for the following tags
			if(fieldList.contains("DISCSINSET") && 0 == [result discTotal]) {
				value = [NSString stringWithUTF8String:fieldList["DISCSINSET"].toString().toCString(true)];
				[result setDiscTotal:[value intValue]];
			}
			if(fieldList.contains("YEAR") && 0 == [result albumYear]) {
				value = [NSString stringWithUTF8String:fieldList["YEAR"].toString().toCString(true)];
				[result setAlbumYear:[value intValue]];
			}
			if(fieldList.contains("COMMENT") && nil == [result albumComment]) {
				value = [NSString stringWithUTF8String:fieldList["COMMENT"].toString().toCString(true)];
				[result setAlbumComment:value];
			}
		}
		
		// Length
		if(NULL !=f.audioProperties() && 0 != f.audioProperties()->length()) {
			[result setLength:f.audioProperties()->length()];
		}
	}
	
	return [result autorelease];
}

+ (AudioMetadata *) metadataFromMonkeysAudioFile:(NSString *)filename
{
	AudioMetadata					*result					= [[AudioMetadata alloc] init];
	str_utf16						*chars					= NULL;
	str_utf16						*tagName				= NULL;
	CAPETag							*f						= NULL;
	CAPETagField					*tag					= NULL;		
	
	@try {
		chars = GetUTF16FromANSI([filename fileSystemRepresentation]);
		if(NULL == chars) {
			@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @"") 
											   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		f = new CAPETag(chars);
		if(NULL == f) {
			@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @"") 
											   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		// Album title
		tagName = [self customizeAPETag:@"ALBUM"];
		tag = f->GetTagField(tagName);
		if(NULL != tag && tag->GetIsUTF8Text()) {
			[result setAlbumTitle:[NSString stringWithUTF8String:tag->GetFieldValue()]];
		}
		free(tagName);
		
		// Artist
		tagName = [self customizeAPETag:@"ARTIST"];
		tag = f->GetTagField(tagName);
		if(NULL != tag && tag->GetIsUTF8Text()) {
			[result setAlbumArtist:[NSString stringWithUTF8String:tag->GetFieldValue()]];
		}
		free(tagName);
		
		// Composer
		tagName = [self customizeAPETag:@"COMPOSER"];
		tag = f->GetTagField(tagName);
		if(NULL != tag && tag->GetIsUTF8Text()) {
			[result setAlbumComposer:[NSString stringWithUTF8String:tag->GetFieldValue()]];
		}
		free(tagName);
		
		// Genre
		tagName = [self customizeAPETag:@"GENRE"];
		tag = f->GetTagField(tagName);
		if(NULL != tag && tag->GetIsUTF8Text()) {
			[result setAlbumGenre:[NSString stringWithUTF8String:tag->GetFieldValue()]];
		}
		free(tagName);
		
		// Year
		tagName = [self customizeAPETag:@"YEAR"];
		tag = f->GetTagField(tagName);
		if(NULL != tag && tag->GetIsUTF8Text()) {
			[result setAlbumYear:[[NSString stringWithUTF8String:tag->GetFieldValue()] intValue]];
		}
		free(tagName);
		
		// Comment
		tagName = [self customizeAPETag:@"COMMENT"];
		tag = f->GetTagField(tagName);
		if(NULL != tag && tag->GetIsUTF8Text()) {
			[result setAlbumComment:[NSString stringWithUTF8String:tag->GetFieldValue()]];
		}
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
		if(NULL != tag && tag->GetIsUTF8Text()) {
			[result setTrackNumber:[[NSString stringWithUTF8String:tag->GetFieldValue()] intValue]];
		}
		free(tagName);
		
		// Track total
		tagName = [self customizeAPETag:@"TRACKTOTAL"];
		tag = f->GetTagField(tagName);
		if(NULL != tag && tag->GetIsUTF8Text()) {
			[result setAlbumTrackCount:[[NSString stringWithUTF8String:tag->GetFieldValue()] intValue]];
		}
		free(tagName);
		
		// Disc number
		tagName = [self customizeAPETag:@"DISCNUMBER"];
		tag = f->GetTagField(tagName);
		if(NULL != tag && tag->GetIsUTF8Text()) {
			[result setDiscNumber:[[NSString stringWithUTF8String:tag->GetFieldValue()] intValue]];
		}
		free(tagName);
		
		// Discs in set
		tagName = [self customizeAPETag:@"DISCTOTAL"];
		tag = f->GetTagField(tagName);
		if(NULL != tag && tag->GetIsUTF8Text()) {
			[result setDiscTotal:[[NSString stringWithUTF8String:tag->GetFieldValue()] intValue]];
		}
		free(tagName);
		
		// Compilation
		tagName = [self customizeAPETag:@"COMPILATION"];
		tag = f->GetTagField(tagName);
		if(NULL != tag && tag->GetIsUTF8Text()) {
			[result setCompilation:(BOOL)[[NSString stringWithUTF8String:tag->GetFieldValue()] intValue]];
		}
		free(tagName);
		
		// ISRC
		tagName = [self customizeAPETag:@"ISRC"];
		tag = f->GetTagField(tagName);
		if(NULL != tag && tag->GetIsUTF8Text()) {
			[result setISRC:[NSString stringWithUTF8String:tag->GetFieldValue()]];
		}
		free(tagName);
		
		// MCN
		tagName = [self customizeAPETag:@"MCN"];
		tag = f->GetTagField(tagName);
		if(NULL != tag && tag->GetIsUTF8Text()) {
			[result setMCN:[NSString stringWithUTF8String:tag->GetFieldValue()]];
		}
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
		if(NULL == wpc) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to open the input file.", @"Exceptions", @"") 
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:error encoding:NSASCIIStringEncoding]] forKeys:[NSArray arrayWithObject:@"errorString"]]];
		}

		// Album title
		tagName		= [[self customizeWavPackTag:@"ALBUM"] cStringUsingEncoding:NSASCIIStringEncoding];
		len			= WavpackGetTagItem(wpc, tagName, NULL, 0);
		if(0 != len) {
			tagValue = (char *)calloc(len + 1, sizeof(char));
			if(NULL == tagValue) {
				@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @"") 
												   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}
			WavpackGetTagItem(wpc, tagName, tagValue, len + 1);
			[result setAlbumTitle:[NSString stringWithUTF8String:tagValue]];
			free(tagValue);
		}

		// Artist
		tagName		= [[self customizeWavPackTag:@"ARTIST"] cStringUsingEncoding:NSASCIIStringEncoding];
		len			= WavpackGetTagItem(wpc, tagName, NULL, 0);
		if(0 != len) {
			tagValue = (char *)calloc(len + 1, sizeof(char));
			if(NULL == tagValue) {
				@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @"") 
												   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}
			WavpackGetTagItem(wpc, tagName, tagValue, len + 1);
			[result setAlbumArtist:[NSString stringWithUTF8String:tagValue]];
			free(tagValue);
		}

		// Composer
		tagName		= [[self customizeWavPackTag:@"COMPOSER"] cStringUsingEncoding:NSASCIIStringEncoding];
		len			= WavpackGetTagItem(wpc, tagName, NULL, 0);
		if(0 != len) {
			tagValue = (char *)calloc(len + 1, sizeof(char));
			if(NULL == tagValue) {
				@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @"") 
												   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}
			WavpackGetTagItem(wpc, tagName, tagValue, len + 1);
			[result setAlbumComposer:[NSString stringWithUTF8String:tagValue]];
			free(tagValue);
		}

		// Genre
		tagName		= [[self customizeWavPackTag:@"GENRE"] cStringUsingEncoding:NSASCIIStringEncoding];
		len			= WavpackGetTagItem(wpc, tagName, NULL, 0);
		if(0 != len) {
			tagValue = (char *)calloc(len + 1, sizeof(char));
			if(NULL == tagValue) {
				@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @"") 
												   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}
			WavpackGetTagItem(wpc, tagName, tagValue, len + 1);
			[result setAlbumGenre:[NSString stringWithUTF8String:tagValue]];
			free(tagValue);
		}

		// Year
		tagName		= [[self customizeWavPackTag:@"YEAR"] cStringUsingEncoding:NSASCIIStringEncoding];
		len			= WavpackGetTagItem(wpc, tagName, NULL, 0);
		if(0 != len) {
			tagValue = (char *)calloc(len + 1, sizeof(char));
			if(NULL == tagValue) {
				@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @"") 
												   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}
			WavpackGetTagItem(wpc, tagName, tagValue, len + 1);
			[result setAlbumYear:[[NSString stringWithUTF8String:tagValue] intValue]];
			free(tagValue);
		}

		// Comment
		tagName		= [[self customizeWavPackTag:@"COMMENT"] cStringUsingEncoding:NSASCIIStringEncoding];
		len			= WavpackGetTagItem(wpc, tagName, NULL, 0);
		if(0 != len) {
			tagValue = (char *)calloc(len + 1, sizeof(char));
			if(NULL == tagValue) {
				@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @"") 
												   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}
			WavpackGetTagItem(wpc, tagName, tagValue, len + 1);
			[result setAlbumComment:[NSString stringWithUTF8String:tagValue]];
			free(tagValue);
		}

		// Track title
		tagName		= [[self customizeWavPackTag:@"TITLE"] cStringUsingEncoding:NSASCIIStringEncoding];
		len			= WavpackGetTagItem(wpc, tagName, NULL, 0);
		if(0 != len) {
			tagValue = (char *)calloc(len + 1, sizeof(char));
			if(NULL == tagValue) {
				@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @"") 
												   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}
			WavpackGetTagItem(wpc, tagName, tagValue, len + 1);
			[result setTrackTitle:[NSString stringWithUTF8String:tagValue]];
			free(tagValue);
		}

		// Track number
		tagName		= [[self customizeWavPackTag:@"TRACK"] cStringUsingEncoding:NSASCIIStringEncoding];
		len			= WavpackGetTagItem(wpc, tagName, NULL, 0);
		if(0 != len) {
			tagValue = (char *)calloc(len + 1, sizeof(char));
			if(NULL == tagValue) {
				@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @"") 
												   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}
			WavpackGetTagItem(wpc, tagName, tagValue, len + 1);
			[result setTrackNumber:[[NSString stringWithUTF8String:tagValue] intValue]];
			free(tagValue);
		}

		// Total tracks
		tagName		= [[self customizeWavPackTag:@"TRACKTOTAL"] cStringUsingEncoding:NSASCIIStringEncoding];
		len			= WavpackGetTagItem(wpc, tagName, NULL, 0);
		if(0 != len) {
			tagValue = (char *)calloc(len + 1, sizeof(char));
			if(NULL == tagValue) {
				@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @"") 
												   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}
			WavpackGetTagItem(wpc, tagName, tagValue, len + 1);
			[result setAlbumTrackCount:[[NSString stringWithUTF8String:tagValue] intValue]];
			free(tagValue);
		}

		// Disc number
		tagName		= [[self customizeWavPackTag:@"DISCNUMBER"] cStringUsingEncoding:NSASCIIStringEncoding];
		len			= WavpackGetTagItem(wpc, tagName, NULL, 0);
		if(0 != len) {
			tagValue = (char *)calloc(len + 1, sizeof(char));
			if(NULL == tagValue) {
				@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @"") 
												   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}
			WavpackGetTagItem(wpc, tagName, tagValue, len + 1);
			[result setDiscNumber:[[NSString stringWithUTF8String:tagValue] intValue]];
			free(tagValue);
		}
		
		// Discs in set
		tagName		= [[self customizeWavPackTag:@"DISCTOTAL"] cStringUsingEncoding:NSASCIIStringEncoding];
		len			= WavpackGetTagItem(wpc, tagName, NULL, 0);
		if(0 != len) {
			tagValue = (char *)calloc(len + 1, sizeof(char));
			if(NULL == tagValue) {
				@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @"") 
												   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}
			WavpackGetTagItem(wpc, tagName, tagValue, len + 1);
			[result setDiscTotal:[[NSString stringWithUTF8String:tagValue] intValue]];
			free(tagValue);
		}

		// Compilation
		tagName		= [[self customizeWavPackTag:@"COMPILATION"] cStringUsingEncoding:NSASCIIStringEncoding];
		len			= WavpackGetTagItem(wpc, tagName, NULL, 0);
		if(0 != len) {
			tagValue = (char *)calloc(len + 1, sizeof(char));
			if(NULL == tagValue) {
				@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @"") 
												   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}
			WavpackGetTagItem(wpc, tagName, tagValue, len + 1);
			[result setCompilation:(BOOL)[[NSString stringWithUTF8String:tagValue] intValue]];
			free(tagValue);
		}

		// MCN
		tagName		= [[self customizeWavPackTag:@"MCN"] cStringUsingEncoding:NSASCIIStringEncoding];
		len			= WavpackGetTagItem(wpc, tagName, NULL, 0);
		if(0 != len) {
			tagValue = (char *)calloc(len + 1, sizeof(char));
			if(NULL == tagValue) {
				@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @"") 
												   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}
			WavpackGetTagItem(wpc, tagName, tagValue, len + 1);
			[result setMCN:[NSString stringWithUTF8String:tagValue]];
			free(tagValue);
		}

		// ISRC
		tagName		= [[self customizeWavPackTag:@"ISRC"] cStringUsingEncoding:NSASCIIStringEncoding];
		len			= WavpackGetTagItem(wpc, tagName, NULL, 0);
		if(0 != len) {
			tagValue = (char *)calloc(len + 1, sizeof(char));
			if(NULL == tagValue) {
				@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @"") 
												   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}
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

#pragma mark Custom Tag Mapping

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

+ (str_utf16 *) customizeAPETag:(NSString *)tag
{
	NSString		*customTag		= nil;
	str_utf16		*result			= NULL;
	
	customTag	= [[NSUserDefaults standardUserDefaults] stringForKey:[NSString stringWithFormat:@"APETag_%@", tag]];
	result		= GetUTF16FromUTF8((const unsigned char *)[(nil == customTag ? tag : customTag) UTF8String]);
	
	if(NULL == result) {
		@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @"") 
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
	}
	
	return result;
}

+ (NSString *) customizeWavPackTag:(NSString *)tag
{
	NSString *customTag;
	
	customTag = [[NSUserDefaults standardUserDefaults] stringForKey:[NSString stringWithFormat:@"WavPackTag_%@", tag]];
	return (nil == customTag ? tag : customTag);
}

#pragma mark Class

- (id) init
{
	if((self = [super init])) {
		
		_trackNumber		= 0;
		_trackTitle			= nil;
		_trackArtist		= nil;
		_trackComposer		= nil;
		_trackYear			= 0;
		_trackGenre			= nil;
		_trackComment		= nil;
		
		_albumTrackCount	= 0;
		_albumTitle			= nil;
		_albumArtist		= nil;
		_albumComposer		= nil;
		_albumYear			= 0;
		_albumGenre			= nil;
		_albumComment		= nil;
		
		_compilation		= NO;
		_discNumber			= 0;
		_discTotal			= 0;
		
		_length				= 0;
		
		_albumArt			= nil;
		
		_playlist			= nil;
		
		_MCN				= nil;
		_ISRC				= nil;
		
		return self;
	}
	
	return nil;
}

- (void) dealloc
{
	[_trackTitle release];
	[_trackArtist release];
	[_trackComposer release];
	[_trackGenre release];
	[_trackComment release];
	
	[_albumTitle release];
	[_albumArtist release];
	[_albumComposer release];
	[_albumGenre release];
	[_albumComment release];
	
	[_albumArt release];
	
	[_playlist release];
	
	[_MCN release];
	[_ISRC release];
	
	[super dealloc];
}

// Create output file's basename
- (NSString *) outputBasenameForDirectory:(NSString *)outputDirectory			{ return [self outputBasenameForDirectory:outputDirectory withSubstitutions:nil]; }

- (NSString *) outputBasenameForDirectory:(NSString *)outputDirectory withSubstitutions:(NSDictionary *)substitutions
{
	NSString		*basename;
		
	// Use custom naming scheme
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"useCustomNaming"]) {
		
		NSMutableString		*customPath			= [NSMutableString stringWithCapacity:100];
		NSString			*customNamingScheme = [[NSUserDefaults standardUserDefaults] stringForKey:@"customNamingScheme"];
		
		// Get the elements needed to build the pathname
		unsigned			discNumber			= [self discNumber];
		unsigned			discTotal			= [self discTotal];
		NSString			*discArtist			= [self albumArtist];
		NSString			*discTitle			= [self albumTitle];
		NSString			*discGenre			= [self albumGenre];
		unsigned			discYear			= [self albumYear];
		NSString			*discComposer		= [self albumComposer];
		NSString			*discComment		= [self albumComment];
		unsigned			trackNumber			= [self trackNumber];
		NSString			*trackArtist		= [self trackArtist];
		NSString			*trackTitle			= [self trackTitle];
		NSString			*trackGenre			= [self trackGenre];
		unsigned			trackYear			= [self trackYear];
		NSString			*trackComposer		= [self trackComposer];
		NSString			*trackComment		= [self trackComment];
		
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
			if(nil == trackComposer) {
				trackComposer = discComposer;
			}
			if(nil == trackComment) {
				trackComment = discComment;
			}
		}
		
		if(nil == customNamingScheme) {
			@throw [NSException exceptionWithName:@"NSObjectInaccessibleException" reason:@"The custom naming string appears to be invalid." userInfo:nil];
		}
		else {
			[customPath setString:customNamingScheme];
		}
		
		if(0 == discNumber) {
			[customPath replaceOccurrencesOfString:@"{discNumber}" withString:@"" options:nil range:NSMakeRange(0, [customPath length])];
		}
		else {
			[customPath replaceOccurrencesOfString:@"{discNumber}" withString:[NSString stringWithFormat:@"%u", discNumber] options:nil range:NSMakeRange(0, [customPath length])];					
		}
		if(0 == discTotal) {
			[customPath replaceOccurrencesOfString:@"{discTotal}" withString:@"" options:nil range:NSMakeRange(0, [customPath length])];
		}
		else {
			[customPath replaceOccurrencesOfString:@"{discTotal}" withString:[NSString stringWithFormat:@"%u", discTotal] options:nil range:NSMakeRange(0, [customPath length])];
		}
		if(nil == discArtist) {
			[customPath replaceOccurrencesOfString:@"{discArtist}" withString:NSLocalizedStringFromTable(@"Unknown Artist", @"CompactDisc", @"") options:nil range:NSMakeRange(0, [customPath length])];
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
		if(0 == discYear) {
			[customPath replaceOccurrencesOfString:@"{discYear}" withString:@"Unknown Year" options:nil range:NSMakeRange(0, [customPath length])];
		}
		else {
			[customPath replaceOccurrencesOfString:@"{discYear}" withString:[NSString stringWithFormat:@"%u", discYear] options:nil range:NSMakeRange(0, [customPath length])];
		}
		if(nil == discComposer) {
			[customPath replaceOccurrencesOfString:@"{discComposer}" withString:@"Unknown Composer" options:nil range:NSMakeRange(0, [customPath length])];
		}
		else {
			[customPath replaceOccurrencesOfString:@"{discComposer}" withString:makeStringSafeForFilename(discComposer) options:nil range:NSMakeRange(0, [customPath length])];
		}
		if(nil == discComment) {
			[customPath replaceOccurrencesOfString:@"{discComment}" withString:@"" options:nil range:NSMakeRange(0, [customPath length])];
		}
		else {
			[customPath replaceOccurrencesOfString:@"{discComment}" withString:makeStringSafeForFilename(discComment) options:nil range:NSMakeRange(0, [customPath length])];
		}
		if(0 == trackNumber) {
			[customPath replaceOccurrencesOfString:@"{trackNumber}" withString:@"" options:nil range:NSMakeRange(0, [customPath length])];
		}
		else {
			if([[NSUserDefaults standardUserDefaults] boolForKey:@"customNamingUseTwoDigitTrackNumbers"]) {
				[customPath replaceOccurrencesOfString:@"{trackNumber}" withString:[NSString stringWithFormat:@"%02u", trackNumber] options:nil range:NSMakeRange(0, [customPath length])];
			}
			else {
				[customPath replaceOccurrencesOfString:@"{trackNumber}" withString:[NSString stringWithFormat:@"%u", trackNumber] options:nil range:NSMakeRange(0, [customPath length])];
			}
		}
		if(nil == trackArtist) {
			[customPath replaceOccurrencesOfString:@"{trackArtist}" withString:NSLocalizedStringFromTable(@"Unknown Artist", @"CompactDisc", @"") options:nil range:NSMakeRange(0, [customPath length])];
		}
		else {
			[customPath replaceOccurrencesOfString:@"{trackArtist}" withString:makeStringSafeForFilename(trackArtist) options:nil range:NSMakeRange(0, [customPath length])];
		}
		if(nil == trackTitle) {
			[customPath replaceOccurrencesOfString:@"{trackTitle}" withString:NSLocalizedStringFromTable(@"Unknown Track", @"CompactDisc", @"") options:nil range:NSMakeRange(0, [customPath length])];
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
		if(0 == trackYear) {
			[customPath replaceOccurrencesOfString:@"{trackYear}" withString:@"Unknown Year" options:nil range:NSMakeRange(0, [customPath length])];
		}
		else {
			[customPath replaceOccurrencesOfString:@"{trackYear}" withString:[NSString stringWithFormat:@"%u", trackYear] options:nil range:NSMakeRange(0, [customPath length])];
		}
		if(nil == trackComposer) {
			[customPath replaceOccurrencesOfString:@"{trackComposer}" withString:@"Unknown Composer" options:nil range:NSMakeRange(0, [customPath length])];
		}
		else {
			[customPath replaceOccurrencesOfString:@"{trackComposer}" withString:makeStringSafeForFilename(trackComposer) options:nil range:NSMakeRange(0, [customPath length])];
		}
		if(nil == trackComment) {
			[customPath replaceOccurrencesOfString:@"{trackComment}" withString:@"" options:nil range:NSMakeRange(0, [customPath length])];
		}
		else {
			[customPath replaceOccurrencesOfString:@"{trackComment}" withString:makeStringSafeForFilename(trackComment) options:nil range:NSMakeRange(0, [customPath length])];
		}
		
		// Perform additional substitutions as necessary
		if(nil != substitutions) {
			NSEnumerator	*enumerator			= [substitutions keyEnumerator];
			id				key;
			
			while((key = [enumerator nextObject])) {
				[customPath replaceOccurrencesOfString:[NSString stringWithFormat:@"{%@}", key] withString:makeStringSafeForFilename([substitutions valueForKey:key]) options:nil range:NSMakeRange(0, [customPath length])];
			}
		}
		
		basename = [NSString stringWithFormat:@"%@/%@", outputDirectory, customPath];
	}
	// Use standard iTunes-style naming for compilations: "Compilations/Album/DiscNumber-TrackNumber TrackTitle.mp3"
	else if([self compilation]) {
		NSString			*path;
		
		NSString			*discTitle			= [self albumTitle];
		NSString			*trackTitle			= [self trackTitle];
		
		if(nil == discTitle) {
			discTitle = NSLocalizedStringFromTable(@"Unknown Album", @"CompactDisc", @"");
		}
		if(nil == trackTitle) {
			trackTitle = NSLocalizedStringFromTable(@"Unknown Track", @"CompactDisc", @"");
		}
		
		path = [NSString stringWithFormat:@"%@/Compilations/%@", outputDirectory, makeStringSafeForFilename(discTitle)]; 
		
		if(0 == [self discNumber]) {
			basename = [NSString stringWithFormat:@"%@/%02u %@", path, [self trackNumber], makeStringSafeForFilename(trackTitle)];
		}
		else {
			basename = [NSString stringWithFormat:@"%@/%i-%02u %@", path, [self discNumber], [self trackNumber], makeStringSafeForFilename(trackTitle)];
		}
	}
	// Use standard iTunes-style naming: "Artist/Album/DiscNumber-TrackNumber TrackTitle.mp3"
	else {
		NSString			*path;
		
		NSString			*discArtist			= [self albumArtist];
		NSString			*trackArtist		= [self trackArtist];
		NSString			*artist;
		NSString			*discTitle			= [self albumTitle];
		NSString			*trackTitle			= [self trackTitle];
		
		artist = trackArtist;
		if(nil == artist) {
			artist = discArtist;
			if(nil == artist) {
				artist = NSLocalizedStringFromTable(@"Unknown Artist", @"CompactDisc", @"");
			}
		}
		if(nil == discTitle) {
			discTitle = NSLocalizedStringFromTable(@"Unknown Album", @"CompactDisc", @"");
		}
		if(nil == trackTitle) {
			trackTitle = NSLocalizedStringFromTable(@"Unknown Track", @"CompactDisc", @"");
		}
		
		path = [NSString stringWithFormat:@"%@/%@/%@", outputDirectory, makeStringSafeForFilename(artist), makeStringSafeForFilename(discTitle)]; 
		
		if(0 == [self discNumber]) {
			basename = [NSString stringWithFormat:@"%@/%02u %@", path, [self trackNumber], makeStringSafeForFilename(trackTitle)];
		}
		else {
			basename = [NSString stringWithFormat:@"%@/%i-%02u %@", path, [self discNumber], [self trackNumber], makeStringSafeForFilename(trackTitle)];
		}
	}
	
	return [[basename retain] autorelease];
}

- (NSString *) replaceKeywordsInString:(NSString *)namingScheme
{
	NSMutableString		*customPath			= [NSMutableString stringWithCapacity:100];
	
	// Get the elements needed for the substitutions
	unsigned			discNumber			= [self discNumber];
	unsigned			discTotal			= [self discTotal];
	NSString			*discArtist			= [self albumArtist];
	NSString			*discTitle			= [self albumTitle];
	NSString			*discGenre			= [self albumGenre];
	unsigned			discYear			= [self albumYear];
	NSString			*discComposer		= [self albumComposer];
	NSString			*discComment		= [self albumComment];
	unsigned			trackNumber			= [self trackNumber];
	NSString			*trackArtist		= [self trackArtist];
	NSString			*trackTitle			= [self trackTitle];
	NSString			*trackGenre			= [self trackGenre];
	unsigned			trackYear			= [self trackYear];
	NSString			*trackComposer		= [self trackComposer];
	NSString			*trackComment		= [self trackComment];
	
	if(nil == namingScheme) {
		@throw [NSException exceptionWithName:@"NSObjectInaccessibleException" reason:@"The custom naming string appears to be invalid." userInfo:nil];
	}
	else {
		[customPath setString:namingScheme];
	}
	
	if(0 == discNumber) {
		[customPath replaceOccurrencesOfString:@"{discNumber}" withString:@"" options:nil range:NSMakeRange(0, [customPath length])];
	}
	else {
		[customPath replaceOccurrencesOfString:@"{discNumber}" withString:[NSString stringWithFormat:@"%u", discNumber] options:nil range:NSMakeRange(0, [customPath length])];					
	}
	if(0 == discTotal) {
		[customPath replaceOccurrencesOfString:@"{discTotal}" withString:@"" options:nil range:NSMakeRange(0, [customPath length])];
	}
	else {
		[customPath replaceOccurrencesOfString:@"{discTotal}" withString:[NSString stringWithFormat:@"%u", discTotal] options:nil range:NSMakeRange(0, [customPath length])];
	}
	if(nil == discArtist) {
		[customPath replaceOccurrencesOfString:@"{discArtist}" withString:NSLocalizedStringFromTable(@"Unknown Artist", @"CompactDisc", @"") options:nil range:NSMakeRange(0, [customPath length])];
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
	if(0 == discYear) {
		[customPath replaceOccurrencesOfString:@"{discYear}" withString:@"Unknown Year" options:nil range:NSMakeRange(0, [customPath length])];
	}
	else {
		[customPath replaceOccurrencesOfString:@"{discYear}" withString:[NSString stringWithFormat:@"%u", discYear] options:nil range:NSMakeRange(0, [customPath length])];
	}
	if(nil == discComposer) {
		[customPath replaceOccurrencesOfString:@"{discComposer}" withString:@"Unknown Composer" options:nil range:NSMakeRange(0, [customPath length])];
	}
	else {
		[customPath replaceOccurrencesOfString:@"{discComposer}" withString:makeStringSafeForFilename(discComposer) options:nil range:NSMakeRange(0, [customPath length])];
	}
	if(nil == discComment) {
		[customPath replaceOccurrencesOfString:@"{discComment}" withString:@"" options:nil range:NSMakeRange(0, [customPath length])];
	}
	else {
		[customPath replaceOccurrencesOfString:@"{discComment}" withString:makeStringSafeForFilename(discComment) options:nil range:NSMakeRange(0, [customPath length])];
	}
	if(0 == trackNumber) {
		[customPath replaceOccurrencesOfString:@"{trackNumber}" withString:@"" options:nil range:NSMakeRange(0, [customPath length])];
	}
	else {
		[customPath replaceOccurrencesOfString:@"{trackNumber}" withString:[NSString stringWithFormat:@"%u", trackNumber] options:nil range:NSMakeRange(0, [customPath length])];
	}
	if(nil == trackArtist) {
		[customPath replaceOccurrencesOfString:@"{trackArtist}" withString:NSLocalizedStringFromTable(@"Unknown Artist", @"CompactDisc", @"") options:nil range:NSMakeRange(0, [customPath length])];
	}
	else {
		[customPath replaceOccurrencesOfString:@"{trackArtist}" withString:makeStringSafeForFilename(trackArtist) options:nil range:NSMakeRange(0, [customPath length])];
	}
	if(nil == trackTitle) {
		[customPath replaceOccurrencesOfString:@"{trackTitle}" withString:NSLocalizedStringFromTable(@"Unknown Track", @"CompactDisc", @"") options:nil range:NSMakeRange(0, [customPath length])];
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
	if(0 == trackYear) {
		[customPath replaceOccurrencesOfString:@"{trackYear}" withString:@"Unknown Year" options:nil range:NSMakeRange(0, [customPath length])];
	}
	else {
		[customPath replaceOccurrencesOfString:@"{trackYear}" withString:[NSString stringWithFormat:@"%u", trackYear] options:nil range:NSMakeRange(0, [customPath length])];
	}
	if(nil == trackComposer) {
		[customPath replaceOccurrencesOfString:@"{trackComposer}" withString:@"Unknown Composer" options:nil range:NSMakeRange(0, [customPath length])];
	}
	else {
		[customPath replaceOccurrencesOfString:@"{trackComposer}" withString:makeStringSafeForFilename(trackComposer) options:nil range:NSMakeRange(0, [customPath length])];
	}
	if(nil == trackComment) {
		[customPath replaceOccurrencesOfString:@"{trackComment}" withString:@"" options:nil range:NSMakeRange(0, [customPath length])];
	}
	else {
		[customPath replaceOccurrencesOfString:@"{trackComment}" withString:makeStringSafeForFilename(trackComment) options:nil range:NSMakeRange(0, [customPath length])];
	}

	return [[customPath retain] autorelease];
}

- (NSString *) description
{
	if([self compilation]) {
		NSString	*artist		= [self trackArtist];
		NSString	*title		= [self trackTitle];
		
		if(nil == artist) {
			artist = [self albumArtist];
			if(nil == artist) {
				artist = NSLocalizedStringFromTable(@"Unknown Artist", @"CompactDisc", @"");
			}
		}
		if(nil == title) {
			title = NSLocalizedStringFromTable(@"Unknown Title", @"CompactDisc", @"");
		}
		
		return [NSString stringWithFormat:@"%@ - %@", artist, title];			
	}
	else if(nil != [self trackTitle]) {
		return [NSString stringWithFormat:@"%@", [self trackTitle]];
	}
	else {
		return NSLocalizedStringFromTable(@"Unknown Track", @"CompactDisc", @"");
	}
}

- (BOOL) isEmpty
{
	return (
			0		== [self trackNumber] &&
			nil		== [self trackTitle] &&
			nil		== [self trackArtist] &&
			nil		== [self trackComposer] &&
			0		== [self trackYear] &&
			nil		== [self trackGenre] &&
			nil		== [self trackComment] &&
			0		== [self albumTrackCount] &&
			nil		== [self albumTitle] &&
			nil		== [self albumArtist] &&
			nil		== [self albumComposer] &&
			0		== [self albumYear] &&
			nil		== [self albumGenre] &&
			nil		== [self albumComment] &&
			NO		== [self compilation] &&
			0		== [self discNumber] &&
			0		== [self discTotal] &&
			0		== [self length] &&
			nil		== [self MCN] &&
			nil		== [self ISRC] &&
			nil		== [self albumArt]
			);
}

#pragma mark Accessors

- (unsigned)	trackNumber					{ return _trackNumber; }
- (unsigned)	trackTotal					{ return _albumTrackCount; }
- (NSString *)	trackTitle					{ return _trackTitle; }
- (NSString *)	trackArtist					{ return _trackArtist; }
- (NSString	*)	trackComposer				{ return _trackComposer; }
- (unsigned)	trackYear					{ return _trackYear; }
- (NSString	*)	trackGenre					{ return _trackGenre; }
- (NSString	*)	trackComment				{ return _trackComment; }

- (unsigned)	albumTrackCount				{ return _albumTrackCount; }
- (NSString	*)	albumTitle					{ return _albumTitle; }
- (NSString	*)	albumArtist					{ return _albumArtist; }
- (NSString	*)	albumComposer				{ return _albumComposer; }
- (unsigned)	albumYear					{ return _albumYear; }
- (NSString	*)	albumGenre					{ return _albumGenre; }
- (NSString	*)	albumComment				{ return _albumComment; }

- (BOOL)		compilation					{ return _compilation; }
- (unsigned)	discNumber					{ return _discNumber; }
- (unsigned)	discTotal					{ return _discTotal; }

- (unsigned)	length						{ return _length; }

- (NSString *)	MCN							{ return _MCN; }
- (NSString *)	ISRC						{ return _ISRC; }

- (NSImage *)	albumArt					{ return _albumArt; }

- (NSString *)	playlist					{ return _playlist; }

#pragma mark Mutators

- (void)		setTrackNumber:(unsigned)trackNumber			{ _trackNumber = trackNumber; }
- (void)		setTrackTotal:(unsigned)trackTotal				{ _albumTrackCount = trackTotal; }
- (void)		setTrackTitle:(NSString *)trackTitle			{ [_trackTitle release]; _trackTitle = [trackTitle retain]; }
- (void)		setTrackArtist:(NSString *)trackArtist			{ [_trackArtist release]; _trackArtist = [trackArtist retain]; }
- (void)		setTrackComposer:(NSString *)trackComposer		{ [_trackComposer release]; _trackComposer = [trackComposer retain]; }
- (void)		setTrackYear:(unsigned)trackYear				{ _trackYear = trackYear; }
- (void)		setTrackGenre:(NSString *)trackGenre			{ [_trackGenre release]; _trackGenre = [trackGenre retain]; }
- (void)		setTrackComment:(NSString *)trackComment		{ [_trackComment release]; _trackComment = [trackComment retain]; }

- (void)		setAlbumTrackCount:(unsigned)albumTrackCount	{ _albumTrackCount = albumTrackCount; }
- (void)		setAlbumTitle:(NSString *)albumTitle			{ [_albumTitle release]; _albumTitle = [albumTitle retain]; }
- (void)		setAlbumArtist:(NSString *)albumArtist			{ [_albumArtist release]; _albumArtist = [albumArtist retain]; }
- (void)		setAlbumComposer:(NSString *)albumComposer		{ [_albumComposer release]; _albumComposer = [albumComposer retain]; }
- (void)		setAlbumYear:(unsigned)albumYear				{ _albumYear = albumYear; }
- (void)		setAlbumGenre:(NSString *)albumGenre			{ [_albumGenre release]; _albumGenre = [albumGenre retain]; }
- (void)		setAlbumComment:(NSString *)albumComment		{ [_albumComment release]; _albumComment = [albumComment retain]; }

- (void)		setCompilation:(BOOL)compilation				{ _compilation = compilation; }
- (void)		setDiscNumber:(unsigned)discNumber				{ _discNumber = discNumber; }
- (void)		setDiscTotal:(unsigned)discTotal				{ _discTotal = discTotal; }

- (void)		setLength:(unsigned)length						{ _length = length; }

- (void)		setMCN:(NSString *)MCN							{ [_MCN release]; _MCN = [MCN retain]; }
- (void)		setISRC:(NSString *)ISRC						{ [_ISRC release]; _ISRC = [ISRC retain]; }

- (void)		setAlbumArt:(NSImage *)albumArt					{ [_albumArt release]; _albumArt = [albumArt retain]; }

- (void)		setPlaylist:(NSString *)playlist				{ [_playlist release]; _playlist = [playlist retain]; }

@end
