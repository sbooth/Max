/*
 *  cdsa.c
 *  Growl
 *
 *  Created by Ingmar Stein on 05.05.05.
 *  Copyright 2005 The Growl Project. All rights reserved.
 */

#include "cdsa.h"

static int cdsaInitialized;

static const CSSM_VERSION cspversion = {2, 0};
static const CSSM_GUID guid = { 0xB057, 0x78, 0xF8, { 0x2,0xD,0x5,0x4,0x4,0xB,0xC,0x7 }};
static const CSSM_API_MEMORY_FUNCS memFuncs = {
	(CSSM_MALLOC)malloc,
	(CSSM_FREE)free,
	(CSSM_REALLOC)realloc,
	(CSSM_CALLOC)calloc,
	NULL
};

CSSM_CSP_HANDLE cspHandle;

CSSM_RETURN cdsaInit(void) {
	if (cdsaInitialized) {
		return CSSM_OK;
	}

	CSSM_RETURN crtn;
	CSSM_PVC_MODE pvcPolicy = CSSM_PVC_NONE;

	/* Initialize CSSM. */
	crtn = CSSM_Init(&cspversion,
					 CSSM_PRIVILEGE_SCOPE_NONE,
					 &guid,
					 CSSM_KEY_HIERARCHY_NONE,
					 &pvcPolicy,
					 /*reserved*/NULL);
	if (crtn) {
		return crtn;
	}

	/* Load the CSP bundle into this app's memory space */
	crtn = CSSM_ModuleLoad(&gGuidAppleCSP,
						   CSSM_KEY_HIERARCHY_NONE,
						   NULL,      // eventHandler
						   NULL);      // AppNotifyCallbackCtx
	if (crtn) {
		return crtn;
	}

	/* Obtain a handle which will be used to refer to the CSP */ 
	crtn = CSSM_ModuleAttach(&gGuidAppleCSP,
							 &cspversion,
							 &memFuncs,      // memFuncs
							 0,          // SubserviceID
							 CSSM_SERVICE_CSP,  
							 0,          // AttachFlags
							 CSSM_KEY_HIERARCHY_NONE,
							 NULL,        // FunctionTable
							 0,          // NumFuncTable
							 NULL,        // reserved
							 &cspHandle);
	if (crtn) {
		return crtn;
	}

	cdsaInitialized = 1;

	return CSSM_OK;
}

void cdsaShutdown(void) {
	CSSM_ModuleDetach(cspHandle);
	CSSM_ModuleUnload(&gGuidAppleCSP,
					  /*AppNotifyCallback*/ NULL,
					  /*AppNotifyCallbackCtx*/ NULL);
	CSSM_Terminate();
}
