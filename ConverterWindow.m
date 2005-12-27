/*
 *  $Id: ConverterWindow.m 281 2005-12-27 07:26:06Z me $
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

#import "ConverterWindow.h"

#import "TaskMaster.h"
#import "FileFormatNotSupportedException.h"
#import "UtilityFunctions.h"

@interface ConverterWindow (Private)
- (void) alertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo;
@end

@implementation ConverterWindow

- (NSDragOperation) draggingEntered:(id <NSDraggingInfo>)sender 
{
    NSPasteboard		*pasteboard		= [sender draggingPasteboard];
	
    if([[pasteboard types] containsObject:NSFilenamesPboardType]) {
		return NSDragOperationCopy;
    }
	
    return NSDragOperationNone;
}

- (BOOL) performDragOperation:(id <NSDraggingInfo>)sender 
{
    NSPasteboard		*pasteboard		= [sender draggingPasteboard];

	@try {
		if([[pasteboard types] containsObject:NSFilenamesPboardType]) {
			NSArray			*filenames		= [pasteboard propertyListForType:NSFilenamesPboardType];
			unsigned		i;
			
			for(i = 0; i < [filenames count]; ++i) {
				NSString		*filename	= [filenames objectAtIndex:i];
				AudioMetadata	*metadata	= [AudioMetadata metadataFromFilename:filename];
				NSString		*basename	= [metadata outputBasename];
				
				createDirectoryStructure(basename);
				
				[[TaskMaster sharedController] encodeFile:filename outputBasename:basename metadata:metadata];
			}
		}
	}
	
	@catch(FileFormatNotSupportedException *exception) {
		displayExceptionSheet(exception, self, self, @selector(alertDidEnd:returnCode:contextInfo:), nil);
	}

	@catch(NSException *exception) {
		@throw;
	}
	
	return YES;
}

- (void) alertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	// Nothing for now
}

@end
