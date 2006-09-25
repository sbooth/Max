//
//  GrowlInstallationPrompt.m
//  Growl
//
//  Created by Evan Schoenberg on 1/8/05.
//  Copyright 2005 The Growl Project. All rights reserved.
//

#import "GrowlInstallationPrompt.h"
#import "GrowlApplicationBridge.h"
#import "GrowlDefines.h"

#define GROWL_INSTALLATION_NIB @"GrowlInstallationPrompt"
#define GROWL_INSTALLATION_STRINGS @"GrowlInstallation.strings"

#define DEFAULT_INSTALLATION_WINDOW_TITLE NSLocalizedStringFromTable(@"Growl Installation Recommended", GROWL_INSTALLATION_STRINGS, @"Growl installation window title")
#define DEFAULT_UPDATE_WINDOW_TITLE NSLocalizedStringFromTable(@"Growl Update Available", GROWL_INSTALLATION_STRINGS, @"Growl update window title")

#define DEFAULT_INSTALLATION_EXPLANATION NSLocalizedStringFromTable(@"This program displays information via Growl, a centralized notification system.  Growl is not currently installed; to see Growl notifications from this and other applications, you must install it.  No download is required.", GROWL_INSTALLATION_STRINGS, @"Default Growl installation explanation")
#define DEFAULT_UPDATE_EXPLANATION NSLocalizedStringFromTable(@"This program displays information via Growl, a centralized notification system.  A version of Growl is currently installed, but this program includes an updated version of Growl.  It is strongly recommended that you update now.  No download is required.", GROWL_INSTALLATION_STRINGS, @"Default Growl update explanation")

#define INSTALL_BUTTON_TITLE NSLocalizedStringFromTable(@"Install", GROWL_INSTALLATION_STRINGS, @"Button title for installing Growl")
#define UPDATE_BUTTON_TITLE NSLocalizedStringFromTable(@"Update", GROWL_INSTALLATION_STRINGS, @"Button title for updating Growl")
#define CANCEL_BUTTON_TITLE NSLocalizedStringFromTable(@"Cancel", GROWL_INSTALLATION_STRINGS, @"Button title for canceling installation of Growl")
#define DONT_ASK_AGAIN_CHECKBOX_TITLE NSLocalizedStringFromTable(@"Don't Ask Again", GROWL_INSTALLATION_STRINGS, @"Don't ask again checkbox title for installation of Growl")

#define GROWL_TEXT_SIZE 11

#ifndef NSAppKitVersionNumber10_3
# define NSAppKitVersionNumber10_3 743
#endif

@interface GrowlInstallationPrompt (private)
- (id)initWithWindowNibName:(NSString *)nibName forUpdateToVersion:(NSString *)updateVersion;
- (void) performInstallGrowl;
- (void) releaseAndClose;
@end

static BOOL checkOSXVersion(void) {
	return (floor(NSAppKitVersionNumber) >= NSAppKitVersionNumber10_3);
}

@implementation GrowlInstallationPrompt

+ (void) showInstallationPrompt {
	if (checkOSXVersion()) {
		[[[[GrowlInstallationPrompt alloc] initWithWindowNibName:GROWL_INSTALLATION_NIB forUpdateToVersion:nil] window] makeKeyAndOrderFront:nil];
	}
}

+ (void) showUpdatePromptForVersion:(NSString *)inUpdateVersion {
	if (checkOSXVersion()) {
		[[[[GrowlInstallationPrompt alloc] initWithWindowNibName:GROWL_INSTALLATION_NIB forUpdateToVersion:inUpdateVersion] window] makeKeyAndOrderFront:nil];
	}
}

- (id) initWithWindowNibName:(NSString *)nibName forUpdateToVersion:(NSString *)inUpdateVersion {
	if ((self = [super initWithWindowNibName:nibName])) {
		updateVersion = [inUpdateVersion retain];
	}

	return self;
}

- (void) dealloc {
	[updateVersion release];

	[super dealloc];
}

