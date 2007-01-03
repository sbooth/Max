package Mac::Growl;

use strict;
use warnings;

our $VERSION = '0.64';

use base 'Exporter';
our @EXPORT = qw();
our @EXPORT_OK = qw(RegisterNotifications PostNotification);
our %EXPORT_TAGS = (all => \@EXPORT_OK);

#### we have various options here ...
#### in declining order of preference, we pick an implementation to use,
#### and stick with it.
our($base, $glue, $helper, $appkit, $encode);

# we could use gotos or something, but this is the most efficient and reliable
# way; we could also try to put all the implementations in one function, but
# that's just messy, and I'd rather have it be messy here than there. -- pudge
sub _Define_Subs {
	no warnings 'redefine';

	sub RegisterNotifications($$$;$);
	sub PostNotification($$$$;$$$);

	sub Foundation_RegisterNotifications($$$;$);
	sub Foundation_PostNotification($$$$;$$$);

	sub Glue_RegisterNotifications($$$;$);
	sub Glue_PostNotification($$$$;$$$);

	sub AppleScript_RegisterNotifications($$$;$);
	sub AppleScript_PostNotification($$$$;$$$);

	if ($base eq 'Foundation') {
		*RegisterNotifications = *Foundation_RegisterNotifications{CODE};
		*PostNotification      = *Foundation_PostNotification{CODE};
	} elsif ($base eq 'Mac::Glue') {
		*PostNotification      = *Glue_PostNotification{CODE};
		*RegisterNotifications = *Glue_RegisterNotifications{CODE};
	} else { # AppleScript
		*PostNotification      = *AppleScript_PostNotification{CODE};
		*RegisterNotifications = *AppleScript_RegisterNotifications{CODE};
	}

	sub _Fix_Glue_String(\$);
	sub _Fix_AppleScript_String(\$);
	sub _Fix_Encode(\$;$);
}

sub BEGIN {
	$encode = eval { require Encode; };
	$helper = 'GrowlHelperApp';

	if (!$base || $base eq 'Foundation') {
		eval 'require Foundation';
		if (!$@) {
			$base = 'Foundation';

			# load classes for images
			my $path = NSString->stringWithCString_('/System/Library/Frameworks/AppKit.framework');
			$appkit = NSBundle->alloc->init->initWithPath_($path);
			$appkit->load if $appkit;
			if ($appkit->isLoaded) {
				no strict 'refs';
				for my $class (qw(NSWorkspace NSImage)) {
					@{$class . '::ISA'} = 'PerlObjCBridge';
				}
			} else {
				undef $appkit;
			}
		} else {
			$base = undef;
		}
	}

	if (!$base || $base eq 'Mac::Glue') {
		eval 'require Mac::Glue';
		unless ($@) {
			eval { $glue = Mac::Glue->new($helper) };
			$base = $glue ? 'Mac::Glue' : undef;
		}
	}

	for my $applescript (qw(Mac::OSA::Simple MacPerl Mac::AppleScript)) {
		if (!$base || $base eq $applescript) {
			eval "require $applescript";
			$base = $@ ? undef : $applescript;
		}
	}

	if (!$base || $base eq 'osascript') {
		chomp(my $res = `osascript -e1`);
		$base = $res eq 1 ? 'osascript' : undef;
	}

	if (!$base) {
		die "No way to invoke Growl, please see `perldoc Mac::Growl`";
	}

#	warn "Using $base for " . __PACKAGE__, "\n";

	_Define_Subs();
}

#################################
### Foundation implementation ###

use constant GROWL_APP_NAME						=> "ApplicationName";
use constant GROWL_APP_ICON						=> "ApplicationIcon";

use constant GROWL_NOTIFICATIONS_DEFAULT		=> "DefaultNotifications";
use constant GROWL_NOTIFICATIONS_ALL			=> "AllNotifications";
use constant GROWL_NOTIFICATIONS_USER_SET		=> "AllowedUserNotifications";

