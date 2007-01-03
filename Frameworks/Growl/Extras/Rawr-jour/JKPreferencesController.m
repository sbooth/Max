//
//  JKPreferencesController.m
//  Rawr-endezvous
//
//  Created by Jeremy Knope on 9/17/04.
//  Copyright 2004 Jeremy Knope. All rights reserved.
//

#import "JKPreferencesController.h"
#import "JKMenuController.h"

@implementation JKPreferencesController
- (void) awakeFromNib {
	// *** Load service 'presets'
	NSString *dbPath;
	dbPath = [[NSBundle mainBundle] pathForResource:@"serviceDb" ofType:@"plist"];
	if (DEBUG)
		NSLog(@"Loading : %@", dbPath);
	NSDictionary *serviceList;
	serviceList = [[NSDictionary alloc] initWithContentsOfFile:dbPath];
	itemPresets = [[NSMutableDictionary alloc] initWithCapacity:[serviceList count]];
	NSDictionary *myDict;
	NSEnumerator *myEnum;
	myEnum = [[serviceList objectForKey:@"services"] objectEnumerator];
	while ((myDict = [myEnum nextObject])) {
		//if (DEBUG)
		//	NSLog(@"Loopdaloop %@",[myDict objectForKey:@"service"]);
		NSMenuItem *newItem = [[NSMenuItem alloc] init];
		[newItem setTitle:[myDict objectForKey:@"name"]];
		[newItem setTarget:self];
		[newItem setAction:@selector(addPreset:)];
		[[servicePopUp menu] insertItem:newItem atIndex:[[servicePopUp menu] numberOfItems]];
		[itemPresets setObject:myDict forKey:[newItem title]];
	}
	[serviceList release];
	//services = [[NSMutableArray alloc] init];
	//services = [NSMutableArray arrayWithObjects:@"_http._tcp.",@"_ssh._tcp.",@"_ftp._tcp.",nil];
	//NSLog(@"Number of services %i",[services count]);
	//serviceNames = [NSMutableArray arrayWithObjects:@"http",@"ssh",@"ftp",nil];
	//NSMutableDictionary *myServices = [[NSMutableDictionary alloc] init];
	//prefs = [[NSMutableDictionary alloc] init];
	//NSArray *mServices = [NSArray arrayWithObjects:[NSDictionary
	//[services retain];
	//[serviceNames retain];
	//tableData = [[NSMutableDictionary alloc] init];
	//[tableData setObject:services forKey:@"services"];
	//[tableData setObject:serviceNames forKey:@"serviceNames"];
	//[self openPrefs];
	[removeServiceButton setEnabled:NO];
	[serviceTable setTarget:self];
	[serviceTable setAction:@selector(tableClick)];
	[serviceTable reloadData];
	showStatusMenuItem = YES;
}

- (void) openPrefs {
	if (DEBUG)
		NSLog(@"PrefsController:: Opening prefs");
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	if (![defaults arrayForKey:@"services"]) { // if nothing, set our default prefs, should clean this
		// set defaults
		//NSLog(@"PrefsController:: Setting default pref settings");
		NSMutableDictionary *mySsh = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
			@"_ssh._tcp.", @"service",
			@"ssh",        @"protocol",
			@"SSH",        @"name",
			nil];
		NSMutableDictionary *myAfp = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
			@"_afpovertcp._tcp.",  @"service",
			@"afp",                @"protocol",
			@"Apple File Sharing", @"name",
			nil];
		NSMutableDictionary *myFtp = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
			@"_ftp._tcp.", @"service",
			@"ftp",        @"protocol",
			@"FTP",        @"name",
			nil];
		NSMutableDictionary *myHttp = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
			@"_http._tcp.", @"service",
			@"http",        @"protocol",
			@"Web",         @"name",
			nil];
		NSArray *myArray = [[NSArray alloc] initWithObjects:mySsh, myAfp, myFtp, myHttp, nil];
		[mySsh  release];
		[myAfp  release];
		[myFtp  release];
		[myHttp release];
		[defaults setObject:myArray forKey:@"services"];
		[myArray release];
		[defaults setBool:YES forKey:@"hideLocalhost"];
		[defaults setBool:YES forKey:@"showStatusMenuItem"];
	}
	// open
	//[services release];
	services = [[NSMutableArray alloc] initWithArray:[defaults arrayForKey:@"services"]];
	if ([defaults boolForKey:@"hideLocalhost"])
		[localHideCheck setState:NSOnState];
	else
		[localHideCheck setState:NSOffState];
	for (unsigned i=0; i<[services count]; ++i) {
		if (DEBUG)
			NSLog(@"PrefsController:: Changing %i into mutable dict",i);
		id myDict = [services objectAtIndex:i];
		[services replaceObjectAtIndex:i withObject:[myDict mutableCopy]];
	}
	showStatusMenuItem = [defaults boolForKey:@"showStatusMenuItem"];
	if (showStatusMenuItem)
		[showStatusMenuItemCheck setState:NSOnState];
	else
		[showStatusMenuItemCheck setState:NSOffState];
	[serviceTable reloadData];
}

