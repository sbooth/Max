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
#include <paths.h>		//_PATH_TMP
#include <unistd.h>		// mkstemp, unlink

#define TEMPFILE_PATTERN	"Max.XXXXXXXX"

@implementation SpeexConverter

- (id) initWithInputFile:(NSString *)inputFilename
{
	char				*path			= NULL;
	const char			*tmpDir;
	ssize_t				tmpDirLen;
	ssize_t				patternLen		= strlen(TEMPFILE_PATTERN);
	
	if((self = [super initWithInputFile:inputFilename])) {

		@try {
			_resampleInput = NO;
			
			if([[NSUserDefaults standardUserDefaults] boolForKey:@"useCustomTmpDirectory"]) {
				tmpDir = [[[[NSUserDefaults standardUserDefaults] stringForKey:@"tmpDirectory"] stringByAppendingString:@"/"] UTF8String];
			}
			else {
				tmpDir = _PATH_TMP;
			}
			
			tmpDirLen	= strlen(tmpDir);
			path		= malloc((tmpDirLen + patternLen + 1) *  sizeof(char));
			if(NULL == path) {
				@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory", @"Exceptions", @"") 
												   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}
			memcpy(path, tmpDir, tmpDirLen);
			memcpy(path + tmpDirLen, TEMPFILE_PATTERN, patternLen);
			path[tmpDirLen + patternLen] = '\0';
			
			mktemp(path);
			_tempFilename = [[NSString stringWithUTF8String:path] retain];
		}
		
		@catch(NSException *exception) {
			@throw;
		}

		@finally {			
			free(path);
		}
		
		return self;
	}
	return nil;
}

