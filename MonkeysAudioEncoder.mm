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

#import "MonkeysAudioEncoder.h"

#include <MAC/All.h>
#include <MAC/MACLib.h>
#include <MAC/APECompress.h>
#include <MAC/CharacterHelper.h>

#include <CoreAudio/CoreAudioTypes.h>
#include <AudioToolbox/AudioFormat.h>
#include <AudioToolbox/AudioConverter.h>
#include <AudioToolbox/AudioFile.h>
#include <AudioToolbox/ExtendedAudioFile.h>

#import "MallocException.h"
#import "IOException.h"
#import "StopException.h"
#import "CoreAudioException.h"
#import "MissingResourceException.h"

#import "UtilityFunctions.h"

@interface MonkeysAudioEncoder (Private)
- (void) compressChunk:(const AudioBufferList *)chunk frameCount:(UInt32)frameCount;
@end

@implementation MonkeysAudioEncoder

+ (void) initialize
{
	NSString				*macDefaultsValuesPath;
    NSDictionary			*macDefaultsValuesDictionary;
    
	@try {
		macDefaultsValuesPath = [[NSBundle mainBundle] pathForResource:@"MonkeysAudioDefaults" ofType:@"plist"];
		if(nil == macDefaultsValuesPath) {
			@throw [MissingResourceException exceptionWithReason:NSLocalizedStringFromTable(@"Your installation of Max appears to be incomplete.", @"Exceptions", @"")
														userInfo:[NSDictionary dictionaryWithObject:@"MonkeysAudioDefaults.plist" forKey:@"filename"]];
		}
		macDefaultsValuesDictionary = [NSDictionary dictionaryWithContentsOfFile:macDefaultsValuesPath];
		[[NSUserDefaults standardUserDefaults] registerDefaults:macDefaultsValuesDictionary];
	}
	
	@catch(NSException *exception) {
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert addButtonWithTitle:NSLocalizedStringFromTable(@"OK", @"General", @"")];
		[alert setMessageText:[NSString stringWithFormat:NSLocalizedStringFromTable(@"An error occurred while initializing the %@ class.", @"Exceptions", @""), @"MonkeysAudioEncoder"]];
		[alert setInformativeText:[exception reason]];
		[alert setAlertStyle:NSWarningAlertStyle];		
		[alert runModal];
	}
}

- (id) initWithPCMFilename:(NSString *)inputFilename
{	
	int level;
	
	if((self = [super initWithPCMFilename:inputFilename])) {
		_compressor = NULL;
		
		level = [[NSUserDefaults standardUserDefaults] integerForKey:@"monkeysAudioCompressionLevel"];
		switch(level) {
			case MAC_COMPRESSION_LEVEL_FAST:		_compressionLevel = COMPRESSION_LEVEL_FAST;				break;
			case MAC_COMPRESSION_LEVEL_NORMAL:		_compressionLevel = COMPRESSION_LEVEL_NORMAL;			break;
			case MAC_COMPRESSION_LEVEL_HIGH:		_compressionLevel = COMPRESSION_LEVEL_HIGH;				break;
			case MAC_COMPRESSION_LEVEL_EXTRA_HIGH:	_compressionLevel = COMPRESSION_LEVEL_EXTRA_HIGH;		break;
			case MAC_COMPRESSION_LEVEL_INSANE:		_compressionLevel = COMPRESSION_LEVEL_INSANE;			break;
			default:								_compressionLevel = COMPRESSION_LEVEL_NORMAL;			break;
		}
		
		return self;	
	}
	
	return nil;
}

