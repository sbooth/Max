/*
 *  $Id: EncoderTask.m 181 2005-11-28 08:38:43Z me $
 *
 *  Copyright (C) 2005 Stephen F. Booth <me@sbooth.org>
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

#include <AudioToolbox/AudioFile.h>

@implementation CoreAudioEncoderTask

- (id) initWithSource:(RipperTask *)source target:(NSString *)target tracks:(NSArray *)tracks formatInfo:(NSDictionary *)formatInfo
{
	if((self = [super initWithSource:source target:target tracks:tracks])) {
		_formatInfo	= [formatInfo retain];
		_encoder	= [[CoreAudioEncoder alloc] initWithSource:[_source valueForKey:@"path"] formatInfo:formatInfo];
		return self;
	}
	return nil;
}

- (void) dealloc
{
	[_formatInfo release];
	[_encoder release];
	[super dealloc];
}

- (void) writeTags
{
	OSStatus				err;
	FSRef					ref;
	AudioFileID				fileID;
	NSMutableDictionary		*info;
	UInt32					size;
	NSString				*bundleVersion			= nil;
	NSNumber				*trackNumber			= nil;
	NSString				*album					= nil;
	NSString				*artist					= nil;
	NSString				*title					= nil;
	NSNumber				*year					= nil;
	NSString				*genre					= nil;
	NSString				*comment				= nil;
	Track					*track					= [_tracks objectAtIndex:0];
	
	
	// Open the file
	err = FSPathMakeRef([_target UTF8String], &ref, NULL);
	if(noErr != err) {
		@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to locate output file (%s: %s)", GetMacOSStatusErrorString(err), GetMacOSStatusCommentString(err)] userInfo:nil];
	}
	
	err = AudioFileOpen(&ref, fsRdWrPerm, [[_formatInfo valueForKey:@"fileType"] intValue], &fileID);
	if(noErr != err) {
		@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to open output file (%s: %s)", GetMacOSStatusErrorString(err), GetMacOSStatusCommentString(err)] userInfo:nil];
	}
	
	// Get the dictionary and set properties
	size = sizeof(info);
	err = AudioFileGetProperty(fileID, kAudioFilePropertyInfoDictionary, &size, &info);
	//		NSLog(@"error is %@", UTCreateStringForOSType(err));
	if(noErr == err) {
		
		bundleVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
		[info setValue:[NSString stringWithFormat:@"Max %@", bundleVersion] forKey:@kAFInfoDictionary_EncodingApplication];
		
		// Album title
		album = [track valueForKeyPath:@"disc.title"];
		if(nil != album) {
			[info setValue:album forKey:@kAFInfoDictionary_Album];
		}
		
		// Artist
		if(1 == [_tracks count]) {
			artist = [track valueForKey:@"artist"];
		}
		if(nil == artist) {
			artist = [track valueForKeyPath:@"disc.artist"];
		}
		if(nil != artist) {
			[info setValue:artist forKey:@kAFInfoDictionary_Artist];
		}
		
		// Genre
		if(1 == [_tracks count]) {
			genre = [track valueForKey:@"genre"];
		}
		if(nil == genre) {
			genre = [track valueForKeyPath:@"disc.genre"];
		}
		if(nil != genre) {
			[info setValue:genre forKey:@kAFInfoDictionary_Genre];
		}
		
		// Year
		if(1 == [_tracks count]) {
			year = [track valueForKey:@"year"];
		}
		if(nil == year) {
			year = [track valueForKeyPath:@"disc.year"];
		}
		if(nil != year) {
			[info setValue:year forKey:@kAFInfoDictionary_Year];
		}
		
		// Comment
		comment = [track valueForKeyPath:@"disc.comment"];
		if(_writeSettingsToComment) {
			comment = (nil == comment ? [_encoder description] : [comment stringByAppendingString:[NSString stringWithFormat:@"\n%@", [_encoder description]]]);
		}
		if(nil != comment) {
			[info setValue:comment forKey:@kAFInfoDictionary_Comments];
		}
		
		if(1 == [_tracks count]) {
			// Track title
			title = [track valueForKey:@"title"];
			if(nil != title) {
				[info setValue:title forKey:@kAFInfoDictionary_Title];
			}
			
			// Track number
			trackNumber = [track valueForKey:@"number"];
			if(nil != trackNumber) {
				[info setValue:trackNumber forKey:@kAFInfoDictionary_TrackNumber];
			}
		}
		else {
			NSEnumerator	*enumerator;
			Track			*temp;
			
			enumerator	= [_tracks objectEnumerator];
			temp		= [enumerator nextObject];
			
			title		= [temp valueForKey:@"title"];
			
			while((temp = [enumerator nextObject])) {
				title = [title stringByAppendingString:[NSString stringWithFormat:@", %@", [temp valueForKey:@"title"]]];
			}

			if(nil != title) {
				[info setValue:title forKey:@kAFInfoDictionary_Title];
			}
		}
		
		size = sizeof(info);
		err = AudioFileSetProperty(fileID, kAudioFilePropertyInfoDictionary, size, &info);
		if(noErr != err) {
			@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to set info dictionary (%s: %s)", GetMacOSStatusErrorString(err), GetMacOSStatusCommentString(err)] userInfo:nil];
		}
	}
	
	// Clean up	
	err = AudioFileClose(fileID);
	if(noErr != err) {
		@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to close output file (%s: %s)", GetMacOSStatusErrorString(err), GetMacOSStatusCommentString(err)] userInfo:nil];
	}
}

- (NSString *) getType
{
	return [_formatInfo valueForKey:@"fileTypeName"];
}

@end
