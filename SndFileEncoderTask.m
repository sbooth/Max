/*
 *  $Id: EncoderTask.m 181 2005-11-28 08:38:43Z me $
 *
 *  Copyright (C) 2005 Stephen F. Booth <me@sbooth.org>
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

#import "SndFileEncoderTask.h"
#import "SndFileEncoder.h"

@implementation SndFileEncoderTask

- (id) initWithSource:(RipperTask *)source target:(NSString *)target track:(Track *)track formatInfo:(NSDictionary *)formatInfo
{
	if((self = [super initWithSource:source target:target track:track])) {
		_formatInfo = [formatInfo retain];
		_encoder	= [[SndFileEncoder alloc] initWithSource:[_source valueForKey:@"path"] format:[[_formatInfo valueForKey:@"sndfileFormat"] intValue]];
		return self;
	}
	return nil;
}

- (void) dealloc
{
	[_formatInfo release];
	[_encoder release];
	[super dealloc];
}

- (void) writeTags
{
}

- (NSString *) getType
{
	return [_formatInfo valueForKey:@"type"];
}

@end
