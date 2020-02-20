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

#import "OggFLACEncoder.h"

#include <CoreAudio/CoreAudioTypes.h>
#include <AudioToolbox/AudioFormat.h>
#include <AudioToolbox/AudioConverter.h>
#include <AudioToolbox/AudioFile.h>
#include <AudioToolbox/ExtendedAudioFile.h>

#import "Decoder.h"
#import "RegionDecoder.h"

#import "StopException.h"

#import "UtilityFunctions.h"

@interface OggFLACEncoder (Private)
- (void)	parseSettings;
- (void)	encodeChunk:(const AudioBufferList *)chunk frameCount:(UInt32)frameCount;
@end

@implementation OggFLACEncoder

- (id) init
{
	if((self = [super init])) {
		_padding				= 8192;
		_exhaustiveModelSearch	= NO;
		_enableMidSide			= YES;
		_enableLooseMidSide		= NO;
		_QLPCoeffPrecision		= 0;
		_minPartitionOrder		= 0;
		_maxPartitionOrder		= 4;
		_maxLPCOrder			= 8;
	}
	
	return self;
}

- (oneway void) encodeToFile:(NSString *) filename
{
	NSDate							*startTime					= [NSDate date];
	unsigned long					iterations					= 0;
	AudioBufferList					bufferList;
	ssize_t							bufferLen					= 0;
	UInt32							bufferByteSize				= 0;
	FLAC__bool						result;
	FLAC__StreamEncoderInitStatus	encoderStatus;
	FLAC__StreamMetadata			padding;
	FLAC__StreamMetadata			*metadata					[1];
	SInt64							totalFrames, framesToRead;
	UInt32							frameCount;
	double							percentComplete;
	NSTimeInterval					interval;
	unsigned						secondsRemaining;
	
	@try {
		bufferList.mBuffers[0].mData = NULL;

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
		
		_sourceBitsPerChannel = [decoder pcmFormat].mBitsPerChannel;

		// Tell our owner we are starting
		[[self delegate] setStartTime:startTime];	
		[[self delegate] setStarted:YES];
				
		// Parse the encoder settings
		[self parseSettings];
		
		totalFrames			= [decoder totalFrames];
		framesToRead		= totalFrames;
		
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
		
		// Create the Ogg FLAC encoder
		_flac = FLAC__stream_encoder_new();
		NSAssert(NULL != _flac, NSLocalizedStringFromTable(@"Unable to create the Ogg FLAC encoder.", @"Exceptions", @""));
		
		// Setup Ogg FLAC encoder

		// Input information
		result = FLAC__stream_encoder_set_sample_rate(_flac, [decoder pcmFormat].mSampleRate);
		NSAssert1(YES == result, @"FLAC__stream_encoder_set_sample_rate failed: %s", FLAC__stream_encoder_get_resolved_state_string(_flac));
		
		result = FLAC__stream_encoder_set_bits_per_sample(_flac, [decoder pcmFormat].mBitsPerChannel);
		NSAssert1(YES == result, @"FLAC__stream_encoder_set_bits_per_sample failed: %s", FLAC__stream_encoder_get_resolved_state_string(_flac));
		
		result = FLAC__stream_encoder_set_channels(_flac, [decoder pcmFormat].mChannelsPerFrame);
		NSAssert1(YES == result, @"FLAC__stream_encoder_set_channels failed: %s", FLAC__stream_encoder_get_resolved_state_string(_flac));
		
		// Encoder parameters
		result = FLAC__stream_encoder_set_do_exhaustive_model_search(_flac, _exhaustiveModelSearch);
		NSAssert1(YES == result, @"FLAC__stream_encoder_set_do_exhaustive_model_search failed: %s", FLAC__stream_encoder_get_resolved_state_string(_flac));
		
		result = FLAC__stream_encoder_set_do_mid_side_stereo(_flac, _enableMidSide);
		NSAssert1(YES == result, @"FLAC__stream_encoder_set_do_mid_side_stereo failed: %s", FLAC__stream_encoder_get_resolved_state_string(_flac));
		
		result = FLAC__stream_encoder_set_loose_mid_side_stereo(_flac, _enableLooseMidSide);
		NSAssert1(YES == result, @"FLAC__stream_encoder_set_loose_mid_side_stereo failed: %s", FLAC__stream_encoder_get_resolved_state_string(_flac));
		
		result = FLAC__stream_encoder_set_qlp_coeff_precision(_flac, _QLPCoeffPrecision);
		NSAssert1(YES == result, @"FLAC__stream_encoder_set_qlp_coeff_precision failed: %s", FLAC__stream_encoder_get_resolved_state_string(_flac));
		
		result = FLAC__stream_encoder_set_min_residual_partition_order(_flac, _minPartitionOrder);
		NSAssert1(YES == result, @"FLAC__stream_encoder_set_min_residual_partition_order failed: %s", FLAC__stream_encoder_get_resolved_state_string(_flac));
		
		result = FLAC__stream_encoder_set_max_residual_partition_order(_flac, _maxPartitionOrder);
		NSAssert1(YES == result, @"FLAC__stream_encoder_set_max_residual_partition_order failed: %s", FLAC__stream_encoder_get_resolved_state_string(_flac));
		
		result = FLAC__stream_encoder_set_max_lpc_order(_flac, _maxLPCOrder);
		NSAssert1(YES == result, @"FLAC__stream_encoder_set_max_lpc_order failed: %s", FLAC__stream_encoder_get_resolved_state_string(_flac));
		

		// Create the padding metadata block if desired
		if(0 < _padding) {
			padding.type		= FLAC__METADATA_TYPE_PADDING;
			padding.is_last		= NO;
			padding.length		= _padding;
			metadata[0]			= &padding;
			
			result = FLAC__stream_encoder_set_metadata(_flac, metadata, 1);
			NSAssert1(YES == result, @"FLAC__stream_encoder_set_metadata failed: %s", FLAC__stream_encoder_get_resolved_state_string(_flac));
		}

		// Initialize the Ogg FLAC encoder
		result = FLAC__stream_encoder_set_total_samples_estimate(_flac, totalFrames);
		NSAssert1(YES == result, @"FLAC__stream_encoder_set_total_samples_estimate failed: %s", FLAC__stream_encoder_get_resolved_state_string(_flac));
		
		result = FLAC__stream_encoder_set_ogg_serial_number(_flac, time(NULL));
		NSAssert1(YES == result, @"FLAC__stream_encoder_set_ogg_serial_number failed: %s", FLAC__stream_encoder_get_resolved_state_string(_flac));
		
		encoderStatus = FLAC__stream_encoder_init_ogg_file(_flac, 
														   [filename fileSystemRepresentation],
														   NULL, 
														   self);
		NSAssert1(FLAC__STREAM_ENCODER_INIT_STATUS_OK == encoderStatus, @"FLAC__stream_encoder_init_ogg_file failed: %s", FLAC__StreamEncoderInitStatusString[encoderStatus]);

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
		
		// Finish up the encoding process
		FLAC__stream_encoder_finish(_flac);		
	}
	
	@catch(StopException *exception) {
		[[self delegate] setStopped:YES];
	}
	
	@catch(NSException *exception) {
		[[self delegate] setException:exception];
		[[self delegate] setStopped:YES];
	}
	
	@finally {
		if(NULL != _flac) {
			FLAC__stream_encoder_delete(_flac);
		}
		
		free(bufferList.mBuffers[0].mData);
	}	

	[[self delegate] setEndTime:[NSDate date]];
	[[self delegate] setCompleted:YES];
}

