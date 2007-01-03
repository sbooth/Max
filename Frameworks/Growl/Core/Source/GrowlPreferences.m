//
//  GrowlPreferences.m
//  Growl
//
//  Created by Nelson Elhage on 8/24/04.
//  Copyright 2004-2005 The Growl Project. All rights reserved.
//
// This file is under the BSD License, refer to License.txt for details


#import "GrowlPreferences.h"
#import "NSURLAdditions.h"
#import "GrowlDefinesInternal.h"
#import "GrowlDefines.h"
#import "GrowlPathUtil.h"
#include <Carbon/Carbon.h>

@implementation GrowlPreferences

static GrowlPreferences *sharedPreferences;
static NSUserDefaults *helperAppDefaults = nil;

+ (void)initialize
{
	if (self == [GrowlPreferences class]) {
		[[NSDistributedNotificationCenter defaultCenter] addObserver:self
															selector:@selector(growlPreferencesChanged:)
																name:GrowlPreferencesChanged
															  object:nil];
		
		helperAppDefaults = [[NSUserDefaults alloc] init];
		[helperAppDefaults addSuiteNamed:HelperAppBundleIdentifier];
	}
}

+ (GrowlPreferences *) preferences {
	if (!sharedPreferences) {
		sharedPreferences = [[GrowlPreferences alloc] init];
	}
	return sharedPreferences;
}

- (id) init {
	if ((self = [super init])) {

	}
	return self;
}

- (void) dealloc {
	[super dealloc];
}

#pragma mark -

- (void) registerDefaults:(NSDictionary *)inDefaults {
	NSDictionary *existing = [helperAppDefaults persistentDomainForName:HelperAppBundleIdentifier];
	if (existing) {
		NSMutableDictionary *domain = [inDefaults mutableCopy];
		[domain addEntriesFromDictionary:existing];
		[helperAppDefaults setPersistentDomain:domain forName:HelperAppBundleIdentifier];
		[domain release];
	} else {
		[helperAppDefaults setPersistentDomain:inDefaults forName:HelperAppBundleIdentifier];
	}
}

- (id) objectForKey:(NSString *)key {
	return [helperAppDefaults objectForKey:key];
}

- (void) setObject:(id)object forKey:(NSString *)key {
	CFPreferencesSetAppValue((CFStringRef)key			/* key */,
							 (CFPropertyListRef)object /* value */,
							 (CFStringRef)HelperAppBundleIdentifier) /* application ID */;\

	CFPreferencesAppSynchronize((CFStringRef)HelperAppBundleIdentifier);

	NSNumber *pid = [[NSNumber alloc] initWithInt:[[NSProcessInfo processInfo] processIdentifier]];
	NSDictionary *userInfo = [[NSDictionary alloc] initWithObjectsAndKeys:pid, @"pid", nil];
	[pid release];
	[[NSDistributedNotificationCenter defaultCenter] postNotificationName:GrowlPreferencesChanged
																   object:key
																 userInfo:userInfo];
	[userInfo release];
}

- (BOOL) boolForKey:(NSString *)key {
	return [helperAppDefaults boolForKey:key];
}

- (void) setBool:(BOOL)value forKey:(NSString *)key {
	NSNumber *object = [[NSNumber alloc] initWithBool:value];
	[self setObject:object forKey:key];
	[object release];
}

- (int) integerForKey:(NSString *)key {
	return [helperAppDefaults integerForKey:key];
}

- (void) setInteger:(int)value forKey:(NSString *)key {
	NSNumber *object = [[NSNumber alloc] initWithInt:value];
	[self setObject:object forKey:key];
	[object release];
}

- (float) floatForKey:(NSString *)key {
	return [helperAppDefaults floatForKey:key];
}

- (void) setFloat:(float)value forKey:(NSString *)key {
	NSNumber *object = [[NSNumber alloc] initWithFloat:value];
	[self setObject:object forKey:key];
	[object release];
}

