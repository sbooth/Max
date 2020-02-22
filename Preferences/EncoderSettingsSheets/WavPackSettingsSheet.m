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

#import "WavPackSettingsSheet.h"
#import "WavPackEncoder.h"

@implementation WavPackSettingsSheet

+ (NSDictionary *) defaultSettings
{
	NSArray		*objects	= nil;
	NSArray		*keys		= nil;
	
	objects = [NSArray arrayWithObjects:
		[NSNumber numberWithInt:WAVPACK_STEREO_MODE_DEFAULT],
		[NSNumber numberWithInt:WAVPACK_COMPRESSION_MODE_DEFAULT],
		[NSNumber numberWithBool:NO],
		[NSNumber numberWithInt:WAVPACK_HYBRID_MODE_BITS_PER_SAMPLE],
		[NSNumber numberWithDouble:16.f],
		[NSNumber numberWithDouble:4800],
		[NSNumber numberWithDouble:0.f],
		nil];
	
	keys = [NSArray arrayWithObjects:
		@"stereoMode", 
		@"compressionMode", 
		@"enableHybridCompression",
		@"hybridMode",
		@"bitsPerSample",
		@"bitrate",
		@"noiseShaping", 
		nil];
	
	
	return [NSDictionary dictionaryWithObjects:objects forKeys:keys];
}

- (id) initWithSettings:(NSDictionary *)settings;
{
	if((self = [super initWithNibName:@"WavPackSettingsSheet" settings:settings])) {
		return self;
	}
	return nil;
}

@end
