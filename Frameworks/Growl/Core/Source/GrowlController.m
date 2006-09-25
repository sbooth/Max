//
//  GrowlController.m
//  Growl
//
//  Created by Karl Adam on Thu Apr 22 2004.
//  Copyright 2004-2005 The Growl Project. All rights reserved.
//
// This file is under the BSD License, refer to License.txt for details

#import "GrowlController.h"
#import "GrowlPreferences.h"
#import "GrowlApplicationTicket.h"
#import "GrowlApplicationNotification.h"
#import "GrowlDistributedNotificationPathway.h"
#import "GrowlRemotePathway.h"
#import "GrowlUDPPathway.h"
#import "GrowlApplicationBridgePathway.h"
#import "CFGrowlAdditions.h"
#import "NSStringAdditions.h"
#import "NSURLAdditions.h"
#import "NSDictionaryAdditions.h"
#import "GrowlDisplayProtocol.h"
#import "GrowlPluginController.h"
#import "GrowlApplicationBridge.h"
#import "GrowlStatusController.h"
#import "GrowlDefines.h"
#import "GrowlVersionUtilities.h"
#import "SVNRevision.h"
#import "GrowlLog.h"
#import "GrowlNotificationCenter.h"
#import "MD5Authenticator.h"
#import "cdsa.h"
#import <SystemConfiguration/SystemConfiguration.h>
#include <sys/socket.h>
#include <netinet/in.h>

// check every 24 hours
#define UPDATE_CHECK_INTERVAL	24.0*3600.0

@interface GrowlController (private)
- (void) loadDisplay;
- (void) notificationClicked:(NSNotification *)notification;
- (void) notificationTimedOut:(NSNotification *)notification;
@end

static struct Version version = { 0U, 7U, 4U, releaseType_release, 0U, };
//static struct Version version = { 0U, 7U, 4U, releaseType_beta, 1U, };
//XXX - update these constants whenever the version changes

#pragma mark -

static id singleton = nil;

@implementation GrowlController

+ (GrowlController *) standardController {
	return singleton;
}

- (id) init {
	if ((self = [super init])) {
		if (cdsaInit()) {
			NSLog(@"ERROR: Could not initialize CDSA.");
			[self release];
			return nil;
		}
		
		timeoutSeconds = 30.0;

		NSDistributedNotificationCenter *NSDNC = [NSDistributedNotificationCenter defaultCenter];

		[NSDNC addObserver:self
				  selector:@selector(preferencesChanged:)
					  name:GrowlPreferencesChanged
					object:nil];
		[NSDNC addObserver:self
				  selector:@selector(showPreview:)
					  name:GrowlPreview
					object:nil];
		[NSDNC addObserver:self
				  selector:@selector(shutdown:)
					  name:GROWL_SHUTDOWN
					object:nil];
		[NSDNC addObserver:self
				  selector:@selector(replyToPing:)
					  name:GROWL_PING
					object:nil];

		NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
		[nc addObserver:self
			   selector:@selector(notificationClicked:)
				   name:GROWL_NOTIFICATION_CLICKED
				 object:nil];
		[nc addObserver:self
			   selector:@selector(notificationTimedOut:)
				   name:GROWL_NOTIFICATION_TIMED_OUT
				 object:nil];

		authenticator = [[MD5Authenticator alloc] init];

		//XXX temporary DNC pathway hack - remove when real pathway support is in
		dncPathway = [[GrowlDistributedNotificationPathway alloc] init];

		tickets = [[NSMutableDictionary alloc] init];

		[self versionDictionary];

		GrowlPreferences *preferences = [GrowlPreferences preferences];
		NSDictionary *defaultDefaults = [[NSDictionary alloc] initWithContentsOfFile:
			[[NSBundle mainBundle] pathForResource:@"GrowlDefaults" ofType:@"plist"]];
		[preferences registerDefaults:defaultDefaults];
		[defaultDefaults release];

		[self preferencesChanged:nil];

		[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
															   selector:@selector(applicationLaunched:)
																   name:NSWorkspaceDidLaunchApplicationNotification
																 object:nil];

		growlIcon = [[NSImage imageNamed:@"NSApplicationIcon"] retain];
		growlIconData = [[growlIcon TIFFRepresentation] retain];

		[GrowlApplicationBridge setGrowlDelegate:self];

		if (!singleton)
			singleton = self;

		statusController = [[GrowlStatusController alloc] init];

		NSDate *lastCheck = [preferences objectForKey:LastUpdateCheckKey];
		NSDate *now = [NSDate date];
		if (!lastCheck || [now timeIntervalSinceDate:lastCheck] > UPDATE_CHECK_INTERVAL) {
			[self checkVersion:nil];
			lastCheck = now;
		}
		[lastCheck addTimeInterval:UPDATE_CHECK_INTERVAL];
		updateTimer = [[NSTimer alloc] initWithFireDate:lastCheck
											   interval:UPDATE_CHECK_INTERVAL
												 target:self
											   selector:@selector(checkVersion:)
											   userInfo:nil
												repeats:YES];

		// create and register GrowlNotificationCenter
		growlNotificationCenter = [[GrowlNotificationCenter alloc] init];
		growlNotificationCenterConnection = [[NSConnection alloc] initWithReceivePort:[NSPort port] sendPort:nil];
		[growlNotificationCenterConnection setRootObject:growlNotificationCenter];
		if (![growlNotificationCenterConnection registerName:@"GrowlNotificationCenter"]) {
			NSLog(@"WARNING: could not register GrowlNotificationCenter");
		}

		// initialize GrowlApplicationBridgePathway
		[GrowlApplicationBridgePathway standardPathway];
	}

	return self;
}

