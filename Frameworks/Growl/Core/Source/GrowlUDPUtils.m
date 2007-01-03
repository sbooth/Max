//
//  GrowlUDPUtils.m
//  Growl
//
//  Created by Ingmar Stein on 20.11.04.
//  Copyright 2004-2005 The Growl Project. All rights reserved.
//

#import "GrowlUDPUtils.h"
#import "GrowlDefines.h"
#import "GrowlDefinesInternal.h"
#include "sha2.h"
#include "cdsa.h"

@implementation GrowlUDPUtils

+ (void) addChecksumToPacket:(CSSM_DATA_PTR)packet authMethod:(enum GrowlAuthenticationMethod)authMethod password:(const CSSM_DATA_PTR)password {
	unsigned       messageLength;
	CSSM_DATA      digestData;
	CSSM_CC_HANDLE ccHandle;
	CSSM_DATA      inData;
	CSSM_RETURN    crtn;

	switch (authMethod) {
		default:
		case GROWL_AUTH_MD5:
			crtn = CSSM_CSP_CreateDigestContext(cspHandle, CSSM_ALGID_MD5, &ccHandle);
			if (crtn)
				cssmPerror("CSSM_CSP_CreateDigestContext", crtn);
			crtn = CSSM_DigestDataInit(ccHandle);
			if (crtn)
				cssmPerror("CSSM_DigestDataInit", crtn);
			messageLength = packet->Length - MD5_DIGEST_LENGTH;
			inData.Data = packet->Data;
			inData.Length = messageLength;
			crtn = CSSM_DigestDataUpdate(ccHandle, &inData, 1U);
			if (crtn)
				cssmPerror("CSSM_DigestDataUpdate", crtn);
			if (password->Data && password->Length) {
				crtn = CSSM_DigestDataUpdate(ccHandle, password, 1U);
				if (crtn)
					cssmPerror("CSSM_DigestDataUpdate", crtn);
			}
			digestData.Data = packet->Data + messageLength;
			digestData.Length = MD5_DIGEST_LENGTH;
			crtn = CSSM_DigestDataFinal(ccHandle, &digestData);
			CSSM_DeleteContext(ccHandle);
			if (crtn)
				cssmPerror("CSSM_DigestDataFinal", crtn);
			break;
		case GROWL_AUTH_SHA256: {
#if MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_4
			crtn = CSSM_CSP_CreateDigestContext(cspHandle, CSSM_ALGID_SHA256, &ccHandle);
			if (crtn)
				cssmPerror("CSSM_CSP_CreateDigestContext", crtn);
			crtn = CSSM_DigestDataInit(ccHandle);
			if (crtn)
				cssmPerror("CSSM_DigestDataInit", crtn);
			messageLength = packet->Length - SHA256_DIGEST_LENGTH;
			inData.Data = packet->Data;
			inData.Length = messageLength;
			crtn = CSSM_DigestDataUpdate(ccHandle, &inData, 1U);
			if (crtn)
				cssmPerror("CSSM_DigestDataUpdate", crtn);
			if (password->Data && password->Length) {
				crtn = CSSM_DigestDataUpdate(ccHandle, password, 1U);
				if (crtn)
					cssmPerror("CSSM_DigestDataUpdate", crtn);
			}
			digestData.Data = packet->Data + messageLength;
			digestData.Length = SHA256_DIGEST_LENGTH;
			crtn = CSSM_DigestDataFinal(ccHandle, &digestData);
			CSSM_DeleteContext(ccHandle);
			if (crtn)
				cssmPerror("CSSM_DigestDataFinal", crtn);
#else
			SHA_CTX sha_ctx;
			messageLength = packet->Length-SHA256_DIGEST_LENGTH;
			SHA256_Init(&sha_ctx);
			SHA256_Update(&sha_ctx, packet->Data, messageLength);
			if (password->Data && password->Length)
				SHA256_Update(&sha_ctx, password->Data, password->Length);
			SHA256_Final(packet->Data + messageLength, &sha_ctx);
#endif
			break;
		}
		case GROWL_AUTH_NONE:
			break;
	}
}

