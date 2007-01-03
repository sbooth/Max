//
//  NSWorkspaceAdditions.m
//  Growl
//
//  Created by Ingmar Stein on 16.05.05.
//  Copyright 2005 The Growl Project. All rights reserved.
//

#import "NSWorkspaceAdditions.h"

@implementation NSWorkspace (GrowlAdditions)

- (NSImage *) iconForApplication:(NSString *) inName {
	NSString *path = [self fullPathForApplication:inName];
	NSImage *appIcon = path ? [self iconForFile:path] : nil;

	if (appIcon) {
		[appIcon setSize:NSMakeSize(128.0f,128.0f)];
	}
	return appIcon;
}

@end
