//
//  GrowlSpeechPrefs.h
//  Display Plugins
//
//  Created by Ingmar Stein on 15.11.04.
//  Copyright 2004-2005 The Growl Project. All rights reserved.
//

#import <PreferencePanes/PreferencePanes.h>

@interface GrowlSpeechPrefs : NSPreferencePane {
	IBOutlet NSTableView	*voiceList;
	NSArray					*voices;
}
- (IBAction) voiceClicked:(id)sender;
- (NSArray *) voices;
- (void) setVoices:(NSArray *)theVoices;

@end
