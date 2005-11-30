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

#import "FLACEncoder.h"
#import "MallocException.h"
#import "IOException.h"
#import "FLACException.h"
#import "StopException.h"
#import "MissingResourceException.h"

#import "UtilityFunctions.h"

#include <fcntl.h>		// open, write
#include <stdio.h>		// fopen, fclose
#include <sys/stat.h>	// stat

@interface FLACEncoder (Private)
- (ssize_t) encodeChunk:(unsigned char *) chunk chunkSize:(ssize_t) chunkSize;
@end

@implementation FLACEncoder

+ (void) initialize
{
	NSString				*flacDefaultsValuesPath;
    NSDictionary			*flacDefaultsValuesDictionary;
    
	@try {
		flacDefaultsValuesPath = [[NSBundle mainBundle] pathForResource:@"FLACDefaults" ofType:@"plist"];
		if(nil == flacDefaultsValuesPath) {
			@throw [MissingResourceException exceptionWithReason:@"Unable to load FLACDefaults.plist." userInfo:nil];
		}
		flacDefaultsValuesDictionary = [NSDictionary dictionaryWithContentsOfFile:flacDefaultsValuesPath];
		[[NSUserDefaults standardUserDefaults] registerDefaults:flacDefaultsValuesDictionary];
	}
	@catch(NSException *exception) {
		displayExceptionAlert(exception);
	}
	@finally {
	}
}

- (id) initWithSource:(NSString *) source
{
	if((self = [super initWithSource:source])) {
		_flac = FLAC__file_encoder_new();
		if(NULL == _flac) {
			@throw [MallocException exceptionWithReason:@"Unable to create FLAC encoder" userInfo:nil];
		}
		return self;
	}
	return nil;
}

- (void) dealloc
{
	FLAC__file_encoder_delete(_flac);
	free(_buf);
	
	[super dealloc];
}

- (ssize_t) encodeToFile:(NSString *) filename
{
	FLAC__FileEncoderState		state				= FLAC__FILE_ENCODER_UNINITIALIZED;
	ssize_t						bytesRead			= 0;
	ssize_t						bytesWritten		= 0;
	ssize_t						bytesToRead			= 0;
	ssize_t						totalBytes			= 0;
	NSDate						*startTime			= [NSDate date];
	
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
	
	// Initialize the FLAC encoder
	if(NO == FLAC__file_encoder_set_total_samples_estimate(_flac, totalBytes / 2)) {
		@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to stat input file (%i:%s)", errno, strerror(errno)] userInfo:nil];
	}
	if(NO == FLAC__file_encoder_set_filename(_flac, [filename UTF8String])) {
		@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to stat input file (%i:%s)", errno, strerror(errno)] userInfo:nil];
	}
	if(FLAC__FILE_ENCODER_OK != FLAC__file_encoder_init(_flac)) {
		@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to stat input file (%i:%s)", errno, strerror(errno)] userInfo:nil];
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
	
	// Finish up the encoding process
	FLAC__file_encoder_finish(_flac);
	
	// Close the input file
	if(-1 == close(_source)) {
		//[self setValue:[NSNumber numberWithBool:YES] forKey:@"stopped"];
		@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to close input file (%i:%s)", errno, strerror(errno)] userInfo:nil];
	}
		
	[self setValue:[NSNumber numberWithBool:YES] forKey:@"completed"];
	[self setValue:[NSNumber numberWithDouble:100.0] forKey:@"percentComplete"];
	
	return 0;//bytesWritten;
}

- (ssize_t) encodeChunk:(unsigned char *) chunk chunkSize:(ssize_t) chunkSize;
{
	int						*rawPCM [2];
	
	int						*leftPCM, *left;
	int						*rightPCM, *right;
	int						numSamples;
	
	const unsigned char		*iter,			*limit;
	unsigned char			temp;
	
	FLAC__bool				flacResult;
	long					bytesWritten;
	
	
	rawPCM[0]		= 0;
	rawPCM[1]		= 0;
	
	@try {
		numSamples	= chunkSize / 2;
		
		rawPCM[0]		= (int *) calloc(numSamples / 2, sizeof(int));
		rawPCM[1]		= (int *) calloc(numSamples / 2, sizeof(int));
		leftPCM			= rawPCM[0];
		rightPCM		= rawPCM[1];
		if(NULL == leftPCM || NULL == rightPCM) {
			[self setValue:[NSNumber numberWithBool:YES] forKey:@"stopped"];
			@throw [MallocException exceptionWithReason:[NSString stringWithFormat:@"Unable to allocate memory (%i:%s)", errno, strerror(errno)] userInfo:nil];
		}
		
		// Raw PCM needs to separated into L/R channels
		iter	= chunk;
		limit	= chunk + chunkSize;
		left	= leftPCM;
		right	= rightPCM;
		while(iter < limit) {
			temp		= *iter++;
			*left++		= (temp << 24) | (*iter++ << 16);
			
			temp		= *iter++;
			*right++	= (temp << 24) | (*iter++ << 16);
		}
		
		// Encode the chunk
		flacResult = FLAC__file_encoder_process(_flac, rawPCM, numSamples / 2);
		
		if(FLAC__FILE_ENCODER_OK > flacResult) {
			[self setValue:[NSNumber numberWithBool:YES] forKey:@"stopped"];
			@throw [FLACException exceptionWithReason:@"FLAC encoding error" userInfo:nil];
		}
	}
	
	@catch(NSException *exception) {
		@throw;
	}
	
	@finally {
		free(leftPCM);
		free(rightPCM);
	}
	
	return 0;//bytesWritten;
}

@end
