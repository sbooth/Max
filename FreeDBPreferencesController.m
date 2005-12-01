#import "FreeDBPreferencesController.h"
#import "FreeDB.h"
#import "FreeDBSite.h"

@implementation FreeDBPreferencesController

- (id) init
{
	if((self = [super initWithWindowNibName:@"FreeDBPreferences"])) {
		return self;		
	}
	return nil;
}

- (IBAction) refreshList:(id)sender
{
	NSLog(@"refreshList");
	@try {
		// Get mirror list
		FreeDB *freeDB = [[[FreeDB alloc] init] autorelease];
		[self setValue:[freeDB fetchSites] forKey:@"mirrors"];
	}
	
	@catch(NSException *exception) {
		displayExceptionAlert(exception);
	}
	
	@finally {
	}
}

- (IBAction) selectMirror:(id)sender
{
	NSLog(@"selectMirror");
	NSArray *selectedObjects = [_mirrorsController selectedObjects];
	if(0 < [selectedObjects count]) {
		FreeDBSite					*mirror					= [selectedObjects objectAtIndex:0];
		NSUserDefaultsController	*defaultsController		= [NSUserDefaultsController sharedUserDefaultsController];
		[[defaultsController values] setValue:[mirror valueForKey:@"address"] forKey:@"server"];
		[[defaultsController values] setValue:[mirror valueForKey:@"port"] forKey:@"port"];
		[[defaultsController values] setValue:[mirror valueForKey:@"protocol"] forKey:@"protocol"];
	}
}

@end
