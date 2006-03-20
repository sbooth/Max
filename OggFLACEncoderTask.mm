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

#import "OggFLACEncoderTask.h"
#import "OggFLACEncoder.h"
#import "IOException.h"

#include <TagLib/oggflacfile.h>			// TagLib::File
#include <TagLib/tag.h>					// TagLib::Tag

@implementation OggFLACEncoderTask

- (id) initWithTask:(PCMGeneratingTask *)task
{
	if((self = [super initWithTask:task])) {
		_encoderClass = [OggFLACEncoder class];
		return self;
	}
	return nil;
}

- (void) writeTags
{
	AudioMetadata								*metadata				= [_task metadata];
	unsigned									trackNumber				= 0;
	NSString									*album					= nil;
	NSString									*artist					= nil;
	NSString									*title					= nil;
	unsigned									year					= 0;
	NSString									*genre					= nil;
	NSString									*comment				= nil;
	TagLib::Ogg::FLAC::File						f						([_outputFilename fileSystemRepresentation], false);
	
	
	if(NO == f.isValid()) {
		@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to open the output file for tagging.", @"Exceptions", @"") userInfo:nil];
	}
	
	// Album title
	album = [metadata albumTitle];
	if(nil != album) {
		f.tag()->setAlbum(TagLib::String([album UTF8String], TagLib::String::UTF8));
	}
	
	// Artist
	artist = [metadata trackArtist];
	if(nil == artist) {
		artist = [metadata albumArtist];
	}
	if(nil != artist) {
		f.tag()->setArtist(TagLib::String([artist UTF8String], TagLib::String::UTF8));
	}
	
	// Genre
	genre = [metadata trackGenre];
	if(nil == genre) {
		genre = [metadata albumGenre];
	}
	if(nil != genre) {
		f.tag()->setGenre(TagLib::String([genre UTF8String], TagLib::String::UTF8));
	}
	
	// Year
	year = [metadata trackYear];
	if(0 == year) {
		year = [metadata albumYear];
	}
	if(0 != year) {
		f.tag()->setYear(year);
	}
	
	// Comment
	comment = [metadata albumComment];
	if(_writeSettingsToComment) {
		comment = (nil == comment ? [self settings] : [comment stringByAppendingString:[NSString stringWithFormat:@"\n%@", [self settings]]]);
	}
	if(nil != comment) {
		f.tag()->setComment(TagLib::String([comment UTF8String], TagLib::String::UTF8));
	}
	
	// Track title
	title = [metadata trackTitle];
	if(nil != title) {
		f.tag()->setTitle(TagLib::String([title UTF8String], TagLib::String::UTF8));
	}
	
	// Track number
	trackNumber = [metadata trackNumber];
	if(0 != trackNumber) {
		f.tag()->setTrack(trackNumber);
	}
	
	f.save();
}

- (NSString *)		extension						{ return @"oggflac"; }
- (NSString *)		outputFormat					{ return NSLocalizedStringFromTable(@"Ogg FLAC", @"General", @""); }

@end
