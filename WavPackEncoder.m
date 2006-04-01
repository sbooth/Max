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

#import "WavPackEncoder.h"

#include <CoreAudio/CoreAudioTypes.h>
#include <AudioToolbox/AudioFormat.h>
#include <AudioToolbox/AudioConverter.h>
#include <AudioToolbox/AudioFile.h>
#include <AudioToolbox/ExtendedAudioFile.h>

#include <WavPack/wputils.h>

#import "UtilityFunctions.h"
#import "MissingResourceException.h"
#import "CoreAudioException.h"
#import "IOException.h"
#import "MallocException.h"
#import "StopException.h"

// WavPack IO wrapper
static int writeWavPackBlock(void *wv_id, void *data, int32_t bcount)			{ return (bcount == write((int)wv_id, data, bcount)); }

@implementation WavPackEncoder

+ (void) initialize
{
	NSString				*wavPackDefaultsValuesPath;
    NSDictionary			*wavPackDefaultsValuesDictionary;
    
	@try {
		wavPackDefaultsValuesPath = [[NSBundle mainBundle] pathForResource:@"WavPackDefaults" ofType:@"plist"];
		if(nil == wavPackDefaultsValuesPath) {
			@throw [MissingResourceException exceptionWithReason:NSLocalizedStringFromTable(@"Your installation of Max appears to be incomplete.", @"Exceptions", @"")
														userInfo:[NSDictionary dictionaryWithObject:@"WavPackDefaults.plist" forKey:@"filename"]];
		}
		wavPackDefaultsValuesDictionary = [NSDictionary dictionaryWithContentsOfFile:wavPackDefaultsValuesPath];
		[[NSUserDefaults standardUserDefaults] registerDefaults:wavPackDefaultsValuesDictionary];
	}
	
	@catch(NSException *exception) {
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert addButtonWithTitle:NSLocalizedStringFromTable(@"OK", @"General", @"")];
		[alert setMessageText:[NSString stringWithFormat:NSLocalizedStringFromTable(@"An error occurred while initializing the %@ class.", @"Exceptions", @""), @"MPEGEncoder"]];
		[alert setInformativeText:[exception reason]];
		[alert setAlertStyle:NSWarningAlertStyle];		
		[alert runModal];
	}
}

- (id) initWithPCMFilename:(NSString *)inputFilename
{
	int		mode;
	
	if((self = [super initWithPCMFilename:inputFilename])) {
		
		_flags			= 0;
		_noiseShaping	= 0.f;
		_bitrate		= 0.f;

		// Set encoding properties from user defaults
		mode = [[NSUserDefaults standardUserDefaults] integerForKey:@"wavPackStereoMode"];
		switch(mode) {
			case WAVPACK_STEREO_MODE_STEREO:			
				_flags |= CONFIG_JOINT_OVERRIDE;
				_flags &= ~CONFIG_JOINT_STEREO;
				break;
			case WAVPACK_STEREO_MODE_JOINT_STEREO:
				_flags |= (CONFIG_JOINT_OVERRIDE | CONFIG_JOINT_STEREO);
				break;
			case WAVPACK_STEREO_MODE_DEFAULT:			;										break;
			default:									;										break;
		}

		mode = [[NSUserDefaults standardUserDefaults] integerForKey:@"wavPackCompressionMode"];
		switch(mode) {
			case WAVPACK_COMPRESSION_MODE_HIGH:			_flags |= CONFIG_HIGH_FLAG;				break;
			case WAVPACK_COMPRESSION_MODE_FAST:			_flags |= CONFIG_FAST_FLAG;				break;
			case WAVPACK_COMPRESSION_MODE_DEFAULT:		;										break;
			default:									;										break;
		}
		
		// Hybrid mode
		if([[NSUserDefaults standardUserDefaults] integerForKey:@"wavPackEnableHybridCompression"]) {

			_flags |= CONFIG_HYBRID_FLAG;
			
			if([[NSUserDefaults standardUserDefaults] integerForKey:@"wavPackCreateCorrectionFile"]) {
				_flags |= CONFIG_CREATE_WVC;
			}

			if([[NSUserDefaults standardUserDefaults] integerForKey:@"wavPackMaximumHybridCompression"]) {
				_flags |= CONFIG_OPTIMIZE_WVC;
			}

			switch([[NSUserDefaults standardUserDefaults] integerForKey:@"wavPackHybridMode"]) {
				
				case WAVPACK_HYBRID_MODE_BITS_PER_SAMPLE:
					_bitrate = [[NSUserDefaults standardUserDefaults] floatForKey:@"wavPackBitsPerSample"];
					break;
					
				case WAVPACK_HYBRID_MODE_BITRATE:
					_bitrate = [[NSUserDefaults standardUserDefaults] floatForKey:@"wavPackBitsPerSample"];
					_flags |= CONFIG_BITRATE_KBPS;
					break;
					
				default:									;									break;
			}
			
			_noiseShaping = [[NSUserDefaults standardUserDefaults] floatForKey:@"wavPackNoiseShaping"];
			if(0.0 != _noiseShaping) {
				_flags |= (CONFIG_HYBRID_SHAPE | CONFIG_SHAPE_OVERRIDE);
			}

		}
		
		return self;
	}
	return nil;
}

