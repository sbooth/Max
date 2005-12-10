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

#import <Cocoa/Cocoa.h>

@interface FormatsPreferencesController : NSWindowController 
{
	NSMutableArray					*_libsndfileFormats;
	NSMutableArray					*_CAFormats;
	
	IBOutlet NSArrayController		*_libsndfileTypesController;
	IBOutlet NSArrayController		*_libsndfileSubtypesController;
	IBOutlet NSArrayController		*_libsndfileSelectedFormatsController;

	IBOutlet NSArrayController		*_CATypesController;
	IBOutlet NSArrayController		*_CASubtypesController;
	IBOutlet NSArrayController		*_CASelectedFormatsController;
}

- (IBAction)		addlibsndfileFormat:(id)sender;
- (IBAction)		removelibsndfileFormat:(id)sender;

- (IBAction)		addCAFormat:(id)sender;
- (IBAction)		removeCAFormat:(id)sender;

@end
