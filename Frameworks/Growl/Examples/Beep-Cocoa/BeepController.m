#import "BeepController.h"
#import "BeepAdditions.h"

#define GROWL_NOTIFICATION_DEFAULT @"NotificationDefault"

@interface BeepController (PRIVATE)
- (void)tableViewSelectionDidChange:(NSNotification *)aNotification;

- (void)notificationsDidChange;
@end

@implementation BeepController

- (id) init {
    if ( self = [super init] ) {
        notifications = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void) dealloc {
	[notificationPanel release];
	[notificationDefault release];
	[notificationSticky release];
	[notificationPriority release];
	[notificationDescription release];
	[notificationImage release];
	[notificationTitle release];
	[addEditButton release];

	[addButtonTitle release];
	[editButtonTitle release];

	[mainWindow release];
	[notificationsTable release];
	[registered release];
	[addNotification release];
	[removeNotification release];
	[sendButton release];

    [notifications release];

	[super dealloc];
}

- (void) awakeFromNib {
	[notificationsTable setDoubleAction:@selector(showEditSheet:)];
	[self tableViewSelectionDidChange:nil];

	addButtonTitle = [[addEditButton title] retain]; //this is the default title in the nib
	editButtonTitle = [NSLocalizedString(@"Edit", /*comment*/ NULL) retain];

	[GrowlApplicationBridge setGrowlDelegate:self];
}

#pragma mark Main window actions

- (IBAction)showAddSheet:(id)sender {
#pragma unused(sender)
	//reset controls to default values
	[notificationDefault     setState:NSOnState];
	[notificationSticky      setState:NSOffState];
	[notificationPriority    selectItemAtIndex:2]; //middle item: 'Normal' priority
	[notificationImage       setImage:nil];
	static NSString *empty = @"";
	[notificationDescription setStringValue:empty];
	[notificationTitle       setStringValue:empty];

	[notificationPanel makeFirstResponder:[notificationPanel initialFirstResponder]];
	[addEditButton setTitle:addButtonTitle];
	[NSApp beginSheet:notificationPanel
	   modalForWindow:mainWindow
		modalDelegate:self
	   didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
		  contextInfo:nil];
}

- (IBAction)showEditSheet:(id)sender {
#pragma unused(sender)
	int index = [notificationsTable selectedRow];
	if(index < 0)
		NSBeep();
	else {
		NSDictionary *dict = [notifications objectAtIndex:index];
		[notificationDefault     setState:[dict stateForKey:GROWL_NOTIFICATION_DEFAULT]];
		[notificationSticky      setState:[dict stateForKey:GROWL_NOTIFICATION_STICKY]];
		int priority = [[dict objectForKey:GROWL_NOTIFICATION_PRIORITY] intValue];
		[notificationPriority    selectItemAtIndex:[notificationPriority indexOfItemWithTag:priority]];
		NSImage *image = [[[NSImage alloc] initWithData:[dict objectForKey:GROWL_NOTIFICATION_ICON]] autorelease];
		[notificationImage       setImage:image];
		[notificationDescription setStringValue:[dict objectForKey:GROWL_NOTIFICATION_DESCRIPTION]];
		[notificationTitle       setStringValue:[dict objectForKey:GROWL_NOTIFICATION_TITLE]];

		[notificationPanel makeFirstResponder:[notificationPanel initialFirstResponder]];
		[addEditButton setTitle:editButtonTitle];

		[NSApp beginSheet:notificationPanel
		   modalForWindow:mainWindow
			modalDelegate:self
		   didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
			  contextInfo:[[NSNumber alloc] initWithInt:index]];
	}
}

- (IBAction)removeNotification:(id)sender {
#pragma unused(sender)
	int selectedRow = [notificationsTable selectedRow];
	if(selectedRow < 0) {
		//no selection
		NSBeep();
		return;
	} else {
		[notifications removeObjectAtIndex:selectedRow];
		[notificationsTable reloadData];
	}

	[self notificationsDidChange];
}

- (IBAction)sendNotification:(id)sender {
#pragma unused(sender)
	int selectedRow = [notificationsTable selectedRow];

	if (selectedRow != -1){
		//send a notification for the selected table cell
		NSDictionary *note = [notifications objectAtIndex:selectedRow];

		//NSLog( @"note - %@", note );
		[GrowlApplicationBridge notifyWithTitle:[note objectForKey:GROWL_NOTIFICATION_TITLE]
							description:[note objectForKey:GROWL_NOTIFICATION_DESCRIPTION]
					   notificationName:[note objectForKey:GROWL_NOTIFICATION_NAME]
							   iconData:[note objectForKey:GROWL_NOTIFICATION_ICON]
							   priority:[[note objectForKey:GROWL_NOTIFICATION_PRIORITY] intValue]
							   isSticky:[[note objectForKey:GROWL_NOTIFICATION_STICKY] boolValue]
						   clickContext:nil];
	}
}

#pragma mark Add/Edit sheet actions

- (IBAction)clearImage:(id)sender {
	[notificationImage setImage:nil];
}

- (IBAction)OKNotification:(id)sender {
	[NSApp endSheet:[sender window] returnCode:NSOKButton];
}
- (IBAction)cancelNotification:(id)sender {
	[NSApp endSheet:[sender window] returnCode:NSCancelButton];
}

/*
- (IBAction) endPanel:(id)sender {
	NSWindow *sheet = [sender window];
    [NSApp endSheet:sheet];
	[sheet orderOut:sender];
}
*/

- (void) sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	if(returnCode == NSOKButton) {
		NSNumber *defaultValue = [NSNumber numberWithBool:[notificationDefault state] == NSOnState];
		NSNumber *stickyValue  = [NSNumber numberWithBool:[notificationSticky state] == NSOnState];
		NSNumber *priority     = [NSNumber numberWithInt:[[notificationPriority selectedItem] tag]];
		NSData   *imageData    = [[notificationImage image] TIFFRepresentation];
		NSString *title        = [notificationTitle stringValue];
		NSString *desc         = [notificationDescription stringValue];

		NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
			title,         GROWL_NOTIFICATION_NAME,
			title,         GROWL_NOTIFICATION_TITLE,
			desc,          GROWL_NOTIFICATION_DESCRIPTION,
			priority,      GROWL_NOTIFICATION_PRIORITY,
			defaultValue,  GROWL_NOTIFICATION_DEFAULT,
			stickyValue,   GROWL_NOTIFICATION_STICKY,
			imageData,     GROWL_NOTIFICATION_ICON,
			nil];

		NSNumber *indexNum = contextInfo;
		if(indexNum) {
			[notifications replaceObjectAtIndex:[indexNum unsignedIntValue]
									 withObject:dict];
			[indexNum release];
		} else {
			[notifications addObject:dict];
		}

		[notificationsTable reloadData];
	}

	[sheet orderOut:self];

	[self notificationsDidChange];
}

