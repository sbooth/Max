//
//  GrowlPref.m
//  Growl
//
//  Created by Karl Adam on Wed Apr 21 2004.
//  Copyright 2004-2005 The Growl Project. All rights reserved.
//
// This file is under the BSD License, refer to License.txt for details

#import "GrowlPref.h"
#import "GrowlPreferences.h"
#import "GrowlDefinesInternal.h"
#import "GrowlDefines.h"
#import "GrowlApplicationNotification.h"
#import "GrowlApplicationTicket.h"
#import "GrowlDisplayProtocol.h"
#import "GrowlPluginController.h"
#import "GrowlPathUtil.h"
#import "GrowlVersionUtilities.h"
#import "ACImageAndTextCell.h"
#import "NSStringAdditions.h"
#import "TicketsArrayController.h"
#import "GrowlBrowserEntry.h"
#import <ApplicationServices/ApplicationServices.h>
#import <Security/SecKeychain.h>
#import <Security/SecKeychainItem.h>
#import <SystemConfiguration/SystemConfiguration.h>

#define PING_TIMEOUT		3

#define keychainServiceName "Growl"
#define keychainAccountName "Growl"

//This is the frame of the preference view that we should get back.
#define DISPLAY_PREF_FRAME NSMakeRect(16.0f, 58.0f, 354.0f, 289.0f)

@interface NSNetService(TigerCompatibility)

- (void) resolveWithTimeout:(NSTimeInterval)timeout;

@end

@implementation GrowlPref

- (id) initWithBundle:(NSBundle *)bundle {
	//	Check that we're running Panther
	//	if a user with a previous OS version tries to launch us - switch out the pane.

	NSApp = [NSApplication sharedApplication];
	if (![NSApp respondsToSelector:@selector(replyToOpenOrPrint:)]) {
		NSString *msg = @"Mac OS X 10.3 \"Panther\" or greater is required.";

		if (NSRunInformationalAlertPanel(@"Growl requires Panther...", msg, @"Quit", @"Get Panther...", nil) == NSAlertAlternateReturn) {
			NSURL *pantherURL = [[NSURL alloc] initWithString:@"http://www.apple.com/macosx/"];
			[[NSWorkspace sharedWorkspace] openURL:pantherURL];
			[pantherURL release];
		}
		[NSApp terminate:nil];
	}

	if ((self = [super initWithBundle:bundle])) {
		pid = [[NSProcessInfo processInfo] processIdentifier];
		loadedPrefPanes = [[NSMutableArray alloc] init];

		NSNotificationCenter *nc = [NSDistributedNotificationCenter defaultCenter];
		[nc addObserver:self selector:@selector(growlLaunched:)   name:GROWL_IS_READY object:nil];
		[nc addObserver:self selector:@selector(growlTerminated:) name:GROWL_SHUTDOWN object:nil];

		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(reloadPrefs:)
													 name:GrowlPreferencesChanged
												   object:nil];

		NSDictionary *defaultDefaults = [[NSDictionary alloc] initWithContentsOfFile:
			[bundle pathForResource:@"GrowlDefaults"
							 ofType:@"plist"]];
		[[GrowlPreferences preferences] registerDefaults:defaultDefaults];
		[defaultDefaults release];
	}

	return self;
}

