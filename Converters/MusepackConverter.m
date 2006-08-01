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

#import "MusepackConverter.h"

#include <mpcdec/mpcdec.h>

#include <CoreAudio/CoreAudioTypes.h>
#include <AudioToolbox/AudioFormat.h>
#include <AudioToolbox/AudioConverter.h>
#include <AudioToolbox/AudioFile.h>
#include <AudioToolbox/ExtendedAudioFile.h>

#import "MallocException.h"
#import "IOException.h"
#import "StopException.h"
#import "CoreAudioException.h"

#include <unistd.h>		// lseek
#include <fcntl.h>		// open, write
#include <sys/stat.h>	// stat

@implementation MusepackConverter

- (oneway void) convertToFile:(NSString *)filename
{
	NSDate							*startTime			= [NSDate date];
	FILE							*f					= NULL;
	mpc_reader_file					reader_file;
	mpc_decoder						decoder;
	mpc_streaminfo					info;
	int								samplesRead			= 0;
	long							samplesToRead		= 0;
	long							totalSamples		= 0;
	OSStatus						err;
	FSRef							ref;
	AudioFileID						audioFile;
	ExtAudioFileRef					extAudioFileRef;
	AudioBufferList					bufferList;
	UInt32							frameCount;
	mpc_uint32_t					bytesRead;
	MPC_SAMPLE_FORMAT				*buffer				= NULL;
	unsigned long					iterations			= 0;
	AudioStreamBasicDescription		asbd;
	AudioStreamBasicDescription		inputASBD;
	
	// Tell our owner we are starting
	[_delegate setStartTime:startTime];	
	[_delegate setStarted];
	
	@try {
		// Open the input file
		f = fopen([_inputFilename fileSystemRepresentation], "r");
		if(NULL == f) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to open the input file.", @"Exceptions", @"") 
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		// Setup reader
		mpc_reader_setup_file_reader(&reader_file, f);
		
		// Get input file information		
		mpc_streaminfo_init(&info);
		if(ERROR_CODE_OK != mpc_streaminfo_read(&info, &reader_file.reader)) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"The file does not appear to be a valid Musepack file.", @"Exceptions", @"") userInfo:nil];
		}

		totalSamples		= info.frames;
		samplesToRead		= totalSamples;
		
		[self setSampleRate:info.sample_freq];
		[self setChannelsPerFrame:info.channels];

		// Use 16-bit sample size (should be adequate)
		[self setBitsPerChannel:16];

		// Set up the decoder
		mpc_decoder_setup(&decoder, &reader_file.reader);
		if(FALSE == mpc_decoder_initialize(&decoder, &info)) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to intialize the Musepack decoder.", @"Exceptions", @"") userInfo:nil];
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
		
		err = ExtAudioFileWrapAudioFileID(audioFile, YES, &extAudioFileRef);
		if(noErr != err) {
			@throw [CoreAudioException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"ExtAudioFileWrapAudioFileID"]
												  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		// MPC feeds us little-endian data, otherwise leave untouched
		inputASBD				= [self outputASBD];
		inputASBD.mFormatFlags	= kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
		
		err = ExtAudioFileSetProperty(extAudioFileRef, kExtAudioFileProperty_ClientDataFormat, sizeof(inputASBD), &inputASBD);
		if(noErr != err) {
			@throw [CoreAudioException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"ExtAudioFileSetProperty"]
												  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		// Set up the AudioBufferList
		bufferList.mNumberBuffers					= 1;
		bufferList.mBuffers[0].mNumberChannels		= [self channelsPerFrame];
		
		// Allocate the buffer used for decompression
		buffer = (MPC_SAMPLE_FORMAT *)calloc(MPC_DECODER_BUFFER_LENGTH, sizeof(MPC_SAMPLE_FORMAT));
		if(NULL == buffer) {
			@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @"") 
											   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		for(;;) {
			
			// Decode the data
			bytesRead = mpc_decoder_decode(&decoder, buffer, 0, 0);
			if((mpc_uint32_t)-1 == bytesRead) {
				@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Musepack decoding error.", @"Exceptions", @"") userInfo:nil];
			}
			
			// EOF?
			if(0 == bytesRead) {
				break;
			}
			
			bufferList.mBuffers[0].mData				= buffer;
			bufferList.mBuffers[0].mDataByteSize		= bytesRead;
			
			frameCount									= bytesRead / ([self channelsPerFrame] * ([self bitsPerChannel] / 8));
			
			// Write the data
			err = ExtAudioFileWrite(extAudioFileRef, frameCount, &bufferList);
			if(noErr != err) {
				@throw [CoreAudioException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"ExtAudioFileWrite"]
													  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}
			
			// Update status
			samplesToRead -= samplesRead;
			
			// Distributed Object calls are expensive, so only perform them every few iterations
			if(0 == iterations % MAX_DO_POLL_FREQUENCY) {
				
				// Check if we should stop, and if so throw an exception
				if([_delegate shouldStop]) {
					@throw [StopException exceptionWithReason:@"Stop requested by user" userInfo:nil];
				}
				
				// Update UI
				double percentComplete = ((double)(totalSamples - samplesToRead)/(double) totalSamples) * 100.0;
				NSTimeInterval interval = -1.0 * [startTime timeIntervalSinceNow];
				unsigned secondsRemaining = (unsigned) (interval / ((double)(totalSamples - samplesToRead)/(double) totalSamples) - interval);
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
	
	@finally {
		NSException						*exception;
		
		// Close the input file
		if(EOF == fclose(f)) {
			exception = [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to close the input file.", @"Exceptions", @"") 
												userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			NSLog(@"%@", exception);
		}
		
		// Close the output file
		err = ExtAudioFileDispose(extAudioFileRef);
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
		
		// Clean up
		free(buffer);
	}
	
	[_delegate setEndTime:[NSDate date]];
	[_delegate setCompleted];	
}

@end
