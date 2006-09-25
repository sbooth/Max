#import <Cocoa/Cocoa.h>
#include <Carbon/Carbon.h>
#import "GrowlPreferences.h"
#import "GrowlPathUtil.h"
#include <string.h>
#include <unistd.h>
#include <stdlib.h>
#import "BuildDate.h"

static const char *argv0 = NULL;
static int status = EXIT_SUCCESS;

#ifdef REINVENTED_WHEEL
static NSSet    *valueTypeFlags = nil;
static NSString *plistError     = nil;

//interprets a property list from argv using defaults-like rules.
static id propertyListFromArgv(int argc, const char **argv, int i, int *next_i);
#endif

static void printversion(void) {
	printf("%s 0.7 built on %s\n", argv0, BUILD_DATE);
}
static void printusage(void) {
	printf("usage: %s <command> [arguments]\n"
		   "commands:\n"
		   "\t""start - start Growl\n"
		   "\t""stop - stop Growl\n"
		   "\t""restart - restart Growl\n"
		   "\t""isRunning [-q] - query whether Growl is running (with -q, reflect this in the exit status rather than stdout)\n"
		   "\t""startmenu - add the Growl Menu Extra to your menu bar\n"
		   "\t""stopmenu - remove the Growl Menu Extra from your menu bar\n"
		   "\t""getpref [name] - obtain one or all of Growl's preferences\n"
		   "\t""setpref <name> <value> - set one of Growl's preferences\n"
		   "\t""help - print this message\n"
		   "\t""version - print version information\n",
		   argv0);
}

