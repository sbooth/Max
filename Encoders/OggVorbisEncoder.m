/*
 *  $Id$
 *
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

#import "OggVorbisEncoder.h"

#include <vorbis/vorbisenc.h>
#include <CoreAudio/CoreAudioTypes.h>
#include <AudioToolbox/AudioFormat.h>
#include <AudioToolbox/AudioConverter.h>
#include <AudioToolbox/AudioFile.h>
#include <AudioToolbox/ExtendedAudioFile.h>

#import "StopException.h"

#import "UtilityFunctions.h"

// My (semi-arbitrary) list of supported vorbis bitrates
static int sVorbisBitrates [14] = { 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320 };

@interface OggVorbisEncoder (Private)
- (void)	parseSettings;
@end

@implementation OggVorbisEncoder

- (oneway void) encodeToFile:(NSString *) filename
{
	NSDate						*startTime							= [NSDate date];	
	ogg_packet					header;
	ogg_packet					header_comm;
	ogg_packet					header_code;
	
	ogg_stream_state			os;
	ogg_page					og;
	ogg_packet					op;
	
	vorbis_info					vi;
	vorbis_comment				vc;
	
	vorbis_dsp_state			vd;
	vorbis_block				vb;
		
	float						**buffer;
	
	int8_t						*buffer8							= NULL;
	int16_t						*buffer16							= NULL;
	int32_t						*buffer32							= NULL;
	unsigned					wideSample;
	unsigned					sample, channel;
	
	int8_t						byteOne, byteTwo, byteThree;
	int32_t						constructedSample;
	float						normalizedSample;

	BOOL						eos									= NO;

	AudioBufferList				bufferList;
	ssize_t						bufferLen							= 0;
	UInt32						bufferByteSize						= 0;
	SInt64						totalFrames, framesToRead;
	UInt32						frameCount;
	
	int							result, bytesWritten;
	
	unsigned long				iterations							= 0;
	
	double						percentComplete;
	NSTimeInterval				interval;
	unsigned					secondsRemaining;
	
	@try {
		bufferList.mBuffers[0].mData = NULL;

		// Parse the encoder settings
		[self parseSettings];

		// Tell our owner we are starting
		[[self delegate] setStartTime:startTime];	
		[[self delegate] setStarted:YES];
		
		// Setup the decoder
		[[self decoder] finalizeSetup];
		
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
		
		bufferByteSize = bufferList.mBuffers[0].mDataByteSize;
		NSAssert(NULL != bufferList.mBuffers[0].mData, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));
		
		// Open the output file
		_out = open([filename fileSystemRepresentation], O_WRONLY | O_TRUNC, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH);
		NSAssert(-1 != _out, NSLocalizedStringFromTable(@"Unable to create the output file.", @"Exceptions", @""));
		
		// Check if we should stop, and if so throw an exception
		if([[self delegate] shouldStop]) {
			@throw [StopException exceptionWithReason:@"Stop requested by user" userInfo:nil];
		}
		
		// Setup the encoder
		vorbis_info_init(&vi);
		
		// Use quality-based VBR
		if(VORBIS_MODE_QUALITY == _mode) {
			result = vorbis_encode_init_vbr(&vi, [[self decoder] pcmFormat].mChannelsPerFrame, [[self decoder] pcmFormat].mSampleRate, _quality);
			NSAssert(0 == result, NSLocalizedStringFromTable(@"Unable to initialize the Ogg (Vorbis) encoder.", @"Exceptions", @""));
		}
		else if(VORBIS_MODE_BITRATE == _mode) {
			result = vorbis_encode_init(&vi, [[self decoder] pcmFormat].mChannelsPerFrame, [[self decoder] pcmFormat].mSampleRate, (_cbr ? _bitrate : -1), _bitrate, (_cbr ? _bitrate : -1));
			NSAssert(0 == result, NSLocalizedStringFromTable(@"Unable to initialize the Ogg (Vorbis) encoder.", @"Exceptions", @""));
		}
		else {
			@throw [NSException exceptionWithName:@"NSInternalInconsistencyException" reason:@"Unrecognized vorbis mode" userInfo:nil];
		}
		
		vorbis_comment_init(&vc);
		
		vorbis_analysis_init(&vd, &vi);
		vorbis_block_init(&vd, &vb);
		
		// Use the current time as the stream id
		srand(time(NULL));
		result = ogg_stream_init(&os, rand());
		NSAssert(-1 != result, NSLocalizedStringFromTable(@"Unable to initialize the ogg stream.", @"Exceptions", @""));
		
		// Write stream headers	
		vorbis_analysis_headerout(&vd, &vc, &header, &header_comm, &header_code);
		ogg_stream_packetin(&os, &header);
		ogg_stream_packetin(&os, &header_comm);
		ogg_stream_packetin(&os, &header_code);
		
		for(;;) {
			if(0 == ogg_stream_flush(&os, &og)) {
				break;	
			}
			
			bytesWritten = write(_out, og.header, og.header_len);
			NSAssert(-1 != bytesWritten, NSLocalizedStringFromTable(@"Unable to write to the output file.", @"Exceptions", @""));
			
			bytesWritten = write(_out, og.body, og.body_len);
			NSAssert(-1 != bytesWritten, NSLocalizedStringFromTable(@"Unable to write to the output file.", @"Exceptions", @""));
		}
		
		// Iteratively get the PCM data and encode it
		while(NO == eos) {
			
			// Set up the buffer parameters
			bufferList.mBuffers[0].mNumberChannels	= [[self decoder] pcmFormat].mChannelsPerFrame;
			bufferList.mBuffers[0].mDataByteSize	= bufferByteSize;
			frameCount								= bufferList.mBuffers[0].mDataByteSize / [[self decoder] pcmFormat].mBytesPerFrame;
			
			// Read a chunk of PCM input
			frameCount		= [[self decoder] readAudio:&bufferList frameCount:frameCount];
			
			// Expose the buffer to submit data
			buffer = vorbis_analysis_buffer(&vd, frameCount);
			
			// Split PCM data into channels and convert to 32-bit float samples for Vorbis
			switch([[self decoder] pcmFormat].mBitsPerChannel) {
				
				case 8:
					buffer8 = bufferList.mBuffers[0].mData;
					for(wideSample = sample = 0; wideSample < frameCount; ++wideSample) {
						for(channel = 0; channel < bufferList.mBuffers[0].mNumberChannels; ++channel, ++sample) {
							buffer[channel][wideSample] = buffer8[sample] / 128.f;
						}
					}
					break;
					
				case 16:
					buffer16 = bufferList.mBuffers[0].mData;
					for(wideSample = sample = 0; wideSample < frameCount; ++wideSample) {
						for(channel = 0; channel < bufferList.mBuffers[0].mNumberChannels; ++channel, ++sample) {
							buffer[channel][wideSample] = ((int16_t)OSSwapBigToHostInt16(buffer16[sample])) / 32768.f;
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
							
							// For simplicity's sake, rather than working with 24-bit numbers just promote them to 32 bits
							constructedSample	= ((byteOne << 24) & 0xFF000000) | ((byteTwo << 16) & 0xFF0000) | ((byteThree << 8) & 0xFF00) | (byteThree & 0xFF);
							constructedSample	= OSSwapBigToHostInt32(constructedSample);
							normalizedSample	= constructedSample / 2147483648.f;
							
							// For some reason I keep gettings clicks when attempting to process the number in 24 bits
							/*
							constructedSample	= ((byteOne << 16) & 0xFF0000) | ((byteTwo << 8) & 0xFF00) | (byteThree & 0xFF);							
							constructedSample	= OSSwapBigToHostInt32(constructedSample);
							
							if(8388608 < constructedSample) {
								constructedSample = ~constructedSample;
								constructedSample &= 0x7FFFFF;
								constructedSample *= -1;
							}

							normalizedSample	= constructedSample / 8388608.f;
							 */
							
							buffer[channel][wideSample] = normalizedSample;
						}
					}
					break;

				case 32:
					buffer32 = bufferList.mBuffers[0].mData;
					for(wideSample = sample = 0; wideSample < frameCount; ++wideSample) {
						for(channel = 0; channel < bufferList.mBuffers[0].mNumberChannels; ++channel, ++sample) {
							buffer[channel][wideSample] = ((int32_t)OSSwapBigToHostInt32(buffer32[sample])) / 2147483648.f;
						}
					}
					break;
					
				default:
					@throw [NSException exceptionWithName:@"IllegalInputException" reason:@"Sample size not supported" userInfo:nil]; 
					break;
			}
			
			// Tell the library how much data we actually submitted
			vorbis_analysis_wrote(&vd, frameCount);
			
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
			
			while(1 == vorbis_analysis_blockout(&vd, &vb)){
				
				vorbis_analysis(&vb, NULL);
				vorbis_bitrate_addblock(&vb);
				
				while(vorbis_bitrate_flushpacket(&vd, &op)) {
					
					ogg_stream_packetin(&os, &op);
					
					// Write out pages (if any)
					while(NO == eos) {
						
						if(0 == ogg_stream_pageout(&os, &og)) {
							break;
						}
						
						bytesWritten = write(_out, og.header, og.header_len);
						NSAssert(-1 != bytesWritten, NSLocalizedStringFromTable(@"Unable to write to the output file.", @"Exceptions", @""));
						
						bytesWritten = write(_out, og.body, og.body_len);
						NSAssert(-1 != bytesWritten, NSLocalizedStringFromTable(@"Unable to write to the output file.", @"Exceptions", @""));
						
						if(ogg_page_eos(&og)) {
							eos = YES;
						}
					}
				}
			}
		}
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
		
		// Close the output file
		if(-1 == close(_out)) {
			exception = [NSException exceptionWithName:@"IOException"
												reason:NSLocalizedStringFromTable(@"Unable to close the output file.", @"Exceptions", @"") 
											  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			NSLog(@"%@", exception);
		}
		
		// Clean up
		ogg_stream_clear(&os);
		vorbis_block_clear(&vb);
		vorbis_dsp_clear(&vd);
		vorbis_comment_clear(&vc);
		vorbis_info_clear(&vi);

		free(bufferList.mBuffers[0].mData);
	}	

	[[self delegate] setEndTime:[NSDate date]];
	[[self delegate] setCompleted:YES];
}

- (NSString *) settingsString
{
	switch(_mode) {
		case VORBIS_MODE_QUALITY:
			return [NSString stringWithFormat:@"Vorbis settings: VBR(q=%f)", _quality * 10.f];
			break;
			
		case VORBIS_MODE_BITRATE:
			return [NSString stringWithFormat:@"Vorbis settings: %@(%l kbps)", (_cbr ? @"CBR" : @"VBR"), _bitrate / 1000];
			break;
			
		default:
			return nil;
			break;
	}
}

@end

@implementation OggVorbisEncoder (Private)

- (void) parseSettings
{
	NSDictionary *settings	= [[self delegate] encoderSettings];
	
	_mode		= [[settings objectForKey:@"mode"] intValue];
	_quality	= [[settings objectForKey:@"quality"] floatValue];
	_bitrate	= sVorbisBitrates[[[settings objectForKey:@"bitrate"] intValue]] * 1000;
	_cbr		= [[settings objectForKey:@"useConstantBitrate"] boolValue];
}

@end
