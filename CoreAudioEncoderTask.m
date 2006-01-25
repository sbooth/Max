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
#import "CoreAudioException.h"
#import "IOException.h"

#include "mp4.h"

#include <AudioToolbox/AudioFile.h>

@implementation CoreAudioEncoderTask

- (id) initWithTask:(PCMGeneratingTask *)task formatInfo:(NSDictionary *)formatInfo
{
	if((self = [super initWithTask:task])) {
		_formatInfo		= [formatInfo retain];
		_encoderClass	= [CoreAudioEncoder class];
		return self;
	}
	return nil;
}

- (void) dealloc
{
	[_formatInfo release];
	[super dealloc];
}

- (NSDictionary *)		getFormatInfo				{ return _formatInfo; }
- (NSString *)			cueSheetFormatName			{ return [self outputFormat]; }

- (BOOL) formatLegalForCueSheet
{ 
	UInt32	formatID	= [[_formatInfo valueForKey:@"formatID"] unsignedLongValue];;

	return (kAudioFormatLinearPCM == formatID || kAudioFormatMPEGLayer3 == formatID);
}

- (NSString *) outputFormat
{
	UInt32	formatID	= [[_formatInfo valueForKey:@"formatID"] unsignedLongValue];;

	// Special case AAC and Apple Lossless, since they are very common and "MPEG4 Audio" is vague
	if(kAudioFormatMPEG4AAC == formatID) {
		return NSLocalizedStringFromTable(@"AAC", @"General", @"");
	}
	else if(kAudioFormatAppleLossless == formatID) {
		return NSLocalizedStringFromTable(@"Apple Lossless", @"General", @"");
	}
	else {
		return [_formatInfo valueForKey:@"fileTypeName"];
	}
}

- (NSString *) extension
{
	id extensions = [_formatInfo valueForKey:@"extensionsForType"];
	return ([extensions isKindOfClass:[NSArray class]] ? [extensions objectAtIndex:0] : extensions);
}

