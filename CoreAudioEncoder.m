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

#import "CoreAudioEncoder.h"

#import "CoreAudioEncoderTask.h"
#import "MallocException.h"
#import "IOException.h"
#import "StopException.h"

#include <fcntl.h>		// open, write
#include <sys/stat.h>	// stat

#include <CoreAudio/CoreAudioTypes.h>
#include <AudioToolbox/AudioFormat.h>
#include <AudioToolbox/AudioConverter.h>
#include <AudioToolbox/AudioFile.h>
#include <AudioToolbox/ExtendedAudioFile.h>
#include <AudioUnit/AudioCodec.h>

@implementation CoreAudioEncoder

+ (void) connectWithPorts:(NSArray *)portArray
{
	NSAutoreleasePool			*pool;
	NSConnection				*connection;
	CoreAudioEncoder			*encoder;
	CoreAudioEncoderTask		*owner;
	
	pool			= [[NSAutoreleasePool alloc] init];
	connection		= [NSConnection connectionWithReceivePort:[portArray objectAtIndex:0] sendPort:[portArray objectAtIndex:1]];
	owner			= (CoreAudioEncoderTask *)[connection rootProxy];
	encoder			= [[self alloc] initWithPCMFilename:[owner getPCMFilename] formatInfo:[owner getFormatInfo]];
	
	[encoder setDelegate:owner];
	[owner encoderReady:encoder];
	
	[encoder release];
	
	[[NSRunLoop currentRunLoop] run];
	
	[pool release];
}

- (id) initWithPCMFilename:(NSString *)pcmFilename formatInfo:(NSDictionary *)formatInfo
{	
	if((self = [super initWithPCMFilename:pcmFilename])) {
	
		_formatInfo						= [formatInfo retain];
				
		bzero(&_inputASBD, sizeof(AudioStreamBasicDescription));
		bzero(&_outputASBD, sizeof(AudioStreamBasicDescription));
		
		// Interleaved 16-bit PCM audio
		_inputASBD.mSampleRate			= 44100.f;
		_inputASBD.mFormatID			= kAudioFormatLinearPCM;
		_inputASBD.mFormatFlags			= kAudioFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsBigEndian;
		_inputASBD.mBytesPerPacket		= 4;
		_inputASBD.mFramesPerPacket		= 1;
		_inputASBD.mBytesPerFrame		= 4;
		_inputASBD.mChannelsPerFrame	= 2;
		_inputASBD.mBitsPerChannel		= 16;

		// Desired output
		_outputASBD.mSampleRate			= [[_formatInfo valueForKey:@"sampleRate"] doubleValue];
		_outputASBD.mFormatID			= [[_formatInfo valueForKey:@"formatID"] unsignedLongValue];
		_outputASBD.mFormatFlags		= [[_formatInfo valueForKey:@"formatFlags"] unsignedLongValue];
		_outputASBD.mBitsPerChannel		= [[_formatInfo valueForKey:@"bitsPerChannel"] unsignedLongValue];

		// Flesh out structure for PCM formats
		if(kAudioFormatLinearPCM == _outputASBD.mFormatID) {
			_outputASBD.mChannelsPerFrame	= 2;
			_outputASBD.mFramesPerPacket	= 1;
			_outputASBD.mBytesPerPacket		= (_outputASBD.mBitsPerChannel * _outputASBD.mChannelsPerFrame) / 8;
			_outputASBD.mBytesPerFrame		= _outputASBD.mBytesPerPacket;
		}
				
		return self;
	}
	return nil;
}

- (void) dealloc
{
	[_formatInfo release];
	[super dealloc];
}

