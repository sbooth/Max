//
//  TicketsArrayController.h
//  Growl
//
//  Created by Ingmar Stein on 12.04.05.
//  Copyright 2005 The Growl Project. All rights reserved.
//
//  This file is under the BSD License, refer to License.txt for details

#import <Cocoa/Cocoa.h>

@interface TicketsArrayController: NSArrayController
{
	NSString *searchString;
}

- (IBAction) search:(id)sender;
- (NSString *) searchString;
- (void) setSearchString:(NSString *)newSearchString;

@end
