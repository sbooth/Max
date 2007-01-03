//
//  NSDictionaryAdditions.m
//  Growl
//
//  Created by Ingmar Stein on 29.05.05.
//  Copyright 2005 The Growl Project. All rights reserved.
//
// This file is under the BSD License, refer to License.txt for details

#import "NSDictionaryAdditions.h"

@implementation NSDictionary(GrowlAdditions)
- (BOOL) boolForKey:(NSString *)key {
	id object = [self objectForKey:key];
	if (object && [object respondsToSelector:@selector(boolValue)])
		return [object boolValue];
	else
		return NO;
}

- (int) integerForKey:(NSString *)key {
	id object = [self objectForKey:key];
	if (object && [object respondsToSelector:@selector(intValue)])
		return [object intValue];
	else
		return 0;
}

@end