- (void) writeTags
{
	OSStatus				err;
	FSRef					ref;
	AudioFileID				fileID;
	NSMutableDictionary		*info;
	UInt32					size;
	MP4FileHandle			mp4FileHandle;
	AudioMetadata			*metadata				= [_task metadata];
	UInt32					formatID				= [[_formatInfo valueForKey:@"formatID"] unsignedLongValue];;
	NSString				*bundleVersion			= nil;
	NSString				*versionString			= nil;
	NSNumber				*trackNumber			= nil;
	NSNumber				*totalTracks			= nil;
	NSNumber				*discNumber				= nil;
	NSNumber				*discsInSet				= nil;
	NSString				*album					= nil;
	NSString				*artist					= nil;
	NSString				*title					= nil;
	NSNumber				*year					= nil;
	NSString				*genre					= nil;
	NSString				*comment				= nil;
	NSNumber				*multipleArtists		= nil;

	
	// Use mp4v2 for Apple lossless/AAC files
	if(kAudioFormatMPEG4AAC == formatID || kAudioFormatAppleLossless == formatID) {
		mp4FileHandle = MP4Modify([_outputFilename UTF8String], 0, 0);
		
		if(MP4_INVALID_FILE_HANDLE != mp4FileHandle) {
			
			// Album title
			album = [metadata valueForKey:@"albumTitle"];
			if(nil != album) {
				MP4SetMetadataAlbum(mp4FileHandle, [album UTF8String]);
			}
			
			// Artist
			artist = [metadata valueForKey:@"trackArtist"];
			if(nil == artist) {
				artist = [metadata valueForKey:@"albumArtist"];
			}
			if(nil != artist) {
				MP4SetMetadataArtist(mp4FileHandle, [artist UTF8String]);
			}
			
			// Genre
			if(1 == [_tracks count]) {
				genre = [metadata valueForKey:@"trackGenre"];
			}
			if(nil == genre) {
				genre = [metadata valueForKey:@"albumGenre"];
			}
			if(nil != genre) {
				MP4SetMetadataGenre(mp4FileHandle, [genre UTF8String]);
			}
			
			// Year
			year = [metadata valueForKey:@"trackYear"];
			if(nil == year) {
				year = [metadata valueForKey:@"albumYear"];
			}
			if(nil != year) {
				MP4SetMetadataYear(mp4FileHandle, [[year stringValue] UTF8String]);
			}
			
			// Comment
			comment = [metadata valueForKey:@"albumComment"];
			if(_writeSettingsToComment) {
				comment = (nil == comment ? [self settings] : [NSString stringWithFormat:@"%@\n%@", comment, [self settings]]);
			}
			if(nil != comment) {
				MP4SetMetadataComment(mp4FileHandle, [comment UTF8String]);
			}
			
			// Track title
			title = [metadata valueForKey:@"trackTitle"];
			if(nil != title) {
				MP4SetMetadataName(mp4FileHandle, [title UTF8String]);
			}
			
			// Track number
			trackNumber = [metadata valueForKey:@"trackNumber"];
			totalTracks = [metadata valueForKey:@"albumTrackCount"];
			if(nil != trackNumber && nil != totalTracks) {
				MP4SetMetadataTrack(mp4FileHandle, [trackNumber unsignedShortValue], [totalTracks unsignedShortValue]);
			}
			else if(nil != trackNumber) {
				MP4SetMetadataTrack(mp4FileHandle, [trackNumber unsignedShortValue], 0);
			}
			else if(nil != totalTracks) {
				MP4SetMetadataTrack(mp4FileHandle, 0, [totalTracks unsignedShortValue]);
			}
			
			// Disc number
			discNumber = [metadata valueForKey:@"discNumber"];
			discsInSet = [metadata valueForKey:@"discsInSet"];
			if(nil != discNumber && nil != discsInSet) {
				MP4SetMetadataDisk(mp4FileHandle, [discNumber unsignedShortValue], [discsInSet unsignedShortValue]);
			}
			else if(nil != discNumber) {
				MP4SetMetadataDisk(mp4FileHandle, [discNumber unsignedShortValue], 0);
			}
			else if(nil != discsInSet) {
				MP4SetMetadataDisk(mp4FileHandle, 0, [discsInSet unsignedShortValue]);
			}
			
			// Compilation
			multipleArtists = [metadata valueForKey:@"multipleArtists"];
			if(nil != multipleArtists) {
				MP4SetMetadataCompilation(mp4FileHandle, [multipleArtists unsignedShortValue]);
			}
			
			// Encoded by
			bundleVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
			versionString = [NSString stringWithFormat:@"Max %@", bundleVersion];
			MP4SetMetadataTool(mp4FileHandle, [versionString UTF8String]);
			
			MP4Close(mp4FileHandle);
			
			return;
		}		
	}
	// Use (unimplemented as of 10.4.3) CoreAudio metadata functions
	else {

		@try {
			err = FSPathMakeRef((const UInt8 *)[_outputFilename UTF8String], &ref, NULL);
			if(noErr != err) {
				@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to locate the output file", @"Exceptions", @"")
											   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:_outputFilename, [NSString stringWithUTF8String:GetMacOSStatusErrorString(err)], [NSString stringWithUTF8String:GetMacOSStatusCommentString(err)], nil] forKeys:[NSArray arrayWithObjects:@"filename", @"errorCode", @"errorString", nil]]];
			}
			
			err = AudioFileOpen(&ref, fsRdWrPerm, [[_formatInfo valueForKey:@"fileType"] intValue], &fileID);
			if(noErr != err) {
				@throw [CoreAudioException exceptionWithReason:NSLocalizedStringFromTable(@"AudioFileOpen failed", @"Exceptions", @"")
													  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithUTF8String:GetMacOSStatusErrorString(err)], [NSString stringWithUTF8String:GetMacOSStatusCommentString(err)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}
			
			// Get the dictionary and set properties
			size = sizeof(info);
			err = AudioFileGetProperty(fileID, kAudioFilePropertyInfoDictionary, &size, &info);
			//		NSLog(@"error is %@", UTCreateStringForOSType(err));
			if(noErr == err) {
				
				bundleVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
				[info setValue:[NSString stringWithFormat:@"Max %@", bundleVersion] forKey:@kAFInfoDictionary_EncodingApplication];
				
				// Album title
				album = [metadata valueForKey:@"albumTitle"];
				if(nil != album) {
					[info setValue:album forKey:@kAFInfoDictionary_Album];
				}
				
				// Artist
				artist = [metadata valueForKey:@"trackArtist"];
				if(nil == artist) {
					artist = [metadata valueForKey:@"albumArtist"];
				}
				if(nil != artist) {
					[info setValue:artist forKey:@kAFInfoDictionary_Artist];
				}
				
				// Genre
				if(1 == [_tracks count]) {
					genre = [metadata valueForKey:@"trackGenre"];
				}
				if(nil == genre) {
					genre = [metadata valueForKey:@"albumGenre"];
				}
				if(nil != genre) {
					[info setValue:genre forKey:@kAFInfoDictionary_Genre];
				}
				
				// Year
				year = [metadata valueForKey:@"trackYear"];
				if(nil == year) {
					year = [metadata valueForKey:@"albumYear"];
				}
				if(nil != year) {
					[info setValue:year forKey:@kAFInfoDictionary_Year];
				}
				
				// Comment
				comment = [metadata valueForKey:@"albumComment"];
				if(_writeSettingsToComment) {
					comment = (nil == comment ? [self settings] : [comment stringByAppendingString:[NSString stringWithFormat:@"\n%@", [self settings]]]);
				}
				if(nil != comment) {
					[info setValue:comment forKey:@kAFInfoDictionary_Comments];
				}
				
				// Track title
				title = [metadata valueForKey:@"trackTitle"];
				if(nil != title) {
					[info setValue:title forKey:@kAFInfoDictionary_Title];
				}
				
				// Track number
				trackNumber = [metadata valueForKey:@"trackNumber"];
				if(nil != trackNumber) {
					[info setValue:trackNumber forKey:@kAFInfoDictionary_TrackNumber];
				}
				
				size = sizeof(info);
				err = AudioFileSetProperty(fileID, kAudioFilePropertyInfoDictionary, size, &info);
				if(noErr != err) {
					// TODO: Uncomment the following lines when (if?) Apple implements this functionality
					//@throw [CoreAudioException exceptionWithReason:NSLocalizedStringFromTable(@"AudioFileSetProperty failed", @"Exceptions", @"")
					//									  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithUTF8String:GetMacOSStatusErrorString(err)], [NSString stringWithUTF8String:GetMacOSStatusCommentString(err)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
				}
			}
		}
				
		@finally {
			// Clean up	
			err = AudioFileClose(fileID);
			if(noErr != err) {
				@throw [CoreAudioException exceptionWithReason:NSLocalizedStringFromTable(@"AudioFileClose failed", @"Exceptions", @"")
													  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithUTF8String:GetMacOSStatusErrorString(err)], [NSString stringWithUTF8String:GetMacOSStatusCommentString(err)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}
		}
	}	
}

@end
