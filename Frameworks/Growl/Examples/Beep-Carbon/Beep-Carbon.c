/*
 *	Beep-Carbon.c
 *	Growl
 *
 *	Created by Mac-arena the Bored Zo on Fri Jun 11 2004.
 *	Public domain.
 *
 */

#include "Beep-Carbon.h"
#include "Beep-Carbon-Helpers.h"
#include "Beep-Carbon-DataBrowser.h"
#include "Beep-Carbon-Notifications.h"
#include "Beep-Carbon-Debugging.h"

#include <syslog.h>
#include <stdarg.h>
extern void CFLog(int priority, CFStringRef format, ...);

/*controlEnablerFunc, n.: function taking one ControlRef (the control to enable
 *	or disable) and returning an OSStatus.
 *Carbon provides two: EnableControl and DisableControl.
 */
typedef OSStatus (*controlEnablerFunc)(ControlRef);

OSStatus handleCommandInWindow(EventHandlerCallRef nextHandler, EventRef event, void *refcon);
OSStatus handleCommandInSheet(EventHandlerCallRef nextHandler, EventRef event, void *refcon);
OSStatus handleDragInSheet(EventHandlerCallRef nextHandler, EventRef event, void *refcon);
OSStatus handleOKToAbort(EventHandlerCallRef nextHandler, EventRef event, void *refcon);

void clearFieldsInSheet(WindowRef sheet);

WindowRef mainWindow = NULL;
WindowRef newNotificationSheet = NULL;

extern CFArrayCallBacks notificationCallbacks;

static struct Growl_Delegate delegate;

enum { typePNG = kPNGCodecType };
static const OSType     wantDragTypes[] = { typeJPEG, typePNG,               0U };
static const OSType tolerateDragTypes[] = { typePict, typeTIFF, typeFileURL, 0U };

