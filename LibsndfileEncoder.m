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
	NSAutoreleasePool			*pool				= nil;
	NSConnection				*connection			= nil;
	LibsndfileEncoder			*encoder			= nil;
	LibsndfileEncoderTask		*owner				= nil;
	
	@try {
		pool			= [[NSAutoreleasePool alloc] init];
		connection		= [NSConnection connectionWithReceivePort:[portArray objectAtIndex:0] sendPort:[portArray objectAtIndex:1]];
		owner			= (LibsndfileEncoderTask *)[connection rootProxy];
		encoder			= [[self alloc] initWithPCMFilename:[owner inputFilename] format:[owner getFormat]];
		
		[encoder setDelegate:owner];
		[owner encoderReady:encoder];
		
		[encoder release];
	}	
	
	@catch(NSException *exception) {
		if(nil != owner) {
			[owner setException:exception];
			[owner setStopped];
		}
	}
	
	@finally {
		if(nil != pool) {
			[pool release];
		}		
	}
}

- (id) initWithPCMFilename:(NSString *)inputFilename format:(int)format
{
	if((self = [super initWithPCMFilename:inputFilename])) {
		_format = format;
		return self;
	}
	return nil;
}

- (oneway void) encodeToFile:(NSString *) filename
{
	NSDate						*startTime			= [NSDate date];
	int							pcm					= -1;
	SNDFILE						*in					= NULL;
	SNDFILE						*out				= NULL;
	SF_INFO						info;
	const char					*string				= NULL;
	int							i;
	int							err					= 0 ;
	int							bufferLen			= 1024;
	int							*intBuffer			= NULL;
	double						*doubleBuffer		= NULL;
	double						maxSignal;
	int							frameCount;
	int							readCount;
	unsigned long				iterations			= 0;
		
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
		
		// Setup libsndfile input file
		info.format			= SF_FORMAT_RAW | SF_FORMAT_PCM_16;
		info.samplerate		= 44100;
		info.channels		= 2;
		in					= sf_open_fd(pcm, SFM_READ, &info, NO);
		if(NULL == in) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to open the input file", @"Exceptions", @"") 
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:sf_error(NULL)], [NSString stringWithUTF8String:sf_strerror(NULL)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		// Setup libsndfile output file
		info.format			= _format;
		out					= sf_open([filename UTF8String], SFM_WRITE, &info);
		if(NULL == out) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to create the output file", @"Exceptions", @"") 
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:sf_error(NULL)], [NSString stringWithUTF8String:sf_strerror(NULL)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
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
				@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory", @"Exceptions", @"") 
												   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}
			
			frameCount		= bufferLen / info.channels ;
			readCount		= frameCount ;
			
			sf_command(in, SFC_CALC_SIGNAL_MAX, &maxSignal, sizeof(maxSignal)) ;
			
			if(maxSignal < 1.0) {	
				while(readCount > 0) {
					// Check if we should stop, and if so throw an exception
					if(0 == iterations % MAX_DO_POLL_FREQUENCY && [_delegate shouldStop]) {
						@throw [StopException exceptionWithReason:@"Stop requested by user" userInfo:nil];
					}
					
					readCount = sf_readf_double(in, doubleBuffer, frameCount) ;
					sf_writef_double(out, doubleBuffer, readCount) ;
					
					++iterations;
				}
			}
			// Renormalize output
			else {	
				sf_command(in, SFC_SET_NORM_DOUBLE, NULL, SF_FALSE);
				
				while(0 < readCount) {
					// Check if we should stop, and if so throw an exception
					if(0 == iterations % MAX_DO_POLL_FREQUENCY && [_delegate shouldStop]) {
						@throw [StopException exceptionWithReason:@"Stop requested by user" userInfo:nil];
					}
					
					readCount = sf_readf_double(in, doubleBuffer, frameCount);
					for(i = 0 ; i < readCount * info.channels; ++i) {
						doubleBuffer[i] /= maxSignal;
					}
					
					sf_writef_double(out, doubleBuffer, readCount);
					
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
				
				readCount = sf_readf_int(in, intBuffer, frameCount);
				sf_writef_int(out, intBuffer, readCount);
				
				++iterations;
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
		free(intBuffer);
		free(doubleBuffer);
		
		if(0 != sf_close(in)) {
			NSException *exception =[IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to close the input file", @"Exceptions", @"") 
															userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:sf_error(NULL)], [NSString stringWithUTF8String:sf_strerror(NULL)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			NSLog(@"%@", exception);
		}
		
		if(0 != sf_close(out)) {
			NSException *exception =[IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to close the output file", @"Exceptions", @"") 
															userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:sf_error(NULL)], [NSString stringWithUTF8String:sf_strerror(NULL)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			NSLog(@"%@", exception);
		}

		// Close the input file
		if(-1 == close(pcm)) {
			NSException *exception = [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to close the input file", @"Exceptions", @"") 
															 userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			NSLog(@"%@", exception);
		}
	}	
	
	[_delegate setEndTime:[NSDate date]];
	[_delegate setCompleted];	
}

@end