- (void) dealloc {
	//free your world
	[self stopServer];
	[authenticator release];
	[dncPathway    release]; //XXX temporary DNC pathway hack - remove when real pathway support is in
	[destinations  release];

	[tickets           release];

	[growlIcon     release];
	[growlIconData release];

	[versionCheckURL  release];
	[updateTimer      invalidate];
	[updateTimer      release];
	[statusController release];

	[growlNotificationCenterConnection invalidate];
	[growlNotificationCenterConnection release];
	[growlNotificationCenter release];

	cdsaShutdown();

	[super dealloc];
}

#pragma mark -

- (void) netService:(NSNetService *)sender didNotPublish:(NSDictionary *)errorDict {
#pragma unused(sender)
	NSLog(@"WARNING: could not publish Growl service. Error: %@", errorDict);
}

- (BOOL) connection:(NSConnection *)ancestor shouldMakeNewConnection:(NSConnection *)conn {
	[conn setDelegate:[ancestor delegate]];
	return YES;
}

- (NSData *) authenticationDataForComponents:(NSArray *)components {
	return [authenticator authenticationDataForComponents:components];
}

- (BOOL) authenticateComponents:(NSArray *)components withData:(NSData *)signature {
	return [authenticator authenticateComponents:components withData:signature];
}

- (void) startServer {
	socketPort = [[NSSocketPort alloc] initWithTCPPort:GROWL_TCP_PORT];
	serverConnection = [[NSConnection alloc] initWithReceivePort:socketPort sendPort:nil];
	server = [[GrowlRemotePathway alloc] init];
	[serverConnection setRootObject:server];
	[serverConnection setDelegate:self];

	// register with the default NSPortNameServer on the local host
	if (![serverConnection registerName:@"GrowlServer"]) {
		NSLog(@"WARNING: could not register Growl server.");
	}

	// configure and publish the Bonjour service
	NSString *serviceName = (NSString *)SCDynamicStoreCopyComputerName(/*store*/ NULL,
																	   /*nameEncoding*/ NULL);
	service = [[NSNetService alloc] initWithDomain:@""	// use local registration domain
											  type:@"_growl._tcp."
											  name:serviceName
											  port:GROWL_TCP_PORT];
	[serviceName release];
	[service setDelegate:self];
	[service publish];

	// start UDP service
	udpServer = [[GrowlUDPPathway alloc] init];
}

- (void) stopServer {
	[udpServer release];
	[serverConnection registerName:nil];	// unregister
	[serverConnection invalidate];
	[serverConnection release];
	[socketPort invalidate];
	[socketPort release];
	[server release];
	[service stop];
	[service release];
	service = nil;
}

- (void) startStopServer {
	BOOL enabled = [[GrowlPreferences preferences] boolForKey:GrowlStartServerKey];

	// Setup notification server
	if (enabled && !service) {
		// turn on
		[self startServer];
	} else if (!enabled && service) {
		// turn off
		[self stopServer];
	}
}

#pragma mark -

- (void) showPreview:(NSNotification *) note {
	NSString *displayName = [note object];
	id <GrowlDisplayPlugin> displayPlugin = [[GrowlPluginController controller] displayPluginNamed:displayName];

	NSString *desc = [[NSString alloc] initWithFormat:@"This is a preview of the %@ display", displayName];
	NSNumber *priority = [[NSNumber alloc] initWithInt:0];
	NSNumber *sticky = [[NSNumber alloc] initWithBool:NO];
	NSDictionary *info = [[NSDictionary alloc] initWithObjectsAndKeys:
		@"Preview", GROWL_NOTIFICATION_TITLE,
		desc,       GROWL_NOTIFICATION_DESCRIPTION,
		priority,   GROWL_NOTIFICATION_PRIORITY,
		sticky,     GROWL_NOTIFICATION_STICKY,
		growlIcon,  GROWL_NOTIFICATION_ICON,
		nil];
	[desc     release];
	[priority release];
	[sticky   release];
	[displayPlugin displayNotificationWithInfo:info];
	[info release];
}

