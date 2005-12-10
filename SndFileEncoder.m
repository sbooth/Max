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

#import "SndFileEncoder.h"
#import "MallocException.h"
#import "IOException.h"
#import "FLACException.h"
#import "StopException.h"
#import "MissingResourceException.h"

#import "UtilityFunctions.h"

#include "sndfile.h"

#include <fcntl.h>		// open, write
#include <stdio.h>		// fopen, fclose
#include <sys/stat.h>	// stat

@implementation SndFileEncoder

- (id) initWithSource:(NSString *) source format:(int)format
{
	if((self = [super initWithSource:source])) {
		_format = format;
		return self;
	}
	return nil;
}

- (void) dealloc
{
	[super dealloc];
}

- (ssize_t) encodeToFile:(NSString *) filename
{
	SNDFILE						*in					= NULL;
	SNDFILE						*out				= NULL;
	SF_INFO						info;
	const char					*string				= NULL;
	int							i;
	int							err					= 0 ;
	int							bufferLen			= 1024 * 10;
	int							*intBuffer			= NULL;
	double						*doubleBuffer		= NULL;
	double						maxSignal;
	int							frameCount;
	int							readCount;
	
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

	// Setup libsndfile input file
	info.format			= SF_FORMAT_RAW | SF_FORMAT_PCM_16;
	info.samplerate		= 44100;
	info.channels		= 2;
	in					= sf_open_fd(_source, SFM_READ, &info, NO);
	if(NULL == in) {
		[self setValue:[NSNumber numberWithBool:YES] forKey:@"stopped"];
		@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to open input sndfile (%i:%s)", sf_error(NULL), sf_strerror(NULL)] userInfo:nil];
	}

	// Setup libsndfile output file
	info.format			= _format;
	out					= sf_open([filename UTF8String], SFM_WRITE, &info);
	if(NULL == out) {
		[self setValue:[NSNumber numberWithBool:YES] forKey:@"stopped"];
		@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to create output sndfile (%i:%s)", sf_error(NULL), sf_strerror(NULL)] userInfo:nil];
	}
	
	totalBytes		= sourceStat.st_size;

	// Copy metadata
	for(i = SF_STR_FIRST; i <= SF_STR_LAST; ++i) {
		string = sf_get_string(in, i);
		if(NULL != string) {
			err = sf_set_string(out, i, string);
		}
	}

	// Copy audio data
	if(((info.format & SF_FORMAT_SUBMASK) == SF_FORMAT_DOUBLE) || ((info.format & SF_FORMAT_SUBMASK) == SF_FORMAT_FLOAT)) {
		
		doubleBuffer = (double *)malloc(bufferLen * sizeof(double));
		if(NULL == doubleBuffer) {
			[self setValue:[NSNumber numberWithBool:YES] forKey:@"stopped"];
			@throw [MallocException exceptionWithReason:[NSString stringWithFormat:@"Unable to allocate memory (%i:%s)", errno, strerror(errno)] userInfo:nil];
		}
		
		frameCount		= bufferLen / info.channels ;
		readCount		= frameCount ;
		
		sf_command(in, SFC_CALC_SIGNAL_MAX, &maxSignal, sizeof(maxSignal)) ;
		
		if(maxSignal < 1.0) {	
			while(readCount > 0) {
				// Check if we should stop, and if so throw an exception
				if([_shouldStop boolValue]) {
					[self setValue:[NSNumber numberWithBool:YES] forKey:@"stopped"];
					@throw [StopException exceptionWithReason:@"Stop requested by user" userInfo:nil];
				}
				
				readCount = sf_readf_double(in, doubleBuffer, frameCount) ;
				sf_writef_double(out, doubleBuffer, readCount) ;
			}
		}
		// Renormalize output
		else {	
			sf_command(in, SFC_SET_NORM_DOUBLE, NULL, SF_FALSE);
			
			while(0 < readCount) {
				// Check if we should stop, and if so throw an exception
				if([_shouldStop boolValue]) {
					[self setValue:[NSNumber numberWithBool:YES] forKey:@"stopped"];
					@throw [StopException exceptionWithReason:@"Stop requested by user" userInfo:nil];
				}
				
				readCount = sf_readf_double(in, doubleBuffer, frameCount);
				for(i = 0 ; i < readCount * info.channels; ++i) {
					doubleBuffer[i] /= maxSignal;
				}
				
				sf_writef_double(out, doubleBuffer, readCount);
			}
		}
		
		free(doubleBuffer);
	}
	else {
		intBuffer = (int *)malloc(bufferLen * sizeof(int));
		if(NULL == intBuffer) {
			[self setValue:[NSNumber numberWithBool:YES] forKey:@"stopped"];
			@throw [MallocException exceptionWithReason:[NSString stringWithFormat:@"Unable to allocate memory (%i:%s)", errno, strerror(errno)] userInfo:nil];
		}
		
		frameCount		= bufferLen / info.channels;
		readCount		= frameCount;
		
		while(0 < readCount) {	
			// Check if we should stop, and if so throw an exception
			if([_shouldStop boolValue]) {
				[self setValue:[NSNumber numberWithBool:YES] forKey:@"stopped"];
				@throw [StopException exceptionWithReason:@"Stop requested by user" userInfo:nil];
			}

			readCount = sf_readf_int(in, intBuffer, frameCount);
			sf_writef_int(out, intBuffer, readCount);
		}
		
		free(intBuffer);
	}
		
	// Update status
	bytesToRead -= bytesRead;
	[self setValue:[NSNumber numberWithDouble:((double)(totalBytes - bytesToRead)/(double) totalBytes) * 100.0] forKey:@"percentComplete"];
	NSTimeInterval interval = -1.0 * [startTime timeIntervalSinceNow];
	unsigned int timeRemaining = interval / ((double)(totalBytes - bytesToRead)/(double) totalBytes) - interval;
	[self setValue:[NSString stringWithFormat:@"%i:%02i", timeRemaining / 60, timeRemaining % 60] forKey:@"timeRemaining"];

	// Clean up sndfile
	sf_close(in);
	sf_close(out);
	
	// Close the input file
	if(-1 == close(_source)) {
		@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to close input file (%i:%s)", errno, strerror(errno)] userInfo:nil];
	}
	
	[self setValue:[NSNumber numberWithBool:YES] forKey:@"completed"];
	[self setValue:[NSNumber numberWithDouble:100.0] forKey:@"percentComplete"];
	
	return 0;//bytesWritten;
}

@end
