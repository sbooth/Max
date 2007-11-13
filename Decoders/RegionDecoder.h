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

#import <Cocoa/Cocoa.h>
#import "DecoderMethods.h"

#include <AudioToolbox/AudioToolbox.h>

@class Decoder;

@interface RegionDecoder : NSObject <DecoderMethods>
{
	Decoder			*_decoder;
	SInt64			_startingFrame;
	UInt32			_frameCount;
	unsigned		_loopCount;
	
	UInt32			_framesReadInCurrentLoop;
	SInt64			_totalFramesRead;
	unsigned		_completedLoops;
}	

// ========================================
// Creation
// ========================================
+ (id) decoderWithFilename:(NSString *)filename startingFrame:(SInt64)startingFrame;
+ (id) decoderWithFilename:(NSString *)filename startingFrame:(SInt64)startingFrame frameCount:(unsigned)frameCount;
+ (id) decoderWithFilename:(NSString *)filename startingFrame:(SInt64)startingFrame frameCount:(unsigned)frameCount loopCount:(unsigned)loopCount;

- (id) initWithFilename:(NSString *)filename startingFrame:(SInt64)startingFrame;
- (id) initWithFilename:(NSString *)filename startingFrame:(SInt64)startingFrame frameCount:(unsigned)frameCount;
- (id) initWithFilename:(NSString *)filename startingFrame:(SInt64)startingFrame frameCount:(unsigned)frameCount loopCount:(unsigned)loopCount;

// ========================================
// Properties
// ========================================
- (Decoder *) decoder;

- (SInt64) startingFrame;
- (void) setStartingFrame:(SInt64)startingFrame;

- (UInt32) frameCount;
- (void) setFrameCount:(UInt32)frameCount;

- (unsigned) loopCount;
- (void) setLoopCount:(unsigned)loopCount;

- (void) reset;
- (unsigned) completedLoops;

@end
