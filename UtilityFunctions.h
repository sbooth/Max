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

#ifdef __cplusplus
extern "C" {
#endif

// Remove /: characters and replace with _
NSString* 
makeStringSafeForFilename(NSString *string);

// Create path if it does not exist; throw an exception if it exists and is a file
void validateAndCreateDirectory(NSString *path);

// Display a modal alert for exception
void displayExceptionAlert(NSException *exception);

// Display an alert sheet for an exception
void displayExceptionSheet(NSException	*exception,
						   NSWindow		*window,
						   id			delegate,
						   SEL			selector,
						   void			*userInfo);

// Get a timestamp in the ID3v2 format
NSString*
getID3v2Timestamp();

#ifdef __cplusplus
}
#endif
	