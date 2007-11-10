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

#import "CoreAudioEncoderTask.h"
#import "CoreAudioEncoder.h"
#import "CoreAudioUtilities.h"
#import "LogController.h"
#import "UtilityFunctions.h"

#include <AudioToolbox/AudioFile.h>
#include <AudioToolbox/AudioFormat.h>
#include <mp4v2/mp4.h>

@implementation CoreAudioEncoderTask

- (id) init
{
	if((self = [super init])) {
		_encoderClass	= [CoreAudioEncoder class];
		return self;
	}
	return nil;
}

- (void) writeTags
{
	OSStatus				err;
	FSRef					ref;
	AudioFileID				fileID;
	NSMutableDictionary		*info;
	UInt32					size;
	MP4FileHandle			mp4FileHandle;
	AudioMetadata			*metadata				= [[self taskInfo] metadata];
	AudioFileTypeID			fileType				= [self fileType];
	NSString				*bundleVersion			= nil;
	NSString				*versionString			= nil;
	NSNumber				*trackNumber			= nil;
	NSNumber				*trackTotal				= nil;
	NSNumber				*discNumber				= nil;
	NSNumber				*discTotal				= nil;
	NSString				*album					= nil;
	NSString				*artist					= nil;
	NSString				*composer				= nil;
	NSString				*title					= nil;
	NSString				*year					= nil;
	NSString				*genre					= nil;
	NSString				*comment				= nil;
	NSString				*trackComment			= nil;
	NSNumber				*compilation			= nil;
	NSImage					*albumArt				= nil;
	NSData					*data					= nil;
	NSString				*tempFilename			= NULL;
	
	
	// Use mp4v2 for mp4/m4a files
	if(kAudioFileMPEG4Type == fileType || kAudioFileM4AType == fileType) {
		mp4FileHandle = MP4Modify([[self outputFilename] fileSystemRepresentation], 0, 0);
		NSAssert(MP4_INVALID_FILE_HANDLE != mp4FileHandle, NSLocalizedStringFromTable(@"Unable to open the output file for tagging.", @"Exceptions", @""));

		// Album title
		album = [metadata albumTitle];
		if(nil != album)
			MP4SetMetadataAlbum(mp4FileHandle, [album UTF8String]);
		
		// Artist
		artist = [metadata trackArtist];
		if(nil == artist)
			artist = [metadata albumArtist];
		if(nil != artist)
			MP4SetMetadataArtist(mp4FileHandle, [artist UTF8String]);
		
		// Composer
		composer = [metadata trackComposer];
		if(nil == composer)
			composer = [metadata albumComposer];
		if(nil != composer)
			MP4SetMetadataWriter(mp4FileHandle, [composer UTF8String]);

		// Genre
		if(nil != [[self taskInfo] inputTracks] && 1 == [[[self taskInfo] inputTracks] count])
			genre = [metadata trackGenre];
		if(nil == genre)
			genre = [metadata albumGenre];
		if(nil != genre)
			MP4SetMetadataGenre(mp4FileHandle, [genre UTF8String]);
		
		// Year
		year = [metadata trackDate];
		if(nil == year)
			year = [metadata albumDate];
		if(nil != year)
			MP4SetMetadataYear(mp4FileHandle, [year UTF8String]);
		
		// Comment
		comment			= [metadata albumComment];
		trackComment	= [metadata trackComment];
		if(nil != trackComment)
			comment = (nil == comment ? trackComment : [NSString stringWithFormat:@"%@\n%@", trackComment, comment]);
		if([[[[self taskInfo] settings] objectForKey:@"saveSettingsInComment"] boolValue])
			comment = (nil == comment ? [self encoderSettingsString] : [NSString stringWithFormat:@"%@\n%@", comment, [self encoderSettingsString]]);
		if(nil != comment)
			MP4SetMetadataComment(mp4FileHandle, [comment UTF8String]);
		
		// Track title
		title = [metadata trackTitle];
		if(nil != title)
			MP4SetMetadataName(mp4FileHandle, [title UTF8String]);
		
		// Track number
		trackNumber = [metadata trackNumber];
		trackTotal = [metadata trackTotal];
		if(nil != trackNumber && nil != trackTotal)
			MP4SetMetadataTrack(mp4FileHandle, [trackNumber intValue], [trackTotal intValue]);
		else if(nil != trackNumber)
			MP4SetMetadataTrack(mp4FileHandle, [trackNumber intValue], 0);
		else if(0 != trackTotal)
			MP4SetMetadataTrack(mp4FileHandle, 0, [trackTotal intValue]);
		
		// Disc number
		discNumber = [metadata discNumber];
		discTotal = [metadata discTotal];
		if(nil != discNumber && nil != discTotal)
			MP4SetMetadataDisk(mp4FileHandle, [discNumber intValue], [discTotal intValue]);
		else if(0 != discNumber)
			MP4SetMetadataDisk(mp4FileHandle, [discNumber intValue], 0);
		else if(0 != discTotal)
			MP4SetMetadataDisk(mp4FileHandle, 0, [discTotal intValue]);
		
		// Compilation
		compilation = [metadata compilation];
		if(nil != compilation) {
			MP4SetMetadataCompilation(mp4FileHandle, [compilation boolValue]);
		}
		
		// Album art
		albumArt = [metadata albumArt];
		if(nil != albumArt) {
			data = getPNGDataForImage(albumArt); 
			MP4SetMetadataCoverArt(mp4FileHandle, (u_int8_t *)[data bytes], [data length]);
		}

		// Encoded by
		bundleVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
		versionString = [NSString stringWithFormat:@"Max %@", bundleVersion];
		MP4SetMetadataTool(mp4FileHandle, [versionString UTF8String]);
		
		MP4Close(mp4FileHandle);
		
		// Optimize the atoms so the MP4 files will play on shared iTunes libraries
		// mp4v2 creates a temp file in ., so use a custom file and manually rename it	
		tempFilename = generateTemporaryFilename([[[self taskInfo] settings] objectForKey:@"temporaryDirectory"], [self fileExtension]);
		
		if(MP4Optimize([[self outputFilename] fileSystemRepresentation], [tempFilename fileSystemRepresentation], 0)) {
			NSFileManager	*fileManager	= [NSFileManager defaultManager];
			
			// Delete the existing output file
			if([fileManager removeFileAtPath:[self outputFilename] handler:nil]) {
				if(NO == [fileManager movePath:tempFilename toPath:[self outputFilename] handler:nil]) {
					[[LogController sharedController] logMessage:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Warning: the file %@ was lost.", @"Exceptions", @""), [[NSFileManager defaultManager] displayNameAtPath:[self outputFilename]]]];
				}
			}
			else {
				[[LogController sharedController] logMessage:NSLocalizedStringFromTable(@"Unable to delete the output file.", @"Exceptions", @"")];
			}
		}
		else {
			[[LogController sharedController] logMessage:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Unable to optimize file: %@", @"General", @""), [[NSFileManager defaultManager] displayNameAtPath:[self outputFilename]]]];
		}
	}
	// Use (unimplemented as of 10.4.3) CoreAudio metadata functions
	else {

		@try {
			err = FSPathMakeRef((const UInt8 *)[[self outputFilename] fileSystemRepresentation], &ref, NULL);
			NSAssert1(noErr == err, NSLocalizedStringFromTable(@"Unable to locate the output file.", @"Exceptions", @""), UTCreateStringForOSType(err));
			
			err = AudioFileOpen(&ref, fsRdWrPerm, [self fileType], &fileID);
			NSAssert2(noErr == err, NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"AudioFileOpen", UTCreateStringForOSType(err));
			
			// Get the dictionary and set properties
			size = sizeof(info);
			err = AudioFileGetProperty(fileID, kAudioFilePropertyInfoDictionary, &size, &info);
			//		NSLog(@"error is %@", UTCreateStringForOSType(err));
			if(noErr == err) {
				
				bundleVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
				[info setObject:[NSString stringWithFormat:@"Max %@", bundleVersion] forKey:@kAFInfoDictionary_EncodingApplication];
				
				// Album title
				album = [metadata albumTitle];
				if(nil != album)
					[info setObject:album forKey:@kAFInfoDictionary_Album];
				
				// Artist
				artist = [metadata trackArtist];
				if(nil == artist)
					artist = [metadata albumArtist];
				if(nil != artist)
					[info setObject:artist forKey:@kAFInfoDictionary_Artist];
				
				// Composer
				composer = [metadata trackComposer];
				if(nil == composer)
					composer = [metadata albumComposer];
				if(nil != composer)
					[info setObject:composer forKey:@kAFInfoDictionary_Composer];

				// Genre
				if(nil != [[self taskInfo] inputTracks] && 1 == [[[self taskInfo] inputTracks] count])
					genre = [metadata trackGenre];
				if(nil == genre)
					genre = [metadata albumGenre];
				if(nil != genre)
					[info setObject:genre forKey:@kAFInfoDictionary_Genre];
				
				// Year
				year = [metadata trackDate];
				if(nil == year)
					year = [metadata albumDate];
				if(nil != year)
					[info setObject:year forKey:@kAFInfoDictionary_Year];
				
				// Comment
				comment			= [metadata albumComment];
				trackComment	= [metadata trackComment];
				if(nil != trackComment)
					comment = (nil == comment ? trackComment : [NSString stringWithFormat:@"%@\n%@", trackComment, comment]);
				if([[[[self taskInfo] settings] objectForKey:@"saveSettingsInComment"] boolValue])
					comment = (nil == comment ? [self encoderSettingsString] : [comment stringByAppendingString:[NSString stringWithFormat:@"\n%@", [self encoderSettingsString]]]);
				if(nil != comment)
					[info setObject:comment forKey:@kAFInfoDictionary_Comments];
				
				// Track title
				title = [metadata trackTitle];
				if(nil != title)
					[info setObject:title forKey:@kAFInfoDictionary_Title];
				
				// Track number
				trackNumber = [metadata trackNumber];
				if(nil != trackNumber)
					[info setObject:trackNumber forKey:@kAFInfoDictionary_TrackNumber];
				
				// On 10.4.8, this returns a 'pty?' error- must not be settable
				/*
				size	= sizeof(info);
				err		= AudioFileSetProperty(fileID, kAudioFilePropertyInfoDictionary, size, &info);
				NSAssert2(noErr == err, NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"AudioFileSetProperty", UTCreateStringForOSType(err));
				 */
			}
		}
				
		@finally {
			// Clean up	
			err = AudioFileClose(fileID);
			NSAssert2(noErr == err, NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"AudioFileClose", UTCreateStringForOSType(err));
		}
	}	
}

- (NSString *) fileExtension
{
	NSArray		*extensions		= [[self encoderSettings] objectForKey:@"extensionsForType"];
	
	return [extensions objectAtIndex:[[[self encoderSettings] objectForKey:@"extensionIndex"] unsignedIntValue]];
}

- (NSString *) outputFormatName
{
	return getCoreAudioOutputFormatName([self fileType], [self formatID], [[[self encoderSettings] objectForKey:@"formatFlags"] unsignedLongValue]);
}

- (AudioFileTypeID)		fileType		{ return [[[self encoderSettings] objectForKey:@"fileType"] unsignedLongValue]; }
- (UInt32)				formatID		{ return [[[self encoderSettings] objectForKey:@"formatID"] unsignedLongValue]; }

@end

@implementation CoreAudioEncoderTask (CueSheetAdditions)

- (NSString *) cueSheetFormatName
{
 	switch([self fileType]) {
		case kAudioFileWAVEType:	return @"WAVE";				break;
		case kAudioFileAIFFType:	return @"AIFF";				break;
		case kAudioFileMP3Type:		return @"MP3";				break;
		default:					return nil;					break;
	}
}

- (BOOL) formatIsValidForCueSheet
{
 	switch([self fileType]) {
		case kAudioFileWAVEType:	return YES;					break;
		case kAudioFileAIFFType:	return YES;					break;
		case kAudioFileMP3Type:		return YES;					break;
		default:					return NO;					break;
	}
}

@end

@implementation CoreAudioEncoderTask (iTunesAdditions)

- (BOOL)			formatIsValidForiTunes
{
 	switch([self fileType]) {
		case kAudioFileWAVEType:	return YES;					break;
		case kAudioFileAIFFType:	return YES;					break;
		case kAudioFileM4AType:		return YES;					break;
		case kAudioFileMP3Type:		return YES;					break;
		default:					return NO;					break;
	}
}

@end
