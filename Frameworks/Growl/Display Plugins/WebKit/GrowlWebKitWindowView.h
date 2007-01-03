//
//  GrowlWebKitWindowView.h
//  Growl
//
//  Created by Ingmar Stein on Thu Apr 14 2005.
//  Copyright 2005 The Growl Project. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

@interface WebView(Transparency)
- (void) setDrawsBackground:(BOOL)flag;
- (BOOL) drawsBackground;
@end

@interface GrowlWebKitWindowView : WebView {
	BOOL				mouseOver;
	BOOL				closeOnMouseExit;
	SEL					action;
	id					target;
	NSTrackingRectTag	trackingRectTag;
}

- (void) sizeToFit;

- (id) target;
- (void) setTarget:(id)object;

- (SEL) action;
- (void) setAction:(SEL)selector;

- (BOOL) mouseOver;
- (void) setCloseOnMouseExit:(BOOL)flag;
@end

