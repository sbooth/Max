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

#import "MonkeysAudioDecoder.h"
#import "CircularBuffer.h"

#include <mac/All.h>
#include <mac/MACLib.h>
#include <mac/IO.h>
#include <mac/CharacterHelper.h>

#define SELF_DECOMPRESSOR	(reinterpret_cast<APE::IAPEDecompress *>(_decompressor))

@implementation MonkeysAudioDecoder

- (id) initWithFilename:(NSString *)filename
{
	if((self = [super initWithFilename:filename])) {
		int result;
		
		// Setup converter
		APE::str_utfn *chars = APE::CAPECharacterHelper::GetUTF16FromANSI([[self filename] fileSystemRepresentation]);
		NSAssert(NULL != chars, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));
		
		_decompressor = (void *)CreateIAPEDecompress(chars, &result);
		NSAssert(NULL != _decompressor && ERROR_SUCCESS == result, @"Unable to open the input file.");
		
		// Setup input format descriptor
		_pcmFormat.mFormatID			= kAudioFormatLinearPCM;
		_pcmFormat.mFormatFlags			= kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsBigEndian | kAudioFormatFlagIsPacked;
		
		_pcmFormat.mSampleRate			= SELF_DECOMPRESSOR->GetInfo(APE::APE_INFO_SAMPLE_RATE);
		_pcmFormat.mChannelsPerFrame	= (UInt32)SELF_DECOMPRESSOR->GetInfo(APE::APE_INFO_CHANNELS);
		_pcmFormat.mBitsPerChannel		= (UInt32)SELF_DECOMPRESSOR->GetInfo(APE::APE_INFO_BITS_PER_SAMPLE);
		
		_pcmFormat.mBytesPerPacket		= (_pcmFormat.mBitsPerChannel / 8) * _pcmFormat.mChannelsPerFrame;
		_pcmFormat.mFramesPerPacket		= 1;
		_pcmFormat.mBytesPerFrame		= _pcmFormat.mBytesPerPacket * _pcmFormat.mFramesPerPacket;
		
		delete [] chars;
	}
	return self;
}

- (void) dealloc
{
	delete SELF_DECOMPRESSOR;
	
	[super dealloc];
}

- (NSString *)		sourceFormatDescription			{ return [NSString stringWithFormat:@"%@, %u channels, %u Hz", NSLocalizedStringFromTable(@"Monkey's Audio", @"General", @""), [self pcmFormat].mChannelsPerFrame, (unsigned)[self pcmFormat].mSampleRate]; }

- (SInt64)			totalFrames						{ return SELF_DECOMPRESSOR->GetInfo(APE::APE_DECOMPRESS_TOTAL_BLOCKS); }
//- (SInt64)			currentFrame					{ return _myCurrentFrame; }

- (BOOL)			supportsSeeking					{ return YES; }

- (SInt64) seekToFrame:(SInt64)frame
{
	NSParameterAssert(0 <= frame && frame < [self totalFrames]);

	int result = SELF_DECOMPRESSOR->Seek(frame);
	if(ERROR_SUCCESS == result)
		_currentFrame = frame;
	
	return (ERROR_SUCCESS == result ? _currentFrame : -1);
}

- (void) fillPCMBuffer
{
	CircularBuffer		*buffer				= [self pcmBuffer];
	int					result;
	APE::intn			blockSize;
	APE::intn			samplesRead;
	void				*rawBuffer;

	
	blockSize	= SELF_DECOMPRESSOR->GetInfo(APE::APE_INFO_BLOCK_ALIGN);
	NSAssert(0 != blockSize, @"Unable to determine the Monkey's Audio block size.");

	rawBuffer	= [buffer exposeBufferForWriting];
	
	result		= SELF_DECOMPRESSOR->GetData((char *)rawBuffer, [buffer freeSpaceAvailable] / blockSize, &samplesRead);
	NSAssert(ERROR_SUCCESS == result, @"Monkey's Audio invalid checksum.");

	// Convert host-ordered data to big-endian
#if __LITTLE_ENDIAN__
	swab(rawBuffer, rawBuffer, samplesRead * blockSize);
#endif
	
	[buffer wroteBytes:samplesRead * blockSize];
}

@end
