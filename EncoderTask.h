/*
 *  $Id: Ripper.h 64 2005-10-02 16:10:43Z me $
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

#import "Encoder.h"
#import "CompactDisc.h"
#import "Track.h"

@interface EncoderTask : NSObject 
{
	NSString		*_target;
	
	Encoder			*_encoder;
	
	NSString			*_trackName;
	NSNumber			*_completed;
	NSNumber			*_stopped;
	NSNumber			*_percentComplete;
	NSString			*_timeRemaining;
}

- (id) initWithSource:(NSString *) source target:(NSString *) target trackName:(NSString *) trackName;

- (void) run:(id) object;

- (void) stop;

- (void) removeOutputFile;

@end
