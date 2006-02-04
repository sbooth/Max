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

#import "OggVorbisEncoderTask.h"
#import "OggVorbisEncoder.h"
#import "IOException.h"

#include "TagLib/vorbisfile.h"			// TagLib::Ogg::Vorbis::File
#include "TagLib/tag.h"					// TagLib::Tag

@implementation OggVorbisEncoderTask

- (id) initWithTask:(PCMGeneratingTask *)task
{
	if((self = [super initWithTask:task])) {
		_encoderClass = [OggVorbisEncoder class];
		return self;
	}
	return nil;
}

- (void) writeTags
{
	AudioMetadata								*metadata				= [_task metadata];
	NSNumber									*trackNumber			= nil;
	NSNumber									*trackTotal				= nil;
	NSNumber									*discNumber				= nil;
	NSNumber									*discsInSet				= nil;
	NSNumber									*multiArtist			= nil;
	NSString									*album					= nil;
	NSString									*artist					= nil;
	NSString									*composer				= nil;
	NSString									*title					= nil;
	NSNumber									*year					= nil;
	NSString									*genre					= nil;
	NSString									*comment				= nil;
	NSString									*isrc					= nil;
	TagLib::Ogg::Vorbis::File					f						([_outputFilename fileSystemRepresentation], false);

	
	if(NO == f.isValid()) {
		@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to open the output file for tagging", @"Exceptions", @"") userInfo:nil];
	}

	// Album title
	album = [metadata valueForKey:@"albumTitle"];
	if(nil != album) {
		f.tag()->setAlbum(TagLib::String([album UTF8String], TagLib::String::UTF8));
	}
	
	// Artist
	artist = [metadata valueForKey:@"trackArtist"];
	if(nil == artist) {
		artist = [metadata valueForKey:@"albumArtist"];
	}
	if(nil != artist) {
		f.tag()->setArtist(TagLib::String([artist UTF8String], TagLib::String::UTF8));
	}

	// Composer
	composer = [metadata valueForKey:@"trackComposer"];
	if(nil == composer) {
		composer = [metadata valueForKey:@"albumComposer"];
	}
	if(nil != composer) {
		f.tag()->addField("COMPOSER", TagLib::String([composer UTF8String], TagLib::String::UTF8));
	}
	
	// Genre
	genre = [metadata valueForKey:@"trackGenre"];
	if(nil == genre) {
		genre = [metadata valueForKey:@"albumGenre"];
	}
	if(nil != genre) {
		f.tag()->setGenre(TagLib::String([genre UTF8String], TagLib::String::UTF8));
	}
	
	// Year
	year = [metadata valueForKey:@"trackYear"];
	if(nil == year) {
		year = [metadata valueForKey:@"albumYear"];
	}
	if(nil != year) {
		f.tag()->setYear([year intValue]);
	}
	
	// Comment
	comment = [metadata valueForKey:@"albumComment"];
	if(_writeSettingsToComment) {
		comment = (nil == comment ? [self settings] : [NSString stringWithFormat:@"%@\n%@", comment, [self settings]]);
	}
	if(nil != comment) {
		f.tag()->setComment(TagLib::String([comment UTF8String], TagLib::String::UTF8));
	}
	
	// Track title
	title = [metadata valueForKey:@"trackTitle"];
	if(nil != title) {
		f.tag()->setTitle(TagLib::String([title UTF8String], TagLib::String::UTF8));
	}
	
	// Track number
	trackNumber = [metadata valueForKey:@"trackNumber"];
	if(nil != trackNumber) {
		f.tag()->setTrack([trackNumber unsignedIntValue]);
	}

	// Track total
	trackTotal = [metadata valueForKey:@"albumTrackCount"];
	if(nil != trackTotal) {
		f.tag()->addField("TRACKTOTAL", TagLib::String([[trackTotal stringValue] UTF8String], TagLib::String::UTF8));
	}

	// Disc number
	discNumber = [metadata valueForKey:@"discNumber"];
	if(nil != discNumber) {
		f.tag()->addField("DISCNUMBER", TagLib::String([[discNumber stringValue] UTF8String], TagLib::String::UTF8));
	}
	
	// Discs in set
	discsInSet = [metadata valueForKey:@"discsInSet"];
	if(nil != discsInSet) {
		f.tag()->addField("DISCSINSET", TagLib::String([[discsInSet stringValue] UTF8String], TagLib::String::UTF8));
	}

	// Multiple artists
	multiArtist = [metadata valueForKey:@"multipleArtists"];
	if(nil != multiArtist && [multiArtist boolValue]) {
		f.tag()->addField("COMPILATION", TagLib::String([[multiArtist stringValue] UTF8String], TagLib::String::UTF8));
	}
	
	// ISRC
	isrc = [metadata valueForKey:@"ISRC"];
	if(nil != isrc) {
		f.tag()->addField("ISRC", TagLib::String([isrc UTF8String], TagLib::String::UTF8));
	}

	// Encoder settings
	f.tag()->addField("ENCODING", TagLib::String([[self settings] UTF8String], TagLib::String::UTF8));
	
	f.save();
}

- (NSString *)		extension						{ return @"ogg"; }
- (NSString *)		outputFormat					{ return NSLocalizedStringFromTable(@"Ogg Vorbis", @"General", @""); }

@end
