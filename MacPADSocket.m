//
//  MacPADSocket.m
//  MacPAD Version Check
//
//  Created by Kevin Ballard on Sun Dec 07 2003.
//  Copyright (c) 2003 TildeSoft. All rights reserved.
//

#import "MacPADSocket.h"
#import <sys/socket.h>
#import <sys/types.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <unistd.h>

// Constant strings
NSString *MacPADErrorCode = @"MacPADErrorCode";
NSString *MacPADErrorMessage = @"MacPADErrorMessage";
NSString *MacPADNewVersionAvailable = @"MacPADNewVersionAvailable";

// NSNotifications
NSString *MacPADErrorOccurredNotification = @"MacPADErrorOccurredNotification";
NSString *MacPADCheckFinishedNotification = @"MacPADCheckFinishedNotification";

enum {
    kNumberType,
    kStringType,
    kPeriodType
};

@implementation MacPADSocket

// Code
- (id)init
{
    if (self = [super init]) {
        _fileHandle = nil;
        _currentVersion = nil;
        _newVersion = nil;
        _releaseNotes = nil;
        _productPageURL = nil;
        _productDownloadURLs = nil;
        _buffer = nil;
    }
    return self;
}

- (void)performCheck:(NSURL *)url withVersion:(NSString *)version
{
    // Make sure we were actually *given* stuff
    if (url == nil || version == nil) {
        // Bah
        [self returnError:kMacPADResultMissingValues message:@"URL or version was nil"];
        return;
    }
    
    // Save the current version
    _currentVersion = [version copy];
    
    NSNumber *port = [url port];
    if (port == nil) {
        // No port information? Default to 80 - it's http!
        port = [NSNumber numberWithInt:80];
    }
    NSString *host = [url host];
    if (host == nil) {
        // Not a valid URL? Error out
        [self returnError:kMacPADResultInvalidURL message:@"Invalid URL"];
        return;
    }
    NSString *path = [url path];
    if (path == nil || [path isEqualToString:@""]) {
        path = @"/";
    }
    
    NSSocketPort *socketPort = [[NSSocketPort alloc] initRemoteWithTCPPort:[port intValue] host:host];
    if ([socketPort address] == nil) {
        // The URL isn't valid
        [self returnError:kMacPADResultInvalidURL message:@"Couldn't resolve remote host address"];
        return;
    }
    struct sockaddr *address = (struct sockaddr *)[[socketPort address] bytes];
    [socketPort release];
    int remoteSocket = socket(address->sa_family, SOCK_STREAM, 0);
    
    if (connect(remoteSocket, address, address->sa_len) != 0) {
        // Couldn't connect
        close(remoteSocket);
        [self returnError:kMacPADResultInvalidURL message:@"Couldn't connect to remote host"];
        return;
    }
    
    // In case we tried to check during a check, we should release the old filehandle and unregister
    // ourselves with the notification center
    [_fileHandle release];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    _fileHandle = [[NSFileHandle alloc] initWithFileDescriptor:remoteSocket closeOnDealloc:YES];
    
    // Now that we have our socket, lets make our request.
    // It's just a simple GET statement.
    NSString *data = [NSString stringWithFormat:@"GET %@ HTTP/1.1\r\nHost: %@\r\n\r\n", path, host];
    [_fileHandle writeData:[data dataUsingEncoding:NSASCIIStringEncoding]];
    
    // Init a couple of variables
    // Releasing the strings shouldn't be necessary, but what if someone
    // re-uses a socket? We don't want to leave extra strings hanging about
    _contentLength = 0;
    _headersReceived = NO;
    _statusReceived = NO;
    [_newVersion release];
    _newVersion = nil;
    [_releaseNotes release];
    _releaseNotes = nil;
    [_productPageURL release];
    _productPageURL = nil;
    [_productDownloadURLs release];
    _productDownloadURLs = nil;
    [_buffer release];
    _buffer = [[NSMutableString alloc] init];
    
    // Now lets start listening for the response
    // First we have to register ourselves with the notification center
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(processData:)
                                                 name:NSFileHandleReadCompletionNotification object:_fileHandle];
    [_fileHandle readInBackgroundAndNotify];
}

