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

#import "LibsndfileConverter.h"

#import "MallocException.h"
#import "IOException.h"
#import "StopException.h"

#include <fcntl.h>		// open, write
#include <sys/stat.h>	// stat

@interface LibsndfileConverter (Private)
- (void) openInputFile;
- (void) closeInputFile:(BOOL)throw;
@end

@implementation LibsndfileConverter

- (id) initWithInputFile:(NSString *)inputFilename
{
	if((self = [super initWithInputFile:inputFilename])) {

		@try {
			// Open the input file to get the file's information
			[self openInputFile];
		}
		
		@finally {
			// Close to avoid too many open file descriptors
			[self closeInputFile:YES];
		}
		
		return self;
	}
	return nil;
}

- (void) dealloc
{
	[_fileType release];	_fileType = nil;
	
	[super dealloc];
}

- (void) openInputFile
{
	SF_INFO					info;
	SF_FORMAT_INFO			formatInfo;
	
	// Open the input file
	info.format = 0;
	
	_in = sf_open([_inputFilename fileSystemRepresentation], SFM_READ, &info);
	if(NULL == _in) {
		@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to open the input file.", @"Exceptions", @"") 
									   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:sf_error(NULL)], [NSString stringWithCString:sf_strerror(NULL) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
	}
	
	[self setSampleRate:info.samplerate];
	[self setChannelsPerFrame:info.channels];
	
	switch(SF_FORMAT_SUBMASK & info.format) {
		case SF_FORMAT_PCM_S8:			[self setBitsPerChannel:8];				break;
		case SF_FORMAT_PCM_16:			[self setBitsPerChannel:16];			break;
		case SF_FORMAT_PCM_24:			[self setBitsPerChannel:24];			break;
		case SF_FORMAT_PCM_32:			[self setBitsPerChannel:32];			break;
	}
	
	// Get format info
	formatInfo.format = info.format;
	
	if(0 == sf_command(NULL, SFC_GET_FORMAT_INFO, &formatInfo, sizeof(formatInfo))) {
		_fileType = [[NSString stringWithCString:formatInfo.name encoding:NSASCIIStringEncoding] retain];
	}
	else {
		_fileType = NSLocalizedStringFromTable(@"Unknown (libsndfile)", @"General", @"");
	}
}

- (void) closeInputFile:(BOOL)throw
{
	if(0 != sf_close(_in)) {
		if(throw) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to close the input file.", @"Exceptions", @"") 
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:sf_error(NULL)], [NSString stringWithCString:sf_strerror(NULL) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		else {
			NSException *exception =[IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to close the input file.", @"Exceptions", @"") 
															userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:sf_error(NULL)], [NSString stringWithCString:sf_strerror(NULL) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			NSLog(@"%@", exception);
		}
	}
}

- (oneway void) convertToFile:(NSString *)filename
{
	NSDate						*startTime			= [NSDate date];
	SNDFILE						*out				= NULL;
	SF_INFO						info;
	int							subtype;
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
	[_delegate setInputFormat:_fileType];
			
	@try {
		// Open input file
		[self openInputFile];
		
		// Setup libsndfile output file
		switch([self bitsPerChannel]) {
			case 8:			subtype = SF_FORMAT_PCM_S8;			break;
			case 16:		subtype = SF_FORMAT_PCM_16;			break;
			case 24:		subtype = SF_FORMAT_PCM_24;			break;
			case 32:		subtype = SF_FORMAT_PCM_32;			break;
				
			default:
				@throw [NSException exceptionWithName:@"IllegalInputException" reason:@"Sample size not supported" userInfo:nil]; 
				break;
		}
		
		info.format			= SF_FORMAT_AIFF | subtype;
		info.samplerate		= [self sampleRate];
		info.channels		= [self channelsPerFrame];
		out					= sf_open([filename fileSystemRepresentation], SFM_WRITE, &info);
		if(NULL == out) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to open the output file.", @"Exceptions", @"") 
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:sf_error(NULL)], [NSString stringWithCString:sf_strerror(NULL) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
				
		// Copy metadata
		for(i = SF_STR_FIRST; i <= SF_STR_LAST; ++i) {
			string = sf_get_string(_in, i);
			if(NULL != string) {
				err = sf_set_string(out, i, string);
			}
		}
		
		// Copy audio data
		if(((info.format & SF_FORMAT_SUBMASK) == SF_FORMAT_DOUBLE) || ((info.format & SF_FORMAT_SUBMASK) == SF_FORMAT_FLOAT)) {
			
			doubleBuffer = (double *)malloc(bufferLen * sizeof(double));
			if(NULL == doubleBuffer) {
				@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @"") 
												   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}
			
			frameCount		= bufferLen / info.channels ;
			readCount		= frameCount ;
			
			sf_command(_in, SFC_CALC_SIGNAL_MAX, &maxSignal, sizeof(maxSignal)) ;
			
			if(maxSignal < 1.0) {	
				while(readCount > 0) {
					// Check if we should stop, and if so throw an exception
					if(0 == iterations % MAX_DO_POLL_FREQUENCY && [_delegate shouldStop]) {
						@throw [StopException exceptionWithReason:@"Stop requested by user" userInfo:nil];
					}
					
					readCount = sf_readf_double(_in, doubleBuffer, frameCount) ;
					sf_writef_double(out, doubleBuffer, readCount) ;
					
					++iterations;
				}
			}
			// Renormalize output
			else {	
				sf_command(_in, SFC_SET_NORM_DOUBLE, NULL, SF_FALSE);
				
				while(0 < readCount) {
					// Check if we should stop, and if so throw an exception
					if(0 == iterations % MAX_DO_POLL_FREQUENCY && [_delegate shouldStop]) {
						@throw [StopException exceptionWithReason:@"Stop requested by user" userInfo:nil];
					}
					
					readCount = sf_readf_double(_in, doubleBuffer, frameCount);
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
				@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @"") 
												   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}
			
			frameCount		= bufferLen / info.channels;
			readCount		= frameCount;
			
			while(0 < readCount) {	
				// Check if we should stop, and if so throw an exception
				if(0 == iterations % MAX_DO_POLL_FREQUENCY && [_delegate shouldStop]) {
					@throw [StopException exceptionWithReason:@"Stop requested by user" userInfo:nil];
				}
				
				readCount = sf_readf_int(_in, intBuffer, frameCount);
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
		[self closeInputFile:NO];
		if(0 != sf_close(out)) {
			NSException *exception =[IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to close the input file.", @"Exceptions", @"") 
															userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:sf_error(NULL)], [NSString stringWithCString:sf_strerror(NULL) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			NSLog(@"%@", exception);
		}
	}
	
	[_delegate setEndTime:[NSDate date]];
	[_delegate setCompleted];	
}

@end
