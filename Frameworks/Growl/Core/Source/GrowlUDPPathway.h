//
//  GrowlUDPServer.h
//  Growl
//
//  Created by Ingmar Stein on 18.11.04.
//  Copyright 2004-2005 The Growl Project. All rights reserved.
//
// This file is under the BSD License, refer to License.txt for details

#import <Foundation/Foundation.h>
#import "GrowlRemotePathway.h"

@interface GrowlUDPPathway: GrowlRemotePathway {
	NSSocketPort    *sock;
	NSFileHandle    *fh;
	NSImage         *notificationIcon;
}

@end
