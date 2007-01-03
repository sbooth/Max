//
//  GrowlInstallationPrompt.h
//  Growl
//
//  Created by Evan Schoenberg on 1/8/05.
//  Copyright 2005 The Growl Project. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface GrowlInstallationPrompt : NSWindowController {
	IBOutlet	NSTextView		*textView_growlInfo;
	IBOutlet	NSScrollView	*scrollView_growlInfo;

	IBOutlet	NSButton			*button_install;
	IBOutlet	NSButton			*button_cancel;
	IBOutlet	NSButton			*checkBox_dontAskAgain;
	IBOutlet	NSProgressIndicator	*spinner;

	NSString	*updateVersion;
}

/*!
 *	@method showInstallationPrompt
 *	@abstract Shows the installation prompt for Growl-WithInstaller
 */
+ (void) showInstallationPrompt;

/*!
 *	@method showUpdatePromptForVersion:
 *	@abstract Show the update prompt for Growl-WithInstaller
 *
 *	@param updateVersion The version for which an update is available (that is, the version the user will have after updating)
 */
+ (void) showUpdatePromptForVersion:(NSString *)updateVersion;

- (IBAction) installGrowl:(id)sender;
- (IBAction) cancel:(id)sender;
- (IBAction) dontAskAgain:(id)sender;

@end
