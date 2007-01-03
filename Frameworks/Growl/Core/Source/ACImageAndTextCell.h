//
//  ImageAndTextCell.h
//
//  Copyright (c) 2001-2002, Apple. All rights reserved.
//  Copyright 2004-2005 The Growl Project. All rights reserved.
//
// This file is under the BSD License, refer to License.txt for details

#import <Cocoa/Cocoa.h>

@interface ACImageAndTextCell : NSTextFieldCell {
@private
	NSImage	*image;
}

- (void) setImage:(NSImage *)anImage;
- (NSImage *) image;

- (void) drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView;
- (NSSize) cellSize;

@end
