//
//  GrowlMailMeDisplay.h
//  Growl Display Plugins
//
//  Copyright 2004 Mac-arena the Bored Zo. All rights reserved.
//

#import <Foundation/Foundation.h>

@class NSPreferencePane;

@interface GrowlMailMeDisplay: NSObject <GrowlDisplayPlugin>
{
	NSPreferencePane	*prefPane;
}

- (void) displayNotificationWithInfo:(NSDictionary *) noteDict;

@end
