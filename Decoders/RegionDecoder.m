/*
 *  $Id$
 *
 *  Copyright (C) 2007 Stephen F. Booth <me@sbooth.org>
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

#import "RegionDecoder.h"
#import "Decoder.h"

@implementation RegionDecoder

#pragma mark Creation

+ (RegionDecoder *) regionDecoderForDecoder:(Decoder *)decoder
{
	return [RegionDecoder regionDecoderForDecoder:decoder startingFrame:0 framesToPlay:[decoder totalFrames] loopCount:0];
}

+ (RegionDecoder *) regionDecoderForDecoder:(Decoder *)decoder startingFrame:(SInt64)startingFrame
{
	return [RegionDecoder regionDecoderForDecoder:decoder startingFrame:startingFrame framesToPlay:([decoder totalFrames] - startingFrame) loopCount:0];
}

+ (RegionDecoder *) regionDecoderForDecoder:(Decoder *)decoder startingFrame:(SInt64)startingFrame framesToPlay:(unsigned)framesToPlay
{
	return [RegionDecoder regionDecoderForDecoder:decoder startingFrame:startingFrame framesToPlay:framesToPlay loopCount:0];
}

+ (RegionDecoder *) regionDecoderForDecoder:(Decoder *)decoder startingFrame:(SInt64)startingFrame framesToPlay:(unsigned)framesToPlay loopCount:(unsigned)loopCount
{
	RegionDecoder *result = [[RegionDecoder alloc] init];
	
	[result setDecoder:decoder];
	[result setStartingFrame:startingFrame];
	[result setFramesToPlay:framesToPlay];
	[result setLoopCount:loopCount];
	
	return [result autorelease];
}

- (void) dealloc
{
	[_decoder release], _decoder = nil;
		
	[super dealloc];
}

#pragma mark Properties

- (Decoder *)	decoder									{ return [[_decoder retain] autorelease]; }

- (void) setDecoder:(Decoder *)decoder
{
	NSParameterAssert(nil != decoder);
//	NSParameterAssert(kAudioFormatFlagsNativeFloatPacked & [decoder format].mFormatFlags);
//	NSParameterAssert(kAudioFormatFlagIsNonInterleaved & [decoder format].mFormatFlags);
	
	[_decoder release];
	_decoder = [decoder retain];	
}

- (unsigned)		loopCount								{ return _loopCount; }
- (void)			setLoopCount:(unsigned)loopCount 		{ _loopCount = loopCount; }

- (SInt64)			startingFrame							{ return _startingFrame; }

- (void) setStartingFrame:(SInt64)startingFrame
{
	NSParameterAssert(0 <= startingFrame);
	
	_startingFrame = startingFrame;
}

- (UInt32)			framesToPlay							{ return _framesToPlay; }

- (void) setFramesToPlay:(UInt32)framesToPlay
{
	NSParameterAssert(0 < framesToPlay);

	_framesToPlay = framesToPlay;
}

#pragma mark Audio Access

- (void) reset
{
	[[self decoder] seekToFrame:[self startingFrame]];
	
	_framesReadInCurrentLoop	= 0;
	_totalFramesRead			= 0;
	_completedLoops				= 0;
	_atEnd						= NO;
}

- (UInt32) readAudio:(AudioBufferList *)bufferList frameCount:(UInt32)frameCount
{
	NSParameterAssert(NULL != bufferList);
	NSParameterAssert(0 < frameCount);
	
	if([self loopCount] < [self completedLoops])
		return 0;
	
	UInt32	framesRemaining		= [self startingFrame] + [self framesToPlay] - [[self decoder] currentFrame];
	UInt32	framesToRead		= (frameCount < framesRemaining ? frameCount : framesRemaining);
	UInt32	framesRead			= 0;
	
	if(0 < framesToRead)
		framesRead = [[self decoder] readAudio:bufferList frameCount:framesToRead];
	
	_framesReadInCurrentLoop	+= framesRead;
	_totalFramesRead			+= framesRead;
	
	if([self framesToPlay] == _framesReadInCurrentLoop || (0 == framesRead && 0 != framesToRead)) {
		[[self decoder] seekToFrame:[self startingFrame]];
		++_completedLoops;
		_framesReadInCurrentLoop = 0;		
	}
	
	if([self loopCount] < [self completedLoops])
		_atEnd = YES;
	
	return framesRead;	
}

- (unsigned)		completedLoops							{ return _completedLoops; }

- (SInt64)			totalFrames								{ return (([self loopCount] + 1) * [self framesToPlay]); }
- (SInt64)			currentFrame							{ return _totalFramesRead; }
- (SInt64)			framesRemaining							{ return ([self totalFrames] - [self currentFrame]); }

- (BOOL)			supportsSeeking							{ return NO /*[[self decoder] supportsSeeking]*/; }

- (SInt64) seekToFrame:(SInt64)frame
{
	NSParameterAssert(0 <= frame && frame < [self totalFrames]);
	
	_completedLoops				= frame / [self framesToPlay];
	_framesReadInCurrentLoop	= frame % [self framesToPlay];
	_totalFramesRead			= frame;
	_atEnd						= NO;

	[[self decoder] seekToFrame:[self startingFrame] + _framesReadInCurrentLoop];
	
	return [self currentFrame];
}

- (BOOL) atEnd
{
	return _atEnd;
}

@end
