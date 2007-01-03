//
//  GrowlUDPUtils.h
//  Growl
//
//  Created by Ingmar Stein on 20.11.04.
//  Copyright 2004-2005 The Growl Project. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Security/Security.h>

enum GrowlAuthenticationMethod {
	GROWL_AUTH_NONE,
	GROWL_AUTH_MD5,
	GROWL_AUTH_SHA256
};

@interface GrowlUDPUtils : NSObject {
}
+ (unsigned char *) registrationToPacket:(NSDictionary *)aNotification digest:(enum GrowlAuthenticationMethod)authMethod password:(const char *)password packetSize:(unsigned *)packetSize;
+ (unsigned char *) notificationToPacket:(NSDictionary *)aNotification digest:(enum GrowlAuthenticationMethod)authMethod password:(const char *)password packetSize:(unsigned *)packetSize;
+ (void) cryptPacket:(CSSM_DATA_PTR)packet algorithm:(CSSM_ALGORITHMS)algorithm password:(CSSM_DATA_PTR)password encrypt:(BOOL)encrypt;

@end
