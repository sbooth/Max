/*
 Copyright (c) The Growl Project, 2004-2005
 All rights reserved.


 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:


 1. Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 2. Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 3. Neither the name of Growl nor the names of its contributors
 may be used to endorse or promote products derived from this software
 without specific prior written permission.


 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

*/
#import <Foundation/Foundation.h>
#import <AppKit/NSImage.h>
#import <AppKit/NSWorkspace.h>
#import "GrowlDefines.h"
#import "GrowlDefinesInternal.h"
#import "GrowlPathway.h"
#import "GrowlUDPUtils.h"
#import "MD5Authenticator.h"
#import "cdsa.h"

#include <unistd.h>
#include <getopt.h>
#include <netinet/in.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>

#define NOTIFICATION_NAME @"Command-Line Growl Notification"

static const char usage[] =
"Usage: growlnotify [-hsvwc] [-i ext] [-I filepath] [--image filepath]\n"
"                   [-a appname] [-p priority] [-H host] [-u] [-P password]\n"
"                   [--port port] [-n name] [-m message] [-t] [title]\n"
"                   [-A method]\n"
"Options:\n"
"    -h,--help       Display this help\n"
"    -v,--version    Display version number\n"
"    -n,--name       Set the name of the application that sends the notification\n"
"                    [Default: growlnotify]\n"
"    -s,--sticky     Make the notification sticky\n"
"    -a,--appIcon    Specify an application name  to take the icon from\n"
"    -i,--icon       Specify a file type or extension to look up for the\n"
"                    notification icon\n"
"    -I,--iconpath   Specify a file whose icon will be the notification icon\n"
"       --image      Specify an image file to be used for the notification icon\n"
"    -m,--message    Sets the message to be used instead of using stdin\n"
"                    Passing - as the argument means read from stdin\n"
"    -p,--priority   Specify an int or named key (default is 0)\n"
"    -d,--identifier Specify a notification identifier (used for coalescing)\n"
"    -H,--host       Specify a hostname to which to send a remote notification.\n"
"    -P,--password   Password used for remote notifications.\n"
"    -u,--udp        Use UDP instead of DO to send a remote notification.\n"
"       --port       Port number for UDP notifications.\n"
"    -A,--auth       Specify digest algorithm for UDP authentication.\n"
"                    Either MD5 [Default], SHA256 or NONE.\n"
"    -c,--crypt      Encrypt UDP notifications.\n"
"    -w,--wait       Wait until the notification has been dismissed.\n"
"\n"
"Display a notification using the title given on the command-line and the\n"
"message given in the standard input.\n"
"\n"
"Priority can be one of the following named keys: Very Low, Moderate, Normal,\n"
"High, Emergency. It can also be an int between -2 and 2.\n"
"\n"
"To be compatible with gNotify the following switch is accepted:\n"
"    -t,--title      Does nothing. Any text following will be treated as the\n"
"                    title because that's the default argument behaviour\n";

static const char *version = "growlnotify 0.6\n"
"Copyright (c) The Growl Project, 2004-2005";

@interface GrowlNotificationObserver : NSObject
- (void) notificationDismissed:(id)clickContext;
@end

@implementation GrowlNotificationObserver {
}
- (void) notificationDismissed:(id)clickContext {
#pragma unused(clickContext)
	[NSApp terminate:self];
}
@end

