/*
 *  Beep-Carbon-Notifications.c
 *  Growl
 *
 *  Created by Mac-arena the Bored Zo on Fri Jun 11 2004.
 *  Adapted for the RB dynamic library by Xpander
 *  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
 *
 */

#include "RBGrowlDylib.h"

#include <syslog.h>
#include <stdarg.h>
extern void CFLog(int priority, CFStringRef format, ...);

static CFMutableArrayRef notifications = NULL;
CFArrayCallBacks notificationCallbacks;

static inline void CreateMasterListIfNecessary(void);

//callbacks.
static const void  *_RetainCFNotification   (CFAllocatorRef allocator, const void *notification);
static void         _ReleaseCFNotification  (CFAllocatorRef allocator, const void *notification);
static CFStringRef  _CopyTitleOfNotification(const void *notification); //copy description

struct CFnotification *CreateCFNotification(CFStringRef title, CFStringRef desc, CFDataRef imageData, Boolean isDefault) {
    struct CFnotification *notification = malloc(sizeof(struct CFnotification));
    if(notification) {
        notification->title =              title     ? CFRetain(title)     : title;
        notification->desc  =              desc      ? CFRetain(desc)      : desc;
        notification->imageData =          imageData ? CFRetain(imageData) : imageData;
        notification->userInfo = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        notification->refCount = 1; //because this was Created
        notification->flags.reserved  = 0;
        notification->flags.isDefault = isDefault;
    }
    return notification;
}

struct CFnotification *RetainCFNotification(struct CFnotification *notification) {
    if(notification)
        ++(notification->refCount);
    return notification;
}
void ReleaseCFNotification(struct CFnotification *notification) {
    if(notification) {
        if(--(notification->refCount) == 0) {
            if(notification->title)     CFRelease(notification->title);
            if(notification->desc)      CFRelease(notification->desc);
            if(notification->imageData) CFRelease(notification->imageData);
            if(notification->userInfo)  CFRelease(notification->userInfo);
            free(notification);
        }
    }
}

void PostCFNotification(CFNotificationCenterRef notificationCenter, struct CFnotification *notification, Boolean deliverImmediately) {
    notificationCenter = (CFNotificationCenterRef)CFRetain(notificationCenter);
    notification = RetainCFNotification(notification);
    
    if(notificationCenter && notification) {
#ifdef DEBUG
        CFLog(LOG_DEBUG, CFSTR("Posting a notification!\n"
                               "\ttitle: @\"%@\"\n"
                               "\tuserInfo: %@\n"
                               "\tdeliverImmediately: %hhu"),
              notification->title, notification->userInfo, deliverImmediately);
#endif
        CFNotificationCenterPostNotification(notificationCenter, notification->title, /*object*/ NULL, notification->userInfo, deliverImmediately);
    }
    
    CFRelease(notificationCenter);
    ReleaseCFNotification(notification);
}

void AddCFNotificationToMasterList(struct CFnotification *notification) {
    CreateMasterListIfNecessary();
    CFArrayAppendValue(notifications, notification);
}
void RemoveCFNotificationFromMasterList(struct CFnotification *notification) {
    if(notifications) {
        //IOW: [notifications removeObject:notification]
        CFArrayRemoveValueAtIndex(notifications, CFArrayGetFirstIndexOfValue(notifications, CFRangeMake(0, CFArrayGetCount(notifications)), notification));
    }
}

struct CFnotification *CopyCFNotificationByIndex(CFIndex index) {
    struct CFnotification *notification = NULL;
    if(notifications)
        notification = RetainCFNotification((struct CFnotification *)CFArrayGetValueAtIndex(notifications, index));
    return notification;
}
void RemoveCFNotificationFromMasterListByIndex(CFIndex index) {
    if(notifications)
        CFArrayRemoveValueAtIndex(notifications, index);
}
CFIndex CountCFNotificationsInMasterList(void) {
    if(notifications)
        return CFArrayGetCount(notifications);
    else
        return 0;
}

static inline void CreateMasterListIfNecessary(void) {
    if(notifications == NULL) {
        notificationCallbacks.version         = 0;
        notificationCallbacks.retain          = _RetainCFNotification;
        notificationCallbacks.release         = _ReleaseCFNotification;
        notificationCallbacks.copyDescription = _CopyTitleOfNotification;
        notificationCallbacks.equal           = NULL;
        
        notifications = CFArrayCreateMutable(kCFAllocatorDefault, 0, &notificationCallbacks);
    }
}

void UpdateCFNotificationUserInfoForGrowl(struct CFnotification *notification) {
    if(notification) {
        //if the userInfo dictionary doesn't exist, we're screwed.
        //we could try to create it... but then we either duplicate code,
        //  squander a function call, or trust in the inline keyword.
        
        //get the app name from our localised Info.plist.
        CFStringRef appName = CFDictionaryGetValue(CFBundleGetLocalInfoDictionary(CFBundleGetMainBundle()), CFSTR("CFBundleName"));
        if(appName == NULL) appName = CFSTR("Beep-Carbon");
        
        CFDictionarySetValue(notification->userInfo, GROWL_APP_NAME, appName);
        
        if(notification->title)
            CFDictionarySetValue(notification->userInfo, GROWL_NOTIFICATION_TITLE, notification->title);
        else
            CFDictionaryRemoveValue(notification->userInfo, GROWL_NOTIFICATION_TITLE);
        
        if(notification->desc)
            CFDictionarySetValue(notification->userInfo, GROWL_NOTIFICATION_DESCRIPTION, notification->desc);
        else
            CFDictionaryRemoveValue(notification->userInfo, GROWL_NOTIFICATION_DESCRIPTION);
        
        if(notification->imageData)
            CFDictionarySetValue(notification->userInfo, GROWL_NOTIFICATION_ICON, notification->imageData);
        else
            CFDictionaryRemoveValue(notification->userInfo, GROWL_NOTIFICATION_ICON);
    }
}

void DestroyMasterNotificationList(void) {
    if(notifications) CFRelease(notifications);
}

//callbacks.
static const void *_RetainCFNotification(CFAllocatorRef allocator, const void *notification) {
    struct CFnotification *_notification = (struct CFnotification *)notification;
    return RetainCFNotification(_notification);
}
static void _ReleaseCFNotification(CFAllocatorRef allocator, const void *notification) {
    struct CFnotification *_notification = (struct CFnotification *)notification;
    ReleaseCFNotification(_notification);
}
static CFStringRef _CopyTitleOfNotification(const void *notification) {
    const struct CFnotification *_notification = notification;
    return CFRetain(_notification->title);
}
