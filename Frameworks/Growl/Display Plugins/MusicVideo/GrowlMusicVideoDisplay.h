//
//  GrowlMusicVideoDisplay.h
//  Growl Display Plugins
//
//  Copyright 2004 Jorge Salvador Caffarena. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <GrowlDisplayProtocol.h>

@class NSPreferencePane;

@interface GrowlMusicVideoDisplay : NSObject <GrowlDisplayPlugin> {
	NSMutableArray		*notificationQueue;
	NSPreferencePane	*preferencePane;
	NSNumber			*clickHandlerEnabled;
}

- (void) displayNotificationWithInfo:(NSDictionary *) noteDict;

@end
