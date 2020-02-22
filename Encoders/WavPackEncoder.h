/*
 *  Copyright (C) 2005 - 2007 Stephen F. Booth <me@sbooth.org>
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

#import "Encoder.h"

// Tag values for NSPopupButton
enum {	
	WAVPACK_STEREO_MODE_DEFAULT				= 0,
	WAVPACK_STEREO_MODE_STEREO				= 1,
	WAVPACK_STEREO_MODE_JOINT_STEREO		= 2,

	WAVPACK_COMPRESSION_MODE_DEFAULT		= 0,
	WAVPACK_COMPRESSION_MODE_HIGH			= 1,
	WAVPACK_COMPRESSION_MODE_FAST			= 2,
	WAVPACK_COMPRESSION_MODE_VERY_HIGH		= 3,
	
	WAVPACK_HYBRID_MODE_BITS_PER_SAMPLE		= 0,
	WAVPACK_HYBRID_MODE_BITRATE				= 1,
	
};

@interface WavPackEncoder : Encoder
{
	int				_flags;
	float			_noiseShaping;
	float			_bitrate;
}

@end
