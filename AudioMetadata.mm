/*
 *  $Id: Track.h 202 2005-12-04 21:50:52Z me $
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

#include "fileref.h"					// TagLib::File
#include "tag.h"						// TagLib::Tag

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
	TagLib::String				s;

	
	// Album title
	s = f.tag()->album();
	if(TagLib::String::Null == s) {
		[metadata setValue:[NSString stringWithUTF8String:s.toCString(true)] forKey:@"albumTitle"];
	}
	
	// Artist
	s = f.tag()->artist();
	if(TagLib::String::Null == s) {
		[metadata setValue:[NSString stringWithUTF8String:s.toCString(true)] forKey:@"albumArtist"];
	}

	// Genre
	s = f.tag()->genre();
	if(TagLib::String::Null == s) {
		[metadata setValue:[NSString stringWithUTF8String:s.toCString(true)] forKey:@"albumGenre"];
	}
	
	// Year
	if(0 != f.tag()->year()) {
		[metadata setValue:[NSNumber numberWithUnsignedInt:f.tag()->year()] forKey:@"albumYear"];
	}

	// Comment
	s = f.tag()->comment();
	if(TagLib::String::Null == s) {
		[metadata setValue:[NSString stringWithUTF8String:s.toCString(true)] forKey:@"albumComment"];
	}

	// Track title
	s = f.tag()->title();
	if(TagLib::String::Null == s) {
		[metadata setValue:[NSString stringWithUTF8String:s.toCString(true)] forKey:@"trackTitle"];
	}

	// Track number
	if(0 != f.tag()->track()) {
		[metadata setValue:[NSNumber numberWithUnsignedInt:f.tag()->track()] forKey:@"trackNumber"];
	}
	
	return [[result retain] autorelease];
}

// Create output file's basename
- (NSString *) basename
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
		NSNumber			*discNumber			= [metadata valueForKey:@"discNumber"];
		NSNumber			*discsInSet			= [metadata valueForKey:@"discsInSet"];
		NSString			*discArtist			= [metadata valueForKey:@"albumArtist"];
		NSString			*discTitle			= [metadata valueForKey:@"albumTitle"];
		NSString			*discGenre			= [metadata valueForKey:@"albumGenre"];
		NSNumber			*discYear			= [metadata valueForKey:@"albumYear"];
		NSNumber			*trackNumber		= [metadata valueForKey:@"trackNumber"];
		NSString			*trackArtist		= [metadata valueForKey:@"trackArtist"];
		NSString			*trackTitle			= [metadata valueForKey:@"trackTitle"];
		NSString			*trackGenre			= [metadata valueForKey:@"trackGenre"];
		NSNumber			*trackYear			= [metadata valueForKey:@"trackYear"];
		
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
	else if([[metadata valueForKey:@"multipleArtists"] boolValue]) {
		NSString			*path;
		
		NSString			*discTitle			= [metadata valueForKey:@"albumTitle"];
		NSString			*trackTitle			= [metadata valueForKey:@"trackTitle"];
		
		if(nil == discTitle) {
			discTitle = @"Unknown Album";
		}
		if(nil == trackTitle) {
			trackTitle = @"Unknown Track";
		}
		
		path = [NSString stringWithFormat:@"%@/Compilations/%@", outputDirectory, makeStringSafeForFilename(discTitle)]; 
		
		if(nil == [metadata valueForKey:@"discNumber"]) {
			basename = [NSString stringWithFormat:@"%@/%02u %@", path, [[metadata valueForKey:@"trackNumber"] unsignedIntValue], makeStringSafeForFilename(trackTitle)];
		}
		else {
			basename = [NSString stringWithFormat:@"%@/%i-%02u %@", path, [[metadata valueForKey:@"discNumber"] intValue], [[metadata valueForKey:@"trackNumber"] unsignedIntValue], makeStringSafeForFilename(trackTitle)];
		}
	}
	// Use standard iTunes-style naming: "Artist/Album/DiscNumber-TrackNumber TrackTitle.mp3"
	else {
		NSString			*path;
		
		NSString			*discArtist			= [metadata valueForKey:@"albumArtist"];
		NSString			*trackArtist		= [metadata valueForKey:@"trackArtist"];
		NSString			*artist;
		NSString			*discTitle			= [metadata valueForKey:@"albumTitle"];
		NSString			*trackTitle			= [metadata valueForKey:@"trackTitle"];
		
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
		
		if(nil == [metadata valueForKey:@"discNumber"]) {
			basename = [NSString stringWithFormat:@"%@/%02u %@", path, [[metadata valueForKey:@"trackNumber"] unsignedIntValue], makeStringSafeForFilename(trackTitle)];
		}
		else {
					basename = [NSString stringWithFormat:@"%@/%i-%02u %@", path, [[metadata valueForKey:@"discNumber"] intValue], [[metadata valueForKey:@"trackNumber"] unsignedIntValue], makeStringSafeForFilename(trackTitle)];
		}
	}
	
	return [[basename retain] autorelease];
}

@end
