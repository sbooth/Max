//
//  GrowlPluginController.m
//  Growl
//
//  Created by Nelson Elhage on 8/25/04.
//  Copyright 2004-2005 The Growl Project. All rights reserved.
//
// This file is under the BSD License, refer to License.txt for details

#import "GrowlPluginController.h"
#import "GrowlPreferences.h"
#import "GrowlDisplayProtocol.h"
#import "GrowlPathUtil.h"
#import "GrowlWebKitController.h"

#define GROWL_PREFPANE_BUNDLE_IDENTIFIER		@"com.growl.prefpanel"
#define PREFERENCE_PANES_SUBFOLDER_OF_LIBRARY	@"PreferencePanes"
#define PREFERENCE_PANE_EXTENSION				@"prefPane"
#define GROWL_VIEW_EXTENSION					@"growlView"
#define GROWL_STYLE_EXTENSION					@"growlStyle"
#define GROWL_PREFPANE_NAME						@"Growl.prefPane"

static GrowlPluginController *sharedController;

@interface GrowlPluginController (PRIVATE)
- (void) loadPlugin:(NSString *)path;
- (void) findPluginsInDirectory:(NSString *)dir;
- (void) pluginInstalledSelector:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (void) pluginExistsSelector:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
@end

@interface WebCoreCache
+ (void) empty;
@end

#pragma mark -

@implementation GrowlPluginController

+ (GrowlPluginController *) controller {
	if (!sharedController) {
		sharedController = [[GrowlPluginController alloc] init];
	}

	return sharedController;
}

- (id) init {
	NSArray *libraries;
	NSEnumerator *enumerator;
	NSString *dir;

	if ((self = [super init])) {
		allDisplayPlugins = [[NSMutableDictionary alloc] init];
		allDisplayPluginBundles = [[NSMutableDictionary alloc] init];

		libraries = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSAllDomainsMask, YES);

		enumerator = [libraries objectEnumerator];
		while ((dir = [enumerator nextObject])) {
			dir = [dir stringByAppendingPathComponent:@"Application Support/Growl/Plugins"];
			[self findPluginsInDirectory:dir];
		}

		NSBundle *helperAppBundle = [GrowlPathUtil helperAppBundle];
		[self findPluginsInDirectory:[helperAppBundle builtInPlugInsPath]];
	}

	return self;
}

#pragma mark -

- (NSArray *) allDisplayPlugins {
	return [[allDisplayPluginBundles allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
}

- (id <GrowlDisplayPlugin>) displayPluginNamed:(NSString *)name {
	id <GrowlDisplayPlugin> plugin = [allDisplayPlugins objectForKey:name];
	if (!plugin) {
		NSBundle *pluginBundle = [allDisplayPluginBundles objectForKey:name];
		NSString *filename = [[pluginBundle bundlePath] lastPathComponent];
		NSString *pathExtension = [filename pathExtension];
		if ([pathExtension isEqualToString:GROWL_VIEW_EXTENSION]) {
			if (pluginBundle && (plugin = [[[pluginBundle principalClass] alloc] init])) {
				[allDisplayPlugins setObject:plugin forKey:name];
				[plugin release];
			} else {
				NSLog(@"Could not load %@", name);
			}
		} else if ([pathExtension isEqualToString:GROWL_STYLE_EXTENSION]) {
			// empty the WebCoreCache to reload stylesheets
			Class webCoreCache = NSClassFromString(@"WebCoreCache");
			[webCoreCache empty];

			// load GrowlWebKitController dynamically so that GrowlMenu does not
			// have to link against it and all of its dependencies
			Class webKitController = NSClassFromString(@"GrowlWebKitController");
			plugin = [[webKitController alloc] initWithStyle:name];
			[allDisplayPlugins setObject:plugin forKey:name];
			[plugin release];
		} else {
			NSLog(@"Unknown plugin filename extension '%@' (from filename '%@' of plugin named '%@')", pathExtension, filename, name);
		}
	}

	return plugin;
}

- (NSBundle *) bundleForPluginNamed:(NSString *)name {
	return [allDisplayPluginBundles objectForKey:name];
}

- (void) dealloc {
	[allDisplayPlugins       release];
	[allDisplayPluginBundles release];

	[super dealloc];
}

- (void) findPluginsInDirectory:(NSString *)dir {
	NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtPath:dir];
	NSString *file;
	while ((file = [enumerator nextObject])) {
		NSString *pathExtension = [file pathExtension];
		if ([pathExtension isEqualToString:GROWL_VIEW_EXTENSION] || [pathExtension isEqualToString:GROWL_STYLE_EXTENSION]) {
			[self loadPlugin:[dir stringByAppendingPathComponent:file]];
			[enumerator skipDescendents];
		}
	}
}

- (void) loadPlugin:(NSString *)path {
	NSBundle *pluginBundle = [[NSBundle alloc] initWithPath:path];

	if (pluginBundle) {
		// TODO: We should use CFBundleIdentifier as the key and display CFBundleName to the user
		NSString *pluginName = [[pluginBundle infoDictionary] objectForKey:(NSString *)kCFBundleNameKey];
		if (pluginName) {
			[allDisplayPluginBundles setObject:pluginBundle forKey:pluginName];
			[allDisplayPlugins removeObjectForKey:pluginName];
		} else {
			NSLog(@"Plugin at path '%@' has no name", path);
		}
		[pluginBundle release];
	} else {
		NSLog(@"Failed to load: %@", path);
	}
}

- (void) pluginInstalledSelector:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
#pragma unused(sheet, contextInfo)
	if (returnCode == NSAlertAlternateReturn) {
		NSBundle *prefPane = [GrowlPathUtil growlPrefPaneBundle];

		if (prefPane && ![[NSWorkspace sharedWorkspace] openFile: [prefPane bundlePath]]) {
			NSLog(@"Could not open Growl PrefPane");
		}
	}
}