- (void)performCheckWithVersion:(NSString *)version
{
    // This method makes use of the MacPAD.url file inside the application bundle
    // If this file isn't there, or it's not in the correct format, this will return
    // error kMacPADResultMissingValues with an appropriate message
    // If it is there, it calls performCheck:withVersion: with the URL
    NSString *path = [[NSBundle mainBundle] pathForResource:@"MacPAD" ofType:@"url"];
    if (path == nil) {
        // File is missing
        [self returnError:kMacPADResultMissingValues message:@"MacPAD.url file was not found"];
        return;
    }
    NSString *contents = [NSString stringWithContentsOfFile:path];
    if (contents == nil) {
        // The file can't be opened
        [self returnError:kMacPADResultMissingValues message:@"The MacPAD.url file can't be opened"];
        return;
    }
    
    NSString *urlString;
    NSRange range = [contents rangeOfString:@"URL="];
    if (range.location != NSNotFound) {
        // We have a URL= prefix
        range.location += range.length;
        range.length = [contents length] - range.location;
        urlString = [contents substringWithRange:range];
    } else {
        // The file is the URL
        urlString = contents;
    }
    // Strip whitespace
    urlString = [urlString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    // Perform the check
    [self performCheck:[NSURL URLWithString:urlString] withVersion:version];
}

- (void)performCheckWithURL:(NSURL *)url
{
    // Gets the version from the Info.plist file and calls performCheck:withVersion:
    NSString *version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
    [self performCheck:url withVersion:version];
}

- (void)performCheck
{
    // Gets the version from the Info.plist file and calls performCheckWithVersion:
    NSString *version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
    [self performCheckWithVersion:version];
}

- (void)setDelegate:(id)delegate
{
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    if (_delegate != nil) {
        // Unregister with the notification center
        [nc removeObserver:_delegate name:MacPADErrorOccurredNotification object:self];
        [nc removeObserver:_delegate name:MacPADCheckFinishedNotification object:self];
        [_delegate autorelease];
    }
    _delegate = [delegate retain];
    // Register the new MacPADSocketNotification methods for the delegate
    // Only register if the delegate implements it, though
    if ([_delegate respondsToSelector:@selector(macPADErrorOccurred:)]) {
        [nc addObserver:_delegate selector:@selector(macPADErrorOccurred:)
                          name:MacPADErrorOccurredNotification object:self];
    }
    if ([_delegate respondsToSelector:@selector(macPADCheckFinished:)]) {
        [nc addObserver:_delegate selector:@selector(macPADCheckFinished:)
                          name:MacPADCheckFinishedNotification object:self];
    }
}

- (NSString *)releaseNotes
{
    if (_releaseNotes == nil) {
        return @"";
    } else {
        return [[_releaseNotes copy] autorelease];
    }
}

- (NSString *)newVersion
{
    if (_newVersion == nil) {
        return @"";
    } else {
        return [[_newVersion copy] autorelease];
    }
}

- (NSString *)productPageURL
{
    if (_productPageURL == nil) {
        return @"";
    } else {
        return [[_productPageURL copy] autorelease];
    }
}

- (NSString *)productDownloadURL
{
    if (_productDownloadURLs != nil && [_productDownloadURLs count] >= 1) {
        return [_productDownloadURLs objectAtIndex:0];
    } else {
        return @"";
    }
}

- (NSArray *)productDownloadURLs
{
    if (_productDownloadURLs == nil) {
        return [NSArray array];
    } else {
        return [[_productDownloadURLs copy] autorelease];
    }
}

- (void)returnError:(MacPADResultCode)code message:(NSString *)msg
{
    NSNumber *yesno = [NSNumber numberWithBool:(code == kMacPADResultNewVersion)];
    NSNumber *errorCode = [NSNumber numberWithInt:code];
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:yesno, MacPADNewVersionAvailable,
                                                msg, MacPADErrorMessage, errorCode, MacPADErrorCode, nil];
    if (code == 0 || code == 5) {
        // Not an error
        [[NSNotificationCenter defaultCenter] postNotificationName:MacPADCheckFinishedNotification
                                                            object:self userInfo:userInfo];
    } else {
        // It's an error
        [[NSNotificationCenter defaultCenter] postNotificationName:MacPADErrorOccurredNotification
                                                            object:self userInfo:userInfo];
    }
}

