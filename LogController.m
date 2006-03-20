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

#import "LogController.h"
#import "IOException.h"

static LogController	*sharedLog = nil;

static NSString			*SaveLogToolbarItemIdentifier		= @"SaveLog";
static NSString			*ClearLogToolbarItemIdentifier		= @"ClearLog";

@implementation LogController

+ (LogController *) sharedController
{
	@synchronized(self) {
		if(nil == sharedLog) {
			sharedLog = [[self alloc] init];
		}
	}
	return sharedLog;
}

+ (id) allocWithZone:(NSZone *)zone
{
    @synchronized(self) {
        if(nil == sharedLog) {
            return [super allocWithZone:zone];
        }
    }
    return sharedLog;
}

+ (void) logMessage:(NSString *)message
{
	[[LogController sharedController] logMessage:message];
}

- (id)init
{
	if((self = [super initWithWindowNibName:@"Log"])) {
		return self;
	}
	return nil;
}

- (id)			copyWithZone:(NSZone *)zone						{ return self; }
- (id)			retain											{ return self; }
- (unsigned)	retainCount										{ return UINT_MAX;  /* denotes an object that cannot be released */ }
- (void)		release											{ /* do nothing */ }
- (id)			autorelease										{ return self; }

- (void) windowDidLoad
{
	[self setShouldCascadeWindows:NO];
	[self setWindowFrameAutosaveName:@"Log"];
	[[self window] setExcludedFromWindowsMenu:YES];
}

- (void) awakeFromNib
{
    NSToolbar *toolbar = [[[NSToolbar alloc] initWithIdentifier:@"Max Log Toolbar"] autorelease];
    
    [toolbar setAllowsUserCustomization:YES];
    [toolbar setAutosavesConfiguration:YES];
    
    [toolbar setDelegate:self];
	
    [[self window] setToolbar:toolbar];
}

- (IBAction) clear:(id)sender
{
	@synchronized(self) {
		[[_logTextView textStorage] deleteCharactersInRange:NSMakeRange(0, [[_logTextView textStorage] length])];
	}
}

- (IBAction) save:(id)sender
{
	NSSavePanel *panel = [NSSavePanel savePanel];
	
	[panel setRequiredFileType:@"rtf"];
	
	[panel beginSheetForDirectory:nil file:nil modalForWindow:[self window] modalDelegate:self didEndSelector:@selector(savePanelDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

- (void) savePanelDidEnd:(NSSavePanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    if(NSOKButton == returnCode) {
		@synchronized(self) {
			NSString		*filename		= [sheet filename];
			NSTextStorage	*storage		= [_logTextView textStorage];
			NSData			*rtf			= [storage RTFFromRange:NSMakeRange(0, [storage length]) documentAttributes:nil];
			
			if(NO == [[NSFileManager defaultManager] createFileAtPath:filename contents:rtf attributes:nil]) {
				@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to create the output file.", @"Exceptions", @"") userInfo:@""];
			}
		}	
	}
}

- (void) logMessage:(NSString *)message
{
	@synchronized(self) {
		NSTextStorage					*storage		= [_logTextView textStorage];
		NSRange							range			= NSMakeRange([storage length], 0);
		NSMutableAttributedString		*logMessage		= [[NSMutableAttributedString alloc] init];
		NSDate							*now			= [NSDate date];
		
		// Build the string
		[logMessage replaceCharactersInRange:NSMakeRange([logMessage length], 0) withString:[NSString stringWithFormat:@"%@", now]];
		[logMessage replaceCharactersInRange:NSMakeRange([logMessage length], 0) withString:@": "];
		[logMessage replaceCharactersInRange:NSMakeRange([logMessage length], 0) withString:message];
		[logMessage replaceCharactersInRange:NSMakeRange([logMessage length], 0) withString:@"\n"];
		
		// Apply styles
		[logMessage addAttribute:NSFontAttributeName value:[NSFont fontWithName:@"Helvetica" size:11.0] range:NSMakeRange(0, [logMessage length])];
		
		[storage beginEditing];
		[storage replaceCharactersInRange:range withAttributedString:logMessage];
		[storage endEditing];
		
		[logMessage release];
	}
}

- (NSToolbarItem *) toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag 
{
    NSToolbarItem *toolbarItem = nil;
    
    if([itemIdentifier isEqualToString:SaveLogToolbarItemIdentifier]) {
        toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
		
		[toolbarItem setLabel: NSLocalizedStringFromTable(@"Save", @"Log", @"")];
		[toolbarItem setPaletteLabel: NSLocalizedStringFromTable(@"Save", @"Log", @"")];
		[toolbarItem setToolTip: NSLocalizedStringFromTable(@"Save log contents to disk", @"Log", @"")];
		[toolbarItem setImage: [NSImage imageNamed:@"SaveLogToolbarImage"]];
		
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(save:)];
	}
	else if([itemIdentifier isEqualToString:ClearLogToolbarItemIdentifier]) {
        toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
		
		[toolbarItem setLabel: NSLocalizedStringFromTable(@"Clear", @"Log", @"")];
		[toolbarItem setPaletteLabel: NSLocalizedStringFromTable(@"Clear", @"Log", @"")];		
		[toolbarItem setToolTip: NSLocalizedStringFromTable(@"Clear log contents", @"Log", @"")];
		[toolbarItem setImage: [NSImage imageNamed:@"ClearLogToolbarImage"]];
		
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(clear:)];
	}
	else {
		toolbarItem = nil;
    }
	
    return toolbarItem;
}

- (NSArray *) toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar 
{
    return [NSArray arrayWithObjects: SaveLogToolbarItemIdentifier, ClearLogToolbarItemIdentifier, 
		NSToolbarFlexibleSpaceItemIdentifier, NSToolbarCustomizeToolbarItemIdentifier,nil];
}

- (NSArray *) toolbarAllowedItemIdentifiers:(NSToolbar *) toolbar 
{
    return [NSArray arrayWithObjects: SaveLogToolbarItemIdentifier, ClearLogToolbarItemIdentifier, 
		NSToolbarSeparatorItemIdentifier,  NSToolbarSpaceItemIdentifier, NSToolbarFlexibleSpaceItemIdentifier,
		NSToolbarCustomizeToolbarItemIdentifier,
		nil];
}

@end
