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
static NSString		*FLACPreferencesToolbarItemIdentifier			= @"FLACPreferences";
static NSString		*OggVorbisPreferencesToolbarItemIdentifier		= @"OggVorbisPreferences";
static NSString		*SpeexPreferencesToolbarItemIdentifier			= @"SpeexPreferences";

@interface PreferencesController (Private)
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
		defaultFiles		= [NSArray arrayWithObjects:@"ApplicationControllerDefaults", @"MediaControllerDefaults", @"FreeDBDefaults",
			@"CompactDiscDocumentDefaults", @"ParanoiaDefaults", @"LAMEDefaults", @"TrackDefaults", @"TaskMasterDefaults", @"OggVorbisDefaults", 
			@"FLACDefaults", @"SpeexDefaults", @"PCMGeneratingTaskDefaults", nil];
		// Add the default values as resettable
		for(i = 0; i < [defaultFiles count]; ++i) {
			defaultsPath = [[NSBundle mainBundle] pathForResource:[defaultFiles objectAtIndex:i] ofType:@"plist"];
			if(nil == defaultsPath) {
				@throw [MissingResourceException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to load required resource", @"Exceptions", @"")
															userInfo:[NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"%@.plist", [defaultFiles objectAtIndex:i]] forKey:@"filename"]];
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
		
		[toolbarItem setLabel: NSLocalizedStringFromTable(@"General", @"Preferences", @"")];
		[toolbarItem setPaletteLabel: NSLocalizedStringFromTable(@"General", @"Preferences", @"")];		
		[toolbarItem setToolTip: NSLocalizedStringFromTable(@"Control the general behavior of Max", @"Preferences", @"")];
		[toolbarItem setImage: [NSImage imageNamed:@"GeneralToolbarImage"]];
		
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(selectPrefsPane:)];
	}
    else if([itemIdentifier isEqualToString:FormatsPreferencesToolbarItemIdentifier]) {
        toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
		
		[toolbarItem setLabel: NSLocalizedStringFromTable(@"Formats", @"Preferences", @"")];
		[toolbarItem setPaletteLabel: NSLocalizedStringFromTable(@"Formats", @"Preferences", @"")];
		[toolbarItem setToolTip: NSLocalizedStringFromTable(@"Select the encoders that Max will use to produce audio", @"Preferences", @"")];
		[toolbarItem setImage: [NSImage imageNamed:@"FormatsToolbarImage"]];
		
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(selectPrefsPane:)];
	}
    else if([itemIdentifier isEqualToString:OutputPreferencesToolbarItemIdentifier]) {
        toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
		
		[toolbarItem setLabel: NSLocalizedStringFromTable(@"Output", @"Preferences", @"")];
		[toolbarItem setPaletteLabel: NSLocalizedStringFromTable(@"Output", @"Preferences", @"")];
		[toolbarItem setToolTip: NSLocalizedStringFromTable(@"Select where output files will be saved and how they will be named", @"Preferences", @"")];
		[toolbarItem setImage: [NSImage imageNamed:@"OutputToolbarImage"]];
		
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(selectPrefsPane:)];
	}
    else if([itemIdentifier isEqualToString:FreeDBPreferencesToolbarItemIdentifier]) {
        toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
		
		[toolbarItem setLabel: NSLocalizedStringFromTable(@"FreeDB", @"Preferences", @"")];
		[toolbarItem setPaletteLabel: NSLocalizedStringFromTable(@"FreeDB", @"Preferences", @"")];
		[toolbarItem setToolTip: NSLocalizedStringFromTable(@"Control the protocol and server used by FreeDB to retrieve CD information", @"Preferences", @"")];
		[toolbarItem setImage: [NSImage imageNamed:@"FreeDBToolbarImage"]];
		
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(selectPrefsPane:)];
	}
    else if([itemIdentifier isEqualToString:RipperPreferencesToolbarItemIdentifier]) {
        toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
		
		[toolbarItem setLabel: NSLocalizedStringFromTable(@"Ripper", @"Preferences", @"")];
		[toolbarItem setPaletteLabel: NSLocalizedStringFromTable(@"Ripper", @"Preferences", @"")];
		[toolbarItem setToolTip: NSLocalizedStringFromTable(@"Adjust the parameters used for CD audio extraction", @"Preferences", @"")];
		[toolbarItem setImage: [NSImage imageNamed:@"RipperToolbarImage"]];
		
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(selectPrefsPane:)];
	}
    else if([itemIdentifier isEqualToString:LAMEPreferencesToolbarItemIdentifier]) {
        toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
		
		[toolbarItem setLabel: NSLocalizedStringFromTable(@"MP3", @"Preferences", @"")];
		[toolbarItem setPaletteLabel: NSLocalizedStringFromTable(@"MP3", @"Preferences", @"")];
		[toolbarItem setToolTip: NSLocalizedStringFromTable(@"Adjust the parameters used by the MP3 encoder", @"Preferences", @"")];
		[toolbarItem setImage: [NSImage imageNamed:@"LAMEToolbarImage"]];
		
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(selectPrefsPane:)];
	} 
    else if([itemIdentifier isEqualToString:FLACPreferencesToolbarItemIdentifier]) {
        toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
		
		[toolbarItem setLabel: NSLocalizedStringFromTable(@"FLAC", @"Preferences", @"")];
		[toolbarItem setPaletteLabel: NSLocalizedStringFromTable(@"FLAC", @"Preferences", @"")];
		[toolbarItem setToolTip: NSLocalizedStringFromTable(@"Adjust the parameters used by the FLAC and Ogg FLAC encoders", @"Preferences", @"")];
		[toolbarItem setImage: [NSImage imageNamed:@"FLAC"]];
		
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(selectPrefsPane:)];
	} 
    else if([itemIdentifier isEqualToString:OggVorbisPreferencesToolbarItemIdentifier]) {
        toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
		
		[toolbarItem setLabel: NSLocalizedStringFromTable(@"Ogg Vorbis", @"Preferences", @"")];
		[toolbarItem setPaletteLabel: NSLocalizedStringFromTable(@"Ogg Vorbis", @"Preferences", @"")];
		[toolbarItem setToolTip: NSLocalizedStringFromTable(@"Adjust the parameters used by the Ogg Vorbis encoder", @"Preferences", @"")];
		[toolbarItem setImage: [NSImage imageNamed:@"OggVorbisToolbarImage"]];
		
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(selectPrefsPane:)];
	} 
    else if([itemIdentifier isEqualToString:SpeexPreferencesToolbarItemIdentifier]) {
        toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
		
		[toolbarItem setLabel: NSLocalizedStringFromTable(@"Speex", @"Preferences", @"")];
		[toolbarItem setPaletteLabel: NSLocalizedStringFromTable(@"Speex", @"Preferences", @"")];
		[toolbarItem setToolTip: NSLocalizedStringFromTable(@"Adjust the parameters used by the Speex encoder", @"Preferences", @"")];
		[toolbarItem setImage: [NSImage imageNamed:@"SpeexToolbarImage"]];
		
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
		FLACPreferencesToolbarItemIdentifier, OggVorbisPreferencesToolbarItemIdentifier,
		SpeexPreferencesToolbarItemIdentifier,
		nil];
}