- (void)processData:(NSNotification *)aNotification
{
    // Get the new data and append it to the buffer
    NSData *data = [[aNotification userInfo] objectForKey:NSFileHandleNotificationDataItem];
    NSString *strData = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    [_buffer appendString:strData];
    [strData release];
    
    // Have we already received headers yet?
    if (!_headersReceived) {
        // Have we checked status yet?
        if (!_statusReceived) {
            // First, make sure that this is an HTTP response.
            // Check the beginning for "HTTP/1". If it's not there, close and error out.
            // First, make sure we've even received that much data
            if ([_buffer length] >= sizeof("HTTP/1")) {
                if (![[_buffer substringWithRange:NSMakeRange(0, 6)] isEqualToString:@"HTTP/1"]) {
                    // Not an HTTP response
                    [_fileHandle closeFile];
                    [_fileHandle release];
                    _fileHandle = nil;
                    [self returnError:kMacPADResultInvalidURL message:@"Not a valid HTTP response"];
                    return;
                }
                // Get the response status
                int loc = [_buffer rangeOfString:@" "].location + 1;
                if (loc != NSNotFound && [_buffer length] >= loc + 3) {
                    NSString *status = [_buffer substringWithRange:NSMakeRange(loc, 3)];
                    if (![status isEqualToString:@"200"]) {
                        // Whoops, it's not a good response
                        [_fileHandle closeFile];
                        [_fileHandle release];
                        _fileHandle = nil;
                        if ([status isEqualToString:@"404"]) {
                            // File doesn't exist
                            [self returnError:kMacPADResultInvalidURL message:@"File doesn't exist on remote host"];
                        } else {
                            // Unknown error
                            [self returnError:kMacPADResultInvalidURL
                                      message:[NSString stringWithFormat:@"HTTP status not good: %@", status]];
                        }
                        return;
                    }
                    _statusReceived = YES;
                }
            }
        }
        // Lets check if at *this* point we've received the status
        if (_statusReceived) {
            // Now, check to see if we have the entire block of headers
            NSRange endRange = [_buffer rangeOfString:@"\r\n\r\n"];
            if (endRange.location != NSNotFound) {
                // We have our headers. Let's grab Content-Length and strip the headers from the buffer
                // Pull out the headers
                NSString *headers = [_buffer substringToIndex:endRange.location];
                _headersReceived = YES;
                // Strip them from the buffer
                [_buffer deleteCharactersInRange:NSMakeRange(0, endRange.location + 4)];
                
                // Examine the headers for Content-Length
                NSRange lengthRange = [headers rangeOfString:@"Content-Length: "];
                if (lengthRange.location == NSNotFound) {
                    // No Content-Length? Something's wrong. Let's close the socket and error out
                    [_fileHandle closeFile];
                    [_fileHandle release];
                    _fileHandle = nil;
                    [self returnError:kMacPADResultInvalidFile message:@"No data was returned"];
                    return;
                }
                NSRange crlfRange = [headers rangeOfString:@"\r\n" options:0
                                                     range:NSMakeRange(lengthRange.location,
                                                                       [headers length] - lengthRange.location)];
                int i = lengthRange.location + lengthRange.length;
                _contentLength = [[headers substringWithRange:NSMakeRange(i, crlfRange.location - i)] intValue];
            }
        }
    }
    // Lets check *now* to see if we've found the headers, and, if so, if we have the entire file
    if (_headersReceived && [_buffer length] >= _contentLength) {
        // Yep, we got all our data
        // Lets close our socket
        [_fileHandle closeFile];
        [_fileHandle release];
        _fileHandle = nil;
        
        // Lets process our data
        [self processFileData:_buffer];
    } else {
        // Nope, not done yet
        // Lets continue reading
        [_fileHandle readInBackgroundAndNotify];
    }
}

- (void)processFileData:(NSString *)data
{
    // Ok, lets process this data
    NSData *plist = [NSData dataWithBytes:[data UTF8String] length:[data length]];
    NSString *errorStr;
    id obj = [NSPropertyListSerialization propertyListFromData:plist
                                              mutabilityOption:NSPropertyListImmutable format:NULL
                                              errorDescription:&errorStr];
    if (obj == nil) {
        // File isn't valid property list
        [self returnError:kMacPADResultInvalidFile message:@"File isn't valid XML"];
        return;
    }
    if (![obj isKindOfClass:[NSDictionary class]]) {
        // File isn't valid format
        [self returnError:kMacPADResultBadSyntax message:@"File isn't correct syntax"];
        return;
    }
    
    NSDictionary *dict = obj;
    _newVersion = [[dict objectForKey:@"productVersion"] copy];
    if (_newVersion == nil) {
        // File is missing version information
        [self returnError:kMacPADResultBadSyntax message:@"Product version information missing"];
        return;
    }
    
    // Get release notes
    _releaseNotes = [[dict objectForKey:@"productReleaseNotes"] copy];
    
    // Get product page URL
    _productPageURL = [[dict objectForKey:@"productPageURL"] copy];
    
    // Get the first product download URL
    _productDownloadURLs = [[dict objectForKey:@"productDownloadURL"] copy];
    
    // Compare versions
    if ([self compareVersion:_newVersion toVersion:_currentVersion] == NSOrderedAscending) {
        // It's a new version
        [self returnError:kMacPADResultNewVersion message:@"New version available"];
    } else {
        [self returnError:kMacPADResultNoNewVersion message:@"No new version available"];
    }
    
    // We're done
}

