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

#import "WavPackDecoder.h"
#import "CircularBuffer.h"

#define WP_INPUT_BUFFER_LEN		1024

@implementation WavPackDecoder

- (id) initWithFilename:(NSString *)filename
{
	if((self = [super initWithFilename:filename])) {
		char error [80];
		
		// Setup converter
		_wpc = WavpackOpenFileInput([[self filename] fileSystemRepresentation], error, OPEN_WVC, 0);
		NSAssert1(NULL != _wpc, @"Unable to open the input file (%s).", error);
		
		// Setup input format descriptor
		_pcmFormat.mFormatID			= kAudioFormatLinearPCM;
		_pcmFormat.mFormatFlags			= kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsBigEndian | kAudioFormatFlagIsPacked;
		
		_pcmFormat.mSampleRate			= WavpackGetSampleRate(_wpc);
		_pcmFormat.mChannelsPerFrame	= WavpackGetNumChannels(_wpc);
		_pcmFormat.mBitsPerChannel		= WavpackGetBitsPerSample(_wpc);
		
		_pcmFormat.mBytesPerPacket		= (_pcmFormat.mBitsPerChannel / 8) * _pcmFormat.mChannelsPerFrame;
		_pcmFormat.mFramesPerPacket		= 1;
		_pcmFormat.mBytesPerFrame		= _pcmFormat.mBytesPerPacket * _pcmFormat.mFramesPerPacket;
	}
	return self;
}

- (void) dealloc
{
	WavpackCloseFile(_wpc);
	_wpc = NULL;
	
	[super dealloc];
}

- (NSString *)		sourceFormatDescription			{ return [NSString stringWithFormat:@"%@, %u channels, %u Hz", NSLocalizedStringFromTable(@"WavPack", @"General", @""), [self pcmFormat].mChannelsPerFrame, (unsigned)[self pcmFormat].mSampleRate]; }

- (SInt64)			totalFrames						{ return WavpackGetNumSamples(_wpc); }

- (SInt64) seekToFrame:(SInt64)frame
{
	if(WavpackSeekSample(_wpc, (uint32_t)frame)) {
		[[self pcmBuffer] reset]; 
		_currentFrame = frame; 
	}
	
	return [self currentFrame];
}

- (void) fillPCMBuffer
{
	CircularBuffer		*buffer				= [self pcmBuffer];
	unsigned			spaceRequired		= 0;
	
	// Calculate how many bytes will be required to hold WP_INPUT_BUFFER_LEN "complete" samples
	spaceRequired		= WP_INPUT_BUFFER_LEN /* * [self pcmFormat].mChannelsPerFrame*/ * ([self pcmFormat].mBitsPerChannel / 8);
	
	if([buffer freeSpaceAvailable] >= spaceRequired) {
		int32_t				inputBuffer			[WP_INPUT_BUFFER_LEN];
		uint32_t			samplesRead			= 0;
		uint32_t			sample				= 0;
		int32_t				audioSample			= 0;
		int8_t				*alias8				= NULL;
		int16_t				*alias16			= NULL;
		int32_t				*alias32			= NULL;
		
		// Wavpack uses "complete" samples (one sample across all channels), i.e. a Core Audio frame
		samplesRead		= WavpackUnpackSamples(_wpc, inputBuffer, WP_INPUT_BUFFER_LEN / [self pcmFormat].mChannelsPerFrame);
		
		switch([self pcmFormat].mBitsPerChannel) {
			
			case 8:
				
				// No need for byte swapping
				alias8 = [buffer exposeBufferForWriting];
				for(sample = 0; sample < samplesRead * [self pcmFormat].mChannelsPerFrame; ++sample) {
					*alias8++ = (int8_t)inputBuffer[sample];
				}

				[buffer wroteBytes:samplesRead * [self pcmFormat].mChannelsPerFrame * sizeof(int8_t)];
				
				break;
				
			case 16:
				
				// Convert to big endian byte order 
				alias16 = [buffer exposeBufferForWriting];
				for(sample = 0; sample < samplesRead * [self pcmFormat].mChannelsPerFrame; ++sample) {
					*alias16++ = (int16_t)OSSwapHostToBigInt16((int16_t)inputBuffer[sample]);
				}
					
				[buffer wroteBytes:samplesRead * [self pcmFormat].mChannelsPerFrame * sizeof(int16_t)];
				
				break;
				
			case 24:
				
				// Convert to big endian byte order 
				alias8 = [buffer exposeBufferForWriting];
				for(sample = 0; sample < samplesRead * [self pcmFormat].mChannelsPerFrame; ++sample) {
					audioSample	= inputBuffer[sample];
					
					// Skip the highest byte
					*alias8++	= (int8_t)((audioSample & 0x00ff0000) >> 16);
					*alias8++	= (int8_t)((audioSample & 0x0000ff00) >> 8);
					*alias8++	= (int8_t)((audioSample & 0x000000ff) /*>> 0*/);					
				}
					
				[buffer wroteBytes:samplesRead * [self pcmFormat].mChannelsPerFrame * 3 * sizeof(int8_t)];
				
				break;
				
			case 32:
				
				// Convert to big endian byte order 
				alias32 = [buffer exposeBufferForWriting];
				for(sample = 0; sample < samplesRead * [self pcmFormat].mChannelsPerFrame; ++sample) {
					*alias32++ = OSSwapHostToBigInt32(inputBuffer[sample]);
				}
					
				[buffer wroteBytes:samplesRead * [self pcmFormat].mChannelsPerFrame * sizeof(int32_t)];
				
				break;
				
			default:
				@throw [NSException exceptionWithName:@"IllegalInputException" reason:@"Sample size not supported" userInfo:nil]; 
			break;	
		}
	}
}

@end
