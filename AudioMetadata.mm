/*
 *  $Id$
 *
 *  Copyright (C) 2005 Stephen F. Booth <me@sbooth.org>
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

#include "fileref.h"					// TagLib::File
#include "tag.h"						// TagLib::Tag
#include "mp4.h"						// MP4FileHandle

@implementation AudioMetadata

- (NSString *) description
{
	if(nil != _multipleArtists && [_multipleArtists boolValue]) {
		return [NSString stringWithFormat:@"%@ - %@", _trackArtist, _trackTitle];
	}
	else if(nil != _trackTitle) {
		return [NSString stringWithFormat:@"%@", _trackTitle];
	}
	else {
		return @"Unknown Track";
	}
}

// Attempt to parse metadata from filename
+ (AudioMetadata *) metadataFromFilename:(NSString *)filename
{
	AudioMetadata				*result				= [[AudioMetadata alloc] init];
	TagLib::FileRef				f					([filename UTF8String]);
	MP4FileHandle				mp4FileHandle		= MP4Read([filename UTF8String], 0);

	[result setValue:[NSNumber numberWithBool:NO] forKey:@"multipleArtists"];
	[result setValue:[NSNumber numberWithUnsignedInt:0] forKey:@"trackNumber"];
	[result setValue:[NSNumber numberWithUnsignedInt:0] forKey:@"discNumber"];
	[result setValue:[NSNumber numberWithUnsignedInt:0] forKey:@"discsInSet"];

	// Try TagLib first
	if(false == f.isNull()) {
		TagLib::String		s;
		
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
		if(0 != f.tag()->track()) {
			[result setValue:[NSNumber numberWithUnsignedInt:f.tag()->track()] forKey:@"trackNumber"];
		}
	}
	// Try mp4v2 second
	else if(MP4_INVALID_FILE_HANDLE != mp4FileHandle) {
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
		if(0xFF != multipleArtists) {
			[result setValue:[NSNumber numberWithBool:YES] forKey:@"multipleArtists"];
		}
		
		MP4Close(mp4FileHandle);
	}
	
	return [result autorelease];
}

// Create output file's basename
- (NSString *) outputBasename
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
		
		basename = [NSString stringWithFormat:@"%@/%@", outputDirectory, customPath];
	}
	// Use standard iTunes-style naming for compilations: "Compilations/Album/DiscNumber-TrackNumber TrackTitle.mp3"
	else if([[self valueForKey:@"multipleArtists"] boolValue]) {
		NSString			*path;
		
		NSString			*discTitle			= [self valueForKey:@"albumTitle"];
		NSString			*trackTitle			= [self valueForKey:@"trackTitle"];
		
		if(nil == discTitle) {
			discTitle = @"Unknown Album";
		}
		if(nil == trackTitle) {
			trackTitle = @"Unknown Track";
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
				artist = @"Unknown Artist";
			}
		}
		if(nil == discTitle) {
			discTitle = @"Unknown Album";
		}
		if(nil == trackTitle) {
			trackTitle = @"Unknown Track";
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

@end
