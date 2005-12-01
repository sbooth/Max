/*
 *  $Id: PreferencesController.h 189 2005-12-01 01:55:55Z me $
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

#import "FreeDBPreferencesController.h"
#import "FreeDB.h"
#import "FreeDBSite.h"

@implementation FreeDBPreferencesController

- (id) init
{
	if((self = [super initWithWindowNibName:@"FreeDBPreferences"])) {
		return self;		
	}
	return nil;
}

- (IBAction) refreshList:(id)sender
{
	NSLog(@"refreshList");
	@try {
		// Get mirror list
		FreeDB *freeDB = [[[FreeDB alloc] init] autorelease];
		[self setValue:[freeDB fetchSites] forKey:@"mirrors"];
	}
	
	@catch(NSException *exception) {
		displayExceptionAlert(exception);
	}
	
	@finally {
	}
}

- (IBAction) selectMirror:(id)sender
{
	NSLog(@"selectMirror");
	NSArray *selectedObjects = [_mirrorsController selectedObjects];
	if(0 < [selectedObjects count]) {
		FreeDBSite					*mirror					= [selectedObjects objectAtIndex:0];
		NSUserDefaultsController	*defaultsController		= [NSUserDefaultsController sharedUserDefaultsController];
		[[defaultsController values] setValue:[mirror valueForKey:@"address"] forKey:@"server"];
		[[defaultsController values] setValue:[mirror valueForKey:@"port"] forKey:@"port"];
		[[defaultsController values] setValue:[mirror valueForKey:@"protocol"] forKey:@"protocol"];
	}
}

@end
