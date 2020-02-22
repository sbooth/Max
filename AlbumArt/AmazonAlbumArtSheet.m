/*
 *  Copyright (C) 2005 - 2007 Stephen F. Booth <me@sbooth.org>
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
#import "LogController.h"
#import "NSString+URLEscapingMethods.h"

// ========================================
// My amazon.com web services access ID
#define AWS_ACCESS_KEY_ID "18PZ5RH3H0X43PS96MR2"

static NSString *
queryStringComponentFromPair(NSString *field, NSString *value)
{
	NSCParameterAssert(nil != field);
	NSCParameterAssert(nil != value);
	
	return [NSString stringWithFormat:@"%@=%@", [field URLEscapedString], [value URLEscapedString]];
}

@interface AmazonAlbumArtSheet (Private)
- (NSString *) localeDomain;
@end

@implementation AmazonAlbumArtSheet

+ (void) initialize
{
	NSString					*defaultsValuesPath;
    NSDictionary				*defaultsValuesDictionary;
    
	@try {
		defaultsValuesPath = [[NSBundle mainBundle] pathForResource:@"AlbumArtDefaults" ofType:@"plist"];
		NSAssert1(nil != defaultsValuesPath, NSLocalizedStringFromTable(@"Your installation of Max appears to be incomplete.", @"Exceptions", @""), @"AlbumArtDefaults.plist");

		defaultsValuesDictionary = [NSDictionary dictionaryWithContentsOfFile:defaultsValuesPath];
		[[NSUserDefaults standardUserDefaults] registerDefaults:defaultsValuesDictionary];
	}
	
	@catch(NSException *exception) {
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert addButtonWithTitle:NSLocalizedStringFromTable(@"OK", @"General", @"")];
		[alert setMessageText:[NSString stringWithFormat:NSLocalizedStringFromTable(@"An error occurred while initializing the %@ class.", @"Exceptions", @""), @"AmazonAlbumArtSheet"]];
		[alert setInformativeText:[exception reason]];
		[alert setAlertStyle:NSWarningAlertStyle];		
		[alert runModal];
	}
}

- (id) initWithSource:(id <AlbumArtMethods>)source;
{
	if((self = [super init])) {
		BOOL	result;
		
		result = [NSBundle loadNibNamed:@"AmazonAlbumArtSheet" owner:self];
		NSAssert1(YES == result, NSLocalizedStringFromTable(@"Your installation of Max appears to be incomplete.", @"Exceptions", @""), @"AmazonAlbumArtSheet.nib");
		
		_source		= source;
		_images		= [[NSMutableArray alloc] init];

		if(nil != [_source artist])
			[_artistTextField setStringValue:[_source artist]];
		if(nil != [_source title])
			[_titleTextField setStringValue:[_source title]];
		
		[self setValue:[NSNumber numberWithBool:NO] forKey:@"searchInProgress"];
	}
	return self;
}

- (void) dealloc
{
	[_images release];	_images = nil;
	
	[super dealloc];
}

- (void) awakeFromNib
{
	[_localePopUpButton selectItemWithTag:[[NSUserDefaults standardUserDefaults] integerForKey:@"amazonDefaultLocale"]];
}

- (void) showAlbumArtMatches
{
    [[NSApplication sharedApplication] beginSheet:_sheet modalForWindow:[_source windowForSheet] modalDelegate:self didEndSelector:@selector(didEndSheet:returnCode:contextInfo:) contextInfo:nil];
	[self search:self];
}

- (IBAction) search:(id)sender
{
	[self setValue:[NSNumber numberWithBool:YES] forKey:@"searchInProgress"];
	
	// All searches start at this URL
	NSString *urlBase = [NSString stringWithFormat:@"http://ecs.amazonaws.%@/onca/xml", [self localeDomain]];
	
	// Build up the query string
	NSMutableArray *queryComponents = [NSMutableArray array];
	
	[queryComponents addObject:queryStringComponentFromPair(@"Service", @"AWSECommerceService")];
	[queryComponents addObject:queryStringComponentFromPair(@"AWSAccessKeyId", @ AWS_ACCESS_KEY_ID)];
	[queryComponents addObject:queryStringComponentFromPair(@"Version", @"2009-02-01")];
	[queryComponents addObject:queryStringComponentFromPair(@"Operation", @"ItemSearch")];
	[queryComponents addObject:queryStringComponentFromPair(@"SearchIndex", @"Music")];
	[queryComponents addObject:queryStringComponentFromPair(@"ResponseGroup", @"Small,Images")];
	[queryComponents addObject:queryStringComponentFromPair(@"Keywords", [NSString stringWithFormat:@"%@ %@", [_artistTextField stringValue], [_titleTextField stringValue]])];
	
	// Create the timestamp in XML dateTime format (omit milliseconds)
	NSCalendarDate *now = [NSCalendarDate calendarDate];
	[now setTimeZone:[NSTimeZone timeZoneWithName:@"GMT"]];
	[queryComponents addObject:queryStringComponentFromPair(@"Timestamp", [now descriptionWithCalendarFormat:@"%Y-%m-%dT%H:%M:%S.000Z"])];
	
	// Sort the parameters and form the canonical AWS query string
	[queryComponents sortUsingSelector:@selector(caseInsensitiveCompare:)];
	NSString *canonicalizedQueryString = [queryComponents componentsJoinedByString:@"&"];
	
	// Build the string which will be signed
	NSString *stringToSign = [NSString stringWithFormat:@"GET\necs.amazonaws.com\n/onca/xml\n%@", canonicalizedQueryString];
	
	// Calculate the HMAC for the string
	// This is done on a server to avoid revealing the secret key
	NSURL *signerURL = [NSURL URLWithString:@"http://sbooth.org/Max/sign_aws_query.php"];
	NSMutableURLRequest *signerURLRequest = [NSMutableURLRequest requestWithURL:signerURL];
	[signerURLRequest setHTTPMethod:@"POST"];
	[signerURLRequest setValue:[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"] forHTTPHeaderField:@"User-Agent"];
	[signerURLRequest setValue:@"application/x-www-form-urlencoded; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
	
	NSString *postBody = [NSString stringWithFormat:@"string_to_sign=%@", [stringToSign URLEscapedString]];	
	[signerURLRequest setValue:[NSString stringWithFormat:@"%ld", [postBody length]] forHTTPHeaderField:@"Content-Length"];
	[signerURLRequest setHTTPBody:[postBody dataUsingEncoding:NSUTF8StringEncoding]];	
	
	NSHTTPURLResponse *signerResponse = nil;
	NSError *error = nil;
	NSData *digestData = [NSURLConnection sendSynchronousRequest:signerURLRequest returningResponse:&signerResponse error:&error];
	if(!digestData) {
		[_sheet presentError:error modalForWindow:_sheet delegate:nil didPresentSelector:NULL contextInfo:NULL];
		return;
	}
	
	NSString *digestString = [[NSString alloc] initWithData:digestData encoding:NSUTF8StringEncoding];
	
	// Append the signature to the request
	[queryComponents addObject:queryStringComponentFromPair(@"Signature", digestString)];
	
	// Build the query string and search URL
	NSString *queryString = [queryComponents componentsJoinedByString:@"&"];
	NSURL *searchURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@?%@", urlBase, queryString]];
	
	NSXMLDocument *xmlDoc = [[NSXMLDocument alloc] initWithContentsOfURL:searchURL options:(NSXMLNodePreserveWhitespace | NSXMLNodePreserveCDATA) error:&error];
	if(nil == xmlDoc) {
		xmlDoc = [[NSXMLDocument alloc] initWithContentsOfURL:searchURL options:NSXMLDocumentTidyXML error:&error];
	}
	if(nil == xmlDoc) {
		if(error) {
			NSAlert *alert = [[[NSAlert alloc] init] autorelease];
			[alert addButtonWithTitle: NSLocalizedStringFromTable(@"OK", @"General", @"")];
			[alert setMessageText: NSLocalizedStringFromTable(@"An error occurred while attempting to download album artwork.", @"Exceptions", @"")];
			[[LogController sharedController] logMessage:NSLocalizedStringFromTable(@"An error occurred while attempting to download album artwork.", @"Exceptions", @"")];
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
		[alert setMessageText: NSLocalizedStringFromTable(@"An error occurred while attempting to download album artwork.", @"Exceptions", @"")];
		[[LogController sharedController] logMessage:NSLocalizedStringFromTable(@"An error occurred while attempting to download album artwork.", @"Exceptions", @"")];
		[alert setInformativeText: [error localizedDescription]];
		[alert setAlertStyle: NSWarningAlertStyle];
		
		[alert runModal];
		
		[self setValue:[NSNumber numberWithBool:NO] forKey:@"searchInProgress"];
		return;
	}
	
	NSXMLNode				*node, *childNode, *grandChildNode;
	NSEnumerator			*childrenEnumerator, *grandChildrenEnumerator;
	NSMutableDictionary		*dictionary;
	NSMutableArray			*images;
		
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
		[_source setAlbumArt:[image autorelease]];
		if([(NSObject *)_source respondsToSelector:@selector(setAlbumArtDownloadDate:)]) {
			[_source setAlbumArtDownloadDate:[NSDate date]];
		}
	}
    [[NSApplication sharedApplication] endSheet:_sheet];
}

- (void) didEndSheet:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    [sheet orderOut:self];
}

- (IBAction) visitAmazon:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:[@"http://www.amazon." stringByAppendingString:[self localeDomain]]]];
}

@end

@implementation AmazonAlbumArtSheet (Private)

- (NSString *) localeDomain
{
	switch([[_localePopUpButton selectedItem] tag]) {
		case kAmazonLocaleUSMenuItemTag:		return @"com";				break;
		case kAmazonLocaleFRMenuItemTag:		return @"fr";				break;
		case kAmazonLocaleCAMenuItemTag:		return @"ca";				break;
		case kAmazonLocaleDEMenuItemTag:		return @"de";				break;
		case kAmazonLocaleUKMenuItemTag:		return @"co.uk";			break;
		case kAmazonLocaleJAMenuItemTag:		return @"co.jp";			break;
		default:								return nil;					break;
	}	
}

@end
