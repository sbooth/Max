/*
 *  $Id$
 *
 *  Copyright (C) 2005, 2006 Stephen F. Booth <me@sbooth.org>
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#import "AmazonAlbumArtSheet.h"
#import "MissingResourceException.h"

@implementation AmazonAlbumArtSheet

- (id) initWithCompactDiscDocument:(CompactDiscDocument *)doc;
{
	if((self = [super init])) {
		if(NO == [NSBundle loadNibNamed:@"AmazonAlbumArtSheet" owner:self])  {
			@throw [MissingResourceException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to load required resource", @"Exceptions", @"")
														userInfo:[NSDictionary dictionaryWithObject:@"AmazonAlbumArtSheet.nib" forKey:@"filename"]];
		}
		
		_doc		= [doc retain];
		_images		= [[NSMutableArray arrayWithCapacity:10] retain];

		[_artistTextField setStringValue:[_doc valueForKey:@"artist"]];
		[_titleTextField setStringValue:[_doc valueForKey:@"title"]];
		
		[self setValue:[NSNumber numberWithBool:NO] forKey:@"searchInProgress"];
		
		return self;
	}
	return nil;
}

- (void) dealloc
{
	[_doc release];
	[_images release];
	[super dealloc];
}

- (void) showAlbumArtMatches
{
    [[NSApplication sharedApplication] beginSheet:_sheet modalForWindow:[_doc windowForSheet] modalDelegate:self didEndSelector:@selector(didEndSheet:returnCode:contextInfo:) contextInfo:nil];
	[self search:self];
}

- (IBAction) search:(id)sender
{
	// http://webservices.amazon.com/onca/xml?Service=AWSECommerceService&AWSAccessKeyId=18PZ5RH3H0X43PS96MR2&Operation=ItemSearch&SearchIndex=Music&ResponseGroup=Images&Artist=Kid+Rock&Title=Cocky
	
	NSError					*error;
	NSString				*urlString, *artist, *title, *locale;
	NSURL					*url;
	NSXMLDocument			*xmlDoc;

	NSXMLNode				*node, *childNode, *grandChildNode;
	NSEnumerator			*childrenEnumerator, *grandChildrenEnumerator;
	NSMutableDictionary		*dictionary;
	NSMutableArray			*images;

	
	[self setValue:[NSNumber numberWithBool:YES] forKey:@"searchInProgress"];

	artist		= [_artistTextField stringValue];
	title		= [_titleTextField stringValue];
	
	switch([[_localePopUpButton selectedItem] tag]) {
		case kAmazonLocaleUSMenuItemTag:		locale = @"com";			break;
		case kAmazonLocaleUKMenuItemTag:		locale = @"co.uk";			break;
		case kAmazonLocaleJapanMenuItemTag:		locale = @"co.jp";			break;
	}

	urlString	= [NSString stringWithFormat:@"http://webservices.amazon.%@/onca/xml?Service=AWSECommerceService&AWSAccessKeyId=18PZ5RH3H0X43PS96MR2&Operation=ItemSearch&SearchIndex=Music&ResponseGroup=Images&Artist=%@&Title=%@", locale, artist, title];
	url			= [NSURL URLWithString:[urlString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
	
	xmlDoc = [[NSXMLDocument alloc] initWithContentsOfURL:url options:(NSXMLNodePreserveWhitespace | NSXMLNodePreserveCDATA) error:&error];
	if(nil == xmlDoc) {
		xmlDoc = [[NSXMLDocument alloc] initWithContentsOfURL:url options:NSXMLDocumentTidyXML error:&error];
	}
	if(nil == xmlDoc) {
		if(error) {
			NSAlert *alert = [[[NSAlert alloc] init] autorelease];
			[alert addButtonWithTitle: NSLocalizedStringFromTable(@"OK", @"General", @"")];
			[alert setMessageText: NSLocalizedStringFromTable(@"An error occurred while attempting to download album artwork.", @"Errors", @"")];
			[alert setInformativeText: [error localizedDescription]];
			[alert setAlertStyle: NSWarningAlertStyle];
			
			[alert runModal];
		}
		
		[self setValue:[NSNumber numberWithBool:NO] forKey:@"searchInProgress"];
		return;
	}
	
	if(error) {
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert addButtonWithTitle: NSLocalizedStringFromTable(@"OK", @"General", @"")];
		[alert setMessageText: NSLocalizedStringFromTable(@"An error occurred while attempting to download album artwork.", @"Errors", @"")];
		[alert setInformativeText: [error localizedDescription]];
		[alert setAlertStyle: NSWarningAlertStyle];
		
		[alert runModal];
		
		[self setValue:[NSNumber numberWithBool:NO] forKey:@"searchInProgress"];
		return;
	}
	
	NSLog(@"xmlDoc=%@",xmlDoc);
		
	images	= [self mutableArrayValueForKey:@"images"];
	[images removeAllObjects];
	node	= [xmlDoc rootElement];
	while((node = [node nextNode])) {
		if([[node name] isEqualToString:@"ImageSet"]) {
			// Iterate through children
			childrenEnumerator = [[node children] objectEnumerator];
			while((childNode = [childrenEnumerator nextObject])) {
				dictionary					= [NSMutableDictionary dictionaryWithCapacity:3];
				grandChildrenEnumerator		= [[childNode children] objectEnumerator];
				
				while((grandChildNode = [grandChildrenEnumerator nextObject])) {
					[dictionary setValue:[grandChildNode stringValue] forKey:[grandChildNode name]];
				}
				
				[images addObject:dictionary];
				//NSLog(@"dictionary = %@", dictionary);
			}
		}
	}
		
	[self setValue:[NSNumber numberWithBool:NO] forKey:@"searchInProgress"];
}

- (IBAction) cancel:(id)sender
{
    [[NSApplication sharedApplication] endSheet:_sheet];
}

- (IBAction) useSelected:(id)sender
{	
	NSImage		*image;
	
	image = [[NSImage alloc] initWithContentsOfURL:[NSURL URLWithString:[[_images objectAtIndex:[_table selectedRow]] valueForKey:@"URL"]]];
	if(nil != image) {
		[_doc setValue:[image autorelease] forKey:@"albumArt"];	
		[_doc albumArtUpdated:self];
	}
    [[NSApplication sharedApplication] endSheet:_sheet];
}

- (void) didEndSheet:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    [sheet orderOut:self];
}

@end
