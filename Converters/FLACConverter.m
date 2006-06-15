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

#include <FLAC/file_decoder.h>

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
	FLACConverter *converter = (FLACConverter *)client_data;
	[converter writeFrame:frame buffer:buffer];
	
	// Always return continue; an exception will be thrown if this isn't the case
	return FLAC__STREAM_DECODER_WRITE_STATUS_CONTINUE;
}

static void
metadataCallback(const FLAC__FileDecoder *decoder, const FLAC__StreamMetadata *metadata, void *client_data)
{
	FLACConverter *converter = (FLACConverter *)client_data;
//	const FLAC__StreamMetadata_CueSheet		*cueSheet			= NULL;
//	FLAC__StreamMetadata_CueSheet_Track		*currentTrack		= NULL;
//	FLAC__StreamMetadata_CueSheet_Index		*currentIndex		= NULL;
//	unsigned								i, j;
	
	switch(metadata->type) {
		case FLAC__METADATA_TYPE_STREAMINFO:
			[converter setSampleRate:metadata->data.stream_info.sample_rate];			
			[converter setBitsPerChannel:metadata->data.stream_info.bits_per_sample];
			[converter setChannelsPerFrame:metadata->data.stream_info.channels];
			break;

/*
		case FLAC__METADATA_TYPE_CUESHEET:
			cueSheet = &(metadata->data.cue_sheet);
			
			for(i = 0; i < cueSheet->num_tracks; ++i) {
				currentTrack = &(cueSheet->tracks[i]);

				FLAC__uint64 offset = currentTrack->offset;
				
				for(j = 0; j < currentTrack->num_indices; ++j) {
					currentIndex = &(currentTrack->indices[j]);					
				}
			}
			break;
*/
	}
}

static void
errorCallback(const FLAC__FileDecoder *decoder, FLAC__StreamDecoderErrorStatus status, void *client_data)
{
	//FLACConverter *converter = (FLACConverter *) client_data;
	
	@throw [FLACException exceptionWithReason:[NSString stringWithCString:FLAC__StreamDecoderErrorStatusString[status] encoding:NSASCIIStringEncoding] userInfo:nil];
}

@implementation FLACConverter