- (void) forwardDictionary:(NSDictionary *)dict withSelector:(SEL)forwardMethod {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	NSEnumerator *enumerator = [destinations objectEnumerator];
	NSDictionary *entry;
	while ((entry = [enumerator nextObject])) {
		if ([entry boolForKey:@"use"]) {
			NSData *destAddress = [entry objectForKey:@"address"];
			NSString *password = [entry objectForKey:@"password"];
			NSSocketPort *serverPort = [[NSSocketPort alloc]
				initRemoteWithProtocolFamily:AF_INET
								  socketType:SOCK_STREAM
									protocol:IPPROTO_TCP
									 address:destAddress];
			
			NSConnection *connection = [[NSConnection alloc] initWithReceivePort:nil
																		sendPort:serverPort];
			MD5Authenticator *auth = [[MD5Authenticator alloc] initWithPassword:password];
			[connection setDelegate:auth];
			[connection setRequestTimeout:timeoutSeconds];
			[connection setReplyTimeout:timeoutSeconds];
			
			@try {
				NSDistantObject *theProxy = [connection rootProxy];
				[theProxy setProtocolForProxy:@protocol(GrowlNotificationProtocol)];
				NSProxy <GrowlNotificationProtocol> *growlProxy = (NSProxy <GrowlNotificationProtocol> *)theProxy;
				[growlProxy performSelector:forwardMethod withObject:dict];
			} @catch(NSException *e) {
				if ([[e name] isEqualToString:@"NSFailedAuthenticationException"]) {
					NSLog(@"Authentication failed while forwarding to %@ (%@)",
						  [NSString stringWithAddressData:destAddress],
						  [NSString hostNameForAddressData:destAddress]);
				} else
					NSLog(@"Exception while forwarding dictionary with selector %s (description of dictionary follows): %@\n%@", forwardMethod, e, dict);
			} @finally {
				[connection invalidate];
				[serverPort invalidate];
				[serverPort release];
				[connection release];
				[auth release];
			}
		}
	}
	
	[pool release];
}

- (void) forwardNotification:(NSDictionary *)dict {
	[self forwardDictionary:dict withSelector:@selector(postNotificationWithDictionary:)];
}

- (void) forwardRegistration:(NSDictionary *)dict {
	[self forwardDictionary:dict withSelector:@selector(registerApplicationWithDictionary:)];
}

