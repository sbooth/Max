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
#import "IOException.h"

#include "mp4.h"

#include <AudioToolbox/AudioFile.h>

@implementation CoreAudioEncoderTask

- (id) initWithTask:(PCMGeneratingTask *)task outputFilename:(NSString *)outputFilename metadata:(AudioMetadata *)metadata formatInfo:(NSDictionary *)formatInfo
{
	if((self = [super initWithTask:task outputFilename:outputFilename metadata:metadata])) {
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

- (void) writeTags
{
	OSStatus				err;
	FSRef					ref;
	AudioFileID				fileID;
	NSMutableDictionary		*info;
	UInt32					size;
	MP4FileHandle			mp4FileHandle;
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
			album = [_metadata valueForKey:@"albumTitle"];
			if(nil != album) {
				MP4SetMetadataAlbum(mp4FileHandle, [album UTF8String]);
			}
			
			// Artist
			artist = [_metadata valueForKey:@"trackArtist"];
			if(nil == artist) {
				artist = [_metadata valueForKey:@"albumArtist"];
			}
			if(nil != artist) {
				MP4SetMetadataArtist(mp4FileHandle, [artist UTF8String]);
			}
			
			// Genre
			if(1 == [_tracks count]) {
				genre = [_metadata valueForKey:@"trackGenre"];
			}
			if(nil == genre) {
				genre = [_metadata valueForKey:@"albumGenre"];
			}
			if(nil != genre) {
				MP4SetMetadataGenre(mp4FileHandle, [genre UTF8String]);
			}
			
			// Year
			year = [_metadata valueForKey:@"trackYear"];
			if(nil == year) {
				year = [_metadata valueForKey:@"albumYear"];
			}
			if(nil != year) {
				MP4SetMetadataYear(mp4FileHandle, [[year stringValue] UTF8String]);
			}
			
			// Comment
			comment = [_metadata valueForKey:@"albumComment"];
			if(_writeSettingsToComment) {
				comment = (nil == comment ? [self settings] : [NSString stringWithFormat:@"%@\n%@", comment, [self settings]]);
			}
			if(nil != comment) {
				MP4SetMetadataComment(mp4FileHandle, [comment UTF8String]);
			}
			
			// Track title
			title = [_metadata valueForKey:@"trackTitle"];
			if(nil != title) {
				MP4SetMetadataName(mp4FileHandle, [title UTF8String]);
			}
			
			// Track number
			trackNumber = [_metadata valueForKey:@"trackNumber"];
			totalTracks = [_metadata valueForKey:@"albumTrackCount"];
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
			discNumber = [_metadata valueForKey:@"discNumber"];
			discsInSet = [_metadata valueForKey:@"discsInSet"];
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
			multipleArtists = [_metadata valueForKey:@"multipleArtists"];
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
		err = FSPathMakeRef((const UInt8 *)[_outputFilename UTF8String], &ref, NULL);
		if(noErr != err) {
			@throw [IOException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Unable to locate the output file '%@' (%s:%s)", @"Exceptions", @""), _outputFilename, GetMacOSStatusErrorString(err), GetMacOSStatusCommentString(err)] userInfo:nil];
		}
		
		err = AudioFileOpen(&ref, fsRdWrPerm, [[_formatInfo valueForKey:@"fileType"] intValue], &fileID);
		if(noErr != err) {
			@throw [IOException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Unable to open the output file (%s:%s)", @"Exceptions", @""), GetMacOSStatusErrorString(err), GetMacOSStatusCommentString(err)] userInfo:nil];
		}
		
		// Get the dictionary and set properties
		size = sizeof(info);
		err = AudioFileGetProperty(fileID, kAudioFilePropertyInfoDictionary, &size, &info);
		//		NSLog(@"error is %@", UTCreateStringForOSType(err));
		if(noErr == err) {
			
			bundleVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
			[info setValue:[NSString stringWithFormat:@"Max %@", bundleVersion] forKey:@kAFInfoDictionary_EncodingApplication];
			
			// Album title
			album = [_metadata valueForKey:@"albumTitle"];
			if(nil != album) {
				[info setValue:album forKey:@kAFInfoDictionary_Album];
			}
			
			// Artist
			artist = [_metadata valueForKey:@"trackArtist"];
			if(nil == artist) {
				artist = [_metadata valueForKey:@"albumArtist"];
			}
			if(nil != artist) {
				[info setValue:artist forKey:@kAFInfoDictionary_Artist];
			}
			
			// Genre
			if(1 == [_tracks count]) {
				genre = [_metadata valueForKey:@"trackGenre"];
			}
			if(nil == genre) {
				genre = [_metadata valueForKey:@"albumGenre"];
			}
			if(nil != genre) {
				[info setValue:genre forKey:@kAFInfoDictionary_Genre];
			}
			
			// Year
			year = [_metadata valueForKey:@"trackYear"];
			if(nil == year) {
				year = [_metadata valueForKey:@"albumYear"];
			}
			if(nil != year) {
				[info setValue:year forKey:@kAFInfoDictionary_Year];
			}
			
			// Comment
			comment = [_metadata valueForKey:@"albumComment"];
			if(_writeSettingsToComment) {
				comment = (nil == comment ? [self settings] : [comment stringByAppendingString:[NSString stringWithFormat:@"\n%@", [self settings]]]);
			}
			if(nil != comment) {
				[info setValue:comment forKey:@kAFInfoDictionary_Comments];
			}
			
			// Track title
			title = [_metadata valueForKey:@"trackTitle"];
			if(nil != title) {
				[info setValue:title forKey:@kAFInfoDictionary_Title];
			}
			
			// Track number
			trackNumber = [_metadata valueForKey:@"trackNumber"];
			if(nil != trackNumber) {
				[info setValue:trackNumber forKey:@kAFInfoDictionary_TrackNumber];
			}
			
			size = sizeof(info);
			err = AudioFileSetProperty(fileID, kAudioFilePropertyInfoDictionary, size, &info);
			if(noErr != err) {
				// TODO: Uncomment the following line when (if?) Apple implements this functionality
				//@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to set info dictionary (%s:%s)", GetMacOSStatusErrorString(err), GetMacOSStatusCommentString(err)] userInfo:nil];
			}
		}
		
		// Clean up	
		err = AudioFileClose(fileID);
		if(noErr != err) {
			@throw [IOException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Unable to close the output file (%s:%s)", @"Exceptions", @""), GetMacOSStatusErrorString(err), GetMacOSStatusCommentString(err)] userInfo:nil];
		}
	}	
}

- (NSString *) getOutputType
{
	return [_formatInfo valueForKey:@"fileTypeName"];
}

@end