use constant GROWL_NOTIFICATION_NAME			=> "NotificationName";
use constant GROWL_NOTIFICATION_TITLE			=> "NotificationTitle";
use constant GROWL_NOTIFICATION_DESCRIPTION		=> "NotificationDescription";
use constant GROWL_NOTIFICATION_ICON			=> "NotificationIcon";
use constant GROWL_NOTIFICATION_PRIORITY		=> "NotificationPriority";
use constant GROWL_NOTIFICATION_STICKY			=> "NotificationSticky";

use constant GROWL_APP_REGISTRATION				=> "GrowlApplicationRegistrationNotification";
use constant GROWL_APP_REGISTRATION_CONF		=> "GrowlApplicationRegistrationConfirmationNotification";
use constant GROWL_NOTIFICATION					=> "GrowlNotification";

use constant GROWL_PING							=> "Honey, Mind Taking Out The Trash";
use constant GROWL_PONG							=> "What Do You Want From Me, Woman";
use constant NSNotificationPostToAllSessions	=> 1 << 1;

sub Foundation_RegisterNotifications($$$;$)
{
	my($appName, $allNotes, $defaultNotes, $iconOfApp) = @_;
	_Fix_Encode($_) for ($appName);

	my $appString    = NSString->alloc->initWithCString_($appName);
	my $notesArray   = NSMutableArray->alloc->init;
	my $defaultArray = NSMutableArray->alloc->init;

	$notesArray->addObject_($_)   for @$allNotes;
	$defaultArray->addObject_($_) for @$defaultNotes;

	my $regDict = NSMutableDictionary->alloc->initWithCapacity_(4);
	$regDict->setObject_forKey_($appString,    GROWL_APP_NAME);
	$regDict->setObject_forKey_($notesArray,   GROWL_NOTIFICATIONS_ALL);
	$regDict->setObject_forKey_($defaultArray, GROWL_NOTIFICATIONS_DEFAULT);
	$appString->release;
	$notesArray->release;
	$defaultArray->release;

	if ($appkit && defined $iconOfApp) {
		my $path = NSWorkspace->sharedWorkspace->fullPathForApplication_(
			NSString->stringWithCString_($iconOfApp)
		);
		if ($path) {
			my $icon = NSWorkspace->sharedWorkspace->iconForFile_($path);
			if ($icon && $icon->isValid) {
				$regDict->setObject_forKey_($icon->TIFFRepresentation, GROWL_APP_ICON);
			}
		}
	}

	NSDistributedNotificationCenter->defaultCenter->postNotificationName_object_userInfo_options_(
		GROWL_APP_REGISTRATION,
		undef,
		$regDict,
		NSNotificationPostToAllSessions
	);
	$regDict->release;
}

