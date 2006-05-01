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

#import "ConverterTask.h"
#import "ConverterMethods.h"
#import "ConverterController.h"
#import "MallocException.h"
#import "IOException.h"
#import "StopException.h"
#import "MissingResourceException.h"

@implementation ConverterTask

+ (void) initialize
{
	NSString				*defaultsValuesPath;
    NSDictionary			*defaultsValuesDictionary;
    
	@try {
		defaultsValuesPath = [[NSBundle mainBundle] pathForResource:@"ConverterTaskDefaults" ofType:@"plist"];
		if(nil == defaultsValuesPath) {
			@throw [MissingResourceException exceptionWithReason:NSLocalizedStringFromTable(@"Your installation of Max appears to be incomplete.", @"Exceptions", @"")
														userInfo:[NSDictionary dictionaryWithObject:@"ConverterTaskDefaults.plist" forKey:@"filename"]];
		}
		defaultsValuesDictionary = [NSDictionary dictionaryWithContentsOfFile:defaultsValuesPath];
		[[NSUserDefaults standardUserDefaults] registerDefaults:defaultsValuesDictionary];
	}
	
	@catch(NSException *exception) {
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert addButtonWithTitle:NSLocalizedStringFromTable(@"OK", @"General", @"")];
		[alert setMessageText:[NSString stringWithFormat:NSLocalizedStringFromTable(@"An error occurred while initializing the %@ class.", @"Exceptions", @""), @"ConverterController"]];
		[alert setInformativeText:[exception reason]];
		[alert setAlertStyle:NSWarningAlertStyle];		
		[alert runModal];
	}
}

- (id) initWithInputFile:(NSString *)inputFilename metadata:(AudioMetadata *)metadata
{
	if((self = [super initWithMetadata:metadata])) {
		_inputFilename	= [inputFilename retain];
		_connection		= nil;
		
		return self;
	}
	return nil;
}

- (void) dealloc
{
	if(nil != _connection) {
		[_connection release];
	}
	
	[_inputFilename release];	
	[super dealloc];
}

- (NSString *) description 
{
	NSString *description = [_metadata description];
	
	if([description isEqualToString:NSLocalizedStringFromTable(@"Unknown Track", @"CompactDisc", @"")]) {
		return [_inputFilename lastPathComponent]; 
	}
	else {
		return [[description retain] autorelease];
	}
}

- (void) run
{
	NSPort		*port1			= [NSPort port];
	NSPort		*port2			= [NSPort port];
	NSArray		*portArray		= nil;

	_connection = [[NSConnection alloc] initWithReceivePort:port1 sendPort:port2];
	[_connection setRootObject:self];

	portArray = [NSArray arrayWithObjects:port2, port1, nil];

	[super setStarted];

	[NSThread detachNewThreadSelector:@selector(connectWithPorts:) toTarget:_converterClass withObject:portArray];
}

- (void) converterReady:(id)anObject
{
    [anObject setProtocolForProxy:@protocol(ConverterMethods)];
	[self touchOutputFile];
	[anObject convertToFile:[self outputFilename]];
}

- (void) setStarted
{
	[super setStarted];
	[[ConverterController sharedController] converterTaskDidStart:self]; 
}

- (void) setStopped 
{
	[super setStopped];
	
	[_connection invalidate];
	[_connection release];
	_connection = nil;
	
	[[ConverterController sharedController] converterTaskDidStop:self]; 
}

- (void) setCompleted 
{
	[super setCompleted]; 
	
	[_connection invalidate];
	[_connection release];
	_connection = nil;
	
	[[ConverterController sharedController] converterTaskDidComplete:self];	
}

- (void) stop
{
	if([self started] && NO == [self stopped]) {
		[self setShouldStop];
	}
	else {
		[self setStopped];
	}
}

- (void) setException:(NSException *)exception
{
	NSAlert		*alert		= nil;
	
	[super setException:exception];
	
	alert = [[[NSAlert alloc] init] autorelease];
	[alert addButtonWithTitle:NSLocalizedStringFromTable(@"OK", @"General", @"")];
	[alert setMessageText:[NSString stringWithFormat:NSLocalizedStringFromTable(@"An error occurred while converting the file \"%@\".", @"Exceptions", @""), [[self inputFilename] lastPathComponent]]];
	[alert setInformativeText:[[self exception] reason]];
	[alert setAlertStyle:NSWarningAlertStyle];		
	[alert runModal];
}

- (NSString *)		inputFilename					{ return _inputFilename; }
- (NSString *)		inputFormat						{ return NSLocalizedStringFromTable(@"Unknown", @"General", @""); }

@end
