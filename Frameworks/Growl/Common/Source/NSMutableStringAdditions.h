//
//  NSMutableStringAdditions.h
//  Growl
//
//  Created by Ingmar Stein on 19.04.05.
//  Copyright 2005 The Growl Project. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSMutableString (GrowlAdditions)
- (NSMutableString *) escapeForJavaScript;
- (NSMutableString *) escapeForHTML;
@end
