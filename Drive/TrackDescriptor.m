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

#import "TrackDescriptor.h"

@implementation TrackDescriptor

+ (BOOL)				accessInstanceVariablesDirectly			{ return NO; }

- (unsigned)			session									{ return _session; }
- (void)				setSession:(unsigned)session			{ _session = session; }

- (unsigned)			number									{ return _number; }
- (void)				setNumber:(unsigned)number				{ _number = number; }

- (unsigned)			firstSector								{ return _firstSector; }
- (void)				setFirstSector:(unsigned)firstSector	{ _firstSector = firstSector; }

- (unsigned)			channels								{ return _channels; }
- (void)				setChannels:(unsigned)channels			{ _channels = channels; }

- (BOOL)				preEmphasis								{ return _preEmphasis; }
- (void)				setPreEmphasis:(BOOL)preEmphasis		{ _preEmphasis = preEmphasis; }

- (BOOL)				copyPermitted							{ return _copyPermitted; }
- (void)				setCopyPermitted:(BOOL)copyPermitted	{ _copyPermitted = copyPermitted; }

- (BOOL)				dataTrack								{ return _dataTrack; }
- (void)				setDataTrack:(BOOL)dataTrack			{ _dataTrack = dataTrack; }

- (NSString *) description
{
	return [NSString stringWithFormat:@"{\n\tSession: %u\n\tTrack: %u\n\tFirst Sector: %i\n}", [self session], [self number], [self firstSector]];
}

@end

