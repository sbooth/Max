/* OutputPreferencesController */

#import <Cocoa/Cocoa.h>

@interface OutputPreferencesController : NSWindowController
{
    IBOutlet NSTextField	*_customNameTextField;
    NSString				*_customNameExample;
}

- (IBAction)	customNamingButtonAction:(id)sender;
- (IBAction)	selectOutputDirectory:(id)sender;

@end
