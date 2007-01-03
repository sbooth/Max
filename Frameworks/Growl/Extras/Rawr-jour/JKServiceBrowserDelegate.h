//
//  JKServiceBrowserDelegate.h
//  Rawr-endezvous
//
//  Created by Jeremy Knope on 9/25/04.
//  Copyright 2004 Jeremy Knope. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface JKServiceBrowserDelegate : NSObject {
	IBOutlet NSBrowser  *serviceBrowser;
	NSMutableArray      *services;
	NSMutableDictionary *serviceTypes;
}

+ (NSString *) stringForService:(NSNetService *)service;
- (void) awakeFromNib;

- (void) addService:(NSNotification *)note;
- (void) removeService:(NSNotification *)note;
@end
