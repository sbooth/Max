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

#include "fileref.h"					// TagLib::FileRef
#include "mpegfile.h"					// TagLib::MPEG::File
#include "id3v2tag.h"					// TagLib::ID3v2::Tag
#include "id3v2frame.h"					// TagLib::ID3v2::Frame
#include "mp4.h"						// MP4FileHandle

@implementation AudioMetadata

// Attempt to parse metadata from filename
+ (AudioMetadata *) metadataFromFile:(NSString *)filename
{
	AudioMetadata				*result				= [[AudioMetadata alloc] init];
	NSString					*extension			= [filename pathExtension];
	BOOL						parsed				= NO;

	[result setValue:[NSNumber numberWithBool:NO] forKey:@"multipleArtists"];
	[result setValue:[NSNumber numberWithUnsignedInt:0] forKey:@"trackNumber"];
	
	// For ".flac" files try to parse with libFLAC
	if([extension isEqualToString:@"flac"]) {
		FLAC__StreamMetadata						*tags, *currentTag;
		FLAC__StreamMetadata_VorbisComment_Entry	*comments;
		unsigned									i;
		NSString									*commentString, *key, *value;
		NSRange										range;
		
		if(FLAC__metadata_get_tags([filename UTF8String], &tags)) {
			
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
								
								if([key isEqualToString:@"ALBUM"]) {
									[result setValue:value forKey:@"albumTitle"];
								}
								else if([key isEqualToString:@"ARTIST"]) {
									[result setValue:value forKey:@"albumArtist"];
								}
								else if([key isEqualToString:@"GENRE"]) {
									[result setValue:value forKey:@"albumGenre"];
								}
								else if([key isEqualToString:@"DATE"]) {
									[result setValue:[NSNumber numberWithUnsignedInt:[value intValue]] forKey:@"albumYear"];
								}
								else if([key isEqualToString:@"DESCRIPTION"]) {
									[result setValue:value forKey:@"albumComment"];
								}
								else if([key isEqualToString:@"TITLE"]) {
									[result setValue:value forKey:@"trackTitle"];
								}
								else if([key isEqualToString:@"TRACKNUMBER"]) {
									[result setValue:[NSNumber numberWithUnsignedInt:[value intValue]] forKey:@"trackNumber"];
								}
								else if([key isEqualToString:@"TOTALTRACKS"]) {
									[result setValue:[NSNumber numberWithUnsignedInt:[value intValue]] forKey:@"albumTrackCount"];
								}
								else if([key isEqualToString:@"COMPILATION"]) {
									[result setValue:[NSNumber numberWithBool:[value intValue]] forKey:@"multipleArtists"];
								}
								else if([key isEqualToString:@"DISCNUMBER"]) {
									[result setValue:[NSNumber numberWithUnsignedInt:[value intValue]] forKey:@"discNumber"];
								}
								else if([key isEqualToString:@"DISCSINSET"]) {
									[result setValue:[NSNumber numberWithUnsignedInt:[value intValue]] forKey:@"discsInSet"];
								}
								else if([key isEqualToString:@"ISRC"]) {
									[result setValue:value forKey:@"ISRC"];
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
	}
	
	// Try TagLib
	if(NO == parsed) {
		TagLib::FileRef			f						([filename UTF8String]);
		TagLib::MPEG::File		*mpegFile				= NULL;
		TagLib::String			s;
		TagLib::ID3v2::Tag		*id3v2tag;
		NSString				*trackString, *trackNum, *totalTracks;
		NSRange					range;
		
		
		if(false == f.isNull()) {
			mpegFile = dynamic_cast<TagLib::MPEG::File *>(f.file());

			// Album title
			s = f.tag()->album();
			if(false == s.isNull()) {
				[result setValue:[NSString stringWithUTF8String:s.toCString(true)] forKey:@"albumTitle"];
			}
			
			// Artist
			s = f.tag()->artist();
			if(false == s.isNull()) {
				[result setValue:[NSString stringWithUTF8String:s.toCString(true)] forKey:@"albumArtist"];
			}
			
			// Genre
			s = f.tag()->genre();
			if(false == s.isNull()) {
				[result setValue:[NSString stringWithUTF8String:s.toCString(true)] forKey:@"albumGenre"];
			}
			
			// Year
			if(0 != f.tag()->year()) {
				[result setValue:[NSNumber numberWithUnsignedInt:f.tag()->year()] forKey:@"albumYear"];
			}
			
			// Comment
			s = f.tag()->comment();
			if(false == s.isNull()) {
				[result setValue:[NSString stringWithUTF8String:s.toCString(true)] forKey:@"albumComment"];
			}
			
			// Track title
			s = f.tag()->title();
			if(false == s.isNull()) {
				[result setValue:[NSString stringWithUTF8String:s.toCString(true)] forKey:@"trackTitle"];
			}

			// Track number
			if(NULL != mpegFile) {
				id3v2tag = mpegFile->ID3v2Tag();
				
				if(NULL != id3v2tag) {
					TagLib::ID3v2::FrameList frameList = id3v2tag->frameListMap()["TRCK"];
					
					if(NO == frameList.isEmpty()) {
						// Split the tracks at '/'
						trackString		= [NSString stringWithUTF8String:frameList.front()->toString().toCString(true)];
						range			= [trackString rangeOfString:@"/" options:NSLiteralSearch];
						
						if(NSNotFound != range.location && 0 != range.length) {
							trackNum		= [trackString substringToIndex:range.location];
							totalTracks		= [trackString substringFromIndex:range.location + 1];
							
							[result setValue:[NSNumber numberWithUnsignedInt:[trackNum intValue]] forKey:@"trackNumber"];
							[result setValue:[NSNumber numberWithUnsignedInt:[totalTracks intValue]] forKey:@"albumTrackCount"];
						}
						else {
							[result setValue:[NSNumber numberWithUnsignedInt:[trackString intValue]] forKey:@"trackNumber"];
						}
					}			
				}
			}
			else if(0 != f.tag()->track()) {
				[result setValue:[NSNumber numberWithUnsignedInt:f.tag()->track()] forKey:@"trackNumber"];
			}
			
			// If this is an MPEG file look for the iTunes TCMP tag
			if(NULL != mpegFile && [[NSUserDefaults standardUserDefaults] boolForKey:@"useiTunesWorkarounds"]) {
				id3v2tag = mpegFile->ID3v2Tag();
				
				if(NULL != id3v2tag) {
					TagLib::ID3v2::FrameList frameList = id3v2tag->frameListMap()["TCMP"];
					
					if(NO == frameList.isEmpty()) {
						// Is it safe to assume this will only be 0 or 1?  (Probably not, it never is)
						NSString *value = [NSString stringWithUTF8String:frameList.front()->toString().toCString(true)];
						[result setValue:[NSNumber numberWithBool:(BOOL)[value intValue]] forKey:@"multipleArtists"];
					}			
				}
			}
						
			parsed = YES;
		}
	}

	// Try mp4v2
	if(NO == parsed) {
		MP4FileHandle mp4FileHandle = MP4Read([filename UTF8String], 0);
		
		if(MP4_INVALID_FILE_HANDLE != mp4FileHandle) {
			char			*s;
			u_int16_t		trackNumber, totalTracks;
			u_int16_t		discNumber, discsInSet;
			u_int8_t		multipleArtists;
			
			// Album title
			MP4GetMetadataAlbum(mp4FileHandle, &s);
			if(0 != s) {
				[result setValue:[NSString stringWithUTF8String:s] forKey:@"albumTitle"];
			}
			
			// Artist
			MP4GetMetadataArtist(mp4FileHandle, &s);
			if(0 != s) {
				[result setValue:[NSString stringWithUTF8String:s] forKey:@"albumArtist"];
			}
			
			// Genre
			MP4GetMetadataGenre(mp4FileHandle, &s);
			if(0 != s) {
				[result setValue:[NSString stringWithUTF8String:s] forKey:@"albumGenre"];
			}
			
			// Year
			MP4GetMetadataYear(mp4FileHandle, &s);
			if(0 != s) {
				// Avoid atoi()
				[result setValue:[NSNumber numberWithInt:[[NSString stringWithUTF8String:s] intValue]] forKey:@"albumYear"];
			}
			
			// Comment
			MP4GetMetadataComment(mp4FileHandle, &s);
			if(0 != s) {
				[result setValue:[NSString stringWithUTF8String:s] forKey:@"albumComment"];
			}
			
			// Track title
			MP4GetMetadataName(mp4FileHandle, &s);
			if(0 != s) {
				[result setValue:[NSString stringWithUTF8String:s] forKey:@"trackTitle"];
			}
			
			// Track number
			MP4GetMetadataTrack(mp4FileHandle, &trackNumber, &totalTracks);
			if(0 != trackNumber) {
				[result setValue:[NSNumber numberWithUnsignedShort:trackNumber] forKey:@"trackNumber"];
			}
			if(0 != totalTracks) {
				[result setValue:[NSNumber numberWithUnsignedShort:totalTracks] forKey:@"albumTrackCount"];
			}
			
			// Disc number
			MP4GetMetadataDisk(mp4FileHandle, &discNumber, &discsInSet);
			if(0 != discNumber) {
				[result setValue:[NSNumber numberWithUnsignedShort:discNumber] forKey:@"discNumber"];
			}
			if(0 != discsInSet) {
				[result setValue:[NSNumber numberWithUnsignedShort:discsInSet] forKey:@"discsInSet"];
			}
			
			// Compilation
			MP4GetMetadataCompilation(mp4FileHandle, &multipleArtists);
			if(multipleArtists) {
				[result setValue:[NSNumber numberWithBool:YES] forKey:@"multipleArtists"];
			}
			
			MP4Close(mp4FileHandle);
		}
	}

	return [result autorelease];
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
		NSNumber			*discNumber			= [self valueForKey:@"discNumber"];
		NSNumber			*discsInSet			= [self valueForKey:@"discsInSet"];
		NSString			*discArtist			= [self valueForKey:@"albumArtist"];
		NSString			*discTitle			= [self valueForKey:@"albumTitle"];
		NSString			*discGenre			= [self valueForKey:@"albumGenre"];
		NSNumber			*discYear			= [self valueForKey:@"albumYear"];
		NSNumber			*trackNumber		= [self valueForKey:@"trackNumber"];
		NSString			*trackArtist		= [self valueForKey:@"trackArtist"];
		NSString			*trackTitle			= [self valueForKey:@"trackTitle"];
		NSString			*trackGenre			= [self valueForKey:@"trackGenre"];
		NSNumber			*trackYear			= [self valueForKey:@"trackYear"];
		
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
			@throw [NSException exceptionWithName:@"NSObjectInaccessibleException" reason:@"Invalid custom naming string." userInfo:nil];
		}
		else {
			[customPath setString:customNamingScheme];
		}
		
		if(nil == discNumber) {
			[customPath replaceOccurrencesOfString:@"{discNumber}" withString:@"" options:nil range:NSMakeRange(0, [customPath length])];
		}
		else {
			[customPath replaceOccurrencesOfString:@"{discNumber}" withString:[discNumber stringValue] options:nil range:NSMakeRange(0, [customPath length])];					
		}
		if(nil == discsInSet) {
			[customPath replaceOccurrencesOfString:@"{discsInSet}" withString:@"" options:nil range:NSMakeRange(0, [customPath length])];
		}
		else {
			[customPath replaceOccurrencesOfString:@"{discsInSet}" withString:[discsInSet stringValue] options:nil range:NSMakeRange(0, [customPath length])];
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
			[customPath replaceOccurrencesOfString:@"{discYear}" withString:[discYear stringValue] options:nil range:NSMakeRange(0, [customPath length])];
		}
		if(nil == trackNumber) {
			[customPath replaceOccurrencesOfString:@"{trackNumber}" withString:@"" options:nil range:NSMakeRange(0, [customPath length])];
		}
		else {
			if([[NSUserDefaults standardUserDefaults] boolForKey:@"customNamingUseTwoDigitTrackNumbers"]) {
				[customPath replaceOccurrencesOfString:@"{trackNumber}" withString:[NSString stringWithFormat:@"%02u", [trackNumber intValue]] options:nil range:NSMakeRange(0, [customPath length])];
			}
			else {
				[customPath replaceOccurrencesOfString:@"{trackNumber}" withString:[trackNumber stringValue] options:nil range:NSMakeRange(0, [customPath length])];
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
		if(nil == trackYear) {
			[customPath replaceOccurrencesOfString:@"{trackYear}" withString:@"Unknown Year" options:nil range:NSMakeRange(0, [customPath length])];
		}
		else {
			[customPath replaceOccurrencesOfString:@"{trackYear}" withString:[trackYear stringValue] options:nil range:NSMakeRange(0, [customPath length])];
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
	else if([[self valueForKey:@"multipleArtists"] boolValue]) {
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
		
		if(nil == [self valueForKey:@"discNumber"]) {
			basename = [NSString stringWithFormat:@"%@/%02u %@", path, [[self valueForKey:@"trackNumber"] unsignedIntValue], makeStringSafeForFilename(trackTitle)];
		}
		else {
			basename = [NSString stringWithFormat:@"%@/%i-%02u %@", path, [[self valueForKey:@"discNumber"] intValue], [[self valueForKey:@"trackNumber"] unsignedIntValue], makeStringSafeForFilename(trackTitle)];
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
		
		if(nil == [self valueForKey:@"discNumber"]) {
			basename = [NSString stringWithFormat:@"%@/%02u %@", path, [[self valueForKey:@"trackNumber"] unsignedIntValue], makeStringSafeForFilename(trackTitle)];
		}
		else {
			basename = [NSString stringWithFormat:@"%@/%i-%02u %@", path, [[self valueForKey:@"discNumber"] intValue], [[self valueForKey:@"trackNumber"] unsignedIntValue], makeStringSafeForFilename(trackTitle)];
		}
	}
	
	return [[basename retain] autorelease];
}

- (NSString *) description
{
	if(nil != _multipleArtists && [_multipleArtists boolValue]) {
		NSString	*artist		= _trackArtist;
		NSString	*title		= _trackTitle;
		
		if(nil == artist) {
			artist = _albumArtist;
			if(nil == artist) {
				artist = NSLocalizedStringFromTable(@"Unknown Artist", @"CompactDisc", @"");
			}
		}
		if(nil == title) {
			title = NSLocalizedStringFromTable(@"Unknown Title", @"CompactDisc", @"");
		}
		
		return [NSString stringWithFormat:@"%@ - %@", artist, title];			
	}
	else if(nil != _trackTitle) {
		return [NSString stringWithFormat:@"%@", _trackTitle];
	}
	else {
		return NSLocalizedStringFromTable(@"Unknown Track", @"CompactDisc", @"");
	}
}

@end
