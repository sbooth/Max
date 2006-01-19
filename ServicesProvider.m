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

#import "ServicesProvider.h"

#import "TaskMaster.h"
#import "FileFormatNotSupportedException.h"
#import "IOException.h"

@implementation ServicesProvider

- (void) encodeFile:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error
{
	NSArray *types = [pboard types];
	
	@try {
		if([types containsObject:NSFilenamesPboardType]) {
			NSFileManager		*manager		= [NSFileManager defaultManager];
			NSArray				*filenames		= [pboard propertyListForType:NSFilenamesPboardType];
			NSString			*filename;
			NSArray				*subpaths;
			BOOL				isDir;
			AudioMetadata		*metadata;
			NSString			*basename;
			NSEnumerator		*enumerator;
			NSString			*subpath;
			unsigned			i;
			
			for(i = 0; i < [filenames count]; ++i) {
				filename = [filenames objectAtIndex:i];
				
				if([manager fileExistsAtPath:filename isDirectory:&isDir]) {
					if(isDir) {
						subpaths	= [manager subpathsAtPath:filename];
						enumerator	= [subpaths objectEnumerator];
						
						while((subpath = [enumerator nextObject])) {
							metadata	= [AudioMetadata metadataFromFilename:[NSString stringWithFormat:@"%@/%@", filename, subpath]];
							basename	= [metadata outputBasename];
							
							createDirectoryStructure(basename);
							@try {
								[[TaskMaster sharedController] encodeFile:[NSString stringWithFormat:@"%@/%@", filename, subpath] outputBasename:basename metadata:metadata];
							}
							@catch(FileFormatNotSupportedException *exception) {
								// Just let it go since we are traversing a folder
							}
						}
					}
					else {
						metadata	= [AudioMetadata metadataFromFilename:filename];
						basename	= [metadata outputBasename];
						
						createDirectoryStructure(basename);
						
						[[TaskMaster sharedController] encodeFile:filename outputBasename:basename metadata:metadata];
					}
				}				
			}
		}
		else if([types containsObject:NSStringPboardType]) {
			NSFileManager		*manager		= [NSFileManager defaultManager];
			NSString			*filename		= [pboard stringForType:NSStringPboardType];
			NSArray				*subpaths;
			BOOL				isDir;
			AudioMetadata		*metadata;
			NSString			*basename;
			NSEnumerator		*enumerator;
			NSString			*subpath;
			
			if([manager fileExistsAtPath:filename isDirectory:&isDir]) {
				if(isDir) {
					subpaths	= [manager subpathsAtPath:filename];
					enumerator	= [subpaths objectEnumerator];
					
					while((subpath = [enumerator nextObject])) {
						metadata	= [AudioMetadata metadataFromFilename:[NSString stringWithFormat:@"%@/%@", filename, subpath]];
						basename	= [metadata outputBasename];
						
						createDirectoryStructure(basename);
						@try {
							[[TaskMaster sharedController] encodeFile:[NSString stringWithFormat:@"%@/%@", filename, subpath] outputBasename:basename metadata:metadata];
						}
						@catch(FileFormatNotSupportedException *exception) {
							// Just let it go since we are traversing a folder
						}
					}
				}
				else {
					metadata	= [AudioMetadata metadataFromFilename:filename];
					basename	= [metadata outputBasename];
					
					createDirectoryStructure(basename);
					
					[[TaskMaster sharedController] encodeFile:filename outputBasename:basename metadata:metadata];
				}
			}
			else {
				@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"File not found", @"Exceptions", @"") userInfo:[NSDictionary dictionaryWithObject:filename forKey:@"filename"]];
			}
		}
	}
	
	@catch(FileFormatNotSupportedException *exception) {
		displayExceptionAlert(exception);
	}
	
	@catch(NSException *exception) {
		displayExceptionAlert(exception);
	}
}

@end