- (void) dispatchNotificationWithDictionary:(NSDictionary *)dict {
	[GrowlLog logNotificationDictionary:dict];

	// Make sure this notification is actually registered
	NSString *appName = [dict objectForKey:GROWL_APP_NAME];
	GrowlApplicationTicket *ticket = [tickets objectForKey:appName];
	NSString *notificationName = [dict objectForKey:GROWL_NOTIFICATION_NAME];
	if (!ticket || ![ticket isNotificationAllowed:notificationName]) {
		// Either the app isn't registered or the notification is turned off
		// We should do nothing
		return;
	}

	NSMutableDictionary *aDict = [dict mutableCopy];

	// Check icon
	NSImage *icon = nil;
	id image = [aDict objectForKey:GROWL_NOTIFICATION_ICON];
	if (image && [image isKindOfClass:[NSImage class]]) {
		icon = [image copy];
	} else if (image && [image isKindOfClass:[NSData class]]) {
		icon = [[NSImage alloc] initWithData:image];
	} else {
		icon = [[ticket icon] copy];
	}
	if (icon) {
		[aDict setObject:icon forKey:GROWL_NOTIFICATION_ICON];
		[icon release];
	} else {
		[aDict removeObjectForKey:GROWL_NOTIFICATION_ICON]; // remove any invalid NSDatas
	}

	// If app icon present, convert to NSImage
	NSData *appIconData = [aDict objectForKey:GROWL_NOTIFICATION_APP_ICON];
	if (appIconData) {
		NSImage *appIcon = [[NSImage alloc] initWithData:appIconData];
		[aDict setObject:appIcon forKey:GROWL_NOTIFICATION_APP_ICON];
		[appIcon release];
	}

	// To avoid potential exceptions, make sure we have both text and title
	if (![aDict objectForKey:GROWL_NOTIFICATION_DESCRIPTION]) {
		[aDict setObject:@"" forKey:GROWL_NOTIFICATION_DESCRIPTION];
	}
	if (![aDict objectForKey:GROWL_NOTIFICATION_TITLE]) {
		[aDict setObject:@"" forKey:GROWL_NOTIFICATION_TITLE];
	}

	//Retrieve and set the the priority of the notification
	GrowlApplicationNotification *notification = [ticket notificationForName:notificationName];
	int priority = [notification priority];
	NSNumber *value;
	if (priority == GP_unset) {
		value = [dict objectForKey:GROWL_NOTIFICATION_PRIORITY];
	} else {
		value = [NSNumber numberWithInt:priority];
	}
	if (value) {
		[aDict setObject:value forKey:GROWL_NOTIFICATION_PRIORITY];
	} else {
		[aDict removeObjectForKey:GROWL_NOTIFICATION_PRIORITY];		
	}

	GrowlPreferences *preferences = [GrowlPreferences preferences];

	// Retrieve and set the sticky bit of the notification
	int sticky = [notification sticky];
	value = nil;

	if (sticky >= 0) {
		//If sticky is 0, the notification is explicitly never sticky. If 1, it is explicitly always sticky.
		value = [[NSNumber alloc] initWithBool:(sticky ? YES : NO)];
	} else if ([preferences boolForKey:GrowlStickyWhenAwayKey]) {
		NSNumber *inSticky = [aDict objectForKey:GROWL_NOTIFICATION_STICKY];

		if (!(inSticky && [inSticky boolValue])) {
			/* If sticky when awaay is YES, and the notification is not already marked as sticky,
			* determine if it should be sticky.
			*/
			value = [[NSNumber alloc] initWithBool:[statusController isIdle]];
		}
	}
	if (value) {
		/* If we set a value, use that as the sticky setting.  If we didn't, leave aDict alone to 
		 * respect whatever was set by the generating notifier.
		 */
		[aDict setObject:value forKey:GROWL_NOTIFICATION_STICKY];
		[value release];
	}

	BOOL saveScreenshot = [[NSUserDefaults standardUserDefaults] boolForKey:GROWL_SCREENSHOT_MODE];
	value = [[NSNumber alloc] initWithBool:saveScreenshot];
	[aDict setObject:value forKey:GROWL_SCREENSHOT_MODE];
	[value release];

	value = [[NSNumber alloc] initWithBool:[ticket clickHandlersEnabled]];
	[aDict setObject:value forKey:@"ClickHandlerEnabled"];
	[value release];

	if (![preferences boolForKey:GrowlSquelchModeKey]) {
		id <GrowlDisplayPlugin> display = [notification displayPlugin];

		if (!display) {
			NSString *displayPluginName = [aDict objectForKey:GROWL_DISPLAY_PLUGIN];
			if (displayPluginName) {
				display = [[GrowlPluginController controller] displayPluginNamed:displayPluginName];
			}
		}

		if (!display) {
			display = [ticket displayPlugin];
		}

		if (!display) {
			display = displayController;
		}

		[display displayNotificationWithInfo:aDict];
	}

	// send to DO observers
	[growlNotificationCenter notifyObservers:aDict];

	[aDict release];

	// forward to remote destinations
	if (enableForward)
		[NSThread detachNewThreadSelector:@selector(forwardNotification:)
								 toTarget:self
							   withObject:dict];
}

- (BOOL) registerApplicationWithDictionary:(NSDictionary *) userInfo {
	[GrowlLog logRegistrationDictionary:userInfo];

	NSString *appName = [userInfo objectForKey:GROWL_APP_NAME];

	GrowlApplicationTicket *newApp = [tickets objectForKey:appName];

	NSString *notificationName;
	if (newApp) {
		[newApp reregisterWithDictionary:userInfo];
		notificationName = @"Application re-registered";
	} else {
		newApp = [[[GrowlApplicationTicket alloc] initWithDictionary:userInfo] autorelease];
		notificationName = @"Application registered";
	}

	BOOL success = YES;

	if (appName && newApp) {
		[tickets setObject:newApp forKey:appName];
		[newApp saveTicket];
		[[NSDistributedNotificationCenter defaultCenter] postNotificationName:GROWL_APP_REGISTRATION_CONF
																	   object:appName];

		[GrowlApplicationBridge notifyWithTitle:notificationName
									description:[appName stringByAppendingString:@" registered"]
							   notificationName:notificationName
									   iconData:growlIconData
									   priority:0
									   isSticky:NO
								   clickContext:nil];

		if (enableForward)
			[NSThread detachNewThreadSelector:@selector(forwardRegistration:)
									 toTarget:self
								   withObject:userInfo];
	} else { //!newApp
		NSString *filename = [(appName ? appName : @"unknown-application") stringByAppendingPathExtension:GROWL_REG_DICT_EXTENSION];
		NSString *path = [@"/var/log" stringByAppendingPathComponent:filename];

		NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:path];
		[fh seekToEndOfFile];
		if ([fh offsetInFile]) //we are not at the beginning of the file
			[fh writeData:[@"\n---\n\n" dataUsingEncoding:NSUTF8StringEncoding]];
		[fh writeData:[[[userInfo description] stringByAppendingString:@"\n"] dataUsingEncoding:NSUTF8StringEncoding]];
		[fh closeFile];

		if (!appName) appName = @"with no name";

		NSLog(@"Failed application registration for application %@; wrote failed registration dictionary %p to %@", appName, userInfo, path);
		success = NO;
	}

	return success;
}

