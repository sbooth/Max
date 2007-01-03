//
//  NSWorkspaceAdditions.h
//  Growl
//
//  Created by Ingmar Stein on 16.05.05.
//  Copyright 2005 The Growl Project. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSWorkspace (GrowlAdditions)
- (NSImage *) iconForApplication:(NSString *) inName;
@end
