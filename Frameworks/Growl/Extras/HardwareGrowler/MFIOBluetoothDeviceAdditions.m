//
//  MFIOBluetoothDeviceAdditions.m
//  ThinAir
//
//  Created by Diggory Laycock on Mon Jul 21 2003.
//  Copyright (c) 2003 Monkeyfood.com. All rights reserved.
//

#import "MFIOBluetoothDeviceAdditions.h"
#import <IOBluetooth/IOBluetoothUtilities.h>

@implementation IOBluetoothDevice (MFIOBluetoothDeviceAdditions)

- (NSString *) name {
	return [self getName];
}

- (NSString  *) address {
	return IOBluetoothNSStringFromDeviceAddress([self getAddress]);
}

- (NSString *) deviceClassMajorName {
	BluetoothDeviceClassMajor classMajor;
	classMajor = [self getDeviceClassMajor];

	/*
	 kBluetoothDeviceClassMajorMiscellaneous	= 0x00,	// [00000] Miscellaneous
	 BluetoothDeviceClassMajorComputer			= 0x01, // [00001] Desktop, Notebook, PDA, Organizers, etc...
	 kBluetoothDeviceClassMajorPhone			= 0x02, // [00010] Cellular, Cordless, Payphone, Modem, etc...
	 kBluetoothDeviceClassMajorLANAccessPoint	= 0x03,	// [00011] LAN Access Point
	 kBluetoothDeviceClassMajorAudio			= 0x04, // [00100] Headset, Speaker, Stereo, etc...
	 kBluetoothDeviceClassMajorPeripheral		= 0x05, // [00101] Mouse, Joystick, Keyboards, etc...
	 kBluetoothDeviceClassMajorImaging			= 0x06,	// [00110] Printing, scanner, camera, display, etc...
	 kBluetoothDeviceClassMajorUnclassified		= 0x1F, // [11111] Specific device code not assigned
	*/

	switch (classMajor) {
		case kBluetoothDeviceClassMajorComputer:
			return @"Computer";
		case kBluetoothDeviceClassMajorPhone:
			return @"Phone";
		case kBluetoothDeviceClassMajorAudio:
			return @"Audio";
		case kBluetoothDeviceClassMajorUnclassified:
			return @"Unknown";
		default:
			NSLog(@"Unknown Type: (%x) " , classMajor);
			return @"Unknown";
	}
}

@end
