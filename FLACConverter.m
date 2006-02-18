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

#import "FLACConverter.h"

#include <CoreAudio/CoreAudioTypes.h>
#include <AudioToolbox/AudioFormat.h>
#include <AudioToolbox/AudioConverter.h>
#include <AudioToolbox/AudioFile.h>
#include <AudioToolbox/ExtendedAudioFile.h>

#include "FLAC/file_decoder.h"

#import "MallocException.h"
#import "IOException.h"
#import "StopException.h"
#import "FLACException.h"
#import "CoreAudioException.h"

#include <sys/stat.h>	// stat

@interface FLACConverter (Private)
- (void) writeFrame:(const FLAC__Frame *)frame buffer:(const FLAC__int32 * const [])buffer;
@end

static FLAC__StreamDecoderWriteStatus 
writeCallback(const FLAC__FileDecoder *decoder, const FLAC__Frame *frame, const FLAC__int32 * const buffer[], void *client_data)
{
	FLACConverter *converter = (FLACConverter *) client_data;
	[converter writeFrame:frame buffer:buffer];
	
	// Always return continue; an exception will be thrown if this isn't the case
	return FLAC__STREAM_DECODER_WRITE_STATUS_CONTINUE;
}

static void
metadataCallback(const FLAC__FileDecoder *decoder, const FLAC__StreamMetadata *metadata, void *client_data)
{
	//FLACConverter *converter = (FLACConverter *) client_data;

	// Only accept 16-bit 2-channel FLAC files
	if(FLAC__METADATA_TYPE_STREAMINFO == metadata->type) {
		if(16 != metadata->data.stream_info.bits_per_sample && 2 != metadata->data.stream_info.channels) {
			@throw [FLACException exceptionWithReason:NSLocalizedStringFromTable(@"FLAC stream is not 16-bit stereo", @"Exceptions", @"") userInfo:nil];
		}
	}
}

static void
errorCallback(const FLAC__FileDecoder *decoder, FLAC__StreamDecoderErrorStatus status, void *client_data)
{
	//FLACConverter *converter = (FLACConverter *) client_data;
	
	@throw [FLACException exceptionWithReason:[NSString stringWithUTF8String:FLAC__FileDecoderStateString[FLAC__file_decoder_get_state(decoder)]] userInfo:nil];
}

@implementation FLACConverter

