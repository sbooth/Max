/*
 *  Copyright (C) 2006 - 2020 Stephen F. Booth <me@sbooth.org>
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
#import "Decoder.h"

#include <mad/mad.h>

@interface MPEGDecoder : Decoder
{
	FILE				*_file;
	unsigned char		*_inputBuffer;
	
	AudioBufferList		*_bufferList;
	
	uint32_t			_mpegFramesDecoded;
	uint32_t			_totalMPEGFrames;
	
	NSUInteger			_samplesToSkipInNextFrame;
	
	SInt64				_myCurrentFrame;
	SInt64				_totalFrames;
	
	uint16_t			_encoderDelay;
	uint16_t			_encoderPadding;
	
	SInt64				_samplesDecoded;
	NSUInteger			_samplesPerMPEGFrame;
	
	BOOL				_foundXingHeader;
	BOOL				_foundLAMEHeader;
	
	off_t				_fileBytes;
	uint8_t				_xingTOC [100];
	
	struct mad_stream	_mad_stream;
	struct mad_frame	_mad_frame;
	struct mad_synth	_mad_synth;
}

@end
