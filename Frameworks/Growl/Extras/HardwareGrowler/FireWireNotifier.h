/* FireWireNotifier */

#import <Cocoa/Cocoa.h>

@interface FireWireNotifier : NSObject {
	id                      delegate;
	IONotificationPortRef	ioKitNotificationPort;
	CFRunLoopSourceRef		notificationRunLoopSource;
	bool					notificationsArePrimed;
}

- (id) initWithDelegate:(id)object;

- (void) ioKitSetUp;
- (void) ioKitTearDown;

- (void) registerForFireWireNotifications;
- (void) fwDeviceAdded: (io_iterator_t ) iterator;
- (void) fwDeviceRemoved: (io_iterator_t ) iterator;

- (NSString *) nameForFireWireObject: (io_object_t) thisObject;

@end

@interface NSObject(FireWireNotifierDelegate)
- (void) fwDidConnect:(NSString *)deviceName;
- (void) fwDidDisconnect:(NSString *)deviceName;
@end