- (void) pluginExistsSelector:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
#pragma unused(sheet)
	NSString *filename = (NSString *)contextInfo;

	if (returnCode == NSAlertAlternateReturn) {
		NSString *pluginFile = [filename lastPathComponent];
		NSString *destination = [[NSHomeDirectory()
			stringByAppendingPathComponent:@"Library/Application Support/Growl/Plugins"]
			stringByAppendingPathComponent:pluginFile];
		NSFileManager *fileManager = [NSFileManager defaultManager];

		// first remove old copy if present
		[fileManager removeFileAtPath:destination handler:nil];

		// copy new version to destination
		if ([fileManager copyPath:filename toPath:destination handler:nil]) {
			[self loadPlugin:destination];
			NSBeginInformationalAlertSheet( NSLocalizedString( @"Plugin installed", @"" ),
											NSLocalizedString( @"No", @"" ),
											NSLocalizedString( @"Yes", @"" ),
											nil, nil, self,
											@selector(pluginInstalledSelector:returnCode:contextInfo:),
											NULL, NULL,
											NSLocalizedString( @"Plugin '%@' has been installed successfully. Do you want to configure it now?", @"" ),
											[pluginFile stringByDeletingPathExtension] );
		} else {
			NSBeginCriticalAlertSheet( NSLocalizedString( @"Plugin not installed", @"" ),
									   NSLocalizedString( @"OK", @"" ),
									   nil, nil, nil, self, NULL, NULL, NULL,
									   NSLocalizedString( @"There was an error while installing the plugin '%@'.", @"" ),
									   [pluginFile stringByDeletingPathExtension] );
		}
	}

	[filename release];
}

- (void) installPlugin:(NSString *)filename {
	NSString *pluginFile = [filename lastPathComponent];
	NSString *destination = [[NSHomeDirectory()
		stringByAppendingPathComponent:@"Library/Application Support/Growl/Plugins"]
		stringByAppendingPathComponent:pluginFile];
	// retain a copy of the filename because it is passed as context to the sheetDidEnd selectors
	NSString *filenameCopy = [[NSString alloc] initWithString:filename];

	if ([[NSFileManager defaultManager] fileExistsAtPath:destination]) {
		// plugin already exists at destination
		NSBeginAlertSheet( NSLocalizedString( @"Plugin already exists", @"" ),
						   NSLocalizedString( @"No", @"" ),
						   NSLocalizedString( @"Yes", @"" ), nil, nil, self,
						   NULL, @selector(pluginExistsSelector:returnCode:contextInfo:),
						   filenameCopy,
						   NSLocalizedString( @"Plugin '%@' is already installed, do you want to overwrite it?", @"" ),
						   [pluginFile stringByDeletingPathExtension] );
	} else {
		[self pluginExistsSelector:nil returnCode:NSAlertAlternateReturn contextInfo:filenameCopy];
	}
}

@end
