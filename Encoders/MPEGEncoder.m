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

#import "MPEGEncoder.h"

#include <CoreAudio/CoreAudioTypes.h>
#include <AudioToolbox/AudioFormat.h>
#include <AudioToolbox/AudioConverter.h>
#include <AudioToolbox/AudioFile.h>
#include <AudioToolbox/ExtendedAudioFile.h>
#include <AudioUnit/AudioCodec.h>

#include <LAME/lame.h>

#import "MallocException.h"
#import "IOException.h"
#import "LAMEException.h"
#import "StopException.h"
#import "MissingResourceException.h"
#import "CoreAudioException.h"

#import "UtilityFunctions.h"

#include <fcntl.h>		// open, write
#include <stdio.h>		// fopen, fclose
#include <sys/stat.h>	// stat

// Bitrates supported for 44.1 kHz audio
static int sLAMEBitrates [14] = { 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320 };

@interface MPEGEncoder (Private)
- (void)	parseSettings;
- (void)	encodeChunk:(const AudioBufferList *)chunk frameCount:(UInt32)frameCount;
- (void)	finishEncode;
@end

@implementation MPEGEncoder

- (id) initWithPCMFilename:(NSString *)inputFilename
{
	if((self = [super initWithPCMFilename:inputFilename])) {
		
		@try {
			// LAME setup
			_gfp	= NULL;
			_gfp	= lame_init();
			if(NULL == _gfp) {
				@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @"") 
									   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}
			
			// Write the Xing VBR tag
			lame_set_bWriteVbrTag(_gfp, 1);			
		}

		@catch(NSException *exception) {
			if(NULL != _gfp) {
				lame_close(_gfp);
			}
			
			@throw;
		}
				
		return self;
	}
	
	return nil;
}

