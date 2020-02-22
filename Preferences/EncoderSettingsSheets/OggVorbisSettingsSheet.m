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

#import "OggVorbisSettingsSheet.h"
#import "OggVorbisEncoder.h"

@implementation OggVorbisSettingsSheet

+ (NSDictionary *) defaultSettings
{
	NSArray		*objects	= nil;
	NSArray		*keys		= nil;
	
	objects = [NSArray arrayWithObjects:
		[NSNumber numberWithInt:VORBIS_MODE_QUALITY],
		[NSNumber numberWithDouble:0.3],
		[NSNumber numberWithInt:6],
		[NSNumber numberWithBool:NO],
		nil];
	
	keys = [NSArray arrayWithObjects:
		@"mode", 
		@"quality", 
		@"bitrate",
		@"useConstantBitrate",
		nil];
	
	
	return [NSDictionary dictionaryWithObjects:objects forKeys:keys];
}

- (id) initWithSettings:(NSDictionary *)settings;
{
	if((self = [super initWithNibName:@"OggVorbisSettingsSheet" settings:settings])) {
		return self;
	}
	return nil;
}

@end
