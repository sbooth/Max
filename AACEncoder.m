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

#import "AACEncoder.h"

#import "MallocException.h"
#import "IOException.h"
#import "StopException.h"

#include "faac.h"
#include "faaccfg.h"

#include <fcntl.h>		// open, write
#include <sys/stat.h>	// stat

// My (semi-arbitrary) list of supported AAC bitrates
static int sAACBitrates [14] = { 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320 };

// Tag values for NSPopupButton
enum {
	FAAC_MODE_QUALITY						= 0,
	FAAC_MODE_BITRATE						= 1,
	
	FAAC_SHORT_CONTROL_BOTH					= 1,
	FAAC_SHORT_CONTROL_SHORT_ONLY			= 2,
	FAAC_SHORT_CONTROL_LONG_ONLY			= 3
};

@interface AACEncoder (Private)
- (ssize_t) encodeChunk:(int16_t *)chunk numSamples:(ssize_t)numSamples;
- (ssize_t) finishEncode;
@end

@implementation AACEncoder

- (id) initWithSource:(NSString *)source
{	
	faacEncConfigurationPtr		faacConf;
	
	if((self = [super initWithSource:source])) {
		_faac = faacEncOpen(44100, 2, &_inputSamples, &_maxOutputBytes);
		if(NULL == _faac) {
			@throw [MallocException exceptionWithReason:@"Unable to create AAC encoder" userInfo:nil];
		}
		
		faacConf					= faacEncGetCurrentConfiguration(_faac);
		faacConf->inputFormat		= FAAC_INPUT_16BIT;
		faacConf->aacObjectType		= LOW;
		faacConf->mpegVersion		= MPEG2;
		
		faacConf->useTns			= [[NSUserDefaults standardUserDefaults] boolForKey:@"faacEnableTNS"];
		faacConf->allowMidside		= [[NSUserDefaults standardUserDefaults] boolForKey:@"faacEnableMidside"];

		switch([[NSUserDefaults standardUserDefaults] integerForKey:@"faacShortControl"]) {
			case FAAC_SHORT_CONTROL_BOTH:			faacConf->shortctl = SHORTCTL_NORMAL;		break;
			case FAAC_SHORT_CONTROL_LONG_ONLY:		faacConf->shortctl = SHORTCTL_NOSHORT;		break;
			case FAAC_SHORT_CONTROL_SHORT_ONLY:		faacConf->shortctl = SHORTCTL_NOLONG;		break;
		}

		if([[NSUserDefaults standardUserDefaults] boolForKey:@"faacUseCustomLowpass"]) {
			faacConf->bandWidth = [[NSUserDefaults standardUserDefaults] integerForKey:@"faacCustomLowpass"];
		}
		
		
		// Use quality-based VBR
		if(FAAC_MODE_QUALITY == [[NSUserDefaults standardUserDefaults] integerForKey:@"faacMode"]) {
			faacConf->quantqual = [[NSUserDefaults standardUserDefaults] integerForKey:@"faacQuality"];
		}
		else if(FAAC_MODE_BITRATE == [[NSUserDefaults standardUserDefaults] integerForKey:@"faacMode"]) {
			int bitrate = sAACBitrates[[[NSUserDefaults standardUserDefaults] integerForKey:@"faacBitrate"]] * 1000;
			faacConf->bitRate = bitrate / 2; // numChannels
		}
		else {
			@throw [NSException exceptionWithName:@"NSInternalInconsistencyException" reason:@"Unrecognized faac mode" userInfo:nil];
		}
		
		faacEncSetConfiguration(_faac, faacConf);
		
		return self;
	}
	return nil;
}

- (void) dealloc
{
	faacEncClose(_faac);
	[super dealloc];
}

- (ssize_t) encodeToFile:(NSString *) filename
{
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
	_buflen			= _inputSamples;
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
	
	// Flush the last frames
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
		
	[self setValue:[NSNumber numberWithBool:YES] forKey:@"completed"];
	[self setValue:[NSNumber numberWithDouble:100.0] forKey:@"percentComplete"];
	
	return bytesWritten;
}

- (ssize_t) encodeChunk:(int16_t *)chunk numSamples:(ssize_t)numSamples;
{
	u_int8_t		*buf;
	int				bufSize;
	
	int				faacResult;
	long			bytesWritten;
	
	
	buf = NULL;
	
	@try {
		// Allocate the buffer
		bufSize = _maxOutputBytes;
		buf = (u_int8_t *) calloc(bufSize, sizeof(u_int8_t));
		if(NULL == buf) {
			[self setValue:[NSNumber numberWithBool:YES] forKey:@"stopped"];
			@throw [MallocException exceptionWithReason:[NSString stringWithFormat:@"Unable to allocate memory (%i:%s)", errno, strerror(errno)] userInfo:nil];
		}
				
		faacResult = faacEncEncode(_faac, (int32_t *)chunk, numSamples, buf, bufSize);
		if(0 > faacResult) {
			[self setValue:[NSNumber numberWithBool:YES] forKey:@"stopped"];
			@throw [IOException exceptionWithReason:@"FAAC encoding error" userInfo:nil];
		}
		
		bytesWritten = write(_out, buf, faacResult);
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
	
	int				faacResult;
	ssize_t			bytesWritten;
	
	
	buf = NULL;
	
	@try {
		// Allocate the buffer
		bufSize = _maxOutputBytes;
		buf = (u_int8_t *) calloc(bufSize, sizeof(u_int8_t));
		if(NULL == buf) {
			[self setValue:[NSNumber numberWithBool:YES] forKey:@"stopped"];
			@throw [MallocException exceptionWithReason:[NSString stringWithFormat:@"Unable to allocate memory (%i:%s)", errno, strerror(errno)] userInfo:nil];
		}
		
		// Flush the buffer
		while((faacResult = faacEncEncode(_faac, NULL, 0, buf, bufSize))) {
			if(0 > faacResult) {
				[self setValue:[NSNumber numberWithBool:YES] forKey:@"stopped"];
				@throw [IOException exceptionWithReason:@"FAAC encoding error" userInfo:nil];
			}
			
			bytesWritten = write(_out, buf, faacResult);
			if(-1 == bytesWritten) {
				[self setValue:[NSNumber numberWithBool:YES] forKey:@"stopped"];
				@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to write to output file (%i:%s)", errno, strerror(errno)] userInfo:nil];
			}
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
