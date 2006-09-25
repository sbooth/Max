/* USBNotifier */

#import <Cocoa/Cocoa.h>
#import <IOKit/IOKitLib.h>

@interface USBNotifier : NSObject {
	id                      delegate;
	IONotificationPortRef	ioKitNotificationPort;
	CFRunLoopSourceRef		notificationRunLoopSource;
	bool					notificationsArePrimed;
}

- (id) initWithDelegate:(id)object;

- (void) ioKitSetUp;
- (void) ioKitTearDown;

- (void) registerForUSBNotifications;
- (void) usbDeviceAdded: (io_iterator_t ) iterator;
- (void) usbDeviceRemoved: (io_iterator_t ) iterator;

@end

@interface NSObject(USBNotifierDelegate)
- (void) usbDidConnect:(NSString *)deviceName;
- (void) usbDidDisconnect:(NSString *)deviceName;
@end
