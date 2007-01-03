#import "USBNotifier.h"
#import <IOKit/IOCFPlugIn.h>
#import <IOKit/usb/IOUSBLib.h>
#import <IOKit/usb/USB.h>

#pragma mark C Callbacks

static void usbDeviceAdded(void *refCon, io_iterator_t iter) {
	[(USBNotifier*)refCon usbDeviceAdded:iter];
}

static void usbDeviceRemoved(void *refCon, io_iterator_t iter) {
	[(USBNotifier*)refCon usbDeviceRemoved:iter];
}

#pragma mark -

@implementation USBNotifier

- (id) initWithDelegate:(id)object {
	if ((self = [super init])) {
		delegate = object;
		notificationsArePrimed = NO;
		[self ioKitSetUp];
		[self registerForUSBNotifications];
	}
	return self;
}

- (void) dealloc {
	[self ioKitTearDown];

	[super dealloc];
}

- (void) ioKitSetUp {
//#warning	kIOMasterPortDefault is only available on 10.2 and above...
	ioKitNotificationPort = IONotificationPortCreate(kIOMasterPortDefault);
	notificationRunLoopSource = IONotificationPortGetRunLoopSource(ioKitNotificationPort);

	CFRunLoopAddSource(CFRunLoopGetCurrent(),
					   notificationRunLoopSource,
					   kCFRunLoopDefaultMode);

}

- (void) ioKitTearDown {
	if (ioKitNotificationPort) {
		CFRunLoopRemoveSource(CFRunLoopGetCurrent(), notificationRunLoopSource, kCFRunLoopDefaultMode);
		IONotificationPortDestroy(ioKitNotificationPort) ;
	}
}

- (void) registerForUSBNotifications {
	//http://developer.apple.com/documentation/DeviceDrivers/Conceptual/AccessingHardware/AH_Finding_Devices/chapter_4_section_2.html#//apple_ref/doc/uid/TP30000379/BABEACCJ
	kern_return_t			matchingResult;
	io_iterator_t			addedIterator;
	io_iterator_t			removedIterator;

//	NSLog(@"registerForUSBNotifications");

	//	Setup a matching Dictionary.
	CFDictionaryRef myMatchDictionary;
	myMatchDictionary = nil;
	myMatchDictionary = IOServiceMatching(kIOUSBDeviceClassName);

	//	Register our notification
	addedIterator = nil;
	matchingResult = IOServiceAddMatchingNotification(ioKitNotificationPort,
													  kIOPublishNotification,
													  myMatchDictionary,
													  usbDeviceAdded,
													  (void *) self,
													  (io_iterator_t *) &addedIterator );

	if (matchingResult)
		NSLog(@"matching notification registration failed: %d" , matchingResult);

	//	Prime the Notifications (And Deal with the existing devices)...
	[self usbDeviceAdded:addedIterator];

	//	Register for removal notifications.
	//	It seems we have to make a new dictionary...  reusing the old one didn't work.

	myMatchDictionary = IOServiceMatching(kIOUSBDeviceClassName);
	kern_return_t			removeNoteResult;
//	io_iterator_t			removedIterator ;
	removeNoteResult = IOServiceAddMatchingNotification(ioKitNotificationPort,
														kIOTerminatedNotification,
														myMatchDictionary,
														usbDeviceRemoved,
														self,
														&removedIterator );

	// Matching notification must be "primed" by iterating over the
	// iterator returned from IOServiceAddMatchingNotification(), so
	// we call our device removed method here...
	//
	if (kIOReturnSuccess != removeNoteResult)
		NSLog(@"Couldn't add device removal notification") ;
	else
		[self usbDeviceRemoved: removedIterator];

	notificationsArePrimed = YES;
}

- (void) usbDeviceAdded: (io_iterator_t ) iterator {
//	NSLog(@"USB Device Added Notification.");
	io_object_t	thisObject;
	while ((thisObject = IOIteratorNext(iterator))) {
		if (notificationsArePrimed || [[NSUserDefaults standardUserDefaults] boolForKey:@"ShowExisting"]) {
			kern_return_t	nameResult;
			io_name_t		deviceNameChars;

			//	This works with USB devices...
			//	but apparently not firewire
			nameResult = IORegistryEntryGetName(thisObject, deviceNameChars);

			NSString *deviceName = [[NSString alloc] initWithCString:deviceNameChars];
			if (!deviceName)
				deviceName = @"Unnamed USB Device";
			else if ([deviceName isEqualToString:@"OHCI Root Hub Simulation"])
				deviceName = @"USB Bus";
			else if ([deviceName isEqualToString:@"EHCI Root Hub Simulation"])
				deviceName = @"USB 2.0 Bus";

			// NSLog(@"USB Device Attached: %@" , deviceName);
			[delegate usbDidConnect:deviceName];
			[deviceName release];
		}

		IOObjectRelease(thisObject);
	}
}

- (void) usbDeviceRemoved: (io_iterator_t ) iterator {
//	NSLog(@"USB Device Removed Notification.");
	io_object_t thisObject;
	while ((thisObject = IOIteratorNext(iterator))) {
		kern_return_t	nameResult;
		io_name_t		deviceNameChars;

		//	This works with USB devices...
		//	but apparently not firewire
		nameResult = IORegistryEntryGetName(thisObject,
											deviceNameChars);
		NSString *deviceName = [[NSString alloc] initWithCString:deviceNameChars];
		if (!deviceName)
			deviceName = @"Unnamed USB Device";

		// NSLog(@"USB Device Detached: %@" , deviceName);
		[delegate usbDidDisconnect:deviceName];
		[deviceName release];

		IOObjectRelease(thisObject);
	}
}

@end
