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

#import "UtilityFunctions.h"

#include <TagLib/fileref.h>					// TagLib::FileRef
#include <TagLib/mpegfile.h>				// TagLib::MPEG::File
#include <TagLib/vorbisfile.h>				// TagLib::Ogg::Vorbis::File
#include <TagLib/id3v2tag.h>				// TagLib::ID3v2::Tag
#include <TagLib/id3v2frame.h>				// TagLib::ID3v2::Frame
#include <TagLib/attachedpictureframe.h>	// TagLib::ID3V2::AttachedPictureFrame
#include <TagLib/xiphcomment.h>				// TagLib::Ogg::XiphComment
#include <TagLib/tbytevector.h>				// TagLib::ByteVector
#include <mp4v2/mp4.h>						// MP4FileHandle

@implementation AudioMetadata

+ (BOOL) accessInstanceVariablesDirectly { return NO; }

// Attempt to parse metadata from filename
+ (AudioMetadata *) metadataFromFile:(NSString *)filename
{
	AudioMetadata				*result				= [[AudioMetadata alloc] init];
	NSString					*extension			= [filename pathExtension];
	BOOL						parsed				= NO;
	
	// For ".flac" files try to parse with libFLAC
	if([extension isEqualToString:@"flac"]) {
		FLAC__StreamMetadata						*tags, *currentTag, streaminfo;
		FLAC__StreamMetadata_VorbisComment_Entry	*comments;
		unsigned									i;
		NSString									*commentString, *key, *value;
		NSRange										range;
		
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
								
								if(NSOrderedSame == [key caseInsensitiveCompare:@"ALBUM"]) {
									[result setAlbumTitle:value];
								}
								else if(NSOrderedSame == [key caseInsensitiveCompare:@"ARTIST"]) {
									[result setAlbumArtist:value];
								}
								else if(NSOrderedSame == [key caseInsensitiveCompare:@"COMPOSER"]) {
									[result setAlbumComposer:value];
								}
								else if(NSOrderedSame == [key caseInsensitiveCompare:@"GENRE"]) {
									[result setAlbumGenre:value];
								}
								else if(NSOrderedSame == [key caseInsensitiveCompare:@"DATE"]) {
									[result setAlbumYear:[value intValue]];
								}
								else if(NSOrderedSame == [key caseInsensitiveCompare:@"DESCRIPTION"]) {
									[result setAlbumComment:value];
								}
								else if(NSOrderedSame == [key caseInsensitiveCompare:@"TITLE"]) {
									[result setTrackTitle:value];
								}
								else if(NSOrderedSame == [key caseInsensitiveCompare:@"TRACKNUMBER"]) {
									[result setTrackNumber:[value intValue]];
								}
								else if(NSOrderedSame == [key caseInsensitiveCompare:@"TRACKTOTAL"]) {
									[result setAlbumTrackCount:[value intValue]];
								}
								// Maintain backwards compatibility for TOTALTRACKS
								else if(NSOrderedSame == [key caseInsensitiveCompare:@"TOTALTRACKS"]) {
									[result setAlbumTrackCount:[value intValue]];
								}
								else if(NSOrderedSame == [key caseInsensitiveCompare:@"COMPILATION"]) {
									[result setMultipleArtists:[value intValue]];
								}
								else if(NSOrderedSame == [key caseInsensitiveCompare:@"DISCNUMBER"]) {
									[result setDiscNumber:[value intValue]];
								}
								else if(NSOrderedSame == [key caseInsensitiveCompare:@"DISCSINSET"]) {
									[result setDiscsInSet:[value intValue]];
								}
								else if(NSOrderedSame == [key caseInsensitiveCompare:@"ISRC"]) {
									[result setISRC:value];
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
			
			parsed = YES;
		}

		// Get length
		if(FLAC__metadata_get_streaminfo([filename fileSystemRepresentation], &streaminfo) && FLAC__METADATA_TYPE_STREAMINFO == streaminfo.type) {
			[result setLength:(streaminfo.data.stream_info.total_samples * streaminfo.data.stream_info.sample_rate)];
		}
	}
	
	// Try TagLib
	if(NO == parsed) {
		TagLib::FileRef							f						([filename fileSystemRepresentation]);
		TagLib::MPEG::File						*mpegFile				= NULL;
		TagLib::Ogg::Vorbis::File				*vorbisFile				= NULL;
		TagLib::ID3v2::AttachedPictureFrame		*picture				= NULL;
		TagLib::String							s;
		TagLib::ID3v2::Tag						*id3v2tag;
		TagLib::Ogg::XiphComment				*xiphComment;
		NSString								*trackString, *trackNum, *totalTracks;
		NSRange									range;
		
		if(false == f.isNull()) {
			mpegFile	= dynamic_cast<TagLib::MPEG::File *>(f.file());
			vorbisFile	= dynamic_cast<TagLib::Ogg::Vorbis::File *>(f.file());

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
			if(0 != f.audioProperties()->length()) {
				[result setLength:f.audioProperties()->length()];
			}
			
			// Special case for certain ID3 tags in MPEG files
			if(NULL != mpegFile) {
				id3v2tag = mpegFile->ID3v2Tag();
				
				if(NULL != id3v2tag) {
					
					// Extract total tracks if present
					TagLib::ID3v2::FrameList frameList = id3v2tag->frameListMap()["TRCK"];
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
						NSImage *image = [[NSImage alloc] initWithData:[NSData dataWithBytes:bv.data() length:bv.size()]];
						if(nil != image) {
							[result setAlbumArt:[image autorelease]];
						}
					}			
					
					// Extract compilation if present (iTunes TCMP tag)
					if([[NSUserDefaults standardUserDefaults] boolForKey:@"useiTunesWorkarounds"]) {
						frameList = id3v2tag->frameListMap()["TCMP"];
						if(NO == frameList.isEmpty()) {
							// Is it safe to assume this will only be 0 or 1?  (Probably not, it never is)
							NSString *value = [NSString stringWithUTF8String:frameList.front()->toString().toCString(true)];
							[result setMultipleArtists:(BOOL)[value intValue]];
						}			
					}
				}
			}
			
			// Special case for certain tags in Ogg Vorbis files
			if(NULL != vorbisFile) {
				xiphComment = vorbisFile->tag();
				
				if(NULL != xiphComment) {
					TagLib::Ogg::FieldListMap		fieldList	= xiphComment->fieldListMap();
					NSString						*value		= nil;
					
					if(fieldList.contains("COMPOSER")) {
						value = [NSString stringWithUTF8String:fieldList["COMPOSER"].toString().toCString(true)];
						[result setAlbumComposer:value];
					}

					if(fieldList.contains("TRACKTOTAL")) {
						value = [NSString stringWithUTF8String:fieldList["TRACKTOTAL"].toString().toCString(true)];
						[result setAlbumTrackCount:[value intValue]];
					}
					
					if(fieldList.contains("DISCNUMBER")) {
						value = [NSString stringWithUTF8String:fieldList["DISCNUMBER"].toString().toCString(true)];
						[result setDiscNumber:[value intValue]];
					}

					if(fieldList.contains("DISCSINSET")) {
						value = [NSString stringWithUTF8String:fieldList["DISCSINSET"].toString().toCString(true)];
						[result setDiscsInSet:[value intValue]];
					}

					if(fieldList.contains("COMPILATION")) {
						value = [NSString stringWithUTF8String:fieldList["COMPILATION"].toString().toCString(true)];
						[result setMultipleArtists:(BOOL)[value intValue]];
					}

					if(fieldList.contains("ISRC")) {
						value = [NSString stringWithUTF8String:fieldList["ISRC"].toString().toCString(true)];
						[result setISRC:value];
					}					

					if(fieldList.contains("MCN")) {
						value = [NSString stringWithUTF8String:fieldList["MCN"].toString().toCString(true)];
						[result setMCN:value];
					}					
				}
			}
			
			parsed = YES;
		}
	}

	// Try mp4v2
	if(NO == parsed) {
		MP4FileHandle mp4FileHandle = MP4Read([filename fileSystemRepresentation], 0);
		
		if(MP4_INVALID_FILE_HANDLE != mp4FileHandle) {
			char			*s									= NULL;
			u_int16_t		trackNumber, totalTracks;
			u_int16_t		discNumber, discsInSet;
			u_int8_t		multipleArtists;
			u_int64_t		duration;
			u_int32_t		artCount;
			u_int8_t		*bytes								= NULL;
			u_int32_t		length								= 0;
			NSImage			*image								= nil;
			
			// Album title
			MP4GetMetadataAlbum(mp4FileHandle, &s);
			if(0 != s) {
				[result setAlbumTitle:[NSString stringWithUTF8String:s]];
			}
			
			// Artist
			MP4GetMetadataArtist(mp4FileHandle, &s);
			if(0 != s) {
				[result setAlbumArtist:[NSString stringWithUTF8String:s]];
			}
			
			// Genre
			MP4GetMetadataGenre(mp4FileHandle, &s);
			if(0 != s) {
				[result setAlbumGenre:[NSString stringWithUTF8String:s]];
			}
			
			// Year
			MP4GetMetadataYear(mp4FileHandle, &s);
			if(0 != s) {
				// Avoid atoi()
				[result setAlbumYear:[[NSString stringWithUTF8String:s] intValue]];
			}
			
			// Comment
			MP4GetMetadataComment(mp4FileHandle, &s);
			if(0 != s) {
				[result setAlbumComment:[NSString stringWithUTF8String:s]];
			}
			
			// Track title
			MP4GetMetadataName(mp4FileHandle, &s);
			if(0 != s) {
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
			MP4GetMetadataDisk(mp4FileHandle, &discNumber, &discsInSet);
			if(0 != discNumber) {
				[result setDiscNumber:discNumber];
			}
			if(0 != discsInSet) {
				[result setDiscsInSet:discsInSet];
			}
			
			// Compilation
			MP4GetMetadataCompilation(mp4FileHandle, &multipleArtists);
			if(multipleArtists) {
				[result setMultipleArtists:YES];
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
				image = [[NSImage alloc] initWithData:[NSData dataWithBytes:bytes length:length]];
				if(nil != image) {
					[result setAlbumArt:[image autorelease]];
				}
			}
			
			MP4Close(mp4FileHandle);
		}
	}

	return [result autorelease];
}

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
		
		_multipleArtists	= NO;
		_discNumber			= 0;
		_discsInSet			= 0;
		
		_length				= 0;
		
		_albumArt			= nil;
		
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
	
	[_MCN release];
	[_ISRC release];
	
	[super dealloc];
}

