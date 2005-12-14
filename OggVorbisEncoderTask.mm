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

- (id) initWithSource:(RipperTask *)source target:(NSString *)target tracks:(NSArray *)tracks
{
	if((self = [super initWithSource:source target:target tracks:tracks])) {
		_encoder = [[OggVorbisEncoder alloc] initWithSource:[_source valueForKey:@"path"]];
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
	Track										*track					= [_tracks objectAtIndex:0];

	
	// Album title
	album = [track valueForKeyPath:@"disc.title"];
	if(nil != album) {
		f.tag()->setAlbum(TagLib::String([album UTF8String], TagLib::String::UTF8));
	}
	
	// Artist
	if(1 == [_tracks count]) {
		artist = [track valueForKey:@"artist"];
	}
	if(nil == artist) {
		artist = [track valueForKeyPath:@"disc.artist"];
	}
	if(nil != artist) {
		f.tag()->setArtist(TagLib::String([artist UTF8String], TagLib::String::UTF8));
	}
	
	// Genre
	if(1 == [_tracks count]) {
		genre = [track valueForKey:@"genre"];
	}
	if(nil == genre) {
		genre = [track valueForKeyPath:@"disc.genre"];
	}
	if(nil != genre) {
		f.tag()->setGenre(TagLib::String([genre UTF8String], TagLib::String::UTF8));
	}
	
	// Year
	if(1 == [_tracks count]) {
		year = [track valueForKey:@"year"];
	}
	if(nil == year) {
		year = [track valueForKeyPath:@"disc.year"];
	}
	if(nil != year) {
		f.tag()->setYear([year intValue]);
	}
	
	// Comment
	if(_writeSettingsToComment) {
		comment = (nil == comment ? [_encoder description] : [comment stringByAppendingString:[NSString stringWithFormat:@"\n%@", [_encoder description]]]);
	}
	comment = [track valueForKeyPath:@"disc.comment"];
	if(nil != comment) {
		f.tag()->setComment(TagLib::String([comment UTF8String], TagLib::String::UTF8));
	}
	
	if(1 == [_tracks count]) {
		// Track title
		title = [track valueForKey:@"title"];
		if(nil != title) {
			f.tag()->setTitle(TagLib::String([title UTF8String], TagLib::String::UTF8));
		}
		
		// Track number
		trackNumber = [track valueForKey:@"number"];
		if(nil != trackNumber) {
			f.tag()->setTrack([trackNumber unsignedIntValue]);
		}
	}
	else {
		NSEnumerator	*enumerator;
		Track			*temp;
		
		enumerator	= [_tracks objectEnumerator];
		temp		= [enumerator nextObject];
		
		title		= [temp valueForKey:@"title"];
		
		while((temp = [enumerator nextObject])) {
			title = [title stringByAppendingString:[NSString stringWithFormat:@", %@", [temp valueForKey:@"title"]]];
		}

		if(nil != title) {
			f.tag()->setTitle(TagLib::String([title UTF8String], TagLib::String::UTF8));
		}
		
	}
	f.save();
}

- (NSString *) getType
{
	return @"Ogg Vorbis";
}

@end
