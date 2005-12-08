/*
 *  $Id: PreferencesController.m 212 2005-12-05 16:47:24Z me $
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

#import "PreferencesController.h"
#import "MissingResourceException.h"

#import "UtilityFunctions.h"


static PreferencesController	*sharedPreferences					= nil;

static NSString		*GeneralPreferencesToolbarItemIdentifier		= @"GeneralPreferences";
static NSString		*FormatsPreferencesToolbarItemIdentifier		= @"FormatsPreferences";
static NSString		*OutputPreferencesToolbarItemIdentifier			= @"OutputPreferences";
static NSString		*FreeDBPreferencesToolbarItemIdentifier			= @"FreeDBPreferences";
static NSString		*RipperPreferencesToolbarItemIdentifier			= @"RipperPreferences";
static NSString		*LAMEPreferencesToolbarItemIdentifier			= @"LAMEPreferences";
static NSString		*OggVorbisPreferencesToolbarItemIdentifier		= @"OggVorbisPreferences";
static NSString		*AACPreferencesToolbarItemIdentifier			= @"AACPreferences";

@interface PreferencesController (Private)
- (void) setupToolbar;
- (void) selectPrefsPane:(id)sender;
@end

@implementation PreferencesController

// Set up initial defaults
+ (void) initialize
{
	NSString				*defaultsPath;
    NSMutableDictionary		*defaultsDictionary;
    NSDictionary			*initialValuesDictionary;
    NSArray					*resettableUserDefaultsKeys;
	NSArray					*defaultFiles;
	unsigned				i;

	@try {
		defaultsDictionary	= [[[NSMutableDictionary alloc] initWithCapacity:20] autorelease];
		defaultFiles		= [NSArray arrayWithObjects:@"MediaControllerDefaults", @"FreeDBDefaults", @"CompactDiscDocumentDefaults", @"ParanoiaDefaults", @"LAMEDefaults", @"TrackDefaults", @"TaskMasterDefaults", @"OggVorbisDefaults", @"AACDefaults", nil];
		// Add the default values as resettable
		for(i = 0; i < [defaultFiles count]; ++i) {
			defaultsPath = [[NSBundle mainBundle] pathForResource:[defaultFiles objectAtIndex:i] ofType:@"plist"];
			if(nil == defaultsPath) {
				@throw [MissingResourceException exceptionWithReason:[NSString stringWithFormat:@"Unable to load %@.plist  Some preferences may not display correctly.", [defaultFiles objectAtIndex:i]] userInfo:nil];
			}
			[defaultsDictionary addEntriesFromDictionary:[NSDictionary dictionaryWithContentsOfFile:defaultsPath]];
		}
	    
		initialValuesDictionary = [defaultsDictionary dictionaryWithValuesForKeys:[defaultsDictionary allKeys]];		
		[[NSUserDefaultsController sharedUserDefaultsController] setInitialValues:initialValuesDictionary];
	}
	@catch(NSException *exception) {
		displayExceptionAlert(exception);
	}
	@finally {
	}
}

+ (PreferencesController *) sharedPreferences
{
	@synchronized(self) {
		if(nil == sharedPreferences) {
			sharedPreferences = [[self alloc] init];
		}
	}
	return sharedPreferences;
}

+ (id) allocWithZone:(NSZone *)zone
{
    @synchronized(self) {
        if(nil == sharedPreferences) {
            return [super allocWithZone:zone];
        }
    }
    return sharedPreferences;
}

- (id) init
{
	if((self = [super initWithWindowNibName:@"Preferences"])) {
		return self;
	}
	return nil;
}

- (id) copyWithZone:(NSZone *)zone								{ return self; }
- (id) retain													{ return self; }
- (unsigned) retainCount										{ return UINT_MAX;  /* denotes an object that cannot be released */ }
- (void) release												{ /* do nothing */ }
- (id) autorelease												{ return self; }

