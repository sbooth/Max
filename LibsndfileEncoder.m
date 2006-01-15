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

#import "LibsndfileEncoder.h"
#import "LibsndfileEncoderTask.h"
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

@implementation LibsndfileEncoder

+ (void) connectWithPorts:(NSArray *)portArray
{
	NSAutoreleasePool			*pool;
	NSConnection				*connection;
	LibsndfileEncoder			*encoder;
	LibsndfileEncoderTask		*owner;
	
	pool			= [[NSAutoreleasePool alloc] init];
	connection		= [NSConnection connectionWithReceivePort:[portArray objectAtIndex:0] sendPort:[portArray objectAtIndex:1]];
	owner			= (LibsndfileEncoderTask *)[connection rootProxy];
	encoder			= [[self alloc] initWithPCMFilename:[owner getPCMFilename] format:[owner getFormat]];
	
	[encoder setDelegate:owner];
	[owner encoderReady:encoder];
	
	[encoder release];
	
	[[NSRunLoop currentRunLoop] run];
	
	[pool release];
}

- (id) initWithPCMFilename:(NSString *)pcmFilename format:(int)format
{
	if((self = [super initWithPCMFilename:pcmFilename])) {
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
	NSDate						*startTime			= [NSDate date];
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
	ssize_t						bytesToRead			= 0;
	ssize_t						totalBytes			= 0;
	
	// Tell our owner we are starting
	[_delegate setStartTime:startTime];	
	[_delegate setStarted];
	
	// Open the input file
	_pcm = open([_pcmFilename UTF8String], O_RDONLY);
	if(-1 == _pcm) {
		[_delegate setStopped];
		@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to open input file (%i:%s) [%s:%i]", errno, strerror(errno), __FILE__, __LINE__] userInfo:nil];
	}
	
	// Get input file information
	struct stat sourceStat;
	if(-1 == fstat(_pcm, &sourceStat)) {
		[_delegate setStopped];
		@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to stat input file (%i:%s) [%s:%i]", errno, strerror(errno), __FILE__, __LINE__] userInfo:nil];
	}

	// Setup libsndfile input file
	info.format			= SF_FORMAT_RAW | SF_FORMAT_PCM_16;
	info.samplerate		= 44100;
	info.channels		= 2;
	in					= sf_open_fd(_pcm, SFM_READ, &info, NO);
	if(NULL == in) {
		[_delegate setStopped];
		@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to open input sndfile (%i:%s)", sf_error(NULL), sf_strerror(NULL)] userInfo:nil];
	}

	// Setup libsndfile output file
	info.format			= _format;
	out					= sf_open([filename UTF8String], SFM_WRITE, &info);
	if(NULL == out) {
		[_delegate setStopped];
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
			[_delegate setStopped];
			@throw [MallocException exceptionWithReason:[NSString stringWithFormat:@"Unable to allocate memory (%i:%s) [%s:%i]", errno, strerror(errno), __FILE__, __LINE__] userInfo:nil];
		}
		
		frameCount		= bufferLen / info.channels ;
		readCount		= frameCount ;
		
		sf_command(in, SFC_CALC_SIGNAL_MAX, &maxSignal, sizeof(maxSignal)) ;
		
		if(maxSignal < 1.0) {	
			while(readCount > 0) {
				// Check if we should stop, and if so throw an exception
				if([_delegate shouldStop]) {
					[_delegate setStopped];
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
				if([_delegate shouldStop]) {
					[_delegate setStopped];
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
			[_delegate setStopped];
			@throw [MallocException exceptionWithReason:[NSString stringWithFormat:@"Unable to allocate memory (%i:%s) [%s:%i]", errno, strerror(errno), __FILE__, __LINE__] userInfo:nil];
		}
		
		frameCount		= bufferLen / info.channels;
		readCount		= frameCount;
		
		while(0 < readCount) {	
			// Check if we should stop, and if so throw an exception
			if([_delegate shouldStop]) {
				[_delegate setStopped];
				@throw [StopException exceptionWithReason:@"Stop requested by user" userInfo:nil];
			}

			readCount = sf_readf_int(in, intBuffer, frameCount);
			sf_writef_int(out, intBuffer, readCount);
		}
		
		free(intBuffer);
	}
		
	// Update status
	bytesToRead -= bytesRead;
	[_delegate setPercentComplete:((double)(totalBytes - bytesToRead)/(double) totalBytes) * 100.0];
	NSTimeInterval interval = -1.0 * [startTime timeIntervalSinceNow];
	unsigned int timeRemaining = interval / ((double)(totalBytes - bytesToRead)/(double) totalBytes) - interval;
	[_delegate setTimeRemaining:[NSString stringWithFormat:@"%i:%02i", timeRemaining / 60, timeRemaining % 60]];

	// Clean up sndfile
	sf_close(in);
	sf_close(out);
	
	// Close the input file
	if(-1 == close(_pcm)) {
		@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to close input file (%i:%s) [%s:%i]", errno, strerror(errno), __FILE__, __LINE__] userInfo:nil];
	}
	
	[_delegate setEndTime:[NSDate date]];
	[_delegate setCompleted];	
	
	return 0;//bytesWritten;
}

@end
