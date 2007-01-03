//
//  JKPreferencesController.h
//  Rawr-endezvous
//
//  Created by Jeremy Knope on 9/17/04.
//  Copyright 2004 Jeremy Knope. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class JKMenuController;

@interface JKPreferencesController : NSObject {
    IBOutlet id serviceTable;
	IBOutlet JKMenuController *main;
    IBOutlet id prefWindow;
    IBOutlet id addServiceButton;
    IBOutlet id removeServiceButton;
    IBOutlet id servicePopUp;
    IBOutlet id localHideCheck;
    IBOutlet id showStatusMenuItemCheck;

    NSMutableArray      *services;      // current services to look for
    NSMutableArray      *serviceNames;  // their names
    NSMutableDictionary *tableData;
    NSMutableDictionary *prefs;
    NSMutableDictionary *itemPresets;

    BOOL showStatusMenuItem;
}
// prefs window actions
- (IBAction) saveClicked:(id)sender;
- (IBAction) addService:(id)sender;
- (IBAction) removeService:(id)sender;
- (IBAction) addPreset:(id)sender;

// the non-UI methods
- (void) openPrefs;
- (IBAction) openPrefsWindow:(id)sender;
- (IBAction) closePrefsWindow:(id)sender;
- (void) savePrefs;
- (NSArray *) getServices;
- (BOOL) getShowStatusMenuItem;
- (int) numberOfRowsInTableView:(NSTableView *)theTableView;
- (id) tableView:(NSTableView *)theTableView objectValueForTableColumn:(NSTableColumn *)theColumn row:(int)rowIndex;
@end