- (NSString *) settingsString
{
	return [NSString stringWithFormat:@"FLAC settings: exhaustiveModelSearch:%i midSideStereo:%i looseMidSideStereo:%i QLPCoeffPrecision:%i, minResidualPartitionOrder:%i, maxResidualPartitionOrder:%i, maxLPCOrder:%i", 
		_exhaustiveModelSearch, _enableMidSide, _enableLooseMidSide, _QLPCoeffPrecision, _minPartitionOrder, _maxPartitionOrder, _maxLPCOrder];
}

@end

@implementation OggFLACEncoder (Private)

- (void) parseSettings
{
	NSDictionary *settings	= [[self delegate] encoderSettings];
	
	_exhaustiveModelSearch	= [[settings objectForKey:@"exhaustiveModelSearch"] boolValue];
	_enableMidSide			= [[settings objectForKey:@"enableMidSide"] boolValue];
	_enableLooseMidSide		= [[settings objectForKey:@"looseEnableMidSide"] boolValue];
	_QLPCoeffPrecision		= [[settings objectForKey:@"QLPCoeffPrecision"] intValue];
	_minPartitionOrder		= [[settings objectForKey:@"minPartitionOrder"] intValue];
	_maxPartitionOrder		= [[settings objectForKey:@"maxPartitionOrder"] intValue];
	_maxLPCOrder			= [[settings objectForKey:@"maxLPCOrder"] intValue];
	_padding				= [[settings objectForKey:@"padding"] unsignedIntValue];
}