- (oneway void) convertToFile:(NSString *)filename
{
	NSDate						*startTime			= [NSDate date];
	FLAC__FileDecoder			*flac				= NULL;
	OSStatus					err;
	FSRef						ref;
	AudioFileID					audioFile;
	FLAC__uint64				bytesRead			= 0;
	FLAC__uint64				bytesToRead			= 0;
	FLAC__uint64				totalBytes			= 0;
	unsigned long				iterations			= 0;
	struct stat					sourceStat;

	
	// Tell our owner we are starting
	[_delegate setStartTime:startTime];	
	[_delegate setStarted];
	
	@try {
		// Open the output file
		err = FSPathMakeRef((const UInt8 *)[filename fileSystemRepresentation], &ref, NULL);
		if(noErr != err) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to locate the output file", @"Exceptions", @"")
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:filename, [NSString stringWithUTF8String:GetMacOSStatusErrorString(err)], [NSString stringWithUTF8String:GetMacOSStatusCommentString(err)], nil] forKeys:[NSArray arrayWithObjects:@"filename", @"errorCode", @"errorString", nil]]];
		}
		err = AudioFileInitialize(&ref, kAudioFileAIFFType, &_outputASBD, 0, &audioFile);
		if(noErr != err) {
			@throw [CoreAudioException exceptionWithReason:NSLocalizedStringFromTable(@"AudioFileInitialize failed", @"Exceptions", @"")
												  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithUTF8String:GetMacOSStatusErrorString(err)], [NSString stringWithUTF8String:GetMacOSStatusCommentString(err)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		err = ExtAudioFileWrapAudioFileID(audioFile, YES, &_extAudioFileRef);
		if(noErr != err) {
			@throw [CoreAudioException exceptionWithReason:NSLocalizedStringFromTable(@"ExtAudioFileWrapAudioFileID failed", @"Exceptions", @"")
												  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithUTF8String:GetMacOSStatusErrorString(err)], [NSString stringWithUTF8String:GetMacOSStatusCommentString(err)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		// Get input file information
		if(-1 == stat([_inputFilename fileSystemRepresentation], &sourceStat)) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to get information on the input file", @"Exceptions", @"") 
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		totalBytes		= (FLAC__uint64)sourceStat.st_size;
		bytesToRead		= totalBytes;
		
		// Create FLAC decoder
		flac = FLAC__file_decoder_new();
		if(NULL == flac) {
			@throw [FLACException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to create FLAC decoder", @"Exceptions", @"") userInfo:nil];
		}
		
		if(NO == FLAC__file_decoder_set_filename(flac, [_inputFilename fileSystemRepresentation])) {
			@throw [FLACException exceptionWithReason:[NSString stringWithUTF8String:FLAC__FileDecoderStateString[FLAC__file_decoder_get_state(flac)]] userInfo:nil];
		}
		
		// Setup callbacks
		if(NO == FLAC__file_decoder_set_write_callback(flac, writeCallback)) {
			@throw [FLACException exceptionWithReason:[NSString stringWithUTF8String:FLAC__FileDecoderStateString[FLAC__file_decoder_get_state(flac)]] userInfo:nil];
		}
		if(NO == FLAC__file_decoder_set_metadata_callback(flac, metadataCallback)) {
			@throw [FLACException exceptionWithReason:[NSString stringWithUTF8String:FLAC__FileDecoderStateString[FLAC__file_decoder_get_state(flac)]] userInfo:nil];
		}
		if(NO == FLAC__file_decoder_set_error_callback(flac, errorCallback)) {
			@throw [FLACException exceptionWithReason:[NSString stringWithUTF8String:FLAC__FileDecoderStateString[FLAC__file_decoder_get_state(flac)]] userInfo:nil];
		}
		if(NO == FLAC__file_decoder_set_client_data(flac, self)) {
			@throw [FLACException exceptionWithReason:[NSString stringWithUTF8String:FLAC__FileDecoderStateString[FLAC__file_decoder_get_state(flac)]] userInfo:nil];
		}

		// Initialize decoder
		if(FLAC__FILE_DECODER_OK != FLAC__file_decoder_init(flac)) {
			@throw [FLACException exceptionWithReason:[NSString stringWithUTF8String:FLAC__FileDecoderStateString[FLAC__file_decoder_get_state(flac)]] userInfo:nil];
		}
		
		for(;;) {
			
			// Decode the data
			if(NO == FLAC__file_decoder_process_single(flac)) {
				@throw [FLACException exceptionWithReason:[NSString stringWithUTF8String:FLAC__FileDecoderStateString[FLAC__file_decoder_get_state(flac)]] userInfo:nil];
			}
			
			// EOF?
			if(FLAC__FILE_DECODER_END_OF_FILE == FLAC__file_decoder_get_state(flac)) {
				break;
			}
			
			// Determine bytes processed
			if(NO == FLAC__file_decoder_get_decode_position(flac, &bytesRead)) {
				@throw [FLACException exceptionWithReason:[NSString stringWithUTF8String:FLAC__FileDecoderStateString[FLAC__file_decoder_get_state(flac)]] userInfo:nil];
			}
			
			// Update status
			bytesToRead = totalBytes - bytesRead;
			
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
		
		// Flush buffers
		if(NO == FLAC__file_decoder_finish(flac)) {
			@throw [FLACException exceptionWithReason:[NSString stringWithUTF8String:FLAC__FileDecoderStateString[FLAC__file_decoder_get_state(flac)]] userInfo:nil];
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
		NSException						*exception;

		FLAC__file_decoder_delete(flac);

		// Close the output file
		err = ExtAudioFileDispose(_extAudioFileRef);
		if(noErr != err) {
			exception = [CoreAudioException exceptionWithReason:NSLocalizedStringFromTable(@"ExtAudioFileDispose failed", @"Exceptions", @"")
													   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithUTF8String:GetMacOSStatusErrorString(err)], [NSString stringWithUTF8String:GetMacOSStatusCommentString(err)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			NSLog(@"%@", exception);
		}
		
		// Close the output file
		err = AudioFileClose(audioFile);
		if(noErr != err) {
			exception = [CoreAudioException exceptionWithReason:NSLocalizedStringFromTable(@"AudioFileClose failed", @"Exceptions", @"")
													   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithUTF8String:GetMacOSStatusErrorString(err)], [NSString stringWithUTF8String:GetMacOSStatusCommentString(err)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			NSLog(@"%@", exception);
		}		
	}

	[_delegate setEndTime:[NSDate date]];
	[_delegate setCompleted];	
}

- (void) writeFrame:(const FLAC__Frame *)frame buffer:(const FLAC__int32 * const [])buffer
{
	// We need to interleave the buffers for PCM output
	ssize_t				pcmBufferLen;
	int16_t				*pcmBuffer				= NULL;
	int16_t				*pos, *limit;
	FLAC__int32			*leftPCM, *rightPCM;
	OSStatus			err;
	AudioBufferList		bufferList;
	UInt32				frameCount;
	
	@try {
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
			*pos++ = OSSwapHostToBigInt16(*leftPCM++);
			*pos++ = OSSwapHostToBigInt16(*rightPCM++);
		}
		
		// Put the data in an AudioBufferList
		bufferList.mNumberBuffers					= 1;
		bufferList.mBuffers[0].mData				= pcmBuffer;
		bufferList.mBuffers[0].mDataByteSize		= pcmBufferLen * sizeof(int16_t);
		bufferList.mBuffers[0].mNumberChannels		= 2;
		
		frameCount									= pcmBufferLen / 2;
		
		// Write the data
		err = ExtAudioFileWrite(_extAudioFileRef, frameCount, &bufferList);
		if(noErr != err) {
			@throw [CoreAudioException exceptionWithReason:NSLocalizedStringFromTable(@"ExtAudioFileWrite failed", @"Exceptions", @"")
												  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithUTF8String:GetMacOSStatusErrorString(err)], [NSString stringWithUTF8String:GetMacOSStatusCommentString(err)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
	}
	
	@finally {
		// Clean up
		free(pcmBuffer);
	}
}

@end
