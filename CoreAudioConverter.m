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

#import "CoreAudioConverter.h"

#import "MallocException.h"
#import "IOException.h"
#import "StopException.h"
#import "CoreAudioException.h"

#include <fcntl.h>		// open, write
#include <sys/stat.h>	// stat

#include <CoreAudio/CoreAudioTypes.h>
#include <AudioToolbox/AudioFormat.h>
#include <AudioToolbox/AudioConverter.h>
#include <AudioToolbox/AudioFile.h>
#include <AudioToolbox/ExtendedAudioFile.h>

@implementation CoreAudioConverter

- (id) initWithInputFilename:(NSString *)inputFilename
{
	OSStatus						err;
	FSRef							ref;
	UInt32							size;
	AudioStreamBasicDescription		asbd;

	if((self = [super initWithInputFilename:inputFilename])) {
		
		bzero(&_outputASBD, sizeof(AudioStreamBasicDescription));
		
		// Desired output is interleaved 16-bit PCM audio
		_outputASBD.mSampleRate			= 44100.f;
		_outputASBD.mFormatID			= kAudioFormatLinearPCM;
		_outputASBD.mFormatFlags		= kAudioFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsBigEndian;
		_outputASBD.mBytesPerPacket		= 4;
		_outputASBD.mFramesPerPacket	= 1;
		_outputASBD.mBytesPerFrame		= 4;
		_outputASBD.mChannelsPerFrame	= 2;
		_outputASBD.mBitsPerChannel		= 16;
		
		// Open the output file
		err = FSPathMakeRef((const UInt8 *)[_inputFilename UTF8String], &ref, NULL);
		if(noErr != err) {
			@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to locate input file (%s: %s)", GetMacOSStatusErrorString(err), GetMacOSStatusCommentString(err)] userInfo:nil];
		}
		
		err = ExtAudioFileOpen(&ref, &_in);
		if(noErr != err) {
			[self setValue:[NSNumber numberWithBool:YES] forKey:@"stopped"];
			@throw [CoreAudioException exceptionWithReason:[NSString stringWithFormat:@"ExtAudioFileOpen failed (%s: %s)", GetMacOSStatusErrorString(err), GetMacOSStatusCommentString(err)] userInfo:nil];
		}
		
		err = ExtAudioFileSetProperty(_in, kExtAudioFileProperty_ClientDataFormat, sizeof(_outputASBD), &_outputASBD);
		if(noErr != err) {
			[self setValue:[NSNumber numberWithBool:YES] forKey:@"stopped"];
			@throw [CoreAudioException exceptionWithReason:[NSString stringWithFormat:@"ExtAudioFileSetProperty failed (%s: %s)", GetMacOSStatusErrorString(err), GetMacOSStatusCommentString(err)] userInfo:nil];
		}

		size	= sizeof(asbd);
		err		= ExtAudioFileGetProperty(_in, kExtAudioFileProperty_FileDataFormat, &size, &asbd);;
		if(err != noErr) {
			[_delegate setValue:[NSNumber numberWithBool:YES] forKey:@"stopped"];
			@throw [CoreAudioException exceptionWithReason:[NSString stringWithFormat:@"ExtAudioFileGetProperty failed (%s: %s)", GetMacOSStatusErrorString(err), GetMacOSStatusCommentString(err)] userInfo:nil];
		}
		
		size	= sizeof(_fileType);
		err		= AudioFormatGetProperty(kAudioFormatProperty_FormatName, sizeof(AudioStreamBasicDescription), &asbd, &size, &_fileType);
		if(noErr != err) {
			_fileType = @"Unknown (Core Audio)";
		}
		
		return self;
	}
	return nil;
}

- (void) dealloc
{
	OSStatus			err;

	[_fileType release];
	
	// Close the input file
	err = ExtAudioFileDispose(_in);
	if(noErr != err) {
		@throw [CoreAudioException exceptionWithReason:[NSString stringWithFormat:@"ExtAudioFileDispose failed (%s: %s)", GetMacOSStatusErrorString(err), GetMacOSStatusCommentString(err)] userInfo:nil];
	}	
		
	[super dealloc];
}

