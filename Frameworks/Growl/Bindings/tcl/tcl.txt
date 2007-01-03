About Tcl Support
-----------------
The Tcl binding for Growl is a simple Objective-C extension which provides the Tcl command ``growl``. It supports notification icons and Unicode strings.

Installation
------------
The following commands will install the binding into /Library/Tcl/growl1.0 ::

	cd Bindings/tcl
	sudo make install 

Usage
-----
The following Tcl commands will post a basic Growl notification. Try it out! ::

	package require growl
	growl register appName "list of notification types" iconFilename
	growl post type title desc "optional icon" 

Author
------
Toby Peterson <toby@opendarwin.org>
