//
//  GrowlWebKitWindowController.m
//  Growl
//
//  Created by Ingmar Stein on Thu Apr 14 2005.
//  Copyright 2005 The Growl Project. All rights reserved.
//

#import "GrowlWebKitWindowController.h"
#import "GrowlWebKitWindowView.h"
#import "GrowlWebKitPrefsController.h"
#import "GrowlWebKitDefines.h"
#import "GrowlImageURLProtocol.h"
#import "NSWindow+Transforms.h"
#import "GrowlPluginController.h"
#import "NSMutableStringAdditions.h"

static unsigned webkitWindowDepth = 0U;
static NSMutableDictionary *notificationsByIdentifier;

@interface TrackingPanel : NSPanel {
}
@end

@implementation TrackingPanel
- (BOOL) canBecomeKeyWindow {
	return YES;
}

- (void) sendEvent:(NSEvent *)theEvent {
	if ([theEvent type] == NSMouseMoved)
		[[[self contentView] hitTest:[theEvent locationInWindow]] mouseMoved:theEvent];
	[super sendEvent:theEvent];
}
@end

@interface NSString(TigerCompatibility)
- (id) initWithContentsOfFile:(NSString *)path encoding:(NSStringEncoding)enc error:(NSError **)error;
@end

@implementation GrowlWebKitWindowController

#define MIN_DISPLAY_TIME				4.0
#define ADDITIONAL_LINES_DISPLAY_TIME	0.5
#define MAX_DISPLAY_TIME				10.0
#define GrowlWebKitPadding				5.0f

#pragma mark -

- (id) initWithTitle:(NSString *) title text:(NSString *) text icon:(NSImage *) icon priority:(int)priority sticky:(BOOL)sticky identifier:(NSString *)ident style:(NSString *)styleName {
	GrowlWebKitWindowController *oldController = [notificationsByIdentifier objectForKey:ident];
	if (oldController) {
		// coalescing
		WebView *view = (WebView *)[[oldController window] contentView];
		[oldController setTitle:title text:text icon:icon priority:priority forView:view];
		[self release];
		self = oldController;
		return self;
	}
	identifier = [ident retain];

	style = [styleName retain];
	prefDomain = [[NSString alloc] initWithFormat:@"%@.%@", GrowlWebKitPrefDomain, style];

	screenNumber = 0U;
	READ_GROWL_PREF_INT(GrowlWebKitScreenPref, prefDomain, &screenNumber);

	NSPanel *panel = [[TrackingPanel alloc] initWithContentRect:NSMakeRect(0.0f, 0.0f, 270.0f, 1.0f)
												styleMask:NSBorderlessWindowMask | NSNonactivatingPanelMask
												  backing:NSBackingStoreBuffered
													defer:NO];
	NSRect panelFrame = [panel frame];
	[panel setBecomesKeyOnlyIfNeeded:YES];
	[panel setHidesOnDeactivate:NO];
	[panel setBackgroundColor:[NSColor clearColor]];
	[panel setLevel:NSStatusWindowLevel];
	[panel setSticky:YES];
	[panel setAlphaValue:0.0f];
	[panel setOpaque:NO];
	[panel setHasShadow:YES];
	[panel setCanHide:NO];
	[panel setOneShot:YES];
	[panel useOptimizedDrawing:YES];
	[panel disableCursorRects];
	//[panel setReleasedWhenClosed:YES]; // ignored for windows owned by window controllers.
	//[panel setDelegate:self];

	NSBundle *styleBundle = [[GrowlPluginController controller] bundleForPluginNamed:style];
	NSDictionary *styleInfo = [styleBundle infoDictionary];
	NSNumber *hasShadow = [styleInfo objectForKey:@"GrowlHasShadow"];
	[panel setHasShadow:(hasShadow && [hasShadow boolValue])];

	NSNumber *paddingValue = [styleInfo objectForKey:@"GrowlPaddingX"];
	paddingX = paddingValue ? [paddingValue floatValue] : GrowlWebKitPadding;
	paddingValue = [styleInfo objectForKey:@"GrowlPaddingY"];
	paddingY = paddingValue ? [paddingValue floatValue] : GrowlWebKitPadding;

	GrowlWebKitWindowView *view = [[GrowlWebKitWindowView alloc] initWithFrame:panelFrame
																	 frameName:nil
																	 groupName:nil];
	[view setMaintainsBackForwardList:NO];
	[view setTarget:self];
	[view setAction:@selector(_notificationClicked:)];
	[view setPolicyDelegate:self];
	[view setFrameLoadDelegate:self];
	if ([view respondsToSelector:@selector(setDrawsBackground:)])
		[view setDrawsBackground:NO];
	[panel setContentView:view];
	
	[self setTitle:title text:text icon:icon priority:priority forView:view];

	panelFrame = [view frame];
	[panel setFrame:panelFrame display:NO];

	if ((self = [super initWithWindow:panel])) {
		autoFadeOut = !sticky;
		delegate = self;

		// the visibility time for this bubble should be the minimum display time plus
		// some multiple of ADDITIONAL_LINES_DISPLAY_TIME, not to exceed MAX_DISPLAY_TIME
		int rowCount = 2;
		BOOL limitPref = YES;
		READ_GROWL_PREF_BOOL(GrowlWebKitLimitPref, prefDomain, &limitPref);
		float duration = MIN_DISPLAY_TIME;
		READ_GROWL_PREF_FLOAT(GrowlWebKitDurationPref, prefDomain, &duration);
		if (limitPref)
			displayTime = duration;
		else
			displayTime = MIN (duration + rowCount * ADDITIONAL_LINES_DISPLAY_TIME,
							   MAX_DISPLAY_TIME);

		if (identifier) {
			if (!notificationsByIdentifier)
				notificationsByIdentifier = [[NSMutableDictionary alloc] init];
			[notificationsByIdentifier setObject:self forKey:identifier];
		}
	}

	return self;
}

