//
//  GrowlRegisterScriptCommand.h
//  Growl
//
//  Created by Ingmar Stein on Tue Nov 09 2004.
//  Copyright (c) 2004 Ingmar Stein. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Foundation/NSScriptCommand.h>

@interface GrowlRegisterScriptCommand : NSScriptCommand {
}

- (void) setError:(int)errorCode;
- (void) setError:(int)errorCode failure:(id)failure;

@end
