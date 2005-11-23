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

#import "UtilityFunctions.h"

#import "FreeDBException.h"
#import "MallocException.h"
#import "IOException.h"
#import "LAMEException.h"
#import "EmptySelectionException.h"
#import "CustomNamingException.h"
#import "MissingResourceException.h"
#import "ParanoiaException.h"

static NSDateFormatter *sDateFormatter = nil;

NSString* 
makeStringSafeForFilename(NSString *string)
{
	NSCharacterSet		*characterSet		= [NSCharacterSet characterSetWithCharactersInString:@"/:"];
	NSMutableString		*result				= [[[NSMutableString alloc] initWithCapacity:[string length]] autorelease];
	NSRange				range;
	
	[result setString:string];
	
	range = [result rangeOfCharacterFromSet:characterSet];		
	while(range.location != NSNotFound && range.length != 0) {
		[result replaceCharactersInRange:range withString:@"_"];
		range = [result rangeOfCharacterFromSet:characterSet];		
	}
	
	return result;
}

void
validateAndCreateDirectory(NSString *path)
{
	NSFileManager		*manager			= [NSFileManager defaultManager];
	BOOL				isDir;

	if(NO == [manager fileExistsAtPath:path isDirectory:&isDir]) {
		if(NO == [manager createDirectoryAtPath:path attributes:nil]) {
			@throw [NSException exceptionWithName:@"NSObjectInaccessibleException" reason:@"Unable to create directory" userInfo:nil];
		}
	}
	else if(FALSE == isDir) {
		@throw [NSException exceptionWithName:@"NSObjectInaccessibleException" reason:@"Unable to create directory" userInfo:nil];
	}	
}

void
displayExceptionAlert(NSException *exception)
{
	displayExceptionSheet(exception, nil, nil, nil, nil);
}

void 
displayExceptionSheet(NSException	*exception,
					  NSWindow		*window,
					  id			delegate,
					  SEL			selector,
					  void			*contextInfo)
{
	NSBeep();
	
	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert addButtonWithTitle: @"OK"];
	if([exception isKindOfClass:[FreeDBException class]]) {
		[alert setMessageText: @"FreeDB Error"];
	}
	else if([exception isKindOfClass:[IOException class]]) {
		[alert setMessageText: @"Input/Output Error"];
	}
	else if([exception isKindOfClass:[MallocException class]]) {
		[alert setMessageText: @"Memory Error"];
	}
	else if([exception isKindOfClass:[LAMEException class]]) {
		[alert setMessageText: @"LAME Error"];
	}
	else if([exception isKindOfClass:[EmptySelectionException class]]) {
		[alert setMessageText: @"Empty Selection"];
	}
	else if([exception isKindOfClass:[CustomNamingException class]]) {
		[alert setMessageText: @"Custom Naming Error"];
	}
	else if([exception isKindOfClass:[MissingResourceException class]]) {
		[alert setMessageText: @"Missing Resource"];
	}
	else if([exception isKindOfClass:[ParanoiaException class]]) {
		[alert setMessageText: @"CDParanoia Error"];
	}
	else {
		[alert setMessageText: @"Unknown Error"];
	}
	[alert setInformativeText: [exception reason]];
	[alert setAlertStyle: NSWarningAlertStyle];
	
	if(nil == window) {
		if([alert runModal] == NSAlertFirstButtonReturn) {
			// do nothing
		} 
	}
	else {
		[alert beginSheetModalForWindow:window modalDelegate:delegate didEndSelector:selector contextInfo:contextInfo];
	}
}

NSString*
getID3v2Timestamp()
{
	@synchronized(sDateFormatter) {
		if(nil == sDateFormatter) {
			[NSDateFormatter setDefaultFormatterBehavior:NSDateFormatterBehavior10_4];
			sDateFormatter = [[NSDateFormatter alloc] init];
			[sDateFormatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"GMT"]];
			[sDateFormatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ss"];
		}
	}
	return [sDateFormatter stringFromDate:[NSDate date]];
}
