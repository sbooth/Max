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

#import "CoreAudioConverterTask.h"
#import "CoreAudioConverter.h"
#import "IOException.h"
#import "CoreAudioException.h"

#include <CoreAudio/CoreAudioTypes.h>
#include <AudioToolbox/AudioFormat.h>
#include <AudioToolbox/AudioConverter.h>
#include <AudioToolbox/AudioFile.h>
#include <AudioToolbox/ExtendedAudioFile.h>

@implementation CoreAudioConverterTask

- (id) initWithInputFilename:(NSString *)inputFilename metadata:(AudioMetadata *)metadata
{
	OSStatus						err;
	FSRef							ref;
	UInt32							size;
	AudioStreamBasicDescription		asbd;
	ExtAudioFileRef					extAudioFileRef;

	if((self = [super initWithInputFilename:inputFilename metadata:metadata])) {

		_converterClass = [CoreAudioConverter class];
		
		// Get information on the input file
		err = FSPathMakeRef((const UInt8 *)[_inputFilename UTF8String], &ref, NULL);
		if(noErr != err) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to locate the input file", @"Exceptions", @"")
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:_inputFilename, [NSString stringWithUTF8String:GetMacOSStatusErrorString(err)], [NSString stringWithUTF8String:GetMacOSStatusCommentString(err)], nil] forKeys:[NSArray arrayWithObjects:@"filename", @"errorCode", @"errorString", nil]]];
		}
		
		err = ExtAudioFileOpen(&ref, &extAudioFileRef);
		if(noErr != err) {
			@throw [CoreAudioException exceptionWithReason:NSLocalizedStringFromTable(@"ExtAudioFileOpen failed", @"Exceptions", @"")
												  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithUTF8String:GetMacOSStatusErrorString(err)], [NSString stringWithUTF8String:GetMacOSStatusCommentString(err)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		size	= sizeof(asbd);
		err		= ExtAudioFileGetProperty(extAudioFileRef, kExtAudioFileProperty_FileDataFormat, &size, &asbd);;
		if(err != noErr) {
			@throw [CoreAudioException exceptionWithReason:NSLocalizedStringFromTable(@"ExtAudioFileGetProperty failed", @"Exceptions", @"")
												  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithUTF8String:GetMacOSStatusErrorString(err)], [NSString stringWithUTF8String:GetMacOSStatusCommentString(err)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		size	= sizeof(_fileFormat);
		err		= AudioFormatGetProperty(kAudioFormatProperty_FormatName, sizeof(AudioStreamBasicDescription), &asbd, &size, &_fileFormat);
		if(noErr != err) {
			_fileFormat = NSLocalizedStringFromTable(@"Unknown (Core Audio)", @"General", @"");
		}		
		
		err = ExtAudioFileDispose(extAudioFileRef);
		if(noErr != err) {
			@throw [CoreAudioException exceptionWithReason:NSLocalizedStringFromTable(@"ExtAudioFileDispose failed", @"Exceptions", @"")
												  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithUTF8String:GetMacOSStatusErrorString(err)], [NSString stringWithUTF8String:GetMacOSStatusCommentString(err)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}	
		
		return self;
	}
	return nil;
}

- (NSString *)		inputFormat									{ return _fileFormat; }

@end