#pragma mark -
#pragma mark Start-at-login control

- (BOOL) startGrowlAtLogin {
	NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
	NSArray        *loginItems = [[defs persistentDomainForName:@"loginwindow"] objectForKey:@"AutoLaunchedApplicationDictionary"];

	//get the prefpane bundle and find GHA within it.
	NSString *pathToGHA      = [[NSBundle bundleForClass:[GrowlPreferences class]] pathForResource:@"GrowlHelperApp" ofType:@"app"];
	//get an Alias (as in Alias Manager) representation of same.
	NSURL    *urlToGHA       = [[NSURL alloc] initFileURLWithPath:pathToGHA];

	BOOL foundIt = NO;

	NSEnumerator *e = [loginItems objectEnumerator];
	NSDictionary *item;
	while ((item = [e nextObject])) {
		/*first compare by alias.
		 *we do this by converting to URL and comparing those.
		 */
		NSData *thisAliasData = [item objectForKey:@"AliasData"];
		if (thisAliasData) {
			NSURL *thisURL = [NSURL fileURLWithAliasData:thisAliasData];
			foundIt = [thisURL isEqual:urlToGHA];
		} else {
			//nope, not the same alias. try comparing by path.
			NSString *thisPath = [[item objectForKey:@"Path"] stringByExpandingTildeInPath];
			foundIt = (thisPath && [thisPath isEqualToString:pathToGHA]);
		}

		if (foundIt)
			break;
	}
	[urlToGHA release];

	return foundIt;
}

- (void) setStartGrowlAtLogin:(BOOL)flag {
	//get the prefpane bundle and find GHA within it.
	NSString *pathToGHA = [[NSBundle bundleForClass:[GrowlPreferences class]] pathForResource:@"GrowlHelperApp" ofType:@"app"];
	[self setStartAtLogin:pathToGHA enabled:flag];
}

- (void) setStartAtLogin:(NSString *)path enabled:(BOOL)flag {
	NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];

	//get an Alias (as in Alias Manager) representation of same.
	NSURL    *url       = [[NSURL alloc] initFileURLWithPath:path];
	NSData   *aliasData = [url aliasData];

	/*the start-at-login pref is an array of dictionaries, like so:
	 *	{
	 *		AliasData = <...>
	 *		Hide = Boolean (maps to kLSLaunchAndHide)
	 *		Path = POSIX path to the bundle, file, or folder (in that order of
	 *			preference)
	 *	}
	 */
	NSMutableDictionary *loginWindowPrefs = [[defs persistentDomainForName:@"loginwindow"] mutableCopy];
	if (!loginWindowPrefs)
		loginWindowPrefs = [[NSMutableDictionary alloc] initWithCapacity:1U];

	NSMutableArray      *loginItems = [[loginWindowPrefs objectForKey:@"AutoLaunchedApplicationDictionary"] mutableCopy];
	if (!loginItems)
		loginItems = [[NSMutableArray alloc] initWithCapacity:1U];

	/*remove any previous mentions of this GHA in the start-at-login array.
	 *note that other GHAs are ignored.
	 */
	BOOL foundOne = NO;

	for (unsigned i = 0U, numItems = [loginItems count]; i < numItems; ) {
		NSDictionary *item = [loginItems objectAtIndex:i];
		BOOL thisIsUs = NO;

		/*first compare by alias.
		 *we do this by converting to URL and comparing those.
		 */
		NSString *thisPath = [[item objectForKey:@"Path"] stringByExpandingTildeInPath];
		NSData *thisAliasData = [item objectForKey:@"AliasData"];
		if (thisAliasData) {
			NSURL *thisURL = [NSURL fileURLWithAliasData:thisAliasData];
			thisIsUs = [thisURL isEqual:url];
		} else {
			//nope, not the same alias. try comparing by path.
			/*NSString **/thisPath = [[item objectForKey:@"Path"] stringByExpandingTildeInPath];
			thisIsUs = (thisPath && [thisPath isEqualToString:path]);
		}

		if (thisIsUs && ((!flag) || (!foundOne))) {
			[loginItems removeObjectAtIndex:i];
			--numItems;
			foundOne = YES;
		} else //only increment if we did not change the array
			++i;
	}
	[url release];

	if (flag) {
		NSNumber *hide = [[NSNumber alloc] initWithBool:NO];
		NSDictionary *launchDict = [[NSDictionary alloc] initWithObjectsAndKeys:
			hide,      @"Hide",
			path,      @"Path",
			aliasData, @"AliasData",
			nil];
		[hide release];
		[loginItems insertObject:launchDict atIndex:0U];
		[launchDict release];
	}

	//save to disk.
	[loginWindowPrefs setObject:loginItems
						 forKey:@"AutoLaunchedApplicationDictionary"];
	[loginItems release];
	[defs setPersistentDomain:loginWindowPrefs forName:@"loginwindow"];
	[loginWindowPrefs release];
	[defs synchronize];
}

