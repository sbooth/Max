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

#import "Converter.h"

#include <CoreAudio/CoreAudioTypes.h>
#include <AudioToolbox/AudioFormat.h>
#include <AudioToolbox/AudioConverter.h>
#include <AudioToolbox/AudioFile.h>
#include <AudioToolbox/ExtendedAudioFile.h>

#import "ConverterTask.h"
#import "MallocException.h"
#import "IOException.h"
#import "StopException.h"

#include <fcntl.h>		// open, write
#include <sys/stat.h>	// stat

@implementation Converter

+ (void) connectWithPorts:(NSArray *)portArray
{
	NSAutoreleasePool	*pool				= nil;
	NSConnection		*connection			= nil;
	Converter			*converter			= nil;
	ConverterTask		*owner				= nil;
	
	@try {
		pool			= [[NSAutoreleasePool alloc] init];
		connection		= [NSConnection connectionWithReceivePort:[portArray objectAtIndex:0] sendPort:[portArray objectAtIndex:1]];
		owner			= (ConverterTask *)[connection rootProxy];
		converter		= [[self alloc] initWithInputFile:[owner inputFilename]];
		
		[converter setDelegate:owner];
		[owner converterReady:converter];
		
		[converter release];
	}	
	
	@catch(NSException *exception) {
		if(nil != owner) {
			[owner setException:exception];
			[owner setStopped];
		}
	}
	
	@finally {
		if(nil != pool) {
			[pool release];
		}		
	}
}

- (id) initWithInputFile:(NSString *)inputFilename
{
	if((self = [super init])) {
		_inputFilename		= [inputFilename retain];
		
		// Default is CD-DA format
		_sampleRate			= 44100.f;
		_channelsPerFrame	= 2;
		_bitsPerChannel		= 16;
		
		_framesPerPacket	= 1;

		return self;
	}
	return nil;
}

- (void) dealloc
{
	[_inputFilename release];	_inputFilename = nil;
	
	[super dealloc];
}

- (AudioStreamBasicDescription) outputASBD
{
	AudioStreamBasicDescription		result;
	
	bzero(&result, sizeof(AudioStreamBasicDescription));

	result.mFormatID			= kAudioFormatLinearPCM;
	result.mFormatFlags			= kAudioFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsBigEndian | kAudioFormatFlagIsPacked;

	result.mSampleRate			= [self sampleRate];
	result.mChannelsPerFrame	= [self channelsPerFrame];
	result.mBitsPerChannel		= [self bitsPerChannel];
	
	result.mBytesPerPacket		= [self bytesPerPacket];
	result.mFramesPerPacket		= [self framesPerPacket];
	result.mBytesPerFrame		= [self bytesPerFrame];
	
	return result;
}

- (Float64)				sampleRate										{ return _sampleRate; }
- (UInt32)				bitsPerChannel									{ return _bitsPerChannel; }
- (UInt32)				channelsPerFrame								{ return _channelsPerFrame; }
- (UInt32)				framesPerPacket									{ return _framesPerPacket; }
- (UInt32)				bytesPerPacket									{ return [self channelsPerFrame] * ([self bitsPerChannel] / 8); }
- (UInt32)				bytesPerFrame									{ return [self framesPerPacket] * [self bytesPerPacket]; }

- (void)				setSampleRate:(Float64)sampleRate				{ _sampleRate = sampleRate; }
- (void)				setBitsPerChannel:(UInt32)bitsPerChannel		{ _bitsPerChannel = bitsPerChannel; }
- (void)				setChannelsPerFrame:(UInt32)channelsPerFrame	{ _channelsPerFrame = channelsPerFrame; }
- (void)				setFramesPerPacket:(UInt32)framesPerPacket		{ _framesPerPacket = framesPerPacket; }

- (void)				setDelegate:(id <TaskMethods>)delegate			{ _delegate = delegate; }
- (id <TaskMethods>)	delegate										{ return _delegate; }

- (oneway void)			convertToFile:(NSString *)filename				{}

- (NSString *)			description										{ return [_inputFilename lastPathComponent]; }

@end
