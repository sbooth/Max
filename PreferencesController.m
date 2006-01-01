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
static NSString		*FLACPreferencesToolbarItemIdentifier			= @"FLACPreferences";

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
	NSArray					*defaultFiles;
	unsigned				i;

	@try {
		defaultsDictionary	= [NSMutableDictionary dictionaryWithCapacity:20];
		defaultFiles		= [NSArray arrayWithObjects:@"ApplicationControllerDefaults", @"MediaControllerDefaults", @"FreeDBDefaults", @"CompactDiscDocumentDefaults", @"ParanoiaDefaults", @"LAMEDefaults", @"TrackDefaults", @"TaskMasterDefaults", @"OggVorbisDefaults", @"FLACDefaults", nil];
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
    NSToolbar *toolbar = [[[NSToolbar alloc] initWithIdentifier:@"Max Preferences Toolbar"] autorelease];
    
    [toolbar setAllowsUserCustomization:YES];
    [toolbar setAutosavesConfiguration:YES];
    
    [toolbar setDelegate:self];
	
    [[self window] setToolbar:toolbar];
}

- (void) windowDidLoad
{
	NSToolbar *toolbar = [[self window] toolbar];

	[toolbar setSelectedItemIdentifier:[[[toolbar visibleItems] objectAtIndex:0] itemIdentifier]];
	[self selectPrefsPane:self];

	[self setShouldCascadeWindows:NO];
	[[self window] center];
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
		[toolbarItem setToolTip: @"Output file format preferences"];
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
    else if([itemIdentifier isEqualToString:FLACPreferencesToolbarItemIdentifier]) {
        toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
		
		[toolbarItem setLabel: @"FLAC"];
		[toolbarItem setPaletteLabel: @"FLAC"];
		[toolbarItem setToolTip: @"FLAC and Ogg FLAC encoder preferences"];
		[toolbarItem setImage: [NSImage imageNamed:@"FLAC"]];
		
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
		OggVorbisPreferencesToolbarItemIdentifier, FLACPreferencesToolbarItemIdentifier,
		NSToolbarFlexibleSpaceItemIdentifier, NSToolbarCustomizeToolbarItemIdentifier,
		nil];
}

- (NSArray *) toolbarAllowedItemIdentifiers: (NSToolbar *) toolbar 
{
    return [NSArray arrayWithObjects: GeneralPreferencesToolbarItemIdentifier, FormatsPreferencesToolbarItemIdentifier, 
		OutputPreferencesToolbarItemIdentifier, FreeDBPreferencesToolbarItemIdentifier,
		RipperPreferencesToolbarItemIdentifier, LAMEPreferencesToolbarItemIdentifier, 
		OggVorbisPreferencesToolbarItemIdentifier, FLACPreferencesToolbarItemIdentifier,
		NSToolbarFlexibleSpaceItemIdentifier, NSToolbarSpaceItemIdentifier, NSToolbarSeparatorItemIdentifier, NSToolbarCustomizeToolbarItemIdentifier,
		nil];
}

- (NSArray *) toolbarSelectableItemIdentifiers: (NSToolbar *)toolbar
{
    return [NSArray arrayWithObjects: GeneralPreferencesToolbarItemIdentifier, FormatsPreferencesToolbarItemIdentifier, 
		OutputPreferencesToolbarItemIdentifier, FreeDBPreferencesToolbarItemIdentifier,
		RipperPreferencesToolbarItemIdentifier, LAMEPreferencesToolbarItemIdentifier, 
		OggVorbisPreferencesToolbarItemIdentifier, FLACPreferencesToolbarItemIdentifier,
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
	[[self window] setTitle:[[self toolbar:toolbar itemForItemIdentifier:itemIdentifier willBeInsertedIntoToolbar:NO] label]];
	[[self window] setFrame:newWindowFrame display:YES animate:[[self window] isVisible]];
	[[self window] setContentView:prefView];
}

@end