#pragma mark -
- (void) growlNotificationWasClicked:(id)clickContext {
	NSURL *downloadURL = (NSURL *)clickContext;
	[[NSWorkspace sharedWorkspace] openURL:downloadURL];
}

- (void) checkVersion:(NSTimer *)timer {
#pragma unused(timer)
	GrowlPreferences *preferences = [GrowlPreferences preferences];

	if (![preferences boolForKey:GrowlUpdateCheckKey])
		return;

	if (!versionCheckURL)
		versionCheckURL = [[NSURL alloc] initWithString:@"http://growl.info/version.xml"];

	NSDictionary *productVersionDict = [[NSDictionary alloc] initWithContentsOfURL:versionCheckURL];

	NSString *currVersionNumber = [GrowlController growlVersion];
	NSString *latestVersionNumber = [productVersionDict objectForKey:@"Growl"];

	NSString *downloadURLString = [productVersionDict objectForKey:@"GrowlDownloadURL"];

	/*do nothing and be quiet if there is no active connection, if the
	 *	version dictionary could not be downloaded, or if the version dictionary
	 *	is missing either of these keys.
	 */
	if (downloadURLString && latestVersionNumber) {
		NSURL *downloadURL = [[NSURL alloc] initWithString:downloadURLString];

		[preferences setObject:[NSDate date] forKey:LastUpdateCheckKey];
		if (compareVersionStringsTranslating1_0To0_5(latestVersionNumber, currVersionNumber) > 0) {
			[GrowlApplicationBridge notifyWithTitle:NSLocalizedString(@"Update Available", /*comment*/ nil)
				                        description:NSLocalizedString(@"A newer version of Growl is available online. Click here to download it now.", /*comment*/ nil)
				                   notificationName:@"Growl update available"
			                               iconData:growlIconData
			                               priority:1
			                               isSticky:YES
			                           clickContext:downloadURL];
		}

		[downloadURL release];
	}

	[productVersionDict release];
}

+ (NSString *) growlVersion {
	return [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString *)kCFBundleVersionKey];
}

- (NSDictionary *)versionDictionary {
	if (!versionInfo) {
		if (version.releaseType == releaseType_svn) {
			version.development = strtoul(SVN_REVISION, /*endptr*/ NULL, 10);
		}

		const unsigned long long *versionNum = (const unsigned long long *)&version;
		NSNumber *complete = [[NSNumber alloc] initWithUnsignedLongLong:*versionNum];
		NSNumber *major = [[NSNumber alloc] initWithUnsignedShort:version.major];
		NSNumber *minor = [[NSNumber alloc] initWithUnsignedShort:version.minor];
		NSNumber *incremental = [[NSNumber alloc] initWithUnsignedChar:version.incremental];
		NSNumber *releaseType = [[NSNumber alloc] initWithUnsignedChar:version.releaseType];
		NSNumber *development = [[NSNumber alloc] initWithUnsignedShort:version.development];

		versionInfo = [NSDictionary dictionaryWithObjectsAndKeys:
			complete,                              @"Complete version",
			[GrowlController growlVersion],        (NSString *)kCFBundleVersionKey,

			major,                                 @"Major version",
			minor,                                 @"Minor version",
			incremental,                           @"Incremental version",
			releaseTypeNames[version.releaseType], @"Release type name",
			releaseType,                           @"Release type",
			development,                           @"Development version",

			nil];

		[complete    release];
		[major       release];
		[minor       release];
		[incremental release];
		[releaseType release];
		[development release];
	}
	return versionInfo;
}

//this method could be moved to Growl.framework, I think.
//pass nil to get GrowlHelperApp's version as a string.
- (NSString *)stringWithVersionDictionary:(NSDictionary *)d {
	if (!d) {
		d = [self versionDictionary];
	}

	//0.6
	NSMutableString *result = [NSMutableString stringWithFormat:@"%@.%@",
		[d objectForKey:@"Major version"],
		[d objectForKey:@"Minor version"]];

	//the .1 in 0.6.1
	NSNumber *incremental = [d objectForKey:@"Incremental version"];
	if ([incremental unsignedShortValue]) {
		[result appendFormat:@"%@", incremental];
	}

	NSString *releaseTypeName = [d objectForKey:@"Release type name"];
	if ([releaseTypeName length]) {
		//"" (release), "b4", " SVN 900"
		[result appendFormat:@"%@%@", releaseTypeName, [d objectForKey:@"Development version"]];
	}

	return result;
}

#pragma mark -

