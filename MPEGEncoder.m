/*
 *  $Id: Encoder.m 175 2005-11-25 04:56:46Z me $
 *
 *  Copyright (C) 2005 Stephen F. Booth <me@sbooth.org>
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

#include <fcntl.h>		// open, write
#include <stdio.h>		// fopen, fclose
#include <sys/stat.h>	// stat

// Bitrates supported for 44.1 kHz audio
static int sLAMEBitrates [14] = { 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320 };

@interface MPEGEncoder (Private)
- (ssize_t) encodeChunk:(int16_t *)chunk numSamples:(ssize_t)numSamples;
- (ssize_t) finishEncode;
@end

// Tag values for NSPopupButton
enum {
	LAME_TARGET_BITRATE						= 0,
	LAME_TARGET_QUALITY						= 1,
	
	LAME_ENCODING_ENGINE_QUALITY_FAST		= 0,
	LAME_ENCODING_ENGINE_QUALITY_STANDARD	= 1,
	LAME_ENCODING_ENGINE_QUALITY_HIGH		= 2,
	
	LAME_VARIABLE_BITRATE_MODE_STANDARD		= 0,
	LAME_VARIABLE_BITRATE_MODE_FAST			= 1
};

@implementation MPEGEncoder

+ (void) initialize
{
	NSString				*lameDefaultsValuesPath;
    NSDictionary			*lameDefaultsValuesDictionary;
    
	@try {
		lameDefaultsValuesPath = [[NSBundle mainBundle] pathForResource:@"LAMEDefaults" ofType:@"plist"];
		if(nil == lameDefaultsValuesPath) {
			@throw [MissingResourceException exceptionWithReason:@"Unable to load LAMEDefaults.plist." userInfo:nil];
		}
		lameDefaultsValuesDictionary = [NSDictionary dictionaryWithContentsOfFile:lameDefaultsValuesPath];
		[[NSUserDefaults standardUserDefaults] registerDefaults:lameDefaultsValuesDictionary];
	}
	@catch(NSException *exception) {
		displayExceptionAlert(exception);
	}
	@finally {
	}
}

- (id) initWithSource:(NSString *) source
{
	int			quality;
	int			bitrate;
	int			lameResult;
	
	
	_gfp				= 0;
	
	@try {
		if((self = [super initWithSource:source])) {
			
			// LAME setup
			_gfp = lame_init();
			if(NULL == _gfp) {
				[self setValue:[NSNumber numberWithBool:YES] forKey:@"stopped"];
				@throw [MallocException exceptionWithReason:[NSString stringWithFormat:@"Unable to allocate memory (%i:%s)", errno, strerror(errno)] userInfo:nil];
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
				[self setValue:[NSNumber numberWithBool:YES] forKey:@"stopped"];
				@throw [NSException exceptionWithName:@"NSInternalInconsistencyException" reason:@"Unrecognized LAME mode" userInfo:nil];
			}
			
			lameResult = lame_init_params(_gfp);
			if(-1 == lameResult) {
				[self setValue:[NSNumber numberWithBool:YES] forKey:@"stopped"];
				@throw [LAMEException exceptionWithReason:@"Failure initializing LAME library" userInfo:nil];
			}
		}
	}
	@catch(NSException *exception) {
		
		if(0 != _gfp) {
			lame_close(_gfp);
		}
		
		@throw;
	}
	
	@finally {
	}
	
	return self;
}

- (void) dealloc
{
	lame_close(_gfp);	
	free(_buf);
	
	[super dealloc];
}

- (ssize_t) encodeToFile:(NSString *) filename
{
	FILE		*file;
	ssize_t		bytesRead			= 0;
	ssize_t		bytesWritten		= 0;
	ssize_t		bytesToRead			= 0;
	ssize_t		totalBytes			= 0;
	NSDate		*startTime			= [NSDate date];
	
	// Tell our owner we are starting
	[self setValue:[NSNumber numberWithBool:YES] forKey:@"started"];
	[self setValue:[NSNumber numberWithDouble:0.0] forKey:@"percentComplete"];
	
	// Open the input file
	_source = open([_sourceFilename UTF8String], O_RDONLY);
	if(-1 == _source) {
		[self setValue:[NSNumber numberWithBool:YES] forKey:@"stopped"];
		@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to open input file (%i:%s)", errno, strerror(errno)] userInfo:nil];
	}
	
	// Get input file information
	struct stat sourceStat;
	if(-1 == fstat(_source, &sourceStat)) {
		[self setValue:[NSNumber numberWithBool:YES] forKey:@"stopped"];
		@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to stat input file (%i:%s)", errno, strerror(errno)] userInfo:nil];
	}
	
	// Allocate the buffer
	_buflen			= 1024 * 10;
	_buf			= (int16_t *) calloc(_buflen, sizeof(int16_t));
	if(NULL == _buf) {
		[self setValue:[NSNumber numberWithBool:YES] forKey:@"stopped"];
		@throw [MallocException exceptionWithReason:[NSString stringWithFormat:@"Unable to allocate memory (%i:%s)", errno, strerror(errno)] userInfo:nil];
	}
	
	totalBytes		= sourceStat.st_size;
	bytesToRead		= totalBytes;
	
	// Create the output file
	_out = open([filename UTF8String], O_WRONLY | O_CREAT | O_EXCL, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH);
	if(-1 == _out) {
		[self setValue:[NSNumber numberWithBool:YES] forKey:@"stopped"];
		@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to create the output file. (%i:%s)", errno, strerror(errno)] userInfo:nil];
	}
	
	// Iteratively get the PCM data and encode it
	while(0 < bytesToRead) {
		// Check if we should stop, and if so throw an exception
		if([_shouldStop boolValue]) {
			[self setValue:[NSNumber numberWithBool:YES] forKey:@"stopped"];
			@throw [StopException exceptionWithReason:@"Stop requested by user" userInfo:nil];
		}
		
		// Read a chunk of PCM input
		bytesRead = read(_source, _buf, (bytesToRead > 2 * _buflen ? 2 * _buflen : bytesToRead));
		if(-1 == bytesRead) {
			[self setValue:[NSNumber numberWithBool:YES] forKey:@"stopped"];
			@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to read from input file. (%i:%s)", errno, strerror(errno)] userInfo:nil];
		}
		
		// Encode the PCM data
		bytesWritten += [self encodeChunk:_buf numSamples:bytesRead / 2];
		
		// Update status
		bytesToRead -= bytesRead;
		[self setValue:[NSNumber numberWithDouble:((double)(totalBytes - bytesToRead)/(double) totalBytes) * 100.0] forKey:@"percentComplete"];
		NSTimeInterval interval = -1.0 * [startTime timeIntervalSinceNow];
		unsigned int timeRemaining = interval / ((double)(totalBytes - bytesToRead)/(double) totalBytes) - interval;
		[self setValue:[NSString stringWithFormat:@"%i:%02i", timeRemaining / 60, timeRemaining % 60] forKey:@"timeRemaining"];
	}
	
	// Flush the last MP3 frames (maybe)
	bytesWritten += [self finishEncode];
	
	// Close the input file
	if(-1 == close(_source)) {
		//[self setValue:[NSNumber numberWithBool:YES] forKey:@"stopped"];
		@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to close input file (%i:%s)", errno, strerror(errno)] userInfo:nil];
	}
	
	// Close the output file
	if(-1 == close(_out)) {
		//[self setValue:[NSNumber numberWithBool:YES] forKey:@"stopped"];
		@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to close output file (%i:%s)", errno, strerror(errno)] userInfo:nil];
	}
	
	// Write the Xing VBR tag
	file = fopen([filename UTF8String], "r+");
	if(NULL == file) {
		[self setValue:[NSNumber numberWithBool:YES] forKey:@"stopped"];
		@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to open output file (%i:%s)", errno, strerror(errno)] userInfo:nil];
	}
	lame_mp3_tags_fid(_gfp, file);
	if(EOF == fclose(file)) {
		//[self setValue:[NSNumber numberWithBool:YES] forKey:@"stopped"];
		@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to close output file (%i:%s)", errno, strerror(errno)] userInfo:nil];
	}
	
	[self setValue:[NSNumber numberWithBool:YES] forKey:@"completed"];
	[self setValue:[NSNumber numberWithDouble:100.0] forKey:@"percentComplete"];
	
	return bytesWritten;
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
			[self setValue:[NSNumber numberWithBool:YES] forKey:@"stopped"];
			@throw [MallocException exceptionWithReason:[NSString stringWithFormat:@"Unable to allocate memory (%i:%s)", errno, strerror(errno)] userInfo:nil];
		}
		
		lameResult = lame_encode_buffer_interleaved(_gfp, chunk, numSamples / 2, buf, bufSize);
		if(0 > lameResult) {
			[self setValue:[NSNumber numberWithBool:YES] forKey:@"stopped"];
			@throw [LAMEException exceptionWithReason:@"LAME encoding error" userInfo:nil];
		}
		
		bytesWritten = write(_out, buf, lameResult);
		if(-1 == bytesWritten) {
			[self setValue:[NSNumber numberWithBool:YES] forKey:@"stopped"];
			@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to write to output file (%i:%s)", errno, strerror(errno)] userInfo:nil];
		}
	}
	
	@catch(NSException *exception) {
		@throw;
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
			[self setValue:[NSNumber numberWithBool:YES] forKey:@"stopped"];
			@throw [MallocException exceptionWithReason:[NSString stringWithFormat:@"Unable to allocate memory (%i:%s)", errno, strerror(errno)] userInfo:nil];
		}
		
		// Flush the mp3 buffer
		lameResult = lame_encode_flush(_gfp, buf, bufSize);
		if(-1 == lameResult) {
			[self setValue:[NSNumber numberWithBool:YES] forKey:@"stopped"];
			@throw [LAMEException exceptionWithReason:@"LAME unable to flush buffers" userInfo:nil];
		}
		
		// And write any frames it returns
		bytesWritten = write(_out, buf, lameResult);
		if(-1 == bytesWritten) {
			[self setValue:[NSNumber numberWithBool:YES] forKey:@"stopped"];
			@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to write to output file (%i:%s)", errno, strerror(errno)] userInfo:nil];
		}
	}
	
	@catch(NSException *exception) {
		@throw;
	}
	
	@finally {
		free(buf);
	}
	
	return bytesWritten;
}

@end
