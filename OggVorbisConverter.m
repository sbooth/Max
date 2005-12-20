/*
 *  $Id: Encoder.h 153 2005-11-23 22:13:56Z me $
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
		
		_file = fopen([inputFilename UTF8String], "r");
		if(NULL == _file) {
			@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to open input file (%i:%s) [%s:%i]", errno, strerror(errno), __FILE__, __LINE__] userInfo:nil];
		}
		
		if(0 != ov_test(_file, &_vf, NULL, 0)) {
			@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Input file does not appear to be an Ogg Vorbis file [%s:%i]", __FILE__, __LINE__] userInfo:nil];
		}

		if(0 != ov_test_open(&_vf)) {
			@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to open input file [%s:%i]", __FILE__, __LINE__] userInfo:nil];
		}
				
		return self;
	}
	return nil;
}

- (void) dealloc
{
	// Will close _file for us
	if(0 != ov_clear(&_vf)) {
		@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to close input file [%s:%i]", __FILE__, __LINE__] userInfo:nil];
	}
	
	[super dealloc];
}

- (void) convertToFile:(int)file
{
	ogg_int64_t		samplesRead			= 0;
	ogg_int64_t		samplesToRead		= 0;
	ogg_int64_t		totalSamples		= 0;
	long			bytesRead;
	int				currentSection;
	char			buf	[4096];
	
	// Tell our owner we are starting
	_startTime = [[NSDate date] retain];
	
	[self setValue:[NSNumber numberWithBool:YES] forKey:@"started"];
	[self setValue:[NSNumber numberWithDouble:0.0] forKey:@"percentComplete"];
	
	// Get input file information
	totalSamples		= ov_pcm_total(&_vf, -1);
	samplesToRead		= totalSamples;
	
	for(;;) {
		
		// Check if we should stop, and if so throw an exception
		if([_shouldStop boolValue]) {
			[self setValue:[NSNumber numberWithBool:YES] forKey:@"stopped"];
			@throw [StopException exceptionWithReason:@"Stop requested by user" userInfo:nil];
		}
		
		// Decode the data
		bytesRead = ov_read(&_vf, buf, 4096, 1, 2, 1, &currentSection);

		// Check for errors
		if(0 > bytesRead) {
			[self setValue:[NSNumber numberWithBool:YES] forKey:@"stopped"];
			@throw [IOException exceptionWithReason:@"Ogg Vorbis decode error" userInfo:nil];
		}
		
		// EOF?
		if(0 == bytesRead) {
			break;
		}
			
		// Write the PCM data to file
		if(-1 == write(file, buf, bytesRead)) {
			[self setValue:[NSNumber numberWithBool:YES] forKey:@"stopped"];
			@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to write to output file (%i:%s) [%s:%i]", errno, strerror(errno), __FILE__, __LINE__] userInfo:nil];
		}
		
		// Update status
		samplesRead		= ov_pcm_tell(&_vf);
		samplesToRead	= totalSamples - samplesRead;
		[self setValue:[NSNumber numberWithDouble:((double)(totalSamples - samplesToRead)/(double) totalSamples) * 100.0] forKey:@"percentComplete"];
		NSTimeInterval interval = -1.0 * [_startTime timeIntervalSinceNow];
		unsigned int timeRemaining = interval / ((double)(totalSamples - samplesToRead)/(double) totalSamples) - interval;
		[self setValue:[NSString stringWithFormat:@"%i:%02i", timeRemaining / 60, timeRemaining % 60] forKey:@"timeRemaining"];
	}
		
	[self setValue:[NSNumber numberWithBool:YES] forKey:@"completed"];
	[self setValue:[NSNumber numberWithDouble:100.0] forKey:@"percentComplete"];
	
	_endTime = [[NSDate date] retain];
}

@end
