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

#import "LibsndfileEncoder.h"

#include <sndfile/sndfile.h>

#import "StopException.h"

#import "UtilityFunctions.h"

@implementation LibsndfileEncoder

- (oneway void) encodeToFile:(NSString *)filename
{
	NSDate							*startTime							= [NSDate date];
	SNDFILE							*sf									= NULL;
	SF_INFO							info;
	int								format								= 0;
	AudioBufferList					bufferList;
	ssize_t							bufferLen							= 0;

	SInt64							totalFrames, framesToRead;
	UInt32							frameCount;
	
	int8_t							*buffer8							= NULL;
	int16_t							*buffer16							= NULL;
	int32_t							*buffer32							= NULL;
	int32_t							*buf								= NULL;
	
	unsigned long					iterations							= 0;

	int8_t							byteOne, byteTwo, byteThree;
	int32_t							constructedSample;
	
	unsigned						wideSample, sample, channel;
	
	double							percentComplete;
	NSTimeInterval					interval;
	unsigned						secondsRemaining;
	
	@try {
		// This will never work if these sizes aren't the same
		NSAssert(sizeof(int32_t) == sizeof(int), @"Type size mismatch.");
		
		// Tell our owner we are starting
		[[self delegate] setStartTime:startTime];	
		[[self delegate] setStarted:YES];
		
		// Setup the decoder
		[[self decoder] finalizeSetup];
		
		// Parse settings
		format = [[[[self delegate] encoderSettings] objectForKey:@"majorFormat"] intValue] | [[[[self delegate] encoderSettings] objectForKey:@"subtypeFormat"] intValue];
		
		totalFrames			= [[self decoder] totalFrames];
		framesToRead		= totalFrames;
		
		// Set up the AudioBufferList
		bufferList.mNumberBuffers					= 1;
		bufferList.mBuffers[0].mData				= NULL;
		bufferList.mBuffers[0].mNumberChannels		= [[self decoder] pcmFormat].mChannelsPerFrame;
		
		// Allocate the buffer that will hold the interleaved audio data
		bufferLen									= 1024;
		switch([[self decoder] pcmFormat].mBitsPerChannel) {
			
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
		
		NSAssert(NULL != bufferList.mBuffers[0].mData, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));

		buf = (int32_t *)calloc(bufferLen, sizeof(int32_t));
		NSAssert(NULL != buf, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));

		// Setup output file
		memset(&info, 0, sizeof(info));
		info.samplerate		= [[self decoder] pcmFormat].mSampleRate;
		info.channels		= [[self decoder] pcmFormat].mChannelsPerFrame;
		info.format			= format;
		sf					= sf_open([filename fileSystemRepresentation], SFM_WRITE, &info);
		NSAssert(NULL != sf, NSLocalizedStringFromTable(@"Unable to create the output file.", @"Exceptions", @""));

		// Iteratively get the PCM data and encode it
		for(;;) {
			
			// Set up the buffer parameters
			bufferList.mBuffers[0].mNumberChannels	= [[self decoder] pcmFormat].mChannelsPerFrame;
			bufferList.mBuffers[0].mDataByteSize	= bufferLen;
			frameCount								= bufferList.mBuffers[0].mDataByteSize / [[self decoder] pcmFormat].mBytesPerFrame;
			
			// Read a chunk of PCM input
			frameCount		= [[self decoder] readAudio:&bufferList frameCount:frameCount];
			
			// We're finished if no frames were returned
			if(0 == frameCount) {
				break;
			}
			
			// Fill buf buffer, converting to host endian byte order
			// Libsndfile expects the most significant byte to be the most significant byte, regardless of
			// sample size
			switch([[self decoder] pcmFormat].mBitsPerChannel) {
				
				case 8:
					buffer8 = bufferList.mBuffers[0].mData;
					for(wideSample = sample = 0; wideSample < frameCount; ++wideSample) {
						for(channel = 0; channel < bufferList.mBuffers[0].mNumberChannels; ++channel, ++sample) {
							buf[sample] = (int32_t)buffer8[sample];
							buf[sample] <<= 24;
						}
					}
					break;
					
				case 16:
					buffer16 = bufferList.mBuffers[0].mData;
					for(wideSample = sample = 0; wideSample < frameCount; ++wideSample) {
						for(channel = 0; channel < bufferList.mBuffers[0].mNumberChannels; ++channel, ++sample) {
							buf[sample] = (int32_t)(int16_t)OSSwapBigToHostInt16(buffer16[sample]);
							buf[sample] <<= 16;
						}
					}
					break;
					
				case 24:
					buffer8 = bufferList.mBuffers[0].mData;
					for(wideSample = sample = 0; wideSample < frameCount; ++wideSample) {
						for(channel = 0; channel < bufferList.mBuffers[0].mNumberChannels; ++channel, ++sample) {
							byteOne				= buffer8[sample];
							byteTwo				= buffer8[++sample];
							byteThree			= buffer8[++sample];							
							constructedSample	= ((byteOne << 16) & 0xFF0000) | ((byteTwo << 8) & 0xFF00) | (byteThree & 0xFF);
							
							buf[(bufferList.mBuffers[0].mNumberChannels * wideSample) + channel] = (int32_t)OSSwapBigToHostInt32(constructedSample);
							buf[(bufferList.mBuffers[0].mNumberChannels * wideSample) + channel] <<= 8;
						}
					}
					break;
					
				case 32:
					buffer32 = bufferList.mBuffers[0].mData;
					for(wideSample = sample = 0; wideSample < frameCount; ++wideSample) {
						for(channel = 0; channel < bufferList.mBuffers[0].mNumberChannels; ++channel, ++sample) {
							buf[sample] = (int32_t)OSSwapBigToHostInt32(buffer32[sample]);
						}
					}
					break;
					
				default:
					@throw [NSException exceptionWithName:@"IllegalInputException" reason:@"Sample size not supported" userInfo:nil]; 
					break;				
			}
			
			// Write the data
			sf_writef_int(sf, buf, frameCount);
			
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

		[[self delegate] setEndTime:[NSDate date]];
		[[self delegate] setCompleted:YES];	
	}

	@catch(StopException *exception) {
		[[self delegate] setStopped:YES];
	}
	
	@catch(NSException *exception) {
		[[self delegate] setException:exception];
		[[self delegate] setStopped:YES];
	}
	
	@finally {
		free(bufferList.mBuffers[0].mData);
		free(buf);
				
		if(0 != sf_close(sf)) {
			NSException *exception =[NSException exceptionWithName:@"IOException"
															reason:NSLocalizedStringFromTable(@"Unable to close the output file.", @"Exceptions", @"") 
														  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:sf_error(NULL)], [NSString stringWithCString:sf_strerror(NULL) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			NSLog(@"%@", exception);
		}
	}	
}

@end
