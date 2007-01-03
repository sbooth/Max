#import "PrefpaneTester.h"
#import <PreferencePanes/PreferencePanes.h>
#import "generatedBuildPath.h"

@implementation PrefpaneTester

- (BOOL) applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication {
#pragma unused(theApplication)
	return YES;
}

- (void) dealloc {
	[prefPaneObject release];
	[super dealloc];
}

- (void) awakeFromNib {
	NSRect aRect;
	NSMutableString *pathToPrefPaneBundle;
	NSBundle *prefBundle;
	Class prefPaneClass;
	NSView *prefView;

	pathToPrefPaneBundle = [NSMutableString stringWithCString: GROWL_OBJROOT];
	[pathToPrefPaneBundle appendString: @"/Growl.prefPane"];

	prefBundle = [NSBundle bundleWithPath: pathToPrefPaneBundle];

	prefPaneClass = [prefBundle principalClass];
	prefPaneObject = [[prefPaneClass alloc] initWithBundle: prefBundle];

	if ([prefPaneObject loadMainView]) {
		[prefPaneObject willSelect];
		prefView = [prefPaneObject mainView];
		/* Add view to window */
		aRect = [prefView frame];

		// Okay, I know this is not so goood...
		aRect.size.height = aRect.size.height + 22;
		[theWindow setFrame: aRect display: YES];
		[[theWindow contentView] addSubview: prefView];
		[prefPaneObject didSelect];
	} else {
		/* loadMainView failed -- handle error */
		NSLog(@"PrefpaneTester -  Error in loadMainView:");
	}
}
@end
