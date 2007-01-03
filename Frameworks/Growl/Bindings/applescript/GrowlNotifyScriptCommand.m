//
//  GrowlNotifyScriptCommand.m
//  Growl
//
//  Created by Patrick Linskey on Tue Aug 10 2004.
//  Copyright (c) 2004 Patrick Linskey. All rights reserved.
//

/*
 *  To do:
 *		- change the name of GrowlHelperApp to just Growl, so you can 'tell application "Growl"'
 */

/*
 *  Some sample scripts:
 *	tell application "GrowlHelperApp"
 *		notify with title "test" description "test description" icon of application "Mail.app"
 *	end tell
 *
 *	tell application "GrowlHelperApp"
 *		notify with title "test" description "test description" icon of file "file:///Applications" sticky yes
 *	end tell
 */

#import "GrowlNotifyScriptCommand.h"
#import "GrowlController.h"
#import "GrowlDefines.h"
#import "NSWorkspaceAdditions.h"

#define KEY_TITLE				@"title"
#define KEY_DESC				@"description"
#define KEY_STICKY				@"sticky"
#define KEY_PRIORITY			@"priority"
#define KEY_IMAGE_URL			@"imageFromURL"
#define KEY_ICON_APP_NAME		@"iconOfApplication"
#define KEY_ICON_FILE			@"iconOfFile"
#define KEY_IMAGE				@"image"
#define KEY_PICTURE				@"pictImage"
#define KEY_APP_NAME			@"appName"
#define KEY_NOTIFICATION_NAME	@"notificationName"

#define ERROR_EXCEPTION								1
#define ERROR_NOT_FILE_URL							2
#define ERROR_ICON_OF_FILE_PATH_INVALID				3
#define ERROR_ICON_OF_FILE_PATH_FILE_MISSING		4
#define ERROR_ICON_OF_FILE_PATH_NOT_IMAGE			5
#define ERROR_ICON_OF_FILE_UNSUPPORTED_PROTOCOL		6

static const NSSize iconSize = { 128.0f, 128.0f };

@implementation GrowlNotifyScriptCommand

- (id) performDefaultImplementation {
	NSDictionary *args = [self evaluatedArguments];

	//should validate params better!
	NSString *title             = [args objectForKey:KEY_TITLE];
	NSString *desc              = [args objectForKey:KEY_DESC];
	NSNumber *sticky            = [args objectForKey:KEY_STICKY];
	NSNumber *priority          = [args objectForKey:KEY_PRIORITY];
	NSString *imageUrl          = [args objectForKey:KEY_IMAGE_URL];
	NSString *iconOfFile        = [args objectForKey:KEY_ICON_FILE];
	NSString *iconOfApplication = [args objectForKey:KEY_ICON_APP_NAME];
	NSData *imageData           = [args objectForKey:KEY_IMAGE];
	NSData *pictureData         = [args objectForKey:KEY_PICTURE];
	NSString *appName           = [args objectForKey:KEY_APP_NAME];
	NSString *notifName         = [args objectForKey:KEY_NOTIFICATION_NAME];

	NSMutableDictionary *noteDict = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
		appName,   GROWL_APP_NAME,
		notifName, GROWL_NOTIFICATION_NAME,
		title,     GROWL_NOTIFICATION_TITLE,
		desc,      GROWL_NOTIFICATION_DESCRIPTION,
		nil];

	if (priority)
		[noteDict setObject:priority forKey:GROWL_NOTIFICATION_PRIORITY];

	if (sticky)
		[noteDict setObject:sticky   forKey:GROWL_NOTIFICATION_STICKY];

	NSAppleEventDescriptor *addrDesc = [[self appleEvent] attributeDescriptorForKeyword:keyAddressAttr];
	NSData *psnData = [[addrDesc coerceToDescriptorType:typeProcessSerialNumber] data];
	if (psnData) {
		pid_t pid;
		GetProcessPID([psnData bytes], &pid);
		NSNumber *pidNumber = [[NSNumber alloc] initWithInt:pid];
		[noteDict setObject:pidNumber forKey:GROWL_APP_PID];
		[pidNumber release];
	}

	@try {
		NSImage *icon = nil;
		NSURL   *url = nil;

		//Command used the "image from URL" argument
		if (imageUrl) {
			if (!(url = [self fileUrlForLocationReference:imageUrl])) {
				return nil;
			}
			if (!(icon = [[[NSImage alloc] initWithContentsOfURL:url] autorelease])) {
				//File exists, but is not a valid image format
				[self setError:ERROR_ICON_OF_FILE_PATH_NOT_IMAGE];
				return nil;
			}
		} else if (iconOfFile) {
			//Command used the "icon of file" argument
			if (!(url = [self fileUrlForLocationReference: iconOfFile])) {
				//NSLog(@"That's a no go on that file's icon.");
				return nil;
			}
			icon = [[NSWorkspace sharedWorkspace] iconForFile:[url path]];
		} else if (iconOfApplication) {
			//Command used the "icon of application" argument
			icon = [[NSWorkspace sharedWorkspace] iconForApplication:iconOfApplication];
		} else if (imageData) {
			icon = [[[NSImage alloc] initWithData:imageData] autorelease];
		} else if (pictureData) {
			icon = [[[NSImage alloc] initWithData:pictureData] autorelease];
			[icon setScalesWhenResized: YES];
		}

		if (icon) {
			NSData *iconData;
			[icon setSize:iconSize];
			iconData = [icon TIFFRepresentation];
			if (iconData)
				[noteDict setObject:iconData forKey:GROWL_NOTIFICATION_ICON];
		}

		[[GrowlController standardController] dispatchNotificationWithDictionary:noteDict];
	} @catch(NSException *e) {
		NSLog(@"error processing AppleScript request: %@", e);
		[self setError:ERROR_EXCEPTION failure:e];
	}

	[noteDict release];

	return nil;
}

