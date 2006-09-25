//
//  MD5Authenticator.m
//  Growl
//
//  Created by Ingmar Stein on 24.04.05.
//  Copyright 2005 The Growl Project. All rights reserved.
//

#import "MD5Authenticator.h"
#import "cdsa.h"

#define keychainServiceName "Growl"
#define keychainAccountName "Growl"

@implementation MD5Authenticator
- (id) initWithPassword:(NSString *)pwd {
	if ((self = [super init])) {
		password = [pwd copy];
	}
	return self;
}

- (void) dealloc {
	[password release];
	[super dealloc];
}

- (NSData *) authenticationDataForComponents:(NSArray *)components {
	NSEnumerator   *e;
	OSStatus       status;
	char           *passwordBytes;
	UInt32         passwordLength;
	CSSM_DATA      digestData;
	CSSM_RETURN    crtn;
	CSSM_CC_HANDLE ccHandle;
	CSSM_DATA      inData;

	crtn = CSSM_CSP_CreateDigestContext(cspHandle, CSSM_ALGID_MD5, &ccHandle);
	if (crtn) {
		return nil;
	}

	crtn = CSSM_DigestDataInit(ccHandle);
	if (crtn) {
		CSSM_DeleteContext(ccHandle);
		return nil;
	}

	e = [components objectEnumerator];
	id item;
	while ((item = [e nextObject])) {
		if ([item isKindOfClass:[NSData class]]) {
			NSData *dataItem = item;
			inData.Data = (uint8 *)[dataItem bytes];
			inData.Length = [dataItem length];
			crtn = CSSM_DigestDataUpdate(ccHandle, &inData, 1U);
			if (crtn) {
				CSSM_DeleteContext(ccHandle);
				return nil;
			}
		}
	}

	if (password) {
		passwordBytes = (char *)[password UTF8String];
		inData.Data = (uint8 *)passwordBytes;
		inData.Length = strlen(passwordBytes);
		crtn = CSSM_DigestDataUpdate(ccHandle, &inData, 1U);
		if (crtn) {
			CSSM_DeleteContext(ccHandle);
			return nil;
		}
	} else {
		status = SecKeychainFindGenericPassword( /*keychainOrArray*/ NULL,
												 strlen(keychainServiceName), keychainServiceName,
												 strlen(keychainAccountName), keychainAccountName,
												 &passwordLength, (void **)&passwordBytes,
												 NULL);
		if (status == noErr) {
			inData.Data = (uint8 *)passwordBytes;
			inData.Length = passwordLength;
			crtn = CSSM_DigestDataUpdate(ccHandle, &inData, 1U);
			SecKeychainItemFreeContent(/*attrList*/ NULL, passwordBytes);
			if (crtn) {
				CSSM_DeleteContext(ccHandle);
				return nil;
			}
		} else if (status != errSecItemNotFound) {
			NSLog(@"Failed to retrieve password from keychain. Error: %d", status);
		}
	}

	digestData.Data = NULL;
	digestData.Length = 0U;
	crtn = CSSM_DigestDataFinal(ccHandle, &digestData);
	CSSM_DeleteContext(ccHandle);
	if (crtn) {
		CSSM_DeleteContext(ccHandle);
		return nil;
	}

	return [NSData dataWithBytesNoCopy:digestData.Data length:digestData.Length freeWhenDone:YES];
}

- (BOOL) authenticateComponents:(NSArray *)components withData:(NSData *)signature {
	NSData *recomputedSignature = [self authenticationDataForComponents:components];

	// If the two NSDatas are not equal, authentication failure!
	if (![recomputedSignature isEqual:signature]) {
		NSLog(@"authentication failure: received signature doesn't match computed signature");
		return NO;
	}
	return YES;
}

@end
