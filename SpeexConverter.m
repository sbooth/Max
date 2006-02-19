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

#import "SpeexConverter.h"

#include <CoreAudio/CoreAudioTypes.h>
#include <AudioToolbox/AudioFormat.h>
#include <AudioToolbox/AudioConverter.h>
#include <AudioToolbox/AudioFile.h>
#include <AudioToolbox/ExtendedAudioFile.h>

#include <Speex/speex.h>
#include <Speex/speex_header.h>
#include <Speex/speex_stereo.h>
#include <Speex/speex_callbacks.h>

#include <Ogg/ogg.h>

#import "MallocException.h"
#import "IOException.h"
#import "StopException.h"
#import "SpeexException.h"
#import "CoreAudioException.h"

#include <fcntl.h>		// open, write
#include <sys/stat.h>	// stat
#include <paths.h>		// _PATH_TMP
#include <unistd.h>		// mkstemp, unlink


@implementation SpeexConverter

- (id) initWithInputFile:(NSString *)inputFilename
{
	if((self = [super initWithInputFile:inputFilename])) {
		_resampleInput = NO;
		return self;
	}
	return nil;
}

- (oneway void) convertToFile:(NSString *)filename
{
	NSDate							*startTime				= [NSDate date];
	int								in_fd					= -1;
	ssize_t							totalBytes;
	ssize_t							bytesToRead;
	ssize_t							bytesRead;
	BOOL							streamInited			= NO;

	void							*st						= NULL;
	const SpeexMode					*mode					= NULL;
	SpeexHeader						*header					= NULL;
	SpeexCallback					callback;
	SpeexBits						bits;
	SpeexStereoState				stereo					= SPEEX_STEREO_STATE_INIT;
	
	int16_t							output [2000];
	int								frameSize				= 0;
	int								packetCount				= 0;

	ogg_sync_state					oy;
	ogg_page						og;
	ogg_packet						op;
	ogg_stream_state				os;
	
	int								enh_enabled				= 1;
	int								framesPerPacket			= 2;
	BOOL							eos						= NO;
	int								channels				= -1;
	int								rate					= 0;
	int								extraHeaders;
	
	char							*data					= NULL;
	int								packetNumber;
	int								j;
		
	unsigned						iterations				= 0;
	
	OSStatus						err;
	FSRef							ref;
	AudioFileID						audioFile;
	ExtAudioFileRef					extAudioFileRef;
	AudioBufferList					bufferList;	
				
	
	// Tell our owner we are starting
	[_delegate setStartTime:startTime];	
	[_delegate setStarted];
	
	@try {
		// Open the output file (converter output may be resampled before it is written to this file)
		err = FSPathMakeRef((const UInt8 *)[filename fileSystemRepresentation], &ref, NULL);
		if(noErr != err) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to locate the output file", @"Exceptions", @"")
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:filename, [NSString stringWithUTF8String:GetMacOSStatusErrorString(err)], [NSString stringWithUTF8String:GetMacOSStatusCommentString(err)], nil] forKeys:[NSArray arrayWithObjects:@"filename", @"errorCode", @"errorString", nil]]];
		}
		err = AudioFileInitialize(&ref, kAudioFileAIFFType, &_outputASBD, 0, &audioFile);
		if(noErr != err) {
			@throw [CoreAudioException exceptionWithReason:NSLocalizedStringFromTable(@"AudioFileInitialize failed", @"Exceptions", @"")
												  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithUTF8String:GetMacOSStatusErrorString(err)], [NSString stringWithUTF8String:GetMacOSStatusCommentString(err)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		err = ExtAudioFileWrapAudioFileID(audioFile, YES, &extAudioFileRef);
		if(noErr != err) {
			@throw [CoreAudioException exceptionWithReason:NSLocalizedStringFromTable(@"ExtAudioFileWrapAudioFileID failed", @"Exceptions", @"")
												  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithUTF8String:GetMacOSStatusErrorString(err)], [NSString stringWithUTF8String:GetMacOSStatusCommentString(err)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
				
		// Open the input file
		in_fd = open([_inputFilename fileSystemRepresentation], O_RDONLY);
		if(-1 == in_fd) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to open the input file", @"Exceptions", @"") 
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		// Get input file information
		struct stat sourceStat;
		if(-1 == fstat(in_fd, &sourceStat)) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to get information on the input file", @"Exceptions", @"") 
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		totalBytes		= sourceStat.st_size;
		bytesToRead		= totalBytes;
		
		// Initialize Ogg data struct
		ogg_sync_init(&oy);
		
		speex_bits_init(&bits);
		
		// Main decoding loop
		while(0 < bytesToRead) {
			
			// Get the ogg buffer for writing
			data = ogg_sync_buffer(&oy, 200);
			
			// Read bitstream from input file
			bytesRead = read(in_fd, data, 200);
			if(-1 == bytesRead) {
				@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to read from the input file", @"Exceptions", @"") 
											   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}
			else if(0 == bytesRead) {
				eos = YES;
			}
			
			ogg_sync_wrote(&oy, bytesRead);
			
			// Loop for all complete pages we got (most likely only one)
			while(1 == ogg_sync_pageout(&oy, &og)) {
				
				if(NO == streamInited) {
					ogg_stream_init(&os, ogg_page_serialno(&og));
					streamInited = YES;
				}
				
				// Add page to the bitstream
				ogg_stream_pagein(&os, &og);
				
				// Extract all available packets
				packetNumber = 0;
				while(NO == eos && 1 == ogg_stream_packetout(&os, &op)) {
					
					// If this is the first packet, process as Speex header
					if(0 == packetCount) {
						
						header = speex_packet_to_header((char*)op.packet, op.bytes);
						if(NULL == header) {
							@throw [SpeexException exceptionWithReason:NSLocalizedStringFromTable(@"Cannot read Speex header", @"Exceptions", @"") userInfo:nil];
						}
						if(SPEEX_NB_MODES <= header->mode) {
							@throw [SpeexException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Unrecognized Speex mode number %i", @"Exceptions", @""), header->mode] userInfo:nil];
						}
						
						mode = speex_lib_get_mode(header->mode);
						
						if(1 < header->speex_version_id) {
							@throw [SpeexException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Unable to decode Speex bitstream version %i", @"Exceptions", @""), header->speex_version_id] userInfo:nil];
						}
						
						if(mode->bitstream_version < header->mode_bitstream_version) {
							@throw [SpeexException exceptionWithReason:NSLocalizedStringFromTable(@"This file was encoded with a newer version of Speex", @"Exceptions", @"") userInfo:nil];
						}
						
						if(mode->bitstream_version > header->mode_bitstream_version)  {
							@throw [SpeexException exceptionWithReason:NSLocalizedStringFromTable(@"This file was encoded with an older version of Speex", @"Exceptions", @"") userInfo:nil];
						}
						
						st = speex_decoder_init(mode);
						if(NULL == st) {
							@throw [SpeexException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to intialize Speex decoder", @"Exceptions", @"") userInfo:nil];
						}
						speex_decoder_ctl(st, SPEEX_SET_ENH, &enh_enabled);
						speex_decoder_ctl(st, SPEEX_GET_FRAME_SIZE, &frameSize);
						
						if(1 != channels) {
							callback.callback_id	= SPEEX_INBAND_STEREO;
							callback.func			= speex_std_stereo_request_handler;
							callback.data			= &stereo;
							
							speex_decoder_ctl(st, SPEEX_SET_HANDLER, &callback);
						}
						rate = header->rate;
						
						speex_decoder_ctl(st, SPEEX_SET_SAMPLING_RATE, &rate);
						
						if(44100 != rate) {
							AudioStreamBasicDescription asbd;
							
							asbd.mSampleRate			= (float)rate;
							asbd.mFormatID				= kAudioFormatLinearPCM;
							asbd.mFormatFlags			= kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsBigEndian;
							asbd.mBytesPerPacket		= 4;
							asbd.mFramesPerPacket		= 1;
							asbd.mBytesPerFrame			= 4;
							asbd.mChannelsPerFrame		= 2;
							asbd.mBitsPerChannel		= 16;
							
							err = ExtAudioFileSetProperty(extAudioFileRef, kExtAudioFileProperty_ClientDataFormat, sizeof(asbd), &asbd);
							if(noErr != err) {
								@throw [CoreAudioException exceptionWithReason:NSLocalizedStringFromTable(@"ExtAudioFileSetProperty failed", @"Exceptions", @"")
																	  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithUTF8String:GetMacOSStatusErrorString(err)], [NSString stringWithUTF8String:GetMacOSStatusCommentString(err)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
							}
						}
						
						framesPerPacket		= header->frames_per_packet;
						channels			= header->nb_channels;
						extraHeaders		= header->extra_headers;
						
						if(0 == framesPerPacket) {
							framesPerPacket = 1;
						}
					} 
					else if(1 == packetCount) {
						// Ignore comments
					} 
					else if(packetCount <= 1 + extraHeaders) {
						// Ignore extra headers
					} 
					else {
						++packetNumber;
						
						// End of stream condition
						if(op.e_o_s) {
							eos = 1;
						}
						
						// Copy Ogg packet to Speex bitstream
						speex_bits_read_from(&bits, (char*)op.packet, op.bytes);
						for(j = 0; j != framesPerPacket; ++j) {
							int ret;
							// Decode frame
							ret = speex_decode_int(st, &bits, output);
							
							if(-1 == ret) {
								break;
							}
							if(-2 == ret) {
								@throw [SpeexException exceptionWithReason:NSLocalizedStringFromTable(@"Decoding error: possible corrupted stream", @"Exceptions", @"") userInfo:nil];
							}
							if(0 > speex_bits_remaining(&bits)) {
								@throw [SpeexException exceptionWithReason:NSLocalizedStringFromTable(@"Decoding overflow: possible corrupted stream", @"Exceptions", @"") userInfo:nil];
							}
							if(2 == channels) {
								speex_decode_stereo_int(output, frameSize, &stereo);
							}
							
							// Put the data in an AudioBufferList
							bufferList.mNumberBuffers					= 1;
							bufferList.mBuffers[0].mData				= output;
							bufferList.mBuffers[0].mDataByteSize		= sizeof(int16_t) * frameSize * channels;
							bufferList.mBuffers[0].mNumberChannels		= channels;
														
							// Write the data
							err = ExtAudioFileWrite(extAudioFileRef, frameSize, &bufferList);
							if(noErr != err) {
								@throw [CoreAudioException exceptionWithReason:NSLocalizedStringFromTable(@"ExtAudioFileWrite failed", @"Exceptions", @"")
																	  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithUTF8String:GetMacOSStatusErrorString(err)], [NSString stringWithUTF8String:GetMacOSStatusCommentString(err)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
							}

							// Convert to int16_t and save to output file
							/*for(i = 0; i < frameSize * channels; ++i) {
								out[i] = le_int16_t(output[i]);
							}*/
						}
					}
				}
				
				++packetCount;
			}
			
			// Update status
			bytesToRead -= bytesRead;
			
			// Distributed Object calls are expensive, so only perform them every few iterations
			if(0 == iterations % MAX_DO_POLL_FREQUENCY) {
				
				// Check if we should stop, and if so throw an exception
				if([_delegate shouldStop]) {
					@throw [StopException exceptionWithReason:@"Stop requested by user" userInfo:nil];
				}
				
				// Update UI
				double percentComplete = ((double)(totalBytes - bytesToRead)/(double) totalBytes) * 100.0;
				NSTimeInterval interval = -1.0 * [startTime timeIntervalSinceNow];
				unsigned int secondsRemaining = interval / ((double)(totalBytes - bytesToRead)/(double) totalBytes) - interval;
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
		NSException *exception;
		
		// Close the input file
		if(-1 == close(in_fd)) {
			exception = [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to close the input file", @"Exceptions", @"") 
												userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			NSLog(@"%@", exception);
		}

		// Close the output file
		err = ExtAudioFileDispose(extAudioFileRef);
		if(noErr != err) {
			exception = [CoreAudioException exceptionWithReason:NSLocalizedStringFromTable(@"ExtAudioFileDispose failed", @"Exceptions", @"")
													   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithUTF8String:GetMacOSStatusErrorString(err)], [NSString stringWithUTF8String:GetMacOSStatusCommentString(err)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			NSLog(@"%@", exception);
		}
		
		// Close the output file
		err = AudioFileClose(audioFile);
		if(noErr != err) {
			exception = [CoreAudioException exceptionWithReason:NSLocalizedStringFromTable(@"AudioFileClose failed", @"Exceptions", @"")
													   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithUTF8String:GetMacOSStatusErrorString(err)], [NSString stringWithUTF8String:GetMacOSStatusCommentString(err)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			NSLog(@"%@", exception);
		}		
		
		// Clean up
		free(header);

		speex_decoder_destroy(st);
		speex_bits_destroy(&bits);
		ogg_stream_clear(&os);
		ogg_sync_clear(&oy);
	}

	[_delegate setEndTime:[NSDate date]];
	[_delegate setCompleted];	
}

@end
