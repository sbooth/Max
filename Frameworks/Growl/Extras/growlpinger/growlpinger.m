/*
 * Project:     growlpinger
 * File:        growlpinger.m
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

#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>
#import "Pinger.h"

#include <unistd.h>


static const char usage[] =
"Usage: %s [-h] [-t timeout]\n"
"Options:\n"
"    -h		display this help\n"
"    -t		timeout before we give up\n"
"    -v		prints verbose information\n";

int code = 0;
int	verbose = 0;

int main (int argc, char *argv[]) {
	NSTimeInterval timeout = 0.0;

	//options
	int ch;

	while ((ch = getopt(argc, argv, "ht:v")) != -1) {
		switch (ch) {
			case '?':
			case 'h':
			default:
				printf(usage, argv[0]);
				exit(1);
				break;
			case 't':
				timeout = strtod(optarg, NULL);
				if (timeout <= 0) {
					printf("Timeout value invalid\n");
					printf(usage, argv[0]);
					exit(1);
				}
				break;
			case 'v':
				verbose = 1;
				break;
		}
	}
	argc -= optind;
	argv += optind;

	[[NSAutoreleasePool alloc] init];
	[NSApplication sharedApplication];
	Pinger *pinger = [[Pinger alloc] initWithInterval:timeout];

	[NSApp setDelegate:pinger];
	[NSApp run];

	//We should never return according to the NSApplication documentation.
    return EXIT_FAILURE;
}
