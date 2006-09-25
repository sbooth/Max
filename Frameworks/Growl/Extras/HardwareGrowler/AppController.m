#import "AppController.h"
#import "FireWireNotifier.h"
#import "USBNotifier.h"
#import "BluetoothNotifier.h"
#import "VolumeNotifier.h"
#import "NetworkNotifier.h"
#import <Growl/Growl.h>

#define NotifierUSBConnectionNotification				@"USB Device Connected"
#define NotifierUSBDisconnectionNotification			@"USB Device Disconnected"
#define NotifierVolumeMountedNotification				@"Volume Mounted"
#define NotifierVolumeUnmountedNotification				@"Volume Unmounted"
#define NotifierBluetoothConnectionNotification			@"Bluetooth Device Connected"
#define NotifierBluetoothDisconnectionNotification		@"Bluetooth Device Disconnected"
#define NotifierFireWireConnectionNotification			@"FireWire Device Connected"
#define NotifierFireWireDisconnectionNotification		@"FireWire Device Disconnected"
#define NotifierNetworkLinkUpNotification				@"Link-Up"
#define NotifierNetworkLinkDownNotification				@"Link-Down"
#define NotifierNetworkIpAcquiredNotification			@"IP-Acquired"
#define NotifierNetworkIpReleasedNotification			@"IP-Released"
#define NotifierNetworkAirportConnectNotification		@"AirPort-Connect"
#define NotifierNetworkAirportDisconnectNotification	@"AirPort-Disconnect"

#define NotifierFireWireConnectionTitle			NSLocalizedString(@"FireWire Connection", @"")
#define NotifierFireWireDisconnectionTitle		NSLocalizedString(@"FireWire Disconnection", @"")
#define NotifierUSBConnectionTitle				NSLocalizedString(@"USB Connection", @"")
#define NotifierUSBDisconnectionTitle			NSLocalizedString(@"USB Disconnection", @"")
#define NotifierBluetoothConnectionTitle		NSLocalizedString(@"Bluetooth Connection", @"")
#define NotifierBluetoothDisconnectionTitle		NSLocalizedString(@"Bluetooth Disconnection", @"")
#define NotifierVolumeMountedTitle				NSLocalizedString(@"Volume Mounted", @"")
#define NotifierVolumeUnmountedTitle			NSLocalizedString(@"Volume Unmounted", @"")
#define NotifierNetworkAirportConnectTitle		NSLocalizedString(@"Airport connected", @"")
#define NotifierNetworkAirportDisconnectTitle	NSLocalizedString(@"Airport disconnected", @"")
#define NotifierNetworkLinkUpTitle				NSLocalizedString(@"Ethernet activated", @"")
#define NotifierNetworkLinkDownTitle			NSLocalizedString(@"Ethernet deactivated", @"")
#define NotifierNetworkIpAcquiredTitle			NSLocalizedString(@"IP address acquired", @"")
#define NotifierNetworkIpReleasedTitle			NSLocalizedString(@"IP address released", @"")

#define NotifierNetworkIpAcquiredDescription	NSLocalizedString(@"New primary IP: %@", @"")
#define NotifierNetworkIpReleasedDescription	NSLocalizedString(@"No IP address now", @"")

@implementation AppController

- (void) awakeFromNib {
	bluetoothLogoData = [[[NSImage imageNamed: @"BluetoothLogo.png"] TIFFRepresentation] retain];
	ejectLogoData = [[[NSImage imageNamed: @"eject.icns"] TIFFRepresentation] retain];
	firewireLogoData = [[[NSImage imageNamed: @"FireWireLogo.png"] TIFFRepresentation] retain];
	usbLogoData = [[[NSImage imageNamed: @"usbLogoWhite.png"] TIFFRepresentation] retain];

	NSWorkspace *ws = [NSWorkspace sharedWorkspace];

	NSString *path = [ws fullPathForApplication:@"Airport Admin Utility.app"];
	airportIconData = [[[ws iconForFile:path] TIFFRepresentation] retain];

	path = [ws fullPathForApplication:@"Internet Connect.app"];
	ipIconData = [[[ws iconForFile:path] TIFFRepresentation] retain];

	//Register ourselves as a Growl delegate for registration purposes
	[GrowlApplicationBridge setGrowlDelegate:self];

	NSNotificationCenter *nc = [ws notificationCenter];

	[nc addObserver:self
		   selector:@selector(didWake:)
			   name:NSWorkspaceDidWakeNotification
			 object:ws];
	[nc addObserver:self
		   selector:@selector(willSleep:)
			   name:NSWorkspaceWillSleepNotification
			 object:ws];

	fwNotifier = [[FireWireNotifier alloc] initWithDelegate:self];
	usbNotifier = [[USBNotifier alloc] initWithDelegate:self];
	btNotifier = [[BluetoothNotifier alloc] initWithDelegate:self];
	volNotifier = [[VolumeNotifier alloc] initWithDelegate:self];
	netNotifier = [[NetworkNotifier alloc] initWithDelegate:self];
}

