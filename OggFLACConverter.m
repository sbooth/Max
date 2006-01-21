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

#import "OggFLACConverter.h"
#import "MallocException.h"
#import "IOException.h"
#import "StopException.h"
#import "FLACException.h"

#include <fcntl.h>		// open, write
#include <sys/stat.h>	// stat

@interface OggFLACConverter (Private)
- (void) writeFrame:(const FLAC__Frame *)frame buffer:(const FLAC__int32 * const [])buffer;
@end

static FLAC__StreamDecoderWriteStatus 
writeCallback(const OggFLAC__FileDecoder *decoder, const FLAC__Frame *frame, const FLAC__int32 * const buffer[], void *client_data)
{
	OggFLACConverter *converter = (OggFLACConverter *) client_data;
	[converter writeFrame:frame buffer:buffer];
	
	// Always return continue; an exception will be thrown if this isn't the case
	return FLAC__STREAM_DECODER_WRITE_STATUS_CONTINUE;
}

static void
metadataCallback(const OggFLAC__FileDecoder *decoder, const FLAC__StreamMetadata *metadata, void *client_data)
{
	//OggFLACConverter *converter = (OggFLACConverter *) client_data;
	
	// Only accept 16-bit 2-channel FLAC files
	if(FLAC__METADATA_TYPE_STREAMINFO == metadata->type) {
		if(16 != metadata->data.stream_info.bits_per_sample && 2 != metadata->data.stream_info.channels) {
			@throw [FLACException exceptionWithReason:NSLocalizedStringFromTable(@"Ogg FLAC stream is not 16-bit stereo", @"Exceptions", @"") userInfo:nil];
		}
	}
}

static void
errorCallback(const OggFLAC__FileDecoder *decoder, FLAC__StreamDecoderErrorStatus status, void *client_data)
{
	//OggFLACConverter *converter = (OggFLACConverter *) client_data;
		
	@throw [FLACException exceptionWithReason:[NSString stringWithUTF8String:OggFLAC__FileDecoderStateString[OggFLAC__file_decoder_get_state(decoder)]] userInfo:nil];
}

@implementation OggFLACConverter

- (id) initWithInputFilename:(NSString *)inputFilename
{
	if((self = [super initWithInputFilename:inputFilename])) {	
		_fd  = -1;
		return self;
	}
	return nil;
}