- (void) setTitle:(NSString *)title text:(NSString *)text icon:(NSImage *)icon priority:(int)priority forView:(WebView *)view {
	NSString *priorityName;
	switch (priority) {
		case -2:
			priorityName = @"verylow";
			break;
		case -1:
			priorityName = @"moderate";
			break;
		default:
		case 0:
			priorityName = @"normal";
			break;
		case 1:
			priorityName = @"high";
			break;
		case 2:
			priorityName = @"emergency";
			break;
	}

	NSBundle *styleBundle = [[GrowlPluginController controller] bundleForPluginNamed:style];
	NSString *templateFile = [styleBundle pathForResource:@"template" ofType:@"html"];
	if (![[NSFileManager defaultManager] fileExistsAtPath:templateFile])
		templateFile = [[NSBundle mainBundle] pathForResource:@"template" ofType:@"html"];

	NSString *stylePath = [styleBundle resourcePath];
	NSMutableString *htmlString = [NSMutableString alloc];
	if ([htmlString respondsToSelector:@selector(initWithContentsOfFile:encoding:error:)]) {
		NSError *error;
		htmlString = [htmlString initWithContentsOfFile:templateFile encoding:NSUTF8StringEncoding error:&error];
	} else {
		// this method has been deprecated in 10.4
		htmlString = [htmlString initWithContentsOfFile:templateFile];
	}
	if (!htmlString)
		NSLog(@"WARNING: could not read template '%@'", templateFile);

	NSString *UUID = [[NSProcessInfo processInfo] globallyUniqueString];
	image = [icon retain];
	[image setName:UUID];
	[GrowlImageURLProtocol class];	// make sure GrowlImageURLProtocol is +initialized

	float opacity = 95.0f;
	READ_GROWL_PREF_FLOAT(GrowlWebKitOpacityPref, prefDomain, &opacity);
	opacity *= 0.01f;
	NSNumber *opacityNumber = [[NSNumber alloc] initWithFloat:opacity];

	NSString        *titleHTML = [[[NSMutableString alloc] initWithString:title] escapeForHTML];
	NSMutableString *textHTML = [[[NSMutableString alloc] initWithString:text] escapeForHTML];
	NSURL           *baseURL = [[NSURL alloc] initFileURLWithPath:stylePath];

	[htmlString replaceOccurrencesOfString:@"%baseurl%"
								withString:[baseURL absoluteString]
								   options:NSLiteralSearch
									 range:NSMakeRange(0U, [htmlString length])];
	[htmlString replaceOccurrencesOfString:@"%opacity%"
								withString:[opacityNumber stringValue]
								   options:NSLiteralSearch
									 range:NSMakeRange(0U, [htmlString length])];
	[htmlString replaceOccurrencesOfString:@"%priority%"
								withString:priorityName
								   options:NSLiteralSearch
									 range:NSMakeRange(0U, [htmlString length])];
	[htmlString replaceOccurrencesOfString:@"%image%"
								withString:UUID
								   options:NSLiteralSearch
									 range:NSMakeRange(0U, [htmlString length])];
	[htmlString replaceOccurrencesOfString:@"%title%"
								withString:titleHTML
								   options:NSLiteralSearch
									 range:NSMakeRange(0U, [htmlString length])];
	[htmlString replaceOccurrencesOfString:@"%text%"
								withString:textHTML
								   options:NSLiteralSearch
									 range:NSMakeRange(0U, [htmlString length])];

	[opacityNumber release];
	[titleHTML release];
	[textHTML release];
	WebFrame *webFrame = [view mainFrame];
	[[self window] disableFlushWindow];
	[self retain];
	[webFrame loadHTMLString:htmlString baseURL:nil];
	[[webFrame frameView] setAllowsScrolling:NO];
	[htmlString release];
	[baseURL release];
}

