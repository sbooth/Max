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

#import "CoreAudioDecoder.h"
#import "CircularBuffer.h"

#include <AudioToolbox/AudioFormat.h>

@implementation CoreAudioDecoder

- (id) initWithFilename:(NSString *)filename
{
	if((self = [super initWithFilename:filename])) {
		OSStatus result = ExtAudioFileOpenURL((CFURLRef)[NSURL fileURLWithPath:filename], &_extAudioFile);
		NSAssert1(noErr == result, @"ExtAudioFileOpenURL failed: %@", UTCreateStringForOSType(result));
		
		// Query file type
		UInt32 dataSize = sizeof(AudioStreamBasicDescription);
		result = ExtAudioFileGetProperty(_extAudioFile, kExtAudioFileProperty_FileDataFormat, &dataSize, &_sourceFormat);
		NSAssert1(noErr == result, @"AudioFileGetProperty failed: %@", UTCreateStringForOSType(result));
		
		// Setup input format descriptor
		_pcmFormat						= _sourceFormat;
		
		_pcmFormat.mFormatID			= kAudioFormatLinearPCM;
		_pcmFormat.mFormatFlags			= kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsBigEndian | kAudioFormatFlagIsPacked;
		
		// For alac the source bit depth is encoded in the format flag
		if(kAudioFormatAppleLossless == _sourceFormat.mFormatID) {
			switch (_sourceFormat.mFormatFlags) {
				case kAppleLosslessFormatFlag_16BitSourceData:
					_pcmFormat.mBitsPerChannel = 16;
					break;
//				case kAppleLosslessFormatFlag_20BitSourceData:
//					_pcmFormat.mBitsPerChannel = 20;
//					break;
				case kAppleLosslessFormatFlag_24BitSourceData:
					_pcmFormat.mBitsPerChannel = 24;
					break;
				case kAppleLosslessFormatFlag_32BitSourceData:
					_pcmFormat.mBitsPerChannel = 32;
					break;
					
// FIXME: How to handle 20-bit files?
				default:
					_pcmFormat.mBitsPerChannel = 16;
					break;
			}	
		}
		else
			// Preserve mSampleRate and mChannelsPerFrame
			_pcmFormat.mBitsPerChannel	= (0 == _pcmFormat.mBitsPerChannel ? 16 : _pcmFormat.mBitsPerChannel);
		
		_pcmFormat.mBytesPerPacket		= (_pcmFormat.mBitsPerChannel / 8) * _pcmFormat.mChannelsPerFrame;
		_pcmFormat.mFramesPerPacket		= 1;
		_pcmFormat.mBytesPerFrame		= _pcmFormat.mBytesPerPacket * _pcmFormat.mFramesPerPacket;
		
		// Tell the extAudioFile the format we'd like for data
		result			= ExtAudioFileSetProperty(_extAudioFile, kExtAudioFileProperty_ClientDataFormat, sizeof(_pcmFormat), &_pcmFormat);
		NSAssert1(noErr == result, @"ExtAudioFileSetProperty failed: %@", UTCreateStringForOSType(result));
		
	}
	return self;
}

- (void) dealloc
{
	OSStatus result = ExtAudioFileDispose(_extAudioFile);
	NSAssert1(noErr == result, @"ExtAudioFileDispose failed: %@", UTCreateStringForOSType(result));
	
	[super dealloc];
}

- (NSString *) sourceFormatDescription
{
	OSStatus						result;
	UInt32							specifierSize;
	AudioStreamBasicDescription		asbd;
	NSString						*fileFormat;
	
	asbd			= _sourceFormat;
	specifierSize	= sizeof(fileFormat);
	result			= AudioFormatGetProperty(kAudioFormatProperty_FormatName, sizeof(AudioStreamBasicDescription), &asbd, &specifierSize, &fileFormat);
	NSAssert1(noErr == result, @"AudioFormatGetProperty failed: %@", UTCreateStringForOSType(result));
	
	return [fileFormat autorelease];
}

- (SInt64) totalFrames
{
	OSStatus	result;
	UInt32		dataSize;
	SInt64		frameCount;
	
	dataSize		= sizeof(frameCount);
	result			= ExtAudioFileGetProperty(_extAudioFile, kExtAudioFileProperty_FileLengthFrames, &dataSize, &frameCount);
	NSAssert1(noErr == result, @"ExtAudioFileGetProperty(kExtAudioFileProperty_FileLengthFrames) failed: %@", UTCreateStringForOSType(result));

	return frameCount;
}

/*
- (SInt64) currentFrame
{
	OSStatus	result;
	SInt64		frame;
	
	result			= ExtAudioFileTell(_extAudioFile, &frame);
	NSAssert1(noErr == result, @"ExtAudioFileTell failed: %@", UTCreateStringForOSType(result));
	
	return frame;
}
*/
- (BOOL) supportsSeeking
{
	return YES;
}

- (SInt64) seekToFrame:(SInt64)frame
{
	OSStatus result = ExtAudioFileSeek(_extAudioFile, frame);
	if(noErr == result) {
		[[self pcmBuffer] reset];
		_currentFrame = frame;
	}
	
	return [self currentFrame];
}

- (void) fillPCMBuffer
{
	CircularBuffer		*buffer				= [self pcmBuffer];
	OSStatus			result;
	AudioBufferList		bufferList;
	UInt32				frameCount;
	
	bufferList.mNumberBuffers				= 1;
	bufferList.mBuffers[0].mNumberChannels	= [self pcmFormat].mChannelsPerFrame;
	bufferList.mBuffers[0].mData			= [buffer exposeBufferForWriting];
	bufferList.mBuffers[0].mDataByteSize	= (UInt32)[buffer freeSpaceAvailable];

	frameCount								= bufferList.mBuffers[0].mDataByteSize / [self pcmFormat].mBytesPerFrame;
	result									= ExtAudioFileRead(_extAudioFile, &frameCount, &bufferList);
	NSAssert1(noErr == result, @"ExtAudioFileRead failed: %@", UTCreateStringForOSType(result));

	NSAssert(frameCount * [self pcmFormat].mBytesPerFrame == bufferList.mBuffers[0].mDataByteSize, @"mismatch");
	
	[buffer wroteBytes:bufferList.mBuffers[0].mDataByteSize];
}

@end
