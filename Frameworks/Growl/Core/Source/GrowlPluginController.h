//
//  GrowlPluginController.h
//  Growl
//
//  Created by Nelson Elhage on 8/25/04.
//  Copyright 2004-2005 The Growl Project. All rights reserved.
//
// This file is under the BSD License, refer to License.txt for details

#import <Cocoa/Cocoa.h>

@protocol GrowlDisplayPlugin;

@interface GrowlPluginController : NSObject {
	NSMutableDictionary		*allDisplayPlugins;
	NSMutableDictionary		*allDisplayPluginBundles;
}

+ (GrowlPluginController *) controller;

- (NSArray *) allDisplayPlugins;
- (id <GrowlDisplayPlugin>) displayPluginNamed:(NSString *)name;
- (NSBundle *) bundleForPluginNamed:(NSString *)name;
- (void) installPlugin:(NSString *)filename;

@end
