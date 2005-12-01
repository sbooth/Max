/* FreeDBPreferencesController */

#import <Cocoa/Cocoa.h>

@interface FreeDBPreferencesController : NSWindowController
{
    IBOutlet NSTextField			*_serverTextField;
    IBOutlet NSTextField			*_portTextField;
    IBOutlet NSArrayController		*_mirrorsController;
	NSArray							*_mirrors;
}

- (IBAction) 		refreshList:(id)sender;
- (IBAction) 		selectMirror:(id)sender;

@end