//This method will attempt to locate an image given either a path or an URL
- (NSURL *)fileUrlForLocationReference:(NSString *)imageReference {
	NSURL   *url = nil;

	NSRange testRange = [imageReference rangeOfString: @"://"];
	if (!(testRange.location == NSNotFound)) {
		//It looks like a protocol string
		if (![imageReference hasPrefix: @"file://"]) {
			//The protocol is not valid  - we only accept file:// URLs
			[self setError:ERROR_NOT_FILE_URL];
			return nil;
		}

		//it was a file URL that was passed
		url = [NSURL URLWithString: imageReference];
		//Check that it's properly encoded
		if (![url path]) {
			//Try encoding the path to fit URL specs
			url = [NSURL URLWithString: [imageReference stringByAddingPercentEscapesUsingEncoding: NSISOLatin1StringEncoding]];
			//Check it again
			if (![url path]) {
				//This path is just no good.
				[self setError:ERROR_ICON_OF_FILE_PATH_INVALID];
				return nil;
			}
		}
	} else {
		//it was an alias / path that was passed
		url = [NSURL fileURLWithPath:[imageReference stringByExpandingTildeInPath]];
		if (!url) {
			[self setError:ERROR_ICON_OF_FILE_PATH_INVALID];
			return nil;
		}
	}

	//Sanity check the URL
	if (![url isFileURL]) {
		//Bail - wrong protocol.
		[self setError:ERROR_NOT_FILE_URL];
		return nil;
	}
	if (!url) {
		[self setError:ERROR_ICON_OF_FILE_PATH_INVALID];
		return nil;
	}
	//Check to see if the file actually exists.
	if (![[NSFileManager defaultManager] fileExistsAtPath:[url path]]) {
		[self setError:ERROR_ICON_OF_FILE_PATH_FILE_MISSING];
		return nil;
	}
	return url;
}


- (void) setError:(int)errorCode {
	[self setError:errorCode failure:nil];
}

- (void)setError:(int)errorCode failure:(id)failure {
	[self setScriptErrorNumber:errorCode];
	NSString *str;

	switch (errorCode) {
		case ERROR_EXCEPTION:
			str = [NSString stringWithFormat:@"Exception raised while processing: %@", failure];
			break;
		case ERROR_NOT_FILE_URL:
			str = @"Non-File URL.  If passing a URL to growl as a parameter, it must be a 'file://' URL.";
			break;
		case ERROR_ICON_OF_FILE_PATH_FILE_MISSING:
			str = @"'image from URL' parameter - File specified does not exist.";
			break;
		case ERROR_ICON_OF_FILE_PATH_INVALID:
			str = @"'image from URL' parameter - Badly formed path.";
			break;
		case ERROR_ICON_OF_FILE_PATH_NOT_IMAGE:
			str = @"'image from URL' parameter - Supplied file is not a valid image type.";
			break;
		case ERROR_ICON_OF_FILE_UNSUPPORTED_PROTOCOL:
			str = @"'image from URL' parameter - Unsupported URL protocol. (Only 'file://' supported)";
			break;
		default:
			str = nil;
	}

	if (str)
		[self setScriptErrorString:str];
}

@end
