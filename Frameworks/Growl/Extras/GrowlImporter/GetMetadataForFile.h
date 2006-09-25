/*
 *  GetMetadataForFile.h
 *  GrowlImporter
 *
 *  Created by Ingmar Stein on 30.03.05.
 *  Copyright 2005 __MyCompanyName__. All rights reserved.
 *
 */

#include <CoreFoundation/CoreFoundation.h>

#ifndef _GET_METADATA_FOR_FILE_H_
#define _GET_METADATA_FOR_FILE_H_

Boolean GetMetadataForFile(void *thisInterface, 
						   CFMutableDictionaryRef attributes, 
						   CFStringRef contentTypeUTI,
						   CFStringRef pathToFile);

#endif
