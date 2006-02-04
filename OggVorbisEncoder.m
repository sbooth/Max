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

#import "OggVorbisEncoder.h"
#import "MallocException.h"
#import "IOException.h"
#import "StopException.h"
#import "MissingResourceException.h"
#import "VorbisException.h"

#import "UtilityFunctions.h"

#include "Vorbis/vorbisenc.h"

#include <fcntl.h>		// open, write
#include <stdio.h>		// fopen, fclose
#include <sys/stat.h>	// stat

// My (semi-arbitrary) list of supported vorbis bitrates
static int sVorbisBitrates [14] = { 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320 };

// Tag values for NSPopupButton
enum {
	VORBIS_MODE_QUALITY						= 0,
	VORBIS_MODE_BITRATE						= 1,
};

@implementation OggVorbisEncoder

+ (void) initialize
{
	NSString				*vorbisDefaultsValuesPath;
    NSDictionary			*vorbisDefaultsValuesDictionary;
    
	@try {
		vorbisDefaultsValuesPath = [[NSBundle mainBundle] pathForResource:@"OggVorbisDefaults" ofType:@"plist"];
		if(nil == vorbisDefaultsValuesPath) {
			@throw [MissingResourceException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to load required resource", @"Exceptions", @"")
														userInfo:[NSDictionary dictionaryWithObject:@"OggVorbisDefaults.plist" forKey:@"filename"]];
		}
		vorbisDefaultsValuesDictionary = [NSDictionary dictionaryWithContentsOfFile:vorbisDefaultsValuesPath];
		[[NSUserDefaults standardUserDefaults] registerDefaults:vorbisDefaultsValuesDictionary];
	}
	
	@catch(NSException *exception) {
		displayExceptionAlert(exception);
	}
}

- (id) initWithPCMFilename:(NSString *)inputFilename
{
	if((self = [super initWithPCMFilename:inputFilename])) {
		_mode		= [[NSUserDefaults standardUserDefaults] integerForKey:@"vorbisMode"];
		_quality	= [[NSUserDefaults standardUserDefaults] floatForKey:@"vorbisQuality"];
		_bitrate	= sVorbisBitrates[[[NSUserDefaults standardUserDefaults] integerForKey:@"vorbisBitrate"]] * 1000;
		_cbr		= [[NSUserDefaults standardUserDefaults] boolForKey:@"vorbisUseConstantBitrate"];

		return self;
	}
	return nil;
}

