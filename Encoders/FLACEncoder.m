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

#import "FLACEncoder.h"

#include <CoreAudio/CoreAudioTypes.h>
#include <AudioToolbox/AudioFormat.h>
#include <AudioToolbox/AudioConverter.h>
#include <AudioToolbox/AudioFile.h>
#include <AudioToolbox/ExtendedAudioFile.h>

#import "MallocException.h"
#import "IOException.h"
#import "FLACException.h"
#import "StopException.h"
#import "CoreAudioException.h"

#import "UtilityFunctions.h"

@interface FLACEncoder (Private)
- (void)	parseSettings;
- (void)	encodeChunk:(const AudioBufferList *)chunk frameCount:(UInt32)frameCount;
@end

@implementation FLACEncoder

- (id) initWithFilename:(NSString *)filename
{	
	if((self = [super initWithFilename:filename])) {
		
		_flac					= NULL;
		_padding				= 4096;
		_exhaustiveModelSearch	= NO;
		_enableMidSide			= YES;
		_enableLooseMidSide		= NO;
		_QLPCoeffPrecision		= 0;
		_minPartitionOrder		= 0;
		_maxPartitionOrder		= 4;
		_maxLPCOrder			= 8;
		
		return self;	
	}
	
	return nil;
}

- (void) parseSettings
{
	NSDictionary *settings	= [[self delegate] userInfo];
	
	_exhaustiveModelSearch	= [[settings objectForKey:@"exhaustiveModelSearch"] boolValue];
	_enableMidSide			= [[settings objectForKey:@"enableMidSide"] boolValue];
	_enableLooseMidSide		= [[settings objectForKey:@"looseEnableMidSide"] boolValue];
	_QLPCoeffPrecision		= [[settings objectForKey:@"QLPCoeffPrecision"] intValue];
	_minPartitionOrder		= [[settings objectForKey:@"minPartitionOrder"] intValue];
	_maxPartitionOrder		= [[settings objectForKey:@"maxPartitionOrder"] intValue];
	_maxLPCOrder			= [[settings objectForKey:@"maxLPCOrder"] intValue];
	_padding				= [[settings objectForKey:@"padding"] unsignedIntValue];
}