- (void) encodeChunk:(const AudioBufferList *)chunk frameCount:(UInt32)frameCount
{
	FLAC__bool		result;
	
	int32_t			**buffer				= NULL;
	
	int8_t			*buffer8				= NULL;
	int16_t			*buffer16				= NULL;
	int32_t			*buffer32				= NULL;
	
	int32_t			constructedSample;
	
	unsigned		wideSample;
	unsigned		sample, channel;
	
	@try {
		// Allocate the FLAC buffer
		buffer = calloc(chunk->mBuffers[0].mNumberChannels, sizeof(int32_t *));
		NSAssert(NULL != buffer, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));
		
		// Initialize each channel buffer to zero
		for(channel = 0; channel < chunk->mBuffers[0].mNumberChannels; ++channel) {
			buffer[channel] = NULL;
		}
		
		// Allocate channel buffers
		for(channel = 0; channel < chunk->mBuffers[0].mNumberChannels; ++channel) {
			buffer[channel] = calloc(frameCount, sizeof(int32_t));
			NSAssert(NULL != buffer[channel], NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));
		}
		
		// Split PCM data into channels and convert to 32-bit sample size for FLAC
		switch(_sourceBitsPerChannel) {
			
			case 8:
				buffer8 = chunk->mBuffers[0].mData;
				for(wideSample = sample = 0; wideSample < frameCount; ++wideSample) {
					for(channel = 0; channel < chunk->mBuffers[0].mNumberChannels; ++channel, ++sample) {
						buffer[channel][wideSample] = (int32_t)buffer8[sample];
					}
				}
				break;
				
			case 16:
				buffer16 = chunk->mBuffers[0].mData;
				for(wideSample = sample = 0; wideSample < frameCount; ++wideSample) {
					for(channel = 0; channel < chunk->mBuffers[0].mNumberChannels; ++channel, ++sample) {
						buffer[channel][wideSample] = (int32_t)(int16_t)OSSwapBigToHostInt16(buffer16[sample]);
					}
				}
				break;
				
			case 24:
				buffer8 = chunk->mBuffers[0].mData;
				for(wideSample = sample = 0; wideSample < frameCount; ++wideSample) {
					for(channel = 0; channel < chunk->mBuffers[0].mNumberChannels; ++channel) {						
						constructedSample = (int8_t)*buffer8++; constructedSample <<= 8;
						constructedSample |= (uint8_t)*buffer8++; constructedSample <<= 8;
						constructedSample |= (uint8_t)*buffer8++;
						
						buffer[channel][wideSample] = constructedSample;
					}
				}
				break;

			case 32:
				buffer32 = chunk->mBuffers[0].mData;
				for(wideSample = sample = 0; wideSample < frameCount; ++wideSample) {
					for(channel = 0; channel < chunk->mBuffers[0].mNumberChannels; ++channel, ++sample) {
						buffer[channel][wideSample] = (int32_t)OSSwapBigToHostInt32(buffer32[sample]);
					}
				}
				break;
				
			default:
				@throw [NSException exceptionWithName:@"IllegalInputException" reason:@"Sample size not supported" userInfo:nil]; 
				break;
		}
		
		// Encode the chunk
		result = FLAC__stream_encoder_process(_flac, (const FLAC__int32 * const *)buffer, frameCount);
		NSAssert1(YES == result, @"FLAC__stream_encoder_process failed: %s", FLAC__stream_encoder_get_resolved_state_string(_flac));
	}
	
	@finally {
		for(channel = 0; channel < chunk->mBuffers[0].mNumberChannels; ++channel) {
			free(buffer[channel]);
		}
		free(buffer);
	}
	
}	

@end