// closes this window
- (IBAction) closeWindow:(id)sender {
#pragma unused(sender)
	if ([self windowShouldClose:nil]) {
		[[self window] close];
	}
}

// called after the about window loads, so we can set up the window before it's displayed
- (void) windowDidLoad {
	NSObject<GrowlApplicationBridgeDelegate> *growlDelegate = [GrowlApplicationBridge growlDelegate];
	NSString *windowTitle;
	NSAttributedString *growlInfo;
	NSWindow *theWindow = [self window];

	//Setup the textviews
	[textView_growlInfo setHorizontallyResizable:NO];
	[textView_growlInfo setVerticallyResizable:YES];
	[textView_growlInfo setDrawsBackground:NO];
	[scrollView_growlInfo setDrawsBackground:NO];

	//Window title
	if (updateVersion ?
		[growlDelegate respondsToSelector:@selector(growlUpdateWindowTitle)] :
		[growlDelegate respondsToSelector:@selector(growlInstallationWindowTitle)]) {

		windowTitle = (updateVersion ? [growlDelegate growlUpdateWindowTitle] : [growlDelegate growlInstallationWindowTitle]);
	} else {
		windowTitle = (updateVersion ? DEFAULT_UPDATE_WINDOW_TITLE : DEFAULT_INSTALLATION_WINDOW_TITLE);
	}

	[theWindow setTitle:windowTitle];

	//Growl information
	if (updateVersion ?
		[growlDelegate respondsToSelector:@selector(growlUpdateInformation)] :
		[growlDelegate respondsToSelector:@selector(growlInstallationInformation)]) {
		growlInfo = (updateVersion ? [growlDelegate growlUpdateInformation] : [growlDelegate growlInstallationInformation]);

	} else {
		NSMutableAttributedString	*defaultGrowlInfo;

		//Start with the window title, centered and bold
		NSMutableParagraphStyle	*centeredStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
		[centeredStyle setAlignment:NSCenterTextAlignment];

		NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
			centeredStyle,                                 NSParagraphStyleAttributeName,
			[NSFont boldSystemFontOfSize:GROWL_TEXT_SIZE], NSFontAttributeName,
			nil];
		[centeredStyle release];
		defaultGrowlInfo = [[NSMutableAttributedString alloc] initWithString:windowTitle
																  attributes:attributes];
		//Skip a line
		[[defaultGrowlInfo mutableString] appendString:@"\n\n"];

		//Now provide a default explanation
		NSAttributedString *defaultExplanation;
		defaultExplanation = [[NSAttributedString alloc] initWithString:(updateVersion ?
																		  DEFAULT_UPDATE_EXPLANATION :
																		  DEFAULT_INSTALLATION_EXPLANATION)
															  attributes:[NSDictionary dictionaryWithObjectsAndKeys:
																  [NSFont systemFontOfSize:GROWL_TEXT_SIZE], NSFontAttributeName,
																  nil]];

		[defaultGrowlInfo appendAttributedString:defaultExplanation];
		[defaultExplanation release];

		growlInfo = defaultGrowlInfo;
	}

	[[textView_growlInfo textStorage] setAttributedString:growlInfo];
	NSRect	frame = [theWindow frame];
	int		heightChange;

	//Resize the window frame to fit the description
	[textView_growlInfo sizeToFit];
	heightChange = [textView_growlInfo frame].size.height - [scrollView_growlInfo documentVisibleRect].size.height;
	frame.size.height += heightChange;
	frame.origin.y -= heightChange;
	[theWindow setFrame:frame display:YES];

	//Localize and size the buttons

	//The install button should maintain its distance from the right side of the window
	NSRect	newInstallButtonFrame, oldInstallButtonFrame;
	int installButtonOriginLeftShift;
	oldInstallButtonFrame = [button_install frame];
	[button_install setTitle:(updateVersion ? UPDATE_BUTTON_TITLE : INSTALL_BUTTON_TITLE)];
	[button_install sizeToFit];
	newInstallButtonFrame = [button_install frame];
	//Don't shrink to a size less than the original size
	if (newInstallButtonFrame.size.width < oldInstallButtonFrame.size.width) {
		newInstallButtonFrame.size.width = oldInstallButtonFrame.size.width;
	}
	//Adjust the origin to put the right edge at the proper place
	newInstallButtonFrame.origin.x = (oldInstallButtonFrame.origin.x + oldInstallButtonFrame.size.width) - newInstallButtonFrame.size.width;
	installButtonOriginLeftShift = oldInstallButtonFrame.origin.x - newInstallButtonFrame.origin.x;
	[button_install setFrame:newInstallButtonFrame];

	NSRect newCancelButtonFrame, oldCancelButtonFrame;
	oldCancelButtonFrame = [button_cancel frame];
	[button_cancel setTitle:CANCEL_BUTTON_TITLE];
	[button_cancel sizeToFit];
	newCancelButtonFrame = [button_cancel frame];
	//Don't shrink to a size less than the original size
	if (newCancelButtonFrame.size.width < oldCancelButtonFrame.size.width) {
		newCancelButtonFrame.size.width = oldCancelButtonFrame.size.width;
	}
	//Adjust the origin to put the right edge at the proper place (same distance from the left edge of the install button as before)
	newCancelButtonFrame.origin.x = ((oldCancelButtonFrame.origin.x + oldCancelButtonFrame.size.width) - newCancelButtonFrame.size.width) - installButtonOriginLeftShift;
	[button_cancel setFrame:newCancelButtonFrame];

	[checkBox_dontAskAgain setTitle:DONT_ASK_AGAIN_CHECKBOX_TITLE];
	[checkBox_dontAskAgain sizeToFit];

	//put the spinner to the left of the Cancel button
	NSRect spinnerFrame = [spinner frame];
	spinnerFrame.origin.x = newCancelButtonFrame.origin.x - (spinnerFrame.size.width + 8.0f);
	[spinner setFrame:spinnerFrame];

	[spinner stopAnimation:nil];
	[button_install setEnabled:YES];
	[button_cancel  setEnabled:YES];
}

