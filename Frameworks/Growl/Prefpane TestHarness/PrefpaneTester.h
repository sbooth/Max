#import <Cocoa/Cocoa.h>

@class NSPreferencePane;

@interface PrefpaneTester : NSObject {
	IBOutlet NSWindow	*theWindow;
	NSPreferencePane	*prefPaneObject;
}

- (void) awakeFromNib;

@end
