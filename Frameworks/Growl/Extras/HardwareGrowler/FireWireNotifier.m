#import "FireWireNotifier.h"

static void fwDeviceAdded (void *refCon, io_iterator_t iter);
static void fwDeviceRemoved (void *refCon, io_iterator_t iter);

@implementation FireWireNotifier

- (id) initWithDelegate:(id)object {
	if ((self = [super init])) {
		delegate = object;
		notificationsArePrimed = NO;
		[self ioKitSetUp];
		[self registerForFireWireNotifications];
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

- (void) registerForFireWireNotifications {
	//http://developer.apple.com/documentation/DeviceDrivers/Conceptual/AccessingHardware/AH_Finding_Devices/chapter_4_section_2.html#//apple_ref/doc/uid/TP30000379/BABEACCJ
	kern_return_t			matchingResult;
	io_iterator_t			gFWAddedIter;

//	NSLog(@"registerForFireWireNotifications");

	//	Setup a matching Dictionary.
	CFDictionaryRef myFireWireMatchDictionary;
	myFireWireMatchDictionary = nil;
	//		myFireWireMatchDictionary = IOServiceMatching(kIOUSBDeviceClassName);
	myFireWireMatchDictionary = IOServiceMatching("IOFireWireDevice");

	//	Register our notification
	gFWAddedIter = nil;
	matchingResult = IOServiceAddMatchingNotification(
													  ioKitNotificationPort,
													  kIOPublishNotification,
													  (CFDictionaryRef) myFireWireMatchDictionary,
													  fwDeviceAdded,
													  (void *) self,
													  (io_iterator_t *) &gFWAddedIter );

	if (matchingResult)
		NSLog(@"matching notification registration failed: %d" , matchingResult);

	//	Prime the Notifications (And Deal with the existing devices)...
	[self fwDeviceAdded: gFWAddedIter];

	//	Register for removal notifications.
	//	It seems we have to make a new dictionary...  reusing the old one didn't work.

	//		myFireWireMatchDictionary = IOServiceMatching(kIOUSBDeviceClassName);
	myFireWireMatchDictionary = IOServiceMatching("IOFireWireDevice");
	kern_return_t			removeNoteResult;
	io_iterator_t			removedIterator ;
	removeNoteResult = IOServiceAddMatchingNotification(ioKitNotificationPort,
														kIOTerminatedNotification,
														(CFDictionaryRef) myFireWireMatchDictionary,
														fwDeviceRemoved,
														self,
														&removedIterator );

	// Matching notification must be "primed" by iterating over the
	// iterator returned from IOServiceAddMatchingNotification(), so
	// we call our device removed method here...
	//
	if (kIOReturnSuccess != removeNoteResult)
		NSLog(@"Couldn't add device removal notification") ;
	else
		[self fwDeviceRemoved: removedIterator];

	notificationsArePrimed = YES;
}

- (void) fwDeviceAdded: (io_iterator_t ) iterator {
	//	NSLog(@"FireWire Device Added Notification.");
	io_object_t	thisObject;
	while ((thisObject = IOIteratorNext(iterator))) {
		if (notificationsArePrimed || [[NSUserDefaults standardUserDefaults] boolForKey:@"ShowExisting"]) {
			NSString *deviceName = [self nameForFireWireObject:thisObject];
			// NSLog(@"FireWire Device Attached: %@" , deviceName);
			[delegate fwDidConnect:deviceName];
		}
		IOObjectRelease(thisObject);
	}
}

- (void) fwDeviceRemoved: (io_iterator_t ) iterator {
//	NSLog(@"FireWire Device Removed Notification.");
	io_object_t thisObject;
	while ((thisObject = IOIteratorNext(iterator))) {
		NSString *deviceName = [self nameForFireWireObject: thisObject];
		// NSLog(@"FireWire Device Removed: %@" , deviceName);
		[delegate fwDidDisconnect:deviceName];

		IOObjectRelease(thisObject);
	}
}

- (NSString *) nameForFireWireObject: (io_object_t) thisObject {
	//	This works with USB devices...
	//	but apparently not firewire
	kern_return_t	nameResult;
	io_name_t		deviceNameChars;

	nameResult = IORegistryEntryGetName(thisObject, deviceNameChars);
	NSString	*tempDeviceName = [NSString stringWithCString: deviceNameChars];
	if (tempDeviceName  && ![tempDeviceName isEqualToString:@"IOFireWireDevice"])
		return tempDeviceName;

	tempDeviceName =
		(NSString *)IORegistryEntrySearchCFProperty(thisObject,
										kIOFireWirePlane,
										CFSTR("FireWire Product Name"),
										nil,
										kIORegistryIterateRecursively);

	if (tempDeviceName)
		return tempDeviceName;

	tempDeviceName =
		(NSString *)IORegistryEntrySearchCFProperty(thisObject,
										kIOFireWirePlane,
										CFSTR("FireWire Vendor Name"),
										nil,
										kIORegistryIterateRecursively);


	if (tempDeviceName)
		return tempDeviceName;

	return @"Unnamed FireWire Device";
}


#pragma mark -
#pragma mark	C Callbacks

static void fwDeviceAdded (void *refCon, io_iterator_t iter) {
	[(FireWireNotifier*)refCon fwDeviceAdded:iter];
}

static void fwDeviceRemoved (void *refCon, io_iterator_t iter) {
	[(FireWireNotifier*)refCon fwDeviceRemoved:iter];
}

@end