sub Foundation_PostNotification($$$$;$$$)
{
	my($appName, $noteName, $noteTitle, $noteDescription, $sticky, $priority, $image) = @_;
	_Fix_Encode($_) for ($appName, $noteName, $noteTitle, $noteDescription);
	$sticky = $sticky ? 1 : 0;

	my $noteDict = NSMutableDictionary->alloc->initWithCapacity_(7);
	my $title = NSString->alloc->initWithUTF8String_($noteTitle);
	my $description = NSString->alloc->initWithUTF8String_($noteDescription);
	$noteDict->setObject_forKey_($noteName,     GROWL_NOTIFICATION_NAME);
	$noteDict->setObject_forKey_($appName,      GROWL_APP_NAME);
	$noteDict->setObject_forKey_($title,        GROWL_NOTIFICATION_TITLE);
	$noteDict->setObject_forKey_($description,  GROWL_NOTIFICATION_DESCRIPTION);
	$title->release;
	$description->release;
	if (defined $sticky) {
		my $noteSticky = NSNumber->alloc->initWithBool_($sticky);
		$noteDict->setObject_forKey_($noteSticky,   GROWL_NOTIFICATION_STICKY);
		$noteSticky->release;
	}
	if (defined $priority) {
		my $notePriority = NSNumber->alloc->initWithInt_($priority);
		$noteDict->setObject_forKey_($notePriority, GROWL_NOTIFICATION_PRIORITY);
		$notePriority->release;
	}

	if ($appkit && defined $image && -e $image) {
		my $path = NSString->alloc->initWithCString_($image);
		if ($path) {
			my $icon = NSImage->alloc->initWithContentsOfFile_($path);
			if ($icon) {
			   	if ($icon->isValid) {
					$noteDict->setObject_forKey_($icon->TIFFRepresentation, GROWL_NOTIFICATION_ICON);
				}
				$icon->release;
			}
			$path->release;
		}
	}

	NSDistributedNotificationCenter->defaultCenter->postNotificationName_object_userInfo_options_(
		GROWL_NOTIFICATION,
		undef,
		$noteDict,
		NSNotificationPostToAllSessions
	);
	$noteDict->release;
}


################################
### Mac::Glue implementation ###

sub Glue_RegisterNotifications($$$;$)
{
	my($appName, $allNotes, $defaultNotes, $iconOfApp) = @_;
	for ($appName) {
		_Fix_Encode($_);
		_Fix_Glue_String($_);
    }

	for my $notes ($allNotes, $defaultNotes) {
		$notes = [ map {
			Mac::Glue::param_type(Mac::AppleEvents::typeChar(), $_)
		} @$notes ];
	}

	$glue->register(
		as_application			=> $appName,
		all_notifications		=> $allNotes,
		default_notifications	=> $defaultNotes,
		icon_of_application		=> $iconOfApp,
	);
}

sub Glue_PostNotification($$$$;$$$)
{
	my($appName, $noteName, $noteTitle, $noteDescription, $sticky, $priority, $image) = @_;
	for ($appName, $noteName, $noteTitle, $noteDescription) {
		_Fix_Encode($_);
		_Fix_Glue_String($_);
    }
	$sticky = $sticky ? 1 : 0;

	my %params = (
		application_name	=> $appName,
		with_name			=> $noteName,
		title				=> $noteTitle,
		description			=> $noteDescription,
		sticky				=> $sticky
	);

	$params{priority} = $priority if defined $priority;

	my $image_url = _Fix_Image_Path($image);
	$params{image_from_location} = Mac::Glue::param_type(
		Mac::Glue::typeChar(), $image_url
	) if $image_url;

	$glue->notify(%params);
}

# make sure the strings are converted to Unicode, just in case
sub _Fix_Glue_String(\$)
{
	my($string) = @_;
	$$string = Mac::Glue::param_type(Mac::Glue::typeUnicodeText(), $$string);
}

##################################
### AppleScript implementation ###

sub AppleScript_RegisterNotifications($$$;$)
{
	my($appName, $allNotes, $defaultNotes, $iconOfApp) = @_;
	_Fix_Encode($_, 'MacRoman') for ($appName);

	# protect quotes and slashes
	for ($appName, $iconOfApp) {
		next unless defined;
		_Fix_AppleScript_String($_);
	}

	for my $list ($allNotes, $defaultNotes) {
		_Fix_AppleScript_String($_) for @$list;
		my $string = join('","', @$list);
		$list = $string;
	}

	my $script = qq'tell application "$helper" to register ' .
		qq'as application "$appName" ' .
		qq'all notifications ["$allNotes"] default notifications ["$defaultNotes"]';
	$script .= qq' icon of application "$iconOfApp"' if $iconOfApp;

	_Execute_AppleScript($script);
}