- (void) preferencesChanged: (NSNotification *) note {
	//[note object] is the changed key. A nil key means reload our tickets.
	id object = [note object];
	if (!note || (object && [object isEqualTo:GrowlStartServerKey])) {
		[self startStopServer];
	}
	if (!note || (object && [object isEqualTo:GrowlUserDefaultsKey])) {
		[[GrowlPreferences preferences] synchronize];
	}
	if (!note || (object && [object isEqualTo:GrowlEnabledKey])) {
		growlIsEnabled = [[GrowlPreferences preferences] boolForKey:GrowlEnabledKey];
	}
	if (!note || (object && [object isEqualTo:GrowlEnableForwardKey])) {
		enableForward = [[GrowlPreferences preferences] boolForKey:GrowlEnableForwardKey];
	}
	if (!note || (object && [object isEqualTo:GrowlForwardTimeoutKey])) {
		timeoutSeconds = (double)[[GrowlPreferences preferences] floatForKey:GrowlForwardTimeoutKey];
	}
	if (!note || (object && [object isEqualTo:GrowlForwardDestinationsKey])) {
		[destinations release];
		destinations = [[[GrowlPreferences preferences] objectForKey:GrowlForwardDestinationsKey] retain];
	}
	if (!note || !object) {
		[tickets removeAllObjects];
		[tickets addEntriesFromDictionary:[GrowlApplicationTicket allSavedTickets]];
	}
	if (!note || (object && [object isEqualTo:GrowlDisplayPluginKey])) {
		[self loadDisplay];
	}
	if (object) {
		if ([object isEqualTo:@"GrowlTicketDeleted"]) {
			NSString *ticketName = [[note userInfo] objectForKey:@"TicketName"];
			[tickets removeObjectForKey:ticketName];
		} else if ([object isEqualTo:@"GrowlTicketChanged"]) {
			NSString *ticketName = [[note userInfo] objectForKey:@"TicketName"];
			GrowlApplicationTicket *newTicket = [[GrowlApplicationTicket alloc] initTicketForApplication:ticketName];
			if (newTicket) {
				[tickets setObject:newTicket forKey:ticketName];
				[newTicket release];
			}
		} else if ([object isEqualTo:GrowlUDPPortKey]) {
			[self stopServer];
			[self startServer];
		}
	}
}

- (void) shutdown:(NSNotification *) note {
#pragma unused(note)
	[NSApp terminate:nil];
}

- (void) replyToPing:(NSNotification *) note {
#pragma unused(note)
	[[NSDistributedNotificationCenter defaultCenter] postNotificationName:GROWL_PONG
																   object:nil
																 userInfo:versionInfo];
}

#pragma mark NSApplication Delegate Methods

- (BOOL) application:(NSApplication *)theApplication openFile:(NSString *)filename {
#pragma unused(theApplication)
	BOOL retVal;
	NSString *pathExtension = [filename pathExtension];

//	NSLog(@"Asked to open file %@", filename);

	if ([pathExtension isEqualToString:@"growlView"] || [pathExtension isEqualToString:@"growlStyle"]) {
		[[GrowlPluginController controller] installPlugin:filename];
		retVal = YES;
	} else if ([pathExtension isEqualToString:GROWL_REG_DICT_EXTENSION]) {
		NSDictionary *regDict = [[NSDictionary alloc] initWithContentsOfFile:filename];
		if ([filename isSubpathOf:NSTemporaryDirectory()]) //assume we got here from GAB
			[[NSFileManager defaultManager] removeFileAtPath:filename handler:nil];

		if (regDict) {
			//Register this app using the indicated dictionary
			[self registerApplicationWithDictionary:regDict];
			[regDict release];
			retVal = YES;
		} else {
			retVal = NO;
		}
	} else {
		retVal = NO;
	}

	/* If Growl is not enabled and was not already running before
	 *	(for example, via an autolaunch even though the user's last
	 *	preference setting was to click "Stop Growl," setting enabled to NO),
	 *	quit having registered; otherwise, remain running.
	 */
	if (!growlIsEnabled && !growlFinishedLaunching) {
		[NSApp terminate:self];
	}

	return retVal;
}