+ (unsigned char *) notificationToPacket:(NSDictionary *)aNotification digest:(enum GrowlAuthenticationMethod)authMethod password:(const char *)password packetSize:(unsigned *)packetSize {
	struct GrowlNetworkNotification *nn;
	unsigned char *data;
	size_t length;
	unsigned short notificationNameLen, titleLen, descriptionLen, applicationNameLen;
	unsigned digestLength;
	CSSM_DATA packetData, passwordData;

	const char *notificationName = [[aNotification objectForKey:GROWL_NOTIFICATION_NAME] UTF8String];
	const char *applicationName  = [[aNotification objectForKey:GROWL_APP_NAME] UTF8String];
	const char *title            = [[aNotification objectForKey:GROWL_NOTIFICATION_TITLE] UTF8String];
	const char *description      = [[aNotification objectForKey:GROWL_NOTIFICATION_DESCRIPTION] UTF8String];
	notificationNameLen = strlen(notificationName);
	applicationNameLen  = strlen(applicationName);
	titleLen            = strlen(title);
	descriptionLen      = strlen(description);

	NSNumber *priority = [aNotification objectForKey:GROWL_NOTIFICATION_PRIORITY];
	NSNumber *isSticky = [aNotification objectForKey:GROWL_NOTIFICATION_STICKY];

	switch (authMethod) {
		case GROWL_AUTH_NONE:
			digestLength = 0U;
			break;
		default:
		case GROWL_AUTH_MD5:
			digestLength = MD5_DIGEST_LENGTH;
			break;
		case GROWL_AUTH_SHA256:
			digestLength = SHA256_DIGEST_LENGTH;
			break;
	}
	length = sizeof(*nn) + notificationNameLen + applicationNameLen + titleLen + descriptionLen + digestLength;

	nn = (struct GrowlNetworkNotification *)malloc(length);
	nn->common.version = GROWL_PROTOCOL_VERSION;
	switch (authMethod) {
		default:
		case GROWL_AUTH_MD5:
			nn->common.type     = GROWL_TYPE_NOTIFICATION;
			break;
		case GROWL_AUTH_SHA256:
			nn->common.type     = GROWL_TYPE_NOTIFICATION_SHA256;
			break;
		case GROWL_AUTH_NONE:
			nn->common.type     = GROWL_TYPE_NOTIFICATION_NOAUTH;
			break;
	}
	nn->flags.reserved = 0;
	nn->flags.priority = [priority intValue];
	nn->flags.sticky   = [isSticky boolValue];
	nn->nameLen        = htons(notificationNameLen);
	nn->titleLen       = htons(titleLen);
	nn->descriptionLen = htons(descriptionLen);
	nn->appNameLen     = htons(applicationNameLen);
	data = nn->data;
	memcpy(data, notificationName, notificationNameLen);
	data += notificationNameLen;
	memcpy(data, title, titleLen);
	data += titleLen;
	memcpy(data, description, descriptionLen);
	data += descriptionLen;
	memcpy(data, applicationName, applicationNameLen);
	data += applicationNameLen;

	packetData.Data = (unsigned char *)nn;
	packetData.Length = length;
	passwordData.Data = (uint8 *)password;
	if (password) {
		passwordData.Length = strlen(password);
	} else {
		passwordData.Length = 0U;
	}
	[GrowlUDPUtils addChecksumToPacket:&packetData authMethod:authMethod password:&passwordData];

	*packetSize = length;

	return (unsigned char *)nn;
}

#warning we need a way to handle the unlikely but fully-possible case wherein the dictionary contains more All notifications than the 8-bit Default indices can hold (Zero-One-Infinity) - first stage would be to try moving all the default notifications to the lower indices of the All array, second stage would be to create multiple packets