#pragma mark -
#pragma mark Growl running state

- (void) setGrowlRunning:(BOOL)flag noMatterWhat:(BOOL)nmw {
	// Store the desired running-state of the helper app for use by GHA.
	[self setBool:flag forKey:GrowlEnabledKey];

	//now launch or terminate as appropriate.
	if (flag)
		[self launchGrowl:nmw];
	else
		[self terminateGrowl];
}

- (BOOL) isRunning:(NSString *)theBundleIdentifier {
	BOOL isRunning = NO;
	ProcessSerialNumber PSN = { kNoProcess, kNoProcess };

	while (GetNextProcess(&PSN) == noErr) {
		NSDictionary *infoDict = (NSDictionary *)ProcessInformationCopyDictionary(&PSN, kProcessDictionaryIncludeAllInformationMask);
		NSString *bundleID = [infoDict objectForKey:(NSString *)kCFBundleIdentifierKey];
		isRunning = bundleID && [bundleID isEqualToString:theBundleIdentifier];
		[infoDict release];

		if (isRunning)
			break;
	}

	return isRunning;
}

- (BOOL) isGrowlRunning {
	return [self isRunning:@"com.Growl.GrowlHelperApp"];
}

- (void) launchGrowl:(BOOL)noMatterWhat {
	NSString *helperPath = [[GrowlPathUtil helperAppBundle] bundlePath];

	// We want to launch in background, so we have to resort to Carbon
	LSLaunchFSRefSpec spec;
	FSRef appRef;
	OSStatus status = FSPathMakeRef((const UInt8 *)[helperPath fileSystemRepresentation], &appRef, NULL);

	if (status == noErr) {
		spec.appRef = &appRef;
		spec.numDocs = 0U;
		spec.itemRefs = NULL;
		spec.passThruParams = NULL;
		spec.launchFlags = kLSLaunchNoParams | kLSLaunchAsync | kLSLaunchDontSwitch;
		if (noMatterWhat)
			spec.launchFlags = spec.launchFlags | kLSLaunchNewInstance;
		spec.asyncRefCon = NULL;
		LSOpenFromRefSpec(&spec, NULL);
	}
}

- (void) terminateGrowl {
	// Ask the Growl Helper App to shutdown via the DNC
	[[NSDistributedNotificationCenter defaultCenter] postNotificationName:GROWL_SHUTDOWN object:nil];
}

#pragma mark -
/*
 * @brief Growl preferences changed
 *
 * Synchronize our NSUserDefaults to immediately get any changes from the disk
 */
+ (void)growlPreferencesChanged:(NSNotification *)notification
{
	[helperAppDefaults synchronize];
	SYNCHRONIZE_GROWL_PREFS();
	
	//Now that we've synchronized, repost the notification locally so any other class doing preference observing can update
	[[NSNotificationCenter defaultCenter] postNotification:notification];
}

@end