- (oneway void) encodeToFile:(NSString *)filename
{
	NSDate							*startTime					= [NSDate date];
	unsigned long					iterations					= 0;
	AudioBufferList					buf;
	ssize_t							buflen						= 0;
	WAVEFORMATEX					formatDesc;
	str_utf16						*chars						= NULL;
	int								result;
	OSStatus						err;
	FSRef							ref;
	ExtAudioFileRef					extAudioFileRef				= NULL;
	SInt64							totalFrames, framesToRead;
	UInt32							size, frameCount;
	
	// Tell our owner we are starting
	[_delegate setStartTime:startTime];	
	[_delegate setStarted];
	
	@try {
		buf.mBuffers[0].mData = NULL;
		
		// Open the input file
		err = FSPathMakeRef((const UInt8 *)[_inputFilename fileSystemRepresentation], &ref, NULL);
		if(noErr != err) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to locate the input file.", @"Exceptions", @"")
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:_inputFilename, [NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"filename", @"errorCode", @"errorString", nil]]];
		}
		
		err = ExtAudioFileOpen(&ref, &extAudioFileRef);
		if(noErr != err) {
			@throw [CoreAudioException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"ExtAudioFileOpen"]
												  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		// Get input file information
		size	= sizeof(totalFrames);
		err		= ExtAudioFileGetProperty(extAudioFileRef, kExtAudioFileProperty_FileLengthFrames, &size, &totalFrames);
		if(err != noErr) {
			@throw [CoreAudioException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"ExtAudioFileGetProperty"]
												  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		framesToRead = totalFrames;
		
		// Allocate the input buffer
		buflen								= 1024;
		buf.mNumberBuffers					= 1;
		buf.mBuffers[0].mNumberChannels		= 2;
		buf.mBuffers[0].mDataByteSize		= buflen * sizeof(int16_t);
		buf.mBuffers[0].mData				= calloc(buflen, sizeof(int16_t));
		if(NULL == buf.mBuffers[0].mData) {
			@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @"") 
											   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		// Create the MAC compressor
		_compressor = CreateIAPECompress();
		if(NULL == _compressor) {
			@throw [NSException exceptionWithName:@"MACException" reason:NSLocalizedStringFromTable(@"Unable to create the Monkey's Audio compressor.", @"Exceptions", @"") userInfo:nil];
		}
						
		// Setup compressor
		chars = GetUTF16FromANSI([filename fileSystemRepresentation]);
		if(NULL == chars) {
			@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @"") 
											   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		result = FillWaveFormatEx(&formatDesc, (int)_inputASBD.mSampleRate, _inputASBD.mBitsPerChannel, _inputASBD.mChannelsPerFrame);
		if(ERROR_SUCCESS != result) {
			@throw [NSException exceptionWithName:@"MACException" reason:NSLocalizedStringFromTable(@"Unable to initialize the Monkey's Audio compressor.", @"Exceptions", @"")
										 userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObject:[NSNumber numberWithInt:result]] forKeys:[NSArray arrayWithObject:@"errorCode"]]];
		}
		
		// Start the compressor
		result = _compressor->Start(chars, &formatDesc, totalFrames * _inputASBD.mBytesPerFrame, _compressionLevel, NULL, 0);
		if(ERROR_SUCCESS != result) {
			@throw [NSException exceptionWithName:@"MACException" reason:NSLocalizedStringFromTable(@"Unable to start the Monkey's Audio compressor.", @"Exceptions", @"")
										 userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObject:[NSNumber numberWithInt:result]] forKeys:[NSArray arrayWithObject:@"errorCode"]]];
		}
		
		// Iteratively get the PCM data and encode it
		for(;;) {
			
			// Read a chunk of PCM input
			frameCount	= buf.mBuffers[0].mDataByteSize / _inputASBD.mBytesPerFrame;
			err			= ExtAudioFileRead(extAudioFileRef, &frameCount, &buf);
			if(err != noErr) {
				@throw [CoreAudioException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"ExtAudioFileRead"]
													  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}
			
			// We're finished if no frames were returned
			if(0 == frameCount) {
				break;
			}
			
			// Encode the PCM data
			[self compressChunk:&buf frameCount:frameCount];
			
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
				unsigned int secondsRemaining = (unsigned) (interval / ((double)(totalFrames - framesToRead)/(double) totalFrames) - interval);
				NSString *timeRemaining = [NSString stringWithFormat:@"%i:%02i", secondsRemaining / 60, secondsRemaining % 60];
				
				[_delegate updateProgress:percentComplete timeRemaining:timeRemaining];
			}
			
			++iterations;
		}
		
		// Finish up the compression process
		_compressor->Finish(NULL, 0, 0);
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
		
		if(NULL != _compressor) {
			delete _compressor;
		}
		
		// Close the input file
		err = ExtAudioFileDispose(extAudioFileRef);
		if(noErr != err) {
			exception = [CoreAudioException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"ExtAudioFileDispose"]
													   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			NSLog(@"%@", exception);
		}
		
		free(buf.mBuffers[0].mData);
		free(chars);
	}
	
	[_delegate setEndTime:[NSDate date]];
	[_delegate setCompleted];	
}

- (void) compressChunk:(const AudioBufferList *)chunk frameCount:(UInt32)frameCount;
{
	int16_t			*iter, *limit;
	int				result;
	
	// Adjust for host endian-ness (MAC expects little-endian input)
	iter	= (int16_t *)chunk->mBuffers[0].mData;
	limit	= iter + (chunk->mBuffers[0].mNumberChannels * frameCount);
	while(iter < limit) {
		*iter = (u_int16_t)( (((uint16_t)*iter & 0x00FF) << 8) | ((uint16_t)(*iter & 0xFF00) >> 8) );
		++iter;
	}
	
	result = _compressor->AddData((unsigned char *)chunk->mBuffers[0].mData, chunk->mBuffers[0].mDataByteSize);
	if(ERROR_SUCCESS != result) {
		@throw [NSException exceptionWithName:@"MACException" reason:NSLocalizedStringFromTable(@"Monkey's Audio compressor error.", @"Exceptions", @"")
									 userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObject:[NSNumber numberWithInt:result]] forKeys:[NSArray arrayWithObject:@"errorCode"]]];
	}
}	

- (NSString *) settings
{
	return [NSString stringWithFormat:@"MAC settings: compression level:%i", _compressionLevel];
}

@end
