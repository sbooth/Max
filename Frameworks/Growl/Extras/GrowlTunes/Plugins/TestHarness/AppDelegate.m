//
//  AppDelegate.m
//  TestHarness
//
//  Created by Kevin Ballard on 9/29/04.
//  Copyright 2004 TildeSoft. All rights reserved.
//

#import "AppDelegate.h"

@interface AppDelegate (AppDelegatePrivate)
- (void) loadPluginsAtPath:(NSString *)dir;
@end

@implementation AppDelegate
- (id) init {
	if (self = [super init]) {
		// Initialize variables
		plugins = [[NSArray alloc] init];
		song = @"";
		album = @"";
		artist = @"";
		compilation = [[NSNumber alloc] initWithBool:NO];

		// find all the GrowlTunes plugins
		NSString *growlTunesPath = [[NSWorkspace sharedWorkspace] fullPathForApplication:@"GrowlTunes"];
		if (growlTunesPath) {
			NSBundle *growlTunesBundle = [NSBundle bundleWithPath:growlTunesPath];
			NSString *pluginsPath = [growlTunesBundle builtInPlugInsPath];
			[self loadPluginsAtPath:pluginsPath];
		}
		NSString *appSupportPath = [@"~/Library/Application Support/GrowlTunes/Plugins" stringByExpandingTildeInPath];
		[self loadPluginsAtPath:appSupportPath];
	}
	return self;
}

- (void) loadPluginsAtPath:(NSString *)dir {
	BOOL isDir;
	if ([[NSFileManager defaultManager] fileExistsAtPath:dir isDirectory:&isDir] && isDir) {
		NSLog(@"Using plugins from: %@", dir);
		NSMutableArray *array = [[self plugins] mutableCopy];
		NSArray *pluginsArray = [[NSFileManager defaultManager] directoryContentsAtPath:dir];
		NSEnumerator *e = [pluginsArray objectEnumerator];
		NSString *path;
		while (path = [e nextObject]) {
			if ([path hasSuffix:@".plugin"]) {
				NSBundle *bundle = [NSBundle bundleWithPath:
					[dir stringByAppendingPathComponent:path]];
				if ([[bundle principalClass] conformsToProtocol:@protocol(GrowlTunesPlugin)]) {
					NSMutableDictionary *dict = [NSMutableDictionary dictionary];
					[dict setValue:bundle forKey:@"bundle"];
					[array addObject:dict];
				} else {
					NSLog(@"Plugin `%@' does not conform to protocol", path);
				}
			}
		}
		[self setPlugins:array];
	}
}

- (void) dealloc {
	[pluginsController removeObserver:self forKeyPath:@"selection"];

	[plugins release];

	[super dealloc];
}

- (void) awakeFromNib {
	// Set up drag&drop for the window here
	[mainWindow registerForDraggedTypes:[NSArray arrayWithObject:NSFilenamesPboardType]];
	NSSortDescriptor *sortDesc = [NSSortDescriptor alloc];
	[sortDesc initWithKey:@"bundle.localizedInfoDictionary.CFBundleName" ascending:YES];
	[pluginsController setSortDescriptors:[NSArray arrayWithObject:sortDesc]];
	[pluginsController addObserver:self forKeyPath:@"selection" options:0 context:nil];
	[pluginsController rearrangeObjects];
}

- (NSArray *) plugins {
	return [[plugins retain] autorelease];
}

- (void) setPlugins:(NSArray *)array {
	[plugins autorelease];
	plugins = [array copy];
}

- (NSImage *) currentImage {
	return [[currentImage retain] autorelease];
}

- (void) setCurrentImage:(NSImage *)image {
	[currentImage autorelease];
	currentImage = [image retain];
}

// - artist:
- (NSString *)artist
{
    return [[artist retain] autorelease];
}

// - setArtist:
- (void)setArtist:(NSString *)anArtist
{
    [anArtist retain];
    [artist release];
    artist = anArtist;

	[self testPlugin];
}

// - album:
- (NSString *)album
{
    return [[album retain] autorelease];
}

// - setAlbum:
- (void)setAlbum:(NSString *)anAlbum
{
    [anAlbum retain];
    [album release];
    album = anAlbum;

	[self testPlugin];
}

// - song:
- (NSString *)song
{
    return [[song retain] autorelease];
}

// - setSong:
- (void)setSong:(NSString *)aSong
{
    [aSong retain];
    [song release];
    song = aSong;

	[self testPlugin];
}

// - compilation
- (NSNumber *)compilation {
	return [[compilation retain] autorelease];
}

// - setCompilation:
- (void)setCompilation:(NSNumber *)isCompilation {
	[isCompilation retain];
	[compilation release];
	compilation = isCompilation;

	[self testPlugin];
}

- (void) testPlugin {
	if ([pluginsController selectionIndex] != NSNotFound) {
		id selection = [pluginsController selection];
		id obj = [selection valueForKey:@"instance"];
		if (!obj) {
			Class principalClass = [[selection valueForKey:@"bundle"] principalClass];
			if ([principalClass conformsToProtocol:@protocol(GrowlTunesPlugin)]) {
				obj = [principalClass new];
				[selection setValue:obj forKey:@"instance"];
			} else {
				NSLog(@"Plugin `%@' does not conform to protocol", [[selection valueForKey:@"bundle"] bundleIdentifier]);
			}
		}
		if (obj) {
			[self setCurrentImage:[obj artworkForTitle:song byArtist:artist onAlbum:album isCompilation:[compilation boolValue]]];
		} else {
			NSBeep();
		}
	}
}

- (void) addPlugin:(NSString *)path {
	NSBundle *bundle = [NSBundle bundleWithPath:path];
	// Make sure it doesn't already exist
	NSArray *dicts = [pluginsController valueForKey:@"arrangedObjects"];
	NSEnumerator *e = [dicts objectEnumerator];
	id obj;
	while (obj = [e nextObject]) {
		if ([[obj valueForKey:@"bundle"] isEqual:bundle]) {
			[pluginsController setSelectedObjects:[NSArray arrayWithObject:obj]];
			return;
		}
	}
	if (bundle && [[bundle principalClass]
							instancesRespondToSelector:@selector(artworkForTitle:byArtist:onAlbum:)]) {
		NSMutableDictionary *dict = [NSMutableDictionary dictionary];
		[dict setValue:bundle forKey:@"bundle"];
		[pluginsController addObject:dict];
		[pluginsController rearrangeObjects];
	} else {
		NSBeep();
	}
}

- (IBAction) open:(id)sender {
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];

	if ([openPanel runModalForTypes:[NSArray arrayWithObject:@"plugin"]] == NSOKButton) {
		[self addPlugin:[openPanel filename]];
	}
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
	if ([object isEqual:pluginsController] && [keyPath isEqualToString:@"selection"] &&
		[object valueForKeyPath:keyPath] != NSNoSelectionMarker) {
		[self testPlugin];
	}
}

#pragma mark -
#pragma mark Window delegate methods
// Window delegate methods
- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender {
    NSPasteboard *pboard = [sender draggingPasteboard];
    if ( [[pboard types] containsObject:NSFilenamesPboardType] ) {
        return NSDragOperationCopy;
    }
    return NSDragOperationNone;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender {
    NSPasteboard *pboard = [sender draggingPasteboard];
    if ( [[pboard types] containsObject:NSFilenamesPboardType] ) {
		NSArray *paths = [pboard propertyListForType:NSFilenamesPboardType];
		NSEnumerator *e = [paths objectEnumerator];
		NSString *path;
		while (path = [e nextObject]) {
			[self addPlugin:path];
		}
		return YES;
    }
    return NO;
}

@end