- (NSArray *) toolbarAllowedItemIdentifiers: (NSToolbar *) toolbar 
{
    return [NSArray arrayWithObjects: GeneralPreferencesToolbarItemIdentifier, FormatsPreferencesToolbarItemIdentifier, 
		OutputPreferencesToolbarItemIdentifier, FreeDBPreferencesToolbarItemIdentifier,
		RipperPreferencesToolbarItemIdentifier, LAMEPreferencesToolbarItemIdentifier, 
		FLACPreferencesToolbarItemIdentifier, OggVorbisPreferencesToolbarItemIdentifier,
		SpeexPreferencesToolbarItemIdentifier,
		NSToolbarSeparatorItemIdentifier,  NSToolbarSpaceItemIdentifier, NSToolbarFlexibleSpaceItemIdentifier,
		NSToolbarCustomizeToolbarItemIdentifier,
		nil];
}

- (NSArray *) toolbarSelectableItemIdentifiers: (NSToolbar *)toolbar
{
    return [NSArray arrayWithObjects: GeneralPreferencesToolbarItemIdentifier, FormatsPreferencesToolbarItemIdentifier, 
		OutputPreferencesToolbarItemIdentifier, FreeDBPreferencesToolbarItemIdentifier,
		RipperPreferencesToolbarItemIdentifier, LAMEPreferencesToolbarItemIdentifier, 
		FLACPreferencesToolbarItemIdentifier, OggVorbisPreferencesToolbarItemIdentifier,
		SpeexPreferencesToolbarItemIdentifier,
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
	NSWindow				*myWindow;

	myWindow				= [self window];
	toolbar					= [myWindow toolbar];
	itemIdentifier			= [toolbar selectedItemIdentifier];
	prefPaneClass			= NSClassFromString([itemIdentifier stringByAppendingString:@"Controller"]);
	prefPaneObject			= [[prefPaneClass alloc] init];
	prefView				= [[prefPaneObject window] contentView];
		
	float windowHeight		= NSHeight([[myWindow contentView] frame]);
	
	// Calculate toolbar height
	if([toolbar isVisible]) {
		windowFrame = [NSWindow contentRectForFrameRect:[myWindow frame] styleMask:[myWindow styleMask]];
		toolbarHeight = NSHeight(windowFrame) - windowHeight;
	}
	
	newWindowHeight		= NSHeight([prefView frame]) + toolbarHeight;
	newWindowWidth		= NSWidth([[myWindow contentView] frame]); // Don't adjust width, only height
	newFrameRect		= NSMakeRect(NSMinX(windowFrame), NSMaxY(windowFrame) - newWindowHeight, newWindowWidth, newWindowHeight);
	newWindowFrame		= [NSWindow frameRectForContentRect:newFrameRect styleMask:[myWindow styleMask]];
	
	[myWindow setContentView:[[[NSView alloc] init] autorelease]];
	[myWindow setTitle:[[self toolbar:toolbar itemForItemIdentifier:itemIdentifier willBeInsertedIntoToolbar:NO] label]];
	[myWindow setFrame:newWindowFrame display:YES animate:[myWindow isVisible]];
	[myWindow setContentView:prefView];
}

@end
