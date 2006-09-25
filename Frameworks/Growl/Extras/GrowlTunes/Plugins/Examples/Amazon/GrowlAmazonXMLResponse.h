//
//  GrowlAmazonXMLResponse.h
//  GrowlTunes-Amazon
//
//  Created by Mac-arena the Bored Zo on 2005-03-21.
//  Copyright 2005 The Growl Project. All rights reserved.
//

#import <Cocoa/Cocoa.h>

//this class is intended for use as the delegate of an NSXMLParser instance.
@interface GrowlAmazonXMLResponse: NSObject
{
	NSMutableArray *foundItems;
	NSMutableDictionary *currentItem;
	NSMutableArray *artists;
	NSString *currentElementName;
	NSMutableString *currentElementContents;
}

- (NSArray *)foundItems;

@end

/*these keys are intentionally the same as the element names used in the actual
 *	XML data returned by Amazon.
 */
#define AMAZON_ARTISTS_KEY          @"Artists"
#define AMAZON_ALBUM_KEY            @"ProductName"
#define AMAZON_IMAGE_URL_SMALL_KEY  @"ImageUrlSmall"
#define AMAZON_IMAGE_URL_MEDIUM_KEY @"ImageUrlMedium"
#define AMAZON_IMAGE_URL_LARGE_KEY  @"ImageUrlLarge"
