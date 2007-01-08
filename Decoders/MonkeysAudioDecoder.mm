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

#import "MonkeysAudioDecoder.h"

#include <mac/All.h>
#include <mac/MACLib.h>
#include <mac/APEDecompress.h>
#include <mac/CharacterHelper.h>

#define SELF_DECOMPRESSOR	(reinterpret_cast<IAPEDecompress *>(_decompressor))

@implementation MonkeysAudioDecoder

- (void)			dealloc
{
	delete SELF_DECOMPRESSOR;
	
	[super dealloc];
}

- (NSString *)		sourceFormatDescription			{ return [NSString stringWithFormat:@"%@, %u channels, %u Hz", NSLocalizedStringFromTable(@"Monkey's Audio", @"General", @""), [self pcmFormat].mChannelsPerFrame, (unsigned)[self pcmFormat].mSampleRate]; }

- (SInt64)			totalFrames
{
	return SELF_DECOMPRESSOR->GetInfo(APE_DECOMPRESS_TOTAL_BLOCKS);
}

- (SInt64)			currentFrame					{ return -1; }
- (SInt64)			seekToFrame:(SInt64)frame		{ return -1; }

- (void)			finalizeSetup
{
	str_utf16			*chars				= NULL;
	int					result;

	// Setup converter
	chars			= GetUTF16FromANSI([[self filename] fileSystemRepresentation]);
	NSAssert(NULL != chars, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));

	_decompressor	= (void *)CreateIAPEDecompress(chars, &result);
	NSAssert(NULL != _decompressor && ERROR_SUCCESS == result, @"Unable to open the input file.");

	// Setup input format descriptor
	_pcmFormat.mFormatID			= kAudioFormatLinearPCM;
	_pcmFormat.mFormatFlags			= kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
	
	_pcmFormat.mSampleRate			= SELF_DECOMPRESSOR->GetInfo(APE_INFO_SAMPLE_RATE);
	_pcmFormat.mChannelsPerFrame	= SELF_DECOMPRESSOR->GetInfo(APE_INFO_CHANNELS);
	_pcmFormat.mBitsPerChannel		= SELF_DECOMPRESSOR->GetInfo(APE_INFO_BITS_PER_SAMPLE);
	
	_pcmFormat.mBytesPerPacket		= (_pcmFormat.mBitsPerChannel / 8) * _pcmFormat.mChannelsPerFrame;
	_pcmFormat.mFramesPerPacket		= 1;
	_pcmFormat.mBytesPerFrame		= _pcmFormat.mBytesPerPacket * _pcmFormat.mFramesPerPacket;
	
	[super finalizeSetup];
	
	delete [] chars;
}

- (void)			fillPCMBuffer
{
	CircularBuffer		*buffer				= [self pcmBuffer];
	int					result;
	int					blockSize;
	int					samplesRead;

	
	blockSize	= SELF_DECOMPRESSOR->GetInfo(APE_INFO_BLOCK_ALIGN);
	NSAssert(0 != blockSize, @"Unable to determine the Monkey's Audio block size.");
	
	result		= SELF_DECOMPRESSOR->GetData((char *)[buffer exposeBufferForWriting], [buffer freeSpaceAvailable] / blockSize, &samplesRead);
	NSAssert(ERROR_SUCCESS == result, @"Monkey's Audio invalid checksum.");

	[buffer wroteBytes:samplesRead * blockSize];
}

@end
