/*
 *  Copyright (C) 2005 - 2020 Stephen F. Booth <me@sbooth.org>
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

#import "WavPackEncoderTask.h"
#import "WavPackEncoder.h"

#include <wavpack/wavpack.h>

@interface AudioMetadata (TagMappings)
+ (NSString *)			customizeWavPackTag:(NSString *)tag;
@end

@implementation WavPackEncoderTask

- (id) init
{
	if((self = [super init])) {
		_encoderClass = [WavPackEncoder class];
		return self;
	}
	return nil;
}

- (void) writeTags
{
	AudioMetadata								*metadata				= [[self taskInfo] metadata];
	NSNumber									*trackNumber			= nil;
	NSNumber									*trackTotal				= nil;
	NSNumber									*discNumber				= nil;
	NSNumber									*discTotal				= nil;
	NSNumber									*compilation			= nil;
	NSString									*album					= nil;
	NSString									*artist					= nil;
	NSString									*composer				= nil;
	NSString									*title					= nil;
	NSString									*year					= nil;
	NSString									*genre					= nil;
	NSString									*comment				= nil;
	NSString									*trackComment			= nil;
	NSString									*isrc					= nil;
	NSString									*mcn					= nil;
	NSString									*bundleVersion;
    WavpackContext								*wpc					= NULL;
	char										error [80];
	int											result;
		
	wpc = WavpackOpenFileInput([[self outputFilename] fileSystemRepresentation], error, OPEN_EDIT_TAGS, 0);
	NSAssert(NULL != wpc, NSLocalizedStringFromTable(@"Unable to open the output file.", @"Exceptions", @""));
	
	// Album title
	album = [metadata albumTitle];
	if(nil != album)
		WavpackAppendTagItem(wpc, [[AudioMetadata customizeWavPackTag:@"ALBUM"] cStringUsingEncoding:NSASCIIStringEncoding], [album UTF8String], (int)strlen([album UTF8String]));
	
	// Artist
	artist = [metadata trackArtist];
	if(nil == artist)
		artist = [metadata albumArtist];
	if(nil != artist)
		WavpackAppendTagItem(wpc, [[AudioMetadata customizeWavPackTag:@"ARTIST"] cStringUsingEncoding:NSASCIIStringEncoding], [artist UTF8String], (int)strlen([artist UTF8String]));
	
	// Composer
	composer = [metadata trackComposer];
	if(nil == composer)
		composer = [metadata albumComposer];
	if(nil != composer)
		WavpackAppendTagItem(wpc, [[AudioMetadata customizeWavPackTag:@"COMPOSER"] cStringUsingEncoding:NSASCIIStringEncoding], [composer UTF8String], (int)strlen([composer UTF8String]));
	
	// Genre
	genre = [metadata trackGenre];
	if(nil == genre)
		genre = [metadata albumGenre];
	if(nil != genre)
		WavpackAppendTagItem(wpc, [[AudioMetadata customizeWavPackTag:@"GENRE"] cStringUsingEncoding:NSASCIIStringEncoding], [genre UTF8String], (int)strlen([genre UTF8String]));
	
	// Year
	year = [metadata trackDate];
	if(nil == year)
		year = [metadata albumDate];
	if(nil != year)
		WavpackAppendTagItem(wpc, [[AudioMetadata customizeWavPackTag:@"YEAR"] cStringUsingEncoding:NSASCIIStringEncoding], [year UTF8String], (int)strlen([year UTF8String]));
	
	// Comment
	comment			= [metadata albumComment];
	trackComment	= [metadata trackComment];
	if(nil != trackComment)
		comment = (nil == comment ? trackComment : [NSString stringWithFormat:@"%@\n%@", trackComment, comment]);
	if([[[[self taskInfo] settings] objectForKey:@"saveSettingsInComment"] boolValue])
		comment = (nil == comment ? [self encoderSettingsString] : [NSString stringWithFormat:@"%@\n%@", comment, [self encoderSettingsString]]);
	if(nil != comment)
		WavpackAppendTagItem(wpc, [[AudioMetadata customizeWavPackTag:@"COMMENT"] cStringUsingEncoding:NSASCIIStringEncoding], [comment UTF8String], (int)strlen([comment UTF8String]));
	
	// Track title
	title = [metadata trackTitle];
	if(nil != title)
		WavpackAppendTagItem(wpc, [[AudioMetadata customizeWavPackTag:@"TITLE"] cStringUsingEncoding:NSASCIIStringEncoding], [title UTF8String], (int)strlen([title UTF8String]));
	
	// Track number
	trackNumber = [metadata trackNumber];
	if(nil != trackNumber)
		WavpackAppendTagItem(wpc, [[AudioMetadata customizeWavPackTag:@"TRACK"] cStringUsingEncoding:NSASCIIStringEncoding], [[NSString stringWithFormat:@"%u", [trackNumber intValue]] UTF8String], (int)strlen([[NSString stringWithFormat:@"%u", [trackNumber intValue]] UTF8String]));
	
	// Track total
	trackTotal = [metadata trackTotal];
	if(nil != trackTotal)
		WavpackAppendTagItem(wpc, [[AudioMetadata customizeWavPackTag:@"TRACKTOTAL"] cStringUsingEncoding:NSASCIIStringEncoding], [[NSString stringWithFormat:@"%u", [trackTotal intValue]] UTF8String], (int)strlen([[NSString stringWithFormat:@"%u", [trackTotal intValue]] UTF8String]));
	
	// Disc number
	discNumber = [metadata discNumber];
	if(nil != discNumber)
		WavpackAppendTagItem(wpc, [[AudioMetadata customizeWavPackTag:@"DISCNUMBER"] cStringUsingEncoding:NSASCIIStringEncoding], [[NSString stringWithFormat:@"%u", [discNumber intValue]] UTF8String], (int)strlen([[NSString stringWithFormat:@"%u", [discNumber intValue]] UTF8String]));
	
	// Discs in set
	discTotal = [metadata discTotal];
	if(nil != discTotal)
		WavpackAppendTagItem(wpc, [[AudioMetadata customizeWavPackTag:@"DISCTOTAL"] cStringUsingEncoding:NSASCIIStringEncoding], [[NSString stringWithFormat:@"%u", [discTotal intValue]] UTF8String], (int)strlen([[NSString stringWithFormat:@"%u", [discTotal intValue]] UTF8String]));
	
	// Compilation
	compilation = [metadata compilation];
	if(nil != compilation)
		WavpackAppendTagItem(wpc, [[AudioMetadata customizeWavPackTag:@"COMPILATION"] cStringUsingEncoding:NSASCIIStringEncoding], [[NSString stringWithFormat:@"%u", [compilation intValue]] UTF8String], (int)strlen([[NSString stringWithFormat:@"%u", [compilation intValue]] UTF8String]));
	
	// ISRC
	isrc = [metadata ISRC];
	if(nil != isrc)
		WavpackAppendTagItem(wpc, [[AudioMetadata customizeWavPackTag:@"ISRC"] cStringUsingEncoding:NSASCIIStringEncoding], [isrc UTF8String], (int)strlen([isrc UTF8String]));
	
	// MCN
	mcn = [metadata MCN];
	if(nil != mcn)
		WavpackAppendTagItem(wpc, [[AudioMetadata customizeWavPackTag:@"MCN"] cStringUsingEncoding:NSASCIIStringEncoding], [mcn UTF8String], (int)strlen([mcn UTF8String]));
	
	// Encoded by
	bundleVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
	WavpackAppendTagItem(wpc, "TOOL NAME", "Max", (int)strlen("Max"));
	WavpackAppendTagItem(wpc, "TOOL VERSION", [bundleVersion UTF8String], (int)strlen([bundleVersion UTF8String]));
	
	// Encoder settings
	WavpackAppendTagItem(wpc, "ENCODING", [[self encoderSettingsString] UTF8String], (int)strlen([[self encoderSettingsString] UTF8String]));

	result = WavpackWriteTag(wpc);
	NSAssert(0 != result, NSLocalizedStringFromTable(@"Unable to write to the output file.", @"Exceptions", @""));
	
	wpc = WavpackCloseFile(wpc);
	NSAssert(NULL == wpc, NSLocalizedStringFromTable(@"Unable to close the output file.", @"Exceptions", @""));
}

- (NSString *)		fileExtension					{ return @"wv"; }
- (NSString *)		outputFormatName				{ return NSLocalizedStringFromTable(@"WavPack", @"General", @""); }

@end

@implementation WavPackEncoderTask (CueSheetAdditions)

- (BOOL)			formatIsValidForCueSheet			{ return YES; }
- (NSString *)		cueSheetFormatName					{ return @"WavPack"; }

@end
