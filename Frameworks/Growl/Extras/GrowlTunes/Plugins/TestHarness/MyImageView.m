//
//  MyImageView.m
//  TestHarness
//
//  Created by Kevin Ballard on 9/29/04.
//  Copyright 2004 TildeSoft. All rights reserved.
//

#import "MyImageView.h"


@implementation MyImageView

- (unsigned int) draggingSourceOperationMaskForLocal:(BOOL)isLocal {
	if ([self image]) {
		return NSDragOperationCopy;
	} else {
		return NSDragOperationNone;
	}
}

- (BOOL) ignoreModifierKeysWhileDragging {
	return YES;
}

- (void) mouseDown:(NSEvent *)event {
	if ([self image]) {
		NSPoint point = [self convertPoint:[event locationInWindow] fromView:nil];
		NSRect rect = NSMakeRect(point.x - 16.0, point.y - 16.0, 32.0, 32.0);
		[self dragPromisedFilesOfTypes:[NSArray arrayWithObject:@"tiff"] fromRect:rect source:self slideBack:YES event:event];
	}
}

- (NSArray *)namesOfPromisedFilesDroppedAtDestination:(NSURL *)dropDestination {
	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *basePath = [[dropDestination path] stringByAppendingPathComponent:@"GrowlTunes Image"];
	NSString *path = [basePath stringByAppendingPathExtension:@"tiff"];
	int i = 0;
	while ([fm fileExistsAtPath:path]) {
		path = [[basePath stringByAppendingFormat:@" %i", ++i] stringByAppendingPathExtension:@"tiff"];
	}
	[fm createFileAtPath:path contents:[[self image] TIFFRepresentation] attributes:nil];
	return [NSArray arrayWithObject:[path lastPathComponent]];
}

@end
