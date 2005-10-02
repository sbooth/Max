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

#import "Encoder.h"
#import "MallocException.h"
#import "IOException.h"
#import "LAMEException.h"
#import "StopException.h"
#import "MissingResourceException.h"

#import "UtilityFunctions.h"

#include <fcntl.h>	// open, write
#include <stdio.h>	// fopen, fclose

// Bitrates supported for 44.1 kHz audio
static int maxBitrates [14] = { 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320 };

@implementation Encoder

+ (void) initialize
{
	NSString				*lameDefaultsValuesPath;
    NSDictionary			*lameDefaultsValuesDictionary;
    
	@try {
		lameDefaultsValuesPath = [[NSBundle mainBundle] pathForResource:@"LAMEDefaults" ofType:@"plist"];
		if(nil == lameDefaultsValuesPath) {
			@throw [MissingResourceException exceptionWithReason:@"Unable to load LAMEDefaults.plist." userInfo:nil];
		}
		lameDefaultsValuesDictionary = [NSDictionary dictionaryWithContentsOfFile:lameDefaultsValuesPath];
		[[NSUserDefaults standardUserDefaults] registerDefaults:lameDefaultsValuesDictionary];
	}
	@catch(NSException *exception) {
		displayExceptionAlert(exception);
	}
	@finally {
	}
}

- (id) initWithController:(CompactDiscController *)controller usingSource:(Ripper *)source forDisc:(CompactDisc *)disc forTrack:(Track *)track toFile:(NSString *)filename
{
	NSString	*quality;
	int			bitrate;
	int			lameResult;
	
	
	_gfp			= 0;
	_controller		= [controller retain];
	_source			= [source retain];
	_disc			= [disc retain];
	_track			= [track retain];
	_filename		= [filename retain];
	
	@try {
		self = [super init];
		if(self) {			
			// LAME setup
			_gfp = lame_init();
			if(NULL == _gfp) {
				@throw [MallocException exceptionWithReason:[NSString stringWithFormat:@"Unable to allocate memory (%i:%s)", errno, strerror(errno)] userInfo:nil];
			}
			
			// We know the input is coming from a CD
			lame_set_num_channels(_gfp, 2);
			lame_set_in_samplerate(_gfp, 44100);
			
			// Write the Xing VBR tag
			lame_set_bWriteVbrTag(_gfp, 1);
			
			// Set encoding properties from user defaults
			lame_set_mode(_gfp, [[NSUserDefaults standardUserDefaults] boolForKey:@"org.sbooth.Max.lameMonoEncoding"] ? MONO : JOINT_STEREO);
			
			quality = [[NSUserDefaults standardUserDefaults] stringForKey:@"org.sbooth.Max.lameEncodingEngineQuality"];
			if([quality isEqualToString:@"Fast"]) {
				lame_set_quality(_gfp, 7);
			}
			else if([quality isEqualToString:@"Standard"]) {
				lame_set_quality(_gfp, 5);
			}
			else if([quality isEqualToString:@"High"]) {
				lame_set_quality(_gfp, 2);
			}
			
			// Target is bitrate
			if([[[NSUserDefaults standardUserDefaults] stringForKey:@"org.sbooth.Max.lameTarget"] isEqualToString:@"Bitrate"]) {
				bitrate = maxBitrates[[[NSUserDefaults standardUserDefaults] integerForKey:@"org.sbooth.Max.lameBitrate"]];
				lame_set_brate(_gfp, bitrate);
				if([[NSUserDefaults standardUserDefaults] boolForKey:@"org.sbooth.Max.lameUseConstantBitrate"]) {
					lame_set_VBR(_gfp, vbr_off);
				}
				else {
					lame_set_VBR(_gfp, vbr_default);
					lame_set_VBR_min_bitrate_kbps(_gfp, bitrate);
				}
			}
			// Target is quality
			else {
				lame_set_VBR(_gfp, [[[NSUserDefaults standardUserDefaults] stringForKey:@"org.sbooth.Max.lameVariableBitrateMode"] isEqualToString:@"Fast"] ? vbr_mtrh : vbr_rh);
				lame_set_preset(_gfp, 400 + [[NSUserDefaults standardUserDefaults] integerForKey:@"org.sbooth.Max.lameVBRQuality"]);
			}
			
			lameResult = lame_init_params(_gfp);
			if(-1 == lameResult) {
				@throw [LAMEException exceptionWithReason:@"Failure initializing LAME library" userInfo:nil];
			}
#if 0
			// Dump configuration info
			NSLog(@"=====================");
			NSLog(@"LAME configuration");
			NSLog(@"=====================");
			NSLog(@"Mode               %i", lame_get_mode(_gfp));
			NSLog(@"Bitrate            %i", lame_get_brate(_gfp));
			NSLog(@"VBR                %i", lame_get_VBR(_gfp));
			NSLog(@"Compression ratio  %f", lame_get_compression_ratio(_gfp));
			NSLog(@"Quality            %i", lame_get_quality(_gfp));
			NSLog(@"VBR Quality        %i", lame_get_VBR_q(_gfp));
			NSLog(@"=====================");
#endif			
		}
	}
	@catch(NSException *exception) {

		if(0 != _gfp) {
			lame_close(_gfp);
		}
		
		[_filename release];

		@throw;
	}
	
	@finally {
	}
	
	return self;
}

