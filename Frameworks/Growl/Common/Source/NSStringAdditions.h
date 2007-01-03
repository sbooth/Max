//
//  NSStringAdditions.h
//  Growl
//
//  Created by Ingmar Stein on 16.05.05.
//  Copyright 2005 The Growl Project. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (GrowlAdditions)

+ (NSString *) stringWithUTF8String:(const char *)bytes length:(unsigned)len;
- (id) initWithUTF8String:(const char *)bytes length:(unsigned)len;

- (BOOL) boolValue;
- (unsigned long) unsignedLongValue;
- (unsigned) unsignedIntValue;

- (BOOL) isSubpathOf:(NSString *)superpath;

+ (NSString *) stringWithAddressData:(NSData *)aAddressData;
+ (NSString *) hostNameForAddressData:(NSData *)aAddressData;

@end