- (oneway void) encodeToFile:(NSString *) filename
{
	NSDate					*startTime							= [NSDate date];
	OSStatus				err;
	AudioBufferList			buf;
	ssize_t					buflen								= 0;
	int16_t					*iter, *limit;
	int32_t					*wpBuf								= NULL;
	int32_t					*wpAlias;
	SInt64					totalFrames, framesToRead;
	UInt32					size, frameCount;
	FSRef					ref;
	ExtAudioFileRef			inExtAudioFile;
	int						fd, cfd;
    WavpackContext			*wpc								= NULL;
	WavpackConfig			config;
	unsigned long			iterations							= 0;
	
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
		
		err = ExtAudioFileOpen(&ref, &inExtAudioFile);
		if(noErr != err) {
			@throw [CoreAudioException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"ExtAudioFileOpen"]
												  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		// Get input file information
		size	= sizeof(totalFrames);
		err		= ExtAudioFileGetProperty(inExtAudioFile, kExtAudioFileProperty_FileLengthFrames, &size, &totalFrames);
		if(err != noErr) {
			@throw [CoreAudioException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"ExtAudioFileGetProperty"]
												  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		framesToRead = totalFrames;
		
		// Allocate the input buffers
		buflen								= 1024;
		buf.mNumberBuffers					= 1;
		buf.mBuffers[0].mNumberChannels		= 2;
		buf.mBuffers[0].mDataByteSize		= buflen * sizeof(int16_t);
		buf.mBuffers[0].mData				= calloc(buflen, sizeof(int16_t));
		if(NULL == buf.mBuffers[0].mData) {
			@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @"") 
											   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		wpBuf								= (int32_t *)calloc(buflen, sizeof(int32_t));
		if(NULL == wpBuf) {
			@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @"") 
											   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		// Open the output file
		fd = open([filename fileSystemRepresentation], O_WRONLY | O_TRUNC, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH);
		if(-1 == fd) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to create the output file.", @"Exceptions", @"") 
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}

		// Open the correction file
		cfd = -1;
		if(_flags & CONFIG_CREATE_WVC) {
			cfd = open([generateUniqueFilename([filename stringByDeletingPathExtension], @"wvc") fileSystemRepresentation], O_WRONLY | O_CREAT | O_EXCL | O_TRUNC, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH);
			if(-1 == cfd) {
				NSLog(@"%s",strerror(errno));
				@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to create the output file.", @"Exceptions", @"") 
											   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}
		}
		
		// Setup the encoder
		wpc = WavpackOpenFileOutput(writeWavPackBlock, (void *)fd, (-1 == cfd ? NULL : (void *)cfd));
		if(NULL == wpc) {
			@throw [NSException exceptionWithName:@"WavPackException" reason:NSLocalizedStringFromTable(@"Unable to create the WavPack encoder.", @"Exceptions", @"") userInfo:nil];
		}
		
		bzero(&config, sizeof(config));
		
		config.num_channels				= 2;
		config.channel_mask				= 3;
		config.sample_rate				= 44100;
		config.bits_per_sample			= 16;
		config.bytes_per_sample			= config.bits_per_sample / 8;
		
		config.flags					= _flags;
		
		if(0.f != _noiseShaping) {
			config.shaping_weight		= _noiseShaping;
		}

		if(0.f != _bitrate) {
			config.bitrate				= _bitrate;
		}
		
		if(FALSE == WavpackSetConfiguration(wpc, &config, totalFrames)) {
			@throw [NSException exceptionWithName:@"WavPackException" reason:NSLocalizedStringFromTable(@"Unable to initialize the WavPack encoder.", @"Exceptions", @"") userInfo:nil];
		}

		WavpackPackInit(wpc);
		
		// Iteratively get the PCM data and encode it
		for(;;) {
			
			// Read a chunk of PCM input
			frameCount	= buf.mBuffers[0].mDataByteSize / _inputASBD.mBytesPerFrame;
			err			= ExtAudioFileRead(inExtAudioFile, &frameCount, &buf);
			if(err != noErr) {
				@throw [CoreAudioException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"ExtAudioFileRead"]
													  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}
			
			// We're finished if no frames were returned
			if(0 == frameCount) {
				break;
			}
			
			// Fill WavPack buffer
			iter		= (int16_t *)buf.mBuffers[0].mData;
			limit		= iter + (buf.mBuffers[0].mNumberChannels * frameCount);
			wpAlias		= wpBuf;
			while(iter < limit) {
				*wpAlias++ = (int32_t)((int16_t)OSSwapBigToHostInt16(*iter++));
			}
			
			// Write the data
			if(FALSE == WavpackPackSamples(wpc, wpBuf, frameCount)) {
				@throw [NSException exceptionWithName:@"WavPackException" reason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"WavpackPackSamples"] userInfo:nil];
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
		
		// Flush any remaining samples
		if(FALSE == WavpackFlushSamples(wpc)) {
			@throw [NSException exceptionWithName:@"WavPackException" reason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"WavpackFlushSamples"] userInfo:nil];
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
		
		// Close the input file
		err = ExtAudioFileDispose(inExtAudioFile);
		if(noErr != err) {
			exception = [CoreAudioException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"ExtAudioFileDispose"]
													   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			NSLog(@"%@", exception);
		}
		
		// Close the output file
		if(NULL != wpc) {
			WavpackCloseFile(wpc);
		}
		close(fd);
		close(cfd);
		
		free(buf.mBuffers[0].mData);
		free(wpBuf);
	}
	
	[_delegate setEndTime:[NSDate date]];
	[_delegate setCompleted];	
}

- (NSString *) settings
{
	return [NSString stringWithFormat:@"WavPack settings: %@%@%@%@%@", 
		(_flags & CONFIG_HIGH_FLAG ? @"high " : @""),
		(_flags & CONFIG_FAST_FLAG ? @"fast " : @""),
		(_flags & CONFIG_HYBRID_FLAG ? @"hybrid " : @""),
		(_flags & CONFIG_JOINT_OVERRIDE ? (_flags & CONFIG_JOINT_STEREO ? @"joint stereo " : @"stereo "): @"")];
}

@end