- (oneway void) encodeToFile:(NSString *)filename
{
	NSDate							*startTime					= [NSDate date];
	unsigned long					iterations					= 0;
	AudioBufferList					bufferList;
	ssize_t							bufferLen					= 0;
	FLAC__StreamMetadata			padding;
	FLAC__StreamMetadata			*metadata [1];
	OSStatus						err;
	FSRef							ref;
	ExtAudioFileRef					extAudioFileRef				= NULL;
	AudioStreamBasicDescription		asbd;
	SInt64							totalFrames, framesToRead;
	UInt32							size, frameCount;
	
	
	// Parse the encoder settings
	[self parseSettings];

	// Tell our owner we are starting
	[_delegate setStartTime:startTime];	
	[_delegate setStarted];

	@try {
		bufferList.mBuffers[0].mData = NULL;
		
		// Open the input file
		err = FSPathMakeRef((const UInt8 *)[_inputFilename fileSystemRepresentation], &ref, NULL);
		if(noErr != err) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to locate the input file.", @"Exceptions", @"")
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:_inputFilename, [NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"filename", @"errorCode", @"errorString", nil]]];
		}

		err = ExtAudioFileOpen(&ref, &extAudioFileRef);
		if(noErr != err) {
			@throw [CoreAudioException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"ExtAudioFileOpen"]
												  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		// Get input file information
		size	= sizeof(asbd);
		err		= ExtAudioFileGetProperty(extAudioFileRef, kExtAudioFileProperty_FileDataFormat, &size, &asbd);
		if(err != noErr) {
			@throw [CoreAudioException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"ExtAudioFileGetProperty"]
												  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		[self setInputASBD:asbd];

		size	= sizeof(totalFrames);
		err		= ExtAudioFileGetProperty(extAudioFileRef, kExtAudioFileProperty_FileLengthFrames, &size, &totalFrames);
		if(err != noErr) {
			@throw [CoreAudioException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"ExtAudioFileGetProperty"]
												  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		framesToRead = totalFrames;
		
		// Set up the AudioBufferList
		bufferList.mNumberBuffers					= 1;
		bufferList.mBuffers[0].mNumberChannels		= [self channelsPerFrame];

		// Allocate the buffer that will hold the interleaved audio data
		bufferLen									= 1024;
		switch([self bitsPerChannel]) {
			
			case 8:				
			case 24:
				bufferList.mBuffers[0].mData			= calloc(bufferLen, sizeof(int8_t));
				bufferList.mBuffers[0].mDataByteSize	= bufferLen * sizeof(int8_t);
				break;
				
			case 16:
				bufferList.mBuffers[0].mData			= calloc(bufferLen, sizeof(int16_t));
				bufferList.mBuffers[0].mDataByteSize	= bufferLen * sizeof(int16_t);
				break;
				
			case 32:
				bufferList.mBuffers[0].mData			= calloc(bufferLen, sizeof(int32_t));
				bufferList.mBuffers[0].mDataByteSize	= bufferLen * sizeof(int32_t);
				break;
				
			default:
				@throw [NSException exceptionWithName:@"IllegalInputException" reason:@"Sample size not supported" userInfo:nil]; 
				break;				
		}
		
		if(NULL == bufferList.mBuffers[0].mData) {
			@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @"") 
											   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		// Create the FLAC encoder
		_flac = FLAC__file_encoder_new();
		if(NULL == _flac) {
			@throw [FLACException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to create the FLAC encoder.", @"Exceptions", @"") userInfo:nil];
		}

		// Setup FLAC encoder
		
		// Input information
		if(NO == FLAC__file_encoder_set_sample_rate(_flac, [self sampleRate])) {
			@throw [FLACException exceptionWithReason:[NSString stringWithCString:FLAC__FileEncoderStateString[FLAC__file_encoder_get_state(_flac)] encoding:NSASCIIStringEncoding] userInfo:nil];
		}
		if(NO == FLAC__file_encoder_set_bits_per_sample(_flac, [self bitsPerChannel])) {
			@throw [FLACException exceptionWithReason:[NSString stringWithCString:FLAC__FileEncoderStateString[FLAC__file_encoder_get_state(_flac)] encoding:NSASCIIStringEncoding] userInfo:nil];
		}
		if(NO == FLAC__file_encoder_set_channels(_flac, [self channelsPerFrame])) {
			@throw [FLACException exceptionWithReason:[NSString stringWithCString:FLAC__FileEncoderStateString[FLAC__file_encoder_get_state(_flac)] encoding:NSASCIIStringEncoding] userInfo:nil];
		}
			
		// Encoder parameters
		if(NO == FLAC__file_encoder_set_do_exhaustive_model_search(_flac, _exhaustiveModelSearch)) {
			@throw [FLACException exceptionWithReason:[NSString stringWithCString:FLAC__FileEncoderStateString[FLAC__file_encoder_get_state(_flac)] encoding:NSASCIIStringEncoding] userInfo:nil];
		}
		if(NO == FLAC__file_encoder_set_do_mid_side_stereo(_flac, _enableMidSide)) {
			@throw [FLACException exceptionWithReason:[NSString stringWithCString:FLAC__FileEncoderStateString[FLAC__file_encoder_get_state(_flac)] encoding:NSASCIIStringEncoding] userInfo:nil];
		}
		if(NO == FLAC__file_encoder_set_loose_mid_side_stereo(_flac, _enableLooseMidSide)) {
			@throw [FLACException exceptionWithReason:[NSString stringWithCString:FLAC__FileEncoderStateString[FLAC__file_encoder_get_state(_flac)] encoding:NSASCIIStringEncoding] userInfo:nil];
		}
		if(NO == FLAC__file_encoder_set_qlp_coeff_precision(_flac, _QLPCoeffPrecision)) {
			@throw [FLACException exceptionWithReason:[NSString stringWithCString:FLAC__FileEncoderStateString[FLAC__file_encoder_get_state(_flac)] encoding:NSASCIIStringEncoding] userInfo:nil];
		}
		if(NO == FLAC__file_encoder_set_min_residual_partition_order(_flac, _minPartitionOrder)) {
			@throw [FLACException exceptionWithReason:[NSString stringWithCString:FLAC__FileEncoderStateString[FLAC__file_encoder_get_state(_flac)] encoding:NSASCIIStringEncoding] userInfo:nil];
		}
		if(NO == FLAC__file_encoder_set_max_residual_partition_order(_flac, _maxPartitionOrder)) {
			@throw [FLACException exceptionWithReason:[NSString stringWithCString:FLAC__FileEncoderStateString[FLAC__file_encoder_get_state(_flac)] encoding:NSASCIIStringEncoding] userInfo:nil];
		}
		if(NO == FLAC__file_encoder_set_max_lpc_order(_flac, _maxLPCOrder)) {
			@throw [FLACException exceptionWithReason:[NSString stringWithCString:FLAC__FileEncoderStateString[FLAC__file_encoder_get_state(_flac)] encoding:NSASCIIStringEncoding] userInfo:nil];
		}

		// Create the padding metadata block if desired
		if(0 < _padding) {
			padding.type		= FLAC__METADATA_TYPE_PADDING;
			padding.is_last		= NO;
			padding.length		= _padding;
			metadata[0]			= &padding;
			
			if(NO == FLAC__file_encoder_set_metadata(_flac, metadata, 1)) {
				@throw [FLACException exceptionWithReason:[NSString stringWithCString:FLAC__FileEncoderStateString[FLAC__file_encoder_get_state(_flac)] encoding:NSASCIIStringEncoding] userInfo:nil];
			}
		}
		
		// Initialize the FLAC encoder
		if(NO == FLAC__file_encoder_set_total_samples_estimate(_flac, totalFrames)) {
			@throw [FLACException exceptionWithReason:[NSString stringWithCString:FLAC__FileEncoderStateString[FLAC__file_encoder_get_state(_flac)] encoding:NSASCIIStringEncoding] userInfo:nil];
		}
		if(NO == FLAC__file_encoder_set_filename(_flac, [filename UTF8String])) {
			@throw [FLACException exceptionWithReason:[NSString stringWithCString:FLAC__FileEncoderStateString[FLAC__file_encoder_get_state(_flac)] encoding:NSASCIIStringEncoding] userInfo:nil];
		}
		if(FLAC__FILE_ENCODER_OK != FLAC__file_encoder_init(_flac)) {
			@throw [FLACException exceptionWithReason:[NSString stringWithCString:FLAC__FileEncoderStateString[FLAC__file_encoder_get_state(_flac)] encoding:NSASCIIStringEncoding] userInfo:nil];
		}		

		// Iteratively get the PCM data and encode it
		for(;;) {
			
			// Read a chunk of PCM input
			frameCount	= bufferList.mBuffers[0].mDataByteSize / [self bytesPerFrame];
			err			= ExtAudioFileRead(extAudioFileRef, &frameCount, &bufferList);
			if(err != noErr) {
				@throw [CoreAudioException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"ExtAudioFileRead"]
													  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}
			
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
				if([_delegate shouldStop]) {
					@throw [StopException exceptionWithReason:@"Stop requested by user" userInfo:nil];
				}
				
				// Update UI
				double percentComplete = ((double)(totalFrames - framesToRead)/(double) totalFrames) * 100.0;
				NSTimeInterval interval = -1.0 * [startTime timeIntervalSinceNow];
				unsigned secondsRemaining = (unsigned) (interval / ((double)(totalFrames - framesToRead)/(double) totalFrames) - interval);
				NSString *timeRemaining = [NSString stringWithFormat:@"%i:%02i", secondsRemaining / 60, secondsRemaining % 60];
				
				[_delegate updateProgress:percentComplete timeRemaining:timeRemaining];
			}
			
			++iterations;
		}
		
		// Finish up the encoding process
		FLAC__file_encoder_finish(_flac);
	}
	
	
	@catch(StopException *exception) {
		[_delegate setStopped];
	}
	
	@catch(NSException *exception) {
		[_delegate setException:exception];
		[_delegate setStopped];
	}
	
	@finally {
		NSException *exception;

		if(NULL != _flac) {
			FLAC__file_encoder_delete(_flac);
		}

		// Close the input file
		err = ExtAudioFileDispose(extAudioFileRef);
		if(noErr != err) {
			exception = [CoreAudioException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"ExtAudioFileDispose"]
													   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			NSLog(@"%@", exception);
		}
				
		free(bufferList.mBuffers[0].mData);
	}
	
	[_delegate setEndTime:[NSDate date]];
	[_delegate setCompleted];	
}

- (void) encodeChunk:(const AudioBufferList *)chunk frameCount:(UInt32)frameCount
{
	FLAC__bool		flacResult;
	
	int32_t			**buffer				= NULL;
	
	int8_t			*buffer8				= NULL;
	int16_t			*buffer16				= NULL;
	int32_t			*buffer32				= NULL;
	
	int8_t			byteOne, byteTwo, byteThree;
	int32_t			constructedSample;
	
	unsigned		wideSample;
	unsigned		sample, channel;
	
	@try {
		// Allocate the FLAC buffer
		buffer = calloc(chunk->mBuffers[0].mNumberChannels, sizeof(int32_t *));
		if(NULL == buffer) {
			@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @"") 
											   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		// Initialize each channel buffer to zero
		for(channel = 0; channel < chunk->mBuffers[0].mNumberChannels; ++channel) {
			buffer[channel] = NULL;
		}
		
		// Allocate channel buffers
		for(channel = 0; channel < chunk->mBuffers[0].mNumberChannels; ++channel) {
			buffer[channel] = calloc(frameCount, sizeof(int32_t));
			if(NULL == buffer[channel]) {
				@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @"") 
												   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}
		}
		
		// Split PCM data into channels and convert to 32-bit sample size for FLAC
		switch([self bitsPerChannel]) {

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
					for(channel = 0; channel < chunk->mBuffers[0].mNumberChannels; ++channel, ++sample) {						
						byteOne				= buffer8[sample];
						byteTwo				= buffer8[++sample];
						byteThree			= buffer8[++sample];
						constructedSample	= ((byteOne << 16) & 0xFF0000) | ((byteTwo << 8) & 0xFF00) | (byteThree & 0xFF);						

						buffer[channel][wideSample] = (int32_t)OSSwapBigToHostInt32(constructedSample);
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
		flacResult = FLAC__file_encoder_process(_flac, (const FLAC__int32 * const *)buffer, frameCount);
		
		if(NO == flacResult) {
			@throw [FLACException exceptionWithReason:[NSString stringWithCString:FLAC__FileEncoderStateString[FLAC__file_encoder_get_state(_flac)] encoding:NSASCIIStringEncoding] userInfo:nil];
		}
	}
		
	@finally {
		for(channel = 0; channel < chunk->mBuffers[0].mNumberChannels; ++channel) {
			free(buffer[channel]);
		}
		free(buffer);
	}
}	

- (NSString *) settings
{
	return [NSString stringWithFormat:@"FLAC settings: exhaustiveModelSearch:%i midSideStereo:%i looseMidSideStereo:%i QLPCoeffPrecision:%i, minResidualPartitionOrder:%i, maxResidualPartitionOrder:%i, maxLPCOrder:%i", 
		_exhaustiveModelSearch, _enableMidSide, _enableLooseMidSide, _QLPCoeffPrecision, _minPartitionOrder, _maxPartitionOrder, _maxLPCOrder];
}

@end
