//
//  GrowlUDPServer.m
//  Growl
//
//  Created by Ingmar Stein on 18.11.04.
//  Copyright 2004-2005 The Growl Project. All rights reserved.
//
// This file is under the BSD License, refer to License.txt for details

#import "GrowlUDPPathway.h"
#import "NSStringAdditions.h"
#import "GrowlDefinesInternal.h"
#import "GrowlDefines.h"
#import "GrowlPreferences.h"
#import "GrowlUDPUtils.h"
#import "sha2.h"
#import "cdsa.h"
#include <netinet/in.h>
#include <sys/types.h>
#include <sys/socket.h>

#define keychainServiceName "Growl"
#define keychainAccountName "Growl"

@implementation GrowlUDPPathway

- (id) init {
	struct sockaddr_in addr;
	NSData *addrData;

	if ((self = [super init])) {
		short port = [[GrowlPreferences preferences] integerForKey:GrowlUDPPortKey];
		addr.sin_len = sizeof(addr);
		addr.sin_family = AF_INET;
		addr.sin_port = htons(port);
		addr.sin_addr.s_addr = INADDR_ANY;
		memset(&addr.sin_zero, 0, sizeof(addr.sin_zero));
		addrData = [NSData dataWithBytes:&addr length:sizeof(addr)];
		sock = [[NSSocketPort alloc] initWithProtocolFamily:AF_INET
												 socketType:SOCK_DGRAM
												   protocol:IPPROTO_UDP
													address:addrData];

		if (!sock) {
			NSLog(@"GrowlUDPPathway: could not create socket.");
			[self release];
			return nil;
		}

		fh = [[NSFileHandle alloc] initWithFileDescriptor:[sock socket]];
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(fileHandleRead:)
													 name:NSFileHandleReadCompletionNotification
												   object:fh];
		[fh readInBackgroundAndNotify];
		notificationIcon = [[NSImage alloc] initWithContentsOfFile:
			@"/System/Library/CoreServices/SystemIcons.bundle/Contents/Resources/GenericNetworkIcon.icns"];
		if (!notificationIcon) {
			// the icon has moved on 10.4
			notificationIcon = [[NSImage alloc] initWithContentsOfFile:
				@"/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericNetworkIcon.icns"];
		}
	}

	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self
													name:NSFileHandleReadCompletionNotification
												  object:nil];
	[notificationIcon release];
	[fh release];
	[sock release];

	[super dealloc];
}

#pragma mark -
+ (BOOL) authenticateWithCSSM:(const CSSM_DATA_PTR)packet algorithm:(CSSM_ALGORITHMS)digestAlg digestLength:(unsigned)digestLength password:(const CSSM_DATA_PTR)password {
	unsigned       messageLength;
	CSSM_DATA      digestData;
	CSSM_RETURN    crtn;
	CSSM_CC_HANDLE ccHandle;
	CSSM_DATA      inData;

	crtn = CSSM_CSP_CreateDigestContext(cspHandle, digestAlg, &ccHandle);
	if (crtn) {
		cssmPerror("CSSM_CSP_CreateDigestContext", crtn);
		return NO;
	}

	crtn = CSSM_DigestDataInit(ccHandle);
	if (crtn) {
		cssmPerror("CSSM_DigestDataInit", crtn);
		CSSM_DeleteContext(ccHandle);
		return NO;
	}

	messageLength = packet->Length - digestLength;
	inData.Data = (uint8 *)packet->Data;
	inData.Length = messageLength;
	crtn = CSSM_DigestDataUpdate(ccHandle, &inData, 1U);
	if (crtn) {
		cssmPerror("CSSM_DigestDataUpdate", crtn);
		CSSM_DeleteContext(ccHandle);
		return NO;
	}

	if (password->Data && password->Length) {
		crtn = CSSM_DigestDataUpdate(ccHandle, password, 1U);
		if (crtn) {
			cssmPerror("CSSM_DigestDataUpdate", crtn);
			CSSM_DeleteContext(ccHandle);
			return NO;
		}
	}

	digestData.Data = NULL;
	digestData.Length = 0U;
	crtn = CSSM_DigestDataFinal(ccHandle, &digestData);
	CSSM_DeleteContext(ccHandle);
	if (crtn) {
		cssmPerror("CSSM_DigestDataFinal", crtn);
		return NO;
	}

	BOOL authenticated;
	if (digestData.Length != digestLength) {
		NSLog(@"GrowlUDPPathway: digestData.Length != digestLength (%u != %u)", digestData.Length, digestLength);
		authenticated = NO;
	} else {
		authenticated = !memcmp(digestData.Data, packet->Data+messageLength, digestData.Length);
	}
	free(digestData.Data);

	return authenticated;
}

