/*
 * Project:     growlpinger
 * File:        Pinger.m
 * Author:      Andrew Wellington
 *
 * License:
 * Copyright (C) 2005 Andrew Wellington.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice,
 * this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 * this list of conditions and the following disclaimer in the documentation
 * and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR "AS IS" AND ANY EXPRESS OR IMPLIED
 * WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 * EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
 * OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
 * OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 * ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "Pinger.h"
#import "GrowlDefines.h"

extern int code;
extern int verbose;

@implementation Pinger

- (id)initWithInterval:(NSTimeInterval)interval {
	if ((self = [super init])) {
		NSTimer *timeout, *ping;
		NSDistributedNotificationCenter *distCenter = [NSDistributedNotificationCenter defaultCenter];
		[distCenter addObserver:self
					   selector:@selector(receivedPong:)
						   name:GROWL_PONG
						 object:nil];
		[distCenter addObserver:self
					   selector:@selector(receivedReady:)
						   name:GROWL_IS_READY
						 object:nil];

		if (interval) {
			timeout = [NSTimer scheduledTimerWithTimeInterval:interval
													   target:self
													 selector:@selector(timeout:)
													 userInfo:nil
													  repeats:NO];
		}

		ping = [NSTimer scheduledTimerWithTimeInterval:0.5
												target:self
											  selector:@selector(sendPing:)
											  userInfo:nil
											   repeats:YES];
		[self sendPing: self];
	}

	return self;
}

- (void)sendPing:(id)sender {
	NSDistributedNotificationCenter *distCenter = [NSDistributedNotificationCenter defaultCenter];
	[distCenter postNotificationName:GROWL_PING object:nil userInfo:nil];
}

- (void)receivedPong:(NSNotification *)notification {
	code = 0;
	if (verbose)
		fputs("Growl is alive: received pong\n", stdout);
	[NSApp terminate:self];
}

- (void)receivedReady:(NSNotification *)notification {
	code = 0;
	if (verbose)
		fputs("Growl is alive: received startup notification\n", stdout);
	[NSApp terminate:self];
}

- (void)timeout:(id)userinfo
{
	code = 1;
	if (verbose)
		fputs("Growl is dead: timed out\n", stdout);
	[NSApp terminate:self];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
	//die rather inelegantly so we can send the right code to the parent
	exit(code);
}

@end
