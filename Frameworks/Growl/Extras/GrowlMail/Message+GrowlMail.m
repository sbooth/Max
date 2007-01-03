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
//  Message+GrowlMail.m
//  GrowlMail
//
//  Created by Ingmar Stein on 27.10.04.
//

#import "Message+GrowlMail.h"
#import "GrowlMail.h"
#import <AddressBook/AddressBook.h>
#import <Growl/Growl.h>

@interface NSString(GrowlMail)
- (NSString *) firstNLines:(unsigned)n;
- (NSString *) stringByReplacingKeywords:(NSDictionary *)keywords;
@end

@implementation NSString(GrowlMail)
- (NSString *) firstNLines:(unsigned)n {
	NSRange range;
	unsigned end;

	range.location = 0U;
	range.length = 0U;
	for (unsigned i=0U; i<n; ++i)
		[self getLineStart:NULL end:&range.location contentsEnd:&end forRange:range];

	return [self substringToIndex:end];
}

- (NSString *) stringByReplacingKeywords:(NSDictionary *)keywords {
	NSString *keyword;
	NSEnumerator *keyEnum = [keywords keyEnumerator];
	NSMutableString *text = [self mutableCopy];
	while ((keyword = [keyEnum nextObject])) {
		[text replaceOccurrencesOfString:keyword
							  withString:[keywords objectForKey:keyword]
								 options:NSLiteralSearch
								   range:NSMakeRange(0U, [text length])];
	}
	return [text autorelease];
}
@end

@implementation Message(GrowlMail)
- (void) showNotification {
	NSString *titleFormat = copyTitleFormatString();
	NSString *descriptionFormat = copyDescriptionFormatString();
	NSString *messageID = [self messageID];

	NSString *body;
	if ([descriptionFormat rangeOfString:@"%body"].location != NSNotFound ||
		[titleFormat rangeOfString:@"%body"].location != NSNotFound) {
		/* We will need the body */		
		MessageBody *messageBody = [self messageBodyIfAvailable];
		
		if (!messageBody) {
			/* No message body available yet, but we need one */
			static NSMutableDictionary *bodyAttemptDict = nil;
			if (!bodyAttemptDict) bodyAttemptDict = [[NSMutableDictionary alloc] init];

			if ([[bodyAttemptDict objectForKey:messageID] intValue] < 3) {
				/* Try again in 0.5 seconds so as not to block */
				[bodyAttemptDict setObject:[NSNumber numberWithInt:([[bodyAttemptDict objectForKey:messageID] intValue] + 1)]
									forKey:messageID];
				[self performSelector:@selector(showNotification)
						   withObject:nil
						   afterDelay:0.5];
				[titleFormat release];
				[descriptionFormat release];
				return;
			} else {
				/* Clear out our dictionary, releasing it if it is no longer needed */
				[bodyAttemptDict removeObjectForKey:messageID];
				if (![bodyAttemptDict count]) {
					[bodyAttemptDict release];
					bodyAttemptDict = nil;
				}
				
				/* Already tried three times (1.5 seconds); this time, block to get it. */
				messageBody = [self messageBody];
			}
		}

		if (messageBody) {
			NSString *originalBody;
			/* The stringForIndexing selector is not available in Mail.app 2.0. */
			if ([messageBody respondsToSelector:@selector(stringForIndexing)])
				originalBody = [messageBody stringForIndexing];
			else
				originalBody = [messageBody stringValueForJunkEvaluation:NO];
			originalBody = [originalBody stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
			body = [originalBody firstNLines:4U];
			if ([body length] > 200U)
				body = [body substringToIndex:200U];
			if ([body length] != [originalBody length]) {
				NSString *ellipsis = [[NSString alloc] initWithUTF8String:"\xE2\x80\xA6"];
				body = [body stringByAppendingString:ellipsis];
				[ellipsis release];
			}
		} else
			body = @"";
	} else {
		body = @"";
	}

	NSString *account = [[[self mailbox] account] displayName];
	NSString *sender = [self sender];
	NSString *senderAddress = [sender uncommentedAddress];
	NSString *subject = [self subject];
	
	/* The fullName selector is not available in Mail.app 2.0. */
	if ([sender respondsToSelector:@selector(fullName)])
		sender = [sender fullName];
	else if ([sender addressComment])
		sender = [sender addressComment];

	NSDictionary *keywords = [[NSDictionary alloc] initWithObjectsAndKeys:
		sender,  @"%sender",
		subject, @"%subject",
		body,    @"%body",
		account, @"%account",
		nil];
	NSString *title = [titleFormat stringByReplacingKeywords:keywords];
	NSString *description = [descriptionFormat stringByReplacingKeywords:keywords];
	[keywords release];

	/*
	NSLog(@"Subject: '%@'", subject);
	NSLog(@"Sender: '%@'", sender);
	NSLog(@"Account: '%@'", account);
	NSLog(@"Body: '%@'", body);
*/
	/*
	 * MailAddressManager fetches images asynchronously so they might arrive
	 * after we have sent our notification.
	 */
	/*
	MailAddressManager *addressManager = [MailAddressManager addressManager];
	[addressManager fetchImageForAddress:senderAddress];
	NSImage *image = [addressManager imageForMailAddress:senderAddress];
	*/
	ABSearchElement *personSearch = [ABPerson searchElementForProperty:kABEmailProperty
																 label:nil
																   key:nil
																 value:senderAddress
															comparison:kABEqualCaseInsensitive];

	NSData *image = nil;
	NSEnumerator *matchesEnum = [[[ABAddressBook sharedAddressBook] recordsMatchingSearchElement:personSearch] objectEnumerator];
	ABPerson *person;
	while ((!image) && (person = [matchesEnum nextObject]))
		image = [person imageData];

	//no matches in the Address Book with an icon, so use Mail's icon instead.
	if (!image)
		image = [[NSImage imageNamed:@"NSApplicationIcon"] TIFFRepresentation];

	CFStringRef notificationName;
	CFBundleRef bundle = GetGrowlMailBundle();
	if ([self isJunk])
		notificationName = CFCopyLocalizedStringFromTableInBundle(CFSTR("New junk mail"), NULL, bundle, "");
	else
		notificationName = CFCopyLocalizedStringFromTableInBundle(CFSTR("New mail"), NULL, bundle, "");

	[GrowlApplicationBridge notifyWithTitle:title
								description:description
						   notificationName:(NSString *)notificationName
								   iconData:image
								   priority:0
								   isSticky:NO
							   clickContext:messageID];
	CFRelease(notificationName);
	
	[titleFormat release];
	[descriptionFormat release];
}
@end
