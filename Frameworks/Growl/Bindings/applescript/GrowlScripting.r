#include <Carbon/Carbon.r>

#define Reserved8   reserved, reserved, reserved, reserved, reserved, reserved, reserved, reserved
#define Reserved12  Reserved8, reserved, reserved, reserved, reserved
#define Reserved13  Reserved12, reserved
#define dp_none__   noParams, "", directParamOptional, singleItem, notEnumerated, Reserved13
#define reply_none__   noReply, "", replyOptional, singleItem, notEnumerated, Reserved13
#define synonym_verb__ reply_none__, dp_none__, { }
#define plural__    "", {"", kAESpecialClassProperties, cType, "", reserved, singleItem, notEnumerated, readOnly, Reserved8, noApostrophe, notFeminine, notMasculine, plural}, {}

resource 'aete' (0, "Growl Terminology") {
	0x1,  // major version
	0x0,  // minor version
	english,
	roman,
	{
		"Growl Suite",
		"AppleScript for the Growl Notification System",
		'Grwl',
		1,
		1,
		{
			/* Events */

			"notify",
			"Post a notification to be displayed via Growl",
			'noti', 'fygr',
			reply_none__,
			dp_none__,
			{
				"with name", 'name', 'TEXT',
				"name of the notification to display",
				required,
				singleItem, notEnumerated, Reserved13,
				"title", 'titl', 'TEXT',
				"title of the notification to display",
				required,
				singleItem, notEnumerated, Reserved13,
				"description", 'desc', 'TEXT',
				"full text of the notification to display",
				required,
				singleItem, notEnumerated, Reserved13,
				"application name", 'appl', 'TEXT',
				"name of the application posting the notification.",
				required,
				singleItem, notEnumerated, Reserved13,
				"image from location", 'iurl', 'insl',
				"Location of the image file to use for this notification. Accepts aliases, paths and file:/// URLs.",
				optional,
				singleItem, notEnumerated, Reserved13,
				"icon of file", 'ifil', 'insl',
				"Location of the file whose icon should be used as the image for this notification. Accepts aliases, paths and file:/// URLs. e.g. 'file:///Applications'.",
				optional,
				singleItem, notEnumerated, Reserved13,
				"icon of application", 'iapp', 'TEXT',
				"Name of the application whose icon should be used for this notification. For example, 'Mail.app'.",
				optional,
				singleItem, notEnumerated, Reserved13,
				"image", 'imag', 'TIFF',
				"TIFF Image to be used for the notification.",
				optional,
				singleItem, notEnumerated, Reserved13,
				"pictImage", 'pict', 'PICT',
				"PICT Image to be used for the notification.",
				optional,
				singleItem, notEnumerated, Reserved13,
				"sticky", 'stck', 'bool',
				"whether or not the notification displayed should time out. Defaults to 'no'.",
				optional,
				singleItem, notEnumerated, Reserved13,
				"priority", 'prio', 'long',
				"The priority of the notification, from -2 (low) to 0 (normal) to 2 (emergency).",
				optional,
				singleItem, notEnumerated, Reserved13
			},

			"register",
			"Register an application with Growl",
			'regi', 'ster',
			reply_none__,
			dp_none__,
			{
				"as application", 'appl', 'TEXT',
				"name of the application as which to register.",
				required,
				singleItem, notEnumerated, Reserved13,
				"all notifications", 'anot', 'TEXT',
				"list of all notifications to register.",
				required,
				listOfItems, notEnumerated, Reserved13,
				"default notifications", 'dnot', 'TEXT',
				"list of default notifications to register.",
				required,
				listOfItems, notEnumerated, Reserved13,
				"icon of application", 'iapp', 'TEXT',
				"Name of the application whose icon should be used for this notification. For example, 'Mail.app'.",
				optional,
				singleItem, notEnumerated, Reserved13
			}
		},
		{
			/* Classes */

			"Picture", 'PICT',
			"",
			{
			},
			{
			},
			"Pictures", 'PICT', plural__,

			"Image", 'TIFF',
			"",
			{
			},
			{
			},
			"Images", 'TIFF', plural__
		},
		{
			/* Comparisons */
		},
		{
			/* Enumerations */
		}
	}
};