- (void) dealloc {
	[[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
	[browser         release];
	[services        release];
	[pluginPrefPane  release];
	[loadedPrefPanes release];
	[tickets         release];
	[startStopTimer  release];
	[images          release];
	[versionCheckURL release];
	[plugins         release];
	[currentPlugin   release];
	[customHistArray release];
	[growlWebSiteURL release];
	[growlForumURL   release];
	[growlDonateURL  release];
	[super dealloc];
}

#pragma mark -

- (NSString *) bundleVersion {
	return [[[self bundle] infoDictionary] objectForKey:(NSString *)kCFBundleVersionKey];
}

- (IBAction) checkVersion:(id)sender {
#pragma unused(sender)
	[growlVersionProgress startAnimation:self];

	if (!versionCheckURL)
		versionCheckURL = [[NSURL alloc] initWithString:@"http://growl.info/version.xml"];

	[self checkVersionAtURL:versionCheckURL
				displayText:NSLocalizedStringFromTableInBundle(@"A newer version of Growl is available online. Would you like to download it now?", nil, [self bundle], @"")];

	[growlVersionProgress stopAnimation:self];
}

- (void) checkVersionAtURL:(NSURL *)url displayText:(NSString *)message {
	NSBundle *bundle = [self bundle];
	NSDictionary *infoDict = [bundle infoDictionary];
	NSString *currVersionNumber = [infoDict objectForKey:(NSString *)kCFBundleVersionKey];
	NSDictionary *productVersionDict = [[NSDictionary alloc] initWithContentsOfURL:url];
	NSString *executableName = [infoDict objectForKey:(NSString *)kCFBundleExecutableKey];
	NSString *latestVersionNumber = [productVersionDict objectForKey:executableName];

	NSURL *downloadURL = [[NSURL alloc] initWithString:
		[productVersionDict objectForKey:[executableName stringByAppendingString:@"DownloadURL"]]];
	/*
	NSLog([[[NSBundle bundleForClass:[GrowlPref class]] infoDictionary] objectForKey:(NSString *)kCFBundleExecutableKey] );
	NSLog(currVersionNumber);
	NSLog(latestVersionNumber);
	*/

	// do nothing--be quiet if there is no active connection or if the
	// version number could not be downloaded
	if (latestVersionNumber && (compareVersionStringsTranslating1_0To0_5(latestVersionNumber, currVersionNumber) > 0)) {
		NSBeginAlertSheet(/*title*/ NSLocalizedStringFromTableInBundle(@"Update Available", nil, bundle, @""),
						  /*defaultButton*/ nil, // use default localized button title ("OK" in English)
						  /*alternateButton*/ NSLocalizedStringFromTableInBundle(@"Cancel", nil, bundle, @""),
						  /*otherButton*/ nil,
						  /*docWindow*/ nil,
						  /*modalDelegate*/ self,
						  /*didEndSelector*/ NULL,
						  /*didDismissSelector*/ @selector(downloadSelector:returnCode:contextInfo:),
						  /*contextInfo*/ downloadURL,
						  /*msg*/ message);
	} else {
		[downloadURL release];
	}

	[productVersionDict release];
}

- (void) downloadSelector:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
#pragma unused(sheet)
	NSURL *downloadURL = (NSURL *)contextInfo;
	if (returnCode == NSAlertDefaultReturn) {
		[[NSWorkspace sharedWorkspace] openURL:downloadURL];
	}
	[downloadURL release];
}

+ (BOOL) isGrowlMenuRunning {
	return [[GrowlPreferences preferences] isRunning:@"com.Growl.MenuExtra"];
}

- (void) enableGrowlMenu {
	NSString *growlMenuPath = [[self bundle] pathForResource:@"GrowlMenu" ofType:@"app"];

	// Add to login items
	[[GrowlPreferences preferences] setStartAtLogin:growlMenuPath enabled:YES];

	// We want to launch in background, so we have to resort to Carbon
	LSLaunchFSRefSpec spec;
	FSRef appRef;
	OSStatus status = FSPathMakeRef((const UInt8 *)[growlMenuPath fileSystemRepresentation], &appRef, NULL);

	if (status == noErr) {
		spec.appRef = &appRef;
		spec.numDocs = 0U;
		spec.itemRefs = NULL;
		spec.passThruParams = NULL;
		spec.launchFlags = kLSLaunchDontAddToRecents | kLSLaunchNoParams | kLSLaunchAsync | kLSLaunchDontSwitch;
		spec.asyncRefCon = NULL;
		LSOpenFromRefSpec(&spec, NULL);
	}
}

- (void) disableGrowlMenu {
	NSString *growlMenuPath = [[self bundle] pathForResource:@"GrowlMenu" ofType:@"app"];

	// Ask GrowlMenu to shutdown via the DNC
	[[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"GrowlMenuShutdown" object:nil];

	// Remove from login items
	[[GrowlPreferences preferences] setStartAtLogin:growlMenuPath enabled:NO];
}

- (void) awakeFromNib {
	NSTableColumn *tableColumn = [growlApplications tableColumnWithIdentifier:@"application"];
	ACImageAndTextCell *imageAndTextCell = [[ACImageAndTextCell alloc] init];
	[imageAndTextCell setEditable:YES];
	[tableColumn setDataCell:imageAndTextCell];
	[imageAndTextCell release];
	// TODO: this does not work
	//NSSecureTextFieldCell *secureTextCell = [[NSSecureTextFieldCell alloc] init];
	//[servicePasswordColumn setDataCell:secureTextCell];
	//[secureTextCell release];

	NSButtonCell *cell = [notificationStickyColumn dataCell];
	[cell setAllowsMixedState:YES];

	// NSCreatesSortDescriptorBindingOption is only available on 10.4 or later
	NSNumber *no = [[NSNumber alloc] initWithBool:NO];
	NSDictionary *bindOptions = [[NSDictionary alloc] initWithObjectsAndKeys:
		no, @"NSCreatesSortDescriptor", //NSCreatesSortDescriptorBindingOption,
		nil];
	[no release];

	// we have to establish this binding programmatically in order to use NSMixedState
	[notificationStickyColumn bind:@"value"
						  toObject:notificationsArrayController
					   withKeyPath:@"arrangedObjects.sticky"
						   options:bindOptions];
	[bindOptions release];

	[ticketsArrayController addObserver:self forKeyPath:@"selection" options:0 context:nil];
	[displayPluginsArrayController addObserver:self forKeyPath:@"selection" options:0 context:nil];

	[self setCanRemoveTicket:NO];

	browser = [[NSNetServiceBrowser alloc] init];

	GrowlPreferences *preferences = [GrowlPreferences preferences];

	// create a deep mutable copy of the forward destinations
	NSArray *destinations = [preferences objectForKey:GrowlForwardDestinationsKey];
	NSEnumerator *destEnum = [destinations objectEnumerator];
	NSMutableArray *theServices = [[NSMutableArray alloc] initWithCapacity:[destinations count]];
	NSDictionary *destination;
	while ((destination = [destEnum nextObject])) {
		GrowlBrowserEntry *entry = [[GrowlBrowserEntry alloc] initWithDictionary:destination];
		[entry setOwner:self];
		[theServices addObject:entry];
		[entry release];
	}
	[self setServices:theServices];
	[theServices release];

	[browser setDelegate:self];
	[browser searchForServicesOfType:@"_growl._tcp." inDomain:@""];

	[self setupAboutTab];

	if ([self growlMenuEnabled] && ![GrowlPref isGrowlMenuRunning]) {
		[self enableGrowlMenu];
	}

	growlWebSiteURL = [[NSURL alloc] initWithString:@"http://growl.info"];
	growlForumURL   = [[NSURL alloc] initWithString:@"http://forums.cocoaforge.com/viewforum.php?f=6"];
	growlDonateURL		= [[NSURL alloc] initWithString:@"http://growl.info/donate.php"];

	customHistArray = [[NSMutableArray alloc] initWithObjects:
		[preferences objectForKey:GrowlCustomHistKey1],
		[preferences objectForKey:GrowlCustomHistKey2],
		[preferences objectForKey:GrowlCustomHistKey3],
		nil];
	[self updateLogPopupMenu];
	int typePref = [preferences integerForKey:GrowlLogTypeKey];
	[logFileType selectCellAtRow:typePref column:0];
}

- (void) mainViewDidLoad {
	[[NSDistributedNotificationCenter defaultCenter] addObserver:self
														selector:@selector(appRegistered:)
															name:GROWL_APP_REGISTRATION_CONF
														  object:nil];
}

//subclassed from NSPreferencePane; called before the pane is displayed.
- (void) willSelect {
	GrowlPreferences *preferences = [GrowlPreferences preferences];
	NSString *lastVersion = [preferences objectForKey:LastKnownVersionKey];
	NSString *currentVersion = [self bundleVersion];
	if (!(lastVersion && [lastVersion isEqualToString:currentVersion])) {
		if ([preferences isGrowlRunning]) {
			[preferences setGrowlRunning:NO noMatterWhat:NO];
			[preferences setGrowlRunning:YES noMatterWhat:YES];
		}
		[preferences setObject:currentVersion forKey:LastKnownVersionKey];
	}
	[self checkGrowlRunning];
}

- (void) didSelect {
	[self reloadPreferences];
}

// copy images to avoid resizing the original image stored in the ticket
- (void) cacheImages {
	if (images)
		[images release];

	images = [[NSMutableArray alloc] initWithCapacity:[tickets count]];
	NSEnumerator *enumerator = [tickets objectEnumerator];
	GrowlApplicationTicket *ticket;

	while ((ticket = [enumerator nextObject])) {
		NSImage *icon = [[ticket icon] copy];
		[icon setScalesWhenResized:YES];
		[icon setSize:NSMakeSize(16.0f, 16.0f)];
		[images addObject:icon];
		[icon release];
	}
}

- (NSMutableArray *) tickets {
	return tickets;
}

- (void) setTickets:(NSArray *)theTickets {
	if (theTickets != tickets) {
		[tickets release];
		tickets = [[NSMutableArray alloc] initWithArray:theTickets];
	}
}

- (void) removeFromTicketsAtIndex:(int)indexToRemove {
	NSMutableArray *ticketsCopy = [tickets mutableCopy];
	[ticketsCopy removeObjectAtIndex:indexToRemove];

	//	We're not using the setTickets accessor here.
	//	If we did, the controller would know we had switched out the entire array.
	//	And UI quirks would happen. (selection jumps back to 0)

	[tickets release];
	tickets = ticketsCopy;
}



- (void) insertInTickets:(GrowlApplicationTicket*)newTicket {
	NSMutableArray			*ticketsCopy = [tickets mutableCopy];
	[ticketsCopy addObject:newTicket];
	[self setTickets:ticketsCopy];
	[ticketsCopy release];
}


- (void) reloadDisplayPluginView {
	NSArray *selectedPlugins = [displayPluginsArrayController selectedObjects];
	unsigned numPlugins = [plugins count];
	[currentPlugin release];
	if (numPlugins > 0U && selectedPlugins && [selectedPlugins count] > 0U) {
		currentPlugin = [[selectedPlugins objectAtIndex:0U] retain];
	} else {
		currentPlugin = nil;
	}

	GrowlPluginController *growlPluginController = [GrowlPluginController controller];
	currentPluginController = [growlPluginController displayPluginNamed:currentPlugin];
	[self loadViewForDisplay:currentPlugin];
	NSDictionary *info = [[growlPluginController bundleForPluginNamed:currentPlugin] infoDictionary];
	[displayAuthor setStringValue:[info objectForKey:@"GrowlPluginAuthor"]];
	[displayVersion setStringValue:[info objectForKey:(NSString *)kCFBundleVersionKey]];
}

- (void) reloadPrefs:(NSNotification *)notification {
	// ignore notifications which are sent by ourselves
	NSNumber *pidValue = [[notification userInfo] objectForKey:@"pid"];
	if (!pidValue || [pidValue intValue] != pid) {
		[self reloadPreferences];
	}
}

- (void) reloadPreferences {
//	NSLog(@"%s\n", __FUNCTION__);
	[self setDisplayPlugins:[[GrowlPluginController controller] allDisplayPlugins]];
	[self setTickets:[[GrowlApplicationTicket allSavedTickets] allValues]];
	
#warning What good does it do to set squelch mode to the value it already is?
//	[self setSquelchMode:[self squelchMode]];
	[self setGrowlMenuEnabled:[self growlMenuEnabled]];
	[self cacheImages];

	GrowlPreferences *preferences = [GrowlPreferences preferences];
	
	// If Growl is enabled, ensure the helper app is launched
	if ([preferences boolForKey:GrowlEnabledKey]) {
		[preferences launchGrowl:NO];
	}

	if ([plugins count] > 0U) {
		NSString *defaultPlugin = [preferences objectForKey:GrowlDisplayPluginKey];
		unsigned defaultIndex = [[displayPluginsArrayController arrangedObjects] indexOfObject:defaultPlugin];
		if (defaultIndex == NSNotFound) {
			defaultIndex = 0U;
		}
		[displayPluginsArrayController setSelectionIndex:defaultIndex];
		[self reloadDisplayPluginView];
	} else {
		[self loadViewForDisplay:nil];
	}
}

- (BOOL) growlIsRunning {
	return growlIsRunning;
}

- (void) setGrowlIsRunning:(BOOL)flag {
	growlIsRunning = flag;
}

- (void) updateRunningStatus {
	[startStopTimer invalidate];
	startStopTimer = nil;
	[startStopGrowl setEnabled:YES];
	NSBundle *bundle = [self bundle];
	[startStopGrowl setTitle:
		growlIsRunning ? NSLocalizedStringFromTableInBundle(@"Stop Growl",nil,bundle,@"")
					   : NSLocalizedStringFromTableInBundle(@"Start Growl",nil,bundle,@"")];
	[growlRunningStatus setStringValue:
		growlIsRunning ? NSLocalizedStringFromTableInBundle(@"Growl is running.",nil,bundle,@"")
					   : NSLocalizedStringFromTableInBundle(@"Growl is stopped.",nil,bundle,@"")];
	[growlRunningProgress stopAnimation:self];
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
						change:(NSDictionary *)change context:(void *)context {
#pragma unused(change, context)
	if ([keyPath isEqualToString:@"selection"]) {
		if ((object == ticketsArrayController)) {
			[self setCanRemoveTicket:(activeTableView == growlApplications) && [ticketsArrayController canRemove]];
		} else if (object == displayPluginsArrayController) {
			[self reloadDisplayPluginView];
		}
	}
}

- (void) writeForwardDestinations {
	NSMutableArray *destinations = [[NSMutableArray alloc] initWithCapacity:[services count]];
	NSEnumerator *enumerator = [services objectEnumerator];
	GrowlBrowserEntry *entry;
	while ((entry = [enumerator nextObject])) {
		if (![entry netService]) {
			[destinations addObject:[entry properties]];
		}
	}
	[[GrowlPreferences preferences] setObject:destinations forKey:GrowlForwardDestinationsKey];
	[destinations release];
}

#pragma mark -
#pragma mark Growl running state

- (void) launchGrowl {
	// Don't allow the button to be clicked while we update
	[startStopGrowl setEnabled:NO];
	[growlRunningProgress startAnimation:self];

	// Update our status visible to the user
	[growlRunningStatus setStringValue:NSLocalizedStringFromTableInBundle(@"Launching Growl...",nil,[self bundle],@"")];

	[[GrowlPreferences preferences] setGrowlRunning:YES noMatterWhat:NO];

	// After 4 seconds force a status update, in case Growl didn't start/stop
	[self performSelector:@selector(checkGrowlRunning)
			   withObject:nil
			   afterDelay:4.0];
}

- (void) terminateGrowl {
	// Don't allow the button to be clicked while we update
	[startStopGrowl setEnabled:NO];
	[growlRunningProgress startAnimation:self];

	// Update our status visible to the user
	[growlRunningStatus setStringValue:NSLocalizedStringFromTableInBundle(@"Terminating Growl...",nil,[self bundle],@"")];

	// Ask the Growl Helper App to shutdown
	[[GrowlPreferences preferences] setGrowlRunning:NO noMatterWhat:NO];

	// After 4 seconds force a status update, in case growl didn't start/stop
	[self performSelector:@selector(checkGrowlRunning)
			   withObject:nil
			   afterDelay:4.0];
}

#pragma mark "General" tab pane

- (IBAction) startStopGrowl:(id) sender {
#pragma unused(sender)
	// Make sure growlIsRunning is correct
	if (growlIsRunning != [[GrowlPreferences preferences] isGrowlRunning]) {
		// Nope - lets just flip it and update status
		[self setGrowlIsRunning:!growlIsRunning];
		[self updateRunningStatus];
		return;
	}

	// Our desired state is a toggle of the current state;
	if (growlIsRunning)
		[self terminateGrowl];
	else
		[self launchGrowl];
}

#pragma mark -

- (BOOL) isStartGrowlAtLogin {
	return [[GrowlPreferences preferences] startGrowlAtLogin];
}

- (void) setStartGrowlAtLogin:(BOOL)flag {
	[[GrowlPreferences preferences] setStartGrowlAtLogin:flag];
}

#pragma mark -

- (BOOL) isBackgroundUpdateCheckEnabled {
	return [[GrowlPreferences preferences] boolForKey:GrowlUpdateCheckKey];
}

- (void) setIsBackgroundUpdateCheckEnabled:(BOOL)flag {
	[[GrowlPreferences preferences] setBool:flag forKey:GrowlUpdateCheckKey];
}

#pragma mark -

- (NSString *) defaultDisplayPluginName {
	return [[GrowlPreferences preferences] objectForKey:GrowlDisplayPluginKey];
}

- (void) setDefaultDisplayPluginName:(NSString *)name {
	[[GrowlPreferences preferences] setObject:name forKey:GrowlDisplayPluginKey];
}

#pragma mark -

- (BOOL) squelchMode {
	return [[GrowlPreferences preferences] boolForKey:GrowlSquelchModeKey];
}

- (void) setSquelchMode:(BOOL)flag {
	[[GrowlPreferences preferences] setBool:flag forKey:GrowlSquelchModeKey];
}

#pragma mark -  

- (BOOL) stickyWhenAway {
	return [[GrowlPreferences preferences] boolForKey:GrowlStickyWhenAwayKey];
}

- (void) setStickyWhenAway:(BOOL)flag {
	[[GrowlPreferences preferences] setBool:flag forKey:GrowlStickyWhenAwayKey];
}

#pragma mark Menu Extra

- (BOOL) growlMenuEnabled {
	return [[GrowlPreferences preferences] boolForKey:GrowlMenuExtraKey];
}

- (void) setGrowlMenuEnabled:(BOOL)state {
	if (state != [self growlMenuEnabled]) {
		[[GrowlPreferences preferences] setBool:state forKey:GrowlMenuExtraKey];
		if (state) {
			[self enableGrowlMenu];
		} else {
			[self disableGrowlMenu];
		}
	}
}

#pragma mark Logging

- (BOOL) loggingEnabled {
	return [[GrowlPreferences preferences] boolForKey:GrowlLoggingEnabledKey];
}

- (void) setLoggingEnabled:(BOOL)flag {
	[[GrowlPreferences preferences] setBool:flag forKey:GrowlLoggingEnabledKey];
}

- (IBAction) logTypeChanged:(id)sender {
#pragma unused(sender)
	int		typePref;

	typePref = [logFileType selectedRow];
	BOOL hasSelection = (typePref != 0);
	if (hasSelection && ([customMenuButton numberOfItems] == 1)) {
		[self customFileChosen:customMenuButton];
	}
	[[GrowlPreferences preferences] setInteger:typePref forKey:GrowlLogTypeKey];
	[customMenuButton setEnabled:(hasSelection && ([customMenuButton numberOfItems] > 1))];
}

- (IBAction) openConsoleApp:(id)sender {
#pragma unused(sender)
	[[NSWorkspace sharedWorkspace] launchApplication:@"Console"];
}

- (IBAction) customFileChosen:(id)sender {
	int selected = [sender indexOfSelectedItem];
	if ((selected == [sender numberOfItems] - 1) || (selected == -1)) {
		NSSavePanel *sp = [NSSavePanel savePanel];
		[sp setRequiredFileType:@"log"];
		[sp setCanSelectHiddenExtension:YES];

		int runResult = [sp runModalForDirectory:nil file:@""];
		NSString *saveFilename = [sp filename];
		if (runResult == NSFileHandlingPanelOKButton) {
			unsigned saveFilenameIndex = NSNotFound;
			unsigned                 i = [customHistArray count];
			if (i) {
				while (--i) {
					if ([[customHistArray objectAtIndex:i] isEqual:saveFilename]) {
						saveFilenameIndex = i;
						break;
					}
				}
			}
			if (saveFilenameIndex == NSNotFound) {
				if ([customHistArray count] == 3U)
					[customHistArray removeLastObject];
			} else {
				[customHistArray removeObjectAtIndex:saveFilenameIndex];
			}
			[customHistArray insertObject:saveFilename atIndex:0U];
		}
	} else {
		NSString *temp = [[customHistArray objectAtIndex:selected] retain];
		[customHistArray removeObjectAtIndex:selected];
		[customHistArray insertObject:temp atIndex:0U];
		[temp release];
	}

	unsigned numHistItems = [customHistArray count];
	//NSLog(@"CustomHistArray = %@", customHistArray);
	if (numHistItems) {
		GrowlPreferences *preferences = [GrowlPreferences preferences];
		NSString *s = [customHistArray objectAtIndex:0U];
		[preferences setObject:s forKey:GrowlCustomHistKey1];
		//NSLog(@"Writing %@ as hist1", s);

		if ((numHistItems > 1U) && (s = [customHistArray objectAtIndex:1U])) {
			[preferences setObject:s forKey:GrowlCustomHistKey2];
			//NSLog(@"Writing %@ as hist2", s);
		}

		if ((numHistItems > 2U) && (s = [customHistArray objectAtIndex:2U])) {
			[preferences setObject:s forKey:GrowlCustomHistKey3];
			//NSLog(@"Writing %@ as hist3", s);
		}

		//[[logFileType cellAtRow:1 column:0] setEnabled:YES];
		[logFileType selectCellAtRow:1 column:0];
	}

	[self updateLogPopupMenu];
}

- (void) updateLogPopupMenu {
	[customMenuButton removeAllItems];

	unsigned numHistItems = [customHistArray count];
	for (unsigned i = 0U; i < numHistItems; i++) {
		NSArray *pathComponentry = [[[customHistArray objectAtIndex:i] stringByAbbreviatingWithTildeInPath] pathComponents];
		unsigned numPathComponents = [pathComponentry count];
		if (numPathComponents > 2U) {
			unichar ellipsis = 0x2026;
			NSMutableString *arg = [[NSMutableString alloc] initWithCharacters:&ellipsis length:1U];
			[arg appendString:@"/"];
			[arg appendString:[pathComponentry objectAtIndex:(numPathComponents - 2U)]];
			[arg appendString:@"/"];
			[arg appendString:[pathComponentry objectAtIndex:(numPathComponents - 1U)]];
			[customMenuButton insertItemWithTitle:arg atIndex:i];
			[arg release];
		} else {
			[customMenuButton insertItemWithTitle:[[customHistArray objectAtIndex:i] stringByAbbreviatingWithTildeInPath] atIndex:i];
		}
	}
	// No separator if there's no file list yet
	if (numHistItems > 0U) {
		[[customMenuButton menu] addItem:[NSMenuItem separatorItem]];
	}
	[customMenuButton addItemWithTitle:NSLocalizedStringFromTableInBundle(@"Browse menu item title", /*tableName*/ nil, [self bundle], /*comment*/ nil)];
	//select first item, if any
	[customMenuButton selectItemAtIndex:numHistItems ? 0 : -1];
}

#pragma mark "Applications" tab pane

- (BOOL) canRemoveTicket {
	return canRemoveTicket;
}

- (void) setCanRemoveTicket:(BOOL)flag {
	canRemoveTicket = flag;
}

- (void) deleteTicket:(id)sender {
#pragma unused(sender)
	GrowlApplicationTicket *ticket = [[ticketsArrayController selectedObjects] objectAtIndex:0U];
	NSString *path = [ticket path];

	if ([[NSFileManager defaultManager] removeFileAtPath:path handler:nil]) {
		NSNumber *pidValue = [[NSNumber alloc] initWithInt:pid];
		NSDictionary *userInfo = [[NSDictionary alloc] initWithObjectsAndKeys:
			[ticket applicationName], @"TicketName",
			pidValue,                 @"pid",
			nil];
		[pidValue release];
		[[NSDistributedNotificationCenter defaultCenter] postNotificationName:GrowlPreferencesChanged
																	   object:@"GrowlTicketDeleted"
																	 userInfo:userInfo];
		[userInfo release];
		unsigned idx = [tickets indexOfObject:ticket];
		[images removeObjectAtIndex:idx];

		unsigned oldSelectionIndex = [ticketsArrayController selectionIndex];

		///	Hmm... This doesn't work for some reason....
		//	Even though the same method definitely^H^H^H^H^H^H probably works in the appRegistered: method...

		//	[self removeFromTicketsAtIndex:	[ticketsArrayController selectionIndex]];

		NSMutableArray *newTickets = [tickets mutableCopy];
		[newTickets removeObject:ticket];
		[self setTickets:newTickets];
		[newTickets release];

		if (oldSelectionIndex >= [tickets count])
			oldSelectionIndex = [tickets count] - 1;

		[ticketsArrayController setSelectionIndex:oldSelectionIndex];
	}
}

#pragma mark "Network" tab pane

- (BOOL) isGrowlServerEnabled {
	return [[GrowlPreferences preferences] boolForKey:GrowlStartServerKey];
}

- (void) setGrowlServerEnabled:(BOOL)enabled {
	[[GrowlPreferences preferences] setBool:enabled forKey:GrowlStartServerKey];
}

#pragma mark -

- (BOOL) isRemoteRegistrationAllowed {
	return [[GrowlPreferences preferences] boolForKey:GrowlRemoteRegistrationKey];
}

- (void) setRemoteRegistrationAllowed:(BOOL)flag {
	[[GrowlPreferences preferences] setBool:flag forKey:GrowlRemoteRegistrationKey];
}

#pragma mark -

- (NSString *) remotePassword {
	char *password;
	UInt32 passwordLength;
	OSStatus status;
	status = SecKeychainFindGenericPassword( NULL,
											 strlen(keychainServiceName), keychainServiceName,
											 strlen(keychainAccountName), keychainAccountName,
											 &passwordLength, (void **)&password, NULL );

	NSString *passwordString;
	if (status == noErr) {
		passwordString = [NSString stringWithUTF8String:password length:passwordLength];
		SecKeychainItemFreeContent(NULL, password);
	} else {
		if (status != errSecItemNotFound) {
			NSLog(@"Failed to retrieve password from keychain. Error: %d", status);
		}
		passwordString = @"";
	}

	return passwordString;
}

- (void) setRemotePassword:(NSString *)value {
	const char *password = value ? [value UTF8String] : "";
	unsigned length = strlen(password);
	OSStatus status;
	SecKeychainItemRef itemRef = nil;
	status = SecKeychainFindGenericPassword( NULL,
											 strlen(keychainServiceName), keychainServiceName,
											 strlen(keychainAccountName), keychainAccountName,
											 NULL, NULL, &itemRef );
	if (status == errSecItemNotFound) {
		// add new item
		status = SecKeychainAddGenericPassword( NULL,
												strlen(keychainServiceName), keychainServiceName,
												strlen(keychainAccountName), keychainAccountName,
												length, password, NULL );
		if (status) {
			NSLog(@"Failed to add password to keychain.");
		}
	} else {
		// change existing password
		SecKeychainAttribute attrs[] = {
		{ kSecAccountItemAttr, strlen(keychainAccountName), (char *)keychainAccountName },
		{ kSecServiceItemAttr, strlen(keychainServiceName), (char *)keychainServiceName }
		};
		const SecKeychainAttributeList attributes = { sizeof(attrs) / sizeof(attrs[0]), attrs };
		status = SecKeychainItemModifyAttributesAndData( itemRef,		// the item reference
														 &attributes,	// no change to attributes
														 length,		// length of password
														 password		// pointer to password data
														 );
		if (itemRef) {
			CFRelease(itemRef);
		}
		if (status) {
			NSLog(@"Failed to change password in keychain.");
		}
	}
}

#pragma mark -

- (int) UDPPort {
	return [[GrowlPreferences preferences] integerForKey:GrowlUDPPortKey];
}

- (void) setUDPPort:(int)value {
	[[GrowlPreferences preferences] setInteger:value forKey:GrowlUDPPortKey];
}

#pragma mark -

- (BOOL) isForwardingEnabled {
	return [[GrowlPreferences preferences] boolForKey:GrowlEnableForwardKey];
}

- (void) setForwardingEnabled:(BOOL)enabled {
	[[GrowlPreferences preferences] setBool:enabled forKey:GrowlEnableForwardKey];
}

- (void) resolveService:(id)sender {
	int row = [sender selectedRow];
	if (row != -1) {
		GrowlBrowserEntry *entry = [services objectAtIndex:row];
		NSNetService *serviceToResolve = [entry netService];
		if (serviceToResolve) {
			// Make sure to cancel any previous resolves.
			if (serviceBeingResolved) {
				[serviceBeingResolved stop];
				[serviceBeingResolved release];
				serviceBeingResolved = nil;
			}

			currentServiceIndex = row;
			serviceBeingResolved = serviceToResolve;
			[serviceBeingResolved retain];
			[serviceBeingResolved setDelegate:self];
			if ([serviceBeingResolved respondsToSelector:@selector(resolveWithTimeout:)]) {
				[serviceBeingResolved resolveWithTimeout:5.0];
			} else {
				// this selector is deprecated in 10.4
				[serviceBeingResolved resolve];
			}
		}
	}
}

- (NSMutableArray *) services {
	return services;
}

- (void) setServices:(NSMutableArray *)theServices {
	if (theServices != services) {
		[services release];
		services = [theServices retain];
	}
}

- (unsigned) countOfServices {
	return [services count];
}

- (id) objectInServicesAtIndex:(unsigned)idx {
	return [services objectAtIndex:idx];
}

- (void) insertObject:(id)anObject inServicesAtIndex:(unsigned)idx {
	[services insertObject:anObject atIndex:idx];
}

- (void) replaceObjectInServicesAtIndex:(unsigned)idx withObject:(id)anObject {
	[services replaceObjectAtIndex:idx withObject:anObject];
}

#pragma mark "Display Options" tab pane

- (NSArray *) displayPlugins {
	return plugins;
}

- (void) setDisplayPlugins:(NSArray *)thePlugins {
	[plugins release];
	plugins = [thePlugins retain];
}

#pragma mark -

- (IBAction) showPreview:(id) sender {
#pragma unused(sender)
	[[NSDistributedNotificationCenter defaultCenter] postNotificationName:GrowlPreview object:currentPlugin];
}

- (void) loadViewForDisplay:(NSString *)displayName {
	NSView *newView = nil;
	NSPreferencePane *prefPane = nil, *oldPrefPane = nil;

	if (pluginPrefPane) {
		oldPrefPane = pluginPrefPane;
	}

	if (displayName) {
		// Old plugins won't support the new protocol. Check first
		if ([currentPluginController respondsToSelector:@selector(preferencePane)]) {
			prefPane = [currentPluginController preferencePane];
		}

		if (prefPane == pluginPrefPane) {
			// Don't bother swapping anything
			return;
		} else {
			[pluginPrefPane release];
			pluginPrefPane = [prefPane retain];
			[oldPrefPane willUnselect];
		}
		if (pluginPrefPane) {
			if ([loadedPrefPanes containsObject:pluginPrefPane]) {
				newView = [pluginPrefPane mainView];
			} else {
				newView = [pluginPrefPane loadMainView];
				[loadedPrefPanes addObject:pluginPrefPane];
			}
			[pluginPrefPane willSelect];
		}
	} else {
		[pluginPrefPane release];
		pluginPrefPane = nil;
	}
	if (!newView) {
		newView = displayDefaultPrefView;
	}
	if (displayPrefView != newView) {
		// Make sure the new view is framed correctly
		[newView setFrame:DISPLAY_PREF_FRAME];
		[[displayPrefView superview] replaceSubview:displayPrefView with:newView];
		displayPrefView = newView;

		if (pluginPrefPane) {
			[pluginPrefPane didSelect];
			// Hook up key view chain
			[displayPluginsTable setNextKeyView:[pluginPrefPane firstKeyView]];
			[[pluginPrefPane lastKeyView] setNextKeyView:previewButton];
			//[[displayPluginsTable window] makeFirstResponder:[pluginPrefPane initialKeyView]];
		} else {
			[displayPluginsTable setNextKeyView:previewButton];
		}

		if (oldPrefPane) {
			[oldPrefPane didUnselect];
		}
	}
}

#pragma mark About Tab

- (void) setupAboutTab {
	[aboutBoxTextView readRTFDFromFile:[[self bundle] pathForResource:@"About" ofType:@"rtf"]];
}

- (IBAction) openGrowlWebSite:(id)sender {
#pragma unused(sender)
	[[NSWorkspace sharedWorkspace] openURL:growlWebSiteURL];
}

- (IBAction) openGrowlForum:(id)sender {
#pragma unused(sender)
	[[NSWorkspace sharedWorkspace] openURL:growlForumURL];
}


- (IBAction) openGrowlDonate:(id)sender {
#pragma unused(sender)
	[[NSWorkspace sharedWorkspace] openURL:growlDonateURL];
}

#pragma mark TableView delegate methods

- (void) tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)column row:(int)row {
	if (tableView == growlApplications && [[column identifier] isEqualTo:@"application"]) {
		NSArray *arrangedTickets = [ticketsArrayController arrangedObjects];
		unsigned idx = [tickets indexOfObject:[arrangedTickets objectAtIndex:row]];
		[(ACImageAndTextCell *)cell setImage:[images objectAtIndex:idx]];
	}
}

- (void) tableViewDidClickInBody:(NSTableView *)tableView {
	activeTableView = tableView;
	[self setCanRemoveTicket:(activeTableView == growlApplications) && [ticketsArrayController canRemove]];
}

#pragma mark NSNetServiceBrowser Delegate Methods

- (void) netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didFindService:(NSNetService *)aNetService moreComing:(BOOL)moreComing {
#pragma unused(aNetServiceBrowser)
	// check if a computer with this name has already been added
	NSString *name = [aNetService name];
	NSEnumerator *enumerator = [services objectEnumerator];
	GrowlBrowserEntry *entry;
	while ((entry = [enumerator nextObject])) {
		if ([[entry computerName] isEqualToString:name]) {
			return;
		}
	}

	// don't add the local machine
	NSString *localHostName = (NSString *)SCDynamicStoreCopyComputerName(/*store*/ NULL,
																		 /*nameEncoding*/ NULL);
	BOOL isLocalHost = [localHostName isEqualToString:name];
	[localHostName release];
	if (isLocalHost) {
		return;
	}

	// add a new entry at the end
	entry = [[GrowlBrowserEntry alloc] initWithComputerName:name netService:aNetService];
	[self willChangeValueForKey:@"services"];
	[services addObject:entry];
	[self didChangeValueForKey:@"services"];
	[entry release];

	if (!moreComing) {
		[self writeForwardDestinations];
	}
}

- (void) netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didRemoveService:(NSNetService *)aNetService moreComing:(BOOL)moreComing {
#pragma unused(aNetServiceBrowser)
	// This case is slightly more complicated. We need to find the object in the list and remove it.
	unsigned count = [services count];
	GrowlBrowserEntry *currentEntry;
	NSString *name = [aNetService name];

	for (unsigned i = 0; i < count; ++i) {
		currentEntry = [services objectAtIndex:i];
		if ([[currentEntry computerName] isEqualToString:name]) {
			[self willChangeValueForKey:@"services"];
			[services removeObjectAtIndex:i];
			[self didChangeValueForKey:@"services"];
			break;
		}
	}

	if (serviceBeingResolved && [serviceBeingResolved isEqual:aNetService]) {
		[serviceBeingResolved stop];
		[serviceBeingResolved release];
		serviceBeingResolved = nil;
	}

	if (!moreComing) {
		[self writeForwardDestinations];
	}
}

- (void) netServiceDidResolveAddress:(NSNetService *)sender {
	NSArray *addresses = [sender addresses];
	if ([addresses count] > 0U) {
		NSData *address = [addresses objectAtIndex:0U];
		GrowlBrowserEntry *entry = [services objectAtIndex:currentServiceIndex];
		[entry setAddress:address];
		[self writeForwardDestinations];
	}
}

#pragma mark Detecting Growl

- (void) checkGrowlRunning {
	[self setGrowlIsRunning:[[GrowlPreferences preferences] isGrowlRunning]];
	[self updateRunningStatus];
}

#pragma mark -

// Refresh preferences when a new application registers with Growl
- (void) appRegistered: (NSNotification *) note {
	NSString *app = [note object];
	GrowlApplicationTicket *newTicket = [[GrowlApplicationTicket alloc] initTicketForApplication:app];

	/*
	 *	Because the tickets array is under KVObservation by the TicketsArrayController
	 *	We need to remove the ticket using the correct KVC method:
	 */
	NSEnumerator *ticketEnumerator = [tickets objectEnumerator];
	GrowlApplicationTicket *ticket;
	int removalIndex = -1;

	int		i = 0U;
	while ((ticket = [ticketEnumerator nextObject])) {
		if ([[ticket applicationName] isEqualToString:app]) {
			removalIndex = i;
			break;
		}
		i++;
	}

	if (removalIndex != -1) {
		[self removeFromTicketsAtIndex:removalIndex];
	}

	[self insertInTickets:newTicket];
	[newTicket release];

	[self cacheImages];
}

- (void) growlLaunched:(NSNotification *)note {
#pragma unused(note)
	[self setGrowlIsRunning:YES];
	[self updateRunningStatus];
}

- (void) growlTerminated:(NSNotification *)note {
#pragma unused(note)
	[self setGrowlIsRunning:NO];
	[self updateRunningStatus];
}

@end
