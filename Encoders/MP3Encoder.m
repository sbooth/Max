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

#import "MP3Encoder.h"

#include <CoreAudio/CoreAudioTypes.h>
#include <AudioToolbox/AudioFormat.h>
#include <AudioToolbox/AudioConverter.h>
#include <AudioToolbox/AudioFile.h>
#include <AudioToolbox/ExtendedAudioFile.h>
#include <AudioUnit/AudioCodec.h>

#include <lame/lame.h>

#import "Decoder.h"
#import "RegionDecoder.h"

#import "StopException.h"

#import "UtilityFunctions.h"

#include <fcntl.h>		// open, write
#include <stdio.h>		// fopen, fclose
#include <sys/stat.h>	// stat

// Bitrates supported for 44.1 kHz audio
static int sLAMEBitrates [14] = { 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320 };

@interface MP3Encoder (Private)
- (void)	parseSettings;
- (void)	encodeChunk:(const AudioBufferList *)chunk frameCount:(UInt32)frameCount;
- (void)	finishEncode;
@end

@implementation MP3Encoder

- (id) init
{
	if((self = [super init])) {
		_gfp	= lame_init();
		NSAssert(NULL != _gfp, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));
		
		// Write the Xing VBR tag
		lame_set_bWriteVbrTag(_gfp, 1);			
	}
	
	return self;
}

- (void) dealloc
{
	lame_close(_gfp);	
	
	[super dealloc];
}

