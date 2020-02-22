/*
 *  Copyright (C) 2005 - 2020 Stephen F. Booth <me@sbooth.org>
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

#import "PostProcessingPreferencesController.h"
#import "PreferencesController.h"
#import "UtilityFunctions.h"

@interface PostProcessingPreferencesController (Private)
- (void)	synchronizeDefaults;
@end

@implementation PostProcessingPreferencesController

- (id) init
{
	if((self = [super initWithWindowNibName:@"PostProcessingPreferences"])) {
		return self;		
	}
	return nil;
}

- (void) awakeFromNib
{
	NSArray			*applications		= nil;
	NSString		*applicationPath	= nil;
	NSDictionary	*applicationEntry	= nil;
	unsigned		i;
		
	// Set up the list of applications for post processing
	applications = [[NSUserDefaults standardUserDefaults] stringArrayForKey:@"postProcessingApplications"];
	for(i = 0; i < [applications count]; ++i) {
		applicationPath		= [applications objectAtIndex:i];
		applicationEntry	= [NSMutableDictionary dictionaryWithObjects:[NSArray arrayWithObjects:applicationPath, [[NSFileManager defaultManager] displayNameAtPath:applicationPath], GetIconForFile(applicationPath, NSMakeSize(16, 16)), nil] 
																 forKeys:[NSArray arrayWithObjects:@"path", @"displayName", @"icon", nil]];
		
		[_postProcessingActionsController addObject:applicationEntry];
	}
	
	// Set the sort descriptor
	[_postProcessingActionsController setSortDescriptors:[NSArray arrayWithObjects:
		[[[NSSortDescriptor alloc] initWithKey:@"displayName" ascending:YES] autorelease],
		nil]];
}

- (IBAction) addPostProcessingApplication:(id)sender
{
	NSOpenPanel		*panel		= [NSOpenPanel openPanel];

	[panel setAllowsMultipleSelection:YES];
	[panel setAllowedFileTypes:@[@"app"]];

	[panel beginSheetModalForWindow:[[PreferencesController sharedPreferences] window] completionHandler:^(NSModalResponse result) {
		if(NSOKButton == result) {
			NSArray				*applications		= [panel URLs];
			NSDictionary		*application		= nil;
			NSString			*applicationPath	= nil;
			unsigned			i;

			for(i = 0; i < [applications count]; ++i) {
				applicationPath = [[applications objectAtIndex:i] path];
				application		= [NSMutableDictionary dictionaryWithObjects:[NSArray arrayWithObjects:applicationPath, [[NSFileManager defaultManager] displayNameAtPath:applicationPath], GetIconForFile(applicationPath, NSMakeSize(16, 16)), nil]
																	 forKeys:[NSArray arrayWithObjects:@"path", @"displayName", @"icon", nil]];

				// Don't add existing items
				if(0 == [[[_postProcessingActionsController arrangedObjects] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"path == %@", applicationPath]] count]) {
					[_postProcessingActionsController addObject:application];
				}
			}
		}

		[self synchronizeDefaults];
	}];
}

- (IBAction) removePostProcessingApplication:(id)sender
{
	[_postProcessingActionsController remove:sender];
	[self synchronizeDefaults];
}

@end

@implementation PostProcessingPreferencesController (Private)

- (void) synchronizeDefaults
{
	NSArray				*applications		= nil;
	NSMutableArray		*applicationPaths	= nil;
	unsigned			i;

	applications		= [_postProcessingActionsController arrangedObjects];
	applicationPaths	= [NSMutableArray array];
	
	for(i = 0; i < [applications count]; ++i) {
		[applicationPaths addObject:[[applications objectAtIndex:i] objectForKey:@"path"]];
	}

	[[NSUserDefaults standardUserDefaults] setObject:applicationPaths forKey:@"postProcessingApplications"];
}

@end
