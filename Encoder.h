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

#import "CompactDiscController.h"
#import "CompactDisc.h"
#import "Track.h"
#import "Ripper.h"

#include "lame/lame.h"

@interface Encoder : NSObject 
{
	CompactDiscController		*_controller;
	CompactDisc					*_disc;
	Track						*_track;
	Ripper						*_source;
	
	int							_fd;
	lame_global_flags			*_gfp;
	NSString					*_filename;
}

- (id) initWithController:(CompactDiscController *)controller usingSource:(Ripper *)source forDisc:(CompactDisc *)disc forTrack:(Track *)track toFile:(NSString *)filename;

- (ssize_t) encode: (NSData *) data;
- (ssize_t) finishEncode;
@end
