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

#import "WavPackConverter.h"

#include <WavPack/wputils.h>

#include <CoreAudio/CoreAudioTypes.h>
#include <AudioToolbox/AudioFormat.h>
#include <AudioToolbox/AudioConverter.h>
#include <AudioToolbox/AudioFile.h>
#include <AudioToolbox/ExtendedAudioFile.h>

#import "MallocException.h"
#import "IOException.h"
#import "StopException.h"
#import "CoreAudioException.h"

#include <unistd.h>		// lseek
#include <fcntl.h>		// open, write
#include <sys/stat.h>	// stat

@implementation WavPackConverter

- (oneway void) convertToFile:(NSString *)filename
{
	NSDate							*startTime			= [NSDate date];
    WavpackContext					*wpc;
	char							error [80];
	UInt32							sample				= 0;
	UInt32							samplesRead			= 0;
	UInt32							samplesToRead		= 0;
	UInt32							totalSamples		= 0;
	UInt32							bytesPerFrame;
	OSStatus						err;
	FSRef							ref;
	AudioFileID						audioFile;
	ExtAudioFileRef					extAudioFileRef;
	AudioStreamBasicDescription		asbd;
	AudioBufferList					bufferList;
	unsigned						bufferLen;
	int32_t							*buffer				= NULL;
	int8_t							*buffer8			= NULL;
	int8_t							*alias8				= NULL;
	int16_t							*buffer16			= NULL;
	int16_t							*alias16			= NULL;
	int32_t							*buffer32			= NULL;
	int32_t							*alias32			= NULL;
	unsigned long					iterations			= 0;
	
	// Tell our owner we are starting
	[_delegate setStartTime:startTime];	
	[_delegate setStarted];
	
	@try {
		// Setup converter
		wpc = WavpackOpenFileInput([_inputFilename fileSystemRepresentation], error, 0, 0);
		if(NULL == wpc) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to open the input file.", @"Exceptions", @"") 
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:error encoding:NSASCIIStringEncoding]] forKeys:[NSArray arrayWithObject:@"errorString"]]];
		}

		[self setSampleRate:WavpackGetSampleRate(wpc)];
		[self setBitsPerChannel:WavpackGetBitsPerSample(wpc)];
		[self setChannelsPerFrame:WavpackGetNumChannels(wpc)];
				
		// Get input file information
		totalSamples		= WavpackGetNumSamples(wpc);
		samplesToRead		= totalSamples;
		bytesPerFrame		= [self channelsPerFrame] * ([self bitsPerChannel] / 8);

		// Open the output file
		err = FSPathMakeRef((const UInt8 *)[filename fileSystemRepresentation], &ref, NULL);
		if(noErr != err) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to locate the output file.", @"Exceptions", @"")
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:filename, [NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"filename", @"errorCode", @"errorString", nil]]];
		}
		asbd = [self outputDescription];
		err = AudioFileInitialize(&ref, kAudioFileAIFFType, &asbd, 0, &audioFile);
		if(noErr != err) {
			@throw [CoreAudioException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"AudioFileInitialize"]
												  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		err = ExtAudioFileWrapAudioFileID(audioFile, YES, &extAudioFileRef);
		if(noErr != err) {
			@throw [CoreAudioException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"ExtAudioFileWrapAudioFileID"]
												  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		// Set up the AudioBufferList
		bufferList.mNumberBuffers					= 1;
		bufferList.mBuffers[0].mNumberChannels		= [self channelsPerFrame];

		// Allocate the input buffer
		bufferLen									= 1024;

		buffer = (int32_t *)calloc(bufferLen, sizeof(int32_t));
		if(NULL == buffer) {
			@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @"") 
											   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		// Allocate the buffer that will hold the interleaved audio data
		switch([self bitsPerChannel]) {
			
			case 8:				
				buffer8 = calloc(bufferLen, sizeof(int8_t));
				if(NULL == buffer8) {
					@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @"") 
													   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
				}
				break;
				
			case 16:
				buffer16 = calloc(bufferLen, sizeof(int16_t));
				if(NULL == buffer16) {
					@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @"") 
													   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
				}
				break;
				
			case 24:
			case 32:
				buffer32 = calloc(bufferLen, sizeof(int32_t));
				if(NULL == buffer32) {
					@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @"") 
													   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
				}
				break;
				
			default:
				@throw [NSException exceptionWithName:@"IllegalInputException" reason:@"Sample size not supported" userInfo:nil]; 
				break;				
		}
				
		for(;;) {
			
			// Decode the data
			samplesRead = WavpackUnpackSamples(wpc, buffer, bufferLen / bytesPerFrame);

			// EOF?
			if(0 == samplesRead) {
				break;
			}
			
			switch([self bitsPerChannel]) {
				
				case 8:
					
					// Interleave the audio, converting to big endian byte order for the AIFF file
					alias8 = buffer8;
					for(sample = 0; sample < samplesRead; ++sample) {
						*alias8++ = (int8_t)OSSwapHostToBigInt32(buffer[sample]);
					}
						
					// Place the interleaved data in the buffer
					bufferList.mBuffers[0].mData				= buffer8;
					bufferList.mBuffers[0].mDataByteSize		= samplesRead * sizeof(int8_t);
					
					break;
					
				case 16:
					
					// Interleave the audio, converting to big endian byte order for the AIFF file
					alias16 = buffer16;
					for(sample = 0; sample < samplesRead; ++sample) {
						*alias16++ = (int16_t)OSSwapHostToBigInt32(buffer[sample]);
					}
						
					// Place the interleaved data in the buffer
					bufferList.mBuffers[0].mData				= buffer16;
					bufferList.mBuffers[0].mDataByteSize		= samplesRead * sizeof(int16_t);
					
					break;
					
				case 24:
				case 32:
					
					// Interleave the audio, converting to big endian byte order for the AIFF file
					alias32 = buffer32;
					for(sample = 0; sample < samplesRead; ++sample) {
						*alias32++ = OSSwapHostToBigInt32(buffer[sample]);
					}
						
					// Place the interleaved data in the buffer
					bufferList.mBuffers[0].mData				= buffer32;
					bufferList.mBuffers[0].mDataByteSize		= samplesRead * sizeof(int32_t);
					
					break;
					
				default:
					@throw [NSException exceptionWithName:@"IllegalInputException" reason:@"Sample size not supported" userInfo:nil]; 
					break;				
			}
			
			// Write the data
			err = ExtAudioFileWrite(extAudioFileRef, samplesRead, &bufferList);
			if(noErr != err) {
				@throw [CoreAudioException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"ExtAudioFileWrite"]
													  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}
			
			// Update status
			samplesToRead -= samplesRead;
			
			// Distributed Object calls are expensive, so only perform them every few iterations
			if(0 == iterations % MAX_DO_POLL_FREQUENCY) {
				
				// Check if we should stop, and if so throw an exception
				if([_delegate shouldStop]) {
					@throw [StopException exceptionWithReason:@"Stop requested by user" userInfo:nil];
				}
				
				// Update UI
				double percentComplete = ((double)(totalSamples - samplesToRead)/(double) totalSamples) * 100.0;
				NSTimeInterval interval = -1.0 * [startTime timeIntervalSinceNow];
				unsigned secondsRemaining = (unsigned) (interval / ((double)(totalSamples - samplesToRead)/(double) totalSamples) - interval);
				NSString *timeRemaining = [NSString stringWithFormat:@"%i:%02i", secondsRemaining / 60, secondsRemaining % 60];
				
				[_delegate updateProgress:percentComplete timeRemaining:timeRemaining];
			}
			
			++iterations;
		}
	}
	
	@catch(StopException *exception) {
		[_delegate setStopped];
	}
	
	@catch(NSException *exception) {
		[_delegate setException:exception];
		[_delegate setStopped];
	}
	
	@finally {
		NSException						*exception;
		
		// Close the output file
		err = ExtAudioFileDispose(extAudioFileRef);
		if(noErr != err) {
			exception = [CoreAudioException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"ExtAudioFileDispose"]
													   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			NSLog(@"%@", exception);
		}
		
		// Close the output file
		err = AudioFileClose(audioFile);
		if(noErr != err) {
			exception = [CoreAudioException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"AudioFileClose"]
													   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			NSLog(@"%@", exception);
		}		
		
		// Close input file
		WavpackCloseFile(wpc);
		
		free(buffer);
		free(buffer8);
		free(buffer16);
		free(buffer32);
	}
	
	[_delegate setEndTime:[NSDate date]];
	[_delegate setCompleted];	
}

@end
