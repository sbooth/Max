//
//  ÇPROJECTNAMEÈDisplayController.m
//  ÇPROJECTNAMEÈ
//
//  Created by ÇFULLUSERNAMEÈ on ÇDATEÈ.
//  Copyright ÇYEARÈ ÇORGANIZATIONNAMEÈ. All rights reserved.
//

#import "ÇPROJECTNAMEÈDisplayController.h"
#import "ÇPROJECTNAMEÈDisplayPreferences.h"

@implementation ÇPROJECTNAMEASIDENTIFIERÈDisplayController
- (void) dealloc {
	[prefPane release];
	[super dealloc];
}

- (NSPreferencePane *) preferencePane {
	// return nil if your display plugin has no preferences
	if (!prefPane) {
		prefPane = [[ÇPROJECTNAMEASIDENTIFIERÈDisplayPreferences alloc] initWithBundle:[NSBundle bundleForClass:[ÇPROJECTNAMEASIDENTIFIERÈDisplayPreferences class]]];
	}
	return prefPane;
}

- (void) displayNotificationWithInfo:(NSDictionary *)noteDict {
	// do something with noteDict
}
@end