- (void) dealloc
{
	lame_close(_gfp);
	
	[_controller release];
	[_source release];
	[_disc release];
	[_track release];
	[_filename release];
	
	[super dealloc];
}

- (void) doIt:(id)object
{
	NSAutoreleasePool		*pool		= [[NSAutoreleasePool alloc] init];
	FILE					*file;
	
	@try {
		// Only allow one rip at a time (per CompactDiscController)
		@synchronized(object) {
			
			// Tell the controller we are starting
			[_controller performSelectorOnMainThread:@selector(encodeDidStart:) withObject:[[_track valueForKey:@"number"] stringValue] waitUntilDone:TRUE];
			[_controller performSelectorOnMainThread:@selector(updateEncodeProgress:) withObject:[NSNumber numberWithDouble:0.0] waitUntilDone:FALSE];
			
			// Create the output file
			_fd = open([_filename UTF8String], O_WRONLY | O_CREAT | O_EXCL, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH);
			if(-1 == _fd) {
				@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to create the output file. (%i:%s)", errno, strerror(errno)] userInfo:nil];
			}

			// Iteratively get the PCM data and encode it
			while(0 < [_source bytesRemaining]) {
								
				// Fetch a chunk of input and encode it
				[self encode:[_source get]];

				// Update the controller on our progress
				[_controller performSelectorOnMainThread:@selector(updateEncodeProgress:) withObject:[NSNumber numberWithDouble:[_source percentRead]] waitUntilDone:FALSE];
				
				// Check if we should stop, and if so throw an exception
				if(YES == [[_controller valueForKey:@"stop"] boolValue]) {
					[_controller performSelectorOnMainThread:@selector(encodeDidStop:) withObject:nil waitUntilDone:TRUE];
					@throw [StopException exceptionWithReason:nil userInfo:nil];
				}
			}
			
			// Flush the last MP3 frames (maybe)
			[self finishEncode];

			// Close the output file
			if(-1 == close(_fd)) {
				@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to close output file (%i:%s)", errno, strerror(errno)] userInfo:nil];
			}
			
			// Write the Xing VBR tag
			file = fopen([_filename UTF8String], "r+");
			if(NULL == file) {
				@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to open output file (%i:%s)", errno, strerror(errno)] userInfo:nil];
			}
			lame_mp3_tags_fid(_gfp, file);
			if(EOF == fclose(file)) {
				@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to close output file (%i:%s)", errno, strerror(errno)] userInfo:nil];
			}
			
			// Tell the controller we are finished
			[_controller performSelectorOnMainThread:@selector(updateEncodeProgress:) withObject:[NSNumber numberWithDouble:100.0] waitUntilDone:TRUE];
			[_controller performSelectorOnMainThread:@selector(encodeDidComplete:) withObject:self waitUntilDone:TRUE];
		}
	}
	
	@catch(StopException *exception) {
	}
	
	@catch(NSException *exception) {
		[_controller performSelectorOnMainThread:@selector(encodeDidStop:) withObject:nil waitUntilDone:TRUE];
		[_controller performSelectorOnMainThread:@selector(displayExceptionSheet:) withObject:exception waitUntilDone:TRUE];
	}
	
	@finally {
		[pool release];
	}	
}