sub AppleScript_PostNotification($$$$;$$$)
{
	my($appName, $noteName, $noteTitle, $noteDescription, $sticky, $priority, $image) = @_;
	$sticky = $sticky ? 1 : 0;

	# protect quotes and slashes
	for ($appName, $noteName, $noteTitle, $noteDescription) {
		next unless defined;
		_Fix_AppleScript_String($_);
		_Fix_Encode($_, 'MacRoman');  # can't get to work with UTF8, so this will do
	}

	my $script = qq'tell application "$helper" to notify ' .
		qq'application name "$appName" with name "$noteName" ' .
		qq'title "$noteTitle" description "$noteDescription"';
	$script .= ' sticky true' if $sticky;

	if (defined $priority) {
		$priority =~ s/^.*?(-?\d+).*$/$1/g;
		$script .= " priority $priority" if $priority;
	}

	my $image_url = _Fix_Image_Path($image);
	$script .= qq' image from location "$image_url"' if $image_url;

	_Execute_AppleScript($script);
}

sub _Fix_AppleScript_String(\$)
{
	my($string) = @_;
	$$string =~ s/\\/\\\\/g;
	$$string =~ s/"/\\"/g;
}

sub _Execute_AppleScript
{
	my($script, $return) = @_;
	my $reply;
	# warn $script, "\n";

	if ($base eq 'Mac::OSA::Simple')
	{
		$reply = Mac::OSA::Simple::applescript($script);
	}

	elsif ($base eq 'MacPerl')
	{
		$reply = MacPerl::DoAppleScript($script);
	}

	elsif ($base eq 'Mac::AppleScript')
	{
		$reply = Mac::AppleScript::RunAppleScript($script);
	}

	else # ($base eq 'osascript')
	{
		if ($return) {
			$script =~ s/\\/\\\\/g;
			$script =~ s/'/'\''/g;
			chomp($reply = `osascript -ss -e '$script' 2>/dev/null`);
		} else {
			system('osascript', '-e', $script);
		}
	}

	if ($return) {
		$reply =~ s/^"(.+)"$/$1/;
		return $reply;
	}
}


#######################
### Misc. Functions ###

{
my $uri_file;

sub _Fix_Image_Path
{
	require File::Spec;
	unless (defined $uri_file) {
		eval 'require URI::file';
		$uri_file = $@ ? 0 : 1;
	}

	my($image) = @_;
	my $path;

	if (defined $image && length $image) {
		$path = File::Spec->rel2abs($image);
		if (-e $path) {
			my $reply;
			if ($uri_file) {
				my $uri = URI::file->new($path);
				$reply = $uri->as_string if $uri;
			} else {
				# URI::file will be available if Mac::Glue
				# is, so this only needs to be implemented
				# in AppleScript; yes, it's a hack, but
				# it's better to work out of the box than
				# to not
				my $script = <<EOT;
tell application "Finder"
   set thisfile to POSIX file "$path" as string
   set thisdoc to document file thisfile
   return URL of thisdoc
end tell
EOT
				$reply = _Execute_AppleScript($script, 1);
			}
			if ($reply) {
				# Growl being excessively anal
				$reply =~ s#^file:/(/localhost/)?(?!/)#file:///#;
				return $reply;
			}
		}
	}

	return;
}
}

sub _Fix_Encode (\$;$)
{
	my($str, $encoding) = @_;
	$$str = Encode::decode('utf8', $$str) if $encode;
	$$str = Encode::encode($encoding, $$str) if $encode && $encoding;
}

1;

__END__

=head1 NAME

Mac::Growl - Perl module for registering and sending Growl Notifications on Mac OS X

=head1 SYNOPSIS

  use Mac::Growl ':all';

  RegisterNotifications("MyPerlApp", \@allNotifications,
    \@defaultNotifications[, $iconOfApp]);

  PostNotification("MyPerlApp", $notificationName, $notificationTitle,
    $notificationDescription[, $sticky, $priority, $image_path]);

=head1 DESCRIPTION

