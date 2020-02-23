/*
 *  Copyright (C) 2005 - 2020 Stephen F. Booth <me@sbooth.org>
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

#include <cdparanoia/cdda_interface.h>
#include <cdparanoia/cdda_paranoia.h>

#import "Ripper.h"

@interface ParanoiaRipper : Ripper
{
	cdrom_drive				*_drive;
	cdrom_paranoia			*_paranoia;
	
	int						_maximumRetries;
	
	NSNumber				*_grandTotalSectors;
	NSNumber				*_sectorsRead;
	NSNumber				*_sectorsWritten;
	NSDate					*_startTime;
}

- (instancetype)			initWithSectors:(NSArray *)sectors deviceName:(NSString *)deviceName;

@end