+ (BOOL) authenticatePacket:(const CSSM_DATA_PTR)packet password:(const CSSM_DATA_PTR)password authMethod:(enum GrowlAuthenticationMethod)authMethod {
	switch (authMethod) {
		default:
		case GROWL_AUTH_MD5:
			return [GrowlUDPPathway authenticateWithCSSM:packet
											   algorithm:CSSM_ALGID_MD5
											digestLength:MD5_DIGEST_LENGTH
												password:password];
		case GROWL_AUTH_SHA256: {
#if MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_4
			// CSSM_ALGID_SHA256 is only available on Mac OS X >= 10.4
			return [GrowlUDPPathway authenticateWithCSSM:packet
											   algorithm:CSSM_ALGID_SHA256
											digestLength:SHA256_DIGEST_LENGTH
												password:password];
#else
			unsigned messageLength;
			SHA_CTX ctx;
			unsigned char digest[SHA256_DIGEST_LENGTH];

			messageLength = packet->Length-sizeof(digest);
			SHA256_Init(&ctx);
			SHA256_Update(&ctx, packet->Data, messageLength);
			if (password->Data && password->Length)
				SHA256_Update(&ctx, password->Data, password->Length);
			SHA256_Final(digest, &ctx);

			return !memcmp(digest, packet->Data+messageLength, sizeof(digest));
#endif
		}
		case GROWL_AUTH_NONE:
			return !password->Length;
	}
}

#pragma mark -

