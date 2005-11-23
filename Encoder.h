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

#include "lame/lame.h"

/*
@protocol Encoder

- (void) setSource:(NSString *) source;
- (void) encodeToFile:(int) file;
- (void) requestStop; 

@end
*/

@interface Encoder : NSObject 
{
	NSString				*_sourceFilename;	
	int						_source;
		
	unsigned char			*_buf;
	ssize_t					_bufsize;

	int						_out;
	lame_global_flags		*_gfp;

	NSNumber				*_started;
	NSNumber				*_completed;
	NSNumber				*_stopped;
	NSNumber				*_percentComplete;
	NSNumber				*_shouldStop;
	NSNumber				*_timeRemaining;
}

- (id) initWithSource:(NSString *) source;

- (ssize_t) encodeToFile:(NSString *) filename;

- (void) requestStop;

@end
