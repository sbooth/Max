/*
 *  Beep-Carbon-Notifications.c
 *  Growl
 *
 *  Created by Mac-arena the Bored Zo on Fri Jun 11 2004.
 *  Public domain.
 *
 */

#include "Beep-Carbon-Notifications.h"

#include <syslog.h>
#include <stdarg.h>
extern void CFLog(int priority, CFStringRef format, ...);

static CFMutableArrayRef allNotifications = NULL;
static CFMutableArrayRef defaultNotifications = NULL;
//this is explicitly not static because main() needs it.
CFArrayCallBacks notificationCallbacks;

//callbacks.
static CFStringRef _CopyNameOfNotification(const void *notification); //copy description

struct Beep_Notification *CreateGrowlNotification(CFStringRef name, CFStringRef title, CFStringRef desc, int priority, CFDataRef imageData, Boolean isSticky, Boolean isDefault) {
	struct Beep_Notification *notification = malloc(sizeof(struct Beep_Notification));
	if(notification) {
		notification->growlNotification.size          = sizeof(struct Growl_Notification);
		notification->growlNotification.name          = name      ? CFRetain(name)      : name;
		notification->growlNotification.title         = title     ? CFRetain(title)     : title;
		notification->growlNotification.description   = desc      ? CFRetain(desc)      : desc;
		notification->growlNotification.priority      = priority;
		notification->growlNotification.iconData      = imageData ? CFRetain(imageData) : imageData;
		notification->growlNotification.reserved      = 0;
		notification->growlNotification.isSticky      = isSticky;
		notification->growlNotification.clickContext  = NULL;
		notification->growlNotification.clickCallback = NULL;
		notification->beepFlags.enabledByDefault      = isDefault;
	}
	return notification;
}

CFIndex AddNotificationToMasterList(struct Beep_Notification *notification) {
	CreateMasterListIfNecessary();
	CFIndex newIndex = CFArrayGetCount(allNotifications);
	CFArrayAppendValue(allNotifications, notification);
	if(notification->beepFlags.enabledByDefault)
		CFArrayAppendValue(defaultNotifications, notification);
	return newIndex;
}
void RemoveNotificationFromMasterList(struct Beep_Notification *notification) {
	if(allNotifications) {
		//IOW: [allNotifications removeObject:notification]
		CFArrayRemoveValueAtIndex(allNotifications, CFArrayGetFirstIndexOfValue(allNotifications, CFRangeMake(0, CFArrayGetCount(allNotifications)), notification));
	}
	if(defaultNotifications) {
		CFArrayRemoveValueAtIndex(defaultNotifications, CFArrayGetFirstIndexOfValue(defaultNotifications, CFRangeMake(0, CFArrayGetCount(defaultNotifications)), notification));
	}
}

struct Beep_Notification *GetNotificationAtIndex(CFIndex index) {
	struct Beep_Notification *notification = NULL;
	if(allNotifications)
		notification = (struct Beep_Notification *)CFArrayGetValueAtIndex(allNotifications, index);
	return notification;
}
void RemoveNotificationFromMasterListByIndex(CFIndex index) {
	if(allNotifications) {
		struct Beep_Notification *notification = (struct Beep_Notification *)CFArrayGetValueAtIndex(allNotifications, index);
		if(notification) {
			//also remove from default-notifications array.
			CFArrayRemoveValueAtIndex(defaultNotifications, CFArrayGetFirstIndexOfValue(defaultNotifications, CFRangeMake(0, CFArrayGetCount(defaultNotifications)), notification));

			CFArrayRemoveValueAtIndex(allNotifications, index);
		}
	}
}
CFIndex CountNotificationsInMasterList(void) {
	if(allNotifications)
		return CFArrayGetCount(allNotifications);
	else
		return 0;
}

void CreateMasterListIfNecessary(void) {
	if(allNotifications == NULL) {
		notificationCallbacks.version         = 0;
		notificationCallbacks.retain          = NULL;
		notificationCallbacks.release         = NULL;
		notificationCallbacks.copyDescription = _CopyNameOfNotification;
		notificationCallbacks.equal           = NULL;
		
		allNotifications = CFArrayCreateMutable(kCFAllocatorDefault, 0, &notificationCallbacks);
	}
	if(defaultNotifications == NULL) {
		notificationCallbacks.version         = 0;
		notificationCallbacks.retain          = NULL;
		notificationCallbacks.release         = NULL;
		notificationCallbacks.copyDescription = _CopyNameOfNotification;
		notificationCallbacks.equal           = NULL;
		
		defaultNotifications = CFArrayCreateMutable(kCFAllocatorDefault, 0, &notificationCallbacks);
	}
}
CFArrayRef GetMasterListAsCFArray(void) {
	CreateMasterListIfNecessary();
	return allNotifications;
}
CFArrayRef GetDefaultNotificationsListAsCFArray(void) {
	CreateMasterListIfNecessary();
	return defaultNotifications;
}

static CFArrayRef _CopyNotificationNamesFromArrayOfNotifications(CFArrayRef notifications) {
	CFIndex numValues = CFArrayGetCount(notifications);
	CFStringRef *values = malloc(numValues * sizeof(CFStringRef));
	CFArrayRef result = NULL;
	if(values) {
		for(CFIndex i = 0; i < numValues; ++i)
			values[i] = ((struct Beep_Notification *)CFArrayGetValueAtIndex(notifications, i))->growlNotification.name;
		/*I don't know why this cast is necessary.
		 *GCC says they're incompatible types.
		 *but at runtime, the behaviour is correct.
		 *--boredzo
		 */
		result = CFArrayCreate(kCFAllocatorDefault, (const void **)values, numValues, &kCFTypeArrayCallBacks);
		free(values);
	}
	return result;
}

void UpdateGrowlDelegate(struct Growl_Delegate *delegate) {
	if(!delegate)
		delegate = Growl_GetDelegate();
	if(delegate) {
		CFMutableDictionaryRef regDict = (CFMutableDictionaryRef)delegate->registrationDictionary;
		if(!regDict)
			delegate->registrationDictionary = regDict = CFDictionaryCreateMutable(kCFAllocatorDefault, /*capacity*/ 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);

		CFArrayRef array;

		array = _CopyNotificationNamesFromArrayOfNotifications(allNotifications);
		CFDictionarySetValue(regDict, GROWL_NOTIFICATIONS_ALL, array);
		CFRelease(array);

		array = _CopyNotificationNamesFromArrayOfNotifications(defaultNotifications);
		CFDictionarySetValue(regDict, GROWL_NOTIFICATIONS_DEFAULT, array);
		CFRelease(array);
	}
}

void DestroyMasterNotificationList(void) {
	if(allNotifications) {
		CFRelease(allNotifications);
		allNotifications = NULL;
	}
}

//callbacks.
static CFStringRef _CopyNameOfNotification(const void *notification) {
	const struct Beep_Notification *_notification = notification;
	return CFRetain(_notification->growlNotification.name);
}
