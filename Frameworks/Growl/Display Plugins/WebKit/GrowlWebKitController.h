//
//  GrowlWebKitController.h
//  Growl
//
//  Created by Ingmar Stein on Thu Apr 14 2005.
//  Copyright 2005 The Growl Project. All rights reserved.
//

@class NSPreferencePane;

@interface GrowlWebKitController : NSObject <GrowlDisplayPlugin> {
	NSPreferencePane	*preferencePane;
	NSString			*style;
	NSNumber			*clickHandlerEnabled;
}

- (id) initWithStyle:(NSString *)styleName;
- (void) displayNotificationWithInfo:(NSDictionary *) noteDict;

@end
