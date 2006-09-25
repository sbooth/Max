//
//  RRTableView.m
//  Growl
//
//  Created by Rudy Richter on 11/12/04.
//  Copyright 2004-2005 The Growl Project. All rights reserved.
//
// This file is under the BSD License, refer to License.txt for details

#import "RRTableView.h"

@implementation RRTableView

- (BOOL) becomeFirstResponder {
	BOOL accept = [super becomeFirstResponder];

	id delegate = [self delegate];
	if ([delegate respondsToSelector:@selector(tableViewDidClickInBody:)]) {
		[delegate tableViewDidClickInBody:self];
	}

	return accept;
}

@end
