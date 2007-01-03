/*
 *  Beep-Carbon-Notifications.h
 *  Growl
 *
 *  Created by Mac-arena the Bored Zo on Fri Jun 11 2004.
 *  Public domain.
 *
 */

#include <Carbon/Carbon.h>
#include <Growl/Growl.h>

struct Beep_Notification {
	struct Growl_Notification growlNotification;
	struct {
		unsigned reserved: 31;
		unsigned enabledByDefault: 1;
	} beepFlags;
};

//as of Growl 0.6, this function actually creates both lists.
void CreateMasterListIfNecessary(void);
CFArrayRef GetMasterListAsCFArray(void);
CFArrayRef GetDefaultNotificationsListAsCFArray(void);

/*copies the names of all notifications in the master and default lists
 *	to the relevant arrays in the registration dictionary of the given Growl
 *	delegate (or the current one).
 *does not reregister.
 */
void UpdateGrowlDelegate(struct Growl_Delegate *delegate);

struct Beep_Notification *CreateGrowlNotification(CFStringRef name, CFStringRef title, CFStringRef desc, int priority, CFDataRef imageData, Boolean isSticky, Boolean isDefault);

CFIndex AddNotificationToMasterList(struct Beep_Notification *notification);
void RemoveNotificationFromMasterList(struct Beep_Notification *notification);

struct Beep_Notification *GetNotificationAtIndex(CFIndex index);

void RemoveNotificationFromMasterListByIndex(CFIndex index);
CFIndex CountNotificationsInMasterList(void);
