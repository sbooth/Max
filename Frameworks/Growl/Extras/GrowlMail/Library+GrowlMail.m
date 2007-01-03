/*
 Copyright (c) The Growl Project, 2004-2005
 All rights reserved.

 Redistribution and use in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 2. Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 3. Neither the name of Growl nor the names of its contributors
 may be used to endorse or promote products derived from this software
 without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 OF THE POSSIBILITY OF SUCH DAMAGE.
*/
//
//  Library+GrowlMail.m
//  GrowlMail
//
//  Created by Ingmar Stein on 27.10.04.
//

#import "Library+GrowlMail.h"
#import "GrowlMail.h"
#import <objc/objc-runtime.h>

static BOOL PerformSwizzle(Class aClass, SEL orig_sel, SEL alt_sel) {
	Method orig_method = nil, alt_method = nil;

	// Look for the methods
	orig_method = class_getClassMethod(aClass, orig_sel);
	alt_method = class_getClassMethod(aClass, alt_sel);

	// If both are found, swizzle them
	if (orig_method && alt_method) {
		IMP temp;
#if MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_4
		if (class_getMethodImplementation) {
			temp = method_getImplementation(orig_method);
			method_setImplementation(orig_method, method_getImplementation(alt_method));
			method_setImplementation(alt_method, temp);
		} else {
#endif
			temp = orig_method->method_imp;
			orig_method->method_imp = alt_method->method_imp;
			alt_method->method_imp = temp;
#if MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_4
		}
#endif

		return YES;
	}

	return NO;
}

@implementation Library(GrowlMail)
+ (void) load {
	if (!PerformSwizzle([Library class],
						@selector(addMessages:withMailbox:fetchBodies:isInitialImport:oldMessagesByNewMessage:),
						@selector(gm_addMessages:withMailbox:fetchBodies:isInitialImport:oldMessagesByNewMessage:)))
		NSLog(@"GrowlMail: could not swizzle addMessages:withMailbox:fetchBodies:isInitialImport:oldMessagesByNewMessage:");
}

+ (id) gm_addMessages:(NSArray *)messages withMailbox:(NSString *)mailbox fetchBodies:(BOOL)fetchBodies isInitialImport:(BOOL)isInitialImport oldMessagesByNewMessage:(id)oldMessagesByNewMessage {
	NSArray *libraryMessages = [self gm_addMessages:messages withMailbox:mailbox fetchBodies:fetchBodies isInitialImport:isInitialImport oldMessagesByNewMessage:oldMessagesByNewMessage];
	GrowlMail *growlMail = [GrowlMail sharedInstance];
	if (GMIsEnabled()) {
		MailboxUid *mailboxUid = [self mailboxUidForURL:mailbox];
		if ([growlMail isAccountEnabled:[[mailboxUid account] path]] && (!GMInboxOnly() || [[MailAccount inboxMailboxUids] containsObject:mailboxUid])) {
			int mailboxType = [mailboxUid type];
			if (mailboxType == 0 || mailboxType == 6) {
				Class popMessageClass = [POPMessage class];
				Class imapMessageClass = [IMAPMessage class];
				for (unsigned i=0U, count=[messages count]; i<count; ++i) {
					Message *message = [messages objectAtIndex:i];
					if (([message isKindOfClass:popMessageClass] || [message isKindOfClass:imapMessageClass]))
						[growlMail queueMessage:[libraryMessages objectAtIndex:i]];
				}
			}
		}
	}
	return libraryMessages;
}
@end