- (void)dealloc
{
    // Unregister the delegate with the notification center
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc removeObserver:_delegate name:MacPADErrorOccurredNotification object:self];
    [nc removeObserver:_delegate name:MacPADCheckFinishedNotification object:self];
    [nc removeObserver:self];
    
    // Release objects
    [_delegate release];
    [_fileHandle release];
    [_currentVersion release];
    [_buffer release];
    [_newVersion release];
    [_releaseNotes release];
    [_productPageURL release];
    [_productDownloadURLs release];
    
    [super dealloc];
}

- (NSComparisonResult)compareVersion:(NSString *)versionA toVersion:(NSString *)versionB
{
    NSArray *partsA = [self splitVersion:versionA];
    NSArray *partsB = [self splitVersion:versionB];
    
    NSString *partA, *partB;
    int i, n, typeA, typeB, intA, intB;
    
    n = MIN([partsA count], [partsB count]);
    for (i = 0; i < n; ++i) {
        partA = [partsA objectAtIndex:i];
        partB = [partsB objectAtIndex:i];
        
        typeA = [self getCharType:partA];
        typeB = [self getCharType:partB];
        
        // Compare types
        if (typeA == typeB) {
            // Same type; we can compare
            if (typeA == kNumberType) {
                intA = [partA intValue];
                intB = [partB intValue];
                if (intA > intB) {
                    return NSOrderedAscending;
                } else if (intA < intB) {
                    return NSOrderedDescending;
                }
            } else if (typeA == kStringType) {
                NSComparisonResult result = [partA compare:partB];
                if (result != NSOrderedSame) {
                    return result;
                }
            }
        } else {
            // Not the same type? Now we have to do some validity checking
            if (typeA != kStringType && typeB == kStringType) {
                // typeA wins
                return NSOrderedAscending;
            } else if (typeA == kStringType && typeB != kStringType) {
                // typeB wins
                return NSOrderedDescending;
            } else {
                // One is a number and the other is a period. The period is invalid
                if (typeA == kNumberType) {
                    return NSOrderedAscending;
                } else {
                    return NSOrderedDescending;
                }
            }
        }
    }
    // The versions are equal up to the point where they both still have parts
    // Lets check to see if one is larger than the other
    if ([partsA count] != [partsB count]) {
        // Yep. Lets get the next part of the larger
        // n holds the value we want
        NSString *missingPart;
        int missingType, shorterResult, largerResult;
        
        if ([partsA count] > [partsB count]) {
            missingPart = [partsA objectAtIndex:n];
            shorterResult = NSOrderedDescending;
            largerResult = NSOrderedAscending;
        } else {
            missingPart = [partsB objectAtIndex:n];
            shorterResult = NSOrderedAscending;
            largerResult = NSOrderedDescending;
        }
        
        missingType = [self getCharType:missingPart];
        // Check the type
        if (missingType == kStringType) {
            // It's a string. Shorter version wins
            return shorterResult;
        } else {
            // It's a number/period. Larger version wins
            return largerResult;
        }
    }
    
    // The 2 strings are identical
    return NSOrderedSame;
}

- (NSArray *)splitVersion:(NSString *)version
{
    NSString *character;
    NSMutableString *s;
    int i, n, oldType, newType;
    NSMutableArray *parts = [NSMutableArray array];
    if ([version length] == 0) {
        // Nothing to do here
        return parts;
    }
    s = [[[version substringToIndex:1] mutableCopy] autorelease];
    oldType = [self getCharType:s];
    n = [version length] - 1;
    for (i = 1; i <= n; ++i) {
        character = [version substringWithRange:NSMakeRange(i, 1)];
        newType = [self getCharType:character];
        if (oldType != newType || oldType == kPeriodType) {
            // We've reached a new segment
            [parts addObject:[s copy]];
            [s setString:character];
        } else {
            // Add character to string and continue
            [s appendString:character];
        }
        oldType = newType;
    }
    
    // Add the last part onto the array
    [parts addObject:[s copy]];
    return parts;
}

- (int)getCharType:(NSString *)character
{
    if ([character isEqualToString:@"."]) {
        return kPeriodType;
    } else if ([character isEqualToString:@"0"] || [character intValue] != 0) {
        return kNumberType;
    } else {
        return kStringType;
    }
}
@end
