/*
 *  $Id$
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

#import <Cocoa/Cocoa.h>

#import "Track.h"
#import "CompactDisc.h"

/*
 @protocol Ripper
 
 - (void) setDisc:(CompactDisc *) disc;
 - (void) setTrack:(Track *) track;
 - (void) ripToFile:(int) file;
 - (void) requestStop; 
 
 @end
 */

@interface Ripper : NSObject 
{
	CompactDisc				*_disc;
	Track					*_track;

	ssize_t					_firstSector;
	ssize_t					_lastSector;
	ssize_t					_blockSize;
	ssize_t					_totalBytes;
	
	unsigned char			*_buf;
	ssize_t					_bufsize;
	
	int						_fd;
	
	NSNumber				*_started;
	NSNumber				*_completed;
	NSNumber				*_stopped;
	NSNumber				*_percentComplete;
	NSNumber				*_shouldStop;
	NSString				*_timeRemaining;
}

- (id) initWithDisc:(CompactDisc *) disc forTrack:(Track *) track;

- (void) requestStop;

- (void) ripToFile:(int) file;

@end
