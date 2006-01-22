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

#import "MPEGEncoder.h"
#import "MallocException.h"
#import "IOException.h"
#import "LAMEException.h"
#import "StopException.h"
#import "MissingResourceException.h"

#import "UtilityFunctions.h"

#include "lame/lame.h"

#include <fcntl.h>		// open, write
#include <stdio.h>		// fopen, fclose
#include <sys/stat.h>	// stat

// Bitrates supported for 44.1 kHz audio
static int sLAMEBitrates [14] = { 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320 };

@interface MPEGEncoder (Private)
- (ssize_t) encodeChunk:(int16_t *)chunk numSamples:(ssize_t)numSamples;
- (ssize_t) finishEncode;
@end

@implementation MPEGEncoder

+ (void) initialize
{
	NSString				*lameDefaultsValuesPath;
    NSDictionary			*lameDefaultsValuesDictionary;
    
	@try {
		lameDefaultsValuesPath = [[NSBundle mainBundle] pathForResource:@"LAMEDefaults" ofType:@"plist"];
		if(nil == lameDefaultsValuesPath) {
			@throw [MissingResourceException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to load required resource", @"Exceptions", @"")
														userInfo:[NSDictionary dictionaryWithObject:@"LAMEDefaults.plist" forKey:@"filename"]];
		}
		lameDefaultsValuesDictionary = [NSDictionary dictionaryWithContentsOfFile:lameDefaultsValuesPath];
		[[NSUserDefaults standardUserDefaults] registerDefaults:lameDefaultsValuesDictionary];
	}
	
	@catch(NSException *exception) {
		displayExceptionAlert(exception);
	}
}

