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

#import "FreeDBMatchSheet.h"

#import "MissingResourceException.h"

@implementation FreeDBMatchSheet

- (id) initWithCompactDiscDocument:(CompactDiscDocument *)doc;
{
	if((self = [super init])) {
		if(NO == [NSBundle loadNibNamed:@"FreeDBMatches" owner:self])  {
			@throw [MissingResourceException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to load required resource", @"Exceptions", @"")
														userInfo:[NSDictionary dictionaryWithObject:@"FreeDBMatches.nib" forKey:@"filename"]];
		}
		
		_doc = [doc retain];
		
		return self;
	}
	return nil;
}

- (void) dealloc
{
	[_doc release];
	[super dealloc];
}

- (void) showFreeDBMatches
{
    [[NSApplication sharedApplication] beginSheet:_sheet modalForWindow:[_doc windowForSheet] modalDelegate:self didEndSelector:@selector(didEndSheet:returnCode:contextInfo:) contextInfo:nil];
}

- (IBAction) cancel:(id)sender
{
    [[NSApplication sharedApplication] endSheet:_sheet];
}

- (IBAction) useSelected:(id)sender
{	
	[_doc updateDiscFromFreeDB:[_matches objectAtIndex:[_table selectedRow]]];	
    [[NSApplication sharedApplication] endSheet:_sheet];
}

- (void) didEndSheet:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    [sheet orderOut:self];
}

@end
