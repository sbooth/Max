//
//  MFIOBluetoothDeviceAdditions.h
//  ThinAir
//
//  Created by Diggory Laycock on Mon Jul 21 2003.
//  Copyright (c) 2003 Monkeyfood.com. All rights reserved.
//

#import <IOBluetooth/objc/IOBluetoothDevice.h>

@interface IOBluetoothDevice (MFIOBluetoothDeviceAdditions)

- (NSString *) name;
- (NSString *) address;
- (NSString *) deviceClassMajorName;

@end
