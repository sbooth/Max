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

#import "OggVorbisConverter.h"
#import "MallocException.h"
#import "IOException.h"
#import "StopException.h"
#import "FLACException.h"

#include <unistd.h>		// lseek
#include <fcntl.h>		// open, write
#include <sys/stat.h>	// stat

@implementation OggVorbisConverter

- (id) initWithInputFilename:(NSString *)inputFilename
{
	if((self = [super initWithInputFilename:inputFilename])) {	
		
		@try {
			_file = fopen([_inputFilename UTF8String], "r");
			if(NULL == _file) {
				@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to open the input file", @"Exceptions", @"") 
											   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString"]]];
			}
			
			if(0 != ov_test(_file, &_vf, NULL, 0)) {
				@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Input file does not appear to be an Ogg Vorbis file", @"Exceptions", @"") userInfo:nil];
			}
			
			if(0 != ov_test_open(&_vf)) {
				@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to open the input file", @"Exceptions", @"") userInfo:nil];
			}
		}
				
		@catch(NSException *exception) {
			[_delegate setException:exception];
			[_delegate setStopped];
		}			   
			   
		return self;
	}
	return nil;
}

- (void) dealloc
{
	// Will close _file for us
	if(0 != ov_clear(&_vf)) {
		NSException *exception = [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to close the input file", @"Exceptions", @"") userInfo:nil];
		NSLog(@"%@", exception);
	}
	
	[super dealloc];
}

- (oneway void) convertToFile:(int)file
{
	NSDate			*startTime			= [NSDate date];
	ogg_int64_t		samplesRead			= 0;
	ogg_int64_t		samplesToRead		= 0;
	ogg_int64_t		totalSamples		= 0;
	long			bytesRead;
	int				currentSection;
	char			buf	[1024];
	unsigned long	iterations			= 0;
	
	// Tell our owner we are starting
	[_delegate setStartTime:startTime];	
	[_delegate setStarted];
	
	@try {
		// Get input file information
		totalSamples		= ov_pcm_total(&_vf, -1);
		samplesToRead		= totalSamples;
		
		for(;;) {
			
			// Decode the data
			bytesRead = ov_read(&_vf, buf, 1024, 1, 2, 1, &currentSection);
			
			// Check for errors
			if(0 > bytesRead) {
				@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Ogg Vorbis decode error", @"Exceptions", @"") userInfo:nil];
			}
			
			// EOF?
			if(0 == bytesRead) {
				break;
			}
			
			// Write the PCM data to file
			if(-1 == write(file, buf, bytesRead)) {
				@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to write to the output file", @"Exceptions", @"") 
											   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString"]]];
			}
			
			// Update status
			samplesRead		= ov_pcm_tell(&_vf);
			samplesToRead	= totalSamples - samplesRead;
			
			// Distributed Object calls are expensive, so only perform them every few iterations
			if(0 == iterations % MAX_DO_POLL_FREQUENCY) {
				
				// Check if we should stop, and if so throw an exception
				if([_delegate shouldStop]) {
					@throw [StopException exceptionWithReason:@"Stop requested by user" userInfo:nil];
				}
				
				// Update UI
				double percentComplete = ((double)(totalSamples - samplesToRead)/(double) totalSamples) * 100.0;
				NSTimeInterval interval = -1.0 * [startTime timeIntervalSinceNow];
				unsigned int secondsRemaining = interval / ((double)(totalSamples - samplesToRead)/(double) totalSamples) - interval;
				NSString *timeRemaining = [NSString stringWithFormat:@"%i:%02i", secondsRemaining / 60, secondsRemaining % 60];
				
				[_delegate updateProgress:percentComplete timeRemaining:timeRemaining];
			}
			
			++iterations;
		}
	}

	@catch(StopException *exception) {
		[_delegate setStopped];
	}
	
	@catch(NSException *exception) {
		[_delegate setException:exception];
		[_delegate setStopped];
	}

	[_delegate setEndTime:[NSDate date]];
	[_delegate setCompleted];	
}

@end
