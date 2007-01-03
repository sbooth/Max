//
//  GrowlPathway.m
//  Growl
//
//  Created by Ingmar Stein on 15.11.04.
//  Copyright 2004-2005 The Growl Project. All rights reserved.
//
// This file is under the BSD License, refer to License.txt for details

#import "GrowlPathway.h"
#import "GrowlController.h"

@implementation GrowlPathway

- (void) registerApplicationWithDictionary:(NSDictionary *)dict {
	[[GrowlController standardController] registerApplicationWithDictionary:dict];
}

- (void) postNotificationWithDictionary:(NSDictionary *)dict {
	[[GrowlController standardController] dispatchNotificationWithDictionary:dict];
}

- (NSString *) growlVersion {
	return [GrowlController growlVersion];
}
@end
