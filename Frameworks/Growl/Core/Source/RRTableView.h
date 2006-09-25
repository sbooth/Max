//
//  RRTableView.h
//  Growl
//
//  Created by Rudy Richter on 11/12/04.
//  Copyright 2004-2005 The Growl Project. All rights reserved.
//
// This file is under the BSD License, refer to License.txt for details

#import <Cocoa/Cocoa.h>


@interface RRTableView : NSTableView {
}

- (BOOL) becomeFirstResponder;
@end

@interface NSObject (RRTableViewDelegateAdditions)
-(void) tableViewDidClickInBody:(NSTableView *)tableView;
@end
