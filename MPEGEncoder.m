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

#import "MPEGEncoder.h"

#include <CoreAudio/CoreAudioTypes.h>
#include <AudioToolbox/AudioFormat.h>
#include <AudioToolbox/AudioConverter.h>
#include <AudioToolbox/AudioFile.h>
#include <AudioToolbox/ExtendedAudioFile.h>
#include <AudioUnit/AudioCodec.h>

#include <LAME/lame.h>

#import "MallocException.h"
#import "IOException.h"
#import "LAMEException.h"
#import "StopException.h"
#import "MissingResourceException.h"
#import "CoreAudioException.h"

#import "UtilityFunctions.h"

#include <fcntl.h>		// open, write
#include <stdio.h>		// fopen, fclose
#include <sys/stat.h>	// stat

// Bitrates supported for 44.1 kHz audio
static int sLAMEBitrates [14] = { 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320 };

@interface MPEGEncoder (Private)
- (void) encodeChunk:(const AudioBufferList *)chunk frameCount:(UInt32)frameCount;
- (void) finishEncode;
@end

@implementation MPEGEncoder

+ (void) initialize
{
	NSString				*lameDefaultsValuesPath;
    NSDictionary			*lameDefaultsValuesDictionary;
    
	@try {
		lameDefaultsValuesPath = [[NSBundle mainBundle] pathForResource:@"LAMEDefaults" ofType:@"plist"];
		if(nil == lameDefaultsValuesPath) {
			@throw [MissingResourceException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to load required resource", @"Exceptions", @"")
														userInfo:[NSDictionary dictionaryWithObject:@"LAMEDefaults.plist" forKey:@"filename"]];
		}
		lameDefaultsValuesDictionary = [NSDictionary dictionaryWithContentsOfFile:lameDefaultsValuesPath];
		[[NSUserDefaults standardUserDefaults] registerDefaults:lameDefaultsValuesDictionary];
	}
	
	@catch(NSException *exception) {
		displayExceptionAlert(exception);
	}
}

