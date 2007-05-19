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

#import "MonkeysAudioEncoderTask.h"
#import "MonkeysAudioEncoder.h"

#include <mac/All.h>
#include <mac/MACLib.h>
#include <mac/APETag.h>
#include <mac/CharacterHelper.h>

@interface AudioMetadata (TagMappings)
+ (str_utf16 *)			customizeAPETag:(NSString *)tag;
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
	unsigned									trackNumber				= 0;
	unsigned									trackTotal				= 0;
	unsigned									discNumber				= 0;
	unsigned									discTotal				= 0;
	BOOL										compilation				= NO;
	NSString									*album					= nil;
	NSString									*artist					= nil;
	NSString									*composer				= nil;
	NSString									*title					= nil;
	unsigned									year					= 0;
	NSString									*genre					= nil;
	NSString									*comment				= nil;
	NSString									*trackComment			= nil;
	NSString									*isrc					= nil;
	NSString									*mcn					= nil;
	NSString									*bundleVersion			= nil;
	str_utf16									*chars					= NULL;
	str_utf16									*tagName				= NULL;
	CAPETag										*f						= NULL;
	int											result;
	

	@try {
		chars = GetUTF16FromANSI([[self outputFilename] fileSystemRepresentation]);
		NSAssert(NULL != chars, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));

		f = new CAPETag(chars);
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
		if(nil == artist) {
			artist = [metadata albumArtist];
		}
		if(nil != artist) {
			tagName = [AudioMetadata customizeAPETag:@"ARTIST"];
			f->SetFieldString(tagName, [artist UTF8String], TRUE);
			free(tagName);
		}
		
		// Composer
		composer = [metadata trackComposer];
		if(nil == composer) {
			composer = [metadata albumComposer];
		}
		if(nil != composer) {
			tagName = [AudioMetadata customizeAPETag:@"COMPOSER"];
			f->SetFieldString(tagName, [composer UTF8String], TRUE);
			free(tagName);
		}
		
		// Genre
		genre = [metadata trackGenre];
		if(nil == genre) {
			genre = [metadata albumGenre];
		}
		if(nil != genre) {
			tagName = [AudioMetadata customizeAPETag:@"GENRE"];
			f->SetFieldString(tagName, [genre UTF8String], TRUE);
			free(tagName);
		}
		
		// Year
		year = [metadata trackYear];
		if(0 == year) {
			year = [metadata albumYear];
		}
		if(0 != year) {
			tagName = [AudioMetadata customizeAPETag:@"YEAR"];
			f->SetFieldString(tagName, [[NSString stringWithFormat:@"%u", year] UTF8String], TRUE);
			free(tagName);
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
		if(0 != trackNumber) {
			tagName = [AudioMetadata customizeAPETag:@"TRACK"];
			f->SetFieldString(tagName, [[NSString stringWithFormat:@"%u", trackNumber] UTF8String], TRUE);
			free(tagName);
		}
		
		// Track total
		trackTotal = [metadata trackTotal];
		if(0 != trackTotal) {
			tagName = [AudioMetadata customizeAPETag:@"TRACKTOTAL"];
			f->SetFieldString(tagName, [[NSString stringWithFormat:@"%u", trackTotal] UTF8String], TRUE);
			free(tagName);
		}
		
		// Disc number
		discNumber = [metadata discNumber];
		if(0 != discNumber) {
			tagName = [AudioMetadata customizeAPETag:@"DISCNUMBER"];
			f->SetFieldString(tagName, [[NSString stringWithFormat:@"%u", discNumber] UTF8String], TRUE);
			free(tagName);
		}
		
		// Discs in set
		discTotal = [metadata discTotal];
		if(0 != discTotal) {
			tagName = [AudioMetadata customizeAPETag:@"DISCTOTAL"];
			f->SetFieldString(tagName, [[NSString stringWithFormat:@"%u", discTotal] UTF8String], TRUE);
			free(tagName);
		}
		
		// Compilation
		compilation = [metadata compilation];
		if(compilation) {
			tagName = [AudioMetadata customizeAPETag:@"COMPILATION"];
			f->SetFieldString(tagName, [@"1" UTF8String], TRUE);
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
