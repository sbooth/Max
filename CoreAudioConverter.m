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

#import "CoreAudioConverter.h"

#include <CoreAudio/CoreAudioTypes.h>
#include <AudioToolbox/AudioFormat.h>
#include <AudioToolbox/AudioConverter.h>
#include <AudioToolbox/AudioFile.h>
#include <AudioToolbox/ExtendedAudioFile.h>

#import "MallocException.h"
#import "IOException.h"
#import "StopException.h"
#import "CoreAudioException.h"

@interface CoreAudioConverter (Private)
- (void) openInputFile;
- (void) closeInputFile:(BOOL)throw;
@end

@implementation CoreAudioConverter

- (id) initWithInputFile:(NSString *)inputFilename
{
	if((self = [super initWithInputFile:inputFilename])) {
		
		@try {			
			// Open the input file to get the file's information
			[self openInputFile];
		}
		
		@finally {
			// Close the input file to avoid too many open file descriptors
			[self closeInputFile:YES];
		}
		
		return self;
	}
	return nil;
}

- (void) dealloc
{
	[_fileType release];
	[super dealloc];
}

- (void) openInputFile
{
	OSStatus						err;
	FSRef							ref;
	UInt32							size;
	AudioStreamBasicDescription		asbd;
	
	// Open the input file
	err = FSPathMakeRef((const UInt8 *)[_inputFilename fileSystemRepresentation], &ref, NULL);
	if(noErr != err) {
		@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to locate the input file.", @"Exceptions", @"")
									   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:_inputFilename, [NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"filename", @"errorCode", @"errorString", nil]]];
	}
	
	err = ExtAudioFileOpen(&ref, &_in);
	if(noErr != err) {
		@throw [CoreAudioException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"ExtAudioFileOpen"]
											  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
	}
	
	err = ExtAudioFileSetProperty(_in, kExtAudioFileProperty_ClientDataFormat, sizeof(_outputASBD), &_outputASBD);
	if(noErr != err) {
		@throw [CoreAudioException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"ExtAudioFileSetProperty"]
											  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
	}
	
	size	= sizeof(asbd);
	err		= ExtAudioFileGetProperty(_in, kExtAudioFileProperty_FileDataFormat, &size, &asbd);
	if(err != noErr) {
		@throw [CoreAudioException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"ExtAudioFileGetProperty"]
											  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
	}
	
	size	= sizeof(_fileType);
	err		= AudioFormatGetProperty(kAudioFormatProperty_FormatName, sizeof(AudioStreamBasicDescription), &asbd, &size, &_fileType);
	if(noErr != err) {
		_fileType = NSLocalizedStringFromTable(@"Unknown (Core Audio)", @"General", @"");
	}		
}

- (void) closeInputFile:(BOOL)throw
{
	OSStatus			err;
	
	// Close the input file
	err = ExtAudioFileDispose(_in);
	if(noErr != err) {
		if(throw) {
			@throw [CoreAudioException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"ExtAudioFileDispose"]
												  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		else {
			NSException *exception =[CoreAudioException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"ExtAudioFileDispose"]
																   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			NSLog(@"%@", exception);
		}
	}	
}

- (oneway void) convertToFile:(NSString *)filename
{
	NSDate				*startTime			= [NSDate date];
	OSStatus			err;
	FSRef				ref;
	AudioFileID			audioFile;
	ExtAudioFileRef		extAudioFileRef;
	UInt32				frameCount;
	UInt32				size;
	SInt64				totalFrames;
	SInt64				framesToRead;
	unsigned long		iterations			= 0;
	
	
	// Tell our owner we are starting
	[_delegate setStartTime:startTime];	
	[_delegate setStarted];
	[_delegate setInputFormat:_fileType];
	
	@try {
		// Open the input file
		[self openInputFile];
		
		// Get input file information
		size	= sizeof(totalFrames);
		err		= ExtAudioFileGetProperty(_in, kExtAudioFileProperty_FileLengthFrames, &size, &totalFrames);
		if(err != noErr) {
			@throw [CoreAudioException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"ExtAudioFileGetProperty"]
												  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		framesToRead = totalFrames;
		
		// Allocate the input buffer
		_buflen								= 1024;
		_buf.mNumberBuffers					= 1;
		_buf.mBuffers[0].mNumberChannels	= 2;
		_buf.mBuffers[0].mDataByteSize		= _buflen * sizeof(int16_t);
		_buf.mBuffers[0].mData				= calloc(_buflen, sizeof(int16_t));
		if(NULL == _buf.mBuffers[0].mData) {
			@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @"") 
											   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		// Open the output file
		err = FSPathMakeRef((const UInt8 *)[filename fileSystemRepresentation], &ref, NULL);
		if(noErr != err) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to locate the output file.", @"Exceptions", @"")
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:filename, [NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"filename", @"errorCode", @"errorString", nil]]];
		}
		err = AudioFileInitialize(&ref, kAudioFileAIFFType, &_outputASBD, 0, &audioFile);
		if(noErr != err) {
			@throw [CoreAudioException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"AudioFileInitialize"]
												  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		err = ExtAudioFileWrapAudioFileID(audioFile, YES, &extAudioFileRef);
		if(noErr != err) {
			@throw [CoreAudioException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"ExtAudioFileWrapAudioFileID"]
												  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		// Iteratively get the data and convert it to PCM
		for(;;) {
			
			// Read a chunk of PCM input (converted from whatever format)
			frameCount	= _buf.mBuffers[0].mDataByteSize / _outputASBD.mBytesPerPacket;
			err			= ExtAudioFileRead(_in, &frameCount, &_buf);
			if(err != noErr) {
				@throw [CoreAudioException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"ExtAudioFileRead"]
													  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}
			
			// We're finished if no frames were returned
			if(0 == frameCount) {
				break;
			}
			
			// Write the data
			err = ExtAudioFileWrite(extAudioFileRef, frameCount, &_buf);
			if(noErr != err) {
				@throw [CoreAudioException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"ExtAudioFileWrite"]
													  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}
			
			// Update status
			framesToRead -= frameCount;
			
			// Distributed Object calls are expensive, so only perform them every few iterations
			if(0 == iterations % MAX_DO_POLL_FREQUENCY) {
				
				// Check if we should stop, and if so throw an exception
				if([_delegate shouldStop]) {
					@throw [StopException exceptionWithReason:@"Stop requested by user" userInfo:nil];
				}
				
				// Update UI
				double percentComplete = ((double)(totalFrames - framesToRead)/(double) totalFrames) * 100.0;
				NSTimeInterval interval = -1.0 * [startTime timeIntervalSinceNow];
				unsigned secondsRemaining = (unsigned) (interval / ((double)(totalFrames - framesToRead)/(double) totalFrames) - interval);
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
		
		free(_buf.mBuffers[0].mData);
		
		// Close the input file
		[self closeInputFile:NO];

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
	}
	
	[_delegate setEndTime:[NSDate date]];
	[_delegate setCompleted];	
}

@end
