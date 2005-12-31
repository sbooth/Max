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

#import "OggFLACEncoder.h"
#import "MallocException.h"
#import "IOException.h"
#import "FLACException.h"
#import "StopException.h"

#import "UtilityFunctions.h"

#include <fcntl.h>		// open, write
#include <stdio.h>		// fopen, fclose
#include <sys/stat.h>	// stat

@interface OggFLACEncoder (Private)
- (ssize_t) encodeChunk:(int16_t *)chunk numSamples:(ssize_t)numSamples;
@end

@implementation OggFLACEncoder

- (id) initWithPCMFilename:(NSString *)pcmFilename
{
	if((self = [super initWithPCMFilename:pcmFilename])) {
		_flac = OggFLAC__file_encoder_new();
		if(NULL == _flac) {
			@throw [MallocException exceptionWithReason:@"Unable to create OggFLAC encoder" userInfo:nil];
		}

		// Setup the OggFLAC encoder
		srand(time(NULL));
		if(NO == OggFLAC__file_encoder_set_serial_number(_flac, rand())) {
			@throw [FLACException exceptionWithReason:[NSString stringWithUTF8String:OggFLAC__FileEncoderStateString[OggFLAC__file_encoder_get_state(_flac)]] userInfo:nil];
		}
		if(NO == OggFLAC__file_encoder_set_do_exhaustive_model_search(_flac, [[NSUserDefaults standardUserDefaults] boolForKey:@"oggFLACExhaustiveModelSearch"])) {
			@throw [FLACException exceptionWithReason:[NSString stringWithUTF8String:OggFLAC__FileEncoderStateString[OggFLAC__file_encoder_get_state(_flac)]] userInfo:nil];
		}
		if(NO == OggFLAC__file_encoder_set_do_mid_side_stereo(_flac, [[NSUserDefaults standardUserDefaults] boolForKey:@"oggFLACEnableMidSide"])) {
			@throw [FLACException exceptionWithReason:[NSString stringWithUTF8String:OggFLAC__FileEncoderStateString[OggFLAC__file_encoder_get_state(_flac)]] userInfo:nil];
		}
		if(NO == OggFLAC__file_encoder_set_loose_mid_side_stereo(_flac, [[NSUserDefaults standardUserDefaults] boolForKey:@"oggFLACEnableLooseMidSide"])) {
			@throw [FLACException exceptionWithReason:[NSString stringWithUTF8String:OggFLAC__FileEncoderStateString[OggFLAC__file_encoder_get_state(_flac)]] userInfo:nil];
		}
		if(NO == OggFLAC__file_encoder_set_qlp_coeff_precision(_flac, [[NSUserDefaults standardUserDefaults] integerForKey:@"oggFLACQLPCoeffPrecision"])) {
			@throw [FLACException exceptionWithReason:[NSString stringWithUTF8String:OggFLAC__FileEncoderStateString[OggFLAC__file_encoder_get_state(_flac)]] userInfo:nil];
		}
		if(NO == OggFLAC__file_encoder_set_min_residual_partition_order(_flac, [[NSUserDefaults standardUserDefaults] integerForKey:@"oggFLACMinPartitionOrder"])) {
			@throw [FLACException exceptionWithReason:[NSString stringWithUTF8String:OggFLAC__FileEncoderStateString[OggFLAC__file_encoder_get_state(_flac)]] userInfo:nil];
		}
		if(NO == OggFLAC__file_encoder_set_max_residual_partition_order(_flac, [[NSUserDefaults standardUserDefaults] integerForKey:@"oggFLACMaxPartitionOrder"])) {
			@throw [FLACException exceptionWithReason:[NSString stringWithUTF8String:OggFLAC__FileEncoderStateString[OggFLAC__file_encoder_get_state(_flac)]] userInfo:nil];
		}
		if(NO == OggFLAC__file_encoder_set_max_lpc_order(_flac, [[NSUserDefaults standardUserDefaults] integerForKey:@"oggFLACMaxLPCOrder"])) {
			@throw [FLACException exceptionWithReason:[NSString stringWithUTF8String:OggFLAC__FileEncoderStateString[OggFLAC__file_encoder_get_state(_flac)]] userInfo:nil];
		}
		
		return self;
	}
	return nil;
}

- (void) dealloc
{
	OggFLAC__file_encoder_delete(_flac);
	free(_buf);
	
	[super dealloc];
}