int main (int argc, const char **argv) {
	argv0 = (argc < 1) ? "growlctl" : argv[0];

	if (argc < 2) {
		printversion();
		printusage();
	} else {
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		GrowlPreferences *growlPref = [GrowlPreferences preferences];

		//control whether Growl is running
		if (!strcmp(argv[1], "start")) {
			[growlPref setGrowlRunning:YES noMatterWhat:NO];
		} else if (!strcmp(argv[1], "stop")) {
			[growlPref setGrowlRunning:NO noMatterWhat:NO];
		} else if (!strcmp(argv[1], "restart")) {
			[growlPref terminateGrowl];
			[growlPref setGrowlRunning:YES noMatterWhat:YES];
		} else if (!strcasecmp(argv[1], "isRunning")) {
			BOOL isRunning = [growlPref isGrowlRunning];
			if ((argc < 3) || strcasecmp(argv[2], "-q"))
				printf("Growl is %s""running\n", isRunning ? "" : "not ");
			status = !isRunning;

		//control the state of the Growl Menu Extra
		} else if (!strcmp(argv[1], "startmenu")) {
			NSBundle *prefpane = [GrowlPathUtil growlPrefPaneBundle];
			NSString *path = [prefpane pathForResource:@"GrowlMenu" ofType:@"app"];
			if (!path) {
				fprintf(stderr, "Could not launch the status item, because it was not found in the Growl preference-pane bundle at %s\n", [[prefpane bundlePath] UTF8String]);
				status = EXIT_FAILURE;
			} else {
				BOOL success = [[NSWorkspace sharedWorkspace] openFile:nil
													   withApplication:path
														 andDeactivate:NO];
				if (!success) {
					fputs("Could not launch the status item (unknown reason)\n", stderr);
					status = EXIT_FAILURE;
				}
			}
		} else if (!strcmp(argv[1], "stopmenu")) {
			//quit the status item with a GrowlMenuShutdown notification
			[[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"GrowlMenuShutdown" object:nil];
		//directly (more or less) access Growl defaults
		} else if (!strcmp(argv[1], "getpref")) {
			NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
			NSDictionary *growlPrefs = [defaults persistentDomainForName:HelperAppBundleIdentifier];

			id obj = argc > 2 ? [growlPrefs objectForKey:[NSString stringWithUTF8String:argv[2]]] : growlPrefs;
			NSString *str;
			if ([obj respondsToSelector:@selector(stringValue)]) //e.g. numbers
				str = [obj stringValue];
			else
				str = [obj description];

			if (argc > 2) {
				printf("%s = %s\n", argv[2], [str UTF8String]);
			} else {
				printf("%s\n", [str UTF8String]);
			}
		} else if (!strcmp(argv[1], "setpref")) {
			/*setpref's arguments are of the same syntax as defaults(1).
			 *rather than reinvent the wheel, we just pass the same arguments
			 *	to defaults, and let it do the work.
			 */
			if (argc < 3) {
				fprintf(stderr, "%s: setpref requires a name and a value\n", argv0);
				status = EXIT_FAILURE;
			} else {
#ifdef REINVENTED_WHEEL
				valueTypeFlags = [[NSSet alloc] initWithObjects:
					@"-bool",  @"-boolean",
					@"-int",   @"-float",
					@"-array", @"-array-add",
					@"-dict",  @"-dict-add",
					nil];

				NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
				NSMutableDictionary *growlPrefsDict = [[[defaults persistentDomainForName:HelperAppBundleIdentifier] mutableCopy] autorelease];

				NSString *key = [NSString stringWithUTF8String:argv[2]];
				id value = propertyListFromArgv(argc, argv, 3, /*next_i*/ NULL);

				if (value) {
					[growlPrefsDict setObject:value forKey:key];
					[defaults setPersistentDomain:growlPrefsDict forName:HelperAppBundleIdentifier];
					[defaults synchronize];
				} else if (plistError) {
					fprintf(stderr, "%s: could not interpret property list data: %s\n", argv0, [plistError UTF8String]);
					status = EXIT_FAILURE;
				}
				[valueTypeFlags release];
#else //ifndef REINVENTED_WHEEL
				/*our command line:
				 *	growlctl setpref key value
				 *defaults' command line:
				 *	defaults write com.growl.growlhelperapp key value
				 *additionally, the argv must be NULL-terminated.
				 */
				const char **defaultsArgv = malloc((argc + 2) * sizeof(char *));
				defaultsArgv[0] = "defaults";
				defaultsArgv[1] = "write";
				defaultsArgv[2] = [HelperAppBundleIdentifier UTF8String];
				unsigned i = 2U;
				for (; i < (unsigned)argc; ++i)
					defaultsArgv[i+1] = argv[i];
				defaultsArgv[i+1] = NULL;
				status = -execvp("defaults", (char *const *)defaultsArgv);
				free(defaultsArgv);
#endif
			}

		//other
		} else if (!strcmp(argv[1], "help")) {
			printusage();
		} else if (!strcmp(argv[1], "version")) {
			printversion();
		} else {
			fprintf(stderr, "%s: unrecognized command '%s'\n", argv0, argv[1]);
			status = EXIT_FAILURE;
		}

		[growlPref release];
		[pool release];
	}

	return status;
}

#ifdef REINVENTED_WHEEL
static id propertyListFromArgv(int argc, const char **argv, int i, int *next_i) {
	id value = nil;
	int old_i = i;

	if (i < argc) {
		NSString *valueType = [NSString stringWithUTF8String:argv[i]];
		if ([valueTypeFlags containsObject:valueType]) {
			if (++i > argc) {
				fprintf(stderr, "%s: value type (%s) supplied, but no value\n", argv0, argv[i-1]);
				status = EXIT_FAILURE;
			} else {
				//interpret according to the rules of defaults.
				NSString     *valueString = [NSString stringWithUTF8String:argv[i]];
				BOOL add = NO;
				if ([valueType hasPrefix:@"-bool"]) {
					value = [NSNumber numberWithBool: [valueString  boolValue]];
				} else if ([valueType isEqualToString:@"-int"]) {
					value = [NSNumber numberWithInt:  [valueString   intValue]];
				} else if ([valueType isEqualToString:@"-float"]) {
					value = [NSNumber numberWithFloat:[valueString floatValue]];
				} else if ([valueType hasPrefix:@"-array"]) {
					NSMutableArray *a = [NSMutableArray arrayWithCapacity:(argc - 3)];
					id obj;

					while ((obj = propertyListFromArgv(argc, argv, i, &i)))
						[a addObject:obj];

					add = (i == 4) && [valueType hasSuffix:@"-add"];
					if (add) {
						NSMutableArray *existing = nil; //[[[growlPrefsDict objectForKey:key] mutableCopy] autorelease];
						if (existing && [existing isKindOfClass:[NSArray class]]) {
							[existing addObjectsFromArray:a];
							value = existing;
						} else
							value = a;
					} else
						value = a;
				} else if ([valueType hasPrefix:@"-dict"]) {
					NSMutableDictionary *d = [NSMutableDictionary dictionaryWithCapacity:(argc - 3) / 2];

					NSString *k = valueString, *v = propertyListFromArgv(argc, argv, ++i, &i);
					while (i < argc) {
						k = [NSString stringWithUTF8String:argv[i++]];
						v = propertyListFromArgv(argc, argv, i, &i);
						if (k && !v) {
							fprintf(stderr, "%s: key %s has no value", argv0, argv[i - 1]);
							goto end;
						} else {
							[d setObject:v forKey:k];
						}
					}
					add = (i == 4) && [valueType hasSuffix:@"-add"];
					if (add) {
						NSMutableDictionary *existing = nil;//[[[growlPrefsDict objectForKey:key] mutableCopy] autorelease];
						if (existing && [existing isKindOfClass:[NSDictionary class]]) {
							[existing addEntriesFromDictionary:d];
							value = existing;
						} else
							value = d;
					} else
						value = d;
				}
			}
		} //if ([valueTypeFlags containsObject:valueType])
		else {
			NSData *valueData = [NSData dataWithBytes:argv[i] length:strlen(argv[i])];
			value = [NSPropertyListSerialization propertyListFromData:valueData
													 mutabilityOption:NSPropertyListImmutable
															   format:NULL
													 errorDescription:&plistError];
		}
	} //if (i < argc)
	/*
	 else {
		 //read from stdin.
		 NSFileHandle *stdinFH = [NSFileHandle fileHandleWithStandardInput];
		 NSData *valueData = [stdinFH availableData];
		 value = [NSPropertyListSerialization propertyListFromData:valueData
												  mutabilityOption:NSPropertyListImmutable
															format:NULL
												  errorDescription:&plistError];
	 }
	 */

end:
		if (next_i)
			*next_i = value ? i : old_i;
	return value;
}
#endif
