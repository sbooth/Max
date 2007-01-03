GrowlDict
______________________________________

Installation:
1) Build in Xcode, using deployment. (For questions about deployment see: http://growl.info/documentation/xcode.php)
2) Copy GrowlDict to ~/Library/Services 
		Note: You may need to create this directory
3) Log out.

How to use it:
GrowlDict is a simple service that runs in the background. To use it simply highlight a word and select Lookup Word from the Services menu under the Application menu (for example, in Safari, the Safari menu). Alternatively, you can just press command-shift-F. The definition of the word will be posted in a Growl notification.

How it works:
GrowlDict does a lookup by calling curl on your machine and having it do a query using the dict protocol against the dict.org server. The key combination is located in the Info.plist within the app, although this will be customizable at some point. The location of the server is within the code itself, but this also will become customizable in the future.

Questions or comments can be sent to the growl-discuss list, or alternatively dcsmith@gmail.com.

