/*
 * TclGrowler.m
 *
 * Copyright (c) 2005, Toby Peterson <toby@opendarwin.org>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the Growl project nor the names of its
 *    contributors may be used to endorse or promote products derived from
 *    this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#include <Cocoa/Cocoa.h>

#include "GrowlApplicationBridge.h"

#include "TclGrowler.h"

@implementation TclGrowler

- (id)initWithName:(NSString *)aName notifications:(NSArray *)notes icon:(NSImage *)aIcon
{
	if ((self = [super init])) {
		appName = [[NSString alloc] initWithString:aName];
		allNotifications = [[NSArray alloc] initWithArray:notes];
		appIcon = [[NSData alloc] initWithData:[aIcon TIFFRepresentation]];

		[GrowlApplicationBridge setGrowlDelegate:self];
	}

	return self;
}

- (void)dealloc
{
	[appName release];
	[allNotifications release];
	[appIcon release];
	[super dealloc];
}

#pragma mark GrowlApplicationBridgeDelegate

- (NSDictionary *)registrationDictionaryForGrowl
{
	return [NSDictionary dictionaryWithObjectsAndKeys:
		allNotifications, GROWL_NOTIFICATIONS_ALL,
		allNotifications, GROWL_NOTIFICATIONS_DEFAULT,
		nil];
}

- (NSString *)applicationNameForGrowl
{
	return appName;
}

- (NSData *)applicationIconDataForGrowl
{
	return appIcon;
}

- (void)growlIsReady
{
}

- (void)growlNotificationWasClicked:(id)clickContext
{
}

@end
