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

#import "CompactDiscController.h"

@implementation CompactDiscController

- (id) init
{
	if((self = [super initWithWindowNibName:@"CompactDiscDocument"])) {
	}
	return self;
}

#if 0
- (id) initWithDisc: (CompactDisc *) disc
{
	@try {
		if((self = [super initWithWindowNibName:@"CompactDisc"])) {
			_disc	= [disc retain];
			_stop	= [NSNumber numberWithBool:FALSE];
			
			[[self window] setRepresentedFilename:[NSString stringWithFormat:@"%@/0x%.8x.xml", gDataDir, [_disc cddb_id]]];
						
			// Load data from file if it exists
			NSFileManager	*manager	= [NSFileManager defaultManager];
			BOOL			fileExists	= [manager fileExistsAtPath:[[self window] representedFilename] isDirectory:nil];

			if(fileExists) {
				NSData					*xmlData	= [manager contentsAtPath:[[self window] representedFilename]];
				NSDictionary			*discInfo;
				NSPropertyListFormat	format;
				NSString				*error;
				
				discInfo = [NSPropertyListSerialization propertyListFromData:xmlData mutabilityOption:NSPropertyListImmutable format:&format errorDescription:&error];
				if(nil != discInfo) {
					[_disc setPropertiesFromDictionary:discInfo];
				}
				else {
					[error release];
				}
			}
			
			if(fileExists && nil != [disc valueForKey:@"title"]) {
				[[self window] setTitle:[disc valueForKey:@"title"]];
			}
			else {
				[[self window] setTitle:[NSString stringWithFormat: @"Compact Disc 0x%.8x", [_disc cddb_id]]];
			}
			[self setWindowFrameAutosaveName:[NSString stringWithFormat: @"Compact Disc 0x%.8x", [_disc cddb_id]]];	
			[self showWindow:self];

			[_disc addObserver:self forKeyPath:@"title" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:nil];
			
			// Query FreeDB if disc not previously seen
			if(NO == fileExists) {
				[self getCDInformation:nil];
			}
		}
	}
	
	@catch(NSException *exception) {
		[_disc removeObserver:self forKeyPath:@"title"];
		[_disc release];
		[self release];
		displayExceptionAlert(exception);
		@throw;
	}
	
	@finally {
		
	}
	
	return self;
}
#endif

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if([keyPath isEqual:@"title"]) {
		if([[change objectForKey:NSKeyValueChangeNewKey] isEqual:[NSNull null]]) {
			//[[self window] setTitle:[NSString stringWithFormat: @"Compact Disc 0x%.8x", [_disc cddb_id]]];
		}
		else {
			[[self window] setTitle:[change objectForKey:NSKeyValueChangeNewKey]];
		}
    }
}


#pragma mark NSWindow delegate methods

- (void) windowWillClose:(NSNotification *) aNotification
{
	// Save data from file if it exists
	NSFileManager			*manager	= [NSFileManager defaultManager];
	NSData					*xmlData;
	NSString				*error;
	
	if(! [manager fileExistsAtPath:[[self window] representedFilename] isDirectory:nil]) {
		[manager createFileAtPath:[[self window] representedFilename] contents:nil attributes:nil];
	}
	
	xmlData = nil;//[NSPropertyListSerialization dataFromPropertyList:[_disc getDictionary] format:NSPropertyListXMLFormat_v1_0 errorDescription:&error];
	if(nil != xmlData) {
		[xmlData writeToFile:[[self window] representedFilename] atomically:YES];
	}
	else {
		[error release];
	}
}

@end
