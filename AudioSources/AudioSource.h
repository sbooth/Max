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

#import <Cocoa/Cocoa.h>
#include <CoreAudio/CoreAudioTypes.h>

#import "ReaderMethods.h"
#import "CircularBuffer.h"

// An AudioSource reads audio data in some format and provides it as PCM:
//   - The raw audio stream is provided by _reader
//   - The audio stream is converted to PCM and placed in _pcmBuffer
@interface AudioSource : NSObject
{
//	id <ReaderMethods>				_reader;		// Access to the raw audio stream
	NSString						*_filename;		// The filename of the source

	AudioStreamBasicDescription		_pcmFormat;		// The type of PCM data provided by this source
	CircularBuffer					*_pcmBuffer;	// The buffer which holds the PCM audio data
}

// Create an AudioSource of the correct type for the given reader
//+ (id)								audioSourceForReader:(id <ReaderMethods>)reader;
+ (id)								audioSourceForFilename:(NSString *)filename;


// The source of the raw audio stream
//- (id <ReaderMethods>)				reader;
//- (void)							setReader:(id <ReaderMethods>)reader;
- (NSString *)						filename;
- (void)							setFilename:(NSString *)filename;

// The type of PCM data provided by the source
- (AudioStreamBasicDescription)		pcmFormat;

// A descriptive string of the PCM data format
- (NSString *)						pcmFormatDescription;

// The buffer which holds the PCM data
- (CircularBuffer *)				pcmBuffer;

// Attempt to read frameCount frames of audio, returning the actual number read
- (UInt32)							readAudio:(AudioBufferList *)bufferList frameCount:(UInt32)frameCount;

// ========================================
// Subclasses must implement these methods!
// ========================================
// The format of audio data provided by the source
- (NSString *)		sourceFormatDescription;

// Input audio frame information
- (SInt64)			totalFrames;
- (SInt64)			currentFrame;
- (SInt64)			seekToFrame:(SInt64)frame;

// Finalize reader setup prior to reading
- (void)			finalizeSetup;

// The meat & potatoes- 
- (void)			fillPCMBuffer;
// ========================================

@end