// Create output file's basename
- (NSString *) outputBasename						{ return [self outputBasenameWithSubstitutions:nil]; }

- (NSString *) outputBasenameWithSubstitutions:(NSDictionary *)substitutions;
{
	NSString		*basename;
	NSString		*outputDirectory;
	
	
	// Create output directory (should exist but could have been deleted/moved)
	outputDirectory = [[[NSUserDefaults standardUserDefaults] stringForKey:@"outputDirectory"] stringByExpandingTildeInPath];
	
	// Use custom naming scheme
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"useCustomNaming"]) {
		
		NSMutableString		*customPath			= [NSMutableString stringWithCapacity:100];
		NSString			*customNamingScheme = [[NSUserDefaults standardUserDefaults] stringForKey:@"customNamingScheme"];
		
		// Get the elements needed to build the pathname
		unsigned			discNumber			= [self discNumber];
		unsigned			discsInSet			= [self discsInSet];
		NSString			*discArtist			= [self albumArtist];
		NSString			*discTitle			= [self albumTitle];
		NSString			*discGenre			= [self albumGenre];
		unsigned			discYear			= [self albumYear];
		unsigned			trackNumber			= [self trackNumber];
		NSString			*trackArtist		= [self trackArtist];
		NSString			*trackTitle			= [self trackTitle];
		NSString			*trackGenre			= [self trackGenre];
		unsigned			trackYear			= [self trackYear];
		
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
			@throw [NSException exceptionWithName:@"NSObjectInaccessibleException" reason:@"Invalid custom naming string" userInfo:nil];
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
		if(0 == discsInSet) {
			[customPath replaceOccurrencesOfString:@"{discsInSet}" withString:@"" options:nil range:NSMakeRange(0, [customPath length])];
		}
		else {
			[customPath replaceOccurrencesOfString:@"{discsInSet}" withString:[NSString stringWithFormat:@"%u", discsInSet] options:nil range:NSMakeRange(0, [customPath length])];
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
			[customPath replaceOccurrencesOfString:@"{discYear}" withString:[NSString stringWithFormat:@"%u", discYear] options:nil range:NSMakeRange(0, [customPath length])];
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
		if(0 == trackYear) {
			[customPath replaceOccurrencesOfString:@"{trackYear}" withString:@"Unknown Year" options:nil range:NSMakeRange(0, [customPath length])];
		}
		else {
			[customPath replaceOccurrencesOfString:@"{trackYear}" withString:[NSString stringWithFormat:@"%u", trackYear] options:nil range:NSMakeRange(0, [customPath length])];
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
	else if([self multipleArtists]) {
		NSString			*path;
		
		NSString			*discTitle			= [self valueForKey:@"albumTitle"];
		NSString			*trackTitle			= [self valueForKey:@"trackTitle"];
		
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
		
		NSString			*discArtist			= [self valueForKey:@"albumArtist"];
		NSString			*trackArtist		= [self valueForKey:@"trackArtist"];
		NSString			*artist;
		NSString			*discTitle			= [self valueForKey:@"albumTitle"];
		NSString			*trackTitle			= [self valueForKey:@"trackTitle"];
		
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

- (NSString *) description
{
	if([self multipleArtists]) {
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

// Accessors
- (unsigned)	trackNumber					{ return _trackNumber; }
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

- (BOOL)		multipleArtists				{ return _multipleArtists; }
- (unsigned)	discNumber					{ return _discNumber; }
- (unsigned)	discsInSet					{ return _discsInSet; }

- (unsigned)	length						{ return _length; }

- (NSString *)	MCN							{ return _MCN; }
- (NSString *)	ISRC						{ return _ISRC; }

- (NSBitmapImageRep *) albumArt				{ return _albumArt; }

// Mutators
- (void)		setTrackNumber:(unsigned)trackNumber			{ _trackNumber = trackNumber; }
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

- (void)		setMultipleArtists:(BOOL)multipleArtists		{ _multipleArtists = multipleArtists; }
- (void)		setDiscNumber:(unsigned)discNumber				{ _discNumber = discNumber; }
- (void)		setDiscsInSet:(unsigned)discsInSet				{ _discsInSet = discsInSet; }

- (void)		setLength:(unsigned)length						{ _length = length; }

- (void)		setMCN:(NSString *)MCN							{ [_MCN release]; _MCN = [MCN retain]; }
- (void)		setISRC:(NSString *)ISRC						{ [_ISRC release]; _ISRC = [ISRC retain]; }

- (void)		setAlbumArt:(NSBitmapImageRep *)albumArt		{ [_albumArt release]; _albumArt = [albumArt retain]; }

@end
