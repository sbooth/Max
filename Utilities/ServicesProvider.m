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

#import "ServicesProvider.h"
#import "ApplicationController.h"
#import "FileFormatNotSupportedException.h"

@implementation ServicesProvider

- (void) encodeFile:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error
{
	NSArray *types = [pboard types];
	
	@try {
		if([types containsObject:NSFilenamesPboardType]) {
			[[ApplicationController sharedController] encodeFiles:[pboard propertyListForType:NSFilenamesPboardType]];
		}
		else if([types containsObject:NSStringPboardType]) {
			[[ApplicationController sharedController] encodeFiles:[NSArray arrayWithObject:[pboard stringForType:NSStringPboardType]]];
		}
	}
	
	@catch(FileFormatNotSupportedException *exception) {
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert addButtonWithTitle:NSLocalizedStringFromTable(@"OK", @"General", @"")];
		[alert setMessageText:[NSString stringWithFormat:NSLocalizedStringFromTable(@"An error occurred while opening the file \"%@\" for conversion.", @"Exceptions", @""), [[exception userInfo] objectForKey:@"filename"]]];
		[alert setInformativeText:[exception reason]];
		[alert setAlertStyle:NSWarningAlertStyle];		
		[alert runModal];
	}
	
	@catch(NSException *exception) {
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert addButtonWithTitle:NSLocalizedStringFromTable(@"OK", @"General", @"")];
		if(nil != [exception userInfo] && nil != [[exception userInfo] objectForKey:@"filename"]) {
			[alert setMessageText:[NSString stringWithFormat:NSLocalizedStringFromTable(@"An error occurred while opening the file \"%@\" for conversion.", @"Exceptions", @""), [[exception userInfo] objectForKey:@"filename"]]];
		}
		else {
			[alert setMessageText:NSLocalizedStringFromTable(@"An error occurred during file conversion.", @"Exceptions", @"")];
		}
		[alert setInformativeText:[exception reason]];
		[alert setAlertStyle:NSWarningAlertStyle];		
		[alert runModal];
	}
}

@end
