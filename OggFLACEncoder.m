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

- (id) initWithPCMFilename:(NSString *)inputFilename
{
	if((self = [super initWithPCMFilename:inputFilename])) {
		
		_flac					= NULL;
		
		_exhaustiveModelSearch	= [[NSUserDefaults standardUserDefaults] boolForKey:@"oggFLACExhaustiveModelSearch"];
		_enableMidSide			= [[NSUserDefaults standardUserDefaults] boolForKey:@"oggFLACEnableMidSide"];
		_enableLooseMidSide		= [[NSUserDefaults standardUserDefaults] boolForKey:@"oggFLACLooseEnableMidSide"];
		_QLPCoeffPrecision		= [[NSUserDefaults standardUserDefaults] integerForKey:@"oggFLACQLPCoeffPrecision"];
		_minPartitionOrder		= [[NSUserDefaults standardUserDefaults] integerForKey:@"oggFLACMinPartitionOrder"];
		_maxPartitionOrder		= [[NSUserDefaults standardUserDefaults] integerForKey:@"oggFLACMaxPartitionOrder"];
		_maxLPCOrder			= [[NSUserDefaults standardUserDefaults] integerForKey:@"oggFLACMaxLPCOrder"];
		
		return self;
	}
	return nil;
}

- (oneway void) encodeToFile:(NSString *) filename
{
	NSDate						*startTime			= [NSDate date];
	int							pcm					= -1;
	ssize_t						bytesRead			= 0;
	ssize_t						bytesWritten		= 0;
	ssize_t						bytesToRead			= 0;
	ssize_t						totalBytes			= 0;
	unsigned long				iterations			= 0;
	int16_t						*buf				= NULL;
	ssize_t						buflen				= 0;
	struct stat					sourceStat;
	
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
		
		// Get input file information
		if(-1 == fstat(pcm, &sourceStat)) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to get information on the input file", @"Exceptions", @"") 
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		// Allocate the buffer
		buflen		= 1024;
		buf			= (int16_t *) calloc(buflen, sizeof(int16_t));
		if(NULL == buf) {
			@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory", @"Exceptions", @"") 
											   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		totalBytes		= sourceStat.st_size;
		bytesToRead		= totalBytes;
		
		// Create the Ogg FLAC encoder
		_flac = OggFLAC__file_encoder_new();
		if(NULL == _flac) {
			@throw [FLACException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to create Ogg FLAC encoder", @"Exceptions", @"") userInfo:nil];
		}
		
		// Setup Ogg FLAC encoder
		srand(time(NULL));
		if(NO == OggFLAC__file_encoder_set_serial_number(_flac, rand())) {
			@throw [FLACException exceptionWithReason:[NSString stringWithUTF8String:OggFLAC__FileEncoderStateString[OggFLAC__file_encoder_get_state(_flac)]] userInfo:nil];
		}
		if(NO == OggFLAC__file_encoder_set_do_exhaustive_model_search(_flac, _exhaustiveModelSearch)) {
			@throw [FLACException exceptionWithReason:[NSString stringWithUTF8String:OggFLAC__FileEncoderStateString[OggFLAC__file_encoder_get_state(_flac)]] userInfo:nil];
		}
		if(NO == OggFLAC__file_encoder_set_do_mid_side_stereo(_flac, _enableMidSide)) {
			@throw [FLACException exceptionWithReason:[NSString stringWithUTF8String:OggFLAC__FileEncoderStateString[OggFLAC__file_encoder_get_state(_flac)]] userInfo:nil];
		}
		if(NO == OggFLAC__file_encoder_set_loose_mid_side_stereo(_flac, _enableLooseMidSide)) {
			@throw [FLACException exceptionWithReason:[NSString stringWithUTF8String:OggFLAC__FileEncoderStateString[OggFLAC__file_encoder_get_state(_flac)]] userInfo:nil];
		}
		if(NO == OggFLAC__file_encoder_set_qlp_coeff_precision(_flac, _QLPCoeffPrecision)) {
			@throw [FLACException exceptionWithReason:[NSString stringWithUTF8String:OggFLAC__FileEncoderStateString[OggFLAC__file_encoder_get_state(_flac)]] userInfo:nil];
		}
		if(NO == OggFLAC__file_encoder_set_min_residual_partition_order(_flac, _minPartitionOrder)) {
			@throw [FLACException exceptionWithReason:[NSString stringWithUTF8String:OggFLAC__FileEncoderStateString[OggFLAC__file_encoder_get_state(_flac)]] userInfo:nil];
		}
		if(NO == OggFLAC__file_encoder_set_max_residual_partition_order(_flac, _maxPartitionOrder)) {
			@throw [FLACException exceptionWithReason:[NSString stringWithUTF8String:OggFLAC__FileEncoderStateString[OggFLAC__file_encoder_get_state(_flac)]] userInfo:nil];
		}
		if(NO == OggFLAC__file_encoder_set_max_lpc_order(_flac, _maxLPCOrder)) {
			@throw [FLACException exceptionWithReason:[NSString stringWithUTF8String:OggFLAC__FileEncoderStateString[OggFLAC__file_encoder_get_state(_flac)]] userInfo:nil];
		}

		// Initialize the Ogg FLAC encoder
		if(NO == OggFLAC__file_encoder_set_total_samples_estimate(_flac, totalBytes / 2)) {
			@throw [FLACException exceptionWithReason:[NSString stringWithUTF8String:OggFLAC__FileEncoderStateString[OggFLAC__file_encoder_get_state(_flac)]] userInfo:nil];
		}
		if(NO == OggFLAC__file_encoder_set_filename(_flac, [filename UTF8String])) {
			@throw [FLACException exceptionWithReason:[NSString stringWithUTF8String:OggFLAC__FileEncoderStateString[OggFLAC__file_encoder_get_state(_flac)]] userInfo:nil];
		}
		if(OggFLAC__FILE_ENCODER_OK != OggFLAC__file_encoder_init(_flac)) {
			@throw [FLACException exceptionWithReason:[NSString stringWithUTF8String:OggFLAC__FileEncoderStateString[OggFLAC__file_encoder_get_state(_flac)]] userInfo:nil];
		}
		
		// Iteratively get the PCM data and encode it
		while(0 < bytesToRead) {
			
			// Read a chunk of PCM input
			bytesRead = read(pcm, buf, (bytesToRead > 2 * buflen ? 2 * buflen : bytesToRead));
			if(-1 == bytesRead) {
				@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to read from the input file", @"Exceptions", @"") 
											   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}
			
			// Encode the PCM data
			bytesWritten += [self encodeChunk:buf numSamples:bytesRead / 2];
			
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
		OggFLAC__file_encoder_finish(_flac);
	}
	
	@catch(StopException *exception) {
		[_delegate setStopped];
	}
	
	@catch(NSException *exception) {
		[_delegate setException:exception];
		[_delegate setStopped];
	}
	
	@finally {
		OggFLAC__file_encoder_delete(_flac);

		// Close the input file
		if(-1 == close(pcm)) {
			NSException *exception = [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to read from the input file", @"Exceptions", @"") 
															 userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			NSLog(@"%@", exception);
		}
		
		free(buf);
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
									   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
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
		flacResult = OggFLAC__file_encoder_process(_flac, (const int32_t * const *)rawPCM, numSamples / 2);
		
		if(NO == flacResult) {
			@throw [FLACException exceptionWithReason:[NSString stringWithUTF8String:OggFLAC__FileEncoderStateString[OggFLAC__file_encoder_get_state(_flac)]] userInfo:nil];
		}
	}
		
	@finally {
		free(rawPCM[0]);
		free(rawPCM[1]);
	}
	
	return 0; //bytesWritten;
}	

- (NSString *) settings
{
	return [NSString stringWithFormat:@"Ogg FLAC settings: exhaustiveModelSearch:%i midSideStereo:%i looseMidSideStereo:%i QPLCoeffPrecision:%i, minResidualPartitionOrder:%i, maxResidualPartitionOrder:%i, maxLPCOrder:%i", 
		_exhaustiveModelSearch, _enableMidSide, _enableLooseMidSide, _QLPCoeffPrecision, _minPartitionOrder, _maxPartitionOrder, _maxLPCOrder];
}

@end
