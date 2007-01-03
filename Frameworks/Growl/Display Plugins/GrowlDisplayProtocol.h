//
//  GrowlDisplayProtocol.h
//  Growl
//

/*!	@header	GrowlDisplayProtocol.h
 *	@abstract	Protocols implemented by plug-ins' principal classes.
 *	@discussion	This header describes protocols that Growl uses to identify
 *	 specific types of plug-ins. As of Growl 0.6, there are two types of
 *	 plug-ins, each with its own protocol: display plug-ins, which display
 *	 Growl notifications to the user; and functional plug-ins, which add
 *	 features to the Growl core.
 */

@class NSPreferencePane;

/*!	@protocol	GrowlPlugin
 *	@abstract	The base plug-in protocol.
 *	@discussion	The methods declared in this protocol are supported by all
 *	 Growl plug-ins.
 */
@protocol GrowlPlugin <NSObject>

/*!	@method	preferencePane
 *	@abstract	Return an NSPreferencePane instance that manages the plugin's
 *	 preferences.
 *	@discussion	Your plug-in should put the controls for its preferences in
 *	 this preference pane.
 *
 *	 The size of the preference pane's view should be 354 pixels by 289 pixels.
 *	 This is because that's all the available space right now. We haven't yet
 *	 figured out what to do if there are more options than fit in that space.
 *	 You should set the springs of the view and its subviews under the
 *	 assumption that it can be resized horizontally and vertically to any size.
 *	@result	The preference pane.
 */
- (NSPreferencePane *) preferencePane;

@end

/*!	@protocol	GrowlDisplayPlugin
 *	@abstract	The display plugin protocol.
 *	@discussion	This protocol declares all methods supported by Growl display plugins.
 */
@protocol GrowlDisplayPlugin <GrowlPlugin>

/*!	@method	displayNotificationWithInfo:
 *	@abstract	Tells the display plugin to display a notification with the
 *	 given information.
 *	@param	noteDict	The userInfo dictionary that describes the notification.
 *	@discussion	This method is not required to display to the screen. For
 *	 example, 0.6 comes with a Log display which writes the notification to a
 *	 file or the Console log, a MailMe display which sends the notification in
 *	 an email message, and a Speech display which reads the notification's
 *	 description aloud.
 */
- (void) displayNotificationWithInfo:(NSDictionary *) noteDict;

@end

/*!	@protocol	GrowlFunctionalPlugin
 *	@abstract	The functional plugin protocol.
 *	@discussion	This protocol declares all methods supported by Growl
 *	 functionality plugins.
 *
 *	 Currently does not require any more methods than the GrowlPlugin protocol.
 */
@protocol GrowlFunctionalPlugin <GrowlPlugin>
//empty for now
@end
