//
//  GrowlSpeechDisplay.h
//  Display Plugins
//
//  Created by Ingmar Stein on 15.11.04.
//  Copyright 2004-2005 The Growl Project. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <GrowlDisplayProtocol.h>

@class NSPreferencePane;

@interface GrowlSpeechDisplay : NSObject <GrowlDisplayPlugin>
{
	NSPreferencePane	*prefPane;
}

@end