- (void) applicationWillFinishLaunching:(NSNotification *)aNotification {
#pragma unused(aNotification)
	BOOL printVersionAndExit = [[NSUserDefaults standardUserDefaults] boolForKey:@"PrintVersionAndExit"];
	if (printVersionAndExit) {
		printf("This is GrowlHelperApp version %s.\n"
			   "PrintVersionAndExit was set to %u, so GrowlHelperApp will now exit.\n",
			   [[self stringWithVersionDictionary:nil] UTF8String],
			   printVersionAndExit);
		[NSApp terminate:nil];
	}

	NSFileManager *fs = [NSFileManager defaultManager];

	NSString *destDir, *subDir;
	NSArray *searchPath = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, /*expandTilde*/ YES);

	destDir = [searchPath objectAtIndex:0U]; //first == last == ~/Library
	[fs createDirectoryAtPath:destDir attributes:nil];
	destDir = [destDir stringByAppendingPathComponent:@"Application Support"];
	[fs createDirectoryAtPath:destDir attributes:nil];
	destDir = [destDir stringByAppendingPathComponent:@"Growl"];
	[fs createDirectoryAtPath:destDir attributes:nil];

	subDir  = [destDir stringByAppendingPathComponent:@"Tickets"];
	[fs createDirectoryAtPath:subDir attributes:nil];
	subDir  = [destDir stringByAppendingPathComponent:@"Plugins"];
	[fs createDirectoryAtPath:subDir attributes:nil];
}

//Post a notification when we are done launching so the application bridge can inform participating applications
- (void) applicationDidFinishLaunching:(NSNotification *)aNotification {
#pragma unused(aNotification)
	[[NSDistributedNotificationCenter defaultCenter] postNotificationName:GROWL_IS_READY
																   object:nil
																 userInfo:nil
													   deliverImmediately:YES];
	growlFinishedLaunching = YES;
}

//Same as applicationDidFinishLaunching, called when we are asked to reopen (that is, we are already running)
- (BOOL) applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)flag {
#pragma unused(theApplication, flag)
	return NO;
}

- (BOOL) applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication {
#pragma unused(theApplication)
	return NO;
}

- (void) applicationWillTerminate:(NSNotification *)notification {
#pragma unused(notification)
	[self release];
}

#pragma mark Auto-discovery

//called by NSWorkspace when an application launches.
- (void) applicationLaunched:(NSNotification *)notification {
	NSDictionary *userInfo = [notification userInfo];

	NSString *appName = [userInfo objectForKey:@"NSApplicationName"];
	NSString *appPath = [userInfo objectForKey:@"NSApplicationPath"];

	if (appPath) {
		NSString *ticketPath = [NSBundle pathForResource:@"Growl Registration Ticket" ofType:GROWL_REG_DICT_EXTENSION inDirectory:appPath];
		NSDictionary *ticket = [[NSDictionary alloc] initWithContentsOfFile:ticketPath];

		if (ticket) {
			//set the app's name in the dictionary, if it's not present already.
			NSMutableDictionary *mTicket = [ticket mutableCopy];
			if (![mTicket objectForKey:GROWL_APP_NAME])
				[mTicket setObject:appName forKey:GROWL_APP_NAME];
			[ticket release];
			ticket = mTicket;

			if ([GrowlApplicationTicket isValidTicketDictionary:ticket]) {
				NSLog(@"Auto-discovered registration ticket in %@ (located at %@)", appName, appPath);

				/*set the app's location in the dictionary, avoiding costly
				 *	lookups later.
				 */
				{
					NSURL *url = [[NSURL alloc] initFileURLWithPath:appPath];
					NSDictionary *file_data = [url dockDescription];
					id location = file_data ? [NSDictionary dictionaryWithObject:file_data forKey:@"file-data"] : appPath;
					[mTicket setObject:location forKey:GROWL_APP_LOCATION];
					[url release];

					//write the new ticket to disk, and be sure to launch this ticket instead of the one in the app bundle.
					NSString *UUID = [[NSProcessInfo processInfo] globallyUniqueString];
					ticketPath = [[NSTemporaryDirectory() stringByAppendingPathComponent:UUID] stringByAppendingPathExtension:GROWL_REG_DICT_EXTENSION];
					[ticket writeToFile:ticketPath atomically:NO];
				}

				/*open the ticket with ourselves.
				 *we need to use LS in order to launch it with this specific
				 *	GHA, rather than some other.
				 */
				NSURL *myURL        = copyCurrentProcessURL();
				NSURL *ticketURL    = [[NSURL alloc] initFileURLWithPath:ticketPath];
				NSArray *URLsToOpen = [NSArray arrayWithObject:ticketURL];
				struct LSLaunchURLSpec spec = {
					.appURL = (CFURLRef)myURL,
					.itemURLs = (CFArrayRef)URLsToOpen,
					.passThruParams = NULL,
					.launchFlags = kLSLaunchDontAddToRecents | kLSLaunchDontSwitch | kLSLaunchAsync,
					.asyncRefCon = NULL,
				};
				OSStatus err = LSOpenFromURLSpec(&spec, /*outLaunchedURL*/ NULL);
				if (err != noErr) {
					NSLog(@"The registration ticket for %@ could not be opened (LSOpenFromURLSpec returned %li). Pathname for the ticket file: %@", appName, (long)err, ticketPath);
				}
				[myURL release];
				[ticketURL release];
			} else if ([GrowlApplicationTicket isKnownTicketVersion:ticket]) {
				NSLog(@"%@ (located at %@) contains an invalid registration ticket - developer, please consult Growl developer documentation (http://growl.info/documentation/developer/)", appName, appPath);
			} else {
				NSLog(@"%@ (located at %@) contains a ticket whose version (%i) is unrecognised by this version (%@) of Growl", appName, appPath, [[ticket objectForKey:GROWL_TICKET_VERSION] intValue], [self stringWithVersionDictionary:nil]);
			}
			[ticket release];
		}
	}
}

