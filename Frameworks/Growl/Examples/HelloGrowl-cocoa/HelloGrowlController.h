/* HelloGrowlController */

#import <Cocoa/Cocoa.h>

@interface HelloGrowlController : NSObject
{
    IBOutlet NSTextField *notificationDescriptionTextField;
    IBOutlet NSTextField *notificationTitleTextField;



}
- (IBAction)growlIt:(id)sender;
@end
