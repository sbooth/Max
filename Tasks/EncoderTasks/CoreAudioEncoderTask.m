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

#import "CoreAudioEncoderTask.h"
#import "CoreAudioEncoder.h"
#import "LogController.h"
#import "UtilityFunctions.h"
#import "CoreAudioException.h"
#import "IOException.h"

#include <AudioToolbox/AudioFile.h>
#include <AudioToolbox/AudioFormat.h>
#include <mp4v2/mp4.h>

#include <paths.h>			// _PATH_TMP
#include <unistd.h>			// mkstemp, unlink

#define TEMPFILE_PATTERN	"MaxXXXXXXXX"

@interface CoreAudioEncoderTask (Private)

- (AudioFileTypeID)		fileType;
- (UInt32)				formatID;

@end

@implementation CoreAudioEncoderTask

- (id) init
{
	if((self = [super init])) {
		_encoderClass	= [CoreAudioEncoder class];
		return self;
	}
	return nil;
}

- (NSString *) cueSheetFormatName
{
 	switch([self fileType]) {
		case kAudioFileWAVEType:	return @"WAVE";				break;
		case kAudioFileAIFFType:	return @"AIFF";				break;
		case kAudioFileMP3Type:		return @"MP3";				break;
		default:					return nil;					break;
	}
}

- (BOOL) formatLegalForCueSheet
{
 	switch([self fileType]) {
		case kAudioFileWAVEType:	return YES;					break;
		case kAudioFileAIFFType:	return YES;					break;
		case kAudioFileMP3Type:		return YES;					break;
		default:					return NO;					break;
	}
}

- (NSString *) outputFormatName
{
	OSStatus						result;
	UInt32							specifierSize;
	UInt32							dataSize;
	AudioFileTypeID					fileType;
	AudioStreamBasicDescription		asbd;
	NSString						*fileFormat;
	NSString						*audioFormat;
	
	// Determine the name of the file (container) type
	fileType				= [self fileType];
	specifierSize			= sizeof(fileType);
	dataSize				= sizeof(fileFormat);
	result					= AudioFileGetGlobalInfo(kAudioFileGlobalInfo_FileTypeName, specifierSize, &fileType, &dataSize, &fileFormat);
	
	NSAssert1(noErr == result, @"AudioFileGetGlobalInfo failed: %@", UTCreateStringForOSType(result));

	// Determine the name of the format
	bzero(&asbd, sizeof(AudioStreamBasicDescription));
	
	asbd.mFormatID			= [self formatID];
	asbd.mFormatFlags		= [[[self encoderSettings] objectForKey:@"formatFlags"] unsignedLongValue];
	
	specifierSize			= sizeof(audioFormat);
	result					= AudioFormatGetProperty(kAudioFormatProperty_FormatName, sizeof(AudioStreamBasicDescription), &asbd, &specifierSize, &audioFormat);
	
	NSAssert1(noErr == result, @"AudioFormatGetProperty failed: %@", UTCreateStringForOSType(result));
	
	return [NSString stringWithFormat:@"%@ (%@)", [fileFormat autorelease], [audioFormat autorelease]];;
}