- (void) savePrefs {
	//NSLog(@"Saving prefs");
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setObject:services forKey:@"services"];
	[defaults setBool:([localHideCheck state] == NSOnState) forKey:@"hideLocalhost"];
	if ([showStatusMenuItemCheck state] == NSOnState) {
		[defaults setBool:YES forKey:@"showStatusMenuItem"];
		showStatusMenuItem = YES;
	} else {
		[defaults setBool:NO forKey:@"showStatusMenuItem"];
		showStatusMenuItem = NO;
	}
	[main refreshServices:nil];
}

- (NSArray *) getServices {
	//NSLog(@"Sending services array %i",[services count]);
	return services;
}

- (BOOL) getShowStatusMenuItem {
	return showStatusMenuItem;
}

- (IBAction) addService:(id)sender {
#pragma unused(sender)
	//[[tableData objectForKey:@"services"] addObject:@"_????._tcp."];
	//[[tableData objectForKey:@"serviceNames"] addObject:@"????"];
	if (DEBUG)
		NSLog(@"PrefsController:: Add service clicked");
	NSMutableDictionary *temp = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
		@"_protocol._tcp.", @"service",
		@"protocol",        @"protocol",
		nil];
	[services addObject:temp];
	[serviceTable reloadData];
	[temp release];
}

- (IBAction) removeService:(id)sender {
#pragma unused(sender)
	//[[tableData objectForKey:@"services"] removeObjectAtIndex:[serviceTable selectedRow]];
	//[[tableData objectForKey:@"serviceNames"] removeObjectAtIndex:[serviceTable selectedRow]];
	if ([serviceTable selectedRow] >= 0)
		[services removeObjectAtIndex:[serviceTable selectedRow]];
	[serviceTable reloadData];
}

- (IBAction) addPreset:(id)sender {
	//int index;
	//index = [servicePopUp indexOfSelectedItem];
	BOOL found;
	found = NO;
	NSString *myStr;
	myStr = [[itemPresets objectForKey:[sender title]] objectForKey:@"service"];
	NSEnumerator *myEnum;
	myEnum = [services objectEnumerator];
	NSDictionary *myDict;
	while ((myDict = [myEnum nextObject])) {
		//NSLog(@"Checking for %@ in %@",myStr,[myDict objectForKey:@"service"]);
		if ([[myDict objectForKey:@"service"] isEqualToString:myStr]) {
			found = YES;
			break;
		}
	}
	if (!found) {
		NSDictionary *preset = [itemPresets objectForKey:[sender title]];
		NSMutableDictionary *temp = [preset mutableCopy];
		[services addObject:temp];
		[temp release];
		[serviceTable reloadData];
	}
}

- (IBAction) saveClicked:(id)sender {
#pragma unused(sender)
	[prefWindow orderOut:self];
	[self savePrefs];
}

- (IBAction) openPrefsWindow:(id)sender {
#pragma unused(sender)
	[self openPrefs];
	[prefWindow makeKeyAndOrderFront:nil];
}

- (IBAction) closePrefsWindow:(id)sender {
#pragma unused(sender)
	[prefWindow orderOut:nil];
}

// -------------- NSTableView data source ----------------
- (int) numberOfRowsInTableView:(NSTableView *)theTableView {
#pragma unused(theTableView)
	if (DEBUG)
		NSLog(@"Returning table row count: %i", [services count]);
	return [services count];
}

- (id) tableView:(NSTableView *)theTableView objectValueForTableColumn:(NSTableColumn *)theColumn row:(int)rowIndex {
#pragma unused(theTableView)
	if (DEBUG)
		NSLog(@"Returning row & col value: %@", [[services objectAtIndex:rowIndex] objectForKey:[theColumn identifier]]);
	return [[services objectAtIndex:rowIndex] objectForKey:[theColumn identifier]];
}

- (void) tableView:(NSTableView *)theTableView setObjectValue:anObject forTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex {
#pragma unused(theTableView)
	if (DEBUG)
		NSLog(@"PrefsController:: Setting %@ for %@", anObject, [aTableColumn identifier]);
	[[services objectAtIndex:rowIndex] setObject:anObject forKey:[aTableColumn identifier]];
}

- (void) tableClick {
	[removeServiceButton setEnabled:([serviceTable selectedRow] >= 0)];
}

@end
