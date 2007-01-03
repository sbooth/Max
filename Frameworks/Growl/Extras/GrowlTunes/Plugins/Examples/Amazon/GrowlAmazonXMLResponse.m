//
//  GrowlAmazonXMLResponse.m
//  GrowlTunes-Amazon
//
//  Created by Mac-arena the Bored Zo on 2005-03-21.
//  Copyright 2005 Mac-arena the Bored Zo. All rights reserved.
//

#import "GrowlAmazonXMLResponse.h"

@implementation GrowlAmazonXMLResponse

- (id) init {
	if ((self = [super init])) {
		foundItems = [[NSMutableArray alloc] init];
	}
	return self;
}
- (void) dealloc {
	[foundItems release];
	[super dealloc];
}

#pragma mark -
#pragma mark Accessors

- (NSArray *) foundItems {
	return [NSArray arrayWithArray:foundItems];
}

#pragma mark -
#pragma mark NSXMLParser delegate conformance

/*note that we only use AMAZON_FOO_KEY constants here for the output (the
 *	elements of currentItem).
 *for comparing element names in the XML data, we use the literal strings.
 */

- (void) parser:(NSXMLParser *)parser
 didStartElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI
 qualifiedName:(NSString *)qualifiedName
	attributes:(NSDictionary *)attributeDict
{
#pragma unused(parser,namespaceURI,qualifiedName,attributeDict)
	//fortunately, we don't need to maintain nesting currently.
	[currentElementName release];
	currentElementName = [elementName copy];

	[currentElementContents release];
	currentElementContents = [[NSMutableString alloc] init];

	if ([elementName isEqualToString:@"Details"])
		currentItem = [[NSMutableDictionary alloc] init];
	else if ([elementName isEqualToString:@"Artists"])
		artists = [[NSMutableArray alloc] init];
}

- (void) parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
#pragma unused(parser)
	[currentElementContents appendString:string];
}

- (void) parser:(NSXMLParser *)parser
 didEndElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI
 qualifiedName:(NSString *)qName
{
#pragma unused(parser,namespaceURI,qName)
	if ([elementName       hasPrefix:@"ImageUrl"]
	||  [elementName isEqualToString:@"ProductName"])
	{
		[currentItem setObject:currentElementContents forKey:elementName];
	} else if ([elementName isEqualToString:@"Artist"]) {
		[artists addObject:currentElementContents];
	} else if ([elementName isEqualToString:@"Artists"]) {
		[currentItem setObject:artists forKey:AMAZON_ARTISTS_KEY];
		[artists release];
		artists  = nil;
	}
	else if ([elementName isEqualToString:@"Details"]) {
		[foundItems addObject:currentItem];
		[currentItem release];
		currentItem  = nil;
	}

	[currentElementName     release];
	currentElementName      = nil;
	[currentElementContents release];
	currentElementContents  = nil;
}

@end