- (NSString *) fileExtension
{
	NSArray		*extensions		= [[self encoderSettings] objectForKey:@"extensionsForType"];
	
	return [extensions objectAtIndex:[[[self encoderSettings] objectForKey:@"extensionIndex"] unsignedIntValue]];
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
	UInt32					formatID				= [self formatID];
	NSString				*bundleVersion			= nil;
	NSString				*versionString			= nil;
	unsigned				trackNumber				= 0;
	unsigned				trackTotal				= 0;
	unsigned				discNumber				= 0;
	unsigned				discTotal				= 0;
	NSString				*album					= nil;
	NSString				*artist					= nil;
	NSString				*composer				= nil;
	NSString				*title					= nil;
	unsigned				year					= 0;
	NSString				*genre					= nil;
	NSString				*comment				= nil;
	NSString				*trackComment			= nil;
	BOOL					compilation				= NO;
	NSImage					*albumArt				= nil;
	NSData					*data					= nil;
	char					*path					= NULL;
	const char				*tmpDir;
	ssize_t					tmpDirLen;
	ssize_t					patternLen				= strlen(TEMPFILE_PATTERN);
	
	
	// Use mp4v2 for Apple lossless/AAC files
	if(kAudioFormatMPEG4AAC == formatID || kAudioFormatAppleLossless == formatID) {
		mp4FileHandle = MP4Modify([_outputFilename fileSystemRepresentation], 0, 0);
		
		if(MP4_INVALID_FILE_HANDLE != mp4FileHandle) {
			
			// Album title
			album = [metadata albumTitle];
			if(nil != album) {
				MP4SetMetadataAlbum(mp4FileHandle, [album UTF8String]);
			}
			
			// Artist
			artist = [metadata trackArtist];
			if(nil == artist) {
				artist = [metadata albumArtist];
			}
			if(nil != artist) {
				MP4SetMetadataArtist(mp4FileHandle, [artist UTF8String]);
			}
			
			// Composer
			composer = [metadata trackComposer];
			if(nil == composer) {
				composer = [metadata albumComposer];
			}
			if(nil != composer) {
				MP4SetMetadataWriter(mp4FileHandle, [composer UTF8String]);
			}

			// Genre
			if(nil != [[self taskInfo] inputTracks] && 1 == [[[self taskInfo] inputTracks] count]) {
				genre = [metadata trackGenre];
			}
			if(nil == genre) {
				genre = [metadata albumGenre];
			}
			if(nil != genre) {
				MP4SetMetadataGenre(mp4FileHandle, [genre UTF8String]);
			}
			
			// Year
			year = [metadata trackYear];
			if(0 == year) {
				year = [metadata albumYear];
			}
			if(0 != year) {
				MP4SetMetadataYear(mp4FileHandle, [[NSString stringWithFormat:@"%u", year] UTF8String]);
			}
			
			// Comment
			comment			= [metadata albumComment];
			trackComment	= [metadata trackComment];
			if(nil != trackComment) {
				comment = (nil == comment ? trackComment : [NSString stringWithFormat:@"%@\n%@", trackComment, comment]);
			}
			if([[[[self taskInfo] settings] objectForKey:@"writeSettingsToComment"] boolValue]) {
				comment = (nil == comment ? [self settings] : [NSString stringWithFormat:@"%@\n%@", comment, [self settings]]);
			}
			if(nil != comment) {
				MP4SetMetadataComment(mp4FileHandle, [comment UTF8String]);
			}
			
			// Track title
			title = [metadata trackTitle];
			if(nil != title) {
				MP4SetMetadataName(mp4FileHandle, [title UTF8String]);
			}
			
			// Track number
			trackNumber = [metadata trackNumber];
			trackTotal = [metadata trackTotal];
			if(0 != trackNumber && 0 != trackTotal) {
				MP4SetMetadataTrack(mp4FileHandle, trackNumber, trackTotal);
			}
			else if(0 != trackNumber) {
				MP4SetMetadataTrack(mp4FileHandle, trackNumber, 0);
			}
			else if(0 != trackTotal) {
				MP4SetMetadataTrack(mp4FileHandle, 0, trackTotal);
			}
			
			// Disc number
			discNumber = [metadata discNumber];
			discTotal = [metadata discTotal];
			if(0 != discNumber && 0 != discTotal) {
				MP4SetMetadataDisk(mp4FileHandle, discNumber, discTotal);
			}
			else if(0 != discNumber) {
				MP4SetMetadataDisk(mp4FileHandle, discNumber, 0);
			}
			else if(0 != discTotal) {
				MP4SetMetadataDisk(mp4FileHandle, 0, discTotal);
			}
			
			// Compilation
			compilation = [metadata compilation];
			if(NO != compilation) {
				MP4SetMetadataCompilation(mp4FileHandle, YES);
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
			
			tmpDir = [[[[self taskInfo] settings] objectForKey:@"temporaryDirectory"] fileSystemRepresentation];
			
			validateAndCreateDirectory([NSString stringWithCString:tmpDir encoding:NSASCIIStringEncoding]);
			
			tmpDirLen	= strlen(tmpDir);
			path		= malloc((tmpDirLen + patternLen + 1) *  sizeof(char));
			if(NULL == path) {
//				@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @"") 
//												   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}
			memcpy(path, tmpDir, tmpDirLen);
			memcpy(path + tmpDirLen, TEMPFILE_PATTERN, patternLen);
			path[tmpDirLen + patternLen] = '\0';
			
			path = mktemp(path);

			if(NO == MP4Optimize([[self outputFilename] fileSystemRepresentation], NULL, 0)) {
				[[LogController sharedController] logMessage:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Unable to optimize file: %@", @"General", @""), [_outputFilename lastPathComponent]]];
			}

			rename(path, [[self outputFilename] fileSystemRepresentation]);
			
			return;
		}		
	}
	// Use (unimplemented as of 10.4.3) CoreAudio metadata functions
	else {

		@try {
			err = FSPathMakeRef((const UInt8 *)[[self outputFilename] fileSystemRepresentation], &ref, NULL);
			if(noErr != err) {
				@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to locate the output file.", @"Exceptions", @"")
											   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:_outputFilename, [NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"filename", @"errorCode", @"errorString", nil]]];
			}
			
			err = AudioFileOpen(&ref, fsRdWrPerm, [self fileType], &fileID);
			if(noErr != err) {
				@throw [CoreAudioException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"AudioFileOpen"]
													  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}
			
			// Get the dictionary and set properties
			size = sizeof(info);
			err = AudioFileGetProperty(fileID, kAudioFilePropertyInfoDictionary, &size, &info);
			//		NSLog(@"error is %@", UTCreateStringForOSType(err));
			if(noErr == err) {
				
				bundleVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
				[info setObject:[NSString stringWithFormat:@"Max %@", bundleVersion] forKey:@kAFInfoDictionary_EncodingApplication];
				
				// Album title
				album = [metadata albumTitle];
				if(nil != album) {
					[info setObject:album forKey:@kAFInfoDictionary_Album];
				}
				
				// Artist
				artist = [metadata trackArtist];
				if(nil == artist) {
					artist = [metadata albumArtist];
				}
				if(nil != artist) {
					[info setObject:artist forKey:@kAFInfoDictionary_Artist];
				}
				
				// Composer
				composer = [metadata trackComposer];
				if(nil == composer) {
					composer = [metadata albumComposer];
				}
				if(nil != composer) {
					[info setObject:composer forKey:@kAFInfoDictionary_Composer];
				}

				// Genre
				if(nil != [[self taskInfo] inputTracks] && 1 == [[[self taskInfo] inputTracks] count]) {
					genre = [metadata trackGenre];
				}
				if(nil == genre) {
					genre = [metadata albumGenre];
				}
				if(nil != genre) {
					[info setObject:genre forKey:@kAFInfoDictionary_Genre];
				}
				
				// Year
				year = [metadata trackYear];
				if(0 == year) {
					year = [metadata albumYear];
				}
				if(0 != year) {
					[info setObject:[NSNumber numberWithUnsignedInt:year] forKey:@kAFInfoDictionary_Year];
				}
				
				// Comment
				comment			= [metadata albumComment];
				trackComment	= [metadata trackComment];
				if(nil != trackComment) {
					comment = (nil == comment ? trackComment : [NSString stringWithFormat:@"%@\n%@", trackComment, comment]);
				}
				if([[[[self taskInfo] settings] objectForKey:@"writeSettingsToComment"] boolValue]) {
					comment = (nil == comment ? [self settings] : [comment stringByAppendingString:[NSString stringWithFormat:@"\n%@", [self settings]]]);
				}
				if(nil != comment) {
					[info setObject:comment forKey:@kAFInfoDictionary_Comments];
				}
				
				// Track title
				title = [metadata trackTitle];
				if(nil != title) {
					[info setObject:title forKey:@kAFInfoDictionary_Title];
				}
				
				// Track number
				trackNumber = [metadata trackNumber];
				if(0 != trackNumber) {
					[info setObject:[NSNumber numberWithUnsignedInt:trackNumber] forKey:@kAFInfoDictionary_TrackNumber];
				}
				
				// I'm getting *** +[NSCFDictionary count]: selector not recognized from the following section
				/*
				size = sizeof(info);
				err = AudioFileSetProperty(fileID, kAudioFilePropertyInfoDictionary, size, info);
				if(noErr != err) {
					@throw [CoreAudioException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"AudioFileSetProperty"]
														  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
				}
				 */
			}
		}
				
		@finally {
			// Clean up	
			err = AudioFileClose(fileID);
			if(noErr != err) {
				@throw [CoreAudioException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"AudioFileClose"]
													  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}
		}
	}	
}

@end

@implementation CoreAudioEncoderTask (Private)

- (AudioFileTypeID)		fileType		{ return [[[self encoderSettings] objectForKey:@"fileType"] unsignedLongValue]; }
- (UInt32)				formatID		{ return [[[self encoderSettings] objectForKey:@"formatID"] unsignedLongValue]; }

@end

