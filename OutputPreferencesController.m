#import "OutputPreferencesController.h"
#import "PreferencesController.h"

#define kDiscNumberButton		0
#define kDiscsInSetButton		1
#define kDiscArtistButton		2
#define kDiscTitleButton		3
#define kDiscGenreButton		4
#define kDiscYearButton			5
#define kTrackNumberButton		6
#define kTrackArtistButton		7
#define kTrackTitleButton		8
#define kTrackGenreButton		9
#define kTrackYearButton		10

@implementation OutputPreferencesController

- (id) init
{
	if((self = [super initWithWindowNibName:@"OutputPreferences"])) {
		return self;		
	}
	return nil;
}

- (void) awakeFromNib
{
	// Update the example track text field
	[self controlTextDidChange:nil];
}
	
- (IBAction)customNamingButtonAction:(id)sender
{
	NSString *string;
	
	switch([(NSButton *)sender tag]) {
		case kDiscNumberButton:			string = @"{discNumber}";		break;
		case kDiscsInSetButton:			string = @"{discsInSet}";		break;
		case kDiscArtistButton:			string = @"{discArtist}";		break;
		case kDiscTitleButton:			string = @"{discTitle}";		break;
		case kDiscGenreButton:			string = @"{discGenre}";		break;
		case kDiscYearButton:			string = @"{discYear}";			break;
		case kTrackNumberButton:		string = @"{trackNumber}";		break;
		case kTrackArtistButton:		string = @"{trackArtist}";		break;
		case kTrackTitleButton:			string = @"{trackTitle}";		break;
		case kTrackGenreButton:			string = @"{trackGenre}";		break;
		case kTrackYearButton:			string = @"{trackYear}";		break;
	}
	
	NSText *fieldEditor = [_customNameTextField currentEditor];
	if(nil == fieldEditor) {
		[_customNameTextField setStringValue:string];
	}
	else {
		if([_customNameTextField textShouldBeginEditing:fieldEditor]) {
			[fieldEditor replaceCharactersInRange:[fieldEditor selectedRange] withString:string];
			[_customNameTextField textShouldEndEditing:fieldEditor];
			[self controlTextDidChange:nil];
		}
	}
}

- (IBAction)selectOutputDirectory:(id)sender
{
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	
	[panel setAllowsMultipleSelection:NO];
	[panel setCanChooseDirectories:YES];
	[panel setCanChooseFiles:NO];
	
	[panel beginSheetForDirectory:nil file:nil types:nil modalForWindow:[[PreferencesController sharedPreferences] window] modalDelegate:self didEndSelector:@selector(openPanelDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

- (void) openPanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    if(NSOKButton == returnCode) {
		NSArray		*filesToOpen	= [sheet filenames];
		int			count			= [filesToOpen count];
		int			i;
		
		for(i = 0; i < count; ++i) {
			NSString *aFile = [filesToOpen objectAtIndex:i];
			[[[NSUserDefaultsController sharedUserDefaultsController] values] setValue:aFile forKey:@"outputDirectory"];
		}
	}	
}

#pragma mark Delegate methods

- (void) controlTextDidChange:(NSNotification *)aNotification
{
	NSString *scheme = [_customNameTextField stringValue];
	if(nil == scheme) {
		scheme = [[NSUserDefaults standardUserDefaults] stringForKey:@"customNamingScheme"];
	}
	// No love
	if(nil == scheme) {
		return;
	}
	
	NSMutableString *sample = [[[NSMutableString alloc] initWithCapacity:[scheme length]] autorelease];
	[sample setString:scheme];		
	
	[sample replaceOccurrencesOfString:@"{discNumber}"		withString:@"" options:nil range:NSMakeRange(0, [sample length])];
	[sample replaceOccurrencesOfString:@"{discsInSet}"		withString:@"" options:nil range:NSMakeRange(0, [sample length])];
	[sample replaceOccurrencesOfString:@"{discArtist}"		withString:@"Nirvana" options:nil range:NSMakeRange(0, [sample length])];
	[sample replaceOccurrencesOfString:@"{discTitle}"		withString:@"MTV Unplugged in New York" options:nil range:NSMakeRange(0, [sample length])];
	[sample replaceOccurrencesOfString:@"{discGenre}"		withString:@"Grunge" options:nil range:NSMakeRange(0, [sample length])];
	[sample replaceOccurrencesOfString:@"{discYear}"		withString:@"1994" options:nil range:NSMakeRange(0, [sample length])];
	[sample replaceOccurrencesOfString:@"{trackNumber}"		withString:@"4" options:nil range:NSMakeRange(0, [sample length])];
	[sample replaceOccurrencesOfString:@"{trackArtist}"		withString:@"" options:nil range:NSMakeRange(0, [sample length])];
	[sample replaceOccurrencesOfString:@"{trackTitle}"		withString:@"The Man Who Sold the World" options:nil range:NSMakeRange(0, [sample length])];
	[sample replaceOccurrencesOfString:@"{trackGenre}"		withString:@"" options:nil range:NSMakeRange(0, [sample length])];
	[sample replaceOccurrencesOfString:@"{trackYear}"		withString:@"" options:nil range:NSMakeRange(0, [sample length])];
	
	[self setValue:sample forKey:@"customNameExample"];
}

@end