- (oneway void) encodeToFile:(NSString *) filename
{
	NSDate							*startTime						= [NSDate date];
	FILE							*file							= NULL;
	int								result;
	AudioBufferList					bufferList;
	ssize_t							bufferLen						= 0;
	UInt32							bufferByteSize					= 0;
	SInt64							totalFrames, framesToRead;
	UInt32							frameCount;
	unsigned long					iterations						= 0;
	double							percentComplete;
	NSTimeInterval					interval;
	unsigned						secondsRemaining;	
	
	@try {
		bufferList.mBuffers[0].mData = NULL;

		// Parse the encoder settings
		[self parseSettings];

		// Tell our owner we are starting
		[[self delegate] setStartTime:startTime];	
		[[self delegate] setStarted:YES];
		
		// Setup the decoder
		id <DecoderMethods> decoder = nil;
		NSString *sourceFilename = [[[self delegate] taskInfo] inputFilenameAtInputFileIndex];
		
		// Create the appropriate kind of decoder
		if(nil != [[[[self delegate] taskInfo] settings] valueForKey:@"framesToConvert"]) {
			SInt64 startingFrame = [[[[[[self delegate] taskInfo] settings] valueForKey:@"framesToConvert"] valueForKey:@"startingFrame"] longLongValue];
			UInt32 frameCount = [[[[[[self delegate] taskInfo] settings] valueForKey:@"framesToConvert"] valueForKey:@"frameCount"] unsignedIntValue];
			decoder = [RegionDecoder decoderWithFilename:sourceFilename startingFrame:startingFrame frameCount:frameCount];
		}
		else
			decoder = [Decoder decoderWithFilename:sourceFilename];
		
		NSAssert(1 == [decoder pcmFormat].mChannelsPerFrame || 2 == [decoder pcmFormat].mChannelsPerFrame, NSLocalizedStringFromTable(@"LAME only supports one or two channel input.", @"Exceptions", @""));

		_sourceBitsPerChannel	= [decoder pcmFormat].mBitsPerChannel;
		totalFrames				= [decoder totalFrames];
		framesToRead			= totalFrames;
		
		// Set up the AudioBufferList
		bufferList.mNumberBuffers					= 1;
		bufferList.mBuffers[0].mData				= NULL;
		bufferList.mBuffers[0].mNumberChannels		= [decoder pcmFormat].mChannelsPerFrame;
		
		// Allocate the buffer that will hold the interleaved audio data
		bufferLen									= 1024;
		switch([decoder pcmFormat].mBitsPerChannel) {
			
			case 8:				
			case 24:
				bufferList.mBuffers[0].mData			= calloc(bufferLen, sizeof(int8_t));
				bufferList.mBuffers[0].mDataByteSize	= (UInt32)bufferLen * sizeof(int8_t);
				break;
				
			case 16:
				bufferList.mBuffers[0].mData			= calloc(bufferLen, sizeof(int16_t));
				bufferList.mBuffers[0].mDataByteSize	= (UInt32)bufferLen * sizeof(int16_t);
				break;
				
			case 32:
				bufferList.mBuffers[0].mData			= calloc(bufferLen, sizeof(int32_t));
				bufferList.mBuffers[0].mDataByteSize	= (UInt32)bufferLen * sizeof(int32_t);
				break;
				
			default:
				@throw [NSException exceptionWithName:@"IllegalInputException" reason:@"Sample size not supported" userInfo:nil]; 
				break;				
		}
		
		bufferByteSize = bufferList.mBuffers[0].mDataByteSize;
		NSAssert(NULL != bufferList.mBuffers[0].mData, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));
		
		// Initialize the LAME encoder
		lame_set_num_channels(_gfp, [decoder pcmFormat].mChannelsPerFrame);
		lame_set_in_samplerate(_gfp, [decoder pcmFormat].mSampleRate);
		
		result = lame_init_params(_gfp);
		NSAssert(-1 != result, NSLocalizedStringFromTable(@"Unable to initialize the LAME encoder.", @"Exceptions", @""));

		// Open the output file
		_out = fopen([filename fileSystemRepresentation], "w");
		NSAssert(NULL != _out, NSLocalizedStringFromTable(@"Unable to create the output file.", @"Exceptions", @""));
		
		// Iteratively get the PCM data and encode it
		for(;;) {
			
			// Set up the buffer parameters
			bufferList.mBuffers[0].mNumberChannels	= [decoder pcmFormat].mChannelsPerFrame;
			bufferList.mBuffers[0].mDataByteSize	= bufferByteSize;
			frameCount								= bufferList.mBuffers[0].mDataByteSize / [decoder pcmFormat].mBytesPerFrame;
			
			// Read a chunk of PCM input
			frameCount		= [decoder readAudio:&bufferList frameCount:frameCount];
			
			// We're finished if no frames were returned
			if(0 == frameCount) {
				break;
			}
			
			// Encode the PCM data
			[self encodeChunk:&bufferList frameCount:frameCount];
			
			// Update status
			framesToRead -= frameCount;
			
			// Distributed Object calls are expensive, so only perform them every few iterations
			if(0 == iterations % MAX_DO_POLL_FREQUENCY) {
				
				// Check if we should stop, and if so throw an exception
				if([[self delegate] shouldStop]) {
					@throw [StopException exceptionWithReason:@"Stop requested by user" userInfo:nil];
				}
				
				// Update UI
				percentComplete		= ((double)(totalFrames - framesToRead)/(double) totalFrames) * 100.0;
				interval			= -1.0 * [startTime timeIntervalSinceNow];
				secondsRemaining	= (unsigned) (interval / ((double)(totalFrames - framesToRead)/(double) totalFrames) - interval);
				
				[[self delegate] updateProgress:percentComplete secondsRemaining:secondsRemaining];
			}
			
			++iterations;
		}
		
		// Flush the last MP3 frames (maybe)
		[self finishEncode];
		
		// Close the output file
		result = fclose(_out);
		NSAssert(0 == result, NSLocalizedStringFromTable(@"Unable to close the output file.", @"Exceptions", @""));
		_out = NULL;
		
		// Write the Xing VBR tag
		file = fopen([filename fileSystemRepresentation], "r+");
		NSAssert(NULL != file, NSLocalizedStringFromTable(@"Unable to open the output file.", @"Exceptions", @""));

		lame_mp3_tags_fid(_gfp, file);
	}

	@catch(StopException *exception) {
		[[self delegate] setStopped:YES];
	}
	
	@catch(NSException *exception) {
		[[self delegate] setException:exception];
		[[self delegate] setStopped:YES];
	}
	
	@finally {
		NSException *exception;
				
		// Close the output file if not already closed
		if(NULL != _out && EOF == fclose(_out)) {
			exception = [NSException exceptionWithName:@"IOException"
												reason:NSLocalizedStringFromTable(@"Unable to close the output file.", @"Exceptions", @"") 
											  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			NSLog(@"%@", exception);
		}

		// And close the other output file
		if(NULL != file && EOF == fclose(file)) {
			exception = [NSException exceptionWithName:@"IOException" 
												reason:NSLocalizedStringFromTable(@"Unable to close the output file.", @"Exceptions", @"")
											  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			NSLog(@"%@", exception);
		}		

		free(bufferList.mBuffers[0].mData);
	}

	[[self delegate] setEndTime:[NSDate date]];
	[[self delegate] setCompleted:YES];	
}

- (NSString *) settingsString
{
	NSString *bitrateString;
	NSString *qualityString;
		
	switch(lame_get_VBR(_gfp)) {
		case vbr_mt:
		case vbr_rh:
		case vbr_mtrh:
//			appendix = "ca. ";
			bitrateString = [NSString stringWithFormat:@"VBR(q=%i)", lame_get_VBR_q(_gfp)];
			break;
		case vbr_abr:
			bitrateString = [NSString stringWithFormat:@"average %d kbps", lame_get_VBR_mean_bitrate_kbps(_gfp)];
			break;
		default:
			bitrateString = [NSString stringWithFormat:@"%3d kbps", lame_get_brate(_gfp)];
			break;
	}
	
//			0.1 * (int) (10. * lame_get_compression_ratio(_gfp) + 0.5),

	qualityString = [NSString stringWithFormat:@"qval=%i", lame_get_quality(_gfp)];
	
	return [NSString stringWithFormat:@"LAME settings: %@ %@", bitrateString, qualityString];
}

@end

@implementation MP3Encoder (Private)
- (void) parseSettings
{
	NSDictionary	*settings	= [[self delegate] encoderSettings];
	int				bitrate;	
	
	
	// Set encoding properties
	switch([[settings objectForKey:@"stereoMode"] intValue]) {
		case LAME_STEREO_MODE_DEFAULT:			lame_set_mode(_gfp, NOT_SET);			break;
		case LAME_STEREO_MODE_MONO:				lame_set_mode(_gfp, MONO);				break;
		case LAME_STEREO_MODE_STEREO:			lame_set_mode(_gfp, STEREO);			break;
		case LAME_STEREO_MODE_JOINT_STEREO:		lame_set_mode(_gfp, JOINT_STEREO);		break;
		default:								lame_set_mode(_gfp, NOT_SET);			break;
	}
	
	switch([[settings objectForKey:@"encodingEngineQuality"] intValue]) {
		case LAME_ENCODING_ENGINE_QUALITY_FAST:			lame_set_quality(_gfp, 7);		break;
		case LAME_ENCODING_ENGINE_QUALITY_STANDARD:		lame_set_quality(_gfp, 5);		break;
		case LAME_ENCODING_ENGINE_QUALITY_HIGH:			lame_set_quality(_gfp, 2);		break;
		default:										lame_set_quality(_gfp, 5);		break;
	}
	
	// Target is bitrate
	if(LAME_TARGET_BITRATE == [[settings objectForKey:@"target"] intValue]) {
		bitrate = sLAMEBitrates[[[settings objectForKey:@"bitrate"] intValue]];
		lame_set_brate(_gfp, bitrate);
		if([[settings objectForKey:@"useConstantBitrate"] boolValue]) {
			lame_set_VBR(_gfp, vbr_off);
		}
		else {
			lame_set_VBR(_gfp, vbr_default);
			lame_set_VBR_min_bitrate_kbps(_gfp, bitrate);
		}
	}
	// Target is quality
	else if(LAME_TARGET_QUALITY == [[settings objectForKey:@"target"] intValue]) {
		lame_set_VBR(_gfp, LAME_VARIABLE_BITRATE_MODE_FAST == [[settings objectForKey:@"variableBitrateMode"] intValue] ? vbr_mtrh : vbr_rh);
		lame_set_VBR_q(_gfp, (100 - [[settings objectForKey:@"VBRQuality"] intValue]) / 10);
	}
	else {
		@throw [NSException exceptionWithName:@"NSInternalInconsistencyException" reason:@"Unrecognized LAME target" userInfo:nil];
	}
	
	if([[settings objectForKey:@"calculateReplayGain"] boolValue]) {
		lame_set_findReplayGain(_gfp, 1);
	}
}

- (void) encodeChunk:(const AudioBufferList *)chunk frameCount:(UInt32)frameCount;
{
	unsigned char	*buffer					= NULL;
	unsigned		bufferLen				= 0;
	
	void			**channelBuffers		= NULL;
	short			**channelBuffers16		= NULL;
	long			**channelBuffers32		= NULL;
	
	int8_t			*buffer8				= NULL;
	int16_t			*buffer16				= NULL;
	int32_t			*buffer32				= NULL;
	
	int32_t			constructedSample;
	
	int				result;
	size_t			numWritten;
	
	unsigned		wideSample;
	unsigned		sample, channel;
	
	@try {
		// Allocate the MP3 buffer using LAME guide for size
		bufferLen	= 1.25 * (chunk->mBuffers[0].mNumberChannels * frameCount) + 7200;
		buffer		= (unsigned char *) calloc(bufferLen, sizeof(unsigned char));
		NSAssert(NULL != buffer, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));
		
		// Allocate channel buffers for sample de-interleaving
		channelBuffers = calloc(chunk->mBuffers[0].mNumberChannels, sizeof(void *));
		NSAssert(NULL != channelBuffers, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));
		
		// Initialize each channel buffer to zero
		for(channel = 0; channel < chunk->mBuffers[0].mNumberChannels; ++channel) {
			channelBuffers[channel] = NULL;
		}

		unsigned long max_long_value_for_lame = 1UL << (8 * sizeof(long) - 1);

		// Split PCM data into channels and convert to appropriate sample size for LAME
		switch(_sourceBitsPerChannel) {
			
			case 8:				
				channelBuffers16 = (short **)channelBuffers;
				
				for(channel = 0; channel < chunk->mBuffers[0].mNumberChannels; ++channel) {
					channelBuffers16[channel] = calloc(frameCount, sizeof(short));
					NSAssert(NULL != channelBuffers16[channel], NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));
				}
					
				buffer8 = chunk->mBuffers[0].mData;
				for(wideSample = sample = 0; wideSample < frameCount; ++wideSample) {
					for(channel = 0; channel < chunk->mBuffers[0].mNumberChannels; ++channel, ++sample) {
						// Rescale values to short
						channelBuffers16[channel][wideSample] = (short)((buffer8[sample] / 128.f) * 32768);
					}
				}
					
				result = lame_encode_buffer(_gfp, channelBuffers16[0], channelBuffers16[1], frameCount, buffer, bufferLen);
				
				break;
				
			case 16:
				channelBuffers16 = (short **)channelBuffers;
				
				for(channel = 0; channel < chunk->mBuffers[0].mNumberChannels; ++channel) {
					channelBuffers16[channel] = calloc(frameCount, sizeof(short));
					NSAssert(NULL != channelBuffers16[channel], NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));
				}
					
				buffer16 = chunk->mBuffers[0].mData;
				for(wideSample = sample = 0; wideSample < frameCount; ++wideSample) {
					for(channel = 0; channel < chunk->mBuffers[0].mNumberChannels; ++channel, ++sample) {
						channelBuffers16[channel][wideSample] = (short)OSSwapBigToHostInt16(buffer16[sample]);
					}
				}
					
				result = lame_encode_buffer(_gfp, channelBuffers16[0], channelBuffers16[1], frameCount, buffer, bufferLen);
				
				break;
				
			case 24:
				channelBuffers32 = (long **)channelBuffers;
				
				for(channel = 0; channel < chunk->mBuffers[0].mNumberChannels; ++channel) {
					channelBuffers32[channel] = calloc(frameCount, sizeof(long));
					NSAssert(NULL != channelBuffers32[channel], NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));
				}

				// Packed 24-bit data is 3 bytes, while unpacked is 24 bits in an int32_t
				buffer8 = chunk->mBuffers[0].mData;
				for(wideSample = sample = 0; wideSample < frameCount; ++wideSample) {
					for(channel = 0; channel < chunk->mBuffers[0].mNumberChannels; ++channel) {
						constructedSample = (int8_t)*buffer8++; constructedSample <<= 8;
						constructedSample |= (uint8_t)*buffer8++; constructedSample <<= 8;
						constructedSample |= (uint8_t)*buffer8++;

						// lame_encode_buffer_long2() expects the values to be scaled to fit the size of long, not a particular bit width
						// Specifically in the range 2^(8*sizeof(long)-1)
						// Which for 32-bit longs = 2147483648 (0x80000000), for 64-bit longs = 9223372036854775808 (0x8000000000000000)
						channelBuffers32[channel][wideSample] = (long)((constructedSample / 8388608.f) * max_long_value_for_lame);
					}
				}
					
				result = lame_encode_buffer_long2(_gfp, channelBuffers32[0], channelBuffers32[1], frameCount, buffer, bufferLen);
				
				break;
				
			case 32:
				channelBuffers32 = (long **)channelBuffers;
				
				for(channel = 0; channel < chunk->mBuffers[0].mNumberChannels; ++channel) {
					channelBuffers32[channel] = calloc(frameCount, sizeof(long));
					NSAssert(NULL != channelBuffers32[channel], NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));
				}

				buffer32 = chunk->mBuffers[0].mData;
				for(wideSample = sample = 0; wideSample < frameCount; ++wideSample) {
					for(channel = 0; channel < chunk->mBuffers[0].mNumberChannels; ++channel, ++sample) {
						// See comment above about expected scaling for lame_encode_buffer_long2()
						channelBuffers32[channel][wideSample] = (long)((OSSwapBigToHostInt32(buffer32[sample]) / 2147483648.f) * max_long_value_for_lame);
					}
				}
					
				result = lame_encode_buffer_long2(_gfp, channelBuffers32[0], channelBuffers32[1], frameCount, buffer, bufferLen);
				
				break;
				
			default:
				@throw [NSException exceptionWithName:@"IllegalInputException" reason:@"Sample size not supported" userInfo:nil]; 
				break;
		}
		
		NSAssert(0 <= result, NSLocalizedStringFromTable(@"LAME encoding error.", @"Exceptions", @""));
		
		numWritten = fwrite(buffer, sizeof(unsigned char), result, _out);
		NSAssert(numWritten == result, NSLocalizedStringFromTable(@"Unable to write to the output file.", @"Exceptions", @""));
	}
	
	@finally {
		for(channel = 0; channel < chunk->mBuffers[0].mNumberChannels; ++channel) {
			free(channelBuffers[channel]);
		}
		free(channelBuffers);
		
		free(buffer);
	}
}

- (void) finishEncode
{
	unsigned char	*buf;
	int				bufSize;
	
	int				result;
	size_t			numWritten;
	
	@try {
		buf = NULL;
		
		// Allocate the MP3 buffer using LAME guide for size
		bufSize		= 7200;
		buf			= (unsigned char *) calloc(bufSize, sizeof(unsigned char));
		NSAssert(NULL != buf, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));
		
		// Flush the mp3 buffer
		result = lame_encode_flush(_gfp, buf, bufSize);
		NSAssert(-1 != result, NSLocalizedStringFromTable(@"LAME was unable to flush the buffers.", @"Exceptions", @""));
		
		// And write any frames it returns
		numWritten = fwrite(buf, sizeof(unsigned char), result, _out);
		NSAssert(numWritten == result, NSLocalizedStringFromTable(@"Unable to write to the output file.", @"Exceptions", @""));
	}
	
	@finally {
		free(buf);
	}
}

@end
