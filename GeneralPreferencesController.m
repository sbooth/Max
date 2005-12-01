#import "GeneralPreferencesController.h"

@implementation GeneralPreferencesController

- (id) init
{
	if((self = [super initWithWindowNibName:@"GeneralPreferences"])) {
		return self;		
	}
	return nil;
}

- (IBAction) restoreDefaults:(id)sender
{
	[[NSUserDefaultsController sharedUserDefaultsController] revertToInitialValues:nil];
}

@end
