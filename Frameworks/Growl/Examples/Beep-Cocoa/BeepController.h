
#import <Growl/Growl.h>

/* BeepController */


@interface BeepController: NSObject<GrowlApplicationBridgeDelegate>
{
	IBOutlet NSPanel		*notificationPanel;			// The Add/Edit Panel
	IBOutlet NSButton		*notificationDefault;		// Whether this notification is allowed by default
	IBOutlet NSButton		*notificationSticky;		// Whether this notification is sticky
	IBOutlet NSPopUpButton	*notificationPriority;		// Priority of the notification
	IBOutlet NSTextField	*notificationDescription;	// The long description
	IBOutlet NSImageView	*notificationImage;			// The associated image
	IBOutlet NSTextField	*notificationTitle;			// The title of this notification
	IBOutlet NSButton		*addEditButton;				// The OK button for the panel
	NSString *addButtonTitle, *editButtonTitle;

	IBOutlet NSWindow		*mainWindow;
	IBOutlet NSTableView	*notificationsTable;		// The table of notifications
	IBOutlet NSButton		*registered;				// The magic button that registers/unregisters
	IBOutlet NSButton		*addNotification;			// The button button that opens the add note pane
	IBOutlet NSButton		*removeNotification;		// The remove button (TBR)
	IBOutlet NSButton		*sendButton;				// The button to send a notification

	//data
	NSMutableArray			*notifications;				// The Array of notifications
}

- (IBAction)showAddSheet:(id)sender;
- (IBAction)showEditSheet:(id)sender;

//actions in sheet
- (IBAction)OKNotification:(id)sender;
- (IBAction)cancelNotification:(id)sender;
- (IBAction)clearImage:(id)sender;

//actions in main window
//- (IBAction)addNotification:(id)sender; //the + button
- (IBAction)removeNotification:(id)sender; //the - button
- (IBAction)sendNotification:(id)sender; //the Send button
//- (IBAction)endPanel:(id)sender;

@end

