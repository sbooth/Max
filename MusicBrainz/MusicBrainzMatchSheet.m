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

#import "MusicBrainzMatchSheet.h"

@implementation MusicBrainzMatchSheet

- (id) init
{
	if((self = [super init])) {
		BOOL	result;
		
		result = [NSBundle loadNibNamed:@"MusicBrainzMatchSheet" owner:self];
		NSAssert1(YES == result, NSLocalizedStringFromTable(@"Your installation of Max appears to be incomplete.", @"Exceptions", @""), @"MusicBrainzMatchSheet.nib");
		
		return self;
	}
	return nil;
}

- (void) awakeFromNib
{
	[_matchesController setSortDescriptors:[NSArray arrayWithObjects:
		[[[NSSortDescriptor alloc] initWithKey:@"artist" ascending:YES] autorelease],
		[[[NSSortDescriptor alloc] initWithKey:@"title" ascending:YES] autorelease],
		nil]];
}

- (NSWindow *)		sheet					{ return [[_sheet retain] autorelease]; }
- (NSDictionary *)	selectedRelease			{ return [[_matchesController selectedObjects] firstObject]; }

- (IBAction)		cancel:(id)sender		{ [[NSApplication sharedApplication] endSheet:[self sheet] returnCode:NSCancelButton]; }
- (IBAction)		ok:(id)sender			{ [[NSApplication sharedApplication] endSheet:[self sheet] returnCode:NSOKButton]; }

@end
