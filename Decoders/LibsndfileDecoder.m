/*
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

#import "LibsndfileDecoder.h"
#import "CircularBuffer.h"

#define SF_INPUT_BUFFER_LEN		1024

@interface LibsndfileDecoder (Private)
- (void)	setFormat:(int)format;
- (void)	setTotalFrames:(sf_count_t)totalFrames;
@end

@implementation LibsndfileDecoder

- (id) initWithFilename:(NSString *)filename
{
	if((self = [super initWithFilename:filename])) {
		SF_INFO info;
		
		_sf = sf_open([[self filename] fileSystemRepresentation], SFM_READ, &info);
		NSAssert1(NULL != _sf, @"Unable to open the input file (%s)", sf_strerror(NULL));
		
		_totalFrames = info.frames;
		[self setFormat:info.format];
		
		// Setup input format descriptor
		_pcmFormat.mFormatID			= kAudioFormatLinearPCM;
		_pcmFormat.mFormatFlags			= kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsBigEndian | kAudioFormatFlagIsPacked;
		
		_pcmFormat.mSampleRate			= info.samplerate;
		_pcmFormat.mChannelsPerFrame	= info.channels;
		
		switch(SF_FORMAT_SUBMASK & [self format]) {
			case SF_FORMAT_PCM_S8:			_pcmFormat.mBitsPerChannel	= 8;			break;
			case SF_FORMAT_PCM_16:			_pcmFormat.mBitsPerChannel	= 16;			break;
			case SF_FORMAT_PCM_24:			_pcmFormat.mBitsPerChannel	= 24;			break;
			case SF_FORMAT_PCM_32:			_pcmFormat.mBitsPerChannel	= 32;			break;
			default:						_pcmFormat.mBitsPerChannel	= 16;			break;
		}
		
		_pcmFormat.mBytesPerPacket		= (_pcmFormat.mBitsPerChannel / 8) * _pcmFormat.mChannelsPerFrame;
		_pcmFormat.mFramesPerPacket		= 1;
		_pcmFormat.mBytesPerFrame		= _pcmFormat.mBytesPerPacket * _pcmFormat.mFramesPerPacket;
	}
	return self;
}

- (void) dealloc
{
	int result = sf_close(_sf);
	NSAssert1(0 == result, @"sf_close failed: %s", sf_error_number(result));
	
	[super dealloc];
}

- (int)				format								{ return _format; }

- (NSString *) sourceFormatDescription
{
	SF_FORMAT_INFO		formatInfo;
	int					result;
	
	formatInfo.format		= [self format];
	result					= sf_command(NULL, SFC_GET_FORMAT_INFO, &formatInfo, sizeof(formatInfo));
	NSAssert(YES == result, @"sf_command (SFC_GET_FORMAT_INFO) failed.");
	
	return [NSString stringWithCString:formatInfo.name encoding:NSASCIIStringEncoding];
}

- (SInt64)			totalFrames								{ return _totalFrames; }

- (BOOL)			supportsSeeking							{ return YES; }

- (SInt64) seekToFrame:(SInt64)frame
{
	_currentFrame = sf_seek(_sf, frame, SEEK_SET);
	[[self pcmBuffer] reset];
	return [self currentFrame];
}

- (void) fillPCMBuffer
{
	CircularBuffer		*buffer				= [self pcmBuffer];
	unsigned			spaceRequired		= SF_INPUT_BUFFER_LEN * [self pcmFormat].mChannelsPerFrame * ([self pcmFormat].mBitsPerChannel / 8);

	if([buffer freeSpaceAvailable] >= spaceRequired) {
		BOOL				fpFormat;
		unsigned			i;
		sf_count_t			frameCount;
		uint32_t			sample				= 0;
		int32_t				audioSample			= 0;
		int8_t				*alias8				= NULL;
		int16_t				*alias16			= NULL;
		int32_t				*alias32			= NULL;

		
		fpFormat			= (SF_FORMAT_DOUBLE == (SF_FORMAT_SUBMASK & [self format])) || (SF_FORMAT_FLOAT == (SF_FORMAT_SUBMASK & [self format]));

		// Format is floating-point
		if(fpFormat) {
			double			doubleBuffer		[SF_INPUT_BUFFER_LEN];
			double			maxSignal;
			
			sf_command(_sf, SFC_CALC_SIGNAL_MAX, &maxSignal, sizeof(maxSignal));
			
			if(1.0 > maxSignal) {	
				frameCount	= sf_readf_double(_sf, doubleBuffer, SF_INPUT_BUFFER_LEN / [self pcmFormat].mChannelsPerFrame);
			}
			// Renormalize output
			else {	
				sf_command(_sf, SFC_SET_NORM_DOUBLE, NULL, SF_FALSE);
								
				frameCount	= sf_readf_double(_sf, doubleBuffer, SF_INPUT_BUFFER_LEN / [self pcmFormat].mChannelsPerFrame);
				for(i = 0 ; i < frameCount * [self pcmFormat].mChannelsPerFrame; ++i) {
					doubleBuffer[i] /= maxSignal;
				}
			}
			
			switch([self pcmFormat].mBitsPerChannel) {
				
				case 8:
					
					// No need for byte swapping
					alias8 = [buffer exposeBufferForWriting];
					for(sample = 0; sample < frameCount * [self pcmFormat].mChannelsPerFrame; ++sample) {
						*alias8++ = (int8_t)(doubleBuffer[sample] * (1 << 7));
					}
						
					[buffer wroteBytes:frameCount * [self pcmFormat].mChannelsPerFrame * sizeof(int8_t)];
					
					break;
					
				case 16:
					
					// Convert to big endian byte order 
					alias16 = [buffer exposeBufferForWriting];
					for(sample = 0; sample < frameCount * [self pcmFormat].mChannelsPerFrame; ++sample) {
						*alias16++ = (int16_t)OSSwapHostToBigInt16((int16_t)(doubleBuffer[sample] * (1 << 15)));
					}
						
					[buffer wroteBytes:frameCount * [self pcmFormat].mChannelsPerFrame * sizeof(int16_t)];
					
					break;
					
				case 24:
					
					// Convert to big endian byte order 
					alias8 = [buffer exposeBufferForWriting];
					for(sample = 0; sample < frameCount * [self pcmFormat].mChannelsPerFrame; ++sample) {
						audioSample	= doubleBuffer[sample] * (1 << 23);
						
						// Skip the highest byte
						*alias8++	= (int8_t)((audioSample & 0x00ff0000) >> 16);
						*alias8++	= (int8_t)((audioSample & 0x0000ff00) >> 8);
						*alias8++	= (int8_t)((audioSample & 0x000000ff) /*>> 0*/);					
					}
						
					[buffer wroteBytes:frameCount * [self pcmFormat].mChannelsPerFrame * 3 * sizeof(int8_t)];
					
					break;
					
				case 32:
					
					// Convert to big endian byte order 
					alias32 = [buffer exposeBufferForWriting];
					for(sample = 0; sample < frameCount * [self pcmFormat].mChannelsPerFrame; ++sample) {
						*alias32++ = OSSwapHostToBigInt32((doubleBuffer[sample] * (1 << 31)));
					}
						
					[buffer wroteBytes:frameCount * [self pcmFormat].mChannelsPerFrame * sizeof(int32_t)];
					
					break;
					
				default:
					@throw [NSException exceptionWithName:@"IllegalInputException" reason:@"Sample size not supported" userInfo:nil]; 
					break;	
			}
			
		}
		// Format is integer
		else {
			int				intBuffer			[SF_INPUT_BUFFER_LEN];
			unsigned		shift;
			
			// libsndfile: "Whenever integer data is moved from one sized container to another sized container, the most significant bit in the source container will become the most significant bit in the destination container."
			shift			= sizeof(int) - ([self pcmFormat].mBitsPerChannel / 8);
			frameCount		= sf_readf_int(_sf, intBuffer, SF_INPUT_BUFFER_LEN / [self pcmFormat].mChannelsPerFrame);
			
			switch([self pcmFormat].mBitsPerChannel) {
				
				case 8:
					
					// No need for byte swapping
					alias8 = [buffer exposeBufferForWriting];
					for(sample = 0; sample < frameCount * [self pcmFormat].mChannelsPerFrame; ++sample) {
						*alias8++ = (int8_t)(intBuffer[sample] >> shift);
					}
						
					[buffer wroteBytes:frameCount * [self pcmFormat].mChannelsPerFrame * sizeof(int8_t)];
					
					break;
					
				case 16:
					
					// Convert to big endian byte order
					alias16 = [buffer exposeBufferForWriting];
					for(sample = 0; sample < frameCount * [self pcmFormat].mChannelsPerFrame; ++sample) {
						*alias16++ = (int16_t)OSSwapHostToBigInt16((int16_t)(intBuffer[sample] >> shift));
					}
						
					[buffer wroteBytes:frameCount * [self pcmFormat].mChannelsPerFrame * sizeof(int16_t)];
					
					break;
					
				case 24:
					
					// Convert to big endian byte order
					alias8 = [buffer exposeBufferForWriting];
					for(sample = 0; sample < frameCount * [self pcmFormat].mChannelsPerFrame; ++sample) {
						audioSample	= OSSwapHostToBigInt32(intBuffer[sample] >> shift);
						*alias8++	= (int8_t)(audioSample >> 16);
						*alias8++	= (int8_t)(audioSample >> 8);
						*alias8++	= (int8_t)audioSample;
					}
						
					[buffer wroteBytes:frameCount * [self pcmFormat].mChannelsPerFrame * 3 * sizeof(int8_t)];
					
					break;
					
				case 32:
					
					// Convert to big endian byte order
					alias32 = [buffer exposeBufferForWriting];
					for(sample = 0; sample < frameCount * [self pcmFormat].mChannelsPerFrame; ++sample) {
						*alias32++ = OSSwapHostToBigInt32(intBuffer[sample] >> shift);
					}
						
					[buffer wroteBytes:frameCount * [self pcmFormat].mChannelsPerFrame * sizeof(int32_t)];
					
					break;
					
				default:
					@throw [NSException exceptionWithName:@"IllegalInputException" reason:@"Sample size not supported" userInfo:nil]; 
					break;	
			}			
		}
	}
}

@end

@implementation LibsndfileDecoder (Private)

- (void)				setFormat:(int)format						{ _format = format; }
- (void)				setTotalFrames:(sf_count_t)totalFrames		{ _totalFrames = totalFrames; }

@end