+ (unsigned char *) registrationToPacket:(NSDictionary *)aNotification digest:(enum GrowlAuthenticationMethod)authMethod password:(const char *)password packetSize:(unsigned *)packetSize {
	struct GrowlNetworkRegistration *nr;
	unsigned char *data;
	const char *notification;
	unsigned i, size, notificationIndex, digestLength;
	size_t length;
	unsigned short applicationNameLen;
	unsigned numAllNotifications, numDefaultNotifications;
	Class NSNumberClass = [NSNumber class];
	CSSM_DATA packetData, passwordData;

	const char *applicationName   = [[aNotification objectForKey:GROWL_APP_NAME] UTF8String];
	NSArray *allNotifications     = [aNotification objectForKey:GROWL_NOTIFICATIONS_ALL];
	NSArray *defaultNotifications = [aNotification objectForKey:GROWL_NOTIFICATIONS_DEFAULT];
	applicationNameLen            = strlen(applicationName);
	numAllNotifications           = [allNotifications count];
	numDefaultNotifications       = [defaultNotifications count];

	// compute packet size
	switch (authMethod) {
		case GROWL_AUTH_NONE:
			digestLength = 0U;
			break;
		default:
		case GROWL_AUTH_MD5:
			digestLength = MD5_DIGEST_LENGTH;
			break;
		case GROWL_AUTH_SHA256:
			digestLength = SHA256_DIGEST_LENGTH;
			break;
	}
	length = sizeof(*nr) + applicationNameLen + digestLength;
	for (i = 0; i < numAllNotifications; ++i) {
		notification  = [[allNotifications objectAtIndex:i] UTF8String];
		length       += sizeof(unsigned short) + strlen(notification);
	}
	size = numDefaultNotifications;
	for (i = 0; i < numDefaultNotifications; ++i) {
		NSNumber *num = [defaultNotifications objectAtIndex:i];
		if ([num isKindOfClass:NSNumberClass]) {
			notificationIndex = [num unsignedIntValue];
			if (notificationIndex >= numAllNotifications) {
				NSLog(@"Warning: index %u found in defaultNotifications is not within the range (%u) of the notifications array", notificationIndex, numAllNotifications);
				--size;
			} else if (notificationIndex > UCHAR_MAX) {
				NSLog(@"Warning: index %u found in defaultNotifications is not within the range (%u) of an 8-bit unsigned number", notificationIndex);
				--size;
			} else {
				++length;
			}
		} else {
			notificationIndex = [allNotifications indexOfObject:num];
			if (notificationIndex == NSNotFound) {
				NSLog(@"Warning: defaultNotifications is not a subset of allNotifications (object found in defaultNotifications that is not in allNotifications; description of object is %@)", num);
				--size;
			} else {
				++length;
			}
		}
	}

	nr = (struct GrowlNetworkRegistration *)malloc(length);
	nr->common.version          = GROWL_PROTOCOL_VERSION;
	switch (authMethod) {
		default:
		case GROWL_AUTH_MD5:
			nr->common.type     = GROWL_TYPE_REGISTRATION;
			break;
		case GROWL_AUTH_SHA256:
			nr->common.type     = GROWL_TYPE_REGISTRATION_SHA256;
			break;
		case GROWL_AUTH_NONE:
			nr->common.type     = GROWL_TYPE_REGISTRATION_NOAUTH;
			break;
	}
	nr->appNameLen              = htons(applicationNameLen);
	nr->numAllNotifications     = (unsigned char)numAllNotifications;
	nr->numDefaultNotifications = (unsigned char)size;
	data = nr->data;
	memcpy(data, applicationName, applicationNameLen);
	data += applicationNameLen;
	for (i = 0; i < numAllNotifications; ++i) {
		notification = [[allNotifications objectAtIndex:i] UTF8String];
		size = strlen(notification);
		*(unsigned short *)data = htons(size);
		data += sizeof(unsigned short);
		memcpy(data, notification, size);
		data += size;
	}
	for (i = 0; i < numDefaultNotifications; ++i) {
		NSNumber *num = [defaultNotifications objectAtIndex:i];
		if ([num isKindOfClass:NSNumberClass]) {
			notificationIndex = [num unsignedIntValue];
			if ((notificationIndex <  numAllNotifications)
			&& (notificationIndex <= UCHAR_MAX)) {
				*data++ = notificationIndex;
			}
		} else {
			notificationIndex = [allNotifications indexOfObject:num];
			if ((notificationIndex <  numAllNotifications)
			&& (notificationIndex <= UCHAR_MAX)
			&& (notificationIndex != NSNotFound)) {
				*data++ = notificationIndex;
			}
		}
	}

	packetData.Data = (unsigned char *)nr;
	packetData.Length = length;
	passwordData.Data = (uint8 *)password;
	if (password) {
		passwordData.Length = strlen(password);
	} else {
		passwordData.Length = 0U;
	}
	[GrowlUDPUtils addChecksumToPacket:&packetData authMethod:authMethod password:&passwordData];
	
	*packetSize = length;

	return (unsigned char *)nr;
}