//After notifications change, tell the app bridge to re-register us with Growl so it knows about the new notifications
- (void)notificationsDidChange
{
	[GrowlApplicationBridge reregisterGrowlNotifications];
}

#pragma mark Table Data Source Methods

- (int)numberOfRowsInTableView:(NSTableView *)tableView {
#pragma unused(tableView)
    return [notifications count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)col row:(int)row {
#pragma unused(tableView, col, row)
    return [[notifications objectAtIndex:row] objectForKey:GROWL_NOTIFICATION_NAME];
}

#pragma mark Table Delegate Methods

- (BOOL)tableView:(NSTableView *)tableView shouldEditTableColumn:(NSTableColumn *)col row:(int)row {
#pragma unused(tableView, col, row)
    return NO;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
#pragma unused(notification)
	BOOL rowIsSelected = ([notificationsTable selectedRow] != -1);

	[sendButton setEnabled:rowIsSelected];
}

#pragma mark NSApplication Delegate Methods

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)app {
	return YES;
}

#pragma mark Growl Delegate methods

- (NSString *)applicationNameForGrowl {
	return @"Beep-Cocoa";
}

//Return the registration dictionary
- (NSDictionary *)registrationDictionaryForGrowl {

	NSMutableArray *defNotesArray = [NSMutableArray array];
	NSMutableArray *allNotesArray = [NSMutableArray array];
	NSNumber *isDefaultNum;
	unsigned numNotifications = [notifications count];

	//Build an array of all notifications we want to use
	for ( unsigned i = 0U; i < numNotifications; ++i ) {
		NSDictionary *def = [notifications objectAtIndex:i];
		[allNotesArray addObject:[def objectForKey:GROWL_NOTIFICATION_NAME]];

		isDefaultNum = [def objectForKey:GROWL_NOTIFICATION_DEFAULT];
		if ( isDefaultNum && [isDefaultNum boolValue] ) {
			[defNotesArray addObject:[NSNumber numberWithUnsignedInt:i]];
		}
	}

	//Set these notifications both for ALL (all possibilites) and DEFAULT (the ones enabled by default)
	NSDictionary *regDict = [NSDictionary dictionaryWithObjectsAndKeys:
		allNotesArray, GROWL_NOTIFICATIONS_ALL,
		defNotesArray, GROWL_NOTIFICATIONS_DEFAULT,
		nil];

	return regDict;
}

- (void)growlIsReady {
	NSLog(@"Growl engaged, Captain!");
}

@end

