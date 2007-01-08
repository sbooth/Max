/*
 *  $Id$
 *
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

// This class only represents one session (a physical disc could contain many sessions)
@interface CompactDisc : NSObject
{
	NSString			*_deviceName;

	NSMutableArray		*_tracks;
	NSString			*_MCN;

	unsigned			_firstSector;
	unsigned			_lastSector;
	
	unsigned			_leadOut;
		
	unsigned			_length;
}

- (id)					initWithDeviceName:(NSString *)deviceName;

- (NSString *)			deviceName;

// Physical disc properties
- (unsigned)			firstSector;
- (unsigned)			lastSector;

- (unsigned)			leadOut;

- (NSString *)			MCN;

- (unsigned)			firstSectorForTrack:(unsigned)track;
- (unsigned)			lastSectorForTrack:(unsigned)track;

- (unsigned)			channelsForTrack:(unsigned)track;

- (BOOL)				trackHasPreEmphasis:(unsigned)track;
- (BOOL)				trackAllowsDigitalCopy:(unsigned)track;
- (BOOL)				trackContainsData:(unsigned)track;

- (NSString *)			ISRCForTrack:(unsigned)track;

// KVC accessors
- (unsigned)			countOfTracks;
- (NSDictionary *)		objectInTracksAtIndex:(unsigned)index;

// Derived properties
- (NSString *)			discID;
- (unsigned)			length;

@end