int main(int argc, const char **argv) {
	// options
	extern char *optarg;
	extern int optind;
	int ch;
	BOOL isSticky = NO;
	BOOL wait = NO;
	char *appName = NULL;
	char *appIcon = NULL;
	char *iconExt = NULL;
	char *iconPath = NULL;
	char *imagePath = NULL;
	char *message = NULL;
	char *host = NULL;
	int priority = 0;
	BOOL useUDP = NO;
	BOOL crypt = NO;
	int flag;
	short port = 0;
	enum GrowlAuthenticationMethod authMethod = GROWL_AUTH_MD5;

	int code = EXIT_SUCCESS;
	struct hostent *he;
	int sock;
	unsigned size;
	CSSM_DATA registrationPacket, notificationPacket;
	struct sockaddr_in to;
	char *password = NULL;
	char *identifier = NULL;

	struct option longopts[] = {
		{ "help",		no_argument,		NULL,	'h' },
		{ "name",		required_argument,	NULL,	'n' },
		{ "icon",		required_argument,	NULL,	'i' },
		{ "iconpath",	required_argument,	NULL,	'I' },
		{ "appIcon",	required_argument,	NULL,	'a' },
		{ "image",		required_argument,	&flag,	 1  },
		{ "title",		no_argument,		NULL,	't' },
		{ "message",	required_argument,	NULL,	'm' },
		{ "priority",	required_argument,	NULL,	'p' },
		{ "host",		required_argument,	NULL,	'H' },
		{ "udp",		no_argument,		NULL,	'u' },
		{ "password",	required_argument,	NULL,	'P' },
		{ "port",		required_argument,	&flag,	 2  },
		{ "version",	no_argument,		NULL,	'v' },
		{ "identifier", required_argument,  NULL,   'd' },
		{ "wait",		no_argument,		NULL,   'w' },
		{ "auth",		required_argument,	NULL,   'A' },
		{ "crypt",      no_argument,        NULL,   'c' },
		{ "sticky",     no_argument,        NULL,   's' },
		{ NULL,			0,					NULL,	 0  }
	};

	while ((ch = getopt_long(argc, (char * const *)argv, "hvn:sa:i:I:p:tm:H:uP:d:wc", longopts, NULL)) != -1) {
		switch (ch) {
		case '?':
			puts(usage);
			exit(EXIT_FAILURE);
			break;
		case 'h':
			puts(usage);
			exit(EXIT_SUCCESS);
			break;
		case 'v':
			puts(version);
			exit(EXIT_SUCCESS);
			break;
		case 'n':
			appName = optarg;
			break;
		case 's':
			isSticky = YES;
			break;
		case 'i':
			iconExt = optarg;
			break;
		case 'I':
			iconPath = optarg;
			break;
		case 'a':
			appIcon = optarg;
			break;
		case 'p':
			if (sscanf(optarg, "%d", &priority) == 0) {
				// It's not an integer - is it one of the priority keys?
				char *keys[] = {"Very Low", "Moderate", "Normal", "High", "Emergency"};
				for (int i = 0; i < 5; i++) {
					if (strcmp(optarg, keys[i]) == 0) {
						priority = i - 2;
						break;
					}
				}
			}
			break;
		case 'A':
			if (!strcasecmp(optarg, "md5")) {
				authMethod = GROWL_AUTH_MD5;
			} else if (!strcasecmp(optarg, "sha256")) {
				authMethod = GROWL_AUTH_SHA256;
			} else if (!strcasecmp(optarg, "none")) {
				authMethod = GROWL_AUTH_NONE;
			} else {
				fprintf(stderr, "Unknown digest algorithm, using default.\n");
			}
			break;
		case 't':
			// do nothing
			break;
		case 'm':
			message = optarg;
			break;
		case 'H':
			host = optarg;
			break;
		case 'u':
			useUDP = YES;
			break;
		case 'P':
			password = optarg;
			break;
		case 'd':
			identifier = optarg;
			break;
		case 'w':
			wait = YES;
			break;
		case 'c':
			crypt = YES;
			break;
		case 0:
			if (flag == 1) {
				imagePath = optarg;
			} else if (flag == 2) {
				port = strtol(optarg, NULL, 0);
			}
			break;
		}
	}
	argc -= optind;
	argv += optind;

	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	// Deal with title
	NSMutableArray *argArray = [[NSMutableArray alloc] initWithCapacity:argc];
	while (argc--) {
		NSString *temp = [[NSString alloc] initWithUTF8String:(argv++)[0]];
		[argArray addObject:temp];
		[temp release];
	}
	[argArray removeObject:@""];
	NSString *title = [argArray componentsJoinedByString:@" "];
	[argArray release];

	// Deal with image
	// --image takes precedence over -I takes precedence over -i takes precedence over --a
	NSWorkspace *ws = [NSWorkspace sharedWorkspace];
	NSFileManager *mgr = [NSFileManager defaultManager];
	NSString *cwd;
	NSImage *image = nil;
	if (imagePath) {
		NSString *path = [[NSString stringWithUTF8String:imagePath] stringByStandardizingPath];
		if (![path isAbsolutePath]) {
			cwd = [mgr currentDirectoryPath];
			path = [cwd stringByAppendingPathComponent:path];
		}
		image = [[[NSImage alloc] initWithContentsOfFile:path] autorelease];
	} else if (iconPath) {
		NSString *path = [[NSString stringWithUTF8String:iconPath] stringByStandardizingPath];
		if (![path isAbsolutePath]) {
			cwd = [mgr currentDirectoryPath];
			path = [cwd stringByAppendingPathComponent:path];
		}
		image = [ws iconForFile:path];
	} else if (iconExt) {
		NSString *fileType = [[NSString alloc] initWithUTF8String:iconExt];
		image = [ws iconForFileType:fileType];
		[fileType release];
	} else if (appIcon) {
		NSString *app = [[NSString alloc] initWithUTF8String:appIcon];
		image = [ws iconForFile:[ws fullPathForApplication:app]];
		[app release];
	}
	if (!image) {
		image = [ws iconForFile:[ws fullPathForApplication:@"Terminal"]];
	}
	NSData *icon = [image TIFFRepresentation];

	// Check message
	NSString *desc;
	if (message && !(message[0] == '-' && message[1] == 0)) {
		// -m was used
		desc = [NSString stringWithUTF8String:message];
	} else {
		// Deal with stdin
		NSData *descData = [[NSFileHandle fileHandleWithStandardInput] readDataToEndOfFile];
		desc = [[[NSString alloc] initWithData:descData encoding:NSUTF8StringEncoding] autorelease];
		desc = [desc stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	}

	// Application name
	NSString *applicationName;
	if (appName) {
		applicationName = [NSString stringWithUTF8String:appName];
	} else {
		applicationName = @"growlnotify";
	}

	NSString *identifierString;
	if (identifier) {
		identifierString = [[NSString alloc] initWithUTF8String:identifier];
	} else {
		identifierString = nil;
	}

	// Register with Growl
	NSArray *defaultAndAllNotifications = [[NSArray alloc] initWithObjects:NOTIFICATION_NAME, nil];
	NSDictionary *registerInfo = [[NSDictionary alloc] initWithObjectsAndKeys:
		applicationName,            GROWL_APP_NAME,
		defaultAndAllNotifications, GROWL_NOTIFICATIONS_ALL,
		defaultAndAllNotifications, GROWL_NOTIFICATIONS_DEFAULT,
		icon,                       GROWL_APP_ICON,
		nil];
	[defaultAndAllNotifications release];

	// Notify
	NSString *clickContext = [[NSProcessInfo processInfo] globallyUniqueString];
	NSNumber *priorityNumber = [[NSNumber alloc] initWithInt:priority];
	NSNumber *stickyNumber = [[NSNumber alloc] initWithBool:isSticky];
	NSDictionary *notificationInfo = [[NSDictionary alloc] initWithObjectsAndKeys:
		NOTIFICATION_NAME, GROWL_NOTIFICATION_NAME,
		applicationName,   GROWL_APP_NAME,
		title,             GROWL_NOTIFICATION_TITLE,
		desc,              GROWL_NOTIFICATION_DESCRIPTION,
		priorityNumber,    GROWL_NOTIFICATION_PRIORITY,
		stickyNumber,      GROWL_NOTIFICATION_STICKY,
		icon,              GROWL_NOTIFICATION_ICON,
		clickContext,      GROWL_NOTIFICATION_CLICK_CONTEXT,
		identifierString,  GROWL_NOTIFICATION_IDENTIFIER,
		nil];
	[priorityNumber release];
	[stickyNumber   release];

	if (host) {
		if (cdsaInit()) {
			NSLog(@"ERROR: Could not initialize CDSA.");
		} else {
			if (useUDP) {
				he = gethostbyname(host);
				if (!he) {
					herror("gethostbyname");
					code = EXIT_FAILURE;
				} else {
					sock = socket( AF_INET, SOCK_DGRAM, IPPROTO_UDP );
					if (sock == -1) {
						perror("socket");
						code = EXIT_FAILURE;
					} else {
						to.sin_len = sizeof(to);
						to.sin_family = AF_INET;
						to.sin_port = htons(port ? port : GROWL_UDP_PORT);
						memcpy(&to.sin_addr.s_addr, he->h_addr_list[0], he->h_length);
						memset(&to.sin_zero, 0, sizeof(to.sin_zero));
					}
					registrationPacket.Data = [GrowlUDPUtils registrationToPacket:registerInfo
																		   digest:authMethod
																		 password:password
																	   packetSize:(unsigned *)&registrationPacket.Length];
					notificationPacket.Data = [GrowlUDPUtils notificationToPacket:notificationInfo
																		   digest:authMethod
																		 password:password
																	   packetSize:(unsigned *)&notificationPacket.Length];
					if (crypt) {
						CSSM_DATA passwordData;
						passwordData.Data = (uint8 *)password;
						if (password) {
							passwordData.Length = strlen(password);
						} else {
							passwordData.Length = 0U;
						}

						[GrowlUDPUtils cryptPacket:&registrationPacket algorithm:CSSM_ALGID_AES password:&passwordData encrypt:YES];
						[GrowlUDPUtils cryptPacket:&notificationPacket algorithm:CSSM_ALGID_AES password:&passwordData encrypt:YES];
					}
					size = (registrationPacket.Length > notificationPacket.Length) ? registrationPacket.Length : notificationPacket.Length;
					if (setsockopt(sock, SOL_SOCKET, SO_SNDBUF, (char *)&size, sizeof(size)) < 0) {
						perror("setsockopt: SO_SNDBUF");
					}
					//printf( "sendbuf: %d\n", size );
					//printf( "registration packet length: %d\n", registrationPacket.Length );
					//printf( "notification packet length: %d\n", notificationPacket.Length );
					if (sendto(sock, registrationPacket.Data, registrationPacket.Length, 0, (struct sockaddr *)&to, sizeof(to)) < 0) {
						perror("sendto");
						code = EXIT_FAILURE;
					}
					if (sendto(sock, notificationPacket.Data, notificationPacket.Length, 0, (struct sockaddr *)&to, sizeof(to)) < 0) {
						perror("sendto");
						code = EXIT_FAILURE;
					}
					free(registrationPacket.Data);
					free(notificationPacket.Data);
					close(sock);
				}
			} else {
				NSSocketPort *port = [[NSSocketPort alloc] initRemoteWithTCPPort:GROWL_TCP_PORT host:[NSString stringWithCString:host]];
				NSConnection *connection = [[NSConnection alloc] initWithReceivePort:nil sendPort:port];
				NSString *passwordString;
				if (password) {
					passwordString = [[NSString alloc] initWithUTF8String:password];
				} else {
					passwordString = nil;
				}
				MD5Authenticator *authenticator = [[MD5Authenticator alloc] initWithPassword:passwordString];
				[passwordString release];
				[connection setDelegate:authenticator];
				@try {
					NSDistantObject *theProxy = [connection rootProxy];
					[theProxy setProtocolForProxy:@protocol(GrowlNotificationProtocol)];
					id<GrowlNotificationProtocol> growlProxy = (id)theProxy;

					[growlProxy registerApplicationWithDictionary:registerInfo];
					[growlProxy postNotificationWithDictionary:notificationInfo];
				} @catch(NSException *e) {
					if ([[e name] isEqualToString:NSFailedAuthenticationException]) {
						NSLog(@"Authentication failed");
					} else {
						NSLog(@"Exception: %@", [e name]);
					}
				} @finally {
					[port release];
					[connection release];
					[authenticator release];
				}
			}
		}
	} else {
		NSDistributedNotificationCenter *distCenter = [NSDistributedNotificationCenter defaultCenter];
		GrowlNotificationObserver *growlNotificationObserver;
		if (wait) {
			growlNotificationObserver = [[GrowlNotificationObserver alloc] init];
			[distCenter addObserver:growlNotificationObserver
						   selector:@selector(notificationDismissed:)
							   name:[applicationName stringByAppendingString:GROWL_NOTIFICATION_CLICKED]
							 object:nil];
			[distCenter addObserver:growlNotificationObserver
						   selector:@selector(notificationDismissed:)
							   name:[applicationName stringByAppendingString:GROWL_NOTIFICATION_TIMED_OUT]
							 object:nil];
		} else {
			growlNotificationObserver = nil;
		}

		NSConnection *connection = [NSConnection connectionWithRegisteredName:@"GrowlApplicationBridgePathway" host:nil];
		if (connection) {
			//Post to Growl via GrowlApplicationBridgePathway
			@try {
				NSDistantObject *theProxy = [connection rootProxy];
				[theProxy setProtocolForProxy:@protocol(GrowlNotificationProtocol)];
				id<GrowlNotificationProtocol> growlProxy = (id)theProxy;
				[growlProxy registerApplicationWithDictionary:registerInfo];
				[growlProxy postNotificationWithDictionary:notificationInfo];
			} @catch(NSException *e) {
				NSLog(@"exception while sending notification: %@", e);
			}
		} else {
			//Post to Growl via NSDistributedNotificationCenter
			NSLog(@"could not find local GrowlApplicationBridgePathway, falling back to NSDNC");
			[distCenter postNotificationName:GROWL_APP_REGISTRATION object:nil userInfo:registerInfo options:NSNotificationPostToAllSessions];
			[distCenter postNotificationName:GROWL_NOTIFICATION object:nil userInfo:notificationInfo options:NSNotificationPostToAllSessions];
		}

		if (wait) {
			[[NSRunLoop currentRunLoop] run];
			[growlNotificationObserver release];
		}
	}

	[registerInfo     release];
	[notificationInfo release];
	[pool             release];

	return code;
}
