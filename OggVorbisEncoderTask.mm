/*
 *  $Id: EncoderTask.m 181 2005-11-28 08:38:43Z me $
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

#import "OggVorbisEncoderTask.h"
#import "OggVorbisEncoder.h"

#include "fileref.h"					// TagLib::File
#include "tag.h"						// TagLib::Tag

@implementation OggVorbisEncoderTask

- (id) initWithSource:(id <PCMGenerating>)source target:(NSString *)target
{
	if((self = [super initWithTarget:target])) {
		_encoder = [[OggVorbisEncoder alloc] initWithSource:[source outputFilename]];
		return self;
	}
	return nil;
}

- (void) dealloc
{
	[_encoder release];
	[super dealloc];
}

- (void) writeTags
{
	NSNumber									*trackNumber			= nil;
	NSString									*album					= nil;
	NSString									*artist					= nil;
	NSString									*title					= nil;
	NSNumber									*year					= nil;
	NSString									*genre					= nil;
	NSString									*comment				= nil;
	TagLib::FileRef								f						([_target UTF8String], false);

	
	// Album title
	album = [_metadata albumTitle];
	if(nil != album) {
		f.tag()->setAlbum(TagLib::String([album UTF8String], TagLib::String::UTF8));
	}
	
	// Artist
	artist = [_metadata trackArtist];
	if(nil == artist) {
		artist = [_metadata albumArtist];
	}
	if(nil != artist) {
		f.tag()->setArtist(TagLib::String([artist UTF8String], TagLib::String::UTF8));
	}
	
	// Genre
	genre = [_metadata trackGenre];
	if(nil == genre) {
		genre = [_metadata albumGenre];
	}
	if(nil != genre) {
		f.tag()->setGenre(TagLib::String([genre UTF8String], TagLib::String::UTF8));
	}
	
	// Year
	year = [_metadata trackYear];
	if(nil == year) {
		year = [_metadata albumYear];
	}
	if(nil != year) {
		f.tag()->setYear([year intValue]);
	}
	
	// Comment
	if(_writeSettingsToComment) {
		comment = (nil == comment ? [_encoder description] : [comment stringByAppendingString:[NSString stringWithFormat:@"\n%@", [_encoder description]]]);
	}
	comment = [_metadata albumComment];
	if(nil != comment) {
		f.tag()->setComment(TagLib::String([comment UTF8String], TagLib::String::UTF8));
	}
	
	// Track title
	title = [_metadata trackTitle];
	if(nil != title) {
		f.tag()->setTitle(TagLib::String([title UTF8String], TagLib::String::UTF8));
	}
	
	// Track number
	trackNumber = [_metadata trackNumber];
	if(nil != trackNumber) {
		f.tag()->setTrack([trackNumber unsignedIntValue]);
	}

	f.save();
}

- (NSString *) getType
{
	return @"Ogg Vorbis";
}

@end