- (void) awakeFromNib
{
	[self setShouldCascadeWindows:NO];

    NSToolbar *toolbar = [[[NSToolbar alloc] initWithIdentifier:@"Max Preferences Toolbar"] autorelease];
    
    [toolbar setAllowsUserCustomization: NO];
    [toolbar setAutosavesConfiguration: NO];
    [toolbar setDisplayMode: NSToolbarDisplayModeIconAndLabel];
    
    [toolbar setDelegate:self];
	[toolbar setSelectedItemIdentifier:GeneralPreferencesToolbarItemIdentifier];
	
    [[self window] setToolbar:toolbar];
	[[self window] center];
	[self selectPrefsPane:[[toolbar items] objectAtIndex:0]];
}

- (NSToolbarItem *) toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag 
{
    NSToolbarItem *toolbarItem = nil;
    
    if([itemIdentifier isEqualToString:GeneralPreferencesToolbarItemIdentifier]) {
        toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
		
		[toolbarItem setLabel: @"General"];
		[toolbarItem setPaletteLabel: @"General"];		
		[toolbarItem setToolTip: @"General preferences"];
		[toolbarItem setImage: [NSImage imageNamed:@"GeneralToolbarImage"]];
		
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(selectPrefsPane:)];
	}
    else if([itemIdentifier isEqualToString:FormatsPreferencesToolbarItemIdentifier]) {
        toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
		
		[toolbarItem setLabel: @"Formats"];
		[toolbarItem setPaletteLabel: @"Formats"];
		[toolbarItem setToolTip: @"Select desired output formats"];
		[toolbarItem setImage: [NSImage imageNamed:@"FormatsToolbarImage"]];
		
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(selectPrefsPane:)];
	}
    else if([itemIdentifier isEqualToString:OutputPreferencesToolbarItemIdentifier]) {
        toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
		
		[toolbarItem setLabel: @"Output"];
		[toolbarItem setPaletteLabel: @"Output"];
		[toolbarItem setToolTip: @"Output file naming and location preferences"];
		[toolbarItem setImage: [NSImage imageNamed:@"OutputToolbarImage"]];
		
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(selectPrefsPane:)];
	}
    else if([itemIdentifier isEqualToString:FreeDBPreferencesToolbarItemIdentifier]) {
        toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
		
		[toolbarItem setLabel: @"FreeDB"];
		[toolbarItem setPaletteLabel: @"FreeDB"];
		[toolbarItem setToolTip: @"FreeDB preferences"];
		[toolbarItem setImage: [NSImage imageNamed:@"FreeDBToolbarImage"]];
		
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(selectPrefsPane:)];
	}
    else if([itemIdentifier isEqualToString:RipperPreferencesToolbarItemIdentifier]) {
        toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
		
		[toolbarItem setLabel: @"Ripper"];
		[toolbarItem setPaletteLabel: @"Ripper"];
		[toolbarItem setToolTip: @"CD ripper preferences"];
		[toolbarItem setImage: [NSImage imageNamed:@"RipperToolbarImage"]];
		
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(selectPrefsPane:)];
	}
    else if([itemIdentifier isEqualToString:LAMEPreferencesToolbarItemIdentifier]) {
        toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
		
		[toolbarItem setLabel: @"MP3"];
		[toolbarItem setPaletteLabel: @"MP3"];
		[toolbarItem setToolTip: @"LAME mp3 encoder preferences"];
		[toolbarItem setImage: [NSImage imageNamed:@"LAMEToolbarImage"]];
		
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(selectPrefsPane:)];
	} 
    else if([itemIdentifier isEqualToString:OggVorbisPreferencesToolbarItemIdentifier]) {
        toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
		
		[toolbarItem setLabel: @"Ogg Vorbis"];
		[toolbarItem setPaletteLabel: @"Ogg Vorbis"];
		[toolbarItem setToolTip: @"Ogg Vorbis encoder preferences"];
		[toolbarItem setImage: [NSImage imageNamed:@"OggVorbisToolbarImage"]];
		
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(selectPrefsPane:)];
	} 
    else if([itemIdentifier isEqualToString:AACPreferencesToolbarItemIdentifier]) {
        toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
		
		[toolbarItem setLabel: @"AAC"];
		[toolbarItem setPaletteLabel: @"AAC"];
		[toolbarItem setToolTip: @"Advanced Audio Coding encoder preferences"];
		[toolbarItem setImage: [NSImage imageNamed:@"AACToolbarImage"]];
		
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(selectPrefsPane:)];
	} 
	else {
		toolbarItem = nil;
    }
	
    return toolbarItem;
}

