/*
 *  Copyright (C) 2005 - 2020 Stephen F. Booth <me@sbooth.org>
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
#include <CoreAudio/CoreAudioTypes.h>

#import "DecoderMethods.h"

@class CircularBuffer;

// A decoder reads audio data in some format and provides it as PCM:
//   - The audio stream is converted to PCM and placed in _pcmBuffer
@interface Decoder : NSObject <DecoderMethods>
{
	NSString						*_filename;		// The filename of the source

	AudioStreamBasicDescription		_pcmFormat;		// The type of PCM data provided by this source
	CircularBuffer					*_pcmBuffer;	// The buffer which holds the PCM audio data
	
	SInt64							_currentFrame;	// The first frame that will be returned from -readAudio:frameCount:
}

// Create a Decoder of the correct type for the given file
+ (instancetype) decoderWithFilename:(NSString *)filename;

- (instancetype) initWithFilename:(NSString *)filename;

// The source of the raw audio stream
- (NSString *) filename;

// The buffer which holds the PCM data
- (CircularBuffer *) pcmBuffer;

// Subclasses must implement this method!
- (void) fillPCMBuffer;

@end
