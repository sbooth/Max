#import <IOBluetooth/Bluetooth.h>
#import <IOBluetooth/objc/IOBluetoothOBEXSession.h>
#import "MFIOBluetoothDeviceAdditions.h"
#import "BluetoothNotifier.h"

@implementation BluetoothNotifier

- (id) initWithDelegate:(id)object {
	if ((self = [super init])) {
		initializing = YES;
		delegate = object;
		//	NSLog(@"registering for BT Notes.");
		/*
		 [IOBluetoothRFCOMMChannel registerForChannelOpenNotifications: self
															  selector: @selector(channelOpened:withChannel:)
														 withChannelID: 0
															 direction: kIOBluetoothUserNotificationChannelDirectionAny];
		 */

		connectionNotification = [IOBluetoothDevice registerForConnectNotifications:self
																		   selector:@selector(bluetoothConnection:toDevice:)];
		initializing = NO;
	}

	return self;
}

- (void) dealloc {
	[connectionNotification unregister];

	[super dealloc];
}

/*
- (void) channelOpened: (IOBluetoothUserNotification*)note withChannel: (IOBluetoothRFCOMMChannel *) chan {
	NSLog(@"BT Channel opened." );

	NSLog(@"%@" , [[chan getDevice] name] );

	[chan registerForChannelCloseNotification: self
									 selector: @selector(channelClosed:withChannel:)];

}

- (void) channelClosed: (IOBluetoothUserNotification*)note withChannel: (IOBluetoothRFCOMMChannel *) chan {
	NSLog(@"BT Channel closed. %@" , note);
}
*/

- (void) bluetoothConnection: (IOBluetoothUserNotification*)note toDevice: (IOBluetoothDevice *)device {
	// NSLog(@"BT Device connection: %@" , [device name]);
	if (!initializing || [[NSUserDefaults standardUserDefaults] boolForKey:@"ShowExisting"]) {
		[delegate bluetoothDidConnect:[device name]];
	}

	[device registerForDisconnectNotification: self
									 selector:@selector(bluetoothDisconnection:fromDevice:)];
}

- (void) bluetoothDisconnection: (IOBluetoothUserNotification*)note fromDevice: (IOBluetoothDevice *)device {
	// NSLog(@"BT Device Disconnection: %@" , [device name]);
	[delegate bluetoothDidDisconnect:[device name]];

	[note unregister];
}

@end