int main(void) {
	IBNibRef nib;

	CreateNibReference(CFSTR("Beep-Carbon"), &nib);
	if(nib) {
		SetMenuBarFromNib(nib,   CFSTR("MenuBar"));
		CreateWindowFromNib(nib, CFSTR("MainWindow"), &mainWindow);
		CreateWindowFromNib(nib, CFSTR("NewNotification"), &newNotificationSheet);
		DisposeNibReference(nib);
	}

	if(mainWindow && newNotificationSheet) {
		OSStatus err = noErr;

		SetAutomaticControlDragTrackingEnabledForWindow(mainWindow, true);
		SetAutomaticControlDragTrackingEnabledForWindow(newNotificationSheet, true);

		SetUpDataBrowser(mainWindow, mainWindowNotificationsBrowserID);

		EventHandlerRef mainWindowHandlerRef = NULL;
		EventHandlerRef sheetHandlerRef = NULL;
		EventHandlerUPP handleCommandInWindowUPP = NewEventHandlerUPP(handleCommandInWindow);
		EventHandlerUPP handleCommandInSheetUPP  = NewEventHandlerUPP(handleCommandInSheet);
		EventHandlerUPP handleDragInSheetUPP     = NewEventHandlerUPP(handleDragInSheet);

		if(handleCommandInWindowUPP && handleCommandInSheetUPP) {
			EventTypeSpec eventTypes[] = {
				{ kEventClassCommand, kEventCommandProcess },
				{ kEventClassWindow,  kEventWindowClose }
			};
			InstallWindowEventHandler(mainWindow, handleCommandInWindowUPP, GetEventTypeCount(eventTypes), eventTypes, /*refcon*/ mainWindow, &mainWindowHandlerRef);
			InstallWindowEventHandler(newNotificationSheet, handleCommandInSheetUPP, 1U, eventTypes, /*refcon*/ newNotificationSheet, &sheetHandlerRef);

			EventTypeSpec dragEventTypes[] = {
				{ kEventClassControl, kEventControlDragEnter },
				{ kEventClassControl, kEventControlDragReceive }
			};
			ControlRef well;
			ControlID wellID = { appSignature, notificationSheetIconWellID };
			err = GetControlByID(newNotificationSheet, &wellID, &well);
			if(err != noErr) well = NULL;
			if(well)
				InstallControlEventHandler(well, handleDragInSheetUPP, GetEventTypeCount(dragEventTypes), dragEventTypes, /*refcon*/ well, NULL /*&sheetHandlerRef*/);
		}

		if(mainWindowHandlerRef && sheetHandlerRef) {
			DialogRef alertSheet = NULL;

			//set up the delegate
			{
				InitGrowlDelegate(&delegate);
				CreateMasterListIfNecessary();

				delegate.applicationName = CFSTR("Beep-Carbon");

				//create empty arrays. they will be replaced when the lists
				//	of notifications change.
				CFArrayRef allNotifications = CFArrayCreateMutable(kCFAllocatorDefault, /*capacity*/ 0, &kCFTypeArrayCallBacks);
				CFArrayRef defaultNotifications = CFRetain(allNotifications);

				const void *keys[] = {
					GROWL_NOTIFICATIONS_ALL,
					GROWL_NOTIFICATIONS_DEFAULT,
				};
				const void *values[] = {
					allNotifications,
					defaultNotifications,
				};
				delegate.registrationDictionary = CFDictionaryCreate(kCFAllocatorDefault, keys, values, 2, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
			}
			Growl_SetDelegate(&delegate);

			if(!Growl_IsInstalled()) {
				const char msg[] = "This application requires Growl 0.6 or later to work.";
				CFStringRef msgstr = CFStringCreateWithCString(kCFAllocatorDefault, msg, kCFStringEncodingUTF8);
				err = CreateStandardSheet(kAlertStopAlert, CFSTR("Could not launch Growl."), msgstr, /*param*/ NULL, GetApplicationEventTarget(), &alertSheet);
				CFRelease(msgstr);

				EventTypeSpec alertEventTypes[] = { { kEventClassCommand, kEventCommandProcess } };
				InstallApplicationEventHandler(handleOKToAbort, GetEventTypeCount(alertEventTypes), alertEventTypes, /*refcon*/ NULL, /*outRef*/ NULL);
			}

			ShowWindow(mainWindow);
			if(alertSheet)
				err = ShowSheetWindow(GetDialogWindow(alertSheet), mainWindow);

			RunApplicationEventLoop();

			if(alertSheet)
				ReleaseWindow((WindowRef)alertSheet);
		}

		if(mainWindowHandlerRef)
			RemoveEventHandler(mainWindowHandlerRef);
		if(sheetHandlerRef)
			RemoveEventHandler(sheetHandlerRef);

		if(handleCommandInWindowUPP)
			DisposeEventHandlerUPP(handleCommandInWindowUPP);
		if(handleCommandInSheetUPP)
			DisposeEventHandlerUPP(handleCommandInSheetUPP);
	}

	if(newNotificationSheet) {
		HideSheetWindow(newNotificationSheet);
		ReleaseWindow(newNotificationSheet);
	}
	if(mainWindow)
		ReleaseWindow(mainWindow);

	return 0;
}

OSStatus handleCommandInWindow(EventHandlerCallRef nextHandler, EventRef event, void *refcon) {
	UInt32 class = GetEventClass(event), kind = GetEventKind(event);
	OSStatus err = eventNotHandledErr;
	WindowRef window = refcon;

	switch(class) {
		case kEventClassCommand:
			switch(kind) {
				case kEventCommandProcess:;
					HICommand cmd;
					err = GetEventParameter(event, kEventParamDirectObject, typeHICommand, /*outActualType*/ NULL, sizeof(cmd), /*outActualSize*/ NULL, &cmd);
					if(err == noErr) {
						struct Beep_Notification *notification = NULL;
						ControlRef dataBrowser = NULL;
						ControlID controlID = { appSignature, mainWindowNotificationsBrowserID };
						err = GetControlByID(window, &controlID, &dataBrowser);
						if(err != noErr) break;

						CFIndex first, last, i;
						GetDataBrowserSelectionAnchor(dataBrowser, (DataBrowserItemID *)&first, (DataBrowserItemID *)&last);

						switch(cmd.commandID) {
#pragma mark Main window, Send button
							case kHICommandOK:
								//send notification
								DEBUG_printf2("Send btn hit - selection is %u to %u\n", (unsigned)first, (unsigned)last);
								if(first < 1 || last < 1) break;
								for(i = first - 1; i < last; ++i) {
									DEBUG_printf1("\tCopying notification %i\n", (int)i);
									notification = GetNotificationAtIndex(i);
									DEBUG_printf1("\tnotification is %p\n", (void *)notification);
									DEBUG_printf1("\tnotification->growlNotification.iconData is %p\n", (void *)notification->growlNotification.iconData);
									Growl_PostNotification(&(notification->growlNotification));
								}
								break;

#pragma mark Main window, Add button
							case registerNotificationCmd:
								/*add a new notification to the list
								 *we do this by running the sheet.
								 *the notification will actually be registered
								 *	when the sheet exits.
								 */
								DEBUG_print("Add btn hit\n");
								clearFieldsInSheet(newNotificationSheet);
								err = ShowSheetWindow(newNotificationSheet, mainWindow);
								break;

#pragma mark Main window, Delete button
							case unregisterNotificationCmd:;
								//remove a notification from the list
								DEBUG_print("Del btn hit\n");

								unsigned numSelected = (last - first) + 1U;

								/*we want to delete the last numSelected indices
								 *	from the data browser, and the selected
								 *	indices from the master list.
								 */

								/*first remove the data browser items.
								 *
								 *the significance of this code is that items
								 *	will contain the selection in reverse:
								 *	{ last, ..., first }.
								 *
								 *example: if there were six items in the list,
								 *	with the second through fourth being
								 *	selected, then items must be:
								 *	{ 6, 5, 4 }.
								 *(remember that for DB, the first index is 1.)
								 *this is because we want to lop off the last
								 *	three DB items (4..6), leaving only the
								 *	first three (1..3), which can then be
								 *	translated into all the remaining indices
								 *	(0..2) of the master notifications list.
								 */
								DataBrowserItemID *items = malloc(sizeof(DataBrowserItemID) * numSelected);
								unsigned j = CountNotificationsInMasterList();
								for(unsigned i = 0U; i < numSelected; ++i) {
									/*note that we want to use post-increment
									 *	here because of DB's 1-based indexing.
									 */
									items[i] = j--;
									DEBUG_printf2("Item to remove #%u: %lu\n", i, (unsigned long)items[i]);
								}

								//remove the actual notifications afterwards.
								for(CFIndex i = first - 1; i < last; ++i) {
									DEBUG_printf1("Deleting notification at index %lli\n", (long long)i);
									RemoveNotificationFromMasterListByIndex(i);
								}
									
								UpdateGrowlDelegate(&delegate);
								Growl_Reregister();
								err = RemoveDataBrowserItems(dataBrowser,
															 /*container*/ kDataBrowserNoItem,
															 numSelected,
															 items,
															 /*preSortProperty*/ kDataBrowserItemNoProperty);
								UpdateDataBrowserItems(dataBrowser,
													   /*container*/ kDataBrowserNoItem,
													   /*numItems*/ 0U,
													   /*items*/ NULL,
													   /*preSortProperty*/ kDataBrowserItemNoProperty,
													   /*propertyID*/ kDataBrowserItemNoProperty);
								free(items);
								break;

#pragma mark Main window, Registered checkbox
							case registerWithGrowlCmd:;
								/*create the allowed and default notification
								 *	arrays, put them in a dictionary, put that
								 *	in a notification, and post it.
								 *
								 *note that currently (Growl 0.6), there is no
								 *	Reregister button. this handler is mainly a
								 *	vestige of the 'Registered' checkbox in the
								 *	old Growl-0.5 Beep-Carbon.
								 *
								 *if a Reregister button is ever created,
								 *	however, we are prepared. :)
								 */
								DEBUG_print("Register button hit\n");
								err = CallNextEventHandler(nextHandler, event);
								if(err != noErr && err != eventNotHandledErr) break;

								UpdateGrowlDelegate(&delegate);
								Growl_Reregister();

								break; //case registerWithGrowlCmd

							default:
								err = eventNotHandledErr;
						} //switch(cmd.commandID)
					} //if(err == noErr)
			} //switch(kind) (kEventClassCommand)
			break;

		case kEventClassWindow:
#pragma mark Main window, Close widget
			if(kind == kEventWindowClose) {
				HICommand cmd;
				cmd.attributes = 0;
				cmd.commandID = kHICommandQuit;
				cmd.menu.menuRef = NULL;
				cmd.menu.menuItemIndex = 0;
				err = ProcessHICommand(&cmd);
			}
			break;
	} //switch(class)

	return err;
}

OSStatus handleCommandInSheet(EventHandlerCallRef nextHandler, EventRef event, void *refcon) {
	OSType class = GetEventClass(event); UInt32 kind = GetEventKind(event);
	OSStatus err = eventNotHandledErr;
	WindowRef window = refcon;
	
	switch(class) {
		case kEventClassCommand:
			switch(kind) {
				case kEventCommandProcess:;
					HICommand cmd;
					err = GetEventParameter(event, kEventParamDirectObject, typeHICommand, /*outActualType*/ NULL, sizeof(cmd), /*outActualSize*/ NULL, &cmd);
					if(err == noErr) {
						struct Beep_Notification *notification;
						ControlRef control = NULL;
						ControlID controlID = { appSignature, 0 };
						DataBrowserItemID item;
						CFStringRef title = NULL, desc = NULL;
						CFDataRef imageData = NULL;
						Boolean isSticky = false, isDefault = false;
						int priority = 0;
						
						switch(cmd.commandID) {
#pragma mark Sheet, OK button
							case kHICommandOK:
								DEBUG_print("OK button hit\n");
								controlID.id = notificationSheetTitleFieldID; //title field
								err = GetControlByID(window, &controlID, &control);
								if(err == noErr)
									err = GetControlData(control, kControlEditTextPart, kControlEditTextCFStringTag, sizeof(title), &title, /*outActualSize*/ NULL);
								if(err == noErr && CFStringGetLength(title) == 0) {
									DEBUG_print("\tTitle is empty!\n");
									CFRelease(title);
									break;
								}

								controlID.id = notificationSheetDescFieldID; //desc field
								err = GetControlByID(window, &controlID, &control);
								if(err == noErr)
									err = GetControlData(control, kControlEditTextPart, kControlEditTextCFStringTag, sizeof(desc), &desc, /*outActualSize*/ NULL);
								if(err == noErr && CFStringGetLength(desc) == 0) {
									DEBUG_print("\tDesc is empty!\n");
									CFRelease(desc);
									desc = NULL;
								}

								controlID.id = notificationSheetPriorityMenu; //priority pop-up menu
								err = GetControlByID(window, &controlID, &control);
								/*	priorities are in the range -2..+2.
								 *	menu item indices are in the range 1..SHRT_MAX.
								 *	thus, a menu item index can be converted
								 *		into a priority by subtracting 3.
								 */
								priority = GetControl32BitValue(control) - 3;

								controlID.id = notificationSheetDefaultCheckboxID; //default-notification checkbox
								err = GetControlByID(window, &controlID, &control);
								isDefault = (GetControl32BitValue(control) != kControlCheckBoxUncheckedValue);

								controlID.id = notificationSheetStickyID; //sticky checkbox
								err = GetControlByID(window, &controlID, &control);
								isSticky = (GetControl32BitValue(control) != kControlCheckBoxUncheckedValue);

								controlID.id = notificationSheetIconWellID; //image well
								err = GetControlByID(window, &controlID, &control);
								if(err == noErr) {
									err = GetControlProperty(control, appSignature, 'ICON', sizeof(imageData), /*actualSize*/ NULL, &imageData);
									RemoveControlProperty(control, appSignature, 'ICON');
								}

								//XXX - we should have a separate field in the sheet for notification name.
								notification = CreateGrowlNotification(title, title, desc, priority, imageData, isSticky, isDefault);
								if(imageData) CFRelease(imageData);
								if(notification) {
									/*	it's worth pointing out that this next
									 *	GCBI call is for the main window, not
									 *	the sheet.
									 */
									controlID.id = mainWindowNotificationsBrowserID;
									err = GetControlByID(mainWindow, &controlID, &control);

									AddNotificationToMasterList(notification);
									UpdateGrowlDelegate(&delegate);
									Growl_Reregister();
									item = (DataBrowserItemID)CountNotificationsInMasterList();
									if(item)
										AddDataBrowserItems(control, kDataBrowserNoItem, 1U, &item, dataBrowserNotificationNameProperty);
								}

#pragma mark Sheet, Cancel button
							case kHICommandCancel:
								if(imageData == NULL) {
									if(control == NULL) {
										controlID.id = notificationSheetIconWellID; //default-notification checkbox
										GetControlByID(window, &controlID, &control);
									}
									if(control) {
										GetControlProperty(control, appSignature, 'ICON', sizeof(imageData), /*actualSize*/ NULL, &imageData);
										RemoveControlProperty(control, appSignature, 'ICON');
									}
									if(imageData)
										CFRelease(imageData);
								}
								err = HideSheetWindow(window);
								break; //case kHICommandCancel

#pragma mark Sheet, default
							default:
								err = eventNotHandledErr;
						} //switch(cmd.commandID)
					} //if(err == noErr)
			} //switch(kind) (kEventClassCommand)
			break;
	} //switch(class)
	
	return err;
}

OSStatus handleDragInSheet(EventHandlerCallRef nextHandler, EventRef event, void *refcon) {
	UInt32 class = GetEventClass(event), kind = GetEventKind(event);
	OSStatus err = eventNotHandledErr;
	ControlRef dropTarget = NULL;
	DragRef drag = NULL;

	switch(class) {
		case kEventClassControl:
			err = GetEventParameter(event, kEventParamDirectObject, typeControlRef, /*outActualType*/ NULL, sizeof(dropTarget), /*outActualSize*/ NULL, &dropTarget);
			DEBUG_printf2("GEP (DirectObject): %i (%p)\n", (int)err, (void *)dropTarget);
			GetEventParameter(event, kEventParamDragRef, typeDragRef, /*outActualType*/ NULL, sizeof(drag), /*outActualSize*/ NULL, &drag);
			DEBUG_printf2("GEP (DragRef): %i (%p)\n", (int)err, (void *)drag);
			err = eventNotHandledErr;

			DragItemRef item = 0;
			UInt16 flavorIndex = 0U;
			switch(kind) {
				case kEventControlDragEnter:;
					DEBUG_print("drag entered!\n");
					Boolean isFileURL = false;

					if(dragItemWithTypes(drag, wantDragTypes, /*outFlavorIndex*/ NULL) || ((isFileURL = true) && (item = dragItemWithTypes(drag, tolerateDragTypes, &flavorIndex)))) {
						Boolean isDir = false;

						/*we don't want to try and read a picture from a
						 *	directory. so, if it's a directory, refuse the drag.
						 *UNFORTUNATELY, Panther's Dock appends a / to every URL
						 *	within it, so files dropped on the well from the
						 *	Dock look like directories - and are thus refused.
						 *so for now, this code is disabled. directories are
						 *	accepted and ignored.
						 */

#ifdef DOCK_DOES_NOT_APPEND_SLASHES_TO_FILES
						DEBUG_printf1("isFileURL: %hhu\n", isFileURL);
						if(isFileURL) {
							FlavorType flavorType;
							err = GetFlavorType(drag, item, flavorIndex, &flavorType);
							DEBUG_printf1("GetFlavorType: %i\n", (int)err);
							if(err == noErr) {
								Size bufSize;
								unsigned char *buf = NULL;
								CFURLRef url = NULL;

								err = GetFlavorDataSize(drag, item, flavorType, &bufSize);
								DEBUG_printf1("GetFlavorDataSize: %i\n", (int)err);
								if(err == noErr)
									buf = malloc(bufSize+1);
								DEBUG_printf1("buf: %p\n", buf);
								if(buf) {
									err = GetFlavorData(drag, item, flavorType, buf, &bufSize, /*dataOffset*/ 0U);
									DEBUG_printf1("GetFlavorData: %i\n", (int)err);
									buf[bufSize] = 0;
									DEBUG_printf1("buf: \"%s\"\n", buf);
									if(err == noErr)
										url = CFURLCreateWithBytes(kCFAllocatorDefault, buf, bufSize, kCFStringEncodingUTF8, /*baseURL*/ NULL);
									DEBUG_printf1("url: %p\n", url);
									CFShow(url);
									if(url) {
										isDir = CFURLHasDirectoryPath(url);
										CFRelease(url);
									}
									DEBUG_printf1("isDir: %hhu\n", isDir);
									free(buf);
								}
							}
						} //if(isFileURL)
#endif //def DOCK_DOES_NOT_APPEND_SLASHES_TO_FILES

						DEBUG_printf1("isDir: %hhu\n", isDir);
						if(!isDir) {
							const Boolean truth = true;
							err = SetEventParameter(event, kEventParamControlWouldAcceptDrop, typeBoolean, sizeof(truth), &truth);
						}
					}
					break;

				case kEventControlDragReceive:;
					DEBUG_print("drag received!\n");
					Size bufSize = 0U;
					void *buf = NULL;
					PicHandle image = NULL;

					item = dragItemWithTypes(drag, wantDragTypes, &flavorIndex);
					if(item == 0)
						item = dragItemWithTypes(drag, tolerateDragTypes, &flavorIndex);
					DEBUG_printf1("item: %u\n", (unsigned)item);
					if(item) {
						FlavorType flavorType;
						err = GetFlavorType(drag, item, flavorIndex, &flavorType);
						CFDataRef data = NULL;
						if(flavorType != typePict) {
							if(flavorType == typeFileURL) {
								//it's a file URL.
								CFURLRef url = NULL;

								err = GetFlavorDataSize(drag, item, flavorType, &bufSize);
								if(err == noErr)
									buf = malloc(bufSize);
								DEBUG_printf1("buf (for file URL): %p\n", buf);
								if(buf)
									err = GetFlavorData(drag, item, flavorType, buf, &bufSize, 0U);
								if(err == noErr)
									url = CFURLCreateWithBytes(kCFAllocatorDefault, buf, bufSize, kCFStringEncodingUTF8, /*baseURL*/ NULL);
								free(buf);
								bufSize = 0U;

								DEBUG_printf1("url: %p\n", url);
								if(url) {
									DEBUG_print("Creating data from file\n");
									Boolean success = CFURLCreateDataAndPropertiesFromResource(kCFAllocatorDefault, url, (CFDataRef *)&data, /*properties*/ NULL, /*desiredProperties*/ NULL, /*errorCode*/ NULL);
									DEBUG_printf1("data (read from URL): %p\n", data);
									if(data && success) {
										bufSize = CFDataGetLength(data);
										buf = (void *)CFDataGetBytePtr(data);
									}
									DEBUG_printf2("Got buffer and size: %p %u\n", buf, (unsigned)bufSize);
									DEBUG_printf1("bufSize: %u\n", (unsigned)bufSize);
									CFRelease(url);
								}
							} //if(flavorType == typeFileURL)
							DEBUG_printf1("buf: %p\n", buf);
							if(buf) {
								DEBUG_printf1("bufSize: %u\n", (unsigned)bufSize);
								CFIndex bufSize2 = bufSize;
								void *buf2 = buf;
								if(buf2 && bufSize2) {
									flavorType = typePict;
									convertBytesToFormat(buf2, bufSize2, flavorType = typePict, &buf, &bufSize);
									if(!data) free(buf2);
								}
							}
						} //if(flavorType != typePict)
						if(flavorType == typePict) {
							DEBUG_printf1("buf (flavorType == typePict): %p\n", buf);
							DEBUG_printf1("bufSize: %u\n", (unsigned)bufSize);
							if(buf == NULL) {
								err = GetFlavorDataSize(drag, item, flavorType, &bufSize);
								if(err == noErr)
									buf = malloc(bufSize);
								DEBUG_printf1("buf: %p\n", buf);
								if(buf) {
									err = GetFlavorData(drag, item, flavorType, buf, &bufSize, 0U);
									if(err == noErr) {
										DEBUG_print("Creating data from flavour data\n");
										data = CFDataCreate(kCFAllocatorDefault, buf, bufSize);
										DEBUG_printf1("data (flavorType == typePict): %p\n", data);
									}
								}
							}
							DEBUG_printf1("data: %p\n", data);
							if(data) {
								if(buf)								
									PtrToHand(buf, (Handle *)&image, bufSize);
								if(image) {
									PicHandle image2 = scalePictureToImageWell(image, dropTarget);
									DisposeHandle((Handle)image);
									image = image2;
								}
								if(image) {
									ControlButtonContentInfo cbci;
									cbci.contentType = kControlContentPictHandle;
									cbci.u.picture = image;
									err = SetImageWellContentInfo(dropTarget, &cbci);
									DEBUG_printf1("SetImageWellContentInfo: %i\n", (int)err);
									HIViewSetNeedsDisplay(dropTarget, true);
								}
								err = SetControlProperty(dropTarget, appSignature, 'ICON', sizeof(data), &data);
								DEBUG_printf1("SetControlProperty: %i\n", (int)err);
								//don't release the data!
							}
						} //if(flavorType == typePict)
					} //if(item)
			} //switch(kind) (kEventClassCommand)
			break;
	} //switch(class)
	
	return err;
}

void clearFieldsInSheet(WindowRef sheet) {
	if(sheet && (sheet == newNotificationSheet)) {
		ControlRef  control   = NULL;
		ControlID   controlID = { appSignature, 0 };
		CFStringRef emptyStr  = CFSTR("");

		//title field.
		controlID.id = notificationSheetTitleFieldID;
		GetControlByID(sheet, &controlID, &control);
		SetControlData(control, kControlEditTextPart, kControlEditTextCFStringTag, sizeof(emptyStr), &emptyStr);
		SetControlDragTrackingEnabled(control, true);
		SetKeyboardFocus(sheet, control, kControlEditTextPart);

		//description field.
		controlID.id = notificationSheetDescFieldID;
		GetControlByID(sheet, &controlID, &control);
		SetControlData(control, kControlEditTextPart, kControlEditTextCFStringTag, sizeof(emptyStr), &emptyStr);
		SetControlDragTrackingEnabled(control, true);

		//default-notification checkbox.
		controlID.id = notificationSheetDefaultCheckboxID;
		GetControlByID(sheet, &controlID, &control);
		SetControl32BitValue(control, kControlCheckBoxCheckedValue);

		//sticky checkbox.
		controlID.id = notificationSheetStickyID;
		GetControlByID(sheet, &controlID, &control);
		SetControl32BitValue(control, kControlCheckBoxUncheckedValue);
		
		//image well.
		{
			controlID.id = notificationSheetIconWellID;
			GetControlByID(sheet, &controlID, &control);

			//clear the image (the one the user sees) from the well.
			ControlButtonContentInfo cbci;
			cbci.contentType = kControlContentPictHandle;
			cbci.u.picture = NULL;
			SetImageWellContentInfo(control, &cbci);

			//we need to release the image data, which means we need to get that
			//	pointer out before we remove the property.
			CFDataRef imageData = NULL;
			GetControlProperty(control, appSignature, 'ICON', sizeof(imageData), /*actualSize*/ NULL, &imageData);
			RemoveControlProperty(control, appSignature, 'ICON');
			if(imageData)
				CFRelease(imageData);

			//finally, ensure the drag-and-droppability of the well.
			SetControlDragTrackingEnabled(control, true);
		}
	}
}

OSStatus updateSendEnabledState(Boolean enabled) {
	ControlRef btn = NULL;
	static const ControlID ctlID = { appSignature, mainWindowSendButtonID };
	OSStatus err;
	static const controlEnablerFunc controlEnablerFuncs[2] = { DisableControl, EnableControl }; 

	err = GetControlByID(mainWindow, &ctlID, &btn);
	if(err == noErr)
		err = controlEnablerFuncs[enabled != false](btn);

	return err;
}

OSStatus updateDeleteEnabledState(Boolean enabled) {
	ControlRef btn = NULL;
	static const ControlID ctlID = { appSignature, mainWindowDeleteNotificationID };
	OSStatus err;
	static const controlEnablerFunc controlEnablerFuncs[2] = { DisableControl, EnableControl }; 
	
	err = GetControlByID(mainWindow, &ctlID, &btn);
	if(err == noErr)
		err = controlEnablerFuncs[enabled != false](btn);

	return err;
}

OSStatus handleOKToAbort(EventHandlerCallRef nextHandler, EventRef event, void *refcon) {
#pragma unused(refcon)
	OSType class = GetEventClass(event); UInt32 kind = GetEventKind(event);
	OSStatus err = eventNotHandledErr;
	
	switch(class) {
		case kEventClassCommand:
			switch(kind) {
				case kEventCommandProcess:;
					HICommand cmd;
					err = GetEventParameter(event, kEventParamDirectObject, typeHICommand, /*outActualType*/ NULL, sizeof(cmd), /*outActualSize*/ NULL, &cmd);
					if(err == noErr) {
						
						switch(cmd.commandID) {
#pragma mark Abort sheet, OK button
							case kHICommandOK:;
								HICommand cmd;
								cmd.attributes = 0;
								cmd.commandID = kHICommandQuit;
								cmd.menu.menuRef = NULL;
								cmd.menu.menuItemIndex = 0;
								err = ProcessHICommand(&cmd);
								
#pragma mark Abort sheet, default
							default:
								err = eventNotHandledErr;
						} //switch(cmd.commandID)
					} //if(err == noErr)
			} //switch(kind) (kEventClassCommand)
			break;
	} //switch(class)
	
	return err;
}