- (oneway void) convertToFile:(NSString *)filename
{
	NSDate						*startTime			= [NSDate date];
	OggFLAC__FileDecoder		*flac				= NULL;
	FLAC__uint64				bytesToRead			= 0;
	FLAC__uint64				totalBytes			= 0;
	unsigned long				iterations			= 0;
	struct stat					sourceStat;

	
	// Tell our owner we are starting
	[_delegate setStartTime:startTime];	
	[_delegate setStarted];
	
	@try {
		// Open the output file
		_fd = open([filename UTF8String], O_WRONLY | O_TRUNC, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH);
		if(-1 == _fd) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to open the output file", @"Exceptions", @"") 
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		// Get input file information
		if(-1 == stat([_inputFilename UTF8String], &sourceStat)) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to get information on the input file", @"Exceptions", @"") 
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		totalBytes		= (FLAC__uint64)sourceStat.st_size;
		bytesToRead		= totalBytes;
		
		// Create Ogg FLAC decoder
		flac = OggFLAC__file_decoder_new();
		if(NULL == flac) {
			@throw [FLACException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to create Ogg FLAC decoder", @"Exceptions", @"") userInfo:nil];
		}
		
		if(NO == OggFLAC__file_decoder_set_filename(flac, [_inputFilename UTF8String])) {
			@throw [FLACException exceptionWithReason:[NSString stringWithUTF8String:OggFLAC__FileDecoderStateString[OggFLAC__file_decoder_get_state(flac)]] userInfo:nil];
		}
		
		// Setup callbacks
		if(NO == OggFLAC__file_decoder_set_write_callback(flac, writeCallback)) {
			@throw [FLACException exceptionWithReason:[NSString stringWithUTF8String:OggFLAC__FileDecoderStateString[OggFLAC__file_decoder_get_state(flac)]] userInfo:nil];
		}
		if(NO == OggFLAC__file_decoder_set_metadata_callback(flac, metadataCallback)) {
			@throw [FLACException exceptionWithReason:[NSString stringWithUTF8String:OggFLAC__FileDecoderStateString[OggFLAC__file_decoder_get_state(flac)]] userInfo:nil];
		}
		if(NO == OggFLAC__file_decoder_set_error_callback(flac, errorCallback)) {
			@throw [FLACException exceptionWithReason:[NSString stringWithUTF8String:OggFLAC__FileDecoderStateString[OggFLAC__file_decoder_get_state(flac)]] userInfo:nil];
		}
		if(NO == OggFLAC__file_decoder_set_client_data(flac, self)) {
			@throw [FLACException exceptionWithReason:[NSString stringWithUTF8String:OggFLAC__FileDecoderStateString[OggFLAC__file_decoder_get_state(flac)]] userInfo:nil];
		}
		
		// Initialize decoder
		if(OggFLAC__FILE_DECODER_OK != OggFLAC__file_decoder_init(flac)) {
			@throw [FLACException exceptionWithReason:[NSString stringWithUTF8String:OggFLAC__FileDecoderStateString[OggFLAC__file_decoder_get_state(flac)]] userInfo:nil];
		}
		
		for(;;) {
			
			// Decode the data
			if(NO == OggFLAC__file_decoder_process_single(flac)) {
				@throw [FLACException exceptionWithReason:[NSString stringWithUTF8String:OggFLAC__FileDecoderStateString[OggFLAC__file_decoder_get_state(flac)]] userInfo:nil];
			}
			
			// EOF?
			if(OggFLAC__FILE_DECODER_END_OF_FILE == OggFLAC__file_decoder_get_state(flac)) {
				break;
			}
			
			// Distributed Object calls are expensive, so only perform them every few iterations
			if(0 == iterations % MAX_DO_POLL_FREQUENCY) {
				
				// Check if we should stop, and if so throw an exception
				if([_delegate shouldStop]) {
					@throw [StopException exceptionWithReason:@"Stop requested by user" userInfo:nil];
				}
			}
			
			++iterations;			
		}
		
		// Flush buffers
		if(NO == OggFLAC__file_decoder_finish(flac)) {
			@throw [FLACException exceptionWithReason:[NSString stringWithUTF8String:OggFLAC__FileDecoderStateString[OggFLAC__file_decoder_get_state(flac)]] userInfo:nil];
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
		OggFLAC__file_decoder_delete(flac);
		
		// Close the output file
		if(-1 == close(_fd)) {
			NSException *exception = [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to close the output file", @"Exceptions", @"") 
															 userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			NSLog(@"%@", exception);
		}
	}
	
	[_delegate setEndTime:[NSDate date]];
	[_delegate setCompleted];	
}

- (void) writeFrame:(const FLAC__Frame *)frame buffer:(const FLAC__int32 * const [])buffer
{
	// We need to interleave the buffers for PCM output
	ssize_t			pcmBufferLen;
	int16_t			*pcmBuffer, *pos, *limit;
	FLAC__int32		*leftPCM, *rightPCM;
	
	pcmBufferLen	= frame->header.channels * frame->header.blocksize;
	pcmBuffer		= calloc(pcmBufferLen, sizeof(int16_t));
	if(NULL == pcmBuffer) {
		@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory", @"Exceptions", @"") 
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
	}
	
	// Interleave (16-bit sample size hard-coded)
	leftPCM			= (FLAC__int32 *)buffer[0];
	rightPCM		= (FLAC__int32 *)buffer[1];
	pos				= pcmBuffer;
	limit			= pcmBuffer + pcmBufferLen;
	while(pos < limit) {
		*pos++ = (int16_t)*leftPCM++;
		*pos++ = (int16_t)*rightPCM++;
	}
	
	if(-1 == write(_fd, pcmBuffer, pcmBufferLen * sizeof(int16_t))) {
		free(pcmBuffer);
		@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to write to the output file", @"Exceptions", @"") 
									   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
	}
	
	free(pcmBuffer);
}

@end
