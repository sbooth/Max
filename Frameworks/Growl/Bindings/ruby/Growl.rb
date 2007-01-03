### Copyright
#
# Copyright 2004 Thomas Kollbach <dev@bitfever.de>
# 
# Released under the BSD license.
#
### Description
#
# A ruby class that enables posting notifications to the Growl daemon.
# See <http://growl.info> for more information.
# 
# Requires RubyCocoa (http://www.fobj.com/rubycocoa/) and Ruby 1.8
# (http://ruby-lang.org).
#
### Versions
# 
# v0.1- 25.11.2004 - Initial version, this is less more then a ruby translation of 
#                    the python bindings
#
# TODO: transform this into a ruby-module, so it is usable as a mixin
#       for ruby-scripts
#
### Usage
#
# Here is a short example how to use this in a script
#
#    n = GrowlNotifier.new('bla',['Foo'],nil,OSX::NSWorkspace.sharedWorkspace().iconForFileType_('unknown'))
#    n.register()
#
#    n.notify('Foo', 'Test Notification', 'Blah blah blah')   
#
###

require 'osx/cocoa'

$priority = {"Very Low" => -2,
             "Moderate" => -1,
             "Normal"   =>  0,
             "High"     =>  1,
             "Emergency"=>  2
             }
             

class GrowlNotifier
#    A class that abstracts the process of registering and posting
#    notifications to the Growl daemon.
#
#    `appName': The name of the application
#    `notifications': an array of notifications - default is an empty array
#
#    `defaultNotifications': optional - defaults to the value of
#    `notifications'  
#    `appIcon' is also optional but defaults to a senseless icon so 
#    so you are higly encouraged to pass it along.
#

    def initialize(appName='GrowlNotifier', notifications=[], defaultNotifications=nil, appIcon=nil)
        @appName = appName
        @notifications = notifications
        @defaultNotifications = defaultNotifications
        @appIcon = appIcon       
    end #initialize
    
    def register
        if @appIcon == nil  then
            @appIcon = OSX::NSWorkspace.sharedWorkspace().iconForFileType_("txt") 
        end
        if @defaultNotifications == nil then
            @defaultNotifications = @notifications
        end
        
        regData = {
            'ApplicationName'=>@appName,
            'AllNotifications'=> OSX::NSArray.arrayWithArray(@notifications),
            'DefaultNotifications'=> OSX::NSArray.arrayWithArray(@defaultNotifications),
            'ApplicationIcon'=> @appIcon.TIFFRepresentation
                  }
                  
        dict = OSX::NSDictionary.dictionaryWithDictionary(regData)
        notifyCenter = OSX::NSDistributedNotificationCenter.defaultCenter
        
        notifyCenter.postNotificationName_object_userInfo_deliverImmediately_("GrowlApplicationRegistrationNotification", nil, dict, true)
    end #register

    def notify(noteType, title, description, icon=nil, appIcon=nil, sticky=false, priority=nil)
#        Post a notification to the Growl daemon.
#
#        `noteType' is the name of the notification that is being posted.
#        `title' is the user-visible title for this notification.
#        `description' is the user-visible description of this notification.
#        `icon' is an optional icon for this notification.  It defaults to
#            `@applicationIcon'.
#        `appIcon' is an optional icon for the sending application.
#        `sticky' is a boolean controlling whether the notification is sticky.

 
       @notifications << noteType
       if icon == nil then icon = @appIcon end
       
       notification = {'NotificationName'=> noteType,
             'ApplicationName'=> @appName,
             'NotificationTitle'=> title,
             'NotificationDescription'=> description,
             'NotificationIcon'=> icon.TIFFRepresentation()}
       
       unless appIcon == nil 
            notification['NotificationAppIcon'] = appicon.TIFFRepresentation
       end     
       
       if sticky 
            notification['NotificationSticky'] = OSX::NSNumber.numberWithBool_(true) 
       end
            
       unless priority == nil 
            notification['NotificationPriority'] = OSX::NSNumber.numberWithInt_(priority)
       end
            
       d = OSX::NSDictionary.dictionaryWithDictionary_(notification)
       
       notCenter = OSX::NSDistributedNotificationCenter.defaultCenter()
       notCenter.postNotificationName_object_userInfo_deliverImmediately_('GrowlNotification', nil, d, true)
       
    end #notify
end #class growlnotifier

