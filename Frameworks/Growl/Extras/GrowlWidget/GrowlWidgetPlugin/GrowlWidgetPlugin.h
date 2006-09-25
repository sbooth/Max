#import <Cocoa/Cocoa.h>
#import "GrowlNotificationCenter.h"

@class WebView;
@protocol GrowlNotificationCenterProtocol;

@interface GrowlWidgetPlugin : NSObject<GrowlNotificationObserver> {
	NSImage								*image;
	WebView								*webView;
	id<GrowlNotificationCenterProtocol>	growlNotificationCenter;
}

- (void) subscribeToGrowlNotificationCenter;
- (void) notifyWithDictionary:(NSDictionary *)dict;
@end