- (oneway void) encodeToFile:(NSString *) filename
{
	NSDate						*startTime									= [NSDate date];	
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
	
	float						*left,				*right;
	int16_t						*alias,				*limit;
		
	NSString					*bundleVersion;

	BOOL						eos											= NO;

	int							pcm											= -1;
	
	int16_t						*buf;
	ssize_t						buflen;

	ssize_t						bytesRead									= 0;
	ssize_t						currentBytesWritten							= 0;
	ssize_t						bytesWritten								= 0;
	ssize_t						bytesToRead									= 0;
	ssize_t						totalBytes									= 0;
	
	unsigned long				iterations									= 0;
	
	// Tell our owner we are starting
	[_delegate setStartTime:startTime];	
	[_delegate setStarted];
	
	@try {
		// Open the input file
		pcm = open([_inputFilename fileSystemRepresentation], O_RDONLY);
		if(-1 == pcm) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to open the input file", @"Exceptions", @"") 
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		// Get input file information
		struct stat sourceStat;
		if(-1 == fstat(pcm, &sourceStat)) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to get information on the input file", @"Exceptions", @"") 
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		// Allocate the buffer (Vorbis crashes if it is too large)
		buflen			= 1024;
		buf				= (int16_t *) calloc(buflen, sizeof(int16_t));
		if(NULL == buf) {
			@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory", @"Exceptions", @"") 
											   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		totalBytes		= sourceStat.st_size;
		bytesToRead		= totalBytes;
		
		// Open the output file
		_out = open([filename fileSystemRepresentation], O_WRONLY | O_TRUNC, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH);
		if(-1 == _out) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to create the output file", @"Exceptions", @"") 
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		// Check if we should stop, and if so throw an exception
		if([_delegate shouldStop]) {
			@throw [StopException exceptionWithReason:@"Stop requested by user" userInfo:nil];
		}
		
		// Setup the encoder
		vorbis_info_init(&vi);
		
		// Use quality-based VBR
		
		if(VORBIS_MODE_QUALITY == _mode) {
			if(vorbis_encode_init_vbr(&vi, 2, 44100, _quality)) {
				@throw [VorbisException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to initialize Ogg Vorbis encoder", @"Exceptions", @"") userInfo:nil];
			}
		}
		else if(VORBIS_MODE_BITRATE == _mode) {
			if(vorbis_encode_init(&vi, 2, 44100, (_cbr ? _bitrate : -1), _bitrate, (_cbr ? _bitrate : -1))) {
				@throw [VorbisException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to initialize Ogg Vorbis encoder", @"Exceptions", @"") userInfo:nil];
			}
		}
		else {
			@throw [NSException exceptionWithName:@"NSInternalInconsistencyException" reason:@"Unrecognized vorbis mode" userInfo:nil];
		}
		
		bundleVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
		
		vorbis_comment_init(&vc);
		vorbis_comment_add_tag(&vc, "ENCODER", (char *)[[NSString stringWithFormat:@"Max %@", bundleVersion] UTF8String]);
		
		vorbis_analysis_init(&vd, &vi);
		vorbis_block_init(&vd, &vb);
		
		// Use the current time as the stream id
		srand(time(NULL));
		if(-1 == ogg_stream_init(&os, rand())) {
			@throw [VorbisException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to initialize ogg stream.", @"Exceptions", @"") userInfo:nil];
		}
		
		// Write stream headers	
		vorbis_analysis_headerout(&vd, &vc, &header, &header_comm, &header_code);
		ogg_stream_packetin(&os, &header);
		ogg_stream_packetin(&os, &header_comm);
		ogg_stream_packetin(&os, &header_code);
		
		for(;;) {
			if(0 == ogg_stream_flush(&os, &og)) {
				break;	
			}
			
			currentBytesWritten = write(_out, og.header, og.header_len);
			if(-1 == currentBytesWritten) {
				@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to write to the output file", @"Exceptions", @"") 
											   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}
			bytesWritten += currentBytesWritten;
			
			currentBytesWritten = write(_out, og.body, og.body_len);
			if(-1 == currentBytesWritten) {
				@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to write to the output file", @"Exceptions", @"") 
											   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}
			bytesWritten += currentBytesWritten;
		}
		
		// Iteratively get the PCM data and encode it
		while(NO == eos) {
			
			// Read a chunk of PCM input
			bytesRead = read(pcm, buf, (bytesToRead > 2 * buflen ? 2 * buflen : bytesToRead));
			if(-1 == bytesRead) {
				@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to read from the input file", @"Exceptions", @"") 
											   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}
			
			// Expose the buffer to submit data
			buffer = vorbis_analysis_buffer(&vd, bytesRead / 4);
			
			left	= buffer[0];
			right	= buffer[1];
			alias	= buf;
			limit	= buf + bytesRead / 2;
			while(alias < limit) {
				*left++		= *alias++ / 32768.0f;
				*right++	= *alias++ / 32768.0f;
			}
			
			// Tell the library how much data we actually submitted
			vorbis_analysis_wrote(&vd, bytesRead / 4);
			
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
						
						currentBytesWritten = write(_out, og.header, og.header_len);
						if(-1 == currentBytesWritten) {
							@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to write to the output file", @"Exceptions", @"") 
														   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
						}
						bytesWritten += currentBytesWritten;
						
						currentBytesWritten = write(_out, og.body, og.body_len);
						if(-1 == currentBytesWritten) {
							@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to write to the output file", @"Exceptions", @"") 
														   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
						}
						bytesWritten += currentBytesWritten;
						
						if(ogg_page_eos(&og)) {
							eos = YES;
						}
					}
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
		NSException *exception;
		// Close the input file
		if(-1 == close(pcm)) {
			exception = [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to close the input file", @"Exceptions", @"") 								
												userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			NSLog(@"%@", exception);
		}

		// Close the output file
		if(-1 == close(_out)) {
			exception = [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to close the output file", @"Exceptions", @"") 
												userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			NSLog(@"%@", exception);
		}
		
		// Clean up
		ogg_stream_clear(&os);
		vorbis_block_clear(&vb);
		vorbis_dsp_clear(&vd);
		vorbis_comment_clear(&vc);
		vorbis_info_clear(&vi);

		free(buf);
	}
	
	[_delegate setEndTime:[NSDate date]];
	[_delegate setCompleted];	
	
//	return bytesWritten;
}

- (NSString *) settings
{
	switch(_mode) {
		case VORBIS_MODE_QUALITY:
			return [NSString stringWithFormat:@"libVorbis settings: VBR(q=%f)", _quality * 10.f];
			break;
			
		case VORBIS_MODE_BITRATE:
			return [NSString stringWithFormat:@"libVorbis settings: %@(%l kbps)", (_cbr ? @"CBR" : @"VBR"), _bitrate / 1000];
			break;
			
		default:
			return nil;
			break;
	}
}

@end