/*!
 * @brief Prevent the webview from following external links.  We direct these to the users web browser.
 */
- (void) webView:(WebView *)sender
	decidePolicyForNavigationAction:(NSDictionary *)actionInformation
		request:(NSURLRequest *)request
		  frame:(WebFrame *)frame
	decisionListener:(id<WebPolicyDecisionListener>)listener
{
#pragma unused(sender, request, frame)
	int actionKey = [[actionInformation objectForKey: WebActionNavigationTypeKey] intValue];
	if (actionKey == WebNavigationTypeOther) {
		[listener use];
	} else {
		NSURL *url = [actionInformation objectForKey:WebActionOriginalURLKey];

		//Ignore file URLs, but open anything else
		if (![url isFileURL])
			[[NSWorkspace sharedWorkspace] openURL:url];

		[listener ignore];
	}
}

/*!
 * @brief Invoked once the webview has loaded and is ready to accept content
 */
- (void) webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame {
#pragma unused(frame)
	NSWindow *myWindow = [self window];
	if ([myWindow isFlushWindowDisabled])
		[myWindow enableFlushWindow];

	GrowlWebKitWindowView *view = (GrowlWebKitWindowView *)sender;
	[view sizeToFit];
	if (!positioned) {
		NSRect panelFrame = [view frame];
		NSRect screen = [[self screen] visibleFrame];
		[[self window] setFrameTopLeftPoint:NSMakePoint(NSMaxX(screen) - NSWidth(panelFrame) - paddingX,
														NSMaxY(screen) - paddingY - webkitWindowDepth)];

#warning this is some temporary code to to stop notifications from spilling off the bottom of the visible screen area
		// It actually doesn't even stop _this_ notification from spilling off the bottom; just the next one.
		if (NSMinY(panelFrame) < 0.0f)
			depth = webkitWindowDepth = 0U;
		else
			depth = webkitWindowDepth += NSHeight(panelFrame) + paddingY;
		positioned = true;
	}
	[self startFadeIn];
	[self release];	// we retained before loadHTMLString
}

- (void) startFadeOut {
	GrowlWebKitWindowView *view = (GrowlWebKitWindowView *)[[self window] contentView];
	if ([view mouseOver]) {
		[view setCloseOnMouseExit:YES];
	} else {
		if (identifier) {
			[notificationsByIdentifier removeObjectForKey:identifier];
			if (![notificationsByIdentifier count]) {
				[notificationsByIdentifier release];
				notificationsByIdentifier = nil;
			}
		}
		[super startFadeOut];
	}
}

- (void) dealloc {
	if (depth == webkitWindowDepth)
		webkitWindowDepth = 0U;

	NSWindow *myWindow = [self window];
	WebView *webView = [myWindow contentView];
	[webView    setPolicyDelegate:nil];
	[webView    setFrameLoadDelegate:nil];
	[webView    release];
	[myWindow   release];
	[image      release];
	[style      release];
	[prefDomain release];
	[identifier release];

	[super dealloc];
}

@end
