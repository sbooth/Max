/*
 *  Copyright (C) 2007 - 2020 Stephen F. Booth <me@sbooth.org>
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

+ (id) decoderWithFilename:(NSString *)filename startingFrame:(SInt64)startingFrame
{
	return [[[RegionDecoder alloc] initWithFilename:filename startingFrame:startingFrame] autorelease];
}

+ (id) decoderWithFilename:(NSString *)filename startingFrame:(SInt64)startingFrame frameCount:(UInt32)frameCount
{
	return [[[RegionDecoder alloc] initWithFilename:filename startingFrame:startingFrame frameCount:frameCount] autorelease];
}

+ (id) decoderWithFilename:(NSString *)filename startingFrame:(SInt64)startingFrame frameCount:(UInt32)frameCount loopCount:(NSUInteger)loopCount
{
	return [[[RegionDecoder alloc] initWithFilename:filename startingFrame:startingFrame frameCount:frameCount loopCount:loopCount] autorelease];
}

- (id) initWithFilename:(NSString *)filename
{
	if((self = [super init])) {
		_decoder = [Decoder decoderWithFilename:filename];
		if(nil != _decoder)
			[_decoder retain];
		else {
			[self release];
			return nil;
		}
		
		[self setFrameCount:(UInt32)[[self decoder] totalFrames]];
	}
	return self;
}

- (id) initWithFilename:(NSString *)filename startingFrame:(SInt64)startingFrame
{
	if((self = [super init])) {
		_decoder = [Decoder decoderWithFilename:filename];
		if(nil != _decoder)
			[_decoder retain];
		else {
			[self release];
			return nil;
		}
		
		[self setStartingFrame:startingFrame];
		[self setFrameCount:(UInt32)([[self decoder] totalFrames] - startingFrame)];
		
		if(0 != [self startingFrame])
			[self reset];
	}
	return self;
}

- (id) initWithFilename:(NSString *)filename startingFrame:(SInt64)startingFrame frameCount:(UInt32)frameCount
{
	if((self = [super init])) {
		_decoder = [Decoder decoderWithFilename:filename];
		if(nil != _decoder)
			[_decoder retain];
		else {
			[self release];
			return nil;
		}
		
		[self setStartingFrame:startingFrame];
		[self setFrameCount:frameCount];
		
		if(0 != [self startingFrame])
			[self reset];
	}
	return self;
}

- (id) initWithFilename:(NSString *)filename startingFrame:(SInt64)startingFrame frameCount:(UInt32)frameCount loopCount:(NSUInteger)loopCount
{
	if((self = [super init])) {
		_decoder = [Decoder decoderWithFilename:filename];
		if(nil != _decoder)
			[_decoder retain];
		else {
			[self release];
			return nil;
		}
		
		[self setStartingFrame:startingFrame];
		[self setFrameCount:frameCount];
		[self setLoopCount:loopCount];
		
		if(0 != [self startingFrame])
			[self reset];
	}
	return self;
}

- (void) dealloc
{
	[_decoder release];
	_decoder = nil;
		
	[super dealloc];
}

#pragma mark Properties

- (Decoder *)	decoder									{ return [[_decoder retain] autorelease]; }

- (NSUInteger)		loopCount								{ return _loopCount; }
- (void)			setLoopCount:(NSUInteger)loopCount 		{ _loopCount = loopCount; }

- (SInt64)			startingFrame							{ return _startingFrame; }

- (void) setStartingFrame:(SInt64)startingFrame
{
	NSParameterAssert(0 <= startingFrame);
	
	_startingFrame = startingFrame;
}

- (UInt32)			frameCount								{ return _frameCount; }

- (void) setFrameCount:(UInt32)frameCount
{
	NSParameterAssert(0 < frameCount);

	_frameCount = frameCount;
}

#pragma mark Audio Access

- (void) reset
{
	[[self decoder] seekToFrame:[self startingFrame]];
	
	_framesReadInCurrentLoop	= 0;
	_totalFramesRead			= 0;
	_completedLoops				= 0;
}

- (UInt32) readAudio:(AudioBufferList *)bufferList frameCount:(UInt32)frameCount
{
	NSParameterAssert(NULL != bufferList);
	NSParameterAssert(0 < frameCount);
	
	if([self loopCount] < [self completedLoops])
		return 0;
	
	UInt32	framesRemaining		= (UInt32)([self startingFrame] + [self frameCount] - [[self decoder] currentFrame]);
	UInt32	framesToRead		= (frameCount < framesRemaining ? frameCount : framesRemaining);
	UInt32	framesRead			= 0;
	
	if(0 < framesToRead)
		framesRead = [[self decoder] readAudio:bufferList frameCount:framesToRead];
	
	_framesReadInCurrentLoop	+= framesRead;
	_totalFramesRead			+= framesRead;
	
	if([self frameCount] == _framesReadInCurrentLoop || (0 == framesRead && 0 != framesToRead)) {
		++_completedLoops;
		_framesReadInCurrentLoop = 0;
		
		if([self loopCount] > [self completedLoops])
			[[self decoder] seekToFrame:[self startingFrame]];
	}
	
	return framesRead;	
}

- (NSUInteger)		completedLoops							{ return _completedLoops; }

- (SInt64)			totalFrames								{ return (([self loopCount] + 1) * [self frameCount]); }
- (SInt64)			currentFrame							{ return _totalFramesRead; }
- (SInt64)			framesRemaining							{ return ([self totalFrames] - [self currentFrame]); }

- (AudioStreamBasicDescription) pcmFormat					{ return [[self decoder] pcmFormat]; }
- (NSString *)		sourceFormatDescription					{ return [[self decoder] sourceFormatDescription]; }
- (NSString *)		pcmFormatDescription					{ return [[self decoder] pcmFormatDescription]; }

- (BOOL)			supportsSeeking							{ return [[self decoder] supportsSeeking]; }

- (SInt64) seekToFrame:(SInt64)frame
{
	NSParameterAssert(0 <= frame && frame < [self totalFrames]);
	
	_completedLoops				= frame / [self frameCount];
	_framesReadInCurrentLoop	= frame % [self frameCount];
	_totalFramesRead			= frame;

	[[self decoder] seekToFrame:[self startingFrame] + _framesReadInCurrentLoop];
	
	return [self currentFrame];
}

@end