- (ssize_t) encode: (NSData *)data
{
	int						*leftPCM,		*left;
	int						*rightPCM,		*right;
	int						numSamples;
	
	const unsigned char		*iter,			*limit;
	unsigned char			swap;
	
	unsigned char			*buf;
	int						bufSize;
	
	int						lameResult;
	long					bytesWritten;
	
	
	leftPCM		= 0;
	rightPCM	= 0;
	buf			= 0;

	@try {
		numSamples	= [data length] / 2;
		
		leftPCM		= (int *) calloc(numSamples / 2, sizeof(int));
		rightPCM	= (int *) calloc(numSamples / 2, sizeof(int));
		if(NULL == leftPCM || NULL == rightPCM) {
			@throw [MallocException exceptionWithReason:[NSString stringWithFormat:@"Unable to allocate memory (%i:%s)", errno, strerror(errno)] userInfo:nil];
		}
		
		// Raw PCM needs to be byte-swapped and separated into L/R channels
		iter	= [data bytes];
		limit	= [data bytes] + [data length];
		left	= leftPCM;
		right	= rightPCM;
		while(iter < limit) {
			swap		= *iter++;
			*left++		= (*iter++ << 24) | (swap << 16);
			
			swap		= *iter++;
			*right++	= (*iter++ << 24) | (swap << 16);
		}
		
		// Allocate the MP3 buffer using LAME guide for size
		bufSize = 1.25 * numSamples + 7200;
		buf = (unsigned char*) calloc(bufSize, sizeof(unsigned char));
		if(NULL == buf) {
			@throw [MallocException exceptionWithReason:[NSString stringWithFormat:@"Unable to allocate memory (%i:%s)", errno, strerror(errno)] userInfo:nil];
		}
		
		lameResult = lame_encode_buffer_int(_gfp, leftPCM, rightPCM, numSamples / 2, buf, bufSize);
		if(0 > lameResult) {
			@throw [LAMEException exceptionWithReason:@"LAME encoding error" userInfo:nil];
		}
		
		bytesWritten = write(_fd, buf, lameResult);
		if(-1 == bytesWritten) {
			@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to write to output file (%i:%s)", errno, strerror(errno)] userInfo:nil];
		}
	}
	
	@catch(NSException *exception) {
		@throw;
	}
	
	@finally {
		free(leftPCM);
		free(rightPCM);
		free(buf);
	}
	
	return bytesWritten;
}

- (ssize_t) finishEncode
{
	unsigned char		*buf;
	int					bufSize;
	
	int					lameResult;
	ssize_t				bytesWritten;
	
	
	buf = NULL;
	
	@try {
		// Allocate the MP3 buffer using LAME guide for size
		bufSize = 7200;
		buf = (unsigned char*) calloc(bufSize, sizeof(unsigned char));
		if(NULL == buf) {
			@throw [MallocException exceptionWithReason:[NSString stringWithFormat:@"Unable to allocate memory (%i:%s)", errno, strerror(errno)] userInfo:nil];
		}
		
		// Flush the mp3 buffer
		lameResult = lame_encode_flush(_gfp, buf, bufSize);
		if(-1 == lameResult) {
			@throw [LAMEException exceptionWithReason:@"LAME unable to flush buffers" userInfo:nil];
		}
		
		// And write any frames it returns
		bytesWritten = write(_fd, buf, lameResult);
		if(-1 == bytesWritten) {
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

@end
