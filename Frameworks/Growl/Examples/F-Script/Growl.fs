#!fscripter
GAB := (NSBundle bundleWithPath:'/Library/Frameworks/Growl.framework') principalClass.

notificationName := 'Test Notification'.
notifications := (NSArray alloc) initWithArray:({notificationName}).
delegate := (GrowlDelegate alloc) initWithAllNotifications:notifications defaultNotifications:notifications.
notifications release.
delegate setApplicationNameForGrowl:'F-Script Test'.

GAB setGrowlDelegate:delegate.
GAB notifyWithTitle:'Title' description:'test' notificationName:notificationName iconData:nil priority:0 isSticky:false clickContext:nil.

delegate release.