- (oneway void) convertToFile:(NSString *)filename
{
	NSDate						*startTime			= [NSDate date];
	FLAC__FileDecoder			*flac				= NULL;
	OSStatus					err;
	FSRef						ref;
	AudioStreamBasicDescription asbd;
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
		// Get input file information
		if(-1 == stat([_inputFilename fileSystemRepresentation], &sourceStat)) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to get information on the input file.", @"Exceptions", @"") 
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		totalBytes		= (FLAC__uint64)sourceStat.st_size;
		bytesToRead		= totalBytes;
		
		// Create FLAC decoder
		flac = FLAC__file_decoder_new();
		if(NULL == flac) {
			@throw [FLACException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to create the FLAC decoder.", @"Exceptions", @"") userInfo:nil];
		}
		
		if(NO == FLAC__file_decoder_set_filename(flac, [_inputFilename fileSystemRepresentation])) {
			@throw [FLACException exceptionWithReason:[NSString stringWithCString:FLAC__FileDecoderStateString[FLAC__file_decoder_get_state(flac)] encoding:NSASCIIStringEncoding] userInfo:nil];
		}
		
/*
		// Process cue sheets
		if(NO == FLAC__file_decoder_set_metadata_respond(flac, FLAC__METADATA_TYPE_CUESHEET)) {
			@throw [FLACException exceptionWithReason:[NSString stringWithCString:FLAC__FileDecoderStateString[FLAC__file_decoder_get_state(flac)] encoding:NSASCIIStringEncoding] userInfo:nil];
		}
 */
				
		// Setup callbacks
		if(NO == FLAC__file_decoder_set_write_callback(flac, writeCallback)) {
			@throw [FLACException exceptionWithReason:[NSString stringWithCString:FLAC__FileDecoderStateString[FLAC__file_decoder_get_state(flac)] encoding:NSASCIIStringEncoding] userInfo:nil];
		}
		if(NO == FLAC__file_decoder_set_metadata_callback(flac, metadataCallback)) {
			@throw [FLACException exceptionWithReason:[NSString stringWithCString:FLAC__FileDecoderStateString[FLAC__file_decoder_get_state(flac)] encoding:NSASCIIStringEncoding] userInfo:nil];
		}
		if(NO == FLAC__file_decoder_set_error_callback(flac, errorCallback)) {
			@throw [FLACException exceptionWithReason:[NSString stringWithCString:FLAC__FileDecoderStateString[FLAC__file_decoder_get_state(flac)] encoding:NSASCIIStringEncoding] userInfo:nil];
		}
		if(NO == FLAC__file_decoder_set_client_data(flac, self)) {
			@throw [FLACException exceptionWithReason:[NSString stringWithCString:FLAC__FileDecoderStateString[FLAC__file_decoder_get_state(flac)] encoding:NSASCIIStringEncoding] userInfo:nil];
		}

		// Initialize decoder
		// This will set our bitsPerSample, etc. appropriately
		if(FLAC__FILE_DECODER_OK != FLAC__file_decoder_init(flac)) {
			@throw [FLACException exceptionWithReason:[NSString stringWithCString:FLAC__FileDecoderStateString[FLAC__file_decoder_get_state(flac)] encoding:NSASCIIStringEncoding] userInfo:nil];
		}

		// Process metadata
		if(NO == FLAC__file_decoder_process_until_end_of_metadata(flac)) {
			@throw [FLACException exceptionWithReason:[NSString stringWithCString:FLAC__FileDecoderStateString[FLAC__file_decoder_get_state(flac)] encoding:NSASCIIStringEncoding] userInfo:nil];
		}
			
		// Open the output file
		err = FSPathMakeRef((const UInt8 *)[filename fileSystemRepresentation], &ref, NULL);
		if(noErr != err) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to locate the output file.", @"Exceptions", @"")
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:filename, [NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"filename", @"errorCode", @"errorString", nil]]];
		}
		asbd = [self outputASBD];
		err = AudioFileInitialize(&ref, kAudioFileAIFFType, &asbd, 0, &audioFile);
		if(noErr != err) {
			@throw [CoreAudioException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"AudioFileInitialize"]
												  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		err = ExtAudioFileWrapAudioFileID(audioFile, YES, &_extAudioFileRef);
		if(noErr != err) {
			@throw [CoreAudioException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"ExtAudioFileWrapAudioFileID"]
												  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		for(;;) {
			
			// Decode the data
			if(NO == FLAC__file_decoder_process_single(flac)) {
				@throw [FLACException exceptionWithReason:[NSString stringWithCString:FLAC__FileDecoderStateString[FLAC__file_decoder_get_state(flac)] encoding:NSASCIIStringEncoding] userInfo:nil];
			}
			
			// EOF?
			if(FLAC__FILE_DECODER_END_OF_FILE == FLAC__file_decoder_get_state(flac)) {
				break;
			}
			
			// Determine bytes processed
			if(NO == FLAC__file_decoder_get_decode_position(flac, &bytesRead)) {
				@throw [FLACException exceptionWithReason:[NSString stringWithCString:FLAC__FileDecoderStateString[FLAC__file_decoder_get_state(flac)] encoding:NSASCIIStringEncoding] userInfo:nil];
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
			@throw [FLACException exceptionWithReason:[NSString stringWithCString:FLAC__FileDecoderStateString[FLAC__file_decoder_get_state(flac)] encoding:NSASCIIStringEncoding] userInfo:nil];
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
		NSException *exception;

		FLAC__file_decoder_delete(flac);

		// Close the output file
		err = ExtAudioFileDispose(_extAudioFileRef);
		if(noErr != err) {
			exception = [CoreAudioException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"ExtAudioFileDispose"]
													   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			NSLog(@"%@", exception);
		}
		
		// Close the output file
		err = AudioFileClose(audioFile);
		if(noErr != err) {
			exception = [CoreAudioException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"AudioFileClose"]
													   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			NSLog(@"%@", exception);
		}		
	}

	[_delegate setEndTime:[NSDate date]];
	[_delegate setCompleted];	
}

- (void) writeFrame:(const FLAC__Frame *)frame buffer:(const FLAC__int32 * const [])buffer
{
	ssize_t				bufferLen				= 0;
	int8_t				*buffer8				= NULL;
	int8_t				*alias8					= NULL;
	int16_t				*buffer16				= NULL;
	int16_t				*alias16				= NULL;
	int32_t				*buffer32				= NULL;
	int32_t				*alias32				= NULL;
	
	unsigned			sample, channel;
	int32_t				audioSample;
	
	OSStatus			err;
	AudioBufferList		bufferList;
	
	@try {

		// Set up the AudioBufferList
		bufferList.mNumberBuffers					= 1;
		bufferList.mBuffers[0].mNumberChannels		= frame->header.channels;
		
		// Calculate the number of audio data points contained in the frame (should be one for each channel)
		bufferLen									= frame->header.blocksize * frame->header.channels;
		
		switch(frame->header.bits_per_sample) {

			case 8:
				
				// Allocate the buffer that will hold the interleaved audio data
				buffer8 = calloc(bufferLen, sizeof(int8_t));
				if(NULL == buffer8) {
					@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @"") 
													   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
				}
				
				// Interleave the audio (no need for byte swapping)
				alias8 = buffer8;
				for(sample = 0; sample < frame->header.blocksize; ++sample) {
					for(channel = 0; channel < frame->header.channels; ++channel) {
						*alias8++ = (int8_t)buffer[channel][sample];
					}
				}
				
				// Place the interleaved data in the buffer
				bufferList.mBuffers[0].mData				= buffer8;
				bufferList.mBuffers[0].mDataByteSize		= bufferLen * sizeof(int8_t);
				
				break;
				
			case 16:
				
				// Allocate the buffer that will hold the interleaved audio data
				buffer16 = calloc(bufferLen, sizeof(int16_t));
				if(NULL == buffer16) {
					@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @"") 
													   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
				}
					
				// Interleave the audio, converting to big endian byte order for the AIFF file
				alias16 = buffer16;
				for(sample = 0; sample < frame->header.blocksize; ++sample) {
					for(channel = 0; channel < frame->header.channels; ++channel) {
						*alias16++ = (int16_t)OSSwapHostToBigInt16((int16_t)buffer[channel][sample]);
					}
				}
					
				// Place the interleaved data in the buffer
				bufferList.mBuffers[0].mData				= buffer16;
				bufferList.mBuffers[0].mDataByteSize		= bufferLen * sizeof(int16_t);

				break;

			case 24:				
				
				// Allocate the buffer that will hold the interleaved audio data
				bufferLen *= 3;
				buffer8 = calloc(bufferLen, sizeof(int8_t));
				if(NULL == buffer8) {
					@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @"") 
													   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
				}
					
				// Interleave the audio
				alias8 = buffer8;
				for(sample = 0; sample < frame->header.blocksize; ++sample) {
					for(channel = 0; channel < frame->header.channels; ++channel) {
						audioSample	= OSSwapHostToBigInt32(buffer[channel][sample]);
						*alias8++	= (int8_t)(audioSample >> 16);
						*alias8++	= (int8_t)(audioSample >> 8);
						*alias8++	= (int8_t)audioSample;
					}
				}
					
				// Place the interleaved data in the buffer
				bufferList.mBuffers[0].mData				= buffer8;
				bufferList.mBuffers[0].mDataByteSize		= bufferLen * sizeof(int8_t);
				
				break;
				
			case 32:
				
				// Allocate the buffer that will hold the interleaved audio data
				buffer32 = calloc(bufferLen, sizeof(int32_t));
				if(NULL == buffer32) {
					@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @"") 
													   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
				}
					
				// Interleave the audio, converting to big endian byte order for the AIFF file
				alias32 = buffer32;
				for(sample = 0; sample < frame->header.blocksize; ++sample) {
					for(channel = 0; channel < frame->header.channels; ++channel) {
						*alias32++ = OSSwapHostToBigInt32(buffer[channel][sample]);
					}
				}
					
				// Place the interleaved data in the buffer
				bufferList.mBuffers[0].mData				= buffer32;
				bufferList.mBuffers[0].mDataByteSize		= bufferLen * sizeof(int32_t);
				
				break;
				
			default:
				@throw [NSException exceptionWithName:@"IllegalInputException" reason:@"Sample size not supported" userInfo:nil]; 
				break;				
		}
				
		// Write the data
		err = ExtAudioFileWrite(_extAudioFileRef, frame->header.blocksize, &bufferList);
		if(noErr != err) {
			@throw [CoreAudioException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"ExtAudioFileWrite"]
												  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
	}
	
	// Clean up
	@finally {
		free(buffer8);
		free(buffer16);
		free(buffer32);
	}
}

@end
