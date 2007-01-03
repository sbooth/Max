//
//  GrowlLog.m
//  Growl
//
//  Created by Ingmar Stein on 17.04.05.
//  Copyright 2004-2005 The Growl Project. All rights reserved.
//

#import "GrowlLog.h"
#import "GrowlPreferences.h"
#import "GrowlDefines.h"

@implementation GrowlLog
+ (void) _performLog:(NSString *)message {
	GrowlPreferences *preferences = [GrowlPreferences preferences];

	int typePref = [preferences integerForKey:GrowlLogTypeKey];
	if (typePref == 0) {
		NSLog(@"%@", message);
	} else {
		BOOL written = NO;
		NSString *logFile = [preferences objectForKey:GrowlCustomHistKey1];
		NSFileManager *fileManager = [NSFileManager defaultManager];
		if (![fileManager fileExistsAtPath:logFile])
			[fileManager createFileAtPath:logFile contents:nil attributes:nil];
		NSFileHandle *logHandle = [NSFileHandle fileHandleForWritingAtPath:logFile];
		if (logHandle) {
			[logHandle seekToEndOfFile];
			[logHandle writeData:[[message stringByAppendingString:@"\n"] dataUsingEncoding:NSUTF8StringEncoding]];
			[logHandle closeFile];
			written = YES;
		}
		if (!written) {
			// Falling back to NSLogging...
			if (logFile) {
				NSLog(@"Failed to write notification to file %@", logFile);
			}
			NSLog(@"%@", message);
		}
	}	
}

+ (void) log:(NSString *)message {
	GrowlPreferences *preferences = [GrowlPreferences preferences];
	if (![preferences boolForKey:GrowlLoggingEnabledKey]) {
		return;
	}

	[self _performLog:message];
}

+ (void) logNotificationDictionary:(NSDictionary *)noteDict {
	GrowlPreferences *preferences = [GrowlPreferences preferences];
	if (![preferences boolForKey:GrowlLoggingEnabledKey]) {
		return;
	}
	
	NSString *logString = [[NSString alloc] initWithFormat:@"%@ %@: %@ (%@) - Priority %d",
		[NSDate date],
		[noteDict objectForKey:GROWL_APP_NAME],
		[noteDict objectForKey:GROWL_NOTIFICATION_TITLE],
		[noteDict objectForKey:GROWL_NOTIFICATION_DESCRIPTION],
		[[noteDict objectForKey:GROWL_NOTIFICATION_PRIORITY] intValue]];
	[self _performLog:logString];
	[logString release];
}

+ (void) logRegistrationDictionary:(NSDictionary *)regDict {
	GrowlPreferences *preferences = [GrowlPreferences preferences];
	if (![preferences boolForKey:GrowlLoggingEnabledKey]) {
		return;
	}

	NSString *logString = [[NSString alloc] initWithFormat:@"%@ %@ registered",
		[NSDate date],
		[regDict objectForKey:GROWL_APP_NAME]];
	[self _performLog:logString];
	[logString release];
}

@end