- (oneway void) encodeToFile:(NSString *) filename
{
	NSDate				*startTime							= [NSDate date];
	OSStatus			err;
	AudioBufferList		bufferList;
	UInt32				frameCount, size, bitrate, quality, mode;
	ssize_t				bytesRead							= 0;
	ssize_t				bytesToRead							= 0;
	ssize_t				totalBytes							= 0;
	NSString			*file, *path;
	FSRef				ref;
	ExtAudioFileRef		extAudioFileRef;
	AudioConverterRef	converter;
	CFArrayRef			converterPropertySettings;
	unsigned long		iterations							= 0;
	
	// Tell our owner we are starting
	[_delegate setStartTime:startTime];	
	[_delegate setStarted];
	
	// Open the input file
	_pcm = open([_pcmFilename UTF8String], O_RDONLY);
	if(-1 == _pcm) {
		[_delegate setStopped];
		@throw [IOException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Unable to open the input file '%@' (%i:%s)", @"Exceptions", @""), _pcmFilename, errno, strerror(errno)] userInfo:nil];
	}
	
	// Get input file information
	struct stat sourceStat;
	if(-1 == fstat(_pcm, &sourceStat)) {
		[_delegate setStopped];
		@throw [IOException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Unable to get information on the input file (%i:%s)", @"Exceptions", @""), errno, strerror(errno)] userInfo:nil];
	}
	
	// Allocate the input buffer
	_buflen			= 1024;
	_buf			= (int16_t *) calloc(_buflen, sizeof(int16_t));
	if(NULL == _buf) {
		[_delegate setStopped];
		@throw [MallocException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Unable to allocate memory (%i:%s)", @"Exceptions", @""), errno, strerror(errno)] userInfo:nil];
	}
	
	totalBytes		= sourceStat.st_size;
	bytesToRead		= totalBytes;
	
	// Create the output file
	path = [filename stringByDeletingLastPathComponent];
	file = [filename lastPathComponent];
	
	err = FSPathMakeRef((const UInt8 *)[path UTF8String], &ref, NULL);
	if(noErr != err) {
		[_delegate setStopped];
		@throw [IOException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Unable to locate the output file '%@' (%s:%s)", @"Exceptions", @""), path, GetMacOSStatusErrorString(err), GetMacOSStatusCommentString(err)] userInfo:nil];
	}
	
	err = ExtAudioFileCreateNew(&ref, (CFStringRef)file, [[_formatInfo valueForKey:@"fileType"] intValue], &_outputASBD, NULL, &extAudioFileRef);
	if(noErr != err) {
		[_delegate setStopped];
		@throw [IOException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Unable to create the output file (%s:%s)", @"Exceptions", @""), GetMacOSStatusErrorString(err), GetMacOSStatusCommentString(err)] userInfo:nil];
	}
	
	err = ExtAudioFileSetProperty(extAudioFileRef, kExtAudioFileProperty_ClientDataFormat, sizeof(_inputASBD), &_inputASBD);
	if(noErr != err) {
		[_delegate setStopped];
		@throw [IOException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Unable to set the output file properties (%s:%s)", @"Exceptions", @""), GetMacOSStatusErrorString(err), GetMacOSStatusCommentString(err)] userInfo:nil];
	}
	
	// Tweak converter settings
	size = sizeof(converter);
	err = ExtAudioFileGetProperty(extAudioFileRef, kExtAudioFileProperty_AudioConverter, &size, &converter);
	if(noErr != err) {
		[_delegate setStopped];
		@throw [IOException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Unable to get AudioConverter (%s:%s)", @"Exceptions", @""), GetMacOSStatusErrorString(err), GetMacOSStatusCommentString(err)] userInfo:nil];
	}

	// Bitrate
	if(nil != [_formatInfo objectForKey:@"bitrate"]) {
		bitrate		= [[_formatInfo objectForKey:@"bitrate"] intValue] * 1000;
		err			= AudioConverterSetProperty(converter, kAudioConverterEncodeBitRate, sizeof(bitrate), &bitrate);
		if(noErr != err) {
			[_delegate setStopped];
			@throw [IOException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Unable to set AudioConverter bitrate (%s:%s)", @"Exceptions", @""), GetMacOSStatusErrorString(err), GetMacOSStatusCommentString(err)] userInfo:nil];
		}		
	}

	// Quality
	if(nil != [_formatInfo objectForKey:@"quality"]) {
		quality		= [[_formatInfo objectForKey:@"quality"] intValue];
		err			= AudioConverterSetProperty(converter, kAudioConverterCodecQuality, sizeof(quality), &quality);
		if(noErr != err) {
			[_delegate setStopped];
			@throw [IOException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Unable to set AudioConverter quality (%s:%s)", @"Exceptions", @""), GetMacOSStatusErrorString(err), GetMacOSStatusCommentString(err)] userInfo:nil];
		}		
	}
	
	// Bitrate mode (this is a semi-hack)
	if(nil != [_formatInfo objectForKey:@"vbrAvailable"]) {
		mode		= [[_formatInfo objectForKey:@"useVBR"] boolValue] ? kAudioCodecBitRateFormat_VBR : kAudioCodecBitRateFormat_CBR;
		err			= AudioConverterSetProperty(converter, kAudioCodecBitRateFormat, sizeof(mode), &mode);
		if(noErr != err) {
			[_delegate setStopped];
			@throw [IOException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Unable to set AudioConverter to VBR (%s:%s)", @"Exceptions", @""), GetMacOSStatusErrorString(err), GetMacOSStatusCommentString(err)] userInfo:nil];
		}		
	}
	
	// Update
	size = sizeof(converterPropertySettings);
	err = AudioConverterGetProperty(converter, kAudioConverterPropertySettings, &size, &converterPropertySettings);
	if(noErr != err) {
		[_delegate setStopped];
		@throw [IOException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Unable to get AudioConverter property settings (%s:%s)", @"Exceptions", @""), GetMacOSStatusErrorString(err), GetMacOSStatusCommentString(err)] userInfo:nil];
	}		

	err = ExtAudioFileSetProperty(extAudioFileRef, kExtAudioFileProperty_ConverterConfig, size, &converterPropertySettings);
	if(noErr != err) {
		[_delegate setStopped];
		@throw [IOException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Unable to set AudioFile converter configuration (%s:%s)", @"Exceptions", @""), GetMacOSStatusErrorString(err), GetMacOSStatusCommentString(err)] userInfo:nil];
	}		
	
	// Iteratively get the PCM data and encode it
	while(0 < bytesToRead) {
				
		// Read a chunk of PCM input
		bytesRead = read(_pcm, _buf, (bytesToRead > 2 * _buflen ? 2 * _buflen : bytesToRead));
		if(-1 == bytesRead) {
			[_delegate setStopped];
			@throw [IOException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Unable to read from the input file (%i:%s)", @"Exceptions", @""), errno, strerror(errno)] userInfo:nil];
		}
		
		// Put the data in an AudioFileBufferList
		bufferList.mNumberBuffers					= 1;
		bufferList.mBuffers[0].mData				= _buf;
		bufferList.mBuffers[0].mDataByteSize		= bytesRead;
		bufferList.mBuffers[0].mNumberChannels		= 2;
		
		frameCount									= bytesRead / _inputASBD.mBytesPerPacket;
		
		// Write the data, encoding/converting in the process
		err = ExtAudioFileWrite(extAudioFileRef, frameCount, &bufferList);
		if(noErr != err) {
			[_delegate setStopped];
			@throw [NSException exceptionWithName:@"CAException" reason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"ExtAudioFileWrite failed (%s:%s)", @"Exceptions", @""), GetMacOSStatusErrorString(err), GetMacOSStatusCommentString(err)] userInfo:nil];
		}

		// Update status
		bytesToRead -= bytesRead;

		// Distributed Object calls are expensive, so only perform them every few iterations
		if(0 == iterations % MAX_DO_POLL_FREQUENCY) {
			
			// Check if we should stop, and if so throw an exception
			if([_delegate shouldStop]) {
				[_delegate setStopped];
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
	
	// Close the input file
	if(-1 == close(_pcm)) {
		[_delegate setStopped];
		@throw [IOException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Unable to close the input file (%i:%s)", @"Exceptions", @""), errno, strerror(errno)] userInfo:nil];
	}
	
	// Close the output file
	err = ExtAudioFileDispose(extAudioFileRef);
	if(noErr != err) {
		[_delegate setStopped];
		@throw [IOException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Unable to close the output file (%s:%s)", @"Exceptions", @""), GetMacOSStatusErrorString(err), GetMacOSStatusCommentString(err)] userInfo:nil];
	}

	free(_buf);

	[_delegate setEndTime:[NSDate date]];
	[_delegate setCompleted];	
	
//	return bytesWritten;
}

- (NSString *) settings
{
	NSString		*bitrateString;
	NSString		*qualityString;
	int				bitrate			= -1;
	int				quality			= -1;
	
	// Bitrate
	if(nil != [_formatInfo objectForKey:@"bitrate"]) {
		bitrate		= [[_formatInfo objectForKey:@"bitrate"] intValue];
	}
	
	// Quality
	if(nil != [_formatInfo objectForKey:@"quality"]) {
		quality		= [[_formatInfo objectForKey:@"quality"] intValue];
	}
	
	bitrateString = (-1 == bitrate ? @"" : [NSString stringWithFormat:@"bitrate=%u", bitrate]);
	qualityString = (-1 == quality ? @"" : [NSString stringWithFormat:@"quality=%u", quality]);

	if(-1 == bitrate && -1 == quality) {
		return nil;
	}
	else {
		return [NSString stringWithFormat:@"Core Audio settings('%@' codec): %@ %@", UTCreateStringForOSType([[_formatInfo valueForKey:@"formatID"] unsignedLongValue]), bitrateString, qualityString];
	}
}

@end