- (id) initWithPCMFilename:(NSString *)inputFilename
{
	int			mode;
	int			quality;
	int			bitrate;
	int			lameResult;
	
	
	if((self = [super initWithPCMFilename:inputFilename])) {
		
		@try {
			// LAME setup
			_gfp	= NULL;
			_gfp	= lame_init();
			if(NULL == _gfp) {
				@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory", @"Exceptions", @"") 
									   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}
			
			// We know the input is coming from a CD
			lame_set_num_channels(_gfp, 2);
			lame_set_in_samplerate(_gfp, 44100);
			
			// Write the Xing VBR tag
			lame_set_bWriteVbrTag(_gfp, 1);
			
			// Set encoding properties from user defaults
			mode = [[NSUserDefaults standardUserDefaults] integerForKey:@"lameStereoMode"];
			switch(mode) {
				case LAME_STEREO_MODE_DEFAULT:			lame_set_mode(_gfp, NOT_SET);			break;
				case LAME_STEREO_MODE_MONO:				lame_set_mode(_gfp, MONO);				break;
				case LAME_STEREO_MODE_STEREO:			lame_set_mode(_gfp, STEREO);			break;
				case LAME_STEREO_MODE_JOINT_STEREO:		lame_set_mode(_gfp, JOINT_STEREO);		break;
				default:								lame_set_mode(_gfp, NOT_SET);			break;
			}
			
			quality = [[NSUserDefaults standardUserDefaults] integerForKey:@"lameEncodingEngineQuality"];
			switch(quality) {
				case LAME_ENCODING_ENGINE_QUALITY_FAST:			lame_set_quality(_gfp, 7);		break;
				case LAME_ENCODING_ENGINE_QUALITY_STANDARD:		lame_set_quality(_gfp, 5);		break;
				case LAME_ENCODING_ENGINE_QUALITY_HIGH:			lame_set_quality(_gfp, 2);		break;
				default:										lame_set_quality(_gfp, 5);		break;
			}
			
			// Target is bitrate
			if(LAME_TARGET_BITRATE == [[NSUserDefaults standardUserDefaults] integerForKey:@"lameTarget"]) {
				bitrate = sLAMEBitrates[[[NSUserDefaults standardUserDefaults] integerForKey:@"lameBitrate"]];
				lame_set_brate(_gfp, bitrate);
				if([[NSUserDefaults standardUserDefaults] boolForKey:@"lameUseConstantBitrate"]) {
					lame_set_VBR(_gfp, vbr_off);
				}
				else {
					lame_set_VBR(_gfp, vbr_default);
					lame_set_VBR_min_bitrate_kbps(_gfp, bitrate);
				}
			}
			// Target is quality
			else if(LAME_TARGET_QUALITY == [[NSUserDefaults standardUserDefaults] integerForKey:@"lameTarget"]) {
				lame_set_VBR(_gfp, LAME_VARIABLE_BITRATE_MODE_FAST == [[NSUserDefaults standardUserDefaults] integerForKey:@"lameVariableBitrateMode"] ? vbr_mtrh : vbr_rh);
				lame_set_VBR_q(_gfp, (100 - [[NSUserDefaults standardUserDefaults] integerForKey:@"lameVBRQuality"]) / 10);
			}
			else {
				@throw [NSException exceptionWithName:@"NSInternalInconsistencyException" reason:@"Unrecognized LAME target" userInfo:nil];
			}
			
			lameResult = lame_init_params(_gfp);
			if(-1 == lameResult) {
				@throw [LAMEException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to initialize LAME encoder", @"Exceptions", @"") userInfo:nil];
			}
		}

		@catch(NSException *exception) {
			if(NULL != _gfp) {
				lame_close(_gfp);
			}
			
			@throw;
		}
				
		return self;
	}
	
	return nil;
}

- (void) dealloc
{
	lame_close(_gfp);	
	
	[super dealloc];
}

- (oneway void) encodeToFile:(NSString *) filename
{
	NSDate				*startTime						= [NSDate date];
	FILE				*file							= NULL;
	AudioBufferList		buf;
	ssize_t				buflen							= 0;
	OSStatus			err;
	FSRef				ref;
	ExtAudioFileRef		inExtAudioFile					= NULL;
	SInt64				totalFrames, framesToRead;
	UInt32				size, frameCount;
	unsigned long		iterations						= 0;

	// Tell our owner we are starting
	[_delegate setStartTime:startTime];	
	[_delegate setStarted];
	
	@try {
		buf.mBuffers[0].mData = NULL;
		
		// Open the input file
		err = FSPathMakeRef((const UInt8 *)[_inputFilename fileSystemRepresentation], &ref, NULL);
		if(noErr != err) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to locate the input file", @"Exceptions", @"")
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:_inputFilename, [NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"filename", @"errorCode", @"errorString", nil]]];
		}
		
		err = ExtAudioFileOpen(&ref, &inExtAudioFile);
		if(noErr != err) {
			@throw [CoreAudioException exceptionWithReason:NSLocalizedStringFromTable(@"ExtAudioFileOpen failed", @"Exceptions", @"")
												  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		// Get input file information
		size	= sizeof(totalFrames);
		err		= ExtAudioFileGetProperty(inExtAudioFile, kExtAudioFileProperty_FileLengthFrames, &size, &totalFrames);
		if(err != noErr) {
			@throw [CoreAudioException exceptionWithReason:NSLocalizedStringFromTable(@"ExtAudioFileGetProperty failed", @"Exceptions", @"")
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
			@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory", @"Exceptions", @"") 
											   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		// Open the output file
		_out = open([filename fileSystemRepresentation], O_WRONLY | O_TRUNC, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH);
		if(-1 == _out) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to create the output file", @"Exceptions", @"") 
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		// Iteratively get the PCM data and encode it
		for(;;) {
			
			// Read a chunk of PCM input
			frameCount	= buf.mBuffers[0].mDataByteSize / _inputASBD.mBytesPerPacket;
			err			= ExtAudioFileRead(inExtAudioFile, &frameCount, &buf);
			if(err != noErr) {
				@throw [CoreAudioException exceptionWithReason:NSLocalizedStringFromTable(@"ExtAudioFileRead failed", @"Exceptions", @"")
													  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}
			
			// We're finished if no frames were returned
			if(0 == frameCount) {
				break;
			}
			
			// Encode the PCM data
			[self encodeChunk:&buf frameCount:frameCount];
			
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
				unsigned int secondsRemaining = interval / ((double)(totalFrames - framesToRead)/(double) totalFrames) - interval;
				NSString *timeRemaining = [NSString stringWithFormat:@"%i:%02i", secondsRemaining / 60, secondsRemaining % 60];
				
				[_delegate updateProgress:percentComplete timeRemaining:timeRemaining];
			}
			
			++iterations;
		}
		
		// Flush the last MP3 frames (maybe)
		[self finishEncode];
		
		// Close the output file
		if(-1 == close(_out)) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to close the output file", @"Exceptions", @"") 
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		_out = -1;
		
		// Write the Xing VBR tag
		file = fopen([filename fileSystemRepresentation], "r+");
		if(NULL == file) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to open the output file", @"Exceptions", @"") 
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		lame_mp3_tags_fid(_gfp, file);
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
		
		// Close the input file
		err = ExtAudioFileDispose(inExtAudioFile);
		if(noErr != err) {
			exception = [CoreAudioException exceptionWithReason:NSLocalizedStringFromTable(@"ExtAudioFileDispose failed", @"Exceptions", @"")
													   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			NSLog(@"%@", exception);
		}
		
		// Close the output file if not already closed
		if(-1 != _out && -1 == close(_out)) {
			exception = [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to close the output file", @"Exceptions", @"") 
												userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			NSLog(@"%@", exception);
		}

		// And close the other output file
		if(NULL != file && EOF == fclose(file)) {
			exception =  [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to close the output file", @"Exceptions", @"")
												 userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			NSLog(@"%@", exception);
		}		

		free(buf.mBuffers[0].mData);
	}

	[_delegate setEndTime:[NSDate date]];
	[_delegate setCompleted];	
}

- (void) encodeChunk:(const AudioBufferList *)chunk frameCount:(UInt32)frameCount;
{
	int16_t			*iter, *limit;
	u_int8_t		*buf;
	int				buflen;

	int				lameResult;
	long			bytesWritten;
	
	
	buf = NULL;
	
	@try {
		// Allocate the MP3 buffer using LAME guide for size
		buflen = 1.25 * (chunk->mBuffers[0].mNumberChannels * frameCount) + 7200;
		buf = (u_int8_t *) calloc(buflen, sizeof(u_int8_t));
		if(NULL == buf) {
			@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory", @"Exceptions", @"") 
									   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		// Adjust for host endian-ness
		iter	= chunk->mBuffers[0].mData;
		limit	= iter + (chunk->mBuffers[0].mNumberChannels * frameCount);
		while(iter < limit) {
			*iter = OSSwapBigToHostInt16(*iter);
			++iter;
		}
		
		lameResult = lame_encode_buffer_interleaved(_gfp, chunk->mBuffers[0].mData, frameCount, buf, buflen);
		if(0 > lameResult) {
			@throw [LAMEException exceptionWithReason:NSLocalizedStringFromTable(@"LAME encoding error", @"Exceptions", @"") userInfo:nil];
		}
		
		bytesWritten = write(_out, buf, lameResult);
		if(-1 == bytesWritten) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to write to the output file", @"Exceptions", @"") 
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
	}
		
	@finally {
		free(buf);
	}
}

- (void) finishEncode
{
	u_int8_t		*buf;
	int				bufSize;
	
	int				lameResult;
	ssize_t			bytesWritten;
		
	@try {
		buf = NULL;
		
		// Allocate the MP3 buffer using LAME guide for size
		bufSize = 7200;
		buf = (u_int8_t *) calloc(bufSize, sizeof(u_int8_t));
		if(NULL == buf) {
			@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory", @"Exceptions", @"") 
									   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		// Flush the mp3 buffer
		lameResult = lame_encode_flush(_gfp, buf, bufSize);
		if(-1 == lameResult) {
			@throw [LAMEException exceptionWithReason:NSLocalizedStringFromTable(@"LAME unable to flush buffers", @"Exceptions", @"") userInfo:nil];
		}
		
		// And write any frames it returns
		bytesWritten = write(_out, buf, lameResult);
		if(-1 == bytesWritten) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to write to the output file", @"Exceptions", @"") 
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
	}
		
	@finally {
		free(buf);
	}
}

- (NSString *) settings
{
	NSString *bitrateString;
	NSString *qualityString;
		
	switch(lame_get_VBR(_gfp)) {
		case vbr_mt:
		case vbr_rh:
		case vbr_mtrh:
//			appendix = "ca. ";
			bitrateString = [NSString stringWithFormat:@"VBR(q=%i)", lame_get_VBR_q(_gfp)];
			break;
		case vbr_abr:
			bitrateString = [NSString stringWithFormat:@"average %d kbps", lame_get_VBR_mean_bitrate_kbps(_gfp)];
			break;
		default:
			bitrateString = [NSString stringWithFormat:@"%3d kbps", lame_get_brate(_gfp)];
			break;
	}
	
//			0.1 * (int) (10. * lame_get_compression_ratio(_gfp) + 0.5),

	qualityString = [NSString stringWithFormat:@"qval=%i", lame_get_quality(_gfp)];
	
	return [NSString stringWithFormat:@"LAME settings: %@ %@", bitrateString, qualityString];
}

@end
