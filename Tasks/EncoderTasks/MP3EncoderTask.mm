/*
 *  $Id$
 *
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

#import "MP3EncoderTask.h"
#import "MP3Encoder.h"
#import "Genres.h"

#import "UtilityFunctions.h"

#include <lame/lame.h>						// get_lame_version

#include <taglib/mpegfile.h>				// TagLib::MPEG::File
#include <taglib/tag.h>						// TagLib::Tag
#include <taglib/tstring.h>					// TagLib::String
#include <taglib/tbytevector.h>				// TagLib::ByteVector
#include <taglib/textidentificationframe.h>	// TagLib::ID3V2::TextIdentificationFrame
#include <taglib/attachedpictureframe.h>	// TagLib::ID3V2::AttachedPictureFrame
#include <taglib/id3v2tag.h>				// TagLib::ID3V2::Tag

@implementation MP3EncoderTask

- (id) init
{
	if((self = [super init])) {
		_encoderClass = [MP3Encoder class];
		return self;
	}
	return nil;
}

- (void) writeTags
{
	AudioMetadata								*metadata				= [[self taskInfo] metadata];
	unsigned									trackNumber				= 0;
	unsigned									trackTotal				= 0;
	NSString									*album					= nil;
	NSString									*artist					= nil;
	NSString									*composer				= nil;
	NSString									*title					= nil;
	unsigned									year					= 0;
	NSString									*genre					= nil;
	NSString									*comment				= nil;
	NSString									*trackComment			= nil;
	BOOL										compilation				= NO;
	unsigned									discNumber				= 0;
	unsigned									discTotal				= 0;
	unsigned									length					= 0;
	TagLib::ID3v2::TextIdentificationFrame		*frame					= NULL;
	TagLib::ID3v2::AttachedPictureFrame			*pictureFrame			= NULL;
	NSImage										*albumArt				= nil;
	NSData										*data					= nil;
	TagLib::MPEG::File							f						([[self outputFilename] fileSystemRepresentation], false);
	NSString									*bundleVersion			= nil;
	NSString									*versionString			= nil;
	NSString									*timestamp				= nil;
	unsigned									index					= NSNotFound;
	
	NSAssert(f.isValid(), NSLocalizedStringFromTable(@"Unable to open the output file for tagging.", @"Exceptions", @""));

	// Use UTF-8 as the default encoding
	(TagLib::ID3v2::FrameFactory::instance())->setDefaultTextEncoding(TagLib::String::UTF8);
	
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
	
	// Composer
	composer = [metadata trackComposer];
	if(nil == composer) {
		composer = [metadata albumComposer];
	}
	if(nil != composer) {
		frame = new TagLib::ID3v2::TextIdentificationFrame("TCOM", TagLib::String::Latin1);
		NSAssert(NULL != frame, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));

		frame->setText(TagLib::String([composer UTF8String], TagLib::String::UTF8));
		f.ID3v2Tag()->addFrame(frame);
	}

	// Genre
	genre = [metadata trackGenre];
	if(nil == genre) {
		genre = [metadata albumGenre];
	}
  	if(nil != genre) {
 		// There is a bug in iTunes that will show numeric genres for ID3v2.4 genre tags
 		if([[NSUserDefaults standardUserDefaults] boolForKey:@"useiTunesWorkarounds"]) {
 			index = [[Genres unsortedGenres] indexOfObject:genre];
 			
 			frame = new TagLib::ID3v2::TextIdentificationFrame("TCON", TagLib::String::Latin1);
			NSAssert(NULL != frame, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));
 
 			// Only use numbers for the original ID3v1 genre list
 			if(NSNotFound == index) {
 				frame->setText(TagLib::String([genre UTF8String], TagLib::String::UTF8));
 			}
 			else {
 				frame->setText(TagLib::String([[NSString stringWithFormat:@"(%u)", index] UTF8String], TagLib::String::UTF8));
 			}
 			
 			f.ID3v2Tag()->addFrame(frame);
 		}
 		else {
 			f.tag()->setGenre(TagLib::String([genre UTF8String], TagLib::String::UTF8));
		}
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
	comment			= [metadata albumComment];
	trackComment	= [metadata trackComment];
	if(nil != trackComment) {
		comment = (nil == comment ? trackComment : [NSString stringWithFormat:@"%@\n%@", trackComment, comment]);
	}
	if([[[[self taskInfo] settings] objectForKey:@"saveSettingsInComment"] boolValue]) {
		comment = (nil == comment ? [self encoderSettingsString] : [NSString stringWithFormat:@"%@\n%@", comment, [self encoderSettingsString]]);
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
	trackNumber		= [metadata trackNumber];
	trackTotal		= [metadata trackTotal];
	if(0 != trackTotal) {
		frame = new TagLib::ID3v2::TextIdentificationFrame("TRCK", TagLib::String::Latin1);
		NSAssert(NULL != frame, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));

		frame->setText(TagLib::String([[NSString stringWithFormat:@"%u/%u", trackNumber, trackTotal] UTF8String], TagLib::String::UTF8));
		f.ID3v2Tag()->addFrame(frame);
	}
	else if(0 != trackNumber) {
		f.tag()->setTrack(trackNumber);
	}
		
	// Multi-artist (compilation)
	// iTunes uses the TCMP frame for this, which isn't in the standard, but we'll use it for compatibility
	compilation = [metadata compilation];
	if(compilation && [[NSUserDefaults standardUserDefaults] boolForKey:@"useiTunesWorkarounds"]) {
		frame = new TagLib::ID3v2::TextIdentificationFrame("TCMP", TagLib::String::Latin1);
		NSAssert(NULL != frame, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));

		frame->setText(TagLib::String("1", TagLib::String::Latin1));
		f.ID3v2Tag()->addFrame(frame);
	}	
	
	// Disc number
	discNumber = [metadata discNumber];
	discTotal = [metadata discTotal];
	
	if(0 != discNumber && 0 != discTotal) {
		frame = new TagLib::ID3v2::TextIdentificationFrame("TPOS", TagLib::String::Latin1);
		NSAssert(NULL != frame, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));

		frame->setText(TagLib::String([[NSString stringWithFormat:@"%u/%u", discNumber, discTotal] UTF8String], TagLib::String::UTF8));
		f.ID3v2Tag()->addFrame(frame);
	}
	else if(0 != discNumber) {
		frame = new TagLib::ID3v2::TextIdentificationFrame("TPOS", TagLib::String::Latin1);
		NSAssert(NULL != frame, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));

		frame->setText(TagLib::String([[NSString stringWithFormat:@"%u", discNumber] UTF8String], TagLib::String::UTF8));
		f.ID3v2Tag()->addFrame(frame);
	}
	else if(0 != discTotal) {
		frame = new TagLib::ID3v2::TextIdentificationFrame("TPOS", TagLib::String::Latin1);
		NSAssert(NULL != frame, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));

		frame->setText(TagLib::String([[NSString stringWithFormat:@"/@u", discTotal] UTF8String], TagLib::String::UTF8));
		f.ID3v2Tag()->addFrame(frame);
	}
	
	// Track length
	length = [metadata length];
	if(nil != [[self taskInfo] inputTracks]) {		
		// Sum up length of all tracks
		unsigned minutes	= [[[[self taskInfo] inputTracks] valueForKeyPath:@"@sum.minute"] unsignedIntValue];
		unsigned seconds	= [[[[self taskInfo] inputTracks] valueForKeyPath:@"@sum.second"] unsignedIntValue];
		unsigned frames		= [[[[self taskInfo] inputTracks] valueForKeyPath:@"@sum.frame"] unsignedIntValue];
		unsigned ms			= ((60 * minutes) + seconds + (unsigned)(frames / 75.0)) * 1000;

		frame = new TagLib::ID3v2::TextIdentificationFrame("TLEN", TagLib::String::Latin1);
		NSAssert(NULL != frame, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));

		frame->setText(TagLib::String([[NSString stringWithFormat:@"%u", ms] UTF8String], TagLib::String::UTF8));
		f.ID3v2Tag()->addFrame(frame);
	}
	else if(0 != length) {
		frame = new TagLib::ID3v2::TextIdentificationFrame("TLEN", TagLib::String::Latin1);
		NSAssert(NULL != frame, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));

		frame->setText(TagLib::String([[NSString stringWithFormat:@"%u", 1000 * length] UTF8String], TagLib::String::UTF8));
		f.ID3v2Tag()->addFrame(frame);
	}
	
	// Album art
	albumArt = [metadata albumArt];
	if(nil != albumArt) {
		data			= getPNGDataForImage(albumArt); 
		pictureFrame	= new TagLib::ID3v2::AttachedPictureFrame();
		NSAssert(NULL != pictureFrame, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));

		pictureFrame->setMimeType(TagLib::String("image/png", TagLib::String::Latin1));
		pictureFrame->setPicture(TagLib::ByteVector((const char *)[data bytes], [data length]));
		f.ID3v2Tag()->addFrame(pictureFrame);
	}
	
	// Encoded by
	frame = new TagLib::ID3v2::TextIdentificationFrame("TENC", TagLib::String::Latin1);
	NSAssert(NULL != frame, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));

	bundleVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
	versionString = [NSString stringWithFormat:@"LAME %s (Max %@)", get_lame_short_version(), bundleVersion];
	frame->setText(TagLib::String([versionString UTF8String], TagLib::String::UTF8));
	f.ID3v2Tag()->addFrame(frame);
	
	// Encoding time
	frame = new TagLib::ID3v2::TextIdentificationFrame("TDEN", TagLib::String::Latin1);
	timestamp = getID3v2Timestamp();
	NSAssert(NULL != frame, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));

	frame->setText(TagLib::String([timestamp UTF8String], TagLib::String::UTF8));
	f.ID3v2Tag()->addFrame(frame);
	
	// Tagging time
	frame = new TagLib::ID3v2::TextIdentificationFrame("TDTG", TagLib::String::Latin1);
	timestamp = getID3v2Timestamp();
	NSAssert(NULL != frame, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));

	frame->setText(TagLib::String([timestamp UTF8String], TagLib::String::UTF8));
	f.ID3v2Tag()->addFrame(frame);
	
	f.save();
}

- (NSString *)		fileExtension					{ return @"mp3"; }
- (NSString *)		outputFormatName				{ return NSLocalizedStringFromTable(@"MP3", @"General", @""); }

@end

@implementation MP3EncoderTask (CueSheetExtensions)

- (BOOL)			formatIsValidForCueSheet		{ return YES; }
- (NSString *)		cueSheetFormatName				{ return @"MP3"; }

@end

@implementation MP3EncoderTask (iTunesAdditions)

- (BOOL)			formatIsValidForiTunes			{ return YES; }

@end
