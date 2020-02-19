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

#import "MonkeysAudioEncoderTask.h"
#import "MonkeysAudioEncoder.h"

#include <mac/All.h>
#include <mac/MACLib.h>
#include <mac/APETag.h>
#include <mac/CharacterHelper.h>

@interface AudioMetadata (TagMappings)
+ (APE::str_utfn *)		customizeAPETag:(NSString *)tag;
@end

@implementation MonkeysAudioEncoderTask

- (id) init
{
	if((self = [super init])) {
		_encoderClass = [MonkeysAudioEncoder class];
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
	NSString									*bundleVersion			= nil;
	APE::str_utfn								*chars					= NULL;
	APE::str_utfn								*tagName				= NULL;
	APE::CAPETag								*f						= NULL;
	int											result;
	

	@try {
		chars = APE::CAPECharacterHelper::GetUTF16FromANSI([[self outputFilename] fileSystemRepresentation]);
		NSAssert(NULL != chars, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));

		f = new APE::CAPETag(chars);
		NSAssert(NULL != f, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));

		// Album title
		album = [metadata albumTitle];
		if(nil != album) {
			tagName = [AudioMetadata customizeAPETag:@"ALBUM"];
			f->SetFieldString(tagName, [album UTF8String], TRUE);
			free(tagName);
		}
		
		// Artist
		artist = [metadata trackArtist];
		if(nil == artist)
			artist = [metadata albumArtist];
		if(nil != artist) {
			tagName = [AudioMetadata customizeAPETag:@"ARTIST"];
			f->SetFieldString(tagName, [artist UTF8String], TRUE);
			free(tagName);
		}
		
		// Composer
		composer = [metadata trackComposer];
		if(nil == composer)
			composer = [metadata albumComposer];
		if(nil != composer) {
			tagName = [AudioMetadata customizeAPETag:@"COMPOSER"];
			f->SetFieldString(tagName, [composer UTF8String], TRUE);
			free(tagName);
		}
		
		// Genre
		genre = [metadata trackGenre];
		if(nil == genre)
			genre = [metadata albumGenre];
		if(nil != genre) {
			tagName = [AudioMetadata customizeAPETag:@"GENRE"];
			f->SetFieldString(tagName, [genre UTF8String], TRUE);
			free(tagName);
		}
		
		// Year
		year = [metadata trackDate];
		if(nil == year)
			year = [metadata albumDate];
		if(nil != year) {
			tagName = [AudioMetadata customizeAPETag:@"YEAR"];
			f->SetFieldString(tagName, [year UTF8String], TRUE);
			free(tagName);
		}
		
		// Comment
		comment			= [metadata albumComment];
		trackComment	= [metadata trackComment];
		if(nil != trackComment)
			comment = (nil == comment ? trackComment : [NSString stringWithFormat:@"%@\n%@", trackComment, comment]);
		if([[[[self taskInfo] settings] objectForKey:@"saveSettingsInComment"] boolValue])
			comment = (nil == comment ? [self encoderSettingsString] : [NSString stringWithFormat:@"%@\n%@", comment, [self encoderSettingsString]]);
		if(nil != comment) {
			tagName = [AudioMetadata customizeAPETag:@"COMMENT"];
			f->SetFieldString(tagName, [comment UTF8String], TRUE);
			free(tagName);
		}
		
		// Track title
		title = [metadata trackTitle];
		if(nil != title) {
			tagName = [AudioMetadata customizeAPETag:@"TITLE"];
			f->SetFieldString(tagName, [title UTF8String], TRUE);
			free(tagName);
		}
		
		// Track number
		trackNumber = [metadata trackNumber];
		if(nil != trackNumber) {
			tagName = [AudioMetadata customizeAPETag:@"TRACK"];
			f->SetFieldString(tagName, [[trackNumber stringValue] UTF8String], TRUE);
			free(tagName);
		}
		
		// Track total
		trackTotal = [metadata trackTotal];
		if(nil != trackTotal) {
			tagName = [AudioMetadata customizeAPETag:@"TRACKTOTAL"];
			f->SetFieldString(tagName, [[trackTotal stringValue] UTF8String], TRUE);
			free(tagName);
		}
		
		// Disc number
		discNumber = [metadata discNumber];
		if(nil != discNumber) {
			tagName = [AudioMetadata customizeAPETag:@"DISCNUMBER"];
			f->SetFieldString(tagName, [[discNumber stringValue] UTF8String], TRUE);
			free(tagName);
		}
		
		// Discs in set
		discTotal = [metadata discTotal];
		if(nil != discTotal) {
			tagName = [AudioMetadata customizeAPETag:@"DISCTOTAL"];
			f->SetFieldString(tagName, [[discTotal stringValue] UTF8String], TRUE);
			free(tagName);
		}
		
		// Compilation
		compilation = [metadata compilation];
		if(nil != compilation) {
			tagName = [AudioMetadata customizeAPETag:@"COMPILATION"];
			f->SetFieldString(tagName, [[compilation stringValue] UTF8String], TRUE);
			free(tagName);
		}
		
		// ISRC
		isrc = [metadata ISRC];
		if(nil != isrc) {
			tagName = [AudioMetadata customizeAPETag:@"ISRC"];
			f->SetFieldString(tagName, [isrc UTF8String], TRUE);
			free(tagName);
		}
		
		// MCN
		mcn = [metadata MCN];
		if(nil != mcn) {
			tagName = [AudioMetadata customizeAPETag:@"MCN"];
			f->SetFieldString(tagName, [mcn UTF8String], TRUE);
			free(tagName);
		}
		
		// Encoder information
		bundleVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
		f->SetFieldString(L"TOOL NAME", [@"Max" UTF8String], TRUE);
		f->SetFieldString(APE_TAG_FIELD_TOOL_VERSION, [bundleVersion UTF8String], TRUE);

		// Encoder settings
		f->SetFieldString(L"ENCODING", [[self encoderSettingsString] UTF8String], TRUE);
		
		result = f->Save();
		if(ERROR_SUCCESS != result) {
			@throw [NSException exceptionWithName:@"MACException" reason:NSLocalizedStringFromTable(@"Unable to write the APE tags.", @"Exceptions", @"")
										 userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObject:[NSNumber numberWithInt:result]] forKeys:[NSArray arrayWithObject:@"errorCode"]]];
		}
	}
	
	@finally {
		if(NULL != f) {
			delete f;
		}
		free(chars);
	}
}

- (NSString *)		fileExtension					{ return @"ape"; }
- (NSString *)		outputFormatName				{ return NSLocalizedStringFromTable(@"Monkey's Audio", @"General", @""); }

@end

@implementation MonkeysAudioEncoderTask (CueSheetAdditions)

- (BOOL)			formatIsValidForCueSheet			{ return YES; }
- (NSString *)		cueSheetFormatName					{ return @"APE"; }

@end
