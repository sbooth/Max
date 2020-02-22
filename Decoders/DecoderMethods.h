/*
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
#include <CoreAudio/CoreAudioTypes.h>

@protocol DecoderMethods

// The type of PCM data provided by this Decoder
- (AudioStreamBasicDescription) pcmFormat;

// A descriptive string of the PCM data format
- (NSString *) pcmFormatDescription;

// Attempt to read frameCount frames of audio, returning the actual number of frames read
- (UInt32) readAudio:(AudioBufferList *)bufferList frameCount:(UInt32)frameCount;

// The format of audio data provided by the source
- (NSString *) sourceFormatDescription;

// Input audio frame information
- (SInt64) totalFrames;
- (SInt64) currentFrame;

- (BOOL) supportsSeeking;
- (SInt64) seekToFrame:(SInt64)frame;

@end
