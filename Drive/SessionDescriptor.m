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

#import "SessionDescriptor.h"

@implementation SessionDescriptor

+ (BOOL)				accessInstanceVariablesDirectly			{ return NO; }

- (unsigned)			number									{ return _number; }
- (void)				setNumber:(unsigned)number				{ _number = number; }

- (unsigned)			firstTrack								{ return _firstTrack; }
- (void)				setFirstTrack:(unsigned)firstTrack		{ _firstTrack = firstTrack; }

- (unsigned)			lastTrack								{ return _lastTrack; }
- (void)				setLastTrack:(unsigned)lastTrack		{ _lastTrack = lastTrack; }

- (unsigned)			leadOut									{ return _leadOut; }
- (void)				setLeadOut:(unsigned)leadOut			{ _leadOut = leadOut; }

- (NSString *) description
{
	return [NSString stringWithFormat:@"{\n\tSession: %u\n\tFirst Track: %u\n\tLast Track: %u\n\tLead Out: %u\n}", [self number], [self firstTrack], [self lastTrack], [self leadOut]];
}

@end
