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

#import "WavPackEncoder.h"

#include <CoreAudio/CoreAudioTypes.h>
#include <AudioToolbox/AudioFormat.h>
#include <AudioToolbox/AudioConverter.h>
#include <AudioToolbox/AudioFile.h>
#include <AudioToolbox/ExtendedAudioFile.h>

#include <WavPack/wputils.h>

#import "UtilityFunctions.h"
#import "MissingResourceException.h"
#import "CoreAudioException.h"
#import "IOException.h"
#import "MallocException.h"
#import "StopException.h"

// WavPack IO wrapper
static int writeWavPackBlock(void *wv_id, void *data, int32_t bcount)			{ return (bcount == write((int)wv_id, data, bcount)); }

@interface WavPackEncoder (Private)
- (void)	parseSettings;
@end

@implementation WavPackEncoder

- (void) parseSettings
{
	NSDictionary	*settings	= [[self delegate] userInfo];
	
	// Set encoding properties
	switch([[settings objectForKey:@"stereoMode"] intValue]) {
		case WAVPACK_STEREO_MODE_STEREO:			
			_flags |= CONFIG_JOINT_OVERRIDE;
			_flags &= ~CONFIG_JOINT_STEREO;
			break;
		case WAVPACK_STEREO_MODE_JOINT_STEREO:
			_flags |= (CONFIG_JOINT_OVERRIDE | CONFIG_JOINT_STEREO);
			break;
		case WAVPACK_STEREO_MODE_DEFAULT:			;										break;
		default:									;										break;
	}
	
	switch([[settings objectForKey:@"compressionMode"] intValue]) {
		case WAVPACK_COMPRESSION_MODE_HIGH:			_flags |= CONFIG_HIGH_FLAG;				break;
		case WAVPACK_COMPRESSION_MODE_FAST:			_flags |= CONFIG_FAST_FLAG;				break;
		case WAVPACK_COMPRESSION_MODE_DEFAULT:		;										break;
		default:									;										break;
	}
	
	// Hybrid mode
	if([[settings objectForKey:@"enableHybridCompression"] boolValue]) {
		
		_flags |= CONFIG_HYBRID_FLAG;
		
		if([[settings objectForKey:@"createCorrectionFile"] intValue]) {
			_flags |= CONFIG_CREATE_WVC;
		}
		
		if([[settings objectForKey:@"maximumHybridCompression"] intValue]) {
			_flags |= CONFIG_OPTIMIZE_WVC;
		}
		
		switch([[settings objectForKey:@"hybridMode"] intValue]) {
			
			case WAVPACK_HYBRID_MODE_BITS_PER_SAMPLE:
				_bitrate = [[settings objectForKey:@"bitsPerSample"] floatValue];
				break;
				
			case WAVPACK_HYBRID_MODE_BITRATE:
				_bitrate = [[settings objectForKey:@"bitrate"] floatValue];
				_flags |= CONFIG_BITRATE_KBPS;
				break;
				
			default:									;									break;
		}
		
		_noiseShaping = [[settings objectForKey:@"noiseShaping"] floatValue];
		if(0.0 != _noiseShaping) {
			_flags |= (CONFIG_HYBRID_SHAPE | CONFIG_SHAPE_OVERRIDE);
		}
		
	}

}

