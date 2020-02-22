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

#import "SessionDescriptor.h"

@implementation SessionDescriptor

+ (BOOL)				accessInstanceVariablesDirectly			{ return NO; }

- (NSUInteger)			number									{ return _number; }
- (void)				setNumber:(NSUInteger)number			{ _number = number; }

- (NSUInteger)			firstTrack								{ return _firstTrack; }
- (void)				setFirstTrack:(NSUInteger)firstTrack	{ _firstTrack = firstTrack; }

- (NSUInteger)			lastTrack								{ return _lastTrack; }
- (void)				setLastTrack:(NSUInteger)lastTrack		{ _lastTrack = lastTrack; }

- (NSUInteger)			leadOut									{ return _leadOut; }
- (void)				setLeadOut:(NSUInteger)leadOut			{ _leadOut = leadOut; }

- (NSString *) description
{
	return [NSString stringWithFormat:@"{\n\tSession: %lu\n\tFirst Track: %lu\n\tLast Track: %lu\n\tLead Out: %lu\n}", (unsigned long)[self number], (unsigned long)[self firstTrack], (unsigned long)[self lastTrack], (unsigned long)[self leadOut]];
}

@end
