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

#include <lame/lame.h>

#import "Encoder.h"

// Tag values for NSPopupButton
enum {
	LAME_TARGET_BITRATE						= 0,
	LAME_TARGET_QUALITY						= 1,
	
	LAME_ENCODING_ENGINE_QUALITY_FAST		= 0,
	LAME_ENCODING_ENGINE_QUALITY_STANDARD	= 1,
	LAME_ENCODING_ENGINE_QUALITY_HIGH		= 2,
	
	LAME_VARIABLE_BITRATE_MODE_STANDARD		= 0,
	LAME_VARIABLE_BITRATE_MODE_FAST			= 1,
	
	LAME_USER_PRESET_BEST					= 1,
	LAME_USER_PRESET_TRANSPARENT			= 2,
	LAME_USER_PRESET_PORTABLE				= 3,
	LAME_USER_PRESET_CUSTOM					= 0	,
	
	LAME_STEREO_MODE_DEFAULT				= 0,
	LAME_STEREO_MODE_MONO					= 1,
	LAME_STEREO_MODE_STEREO					= 2,
	LAME_STEREO_MODE_JOINT_STEREO			= 3,
};

@interface MP3Encoder : Encoder
{	
	FILE					*_out;
	lame_global_flags		*_gfp;
	UInt32					_sourceBitsPerChannel;
}

@end