- (id) initWithPCMFilename:(NSString *)inputFilename
{
	int			quality;
	int			bitrate;
	int			lameResult;
	
	
	if((self = [super initWithPCMFilename:inputFilename])) {
		
		@try {
			// LAME setup
			_gfp	= NULL;
			_gfp	= lame_init();
			if(NULL == _gfp) {
				@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory", @"Exceptions", @"") 
									   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}
			
			// We know the input is coming from a CD
			lame_set_num_channels(_gfp, 2);
			lame_set_in_samplerate(_gfp, 44100);
			
			// Write the Xing VBR tag
			lame_set_bWriteVbrTag(_gfp, 1);
			
			// Set encoding properties from user defaults
			lame_set_mode(_gfp, [[NSUserDefaults standardUserDefaults] boolForKey:@"lameMonoEncoding"] ? MONO : JOINT_STEREO);
			
			quality = [[NSUserDefaults standardUserDefaults] integerForKey:@"lameEncodingEngineQuality"];
			if(LAME_ENCODING_ENGINE_QUALITY_FAST == quality) {
				lame_set_quality(_gfp, 7);
			}
			else if(LAME_ENCODING_ENGINE_QUALITY_STANDARD == quality) {
				lame_set_quality(_gfp, 5);
			}
			else if(LAME_ENCODING_ENGINE_QUALITY_HIGH == quality) {
				lame_set_quality(_gfp, 2);
			}
			
			// Target is bitrate
			if(LAME_TARGET_BITRATE == [[NSUserDefaults standardUserDefaults] integerForKey:@"lameTarget"]) {
				bitrate = sLAMEBitrates[[[NSUserDefaults standardUserDefaults] integerForKey:@"lameBitrate"]];
				lame_set_brate(_gfp, bitrate);
				if([[NSUserDefaults standardUserDefaults] boolForKey:@"lameUseConstantBitrate"]) {
					lame_set_VBR(_gfp, vbr_off);
				}
				else {
					lame_set_VBR(_gfp, vbr_default);
					lame_set_VBR_min_bitrate_kbps(_gfp, bitrate);
				}
			}
			// Target is quality
			else if(LAME_TARGET_QUALITY == [[NSUserDefaults standardUserDefaults] integerForKey:@"lameTarget"]) {
				lame_set_VBR(_gfp, LAME_VARIABLE_BITRATE_MODE_FAST == [[NSUserDefaults standardUserDefaults] integerForKey:@"lameVariableBitrateMode"] ? vbr_mtrh : vbr_rh);
				lame_set_VBR_q(_gfp, (100 - [[NSUserDefaults standardUserDefaults] integerForKey:@"lameVBRQuality"]) / 10);
			}
			else {
				@throw [NSException exceptionWithName:@"NSInternalInconsistencyException" reason:@"Unrecognized LAME mode" userInfo:nil];
			}
			
			lameResult = lame_init_params(_gfp);
			if(-1 == lameResult) {
				@throw [LAMEException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to initialize LAME encoder", @"Exceptions", @"") userInfo:nil];
			}
		}

		@catch(NSException *exception) {
			if(NULL != _gfp) {
				lame_close(_gfp);
			}
			
			@throw;
		}
				
		return self;
	}
	
	return nil;
}

- (void) dealloc
{
	lame_close(_gfp);	
	
	[super dealloc];
}

- (oneway void) encodeToFile:(NSString *) filename
{
	NSDate				*startTime			= [NSDate date];
	int					pcm					= -1;
	FILE				*file;
	ssize_t				bytesRead			= 0;
	ssize_t				bytesWritten		= 0;
	ssize_t				bytesToRead			= 0;
	ssize_t				totalBytes			= 0;
	unsigned long		iterations			= 0;
	int16_t				*buf;
	ssize_t				buflen;

	// Tell our owner we are starting
	[_delegate setStartTime:startTime];	
	[_delegate setStarted];
	
	@try {
		// Open the input file
		pcm = open([_inputFilename UTF8String], O_RDONLY);
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
		
		// Allocate the buffer
		buflen		= 1024;
		buf			= (int16_t *) calloc(buflen, sizeof(int16_t));
		if(NULL == buf) {
			@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory", @"Exceptions", @"") 
											   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		totalBytes		= sourceStat.st_size;
		bytesToRead		= totalBytes;
		
		// Open the output file
		_out = open([filename UTF8String], O_WRONLY | O_TRUNC, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH);
		if(-1 == _out) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to create the output file", @"Exceptions", @"") 
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		// Iteratively get the PCM data and encode it
		while(0 < bytesToRead) {
			
			// Read a chunk of PCM input
			bytesRead = read(pcm, buf, (bytesToRead > 2 * buflen ? 2 * buflen : bytesToRead));
			if(-1 == bytesRead) {
				@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to read from the input file", @"Exceptions", @"") 
											   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}
			
			// Encode the PCM data
			bytesWritten += [self encodeChunk:buf numSamples:bytesRead / 2];
			
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
		
		// Flush the last MP3 frames (maybe)
		bytesWritten += [self finishEncode];
		
		// Close the output file
		if(-1 == close(_out)) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to close the output file", @"Exceptions", @"") 
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		_out = -1;
		
		// Write the Xing VBR tag
		file = fopen([filename UTF8String], "r+");
		if(NULL == file) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to open the output file", @"Exceptions", @"") 
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		lame_mp3_tags_fid(_gfp, file);
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
		if(-1 == close(pcm)) {
			NSException *exception = [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to close the input file", @"Exceptions", @"") 
															 userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			NSLog(@"%@", exception);
		}		
		
		// Close the output file if not already closed
		if(-1 != _out && -1 == close(_out)) {
			NSException *exception = [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to close the output file", @"Exceptions", @"") 
															 userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			NSLog(@"%@", exception);
		}

		// And close the other output file
		if(EOF == fclose(file)) {
			NSException *exception =  [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to close the output file", @"Exceptions", @"") 
															  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			NSLog(@"%@", exception);
		}		

		free(buf);
	}

	[_delegate setEndTime:[NSDate date]];
	[_delegate setCompleted];	
}

- (ssize_t) encodeChunk:(int16_t *)chunk numSamples:(ssize_t)numSamples;
{
	u_int8_t		*buf;
	int				bufSize;

	int				lameResult;
	long			bytesWritten;
	
	
	buf = NULL;
	
	@try {
		// Allocate the MP3 buffer using LAME guide for size
		bufSize = 1.25 * numSamples + 7200;
		buf = (u_int8_t *) calloc(bufSize, sizeof(u_int8_t));
		if(NULL == buf) {
			@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory", @"Exceptions", @"") 
									   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		lameResult = lame_encode_buffer_interleaved(_gfp, chunk, numSamples / 2, buf, bufSize);
		if(0 > lameResult) {
			@throw [LAMEException exceptionWithReason:NSLocalizedStringFromTable(@"LAME encoding error", @"Exceptions", @"") userInfo:nil];
		}
		
		bytesWritten = write(_out, buf, lameResult);
		if(-1 == bytesWritten) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to write to the output file", @"Exceptions", @"") 
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
	}
		
	@finally {
		free(buf);
	}
	
	return bytesWritten;
}

- (ssize_t) finishEncode
{
	u_int8_t		*buf;
	int				bufSize;
	
	int				lameResult;
	ssize_t			bytesWritten;
	
	
	buf = NULL;
	
	@try {
		// Allocate the MP3 buffer using LAME guide for size
		bufSize = 7200;
		buf = (u_int8_t *) calloc(bufSize, sizeof(u_int8_t));
		if(NULL == buf) {
			@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory", @"Exceptions", @"") 
									   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		// Flush the mp3 buffer
		lameResult = lame_encode_flush(_gfp, buf, bufSize);
		if(-1 == lameResult) {
			@throw [LAMEException exceptionWithReason:NSLocalizedStringFromTable(@"LAME unable to flush buffers", @"Exceptions", @"") userInfo:nil];
		}
		
		// And write any frames it returns
		bytesWritten = write(_out, buf, lameResult);
		if(-1 == bytesWritten) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to write to the output file", @"Exceptions", @"") 
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
	}
		
	@finally {
		free(buf);
	}
	
	return bytesWritten;
}

- (NSString *) settings
{
	NSString *bitrateString;
	NSString *qualityString;
		
	switch(lame_get_VBR(_gfp)) {
		case vbr_mt:
		case vbr_rh:
		case vbr_mtrh:
//			appendix = "ca. ";
			bitrateString = [NSString stringWithFormat:@"VBR(q=%i)", lame_get_VBR_q(_gfp)];;
			break;
		case vbr_abr:
			bitrateString = [NSString stringWithFormat:@"average %d kbps", lame_get_VBR_mean_bitrate_kbps(_gfp)];;
			break;
		default:
			bitrateString = [NSString stringWithFormat:@"%3d kbps", lame_get_brate(_gfp)];;
			break;
	}
	
//			0.1 * (int) (10. * lame_get_compression_ratio(_gfp) + 0.5),

	qualityString = [NSString stringWithFormat:@"qval=%i", lame_get_quality(_gfp)];
	
	return [NSString stringWithFormat:@"LAME settings: %@ %@", bitrateString, qualityString];
}

@end