- (void) convertToFile:(int)file
{
	NSDate			*startTime			= [NSDate date];
	OSStatus		err;
	UInt32			frameCount;
	UInt32			size;
	SInt64			totalFrames;
	SInt64			framesToRead;
	
	
	// Tell our owner we are starting
	[_delegate setValue:startTime forKey:@"startTime"];	
	[_delegate setValue:[NSNumber numberWithBool:YES] forKey:@"started"];
	[_delegate setValue:[NSNumber numberWithDouble:0.0] forKey:@"percentComplete"];
	
	// Get input file information
	size	= sizeof(totalFrames);
	err		= ExtAudioFileGetProperty(_in, kExtAudioFileProperty_FileLengthFrames, &size, &totalFrames);;
	if(err != noErr) {
		[_delegate setValue:[NSNumber numberWithBool:YES] forKey:@"stopped"];
		@throw [CoreAudioException exceptionWithReason:[NSString stringWithFormat:@"ExtAudioFileGetProperty failed (%s: %s)", GetMacOSStatusErrorString(err), GetMacOSStatusCommentString(err)] userInfo:nil];
	}
	
	framesToRead = totalFrames;
	
	// Allocate the input buffer
	_buflen								= 1024;
	_buf.mNumberBuffers					= 1;
	_buf.mBuffers[0].mNumberChannels	= 2;
	_buf.mBuffers[0].mDataByteSize		= _buflen * sizeof(int16_t);
	_buf.mBuffers[0].mData				= calloc(_buflen, sizeof(int16_t));;
	if(NULL == _buf.mBuffers[0].mData) {
		[_delegate setValue:[NSNumber numberWithBool:YES] forKey:@"stopped"];
		@throw [MallocException exceptionWithReason:[NSString stringWithFormat:@"Unable to allocate memory (%i:%s) [%s:%i]", errno, strerror(errno), __FILE__, __LINE__] userInfo:nil];
	}
	
	// Iteratively get the data and convert it to PCM
	for(;;) {
		// Check if we should stop, and if so throw an exception
		if([_delegate shouldStop]) {
			[_delegate setValue:[NSNumber numberWithBool:YES] forKey:@"stopped"];
			@throw [StopException exceptionWithReason:@"Stop requested by user" userInfo:nil];
		}
		
		// Read a chunk of PCM input (converted from whatever format)
		frameCount	= _buf.mBuffers[0].mDataByteSize / _outputASBD.mBytesPerPacket;
		err			= ExtAudioFileRead(_in, &frameCount, &_buf);
		if(err != noErr) {
			[_delegate setValue:[NSNumber numberWithBool:YES] forKey:@"stopped"];
			@throw [CoreAudioException exceptionWithReason:[NSString stringWithFormat:@"ExtAudioFileRead failed (%s: %s)", GetMacOSStatusErrorString(err), GetMacOSStatusCommentString(err)] userInfo:nil];
		}
		
		// We're finished if no frames were returned
		if(0 == frameCount) {
			break;
		}
		
		// Write the PCM data to file
		if(-1 == write(file, _buf.mBuffers[0].mData, frameCount * _outputASBD.mBytesPerPacket)) {
			[_delegate setValue:[NSNumber numberWithBool:YES] forKey:@"stopped"];
			@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to write to output file (%i:%s) [%s:%i]", errno, strerror(errno), __FILE__, __LINE__] userInfo:nil];
		}
			
		// Update status
		framesToRead -= frameCount;
		if(0 == framesToRead % 10) {
			[_delegate setValue:[NSNumber numberWithDouble:((double)(totalFrames - framesToRead)/(double) totalFrames) * 100.0] forKey:@"percentComplete"];
			NSTimeInterval interval = -1.0 * [startTime timeIntervalSinceNow];
			unsigned int timeRemaining = interval / ((double)(totalFrames - framesToRead)/(double) totalFrames) - interval;
			[_delegate setValue:[NSString stringWithFormat:@"%i:%02i", timeRemaining / 60, timeRemaining % 60] forKey:@"timeRemaining"];
		}
	}
	
	[_delegate setValue:[NSDate date] forKey:@"endTime"];
	[_delegate setValue:[NSNumber numberWithDouble:100.0] forKey:@"percentComplete"];
	[_delegate setValue:[NSNumber numberWithBool:YES] forKey:@"completed"];	
}

@end