#pragma mark Growl Delegate Methods
- (NSData *) applicationIconDataForGrowl {
	return growlIconData;
}

- (NSString *) applicationNameForGrowl {
	return @"Growl";
}

- (NSDictionary *) registrationDictionaryForGrowl {
	NSArray *allNotifications = [[NSArray alloc] initWithObjects:
		@"Growl update available",
		@"Application registered",
		@"Application re-registered",
		nil];

	NSNumber *default0 = [[NSNumber alloc] initWithUnsignedInt:0U];
	NSNumber *default1 = [[NSNumber alloc] initWithUnsignedInt:1U];
	NSArray *defaultNotifications = [[NSArray alloc] initWithObjects:
		default0, default1, nil];
	[default0 release];
	[default1 release];

	NSDictionary *registrationDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
		allNotifications, GROWL_NOTIFICATIONS_ALL,
		defaultNotifications, GROWL_NOTIFICATIONS_DEFAULT,
		nil];

	[allNotifications     release];
	[defaultNotifications release];

	return registrationDictionary;
}

@end

#pragma mark -

@implementation GrowlController (private)

- (void) loadDisplay {
	NSString *displayPlugin = [[GrowlPreferences preferences] objectForKey:GrowlDisplayPluginKey];
	displayController = [[GrowlPluginController controller] displayPluginNamed:displayPlugin];
}

#pragma mark -

- (void) notificationClicked:(NSNotification *)notification {
	NSString *appName, *growlNotificationClickedName;
	NSString *suffix;
	NSDictionary *clickInfo;
	NSDictionary *userInfo;

	userInfo = [notification userInfo];

	//Build the application-specific notification name
	appName = [notification object];
	if ([[userInfo objectForKey:@"ClickHandlerEnabled"] boolValue]) {
		suffix = GROWL_NOTIFICATION_CLICKED;
	} else {
		/*
		 * send GROWL_NOTIFICATION_TIMED_OUT instead, so that an application is
		 * guaranteed to receive feedback for every notification.
		 */
		suffix = GROWL_NOTIFICATION_TIMED_OUT;
	}
	NSNumber *pid = [userInfo objectForKey:GROWL_APP_PID];
	if (pid) {
		growlNotificationClickedName = [[NSString alloc] initWithFormat:@"%@-%@-%@",
			appName, pid, suffix];
	} else {
		growlNotificationClickedName = [[NSString alloc] initWithFormat:@"%@%@",
			appName, suffix];
	}
	clickInfo = [[NSDictionary alloc] initWithObjectsAndKeys:
		[userInfo objectForKey:GROWL_KEY_CLICKED_CONTEXT], GROWL_KEY_CLICKED_CONTEXT,
		nil];

	[[NSDistributedNotificationCenter defaultCenter] postNotificationName:growlNotificationClickedName
																   object:nil
																 userInfo:clickInfo
													   deliverImmediately:YES];

	[clickInfo release];
	[growlNotificationClickedName release];
}

- (void) notificationTimedOut:(NSNotification *)notification {
	NSString *appName, *growlNotificationTimedOutName;
	NSDictionary *clickInfo;
	NSDictionary *userInfo;

	userInfo = [notification userInfo];

	//Build the application-specific notification name
	appName = [notification object];
	NSNumber *pid = [userInfo objectForKey:GROWL_APP_PID];
	if (pid) {
		growlNotificationTimedOutName = [[NSString alloc] initWithFormat:@"%@-%@-%@",
			appName, pid, GROWL_NOTIFICATION_TIMED_OUT];
	} else {
		growlNotificationTimedOutName = [[NSString alloc] initWithFormat:@"%@%@",
			appName, GROWL_NOTIFICATION_TIMED_OUT];
	}
	clickInfo = [[NSDictionary alloc] initWithObjectsAndKeys:
		[userInfo objectForKey:GROWL_KEY_CLICKED_CONTEXT], GROWL_KEY_CLICKED_CONTEXT,
		nil];

	[[NSDistributedNotificationCenter defaultCenter] postNotificationName:growlNotificationTimedOutName
																   object:nil
																 userInfo:clickInfo
													   deliverImmediately:YES];

	[clickInfo release];
	[growlNotificationTimedOutName release];
}

@end
