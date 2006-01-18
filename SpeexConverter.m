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

#import "MallocException.h"
#import "IOException.h"
#import "StopException.h"
#import "SpeexException.h"

#include "speex/speex.h"
#include "speex/speex_header.h"
#include "speex/speex_stereo.h"
#include "speex/speex_callbacks.h"
#include "ogg/ogg.h"

#include "sndfile.h"
#include <fcntl.h>		// open, write
#include <sys/stat.h>	// stat

@implementation SpeexConverter

- (id) initWithInputFilename:(NSString *)inputFilename
{
	if((self = [super initWithInputFilename:inputFilename])) {

		return self;
	}
	return nil;
}

- (void) dealloc
{
	[super dealloc];
}

- (oneway void) convertToFile:(int)file
{
	NSDate							*startTime				= [NSDate date];
	ssize_t							totalBytes;
	ssize_t							bytesToRead;
	ssize_t							bytesRead;
	ssize_t							bytesWritten			= 0;
	ssize_t							currentBytesWritten;
	int								fd;
	BOOL							streamInited			= NO;

	void							*st;
	const SpeexMode					*mode;
	SpeexHeader						*header;
	SpeexCallback					callback;
	SpeexBits						bits;
	SpeexStereoState				stereo					= SPEEX_STEREO_STATE_INIT;
	
	int16_t							out[2000];
	int16_t							output[2000];
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
	
	char							*data;
	int								i, j;
	int								packetNumber;
	
	unsigned						iterations				= 0;
	
	
	
	// Tell our owner we are starting
	[_delegate setStartTime:startTime];	
	[_delegate setStarted];
	
	// Open the input file
	fd = open([_inputFilename UTF8String], O_RDONLY);
	if(-1 == fd) {
		[_delegate setStopped];
		@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to open input file (%i:%s) [%s:%i]", errno, strerror(errno), __FILE__, __LINE__] userInfo:nil];
	}

	// Get input file information
	struct stat sourceStat;
	if(-1 == fstat(fd, &sourceStat)) {
		[_delegate setStopped];
		@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to stat input file (%i:%s) [%s:%i]", errno, strerror(errno), __FILE__, __LINE__] userInfo:nil];
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
		bytesRead = read(fd, data, 200);
		if(-1 == bytesRead) {
			[_delegate setStopped];
			@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to read from input file. (%i:%s) [%s:%i]", errno, strerror(errno), __FILE__, __LINE__] userInfo:nil];
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
						[_delegate setStopped];
						@throw [SpeexException exceptionWithReason:@"Cannot read Speex header" userInfo:nil];
					}
					if(SPEEX_NB_MODES <= header->mode) {
						[_delegate setStopped];
						@throw [SpeexException exceptionWithReason:[NSString stringWithFormat:@"Mode number %i does not (yet/any longer) exist in this version", header->mode] userInfo:nil];
					}
					
					mode = speex_lib_get_mode(header->mode);
					
					if(1 < header->speex_version_id) {
						[_delegate setStopped];
						@throw [SpeexException exceptionWithReason:[NSString stringWithFormat:@"This file was encoded with Speex bit-stream version %i, which I don't know how to decode", header->speex_version_id] userInfo:nil];
					}
					
					if(mode->bitstream_version < header->mode_bitstream_version) {
						[_delegate setStopped];
						@throw [SpeexException exceptionWithReason:@"The file was encoded with a newer version of Speex. You need to upgrade in order to play it." userInfo:nil];
					}
					
					if(mode->bitstream_version > header->mode_bitstream_version)  {
						[_delegate setStopped];
						@throw [SpeexException exceptionWithReason:@"The file was encoded with an older version of Speex. You would need to downgrade the version in order to play it." userInfo:nil];
					}
					
					st = speex_decoder_init(mode);
					if(NULL == st) {
						[_delegate setStopped];
						@throw [SpeexException exceptionWithReason:@"Unable to intialize Speex decoder." userInfo:nil];
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
					
					framesPerPacket		= header->frames_per_packet;
					channels			= header->nb_channels;
					extraHeaders		= header->extra_headers;
					
					free(header);
					
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
							[_delegate setStopped];
							@throw [SpeexException exceptionWithReason:@"Decode error: corrupted stream?" userInfo:nil];
						}
						if(0 > speex_bits_remaining(&bits)) {
							[_delegate setStopped];
							@throw [SpeexException exceptionWithReason:@"Decoding overflow: corrupted stream?" userInfo:nil];
						}
						if(2 == channels) {
							speex_decode_stereo_int(output, frameSize, &stereo);
						}
						
						// Convert to int16_t and save to output file
						/*for(i = 0; i < frameSize * channels; ++i) {
							out[i] = le_int16_t(output[i]);
						}*/

						currentBytesWritten = write(file, output, sizeof(int16_t) * frameSize * channels);
						if(-1 == currentBytesWritten) {
							[_delegate setStopped];
							@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to write to output file (%i:%s) [%s:%i]", errno, strerror(errno), __FILE__, __LINE__] userInfo:nil];
						}
						bytesWritten += currentBytesWritten;
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
				[_delegate setStopped];
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

	// Close the input file
	if(-1 == close(fd)) {
		[_delegate setStopped];
		@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to close input file (%i:%s) [%s:%i]", errno, strerror(errno), __FILE__, __LINE__] userInfo:nil];
	}

	// Clean up
	speex_decoder_destroy(st);
	speex_bits_destroy(&bits);
	ogg_stream_clear(&os);
	ogg_sync_clear(&oy);

	[_delegate setEndTime:[NSDate date]];
	[_delegate setCompleted];	
}

@end