- (ssize_t) encodeToFile:(NSString *) filename
{
	ssize_t						bytesRead			= 0;
	ssize_t						bytesWritten		= 0;
	ssize_t						bytesToRead			= 0;
	ssize_t						totalBytes			= 0;
	NSDate						*startTime			= [NSDate date];
	
	// Tell our owner we are starting
	[self setValue:[NSNumber numberWithBool:YES] forKey:@"started"];
	[self setValue:[NSNumber numberWithDouble:0.0] forKey:@"percentComplete"];
	
	// Open the input file
	_pcm = open([_pcmFilename UTF8String], O_RDONLY);
	if(-1 == _pcm) {
		[self setValue:[NSNumber numberWithBool:YES] forKey:@"stopped"];
		@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to open input file (%i:%s) [%s:%i]", errno, strerror(errno), __FILE__, __LINE__] userInfo:nil];
	}
	
	// Get input file information
	struct stat sourceStat;
	if(-1 == fstat(_pcm, &sourceStat)) {
		[self setValue:[NSNumber numberWithBool:YES] forKey:@"stopped"];
		@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to stat input file (%i:%s) [%s:%i]", errno, strerror(errno), __FILE__, __LINE__] userInfo:nil];
	}
	
	// Allocate the buffer
	_buflen			= 1024 * 10;
	_buf			= (int16_t *) calloc(_buflen, sizeof(int16_t));
	if(NULL == _buf) {
		[self setValue:[NSNumber numberWithBool:YES] forKey:@"stopped"];
		@throw [MallocException exceptionWithReason:[NSString stringWithFormat:@"Unable to allocate memory (%i:%s) [%s:%i]", errno, strerror(errno), __FILE__, __LINE__] userInfo:nil];
	}
	
	totalBytes		= sourceStat.st_size;
	bytesToRead		= totalBytes;
	
	// Initialize the OggFLAC encoder
	if(NO == OggFLAC__file_encoder_set_total_samples_estimate(_flac, totalBytes / 2)) {
		[self setValue:[NSNumber numberWithBool:YES] forKey:@"stopped"];
		@throw [FLACException exceptionWithReason:[NSString stringWithUTF8String:OggFLAC__FileEncoderStateString[OggFLAC__file_encoder_get_state(_flac)]] userInfo:nil];
	}
	if(NO == OggFLAC__file_encoder_set_filename(_flac, [filename UTF8String])) {
		[self setValue:[NSNumber numberWithBool:YES] forKey:@"stopped"];
		@throw [FLACException exceptionWithReason:[NSString stringWithUTF8String:OggFLAC__FileEncoderStateString[OggFLAC__file_encoder_get_state(_flac)]] userInfo:nil];
	}
	if(OggFLAC__FILE_ENCODER_OK != OggFLAC__file_encoder_init(_flac)) {
		[self setValue:[NSNumber numberWithBool:YES] forKey:@"stopped"];
		@throw [FLACException exceptionWithReason:[NSString stringWithUTF8String:OggFLAC__FileEncoderStateString[OggFLAC__file_encoder_get_state(_flac)]] userInfo:nil];
	}
	
	// Iteratively get the PCM data and encode it
	while(0 < bytesToRead) {
		// Check if we should stop, and if so throw an exception
		if([_shouldStop boolValue]) {
			[self setValue:[NSNumber numberWithBool:YES] forKey:@"stopped"];
			@throw [StopException exceptionWithReason:@"Stop requested by user" userInfo:nil];
		}
		
		// Read a chunk of PCM input
		bytesRead = read(_pcm, _buf, (bytesToRead > 2 * _buflen ? 2 * _buflen : bytesToRead));
		if(-1 == bytesRead) {
			[self setValue:[NSNumber numberWithBool:YES] forKey:@"stopped"];
			@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to read from input file. (%i:%s) [%s:%i]", errno, strerror(errno), __FILE__, __LINE__] userInfo:nil];
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
	
	// Finish up the encoding process
	OggFLAC__file_encoder_finish(_flac);
	
	// Close the input file
	if(-1 == close(_pcm)) {
		//[self setValue:[NSNumber numberWithBool:YES] forKey:@"stopped"];
		@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to close input file (%i:%s) [%s:%i]", errno, strerror(errno), __FILE__, __LINE__] userInfo:nil];
	}
	
	[self setValue:[NSNumber numberWithBool:YES] forKey:@"completed"];
	[self setValue:[NSNumber numberWithDouble:100.0] forKey:@"percentComplete"];
	
	return 0;//bytesWritten;
}

- (ssize_t) encodeChunk:(int16_t *)chunk numSamples:(ssize_t)numSamples
{
	FLAC__bool		flacResult;
	int32_t			*rawPCM [2];
	int32_t			*left, *right;
	int16_t			*iter, *limit;
	
	@try {
		
		rawPCM[0] = calloc(numSamples / 2, sizeof(int32_t));
		rawPCM[1] = calloc(numSamples / 2, sizeof(int32_t));
		if(NULL == rawPCM[0] || NULL == rawPCM[1]) {
			[self setValue:[NSNumber numberWithBool:YES] forKey:@"stopped"];
			@throw [MallocException exceptionWithReason:[NSString stringWithFormat:@"Unable to allocate memory (%i:%s) [%s:%i]", errno, strerror(errno), __FILE__, __LINE__] userInfo:nil];
		}
		
		// Split PCM into channels and convert to 32-bits
		iter	= chunk;
		limit	= chunk + numSamples;
		left	= rawPCM[0];
		right	= rawPCM[1];
		while(iter < limit) {
			*left++		= *iter++;
			*right++	= *iter++;
		}
		
		// Encode the chunk
		flacResult = OggFLAC__file_encoder_process(_flac, rawPCM, numSamples / 2);
		
		if(NO == flacResult) {
			[self setValue:[NSNumber numberWithBool:YES] forKey:@"stopped"];
			@throw [FLACException exceptionWithReason:[NSString stringWithUTF8String:OggFLAC__FileEncoderStateString[OggFLAC__file_encoder_get_state(_flac)]] userInfo:nil];
		}
	}
	
	@catch(NSException *exception) {
		@throw;
	}
	
	@finally {
		free(rawPCM[0]);
		free(rawPCM[1]);
	}
	
	return 0; //bytesWritten;
}	

@end