- (void) dealloc
{
	// Delete resampled temporary file
	if(-1 == unlink([_tempFilename UTF8String])) {
		NSException *exception = [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to delete the temporary file", @"Exceptions", @"") 					
														 userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		NSLog(@"%@", exception);
	}			
	
	[_tempFilename release];

	[super dealloc];
}

- (oneway void) convertToFile:(NSString *)filename
{
	NSDate							*startTime				= [NSDate date];
	int								in_fd					= -1;
	int								out_fd					= -1;
	int								temp_fd					= -1;
	int								current_fd				= -1;
	ssize_t							totalBytes;
	ssize_t							bytesToRead;
	ssize_t							bytesRead;
	ssize_t							bytesWritten			= 0;
	ssize_t							currentBytesWritten;
	BOOL							streamInited			= NO;

	void							*st;
	const SpeexMode					*mode;
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
	
	char							*data;
	int								packetNumber;
	int								j;
		
	unsigned						iterations				= 0;
	
	SNDFILE							*inSF;
	SF_INFO							info;
	SNDFILE							*outSF				= NULL;
	const char						*string				= NULL;
	int								i;
	int								err					= 0 ;
	int								bufferLen			= 1024;
	int								*intBuffer			= NULL;
	double							*doubleBuffer		= NULL;
	double							maxSignal;
	int								frameCount;
	int								readCount;
				
				
	
	// Tell our owner we are starting
	[_delegate setStartTime:startTime];	
	[_delegate setStarted];
	
	@try {
		// Open the output file (converter output may be resampled before it is written to this file)
		out_fd = open([filename UTF8String], O_WRONLY | O_TRUNC, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH);
		if(-1 == out_fd) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to open the output file", @"Exceptions", @"") 
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		// Open the temporary file if resampling is necessary
		if(_resampleInput) {
			temp_fd = open([_tempFilename UTF8String], O_WRONLY | O_TRUNC, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH);
			if(-1 == temp_fd) {
				@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to open the temporary file", @"Exceptions", @"") 
											   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}
		}
		
		// Open the input file
		in_fd = open([_inputFilename UTF8String], O_RDONLY);
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
							_resampleInput	= YES;
							current_fd		= temp_fd;
						}
						else {
							current_fd		= out_fd;
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
							
							// Convert to int16_t and save to output file
							/*for(i = 0; i < frameSize * channels; ++i) {
								out[i] = le_int16_t(output[i]);
							}*/
							
							currentBytesWritten = write(current_fd, output, sizeof(int16_t) * frameSize * channels);
							if(-1 == currentBytesWritten) {
								@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to write to the output file", @"Exceptions", @"") 
															   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
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
		
		// Resample to 44.1 for intermediate format if required
		if(_resampleInput) {

			// Open the input file
			info.format			= SF_FORMAT_RAW | SF_FORMAT_PCM_16;
			info.samplerate		= rate;
			info.channels		= 2;
			
			inSF = sf_open_fd(temp_fd, SFM_READ, &info, 0);
			if(NULL == inSF) {
				@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to open the temporary file", @"Exceptions", @"") 
											   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:sf_error(NULL)], [NSString stringWithUTF8String:sf_strerror(NULL)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}
			
			// Setup downsampled output file
			info.format			= SF_FORMAT_RAW | SF_FORMAT_PCM_16;
			info.samplerate		= 44100;
			info.channels		= 2;
			outSF				= sf_open_fd(out_fd, SFM_WRITE, &info, 0);
			if(NULL == outSF) {
				@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to create the output file", @"Exceptions", @"") 
											   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:sf_error(NULL)], [NSString stringWithUTF8String:sf_strerror(NULL)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}
			
			// Copy metadata
			for(i = SF_STR_FIRST; i <= SF_STR_LAST; ++i) {
				string = sf_get_string(inSF, i);
				if(NULL != string) {
					err = sf_set_string(outSF, i, string);
				}
			}
			
			// Copy audio data
			if(((info.format & SF_FORMAT_SUBMASK) == SF_FORMAT_DOUBLE) || ((info.format & SF_FORMAT_SUBMASK) == SF_FORMAT_FLOAT)) {
				
				doubleBuffer = (double *)malloc(bufferLen * sizeof(double));
				if(NULL == doubleBuffer) {
					@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory", @"Exceptions", @"") 
													   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
				}
				
				frameCount		= bufferLen / info.channels ;
				readCount		= frameCount ;
				
				sf_command(inSF, SFC_CALC_SIGNAL_MAX, &maxSignal, sizeof(maxSignal)) ;
				
				if(maxSignal < 1.0) {	
					while(readCount > 0) {
						// Check if we should stop, and if so throw an exception
						if(0 == iterations % MAX_DO_POLL_FREQUENCY && [_delegate shouldStop]) {
							@throw [StopException exceptionWithReason:@"Stop requested by user" userInfo:nil];
						}
						
						readCount = sf_readf_double(inSF, doubleBuffer, frameCount) ;
						sf_writef_double(outSF, doubleBuffer, readCount) ;
						
						++iterations;
					}
				}
				// Renormalize output
				else {	
					sf_command(inSF, SFC_SET_NORM_DOUBLE, NULL, SF_FALSE);
					
					while(0 < readCount) {
						// Check if we should stop, and if so throw an exception
						if(0 == iterations % MAX_DO_POLL_FREQUENCY && [_delegate shouldStop]) {
							@throw [StopException exceptionWithReason:@"Stop requested by user" userInfo:nil];
						}
						
						readCount = sf_readf_double(inSF, doubleBuffer, frameCount);
						for(i = 0 ; i < readCount * info.channels; ++i) {
							doubleBuffer[i] /= maxSignal;
						}
						
						sf_writef_double(outSF, doubleBuffer, readCount);
						
						++iterations;
					}
				}
			}
			else {
				intBuffer = (int *)malloc(bufferLen * sizeof(int));
				if(NULL == intBuffer) {
					@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory", @"Exceptions", @"") 
													   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
				}
				
				frameCount		= bufferLen / info.channels;
				readCount		= frameCount;
				
				while(0 < readCount) {	
					// Check if we should stop, and if so throw an exception
					if(0 == iterations % MAX_DO_POLL_FREQUENCY && [_delegate shouldStop]) {
						@throw [StopException exceptionWithReason:@"Stop requested by user" userInfo:nil];
					}
					
					readCount = sf_readf_int(inSF, intBuffer, frameCount);
					sf_writef_int(outSF, intBuffer, readCount);
					
					++iterations;
				}
			}
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
		// Close the input file
		if(-1 == close(in_fd)) {
			NSException *exception = [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to close the input file", @"Exceptions", @"") 
															 userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:sf_error(NULL)], [NSString stringWithUTF8String:sf_strerror(NULL)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			NSLog(@"%@", exception);
		}

		// Close the output file
		if(-1 == close(out_fd)) {
			NSException *exception = [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to close the output file", @"Exceptions", @"") 
															 userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:sf_error(NULL)], [NSString stringWithUTF8String:sf_strerror(NULL)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			NSLog(@"%@", exception);
		}

		// Close the temporary file
		if(_resampleInput) {
			if(-1 == close(temp_fd)) {
				NSException *exception = [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to close the temporary file", @"Exceptions", @"") 
																 userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:sf_error(NULL)], [NSString stringWithUTF8String:sf_strerror(NULL)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
				NSLog(@"%@", exception);
			}
			
			// Clean up sndfiles
			if(0 != sf_close(inSF)) {
				NSException *exception =[IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to close the input file", @"Exceptions", @"") 
																userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:sf_error(NULL)], [NSString stringWithUTF8String:sf_strerror(NULL)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
				NSLog(@"%@", exception);
			}
			if(0 != sf_close(outSF)) {
				NSException *exception =[IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to close the input file", @"Exceptions", @"") 
																userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:sf_error(NULL)], [NSString stringWithUTF8String:sf_strerror(NULL)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
				NSLog(@"%@", exception);
			}

			free(intBuffer);
			free(doubleBuffer);
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
