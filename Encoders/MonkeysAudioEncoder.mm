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

#import "MonkeysAudioEncoder.h"

#include <mac/All.h>
#include <mac/MACLib.h>
#include <mac/APECompress.h>
#include <mac/CharacterHelper.h>

#include <CoreAudio/CoreAudioTypes.h>
#include <AudioToolbox/AudioFormat.h>
#include <AudioToolbox/AudioConverter.h>
#include <AudioToolbox/AudioFile.h>
#include <AudioToolbox/ExtendedAudioFile.h>

#import "Decoder.h"
#import "RegionDecoder.h"

#import "StopException.h"

#import "UtilityFunctions.h"

@interface MonkeysAudioEncoder (Private)
- (void)	parseSettings;
- (void)	compressChunk:(const AudioBufferList *)chunk frameCount:(UInt32)frameCount;
@end

@implementation MonkeysAudioEncoder

- (id) init
{	
	if((self = [super init])) {
		_compressionLevel	= COMPRESSION_LEVEL_NORMAL;
	}
	
	return self;
}

- (oneway void) encodeToFile:(NSString *)filename
{
	NSDate							*startTime					= [NSDate date];
	unsigned long					iterations					= 0;
	AudioBufferList					bufferList;
	ssize_t							bufferLen					= 0;
	UInt32							bufferByteSize				= 0;
	APE::WAVEFORMATEX				formatDesc;
	APE::str_utfn					*chars						= NULL;
	int								result;
	SInt64							totalFrames, framesToRead;
	UInt32							frameCount;
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
		
		_sourceBitsPerChannel	= [decoder pcmFormat].mBitsPerChannel;
		_sourceBytesPerFrame	= [decoder pcmFormat].mBytesPerFrame;
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

		// Create the MAC compressor
		_compressor = CreateIAPECompress();
		NSAssert(NULL != _compressor, NSLocalizedStringFromTable(@"Unable to create the Monkey's Audio compressor.", @"Exceptions", @""));
						
		// Setup compressor
		chars = APE::CAPECharacterHelper::GetUTF16FromANSI([filename fileSystemRepresentation]);
		NSAssert(NULL != chars, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));
		
		result = FillWaveFormatEx(&formatDesc, (int)[decoder pcmFormat].mSampleRate, [decoder pcmFormat].mBitsPerChannel, [decoder pcmFormat].mChannelsPerFrame);
		NSAssert(ERROR_SUCCESS == result, NSLocalizedStringFromTable(@"Unable to initialize the Monkey's Audio compressor.", @"Exceptions", @""));
		
		// Start the compressor
		result = _compressor->Start(chars, &formatDesc, totalFrames * [decoder pcmFormat].mBytesPerFrame, _compressionLevel, NULL, 0);
		NSAssert(ERROR_SUCCESS == result, NSLocalizedStringFromTable(@"Unable to start the Monkey's Audio compressor.", @"Exceptions", @""));
		
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
			[self compressChunk:&bufferList frameCount:frameCount];
			
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
		
		// Finish up the compression process
		_compressor->Finish(NULL, 0, 0);
	}
	
	
	@catch(StopException *exception) {
		[[self delegate] setStopped:YES];
	}
	
	@catch(NSException *exception) {
		[[self delegate] setException:exception];
		[[self delegate] setStopped:YES];
	}
	
	@finally {
		if(NULL != _compressor) {
			delete _compressor;
		}
				
		free(bufferList.mBuffers[0].mData);
		free(chars);
	}	

	[[self delegate] setEndTime:[NSDate date]];
	[[self delegate] setCompleted:YES];	
}

- (NSString *) settingsString
{
	return [NSString stringWithFormat:@"MAC settings: compression level:%i", _compressionLevel];
}

@end

@implementation MonkeysAudioEncoder (Private)

- (void) parseSettings
{
	NSDictionary	*settings	= [[self delegate] encoderSettings];
	int				level		= 0;
	
	level = [[settings objectForKey:@"compressionLevel"] intValue];
	switch(level) {
		case MAC_COMPRESSION_LEVEL_FAST:		_compressionLevel = COMPRESSION_LEVEL_FAST;				break;
		case MAC_COMPRESSION_LEVEL_NORMAL:		_compressionLevel = COMPRESSION_LEVEL_NORMAL;			break;
		case MAC_COMPRESSION_LEVEL_HIGH:		_compressionLevel = COMPRESSION_LEVEL_HIGH;				break;
		case MAC_COMPRESSION_LEVEL_EXTRA_HIGH:	_compressionLevel = COMPRESSION_LEVEL_EXTRA_HIGH;		break;
		case MAC_COMPRESSION_LEVEL_INSANE:		_compressionLevel = COMPRESSION_LEVEL_INSANE;			break;
		default:								_compressionLevel = COMPRESSION_LEVEL_NORMAL;			break;
	}
}

- (void) compressChunk:(const AudioBufferList *)chunk frameCount:(UInt32)frameCount;
{
	//	uint8_t			*buffer8				= NULL;
	uint16_t		*buffer16				= NULL;
	uint32_t		*buffer32				= NULL;
	unsigned		wideSample;
	unsigned		sample, channel;
	APE::int64		result;
	
	// Convert MAC buffer to host endian byte order
	switch(_sourceBitsPerChannel) {
		
		case 8:
			/*			buffer8 = (uint8_t *)chunk->mBuffers[0].mData;
			for(wideSample = sample = 0; wideSample < frameCount; ++wideSample) {
				for(channel = 0; channel < chunk->mBuffers[0].mNumberChannels; ++channel, ++sample) {
					buffer8[sample] = buffer8[sample];
				}
			}*/
			break;
			
		case 16:
			buffer16 = (uint16_t *)chunk->mBuffers[0].mData;
			for(wideSample = sample = 0; wideSample < frameCount; ++wideSample) {
				for(channel = 0; channel < chunk->mBuffers[0].mNumberChannels; ++channel, ++sample) {
					buffer16[sample] = OSSwapBigToHostInt16(buffer16[sample]);
				}
			}
				break;
			
		case 24:
			/*			buffer8 = (uint8_t *)chunk->mBuffers[0].mData;
			for(wideSample = sample = 0; wideSample < frameCount; ++wideSample) {
				for(channel = 0; channel < chunk->mBuffers[0].mNumberChannels; ++channel, ++sample) {
					buffer8[sample] = buffer8[sample];
				}
			}*/
			break;
			
		case 32:
			buffer32 = (uint32_t *)chunk->mBuffers[0].mData;
			for(wideSample = sample = 0; wideSample < frameCount; ++wideSample) {
				for(channel = 0; channel < chunk->mBuffers[0].mNumberChannels; ++channel, ++sample) {
					buffer32[sample] = OSSwapBigToHostInt32(buffer32[sample]);
				}
			}
				break;
			
		default:
			@throw [NSException exceptionWithName:@"IllegalInputException" reason:@"Sample size not supported" userInfo:nil]; 
			break;				
	}
	
	// Compress the chunk
	result = _compressor->AddData((unsigned char *)chunk->mBuffers[0].mData, frameCount * _sourceBytesPerFrame);
	NSAssert(ERROR_SUCCESS == result, NSLocalizedStringFromTable(@"Monkey's Audio compressor error.", @"Exceptions", @""));
}	

@end