Mac::Growl provides a simple notification for perl apps to register
themselves with and send notifications to the Mac OS X notification
application Growl.

Mac::Growl defines two methods:

=over 4

=item RegisterNotifications(appname, allNotifications, defaultNotifications[, iconOfApp]);

RegisterNotifications takes the name of the application sending
notifications, as well as a reference to a list of all notifications the
app sends out, and a reference to an array of all the notifications to
be enabled by default.  Also, optionally accepts the name of an
application whose icon to use by default.

=item PostNotification(appname, name, title, description[, sticky, priority, image_path]);

PostNotification takes the name of the sending application (normally the
same as passed to the Register call), the name of the notification
(should be one of the allNotification list passed to Register), and a
title and description to be displayed by Growl. Also, optionally accepts
a "sticky" flag, which, if true, will cause the notification to remain
until dismissed, instead of timing out normally; a "priority" value
(range from -2 for low to 2 for high); and an image path, a path to a
file containing the image for the notification.

=back

For more information, see
L<http://growl.info/documentation/applescript-support.php>, which
details how this all fits together.  It is specific to AppleScript, but
the concepts apply to this module as well, except that file paths for
images are Unix paths, not URLs.

=head2 Unicode

Mac::Growl expects strings to be passed as UTF-8, if they have high-bit
characters.  You must take responsibility to encode the characters
properly yourself.  This can usually be accomplished with L<utf8>
or L<Encode>, such as:

	use utf8;
	utf8::encode($string);

or:

	require Encode;
	$string = Encode::encode('utf8', $string);

If you have a string that is not in some representation other than
"Perl's internal representation" -- for example, maybe you have been
passed a MacRoman string from another source -- you can use Encode:

	require Encode;
	Encode::from_to($string, 'MacRoman', 'utf8');



=head1 CAVEATS

=head2 Architecture

This module is designed to use L<Foundation>, a perl module included
with Mac OS X that is probably only available if you are using the
default system perl.  If Foundation is not available (such as if you
built your own version of perl), this module will attempt to talk to
Growl using Apple events instead of the Cocoa API.

It tries various perl modules to accomplish this, in descending order of
preference: L<Mac::Glue>, L<Mac::OSA::Simple>, L<MacPerl> (which defines
C<DoAppleScript>), and L<Mac::AppleScript>.  As a last resort, it will
use C<osascript(1)>, a command line program that should be available on
all Mac OS X machines.

The methods should all function the same way, except that the various
AppleScript methods (all except for Foundation and Mac::Glue) convert
text to MacRoman instead of passing in UTF-8, and the Foundation method
will send notifications to all logged-in users instead of just the
current user.


=head2 Advanced Architecture Selection

You can specify which architecture is used, by defining $Mac::Growl::base before
loading the module, e.g.:

	BEGIN { $Mac::Growl::base = 'Mac::Glue' }
	use Mac::Growl;

Possible values for this var are, as described above: Foundation, Mac::Glue,
Mac::OSA::Simple, MacPerl, Mac::AppleScript, and osascript.  B<Note>: You
normally do not want to do this.  The default is sensible in almost all
cases.  The only case I've found where I need to use this is in X-Chat,
where X-Chat dies when Foundation is loaded.


=head1 EXPORT

None by default.


=head1 SEE ALSO

http://growl.info

#growl on irc.freenode.net


=head1 AUTHORS

Nelson Elhage E<lt>nelhage@gmail.comE<gt>,
Chris Nandor E<lt>projects@pudge.netE<gt>


=head1 COPYRIGHT AND LICENSE

Copyright (C) 2004-2005 The Growl Project.  All rights reserved.


Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are
met:


1) Redistributions of source code must retain the above copyright
notice, this list of conditions and the following disclaimer.

2) Redistributions in binary form must reproduce the above copyright
notice, this list of conditions and the following disclaimer in the
documentation and/or other materials provided with the distribution.


THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER
OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


=cut
