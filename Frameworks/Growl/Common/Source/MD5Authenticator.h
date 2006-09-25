//
//  MD5Authenticator.h
//  Growl
//
//  Created by Ingmar Stein on 24.04.05.
//  Copyright 2005 The Growl Project. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface MD5Authenticator : NSObject {
	NSString *password;
}
- (id) initWithPassword:(NSString *)pwd;
- (NSData *) authenticationDataForComponents:(NSArray *)components;
- (BOOL) authenticateComponents:(NSArray *)components withData:(NSData *)signature;

@end