- (IBAction) installGrowl:(id)sender {
#pragma unused(sender)
	[spinner startAnimation:sender];
	[button_install setEnabled:NO];
	[button_cancel  setEnabled:NO];

	[self performInstallGrowl];

	[self releaseAndClose];
}

- (IBAction) cancel:(id)sender {
#pragma unused(sender)
	if (!updateVersion) {
		//Tell the app bridge about the user's choice
		[GrowlApplicationBridge _userChoseNotToInstallGrowl];
	}

	//Shut down the installation prompt
	[self releaseAndClose];
}

- (IBAction) dontAskAgain:(id)sender {
	BOOL dontAskAgain = ([sender state] == NSOnState);

	if (updateVersion) {
		if (dontAskAgain) {
			/* We want to be able to prompt again for the next version, so we track the version for which the user requested
			 * not to be prompted again.
			 */
			[[NSUserDefaults standardUserDefaults] setObject:updateVersion
													  forKey:@"Growl Update:Do Not Prompt Again:Last Version"];
		} else {
			[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"Growl Update:Do Not Prompt Again:Last Version"];
		}

	} else {
		//Store the user's preference to the user defaults dictionary
		[[NSUserDefaults standardUserDefaults] setBool:dontAskAgain
												forKey:@"Growl Installation:Do Not Prompt Again"];
	}
}

// called as the window closes
- (BOOL) windowShouldClose:(id)sender {
#pragma unused(sender)
	//If the window closes via the close button or cmd-W, it should be treated as clicking Cancel.
	[self cancel:nil];

	return YES;
}

