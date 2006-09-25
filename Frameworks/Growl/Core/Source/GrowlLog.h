//
//  GrowlLog.h
//  Growl
//
//  Created by Ingmar Stein on 17.04.05.
//  Copyright 2004-2005 The Growl Project. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface GrowlLog : NSObject {

}
+ (void) log:(NSString *)message;
+ (void) logNotificationDictionary:(NSDictionary *)noteDict;
+ (void) logRegistrationDictionary:(NSDictionary *)regDict;
@end
