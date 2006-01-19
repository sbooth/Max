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

#import "FLACEncoder.h"
#import "MallocException.h"
#import "IOException.h"
#import "FLACException.h"
#import "StopException.h"

#import "UtilityFunctions.h"

#include <fcntl.h>		// open, write
#include <stdio.h>		// fopen, fclose
#include <sys/stat.h>	// stat

@interface FLACEncoder (Private)
- (ssize_t) encodeChunk:(int16_t *)chunk numSamples:(ssize_t)numSamples;
@end

@implementation FLACEncoder

- (id) initWithPCMFilename:(NSString *)pcmFilename
{
	if((self = [super initWithPCMFilename:pcmFilename])) {
		
		@try {
			_flac = FLAC__file_encoder_new();
			if(NULL == _flac) {
				@throw [FLACException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to create FLAC encoder", @"Exceptions", @"") userInfo:nil];
			}
			
			// Setup the FLAC encoder
			if(NO == FLAC__file_encoder_set_do_exhaustive_model_search(_flac, [[NSUserDefaults standardUserDefaults] boolForKey:@"flacExhaustiveModelSearch"])) {
				@throw [FLACException exceptionWithReason:[NSString stringWithUTF8String:FLAC__FileEncoderStateString[FLAC__file_encoder_get_state(_flac)]] userInfo:nil];
			}
			if(NO == FLAC__file_encoder_set_do_mid_side_stereo(_flac, [[NSUserDefaults standardUserDefaults] boolForKey:@"flacEnableMidSide"])) {
				@throw [FLACException exceptionWithReason:[NSString stringWithUTF8String:FLAC__FileEncoderStateString[FLAC__file_encoder_get_state(_flac)]] userInfo:nil];
			}
			if(NO == FLAC__file_encoder_set_loose_mid_side_stereo(_flac, [[NSUserDefaults standardUserDefaults] boolForKey:@"flacEnableLooseMidSide"])) {
				@throw [FLACException exceptionWithReason:[NSString stringWithUTF8String:FLAC__FileEncoderStateString[FLAC__file_encoder_get_state(_flac)]] userInfo:nil];
			}
			if(NO == FLAC__file_encoder_set_qlp_coeff_precision(_flac, [[NSUserDefaults standardUserDefaults] integerForKey:@"flacQLPCoeffPrecision"])) {
				@throw [FLACException exceptionWithReason:[NSString stringWithUTF8String:FLAC__FileEncoderStateString[FLAC__file_encoder_get_state(_flac)]] userInfo:nil];
			}
			if(NO == FLAC__file_encoder_set_min_residual_partition_order(_flac, [[NSUserDefaults standardUserDefaults] integerForKey:@"flacMinPartitionOrder"])) {
				@throw [FLACException exceptionWithReason:[NSString stringWithUTF8String:FLAC__FileEncoderStateString[FLAC__file_encoder_get_state(_flac)]] userInfo:nil];
			}
			if(NO == FLAC__file_encoder_set_max_residual_partition_order(_flac, [[NSUserDefaults standardUserDefaults] integerForKey:@"flacMaxPartitionOrder"])) {
				@throw [FLACException exceptionWithReason:[NSString stringWithUTF8String:FLAC__FileEncoderStateString[FLAC__file_encoder_get_state(_flac)]] userInfo:nil];
			}
			if(NO == FLAC__file_encoder_set_max_lpc_order(_flac, [[NSUserDefaults standardUserDefaults] integerForKey:@"flacMaxLPCOrder"])) {
				@throw [FLACException exceptionWithReason:[NSString stringWithUTF8String:FLAC__FileEncoderStateString[FLAC__file_encoder_get_state(_flac)]] userInfo:nil];
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
	FLAC__file_encoder_delete(_flac);
	
	[super dealloc];
}

- (oneway void) encodeToFile:(NSString *) filename
{
	NSDate						*startTime			= [NSDate date];
	ssize_t						bytesRead			= 0;
	ssize_t						bytesWritten		= 0;
	ssize_t						bytesToRead			= 0;
	ssize_t						totalBytes			= 0;
	unsigned long				iterations			= 0;
	
	// Tell our owner we are starting
	[_delegate setStartTime:startTime];	
	[_delegate setStarted];
	
	@try {
		// Open the input file
		_pcm = open([_pcmFilename UTF8String], O_RDONLY);
		if(-1 == _pcm) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to open the input file", @"Exceptions", @"") 
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString"]]];
		}
		
		// Get input file information
		struct stat sourceStat;
		if(-1 == fstat(_pcm, &sourceStat)) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to get information on the input file", @"Exceptions", @"") 
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString"]]];
		}
		
		// Allocate the buffer
		_buflen			= 1024;
		_buf			= (int16_t *) calloc(_buflen, sizeof(int16_t));
		if(NULL == _buf) {
			@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory", @"Exceptions", @"") 
											   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString"]]];
		}
		
		totalBytes		= sourceStat.st_size;
		bytesToRead		= totalBytes;
		
		// Initialize the FLAC encoder
		if(NO == FLAC__file_encoder_set_total_samples_estimate(_flac, totalBytes / 2)) {
			@throw [FLACException exceptionWithReason:[NSString stringWithUTF8String:FLAC__FileEncoderStateString[FLAC__file_encoder_get_state(_flac)]] userInfo:nil];
		}
		if(NO == FLAC__file_encoder_set_filename(_flac, [filename UTF8String])) {
			@throw [FLACException exceptionWithReason:[NSString stringWithUTF8String:FLAC__FileEncoderStateString[FLAC__file_encoder_get_state(_flac)]] userInfo:nil];
		}
		if(FLAC__FILE_ENCODER_OK != FLAC__file_encoder_init(_flac)) {
			@throw [FLACException exceptionWithReason:[NSString stringWithUTF8String:FLAC__FileEncoderStateString[FLAC__file_encoder_get_state(_flac)]] userInfo:nil];
		}
		
		// Iteratively get the PCM data and encode it
		while(0 < bytesToRead) {
			
			// Read a chunk of PCM input
			bytesRead = read(_pcm, _buf, (bytesToRead > 2 * _buflen ? 2 * _buflen : bytesToRead));
			if(-1 == bytesRead) {
				@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to read from the input file", @"Exceptions", @"") 
											   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString"]]];
			}
			
			// Encode the PCM data
			bytesWritten += [self encodeChunk:_buf numSamples:bytesRead / 2];
			
			// Update status
			bytesToRead -= bytesRead;
			
			// Distributed Object calls are expensive, so only perform them every few iterations
			if(0 == iterations % MAX_DO_POLL_FREQUENCY) {
				
				// Check if we should stop, and if so throw an exception
				if([_delegate shouldStop]) {
					@throw [StopException exceptionWithReason:@"Stop requested by user" userInfo:nil];
				}
				
				// Update UI
				double percentComplete = ((double)(totalBytes - bytesToRead)/(double) totalBytes) * 100.0;
				NSTimeInterval interval = -1.0 * [startTime timeIntervalSinceNow];
				unsigned int secondsRemaining = interval / ((double)(totalBytes - bytesToRead)/(double) totalBytes) - interval;
				NSString *timeRemaining = [NSString stringWithFormat:@"%i:%02i", secondsRemaining / 60, secondsRemaining % 60];
				
				[_delegate updateProgress:percentComplete timeRemaining:timeRemaining];
			}
			
			++iterations;
		}
		
		// Finish up the encoding process
		FLAC__file_encoder_finish(_flac);
	}
	
	
	@catch(StopException *exception) {
		[_delegate setStopped];
	}
	
	@catch(NSException *exception) {
		[_delegate setException:exception];
		[_delegate setStopped];
	}
	
	@finally {
		// Close the input file
		if(-1 == close(_pcm)) {
			NSException *exception = [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to read from the input file", @"Exceptions", @"") 
															 userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString"]]];
			NSLog(@"%@", exception);
		}
			
		free(_buf);
	}
	
	[_delegate setEndTime:[NSDate date]];
	[_delegate setCompleted];	
}

- (ssize_t) encodeChunk:(int16_t *)chunk numSamples:(ssize_t)numSamples
{
	FLAC__bool		flacResult;
	int32_t			*rawPCM [2];
	int32_t			*left, *right;
	int16_t			*iter, *limit;
	
	@try {
		rawPCM[0] = NULL;
		rawPCM[1] = NULL;
		rawPCM[0] = calloc(numSamples / 2, sizeof(int32_t));
		rawPCM[1] = calloc(numSamples / 2, sizeof(int32_t));
		if(NULL == rawPCM[0] || NULL == rawPCM[1]) {
			@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory", @"Exceptions", @"") 
									   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString"]]];
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
		flacResult = FLAC__file_encoder_process(_flac, rawPCM, numSamples / 2);
		
		if(NO == flacResult) {
			@throw [FLACException exceptionWithReason:[NSString stringWithUTF8String:FLAC__FileEncoderStateString[FLAC__file_encoder_get_state(_flac)]] userInfo:nil];
		}
	}
	
	@catch(NSException *exception) {
		@throw;
	}
	
	@finally {
		free(rawPCM[0]);
		free(rawPCM[1]);
	}
	
	return 0;
}	

- (NSString *) settings
{
	return [NSString stringWithFormat:@"FLAC settings: exhaustiveModelSearch:%i midSideStereo:%i looseMidSideStereo:%i QPLCoeffPrecision:%i, minResidualPartitionOrder:%i, maxResidualPartitionOrder:%i, maxLPCOrder:%i", 
		FLAC__file_encoder_get_do_exhaustive_model_search(_flac),
		FLAC__file_encoder_get_do_mid_side_stereo(_flac),
		FLAC__file_encoder_get_loose_mid_side_stereo(_flac),
		FLAC__file_encoder_get_qlp_coeff_precision(_flac),
		FLAC__file_encoder_get_min_residual_partition_order(_flac),
		FLAC__file_encoder_get_max_residual_partition_order(_flac),
		FLAC__file_encoder_get_max_lpc_order(_flac)];
}

@end
