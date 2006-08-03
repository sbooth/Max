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

#import "FilesTableView.h"

@implementation FilesTableView

- (unsigned) draggingSourceOperationMaskForLocal:(BOOL)isLocal
{
	return (isLocal ? NSDragOperationMove : NSDragOperationCopy);
}

- (void) keyDown:(NSEvent *)event
{
	unichar			key		= [[event charactersIgnoringModifiers] characterAtIndex:0];    
	unsigned int	flags	= ( [event modifierFlags] & 0x00FF );
    
	if(NSDeleteCharacter == key && 0 == flags) {
		if(-1 == [self selectedRow]) {
			NSBeep(); }
		else {
			[_filesController removeObjectsAtArrangedObjectIndexes:[self selectedRowIndexes]];
		}
	}
	else {
		[super keyDown:event]; // let somebody else handle the event 
	}
}

@end
