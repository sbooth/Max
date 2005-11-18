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

#import "Tagger.h"

#import "MallocException.h"
#import "UtilityFunctions.h"

#include "lame/lame.h"					// get_lame_version

#include "mpegfile.h"					// TagLib::MPEG::File
#include "tag.h"						// TagLib::Tag
#include "tstring.h"					// TagLib::String
#include "textidentificationframe.h"	// TagLib::ID3V2::TextIdentificationFrame
#include "id3v2tag.h"					// TagLib::ID3V2::Tag

@implementation Tagger

+ (void) tagFile:(NSString *)filename fromTrack:(Track *)track
{
	NSNumber									*trackNumber			= nil;
	unsigned int								totalTracks				= 0;
	NSString									*album					= nil;
	NSString									*artist					= nil;
	NSString									*title					= nil;
	NSNumber									*year					= nil;
	NSString									*genre					= nil;
	NSString									*comment				= nil;
	NSNumber									*discNumber				= nil;
	NSNumber									*discsInSet				= nil;
	TagLib::ID3v2::TextIdentificationFrame		*frame					= nil;
	TagLib::MPEG::File							f						([filename UTF8String]);
	NSString									*bundleVersion			= nil;
	NSString									*versionString			= nil;
	NSString									*timestamp				= nil;
		
	// Track title
	title = [track valueForKey:@"title"];
	if(nil != title) {
		f.tag()->setTitle(TagLib::String([title UTF8String], TagLib::String::UTF8));
	}

	// Track number
	trackNumber = [track valueForKey:@"number"];
	totalTracks = [[[track valueForKey:@"disc"] valueForKey:@"tracks"] count];
	frame = new TagLib::ID3v2::TextIdentificationFrame("TRCK", TagLib::String::Latin1);
	if(nil == frame) {
		@throw [MallocException exceptionWithReason:@"Unable to allocate memory" userInfo:nil];
	}
	frame->setText(TagLib::String([[NSString stringWithFormat:@"%@/%u", trackNumber, totalTracks] UTF8String], TagLib::String::UTF8));
	f.ID3v2Tag()->addFrame(frame);
	
	
	// Album title
	album = [[track valueForKey:@"disc"] valueForKey:@"title"];
	if(nil != album) {
		f.tag()->setAlbum(TagLib::String([album UTF8String], TagLib::String::UTF8));
	}
	
	// Artist (fall back to disc)
	artist = [track valueForKey:@"artist"];
	if(nil == artist) {
		artist = [[track valueForKey:@"disc"] valueForKey:@"artist"];
	}
	if(nil != artist) {
		f.tag()->setArtist(TagLib::String([artist UTF8String], TagLib::String::UTF8));
	}

	// Genre (fall back to disc)
	genre = [track valueForKey:@"genre"];
	if(nil == genre) {
		genre = [[track valueForKey:@"disc"] valueForKey:@"genre"];
	}
	if(nil != genre) {
		f.tag()->setGenre(TagLib::String([genre UTF8String], TagLib::String::UTF8));
	}
	
	// Year (fall back to disc)
	year = [track valueForKey:@"year"];
	if(nil == year) {
		year = [[track valueForKey:@"disc"] valueForKey:@"year"];
	}
	if(nil != year) {
		f.tag()->setYear([year intValue]);
	}
	
	// Comment
	comment = [[track valueForKey:@"disc"] valueForKey:@"comment"];
	if(nil != comment) {
		f.tag()->setComment(TagLib::String([comment UTF8String], TagLib::String::UTF8));
	}

	// Disc number
	discNumber = [[track valueForKey:@"disc"] valueForKey:@"discNumber"];
	discsInSet = [[track valueForKey:@"disc"] valueForKey:@"discsInSet"];
	
	if(nil != discNumber && nil != discsInSet) {
		frame = new TagLib::ID3v2::TextIdentificationFrame("TPOS", TagLib::String::Latin1);
		if(nil == frame) {
			@throw [MallocException exceptionWithReason:@"Unable to allocate memory" userInfo:nil];
		}
		frame->setText(TagLib::String([[NSString stringWithFormat:@"%@/%@", discNumber, discsInSet] UTF8String], TagLib::String::UTF8));
		f.ID3v2Tag()->addFrame(frame);
	}
	else if(nil != discNumber) {
		frame = new TagLib::ID3v2::TextIdentificationFrame("TPOS", TagLib::String::Latin1);
		if(nil == frame) {
			@throw [MallocException exceptionWithReason:@"Unable to allocate memory" userInfo:nil];
		}
		frame->setText(TagLib::String([[discNumber stringValue] UTF8String], TagLib::String::UTF8));
		f.ID3v2Tag()->addFrame(frame);
	}
	else if(nil != discsInSet) {
		frame = new TagLib::ID3v2::TextIdentificationFrame("TPOS", TagLib::String::Latin1);
		if(nil == frame) {
			@throw [MallocException exceptionWithReason:@"Unable to allocate memory" userInfo:nil];
		}
		frame->setText(TagLib::String([[NSString stringWithFormat:@"/@u", discsInSet] UTF8String], TagLib::String::UTF8));
		f.ID3v2Tag()->addFrame(frame);
	}

	// Encoded by
	frame = new TagLib::ID3v2::TextIdentificationFrame("TENC", TagLib::String::Latin1);
	if(nil == frame) {
		@throw [MallocException exceptionWithReason:@"Unable to allocate memory" userInfo:nil];
	}
	bundleVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
	versionString = [NSString stringWithFormat:@"LAME %s (Max %@)", get_lame_version(), bundleVersion];
	frame->setText(TagLib::String([versionString UTF8String], TagLib::String::UTF8));
	f.ID3v2Tag()->addFrame(frame);
	
	// Encoding time
	frame = new TagLib::ID3v2::TextIdentificationFrame("TDEN", TagLib::String::Latin1);
	timestamp = getID3v2Timestamp();
	if(nil == frame) {
		@throw [MallocException exceptionWithReason:@"Unable to allocate memory" userInfo:nil];
	}
	frame->setText(TagLib::String([timestamp UTF8String], TagLib::String::UTF8));
	f.ID3v2Tag()->addFrame(frame);

	// Tagging time
	frame = new TagLib::ID3v2::TextIdentificationFrame("TDTG", TagLib::String::Latin1);
	timestamp = getID3v2Timestamp();
	if(nil == frame) {
		@throw [MallocException exceptionWithReason:@"Unable to allocate memory" userInfo:nil];
	}
	frame->setText(TagLib::String([timestamp UTF8String], TagLib::String::UTF8));
	f.ID3v2Tag()->addFrame(frame);
	
	f.save();
}

@end