- (void) performInstallGrowl {
	// Obtain the path to the archived Growl.prefPane
	NSFileManager *mgr = [NSFileManager defaultManager];
	NSBundle *bundle;
	NSString *archivePath, *tmpDir;
	NSTask	*unzip;
	BOOL success = NO;

	bundle = [NSBundle bundleForClass:[GrowlInstallationPrompt class]];
	archivePath = [bundle pathForResource:GROWL_PREFPANE_NAME ofType:@"zip"];

	//desired folder (Panther): /private/tmp/$UID/GrowlInstallations/`uuidgen`
	//desired folder (Tiger):   /private/var/tmp/folders.$UID/TemporaryItems/GrowlInstallations/`uuidgen`

	tmpDir = [NSTemporaryDirectory() stringByAppendingPathComponent:@"GrowlInstallations"];
	if (tmpDir) {
		[[NSFileManager defaultManager] createDirectoryAtPath:tmpDir attributes:nil];

		tmpDir = [tmpDir stringByAppendingPathComponent:[[NSProcessInfo processInfo] globallyUniqueString]];
		if (tmpDir) {
			[mgr createDirectoryAtPath:tmpDir attributes:nil];
			BOOL hasUnzip = YES;

			NSString *launchPath = @"/System/Library/CoreServices/BOMArchiveHelper.app/Contents/MacOS/BOMArchiveHelper";
			NSArray *arguments = nil;
			if ([mgr fileExistsAtPath:launchPath]) {
				//BOMArchiveHelper is more particular than unzip, so we need to do some clean-up first:
				//(1) copy the zip file into the temporary directory.
				NSString *archiveFilename = [archivePath lastPathComponent];
				NSString *tmpArchivePath = [tmpDir stringByAppendingPathComponent:archiveFilename];
				[mgr copyPath:archivePath
				       toPath:tmpArchivePath
				      handler:nil];

				//(2) pass BOMArchiveHelper only the path to the archive.
				arguments = [NSArray arrayWithObject:tmpArchivePath];
			} else {
				//no BOMArchiveHelper - fall back on unzip.
				launchPath = @"/usr/bin/unzip";
				hasUnzip = [mgr fileExistsAtPath:launchPath];

				if (hasUnzip) {
					arguments = [NSArray arrayWithObjects:
						@"-o",         //overwrite
						@"-q",         //quiet!
						archivePath,   //source zip file
						@"-d", tmpDir, //The temporary folder is the destination folder
						nil];
				}
			}

			if (hasUnzip) {
				unzip = [[NSTask alloc] init];
				[unzip setLaunchPath:launchPath];
				[unzip setArguments:arguments];
				[unzip setCurrentDirectoryPath:tmpDir];

				NS_DURING
					[unzip launch];
					[unzip waitUntilExit];
					success = ([unzip terminationStatus] == 0);
				NS_HANDLER
					/* No exception handler needed */
				NS_ENDHANDLER
				[unzip release];
			}

			if (success) {
				NSString	*tempGrowlPrefPane;

				/*Kill the running GrowlHelperApp if necessary by asking it via
				 *	DNC to shutdown.
				 */
				[[NSDistributedNotificationCenter defaultCenter] postNotificationName:GROWL_SHUTDOWN object:nil];

				//tell GAB to register when GHA next launches.
				[GrowlApplicationBridge setWillRegisterWhenGrowlIsReady:YES];

				/*Open Growl.prefPane using System Preferences, which will
				 *	take care of the rest.
				 *Growl.prefPane will relaunch the GHA if appropriate.
				 */
				tempGrowlPrefPane = [tmpDir stringByAppendingPathComponent:GROWL_PREFPANE_NAME];
				success = [[NSWorkspace sharedWorkspace] openFile:tempGrowlPrefPane
												  withApplication:@"System Preferences"
													andDeactivate:YES];
				if (!success) {
					/*If the System Preferences app could not be found for
					 *	whatever reason, try opening Growl.prefPane with
					 *	-openTempFile: so the associated app will launch. This
					 *	could be the case if "System Preferences.app" were
					 *	renamed or if an alternative program were being used.
					 */
					success = [[NSWorkspace sharedWorkspace] openTempFile:tempGrowlPrefPane];
				}
			}
		}
	}

	if (!success) {
#warning XXX - show this to the user; do not just log it.
		NSLog(@"%@", @"GrowlInstallationPrompt: Growl was not successfully installed");
	}
}

- (void)releaseAndClose {
	[self autorelease];
	[[self window] close];
}

@end