- (void) fileHandleRead:(NSNotification *)aNotification {
	char *notificationName;
	char *title;
	char *description;
	char *applicationName;
	char *notification;
	unsigned notificationNameLen, titleLen, descriptionLen, priority, applicationNameLen;
	unsigned length, num, i, size, packetSize, notificationIndex;
	unsigned digestLength;
	int error;
	BOOL isSticky;
	enum GrowlAuthenticationMethod authMethod;
	CSSM_DATA packetData;
	CSSM_DATA passwordData;

	NSDictionary *userInfo = [aNotification userInfo];
	error = [[userInfo objectForKey:@"NSFileHandleError"] intValue];

	if (!error) {
		NSData *data = [userInfo objectForKey:NSFileHandleNotificationDataItem];
		length = [data length];

		if (length >= sizeof(struct GrowlNetworkPacket)) {
			struct GrowlNetworkPacket *packet = (struct GrowlNetworkPacket *)[data bytes];
			packetData.Data = (uint8 *)packet;
			packetData.Length = length;

			if (packet->version == GROWL_PROTOCOL_VERSION || packet->version == GROWL_PROTOCOL_VERSION_AES128) {
				unsigned char *password = NULL;
				OSStatus status;
				UInt32 passwordLength = 0U;

				status = SecKeychainFindGenericPassword(/*keychainOrArray*/ NULL,
														strlen(keychainServiceName), keychainServiceName,
														strlen(keychainAccountName), keychainAccountName,
														&passwordLength, (void **)&password, NULL);

				if (status == noErr) {
					passwordData.Data = password;
					passwordData.Length = passwordLength;
				} else {
					if (status != errSecItemNotFound)
						NSLog(@"Failed to retrieve password from keychain. Error: %d", status);
					passwordData.Data = NULL;
					passwordData.Length = 0U;
				}

				if (packet->version == GROWL_PROTOCOL_VERSION_AES128) {
					[GrowlUDPUtils cryptPacket:&packetData
									 algorithm:CSSM_ALGID_AES
									  password:&passwordData
									   encrypt:NO];
					length = packetData.Length;
				}
				switch (packet->type) {
					case GROWL_TYPE_REGISTRATION:
					case GROWL_TYPE_REGISTRATION_SHA256:
					case GROWL_TYPE_REGISTRATION_NOAUTH:
						if (length >= sizeof(struct GrowlNetworkRegistration)) {
							BOOL enabled = [[GrowlPreferences preferences] boolForKey:GrowlRemoteRegistrationKey];

							if (enabled) {
								BOOL valid = YES;
								struct GrowlNetworkRegistration *nr = (struct GrowlNetworkRegistration *)packet;
								applicationName = (char *)nr->data;
								applicationNameLen = ntohs(nr->appNameLen);

								// check packet size
								switch (packet->type) {
									default:
									case GROWL_TYPE_REGISTRATION:
										authMethod = GROWL_AUTH_MD5;
										digestLength = MD5_DIGEST_LENGTH;
										break;
									case GROWL_TYPE_REGISTRATION_SHA256:
										authMethod = GROWL_AUTH_SHA256;
										digestLength = SHA256_DIGEST_LENGTH;
										break;
									case GROWL_TYPE_REGISTRATION_NOAUTH:
										authMethod = GROWL_AUTH_NONE;
										digestLength = 0U;
										break;
								}
								packetSize = sizeof(*nr) + nr->numDefaultNotifications + applicationNameLen + digestLength;
								if (packetSize > length) {
									valid = NO;
								} else {
									num = nr->numAllNotifications;
									notification = applicationName + applicationNameLen;
									for (i = 0U; i < num; ++i) {
										if (packetSize >= length) {
											valid = NO;
											break;
										}
										size = ntohs(*(unsigned short *)notification) + sizeof(unsigned short);
										notification += size;
										packetSize += size;
									}
									if (packetSize != length) {
										valid = NO;
									}
								}

								if (valid) {
									// all notifications
									num = nr->numAllNotifications;
									notification = applicationName + applicationNameLen;
									NSMutableArray *allNotifications = [[NSMutableArray alloc] initWithCapacity:num];
									for (i = 0U; i < num; ++i) {
										size = ntohs(*(unsigned short *)notification);
										notification += sizeof(unsigned short);
										NSString *n = [[NSString alloc] initWithUTF8String:notification length:size];
										[allNotifications addObject:n];
										[n release];
										notification += size;
									}

									// default notifications
									num = nr->numDefaultNotifications;
									NSMutableArray *defaultNotifications = [[NSMutableArray alloc] initWithCapacity:num];
									for (i = 0U; i < num; ++i) {
										notificationIndex = *notification++;
										if (notificationIndex < nr->numAllNotifications) {
											[defaultNotifications addObject:[allNotifications objectAtIndex: notificationIndex]];
										} else {
											NSLog(@"GrowlUDPServer: Bad notification index: %u", notificationIndex);
										}
									}

									if ([GrowlUDPPathway authenticatePacket:&packetData password:&passwordData authMethod:authMethod]) {
										NSString *appName = [[NSString alloc] initWithUTF8String:applicationName length:applicationNameLen];
										NSDictionary *registerInfo = [[NSDictionary alloc] initWithObjectsAndKeys:
											appName,              GROWL_APP_NAME,
											allNotifications,     GROWL_NOTIFICATIONS_ALL,
											defaultNotifications, GROWL_NOTIFICATIONS_DEFAULT,
											nil];
										[appName release];
										[self registerApplicationWithDictionary:registerInfo];
										[registerInfo release];
									} else {
										NSLog(@"GrowlUDPServer: authentication failed.");
									}

									[allNotifications     release];
									[defaultNotifications release];
								} else {
									NSLog(@"GrowlUDPServer: received invalid registration packet.");
								}
							}
						} else {
							NSLog(@"GrowlUDPServer: received runt registration packet.");
						}
						break;
					case GROWL_TYPE_NOTIFICATION:
					case GROWL_TYPE_NOTIFICATION_SHA256:
					case GROWL_TYPE_NOTIFICATION_NOAUTH:
						if (length >= sizeof(struct GrowlNetworkNotification)) {
							struct GrowlNetworkNotification *nn = (struct GrowlNetworkNotification *)packet;

							priority = nn->flags.priority;
							isSticky = nn->flags.sticky;
							notificationName = (char *)nn->data;
							notificationNameLen = ntohs(nn->nameLen);
							title = notificationName + notificationNameLen;
							titleLen = ntohs(nn->titleLen);
							description = title + titleLen;
							descriptionLen = ntohs(nn->descriptionLen);
							applicationName = description + descriptionLen;
							applicationNameLen = ntohs(nn->appNameLen);
							switch (packet->type) {
								default:
								case GROWL_TYPE_NOTIFICATION:
									authMethod = GROWL_AUTH_MD5;
									digestLength = MD5_DIGEST_LENGTH;
									break;
								case GROWL_TYPE_NOTIFICATION_SHA256:
									authMethod = GROWL_AUTH_SHA256;
									digestLength = SHA256_DIGEST_LENGTH;
									break;
								case GROWL_TYPE_NOTIFICATION_NOAUTH:
									authMethod = GROWL_AUTH_NONE;
									digestLength = 0U;
									break;
							}
							packetSize = sizeof(*nn) + notificationNameLen + titleLen + descriptionLen + applicationNameLen + digestLength;

							if (length == packetSize) {
								if ([GrowlUDPPathway authenticatePacket:&packetData password:&passwordData authMethod:authMethod]) {
									NSString *growlNotificationName = [[NSString alloc] initWithUTF8String:notificationName length:notificationNameLen];
									NSString *growlAppName = [[NSString alloc] initWithUTF8String:applicationName length:applicationNameLen];
									NSString *growlNotificationTitle = [[NSString alloc] initWithUTF8String:title length:titleLen];
									NSString *growlNotificationDesc = [[NSString alloc] initWithUTF8String:description length:descriptionLen];
									NSNumber *growlNotificationPriority = [[NSNumber alloc] initWithInt:priority];
									NSNumber *growlNotificationSticky = [[NSNumber alloc] initWithBool:isSticky];
									NSDictionary *notificationInfo = [[NSDictionary alloc] initWithObjectsAndKeys:
										growlNotificationName,     GROWL_NOTIFICATION_NAME,
										growlAppName,              GROWL_APP_NAME,
										growlNotificationTitle,    GROWL_NOTIFICATION_TITLE,
										growlNotificationDesc,     GROWL_NOTIFICATION_DESCRIPTION,
										growlNotificationPriority, GROWL_NOTIFICATION_PRIORITY,
										growlNotificationSticky,   GROWL_NOTIFICATION_STICKY,
										notificationIcon,          GROWL_NOTIFICATION_ICON,
										nil];
									[growlNotificationName     release];
									[growlAppName              release];
									[growlNotificationTitle    release];
									[growlNotificationDesc     release];
									[growlNotificationPriority release];
									[growlNotificationSticky   release];
									[self postNotificationWithDictionary:notificationInfo];
									[notificationInfo release];
								} else {
									NSLog(@"GrowlUDPServer: authentication failed.");
								}
							} else {
								NSLog(@"GrowlUDPServer: received invalid notification packet.");
							}
						} else {
							NSLog(@"GrowlUDPServer: received runt notification packet.");
						}
						break;
					default:
						NSLog(@"GrowlUDPServer: received packet of invalid type.");
						break;
				}
				if (password) {
					SecKeychainItemFreeContent(/*attrList*/ NULL, password);
				}
			} else {
				NSLog(@"GrowlUDPServer: unknown version %u, expected %d or %d", packet->version, GROWL_PROTOCOL_VERSION, GROWL_PROTOCOL_VERSION_AES128);
			}
		} else {
			NSLog(@"GrowlUDPServer: received runt packet.");
		}
	} else {
		NSLog(@"GrowlUDPServer: error %d.", error);
	}

	[fh readInBackgroundAndNotify];
}

@end