- (oneway void) encodeToFile:(NSString *) filename
{
	NSDate							*startTime							= [NSDate date];
	OSStatus						err;

	AudioBufferList					bufferList;
	ssize_t							bufferLen							= 0;
	
	int8_t							*buffer8							= NULL;
	int16_t							*buffer16							= NULL;
	int32_t							*buffer32							= NULL;
	int32_t							*wpBuf								= NULL;
	
	SInt64							totalFrames, framesToRead;
	UInt32							size, frameCount;
	
	FSRef							ref;
	ExtAudioFileRef					extAudioFileRef;
	
	AudioStreamBasicDescription		asbd;
	int								fd, cfd;
    
	WavpackContext					*wpc								= NULL;
	WavpackConfig					config;
	
	unsigned long					iterations							= 0;

	int8_t							byteOne, byteTwo, byteThree;
	int32_t							constructedSample;

	unsigned						wideSample, sample, channel;
	

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
		
		wpBuf = (int32_t *)calloc(bufferLen, sizeof(int32_t));
		if(NULL == wpBuf) {
			@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @"") 
											   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		// Open the output file
		fd = open([filename fileSystemRepresentation], O_WRONLY | O_TRUNC, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH);
		if(-1 == fd) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to create the output file.", @"Exceptions", @"") 
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}

		// Open the correction file
		cfd = -1;
		if(_flags & CONFIG_CREATE_WVC) {
			cfd = open([generateUniqueFilename([filename stringByDeletingPathExtension], @"wvc") fileSystemRepresentation], O_WRONLY | O_CREAT | O_EXCL | O_TRUNC, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH);
			if(-1 == cfd) {
				NSLog(@"%s",strerror(errno));
				@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to create the output file.", @"Exceptions", @"") 
											   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}
		}
		
		// Setup the encoder
		wpc = WavpackOpenFileOutput(writeWavPackBlock, (void *)fd, (-1 == cfd ? NULL : (void *)cfd));
		if(NULL == wpc) {
			@throw [NSException exceptionWithName:@"WavPackException" reason:NSLocalizedStringFromTable(@"Unable to create the WavPack encoder.", @"Exceptions", @"") userInfo:nil];
		}
		
		bzero(&config, sizeof(config));
		
		config.num_channels				= [self channelsPerFrame];
		config.channel_mask				= 3;
		config.sample_rate				= [self sampleRate];
		config.bits_per_sample			= [self bitsPerChannel];
		config.bytes_per_sample			= config.bits_per_sample / 8;
		
		config.flags					= _flags;
		
		if(0.f != _noiseShaping) {
			config.shaping_weight		= _noiseShaping;
		}

		if(0.f != _bitrate) {
			config.bitrate				= _bitrate;
		}
		
		if(FALSE == WavpackSetConfiguration(wpc, &config, totalFrames)) {
			@throw [NSException exceptionWithName:@"WavPackException" reason:NSLocalizedStringFromTable(@"Unable to initialize the WavPack encoder.", @"Exceptions", @"") userInfo:nil];
		}

		WavpackPackInit(wpc);
		
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
			
			// Fill WavPack buffer, converting to host endian byte order
			switch([self bitsPerChannel]) {
				
				case 8:
					buffer8 = bufferList.mBuffers[0].mData;
					for(wideSample = sample = 0; wideSample < frameCount; ++wideSample) {
						for(channel = 0; channel < bufferList.mBuffers[0].mNumberChannels; ++channel, ++sample) {
							wpBuf[sample] = (int32_t)buffer8[sample];
						}
					}
					break;
					
				case 16:
					buffer16 = bufferList.mBuffers[0].mData;
					for(wideSample = sample = 0; wideSample < frameCount; ++wideSample) {
						for(channel = 0; channel < bufferList.mBuffers[0].mNumberChannels; ++channel, ++sample) {
							wpBuf[sample] = (int32_t)(int16_t)OSSwapBigToHostInt16(buffer16[sample]);
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
							
							wpBuf[(bufferList.mBuffers[0].mNumberChannels * wideSample) + channel] = (int32_t)OSSwapBigToHostInt32(constructedSample);
						}
					}
					break;
					
				case 32:
					buffer32 = bufferList.mBuffers[0].mData;
					for(wideSample = sample = 0; wideSample < frameCount; ++wideSample) {
						for(channel = 0; channel < bufferList.mBuffers[0].mNumberChannels; ++channel, ++sample) {
							wpBuf[sample] = (int32_t)OSSwapBigToHostInt32(buffer32[sample]);
						}
					}
					break;
					
				default:
					@throw [NSException exceptionWithName:@"IllegalInputException" reason:@"Sample size not supported" userInfo:nil]; 
					break;				
			}

			// Write the data
			if(FALSE == WavpackPackSamples(wpc, wpBuf, frameCount)) {
				@throw [NSException exceptionWithName:@"WavPackException" reason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"WavpackPackSamples"] userInfo:nil];
			}
			
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
		
		// Flush any remaining samples
		if(FALSE == WavpackFlushSamples(wpc)) {
			@throw [NSException exceptionWithName:@"WavPackException" reason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"WavpackFlushSamples"] userInfo:nil];
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
		NSException *exception;
		
		// Close the input file
		err = ExtAudioFileDispose(extAudioFileRef);
		if(noErr != err) {
			exception = [CoreAudioException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"ExtAudioFileDispose"]
													   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			NSLog(@"%@", exception);
		}
		
		// Close the output file
		if(NULL != wpc) {
			WavpackCloseFile(wpc);
		}
		close(fd);
		close(cfd);
		
		free(bufferList.mBuffers[0].mData);
		free(wpBuf);
	}
	
	[_delegate setEndTime:[NSDate date]];
	[_delegate setCompleted];	
}

- (NSString *) settings
{
	return [NSString stringWithFormat:@"WavPack settings: %@%@%@%@%@", 
		(_flags & CONFIG_HIGH_FLAG ? @"high " : @""),
		(_flags & CONFIG_FAST_FLAG ? @"fast " : @""),
		(_flags & CONFIG_HYBRID_FLAG ? @"hybrid " : @""),
		(_flags & CONFIG_JOINT_OVERRIDE ? (_flags & CONFIG_JOINT_STEREO ? @"joint stereo " : @"stereo ") : @"")];
}

@end
