/* AppController */

#import <Cocoa/Cocoa.h>

@class FireWireNotifier, USBNotifier, BluetoothNotifier, VolumeNotifier, NetworkNotifier;

@interface AppController : NSObject {
	FireWireNotifier	*fwNotifier;
	USBNotifier			*usbNotifier;
	BluetoothNotifier	*btNotifier;
	VolumeNotifier		*volNotifier;
	NetworkNotifier		*netNotifier;

	NSData				*bluetoothLogoData;
	NSData				*ejectLogoData;
	NSData				*firewireLogoData;
	NSData				*usbLogoData;
	NSData				*airportIconData;
	NSData				*ipIconData;

	BOOL				sleeping;
}

- (IBAction) doSimpleHelp:(id)sender;

@end
