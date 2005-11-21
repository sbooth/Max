/*
 *  $Id$
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

#import "Encoder.h"
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
static int maxBitrates [14] = { 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320 };

@interface Encoder (Private)
- (ssize_t) encodeChunk:(unsigned char *) chunk chunkSize:(ssize_t) chunkSize;
- (ssize_t) finishEncode;
@end

@implementation Encoder

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

- (id) init
{
	@throw [NSException exceptionWithName:@"NSInternalInconsistencyException" reason:@"Encoder::init called" userInfo:nil];
}

- (id) initWithSource:(NSString *) source
{
	NSString	*quality;
	int			bitrate;
	int			lameResult;
	
	
	_gfp				= 0;
	_sourceFilename		= [source retain];
	
	@try {
		if((self = [super init])) {
			
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
			lame_set_mode(_gfp, [[NSUserDefaults standardUserDefaults] boolForKey:@"org.sbooth.Max.lameMonoEncoding"] ? MONO : JOINT_STEREO);
			
			quality = [[NSUserDefaults standardUserDefaults] stringForKey:@"org.sbooth.Max.lameEncodingEngineQuality"];
			if([quality isEqualToString:@"Fast"]) {
				lame_set_quality(_gfp, 7);
			}
			else if([quality isEqualToString:@"Standard"]) {
				lame_set_quality(_gfp, 5);
			}
			else if([quality isEqualToString:@"High"]) {
				lame_set_quality(_gfp, 2);
			}
			
			// Target is bitrate
			if([[[NSUserDefaults standardUserDefaults] stringForKey:@"org.sbooth.Max.lameTarget"] isEqualToString:@"Bitrate"]) {
				bitrate = maxBitrates[[[NSUserDefaults standardUserDefaults] integerForKey:@"org.sbooth.Max.lameBitrate"]];
				lame_set_brate(_gfp, bitrate);
				if([[NSUserDefaults standardUserDefaults] boolForKey:@"org.sbooth.Max.lameUseConstantBitrate"]) {
					lame_set_VBR(_gfp, vbr_off);
				}
				else {
					lame_set_VBR(_gfp, vbr_default);
					lame_set_VBR_min_bitrate_kbps(_gfp, bitrate);
				}
			}
			// Target is quality
			else {
				lame_set_VBR(_gfp, [[[NSUserDefaults standardUserDefaults] stringForKey:@"org.sbooth.Max.lameVariableBitrateMode"] isEqualToString:@"Fast"] ? vbr_mtrh : vbr_rh);
				lame_set_preset(_gfp, 400 + [[NSUserDefaults standardUserDefaults] integerForKey:@"org.sbooth.Max.lameVBRQuality"]);
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
		
		free(_buf);

		[_sourceFilename release];

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
	
	[_sourceFilename release];

	[super dealloc];
}

- (void) requestStop
{
	@synchronized(self) {
		if([_started boolValue]) {
			_shouldStop = [NSNumber numberWithBool:YES];			
		}
		else {
			[self setValue:[NSNumber numberWithBool:YES] forKey:@"stopped"];
		}
	}
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
	_bufsize		= 1024 * 1024;
	_buf			= (unsigned char *) calloc(_bufsize, sizeof(unsigned char));
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
		bytesRead = read(_source, _buf, (bytesToRead > _bufsize ? _bufsize : bytesToRead));

		// Encode the PCM data
		bytesWritten += [self encodeChunk:_buf chunkSize:bytesRead];

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

- (ssize_t) encodeChunk:(unsigned char *) chunk chunkSize:(ssize_t) chunkSize;
{
	int						*leftPCM,		*left;
	int						*rightPCM,		*right;
	int						numSamples;
	
	const unsigned char		*iter,			*limit;
	unsigned char			swap;
	
	unsigned char			*buf;
	int						bufSize;
	
	int						lameResult;
	long					bytesWritten;
	
	
	leftPCM		= 0;
	rightPCM	= 0;
	buf			= 0;

	@try {
		numSamples	= chunkSize / 2;
		
		leftPCM		= (int *) calloc(numSamples / 2, sizeof(int));
		rightPCM	= (int *) calloc(numSamples / 2, sizeof(int));
		if(NULL == leftPCM || NULL == rightPCM) {
			[self setValue:[NSNumber numberWithBool:YES] forKey:@"stopped"];
			@throw [MallocException exceptionWithReason:[NSString stringWithFormat:@"Unable to allocate memory (%i:%s)", errno, strerror(errno)] userInfo:nil];
		}
		
		// Raw PCM needs to be byte-swapped and separated into L/R channels
		iter	= chunk;
		limit	= chunk + chunkSize;
		left	= leftPCM;
		right	= rightPCM;
		while(iter < limit) {
			swap		= *iter++;
			*left++		= (*iter++ << 24) | (swap << 16);
			
			swap		= *iter++;
			*right++	= (*iter++ << 24) | (swap << 16);
		}
		
		// Allocate the MP3 buffer using LAME guide for size
		bufSize = 1.25 * numSamples + 7200;
		buf = (unsigned char *) calloc(bufSize, sizeof(unsigned char));
		if(NULL == buf) {
			[self setValue:[NSNumber numberWithBool:YES] forKey:@"stopped"];
			@throw [MallocException exceptionWithReason:[NSString stringWithFormat:@"Unable to allocate memory (%i:%s)", errno, strerror(errno)] userInfo:nil];
		}
		
		lameResult = lame_encode_buffer_int(_gfp, leftPCM, rightPCM, numSamples / 2, buf, bufSize);
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
		free(leftPCM);
		free(rightPCM);
		free(buf);
	}
	
	return bytesWritten;
}

- (ssize_t) finishEncode
{
	unsigned char		*buf;
	int					bufSize;
	
	int					lameResult;
	ssize_t				bytesWritten;
	
	
	buf = NULL;
	
	@try {
		// Allocate the MP3 buffer using LAME guide for size
		bufSize = 7200;
		buf = (unsigned char *) calloc(bufSize, sizeof(unsigned char));
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
