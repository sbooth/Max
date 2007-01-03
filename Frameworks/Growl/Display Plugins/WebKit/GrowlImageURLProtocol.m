//
//  GrowlImageURLProtocol.m
//  Growl
//
//  Created by Ingmar Stein on 15.04.05.
//  Copyright 2005 The Growl Project. All rights reserved.
//

#import "GrowlImageURLProtocol.h"

@implementation GrowlImageURLProtocol
+ (void) initialize {
	[super initialize];
	[NSURLProtocol registerClass:[GrowlImageURLProtocol class]];
}

+ (BOOL) canInitWithRequest:(NSURLRequest *)request {
	return [[[request URL] scheme] isEqualToString:@"growlimage"];
}

+ (NSURLRequest *) canonicalRequestForRequest:(NSURLRequest *)request {
	return request;
}

- (void) startLoading {
	NSURLRequest *request = [self request];
	NSURL *url = [request URL];
	NSString *imageName = [url host];
	NSImage *image = [NSImage imageNamed:imageName];
	NSData *imageData = [image TIFFRepresentation];
	NSURLResponse *response = [[NSURLResponse alloc] initWithURL:url
														MIMEType:@"image/tiff"
										   expectedContentLength:[imageData length]
												textEncodingName:nil];
	[response autorelease];

	id <NSURLProtocolClient> client = [self client];
	[client URLProtocol:self
	 didReceiveResponse:response
	 cacheStoragePolicy:NSURLCacheStorageNotAllowed];
	[client URLProtocol:self
			didLoadData:imageData];
	[client URLProtocolDidFinishLoading:self];
}

- (void) stopLoading {
	// nothing to do
}
@end
