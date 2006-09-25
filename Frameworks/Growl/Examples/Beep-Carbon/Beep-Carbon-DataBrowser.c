/*
 *  Beep-Carbon-DataBrowser.c
 *  Growl
 *
 *  Created by Mac-arena the Bored Zo on Fri Jun 11 2004.
 *  Public domain.
 *
 */

#include "Beep-Carbon-DataBrowser.h"
#include "Beep-Carbon-Notifications.h"

#include <syslog.h>
#include <stdarg.h>
extern void CFLog(int priority, CFStringRef format, ...);

static OSStatus dataBrowserItemData(ControlRef db, DataBrowserItemID item, DataBrowserPropertyID property, DataBrowserItemDataRef itemData, Boolean setValue);
static OSStatus dataBrowserNotification(ControlRef db, DataBrowserItemID item, DataBrowserItemNotification message);

OSStatus SetUpDataBrowser(WindowRef window, UInt32 controlIDnum) {
	OSStatus err = noErr;
	
	ControlID controlID = { appSignature, controlIDnum };
	ControlRef control;

	err = GetControlByID(window, &controlID, &control);
	
	if(err == noErr) {
		/*set the width of the column to be the width of the browser.
		 *(this overshoots slightly, but since we only have one column, this
		 *	isn't a problem.)
		 *we use HIView because it gives us the width and height; Control Mgr
		 *	just gives us the four corners, leaving us to compute the width
		 *	ourselves.
		 */
		HIRect bounds;
		HIViewGetFrame((HIViewRef)control, &bounds);

		SetDataBrowserTableViewNamedColumnWidth(control, dataBrowserNotificationNameProperty, bounds.size.width);

		//set up us the callbacks.
		DataBrowserCallbacks dbcb;
		dbcb.version = 0;
		InitDataBrowserCallbacks(&dbcb);

		dbcb.u.v1.itemDataCallback = NewDataBrowserItemDataUPP(dataBrowserItemData);
		dbcb.u.v1.itemNotificationCallback = NewDataBrowserItemNotificationUPP((DataBrowserItemNotificationProcPtr)dataBrowserNotification);

		err = SetDataBrowserCallbacks(control, &dbcb);
	}
	
	return err;
}

static OSStatus dataBrowserItemData(ControlRef db, DataBrowserItemID item, DataBrowserPropertyID property, DataBrowserItemDataRef itemData, Boolean setValue) {
	OSStatus err = noErr;

	switch(property) {
		case dataBrowserNotificationNameProperty:;
			struct Beep_Notification *notification = GetNotificationAtIndex((CFIndex)item - 1);
			err = SetDataBrowserItemDataText(itemData, notification->growlNotification.title);
			break;

		case kDataBrowserItemIsActiveProperty:
			err = SetDataBrowserItemDataBooleanValue(itemData, true);
			break;
		case kDataBrowserItemIsSelectableProperty:
			err = SetDataBrowserItemDataBooleanValue(itemData, true);
			break;
		case kDataBrowserItemIsEditableProperty:
			err = SetDataBrowserItemDataBooleanValue(itemData, false);
			break;
		case kDataBrowserItemIsContainerProperty:
			err = SetDataBrowserItemDataBooleanValue(itemData, false);
			break;
		/*XXX - should add editing support to match Beep-Cocoa
		 *do this by allowing opening, and when the item is 'opened', run
		 *	the edit sheet.
		 */
		case kDataBrowserContainerIsOpenableProperty:
			err = SetDataBrowserItemDataBooleanValue(itemData, false);
			break;
		case kDataBrowserContainerIsClosableProperty:
			err = SetDataBrowserItemDataBooleanValue(itemData, false);
			break;
		case kDataBrowserContainerIsSortableProperty:
			err = SetDataBrowserItemDataBooleanValue(itemData, true);
			break;
		case kDataBrowserItemParentContainerProperty:
			err = SetDataBrowserItemDataItemID(itemData, kDataBrowserNoItem);
			break;

		default:
			err = errDataBrowserPropertyNotSupported;
	}

	return err;
}

static OSStatus dataBrowserNotification(ControlRef db, DataBrowserItemID item, DataBrowserItemNotification message) {
	OSStatus err = noErr;

	DataBrowserItemID selStart, selEnd;
	switch(message) {
		case kDataBrowserSelectionSetChanged:
			err = GetDataBrowserSelectionAnchor(db, &selStart, &selEnd);
			if(err == noErr) {
				Boolean isSelection = (selStart != kDataBrowserNoItem && selEnd != kDataBrowserNoItem);
				err = updateSendEnabledState(isSelection);
				OSStatus err2 = updateDeleteEnabledState(isSelection);
				if(err == noErr) err = err2;
			}
			break;
	}
	return err;
}
