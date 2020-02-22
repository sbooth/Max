/*
 *  Copyright (C) 2005 - 2007 Stephen F. Booth <me@sbooth.org>
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

#include <taglib/vorbisfile.h>			// TagLib::Ogg::Vorbis::File
#include <taglib/tag.h>					// TagLib::Tag

@interface AudioMetadata (TagMappings)
+ (TagLib::String)		customizeOggVorbisTag:(NSString *)tag;
@end

@implementation OggVorbisEncoderTask

- (id) init
{
	if((self = [super init])) {
		_encoderClass = [OggVorbisEncoder class];
		return self;
	}
	return nil;
}

- (void) writeTags
{
	AudioMetadata								*metadata					= [[self taskInfo] metadata];
	NSNumber									*trackNumber				= nil;
	NSNumber									*trackTotal					= nil;
	NSNumber									*discNumber					= nil;
	NSNumber									*discTotal					= nil;
	NSNumber									*compilation				= nil;
	NSString									*album						= nil;
	NSString									*artist						= nil;
	NSString									*composer					= nil;
	NSString									*title						= nil;
	NSString									*year						= nil;
	NSString									*genre						= nil;
	NSString									*comment					= nil;
	NSString									*trackComment				= nil;
	NSString									*isrc						= nil;
	NSString									*mcn						= nil;
	NSString									*musicbrainzTrackId			= nil;
	NSString									*musicbrainzAlbumId			= nil;
	NSString									*musicbrainzArtistId		= nil;
	NSString									*musicbrainzAlbumArtistId	= nil;
	NSString									*musicbrainzDiscId			= nil;
	NSString									*bundleVersion, *versionString;
	TagLib::Ogg::Vorbis::File					f						([[self outputFilename] fileSystemRepresentation], false);

	NSAssert(f.isValid(), NSLocalizedStringFromTable(@"Unable to open the output file for tagging.", @"Exceptions", @""));

	// Album title
	album = [metadata albumTitle];
	if(nil != album)
		f.tag()->addField([AudioMetadata customizeOggVorbisTag:@"ALBUM"], TagLib::String([album UTF8String], TagLib::String::UTF8));
	
	// Artist
	artist = [metadata trackArtist];
	if(nil == artist)
		artist = [metadata albumArtist];
	if(nil != artist)
		f.tag()->addField([AudioMetadata customizeOggVorbisTag:@"ARTIST"], TagLib::String([artist UTF8String], TagLib::String::UTF8));

	// Composer
	composer = [metadata trackComposer];
	if(nil == composer)
		composer = [metadata albumComposer];
	if(nil != composer)
		f.tag()->addField([AudioMetadata customizeOggVorbisTag:@"COMPOSER"], TagLib::String([composer UTF8String], TagLib::String::UTF8));
	
	// Genre
	genre = [metadata trackGenre];
	if(nil == genre)
		genre = [metadata albumGenre];
	if(nil != genre)
		f.tag()->addField([AudioMetadata customizeOggVorbisTag:@"GENRE"], TagLib::String([genre UTF8String], TagLib::String::UTF8));
	
	// Year
	year = [metadata trackDate];
	if(nil == year)
		year = [metadata albumDate];
	if(nil != year)
		f.tag()->addField([AudioMetadata customizeOggVorbisTag:@"DATE"], TagLib::String([year UTF8String], TagLib::String::UTF8));
	
	// Comment
	comment			= [metadata albumComment];
	trackComment	= [metadata trackComment];
	if(nil != trackComment)
		comment = (nil == comment ? trackComment : [NSString stringWithFormat:@"%@\n%@", trackComment, comment]);
	if([[[[self taskInfo] settings] objectForKey:@"saveSettingsInComment"] boolValue])
		comment = (nil == comment ? [self encoderSettingsString] : [NSString stringWithFormat:@"%@\n%@", comment, [self encoderSettingsString]]);
	if(nil != comment)
		f.tag()->addField([AudioMetadata customizeOggVorbisTag:@"DESCRIPTION"], TagLib::String([comment UTF8String], TagLib::String::UTF8));
	
	// Track title
	title = [metadata trackTitle];
	if(nil != title)
		f.tag()->addField([AudioMetadata customizeOggVorbisTag:@"TITLE"], TagLib::String([title UTF8String], TagLib::String::UTF8));
	
	// Track number
	trackNumber = [metadata trackNumber];
	if(nil != trackNumber)
		f.tag()->addField([AudioMetadata customizeOggVorbisTag:@"TRACKNUMBER"], TagLib::String([[trackNumber stringValue] UTF8String], TagLib::String::UTF8));

	// Track total
	trackTotal = [metadata trackTotal];
	if(nil != trackTotal)
		f.tag()->addField([AudioMetadata customizeOggVorbisTag:@"TRACKTOTAL"], TagLib::String([[trackTotal stringValue] UTF8String], TagLib::String::UTF8));

	// Disc number
	discNumber = [metadata discNumber];
	if(nil != discNumber)
		f.tag()->addField([AudioMetadata customizeOggVorbisTag:@"DISCNUMBER"], TagLib::String([[discNumber stringValue] UTF8String], TagLib::String::UTF8));
	
	// Discs in set
	discTotal = [metadata discTotal];
	if(nil != discTotal)
		f.tag()->addField([AudioMetadata customizeOggVorbisTag:@"DISCTOTAL"], TagLib::String([[discTotal stringValue] UTF8String], TagLib::String::UTF8));

	// Compilation
	compilation = [metadata compilation];
	if(nil != compilation)
		f.tag()->addField([AudioMetadata customizeOggVorbisTag:@"COMPILATION"], TagLib::String([[compilation stringValue] UTF8String], TagLib::String::UTF8));
	
	// ISRC
	isrc = [metadata ISRC];
	if(nil != isrc)
		f.tag()->addField([AudioMetadata customizeOggVorbisTag:@"ISRC"], TagLib::String([isrc UTF8String], TagLib::String::UTF8));

	// MCN
	mcn = [metadata MCN];
	if(nil != mcn)
		f.tag()->addField([AudioMetadata customizeOggVorbisTag:@"MCN"], TagLib::String([mcn UTF8String], TagLib::String::UTF8));
	
	// MusicBrainz Track Id
	musicbrainzTrackId = [metadata musicbrainzTrackId];
	if(nil != musicbrainzTrackId)
		f.tag()->addField([@"MUSICBRAINZ_TRACKID" UTF8String], TagLib::String([musicbrainzTrackId UTF8String], TagLib::String::UTF8));
	
	// MusicBrainz Album Id
	musicbrainzAlbumId = [metadata musicbrainzAlbumId];
	if(nil != musicbrainzAlbumId)
		f.tag()->addField([@"MUSICBRAINZ_ALBUMID" UTF8String], TagLib::String([musicbrainzAlbumId UTF8String], TagLib::String::UTF8));
	
	// MusicBrainz Artist Id
	musicbrainzArtistId = [metadata musicbrainzArtistId];
	if(nil != musicbrainzArtistId)
		f.tag()->addField([@"MUSICBRAINZ_ARTISTID" UTF8String], TagLib::String([musicbrainzArtistId UTF8String], TagLib::String::UTF8));
	
	// MusicBrainz Album Artist Id
	musicbrainzAlbumArtistId = [metadata musicbrainzAlbumArtistId];
	if(nil != musicbrainzAlbumArtistId)
		f.tag()->addField([@"MUSICBRAINZ_ALBUMARTISTID" UTF8String], TagLib::String([musicbrainzAlbumArtistId UTF8String], TagLib::String::UTF8));
	
	// MusicBrainz Disc Id
	musicbrainzDiscId = [metadata discId];
	if(nil != musicbrainzDiscId)
		f.tag()->addField([@"MUSICBRAINZ_DISCID" UTF8String], TagLib::String([musicbrainzDiscId UTF8String], TagLib::String::UTF8));
	
	// Encoded by
	bundleVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
	versionString = [NSString stringWithFormat:@"Max %@", bundleVersion];
	f.tag()->addField("ENCODER", TagLib::String([versionString UTF8String], TagLib::String::UTF8));

	// Encoder settings
	f.tag()->addField("ENCODING", TagLib::String([[self encoderSettingsString] UTF8String], TagLib::String::UTF8));
	
	f.save();
}

- (NSString *)		fileExtension					{ return @"ogg"; }
- (NSString *)		outputFormatName				{ return NSLocalizedStringFromTable(@"Ogg Vorbis", @"General", @""); }

@end