- (void) parseSettings
{
	NSDictionary	*settings	= [[self delegate] userInfo];
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
	
	//lame_set_findReplayGain(_gfp, 1);			
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
	int								lameResult;
	AudioBufferList					bufferList;
	ssize_t							bufferLen						= 0;
	OSStatus						err;
	FSRef							ref;
	ExtAudioFileRef					extAudioFileRef					= NULL;
	AudioStreamBasicDescription		asbd;
	SInt64							totalFrames, framesToRead;
	UInt32							size, frameCount;
	unsigned long					iterations						= 0;


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

		if(1 != [self channelsPerFrame] && 2 != [self channelsPerFrame]) {
			@throw [LAMEException exceptionWithReason:NSLocalizedStringFromTable(@"LAME only supports one or two channel input.", @"Exceptions", @"") userInfo:nil];
		}

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
		
		// Initialize the LAME encoder
		lame_set_num_channels(_gfp, [self channelsPerFrame]);
		lame_set_in_samplerate(_gfp, [self sampleRate]);
		
		lameResult = lame_init_params(_gfp);
		if(-1 == lameResult) {
			@throw [LAMEException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to initialize the LAME encoder.", @"Exceptions", @"") userInfo:nil];
		}

		// Open the output file
		_out = open([filename fileSystemRepresentation], O_WRONLY | O_TRUNC, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH);
		if(-1 == _out) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to create the output file.", @"Exceptions", @"") 
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
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
		
		// Flush the last MP3 frames (maybe)
		[self finishEncode];
		
		// Close the output file
		if(-1 == close(_out)) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to close the output file.", @"Exceptions", @"") 
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		_out = -1;
		
		// Write the Xing VBR tag
		file = fopen([filename fileSystemRepresentation], "r+");
		if(NULL == file) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to open the output file.", @"Exceptions", @"") 
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		lame_mp3_tags_fid(_gfp, file);
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
		
		// Close the input file
		err = ExtAudioFileDispose(extAudioFileRef);
		if(noErr != err) {
			exception = [CoreAudioException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"ExtAudioFileDispose"]
													   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			NSLog(@"%@", exception);
		}
		
		// Close the output file if not already closed
		if(-1 != _out && -1 == close(_out)) {
			exception = [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to close the output file.", @"Exceptions", @"") 
												userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			NSLog(@"%@", exception);
		}

		// And close the other output file
		if(NULL != file && EOF == fclose(file)) {
			exception =  [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to close the output file.", @"Exceptions", @"")
												 userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			NSLog(@"%@", exception);
		}		

		free(bufferList.mBuffers[0].mData);
	}

	[_delegate setEndTime:[NSDate date]];
	[_delegate setCompleted];	
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

	int8_t			byteOne, byteTwo, byteThree;
	int32_t			constructedSample;
	
	int				lameResult;
	long			bytesWritten;

	unsigned		wideSample;
	unsigned		sample, channel;
	
	@try {
		// Allocate the MP3 buffer using LAME guide for size
		bufferLen	= 1.25 * (chunk->mBuffers[0].mNumberChannels * frameCount) + 7200;
		buffer		= (unsigned char *) calloc(bufferLen, sizeof(unsigned char));
		if(NULL == buffer) {
			@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @"") 
											   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
				
		// Allocate channel buffers for sample de-interleaving
		channelBuffers = calloc(chunk->mBuffers[0].mNumberChannels, sizeof(void *));
		if(NULL == channelBuffers) {
			@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @"") 
											   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		// Initialize each channel buffer to zero
		for(channel = 0; channel < chunk->mBuffers[0].mNumberChannels; ++channel) {
			channelBuffers[channel] = NULL;
		}
		
		// Split PCM data into channels and convert to appropriate sample size for LAME
		switch([self bitsPerChannel]) {
			
			case 8:				
				channelBuffers16 = (short **)channelBuffers;

				for(channel = 0; channel < chunk->mBuffers[0].mNumberChannels; ++channel) {
					channelBuffers16[channel] = calloc(frameCount, sizeof(short));
					if(NULL == channelBuffers16[channel]) {
						@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @"") 
														   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
					}
				}
				
				buffer8 = chunk->mBuffers[0].mData;
				for(wideSample = sample = 0; wideSample < frameCount; ++wideSample) {
					for(channel = 0; channel < chunk->mBuffers[0].mNumberChannels; ++channel, ++sample) {
						// Rescale values to short
						channelBuffers16[channel][wideSample] = (short)(((buffer8[sample] << 8) & 0xFF00) | (buffer8[sample] & 0xFF));
					}
				}

				lameResult = lame_encode_buffer(_gfp, channelBuffers16[0], channelBuffers16[1], frameCount, buffer, bufferLen);

				break;
				
			case 16:
				channelBuffers16 = (short **)channelBuffers;
				
				for(channel = 0; channel < chunk->mBuffers[0].mNumberChannels; ++channel) {
					channelBuffers16[channel] = calloc(frameCount, sizeof(short));
					if(NULL == channelBuffers16[channel]) {
						@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @"") 
														   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
					}
				}

				buffer16 = chunk->mBuffers[0].mData;
				for(wideSample = sample = 0; wideSample < frameCount; ++wideSample) {
					for(channel = 0; channel < chunk->mBuffers[0].mNumberChannels; ++channel, ++sample) {
						channelBuffers16[channel][wideSample] = (short)OSSwapBigToHostInt16(buffer16[sample]);
					}
				}
					
				lameResult = lame_encode_buffer(_gfp, channelBuffers16[0], channelBuffers16[1], frameCount, buffer, bufferLen);

				break;
				
			case 24:
				channelBuffers32 = (long **)channelBuffers;
				
				for(channel = 0; channel < chunk->mBuffers[0].mNumberChannels; ++channel) {
					channelBuffers32[channel] = calloc(frameCount, sizeof(long));
					if(NULL == channelBuffers32[channel]) {
						@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @"") 
														   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
					}
				}

				// Packed 24-bit data is 3 bytes, while unpacked is 24 bits in an int32_t
				buffer8 = chunk->mBuffers[0].mData;
				for(wideSample = sample = 0; wideSample < frameCount; ++wideSample) {
					for(channel = 0; channel < chunk->mBuffers[0].mNumberChannels; ++channel, ++sample) {
						// Reconstruct the original sample
						byteOne				= buffer8[sample];
						byteTwo				= buffer8[++sample];
						byteThree			= buffer8[++sample];
						constructedSample	= ((byteOne << 16) & 0xFF0000) | ((byteTwo << 8) & 0xFF00) | (byteThree & 0xFF);
						
						// Convert to 32-bit sample size
						channelBuffers32[channel][wideSample] = (long)OSSwapBigToHostInt32(((constructedSample << 8) & 0xFFFFFF00) | (constructedSample & 0xFF));
					}
				}
					
				lameResult = lame_encode_buffer_long2(_gfp, channelBuffers32[0], channelBuffers32[1], frameCount, buffer, bufferLen);
				
				break;

			case 32:
				channelBuffers32 = (long **)channelBuffers;
				
				for(channel = 0; channel < chunk->mBuffers[0].mNumberChannels; ++channel) {
					channelBuffers32[channel] = calloc(frameCount, sizeof(long));
					if(NULL == channelBuffers32[channel]) {
						@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @"") 
														   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
					}
				}

				buffer32 = chunk->mBuffers[0].mData;
				for(wideSample = sample = 0; wideSample < frameCount; ++wideSample) {
					for(channel = 0; channel < chunk->mBuffers[0].mNumberChannels; ++channel, ++sample) {
						channelBuffers32[channel][wideSample] = (long)OSSwapBigToHostInt32(buffer32[sample]);
					}
				}
				
				lameResult = lame_encode_buffer_long2(_gfp, channelBuffers32[0], channelBuffers32[1], frameCount, buffer, bufferLen);

				break;
				
			default:
				@throw [NSException exceptionWithName:@"IllegalInputException" reason:@"Sample size not supported" userInfo:nil]; 
				break;
		}
		
		if(0 > lameResult) {
			@throw [LAMEException exceptionWithReason:NSLocalizedStringFromTable(@"LAME encoding error.", @"Exceptions", @"") userInfo:nil];
		}
		
		bytesWritten = write(_out, buffer, lameResult);
		if(-1 == bytesWritten) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to write to the output file.", @"Exceptions", @"") 
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}		
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
	
	int				lameResult;
	ssize_t			bytesWritten;
		
	@try {
		buf = NULL;
		
		// Allocate the MP3 buffer using LAME guide for size
		bufSize		= 7200;
		buf			= (unsigned char *) calloc(bufSize, sizeof(unsigned char));
		if(NULL == buf) {
			@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @"") 
									   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		// Flush the mp3 buffer
		lameResult = lame_encode_flush(_gfp, buf, bufSize);
		if(-1 == lameResult) {
			@throw [LAMEException exceptionWithReason:NSLocalizedStringFromTable(@"LAME was unable to flush the buffers.", @"Exceptions", @"") userInfo:nil];
		}
		
		// And write any frames it returns
		bytesWritten = write(_out, buf, lameResult);
		if(-1 == bytesWritten) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to write to the output file.", @"Exceptions", @"") 
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
	}
		
	@finally {
		free(buf);
	}
}

- (NSString *) settings
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
