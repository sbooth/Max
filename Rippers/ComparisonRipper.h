/*
 *  $Id$
 *
 *  Copyright (C) 2005, 2006 Stephen F. Booth <me@sbooth.org>
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

#import "Ripper.h"
#import "Drive.h"

@interface ComparisonRipper : Ripper
{
	Drive					*_drive;

	int						_driveOffset;

	unsigned				_requiredMatches;
	unsigned				_maximumRetries;
	BOOL					_useHashes;
	BOOL					_useC2;
	
	unsigned				_grandTotalSectors;
	unsigned				_sectorsRead;
	NSDate					*_startTime;
}

- (id)						initWithSectors:(NSArray *)sectors deviceName:(NSString *)deviceName;

- (int)						driveOffset;
- (void)					setDriveOffset:(int)driveOffset;

- (unsigned)				requiredMatches;
- (void)					setRequiredMatches:(unsigned)matches;

- (unsigned)				maximumRetries;
- (void)					setMaximumRetries:(unsigned)retries;

- (BOOL)					useHashes;
- (void)					setUseHashes:(BOOL)useHashes;

- (BOOL)					useC2;
- (void)					setUseC2:(BOOL)useC2;

@end
