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

#import "MonkeysAudioEncoder.h"

#include <MAC/All.h>
#include <MAC/MACLib.h>
#include <MAC/APECompress.h>
#include <MAC/CharacterHelper.h>

#include <CoreAudio/CoreAudioTypes.h>
#include <AudioToolbox/AudioFormat.h>
#include <AudioToolbox/AudioConverter.h>
#include <AudioToolbox/AudioFile.h>
#include <AudioToolbox/ExtendedAudioFile.h>

#import "MallocException.h"
#import "IOException.h"
#import "StopException.h"
#import "CoreAudioException.h"
#import "MissingResourceException.h"

#import "UtilityFunctions.h"

@interface MonkeysAudioEncoder (Private)
- (void)	parseSettings;
- (void)	compressChunk:(const AudioBufferList *)chunk frameCount:(UInt32)frameCount;
@end

@implementation MonkeysAudioEncoder

- (id) initWithPCMFilename:(NSString *)inputFilename
{	
	if((self = [super initWithPCMFilename:inputFilename])) {

		_compressor			= NULL;
		_compressionLevel	= COMPRESSION_LEVEL_NORMAL;
				
		return self;	
	}
	
	return nil;
}

- (void) parseSettings
{
	NSDictionary	*settings	= [[self delegate] userInfo];
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

- (oneway void) encodeToFile:(NSString *)filename
{
	NSDate							*startTime					= [NSDate date];
	unsigned long					iterations					= 0;
	AudioBufferList					bufferList;
	ssize_t							bufferLen					= 0;
	WAVEFORMATEX					formatDesc;
	str_utf16						*chars						= NULL;
	int								result;
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
		
		[self setSampleRate:asbd.mSampleRate];
		[self setBitsPerChannel:asbd.mBitsPerChannel];
		[self setChannelsPerFrame:asbd.mChannelsPerFrame];
		
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
				bufferList.mBuffers[0].mData			= calloc(bufferLen, sizeof(int8_t));
				bufferList.mBuffers[0].mDataByteSize	= bufferLen * sizeof(int8_t);
				break;
				
			case 16:
				bufferList.mBuffers[0].mData			= calloc(bufferLen, sizeof(int16_t));
				bufferList.mBuffers[0].mDataByteSize	= bufferLen * sizeof(int16_t);
				break;
				
			case 24:
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
		
		// Create the MAC compressor
		_compressor = CreateIAPECompress();
		if(NULL == _compressor) {
			@throw [NSException exceptionWithName:@"MACException" reason:NSLocalizedStringFromTable(@"Unable to create the Monkey's Audio compressor.", @"Exceptions", @"") userInfo:nil];
		}
						
		// Setup compressor
		chars = GetUTF16FromANSI([filename fileSystemRepresentation]);
		if(NULL == chars) {
			@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @"") 
											   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		result = FillWaveFormatEx(&formatDesc, (int)[self sampleRate], [self bitsPerChannel], [self channelsPerFrame]);
		if(ERROR_SUCCESS != result) {
			@throw [NSException exceptionWithName:@"MACException" reason:NSLocalizedStringFromTable(@"Unable to initialize the Monkey's Audio compressor.", @"Exceptions", @"")
										 userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObject:[NSNumber numberWithInt:result]] forKeys:[NSArray arrayWithObject:@"errorCode"]]];
		}
		
		// Start the compressor
		result = _compressor->Start(chars, &formatDesc, totalFrames * [self bytesPerFrame], _compressionLevel, NULL, 0);
		if(ERROR_SUCCESS != result) {
			@throw [NSException exceptionWithName:@"MACException" reason:NSLocalizedStringFromTable(@"Unable to start the Monkey's Audio compressor.", @"Exceptions", @"")
										 userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObject:[NSNumber numberWithInt:result]] forKeys:[NSArray arrayWithObject:@"errorCode"]]];
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
			[self compressChunk:&bufferList frameCount:frameCount];
			
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
				unsigned int secondsRemaining = (unsigned) (interval / ((double)(totalFrames - framesToRead)/(double) totalFrames) - interval);
				NSString *timeRemaining = [NSString stringWithFormat:@"%i:%02i", secondsRemaining / 60, secondsRemaining % 60];
				
				[_delegate updateProgress:percentComplete timeRemaining:timeRemaining];
			}
			
			++iterations;
		}
		
		// Finish up the compression process
		_compressor->Finish(NULL, 0, 0);
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
		
		if(NULL != _compressor) {
			delete _compressor;
		}
		
		// Close the input file
		err = ExtAudioFileDispose(extAudioFileRef);
		if(noErr != err) {
			exception = [CoreAudioException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"ExtAudioFileDispose"]
													   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			NSLog(@"%@", exception);
		}
		
		free(bufferList.mBuffers[0].mData);
		free(chars);
	}
	
	[_delegate setEndTime:[NSDate date]];
	[_delegate setCompleted];	
}

- (void) compressChunk:(const AudioBufferList *)chunk frameCount:(UInt32)frameCount;
{
	uint8_t			*buffer8				= NULL;
	uint16_t		*buffer16				= NULL;
	uint32_t		*buffer32				= NULL;
	unsigned		wideSample;
	unsigned		sample, channel;
	int				result;
	
	// Convert MAC buffer to little endian byte order
	switch([self bitsPerChannel]) {
		
		case 8:
			buffer8 = (uint8_t *)chunk->mBuffers[0].mData;
			for(wideSample = sample = 0; wideSample < frameCount; ++wideSample) {
				for(channel = 0; channel < chunk->mBuffers[0].mNumberChannels; ++channel, ++sample) {
					buffer8[sample] = buffer8[sample];
				}
			}
			break;
			
		case 16:
			buffer16 = (uint16_t *)chunk->mBuffers[0].mData;
			for(wideSample = sample = 0; wideSample < frameCount; ++wideSample) {
				for(channel = 0; channel < chunk->mBuffers[0].mNumberChannels; ++channel, ++sample) {
					buffer16[sample] = OSSwapInt16(buffer16[sample]);
				}
			}
			break;
			
		case 24:
		case 32:
			buffer32 = (uint32_t *)chunk->mBuffers[0].mData;
			for(wideSample = sample = 0; wideSample < frameCount; ++wideSample) {
				for(channel = 0; channel < chunk->mBuffers[0].mNumberChannels; ++channel, ++sample) {
					buffer32[sample] = OSSwapInt32(buffer32[sample]);
				}
			}
			break;
			
		default:
			@throw [NSException exceptionWithName:@"IllegalInputException" reason:@"Sample size not supported" userInfo:nil]; 
			break;				
	}
	
	// Compress the chunk
	result = _compressor->AddData((unsigned char *)chunk->mBuffers[0].mData, frameCount * [self bytesPerFrame]);
	if(ERROR_SUCCESS != result) {
		@throw [NSException exceptionWithName:@"MACException" reason:NSLocalizedStringFromTable(@"Monkey's Audio compressor error.", @"Exceptions", @"")
									 userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObject:[NSNumber numberWithInt:result]] forKeys:[NSArray arrayWithObject:@"errorCode"]]];
	}
}	

- (NSString *) settings
{
	return [NSString stringWithFormat:@"MAC settings: compression level:%i", _compressionLevel];
}

@end