- (NSArray *) toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar 
{
    return [NSArray arrayWithObjects: GeneralPreferencesToolbarItemIdentifier, FormatsPreferencesToolbarItemIdentifier, 
		OutputPreferencesToolbarItemIdentifier, FreeDBPreferencesToolbarItemIdentifier,
		RipperPreferencesToolbarItemIdentifier, LAMEPreferencesToolbarItemIdentifier, 
		OggVorbisPreferencesToolbarItemIdentifier, AACPreferencesToolbarItemIdentifier,
		nil];
}

- (NSArray *) toolbarAllowedItemIdentifiers: (NSToolbar *) toolbar 
{
    return [NSArray arrayWithObjects: GeneralPreferencesToolbarItemIdentifier, FormatsPreferencesToolbarItemIdentifier, 
		OutputPreferencesToolbarItemIdentifier, FreeDBPreferencesToolbarItemIdentifier,
		RipperPreferencesToolbarItemIdentifier, LAMEPreferencesToolbarItemIdentifier, 
		OggVorbisPreferencesToolbarItemIdentifier, AACPreferencesToolbarItemIdentifier,
		nil];
}

- (NSArray *) toolbarSelectableItemIdentifiers: (NSToolbar *)toolbar
{
    return [NSArray arrayWithObjects: GeneralPreferencesToolbarItemIdentifier, FormatsPreferencesToolbarItemIdentifier, 
		OutputPreferencesToolbarItemIdentifier, FreeDBPreferencesToolbarItemIdentifier,
		RipperPreferencesToolbarItemIdentifier, LAMEPreferencesToolbarItemIdentifier, 
		OggVorbisPreferencesToolbarItemIdentifier, AACPreferencesToolbarItemIdentifier,
		nil];
}

- (void) selectPrefsPane:(id)sender
{
	NSToolbar				*toolbar;
	NSString				*itemIdentifier;
	Class					prefPaneClass;
	NSWindowController		*prefPaneObject;
	NSView					*prefView;
	float					toolbarHeight, newWindowHeight, newWindowWidth;
	NSRect					windowFrame, newFrameRect, newWindowFrame;

	
	toolbar					= [[self window] toolbar];
	itemIdentifier			= [toolbar selectedItemIdentifier];
	prefPaneClass			= NSClassFromString([itemIdentifier stringByAppendingString:@"Controller"]);
	prefPaneObject			= [[prefPaneClass alloc] init];
	prefView				= [[prefPaneObject window] contentView];
		
	float windowHeight		= NSHeight([[[self window] contentView] frame]);
	
	// Calculate toolbar height
	if([toolbar isVisible]) {
		windowFrame = [NSWindow contentRectForFrameRect:[[self window] frame] styleMask:[[self window] styleMask]];
		toolbarHeight = NSHeight(windowFrame) - windowHeight;
	}
	
	newWindowHeight		= NSHeight([prefView frame]) + toolbarHeight;
	newWindowWidth		= NSWidth([prefView frame]);
	newFrameRect		= NSMakeRect(NSMinX(windowFrame), NSMaxY(windowFrame) - newWindowHeight, newWindowWidth, newWindowHeight);
	newWindowFrame		= [NSWindow frameRectForContentRect:newFrameRect styleMask:[[self window] styleMask]];
	
	[[self window] setContentView:[[[NSView alloc] init] autorelease]];
	[[self window] setFrame:newWindowFrame display:YES animate:[[self window] isVisible]];
	[[self window] setContentView:prefView];
}

@end
