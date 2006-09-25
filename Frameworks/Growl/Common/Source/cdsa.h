/*
 *  cdsa.h
 *  Growl
 *
 *  Created by Ingmar Stein on 05.05.05.
 *  Copyright 2005 The Growl Project. All rights reserved.
 */

#import <Security/Security.h>

#ifndef CSSM_ALGID_SHA256
# define CSSM_ALGID_SHA256		0x8000000E
#endif
#ifndef SHA256_DIGEST_LENGTH
# define SHA256_DIGEST_LENGTH	32
#endif
#ifndef MD5_DIGEST_LENGTH
# define MD5_DIGEST_LENGTH		16
#endif

extern CSSM_CSP_HANDLE cspHandle;

CSSM_RETURN cdsaInit(void);
void cdsaShutdown(void);
