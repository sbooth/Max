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

// A representation of the information for a single track contained in a CDTOC
@interface TrackDescriptor : NSObject
{
	unsigned		_session;
	unsigned 		_number;
	unsigned		_firstSector;
	unsigned 		_channels;
	BOOL			_preEmphasis;
	BOOL			_copyPermitted;
	BOOL			_dataTrack;
}

- (unsigned)		session;
- (void)			setSession:(unsigned)session;

- (unsigned)		number;
- (void)			setNumber:(unsigned)number;

- (unsigned)		firstSector;
- (void)			setFirstSector:(unsigned)firstSector;

- (unsigned)		channels;
- (void)			setChannels:(unsigned)channels;

- (BOOL)			preEmphasis;
- (void)			setPreEmphasis:(BOOL)preEmphasis;

- (BOOL)			copyPermitted;
- (void)			setCopyPermitted:(BOOL)copyPermitted;

- (BOOL)			dataTrack;
- (void)			setDataTrack:(BOOL)dataTrack;

@end
