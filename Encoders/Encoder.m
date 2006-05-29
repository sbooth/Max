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

#import "Encoder.h"
#import "EncoderTask.h"

@implementation Encoder

+ (void) connectWithPorts:(NSArray *)portArray
{
	NSAutoreleasePool	*pool				= nil;
	NSConnection		*connection			= nil;
	Encoder				*encoder			= nil;
	EncoderTask			*owner				= nil;
	
	@try {
		pool			= [[NSAutoreleasePool alloc] init];
		connection		= [NSConnection connectionWithReceivePort:[portArray objectAtIndex:0] sendPort:[portArray objectAtIndex:1]];
		owner			= (EncoderTask *)[connection rootProxy];
		encoder			= [[self alloc] initWithPCMFilename:[owner inputFilename]];
		
		[encoder setDelegate:owner];
		[owner encoderReady:encoder];
		
		[encoder release];
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

- (id) initWithPCMFilename:(NSString *)inputFilename
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
	[_inputFilename release];
	[super dealloc];
}

- (AudioStreamBasicDescription) inputDescription
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

- (id <TaskMethods>)	delegate										{ return _delegate; }
- (void)				setDelegate:(id <TaskMethods>)delegate			{ _delegate = delegate; }

- (oneway void)			encodeToFile:(NSString *)filename				{}

- (NSString *)			settings										{ return @"Encoder settings unknown"; }

@end
