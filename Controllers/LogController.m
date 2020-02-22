/*
 *  Copyright (C) 2005 - 2020 Stephen F. Booth <me@sbooth.org>
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

static LogController	*sharedLog = nil;

static NSString			*SaveLogToolbarItemIdentifier		= @"org.sbooth.Max.Log.Toolbar.Save";
static NSString			*ClearLogToolbarItemIdentifier		= @"org.sbooth.Max.Log.Toolbar.Clear";

@interface LogController (Private)
- (void) insertObject:(NSDictionary *)entry inLogEntriesAtIndex:(NSUInteger)idx;
- (void) removeObjectFromLogEntriesAtIndex:(NSUInteger)idx;
@end

@implementation LogController

+ (LogController *) sharedController
{
	@synchronized(self) {
		if(nil == sharedLog)
			[[self alloc] init];
	}
	return sharedLog;
}

+ (id) allocWithZone:(NSZone *)zone
{
    @synchronized(self) {
        if(nil == sharedLog) {
            sharedLog = [super allocWithZone:zone];
			return sharedLog;
        }
    }
    return nil;
}

+ (void) logMessage:(NSString *)message
{
	[[LogController sharedController] logMessage:message];
}

+ (BOOL) accessInstanceVariablesDirectly	{ return NO; }

- (id)init
{
	if((self = [super initWithWindowNibName:@"Log"])) {
		_logEntries = [[NSMutableArray alloc] init];
		return self;
	}
	return nil;
}

- (void) dealloc
{
	[_logEntries release];		_logEntries = nil;
	
	[super dealloc];
}

- (id)			copyWithZone:(NSZone *)zone						{ return self; }
- (id)			retain											{ return self; }
- (NSUInteger)	retainCount										{ return UINT_MAX;  /* denotes an object that cannot be released */ }
- (oneway void)	release											{ /* do nothing */ }
- (id)			autorelease										{ return self; }

- (void) windowDidLoad
{
	[self setShouldCascadeWindows:NO];
	[self setWindowFrameAutosaveName:@"Log"];
	[[self window] setExcludedFromWindowsMenu:YES];
	
	// Select the most recent log entry
	if(0 < [self countOfLogEntries]) {
		[_logEntriesController setSelectedObjects:[NSArray arrayWithObject:[self objectInLogEntriesAtIndex:[self countOfLogEntries] - 1]]];
	}
}

- (void) awakeFromNib
{
    NSToolbar *toolbar = [[[NSToolbar alloc] initWithIdentifier:@"org.sbooth.Max.Log.Toolbar"] autorelease];
    
    [toolbar setAllowsUserCustomization:YES];
    [toolbar setAutosavesConfiguration:YES];
    
    [toolbar setDelegate:self];
	
    [[self window] setToolbar:toolbar];
	
	[_logEntriesController setSortDescriptors:[NSArray arrayWithObject:[[[NSSortDescriptor alloc] initWithKey:@"timestamp" ascending:NO] autorelease]]];
}

- (IBAction) clear:(id)sender
{
	@synchronized(self) {
		[self willChangeValueForKey:@"logEntries"];
		[_logEntries removeAllObjects];
		[self didChangeValueForKey:@"logEntries"];
	}
}

- (IBAction) save:(id)sender
{
	NSSavePanel *panel = [NSSavePanel savePanel];

	panel.allowedFileTypes = @[@"rtf"];

	[panel beginSheetModalForWindow:[self window] completionHandler:^(NSInteger result) {
		if(NSOKButton == result) {
			@synchronized(self) {
				NSString						*filename		= [[panel URL] path];
				NSMutableAttributedString		*logMessage		= [[NSMutableAttributedString alloc] init];

				// Build the strings
				for(NSUInteger i = 0; i < [self countOfLogEntries]; ++i) {

					NSDictionary *current = [self objectInLogEntriesAtIndex:i];

					[logMessage replaceCharactersInRange:NSMakeRange([logMessage length], 0) withString:[NSString stringWithFormat:@"%@", [current objectForKey:@"timestamp"]]];
					[logMessage replaceCharactersInRange:NSMakeRange([logMessage length], 0) withString:@"\t"];
					[logMessage replaceCharactersInRange:NSMakeRange([logMessage length], 0) withString:[current objectForKey:@"message"]];
					[logMessage replaceCharactersInRange:NSMakeRange([logMessage length], 0) withString:@"\n"];
				}

				// Apply style
				[logMessage addAttribute:NSFontAttributeName value:[NSFont fontWithName:@"Helvetica" size:11.0] range:NSMakeRange(0, [logMessage length])];

				NSData							*rtf			= [logMessage RTFFromRange:NSMakeRange(0, [logMessage length]) documentAttributes:@{ NSDocumentTypeDocumentAttribute: NSRTFTextDocumentType } ];

				BOOL fileCreated = [[NSFileManager defaultManager] createFileAtPath:filename contents:rtf attributes:nil];
				NSAssert(YES == fileCreated, NSLocalizedStringFromTable(@"Unable to create the output file.", @"Exceptions", @""));
			}	
		}
	}];
}

- (void) logMessage:(NSString *)message
{
	@synchronized(self) {
		NSDictionary *newEntry = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSDate date], @"unknown", message, nil]
															 forKeys:[NSArray arrayWithObjects:@"timestamp", @"component", @"message", nil]];

		// Modify the array directly instead of using the controller so the entry will be registered even if the user hasn't
		// displayed the log window
		[self insertObject:newEntry inLogEntriesAtIndex:[self countOfLogEntries]];
		[_logEntriesController setSelectedObjects:[NSArray arrayWithObject:newEntry]];
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
		NSToolbarFlexibleSpaceItemIdentifier, NSToolbarCustomizeToolbarItemIdentifier, nil];
}

- (NSArray *) toolbarAllowedItemIdentifiers:(NSToolbar *) toolbar 
{
    return [NSArray arrayWithObjects: SaveLogToolbarItemIdentifier, ClearLogToolbarItemIdentifier, 
		NSToolbarSeparatorItemIdentifier,  NSToolbarSpaceItemIdentifier, NSToolbarFlexibleSpaceItemIdentifier,
		NSToolbarCustomizeToolbarItemIdentifier,
		nil];
}

- (NSUInteger)		countOfLogEntries								{ return [_logEntries count]; }
- (NSDictionary *)	objectInLogEntriesAtIndex:(NSUInteger)index		{ return [_logEntries objectAtIndex:index]; }

@end

@implementation LogController (Private)

- (void) insertObject:(NSDictionary *)entry inLogEntriesAtIndex:(NSUInteger)index
{
	[_logEntries insertObject:entry atIndex:index];
}

- (void) removeObjectFromLogEntriesAtIndex:(NSUInteger)index
{
	[_logEntries removeObjectAtIndex:index];
}

@end