static uint8 iv[16] = { 0U,0U,0U,0U,0U,0U,0U,0U,0U,0U,0U,0U,0U,0U,0U,0U };
static const CSSM_DATA ivCommon = {16U, iv};

+ (void) cryptPacket:(CSSM_DATA_PTR)packet algorithm:(CSSM_ALGORITHMS)algorithm password:(CSSM_DATA_PTR)password encrypt:(BOOL)encrypt {
	CSSM_CC_HANDLE ccHandle;
	CSSM_KEY key;
	CSSM_DATA inData;
	CSSM_DATA remData;
	CSSM_CRYPTO_DATA seed;
	CSSM_RETURN crtn;
	uint32 bytesCrypted;

	seed.Param = *password;
	seed.Callback = NULL;
	seed.CallerCtx = NULL;

	crtn = CSSM_CSP_CreateDeriveKeyContext(cspHandle, CSSM_ALGID_PKCS12_PBE_ENCR,
										   algorithm, 128U,
										   /*AccessCred*/ NULL,
										   /*BaseKey*/ NULL,
										   /*IterationCount*/ 1U,
										   /*Salt*/ NULL,
										   /*Seed*/ &seed,
										   &ccHandle);
	crtn = CSSM_DeriveKey(ccHandle,
						  (CSSM_DATA_PTR)&ivCommon,
						  encrypt ? CSSM_KEYUSE_ENCRYPT : CSSM_KEYUSE_DECRYPT,
						  /*KeyAttr*/ 0U,
						  /*KeyLabel*/ NULL,
						  /*CredAndAclEntry*/ NULL,
						  &key);
	CSSM_DeleteContext(ccHandle);

	crtn = CSSM_CSP_CreateSymmetricContext(cspHandle,
										   algorithm,
										   CSSM_ALGMODE_CBCPadIV8,
										   /*AccessCred*/ NULL,
										   &key,
										   &ivCommon,
										   CSSM_PADDING_PKCS7,	
										   /*Reserved*/ NULL,
										   &ccHandle);

	inData.Data = packet->Data + 1;	// skip the version byte
	inData.Length = packet->Length - 1;
	remData.Data = NULL;
	remData.Length = 0U;
	if (encrypt) {
		crtn = CSSM_EncryptData(ccHandle,
								&inData,
								1U,
								&inData,
								1U,
								&bytesCrypted,
								&remData);
		if (remData.Length) {
			unsigned newlength = packet->Length + remData.Length;
			packet->Data = realloc(packet->Data, newlength);
			memcpy(packet->Data + packet->Length, remData.Data, remData.Length);
			packet->Length = newlength;
		}
		packet->Data[0] = GROWL_PROTOCOL_VERSION_AES128;	// adjust version byte
	} else {
		crtn = CSSM_DecryptData(ccHandle,
								&inData,
								1U,
								&inData,
								1U,
								&bytesCrypted,
								&remData);
		packet->Data[0] = GROWL_PROTOCOL_VERSION;	// adjust version byte
	}
	packet->Length = bytesCrypted + 1;
	if (remData.Data) {
		free(remData.Data);
	}

	CSSM_DeleteContext(ccHandle);
	CSSM_FreeKey(cspHandle,
				 /*AccessCred*/ NULL,
				 &key,
				 /*Delete*/ CSSM_FALSE);
}
@end
