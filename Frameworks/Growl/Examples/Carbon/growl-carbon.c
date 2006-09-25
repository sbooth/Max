/*
 *	growl-carbon.c: An example using the Growl Carbon API.
 *		This example registers 2 types of notifications with Growl, of
 *		which one enabled by default. Then, it emits both notifications.
 *
 *	Compile with :
 *		gcc -W -Wall -framework CoreFoundation -framework Growl growl-carbon.c -o growl-carbon
 *
 *	Remko Troncon <remko@psi-im.org>
 */

#include <CoreFoundation/CoreFoundation.h>
#include <Growl/GrowlApplicationBridge-Carbon.h>
#include <Growl/GrowlDefines.h>
#include <stdlib.h>

static void growlNotificationWasClicked(CFPropertyListRef clickContext) {
	printf("Notification was clicked, clickContext=%p\n", clickContext);
	exit(EXIT_SUCCESS);
}

static void growlNotificationTimedOut(CFPropertyListRef clickContext) {
	printf("Notification timed out, clickContext=%p\n", clickContext);
	exit(EXIT_SUCCESS);
}

int main() {
	// ******************** Registration  ********************

	// Create & fill the array containing the notifications
	CFMutableArrayRef allNotifications = CFArrayCreateMutable(
															kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks);
	CFArrayAppendValue(allNotifications, CFSTR("Notification 1"));
	CFArrayAppendValue(allNotifications, CFSTR("Notification 2"));

	// Create & fill the array containing the notifications that are turned
	// on by default.
	CFMutableArrayRef defaultNotifications = CFArrayCreateMutable(
																  kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks);
	CFArrayAppendValue(defaultNotifications, CFSTR("Notification 2"));

	// Initialize the delegate
	struct Growl_Delegate delegate;
	InitGrowlDelegate(&delegate);
	delegate.applicationName = CFSTR("MyFirstGrowlApp");

	// Fill in the dictionary in the delegate
	CFTypeRef keys[] = { GROWL_NOTIFICATIONS_ALL, GROWL_NOTIFICATIONS_DEFAULT };
	CFTypeRef values[] = { allNotifications, defaultNotifications };
	delegate.registrationDictionary = CFDictionaryCreate(
														 kCFAllocatorDefault, keys, values, 2,
														 &kCFTypeDictionaryKeyCallBacks,
														 &kCFTypeDictionaryValueCallBacks);

	delegate.growlNotificationWasClicked = growlNotificationWasClicked;
	delegate.growlNotificationTimedOut = growlNotificationTimedOut;

	// Register with Growl
	if (!Growl_SetDelegate(&delegate)) {
		printf("Delegate registration failed !\n");
		return -1;
	}

	// ******************** Notification ********************

	// Show notification 1. This notification is not showed by default, you
	// have to enable it in the Growl preferences.
	Growl_NotifyWithTitleDescriptionNameIconPriorityStickyClickContext(
																	   CFSTR("My title 1"), CFSTR("My description 1"), CFSTR("Notification 1"),
																	   0, 0, false, CFSTR("clickMe"));

	// Show notification 2, and make it sticky.
	Growl_NotifyWithTitleDescriptionNameIconPriorityStickyClickContext(
																	   CFSTR("My title 2"), CFSTR("My description 2"), CFSTR("Notification 2"),
																	   0, 0, true, CFSTR("clickMe"));

	// Uncomment the following line if the application should wait for clicked or timedOut notifications
	//CFRunLoopRun();

	return EXIT_SUCCESS;
}
