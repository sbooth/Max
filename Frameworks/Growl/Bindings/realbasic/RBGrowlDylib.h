/*
 *  Beep-Carbon-Notifications.h
 *  Growl
 *
 *  Created by Mac-arena the Bored Zo on Fri Jun 11 2004.
 *  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
 *
 */

#include <Carbon/Carbon.h>
#include "GrowlDefines.h"

struct CFnotification {
    CFStringRef title;
    CFStringRef desc;
    //	CGImageRef  image;
    CFDataRef   imageData;
    CFMutableDictionaryRef userInfo;
    CFIndex     refCount;
    struct {
        unsigned reserved  :31;
        unsigned isDefault :1;
    } flags;
};

struct CFnotification *CreateCFNotification(CFStringRef title, CFStringRef desc, CFDataRef imageData, Boolean isDefault);
struct CFnotification *RetainCFNotification(struct CFnotification *notification);
void ReleaseCFNotification(struct CFnotification *notification);

void PostCFNotification(CFNotificationCenterRef notificationCenter, struct CFnotification *notification, Boolean deliverImmediately);

void AddCFNotificationToMasterList(struct CFnotification *notification);
void RemoveCFNotificationFromMasterList(struct CFnotification *notification);

struct CFnotification *CopyCFNotificationByIndex(CFIndex index);
void RemoveCFNotificationFromMasterListByIndex(CFIndex index);
CFIndex CountCFNotificationsInMasterList(void);

void UpdateCFNotificationUserInfoForGrowl(struct CFnotification *notification);
