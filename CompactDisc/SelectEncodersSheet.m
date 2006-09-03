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

#import "SelectEncodersSheet.h"
#import "MissingResourceException.h"

#import "UtilityFunctions.h"

// A bastardized hybrid of an application-modal sheet (for file conversion) and
// a regular sheet (for ripping)

@implementation SelectEncodersSheet

- (id) init
{
	if((self = [super init])) {
		if(NO == [NSBundle loadNibNamed:@"SelectEncodersSheet" owner:self])  {
			@throw [MissingResourceException exceptionWithReason:NSLocalizedStringFromTable(@"Your installation of Max appears to be incomplete.", @"Exceptions", @"")
														userInfo:[NSDictionary dictionaryWithObject:@"SelectEncodersSheet.nib" forKey:@"filename"]];
		}
				
		_doc = nil;
		
		return self;
	}
	return nil;
}

- (id) initWithCompactDiscDocument:(CompactDiscDocument *)doc;
{
	if((self = [self init])) {
		
		_doc = [doc retain];
		
		return self;
	}
	return nil;
}

- (void) dealloc
{
	[_doc release];		_doc = nil;
	
	[super dealloc];
}

- (void) awakeFromNib
{
	[_encoderController setSelectedObjects:getDefaultOutputFormats()];
}

- (NSWindow *) sheet
{
	return _sheet;
}

- (void) showSheet
{
	if(nil != _doc) {
		[self showSheet:[_doc windowForSheet]];
	}
}

- (void) showSheet:(NSWindow *)window
{
	[[NSApplication sharedApplication] beginSheet:_sheet modalForWindow:window modalDelegate:self didEndSelector:@selector(didEndSheet:returnCode:contextInfo:) contextInfo:nil];
}

- (NSArray *) selectedEncoders
{
	return [_encoderController selectedObjects];
}

- (IBAction) cancel:(id)sender
{
    [[NSApplication sharedApplication] endSheet:_sheet];

	if(nil == _doc) {
		[[NSApplication sharedApplication] stopModalWithCode:NSCancelButton];
	}
}

- (IBAction) ok:(id)sender
{	
    [[NSApplication sharedApplication] endSheet:_sheet];
	
	if(nil == _doc) {
		[[NSApplication sharedApplication] stopModalWithCode:NSOKButton];
	}
	else {
		[_doc setActiveEncoders:[self selectedEncoders]];
		[_doc customEncodersSelected];
	}
}

- (void) didEndSheet:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    [sheet orderOut:self];
}

@end
