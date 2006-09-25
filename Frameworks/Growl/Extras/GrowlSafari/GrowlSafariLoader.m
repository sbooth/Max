//
//  GrowlSafariLoader.m
//  GrowlSafari
//
//  Created by Ingmar Stein on 30.05.05.
//  Copyright 2005 The Growl Project. All rights reserved.
//

#import "GrowlSafariLoader.h"

@implementation GrowlSafariLoader

+ (void) load {
	if ([[[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString *)kCFBundleIdentifierKey] isEqualToString:@"com.apple.Safari"]) {
		NSBundle *loaderBundle = [NSBundle bundleForClass:[GrowlSafariLoader class]];
		NSString *growlSafariPath = [[loaderBundle builtInPlugInsPath] stringByAppendingPathComponent:@"GrowlSafari.bundle"];
		NSBundle *growlSafariBundle = [NSBundle bundleWithPath:growlSafariPath];
		if (!(growlSafariBundle && [growlSafariBundle load]))
			NSLog(@"GrowlSafariLoader: could not load %@", growlSafariPath);
	}
}

@end