- (void) dealloc {
	[fwNotifier release];
	[usbNotifier release];
	[btNotifier release];
	[volNotifier release];
	[netNotifier release];

	[bluetoothLogoData release];
	[ejectLogoData release];
	[airportIconData release];
	[ipIconData release];

	[[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self
																 name:nil
															   object:nil];

	[super dealloc];
}

- (NSString *) applicationNameForGrowl {
	return @"HardwareGrowler";
}

- (NSDictionary *) registrationDictionaryForGrowl {
	//	Register with Growl

	NSArray *notifications = [NSArray arrayWithObjects:
		NotifierBluetoothConnectionNotification,
		NotifierBluetoothDisconnectionNotification,
		NotifierFireWireConnectionNotification,
		NotifierFireWireDisconnectionNotification,
		NotifierUSBConnectionNotification,
		NotifierUSBDisconnectionNotification,
		NotifierVolumeMountedNotification,
		NotifierVolumeUnmountedNotification,
		NotifierNetworkLinkUpNotification,
		NotifierNetworkLinkDownNotification,
		NotifierNetworkIpAcquiredNotification,
		NotifierNetworkIpReleasedNotification,
		NotifierNetworkAirportConnectNotification,
		NotifierNetworkAirportDisconnectNotification,
		nil];

	NSDictionary *regDict = [NSDictionary dictionaryWithObjectsAndKeys:
		@"HardwareGrowler", GROWL_APP_NAME,
		notifications, GROWL_NOTIFICATIONS_ALL,
		notifications, GROWL_NOTIFICATIONS_DEFAULT,
		nil];

	return regDict;
}

- (IBAction) doSimpleHelp: (id)sender {
	[[NSWorkspace sharedWorkspace] openFile:[[NSBundle mainBundle] pathForResource:@"readme" ofType:@"txt"]];
}

#pragma mark -
#pragma mark Notification methods
- (void) willSleep:(NSNotification *)note {
	//NSLog(@"willSleep");
	sleeping = YES;
}

- (void) didWake:(NSNotification *)note {
	//NSLog(@"didWake");
	sleeping = NO;
}

- (void) fwDidConnect:(NSString *)deviceName {
//	NSLog(@"FireWire Connect: %@", deviceName );

	[GrowlApplicationBridge notifyWithTitle:NotifierFireWireConnectionTitle
							description:deviceName
							notificationName:NotifierFireWireConnectionNotification
							iconData:firewireLogoData
							priority:0
							isSticky:NO
							clickContext:nil];

}

- (void) fwDidDisconnect:(NSString *)deviceName {
//	NSLog(@"FireWire Disconnect: %@", deviceName );

	[GrowlApplicationBridge notifyWithTitle:NotifierFireWireDisconnectionTitle
							description:deviceName
							notificationName:NotifierFireWireDisconnectionNotification
							iconData:firewireLogoData
							priority:0
							isSticky:NO
							clickContext:nil];
}

- (void) usbDidConnect:(NSString *)deviceName {
//	NSLog(@"USB Connect: %@", deviceName );
	[GrowlApplicationBridge notifyWithTitle:NotifierUSBConnectionTitle
							description:deviceName
							notificationName:NotifierUSBConnectionNotification
							iconData:usbLogoData
							priority:0
							isSticky:NO
							clickContext:nil];
}

- (void) usbDidDisconnect:(NSString *)deviceName {
//	NSLog(@"USB Disconnect: %@", deviceName );
	[GrowlApplicationBridge notifyWithTitle:NotifierUSBDisconnectionTitle
							description:deviceName
							notificationName:NotifierUSBDisconnectionNotification
							iconData:usbLogoData
							priority:0
							isSticky:NO
							clickContext:nil];
}

- (void) bluetoothDidConnect:(NSString *)device {
//	NSLog(@"Bluetooth Connect: %@", device );
	[GrowlApplicationBridge notifyWithTitle:NotifierBluetoothConnectionTitle
							description:device
							notificationName:NotifierBluetoothConnectionNotification
							iconData:bluetoothLogoData
							priority:0
							isSticky:NO
							clickContext:nil];
}

- (void) bluetoothDidDisconnect:(NSString *)device {
//	NSLog(@"Bluetooth Disconnect: %@", device );
	[GrowlApplicationBridge notifyWithTitle:NotifierBluetoothDisconnectionTitle
							description:device
							notificationName:NotifierBluetoothDisconnectionNotification
							iconData:bluetoothLogoData
							priority:0
							isSticky:NO
							clickContext:nil];
}

- (void) volumeDidMount:(NSString *)path {
	//NSLog(@"volume Mount: %@", path );

	NSData *iconData = [[[NSWorkspace sharedWorkspace] iconForFile:path] TIFFRepresentation];

	[GrowlApplicationBridge notifyWithTitle:NotifierVolumeMountedTitle
							description:[path lastPathComponent]
							notificationName:NotifierVolumeMountedNotification
							iconData:iconData
							priority:0
							isSticky:NO
							clickContext:nil];
}

- (void) volumeDidUnmount:(NSString *)path {
//	NSLog(@"volume UnMount: %@", path );

//	NSData	*iconData = [[[NSWorkspace sharedWorkspace] iconForFile:path] TIFFRepresentation];
	[GrowlApplicationBridge notifyWithTitle:NotifierVolumeUnmountedTitle
							description:[path lastPathComponent]
							notificationName:NotifierVolumeUnmountedNotification
							iconData:ejectLogoData
							priority:0
							isSticky:NO
							clickContext:nil];
}

- (void) airportConnect:(NSString *)description {
	//NSLog(@"AirPort connect: %@", description);

	if (sleeping)
		return;

	[GrowlApplicationBridge notifyWithTitle:NotifierNetworkAirportConnectTitle
								description:description
						   notificationName:NotifierNetworkAirportConnectNotification
								   iconData:airportIconData
								   priority:0
								   isSticky:NO
							   clickContext:nil];
}

- (void) airportDisconnect:(NSString *)description {
	//NSLog(@"AirPort disconnect: %@", description);

	if (sleeping)
		return;

	[GrowlApplicationBridge notifyWithTitle:NotifierNetworkAirportDisconnectTitle
								description:description
						   notificationName:NotifierNetworkAirportDisconnectNotification
								   iconData:airportIconData
								   priority:0
								   isSticky:NO
							   clickContext:nil];
}

- (void) linkUp:(NSString *)description {
	//NSLog(@"Link up: %@", description);

	if (sleeping)
		return;

	[GrowlApplicationBridge notifyWithTitle:NotifierNetworkLinkUpTitle
								description:description
						   notificationName:NotifierNetworkLinkUpNotification
								   iconData:ipIconData
								   priority:0
								   isSticky:NO
							   clickContext:nil];
}

- (void) linkDown:(NSString *)description {
	//NSLog(@"Link down: %@", description);

	if (sleeping)
		return;

	[GrowlApplicationBridge notifyWithTitle:NotifierNetworkLinkDownTitle
								description:description
						   notificationName:NotifierNetworkLinkDownNotification
								   iconData:ipIconData
								   priority:0
								   isSticky:NO
							   clickContext:nil];
}

- (void) ipAcquired:(NSString *)ip {
	//NSLog(@"IP acquired: %@", ip);

	if (sleeping)
		return;

	[GrowlApplicationBridge notifyWithTitle:NotifierNetworkIpAcquiredTitle
								description:[NSString stringWithFormat:NotifierNetworkIpAcquiredDescription, ip]
						   notificationName:NotifierNetworkIpAcquiredNotification
								   iconData:ipIconData
								   priority:0
								   isSticky:NO
							   clickContext:nil];
}

- (void) ipReleased {
	//NSLog(@"IP released");

	if (sleeping)
		return;

	[GrowlApplicationBridge notifyWithTitle:NotifierNetworkIpReleasedTitle
								description:NotifierNetworkIpReleasedDescription
						   notificationName:NotifierNetworkIpReleasedNotification
								   iconData:ipIconData
								   priority:0
								   isSticky:NO
							   clickContext:nil];
}

@end
