#!/usr/bin/perl

# http://www.xchat.org/docs/xchat2-perl.html
# This script is to be used with the X11 version of XChat. X-Chat Aqua now has native support for Growl.
package Xchat::Mac::Growl;

use strict;
BEGIN { # Foundation clashes with perl lib in X-Chat ...
	$Mac::Growl::base = 'Mac::Glue';
}

use Mac::Growl 0.62;
use Mac::Growl ':all';
use File::Spec::Functions qw(catfile tmpdir);
use File::Temp qw(tmpnam);
use Encode;

Xchat::register('growl', '1.1');
Xchat::print("Loading Growl interface ...\n");

my($appname, $notification) = ('X-Chat Aqua', 'notify');
RegisterNotifications($appname, [$notification], [$notification], $appname);
Xchat::hook_server('PRIVMSG', \&privmsg);
Xchat::hook_print('Channel Msg Hilight', \&hilight);

PostNotification(
	$appname, $notification,
	"$appname plugin loaded",
	"Growl interface loaded for perl $] and $Mac::Growl::base."
);

sub privmsg {
	$_ = Encode::decode('utf8', $_, Encode::FB_PERLQQ);
	my($msgs, $words) = @_;

	return if $msgs->[2] =~ /^[#@]/;

	my($user) = $msgs->[0] =~ /^:(.+)!/;
	(my $msg = $words->[3]) =~ s/^://;

	notify("Privmsg from $user", $msg, 0, 2);

	return Xchat::EAT_NONE;
}

sub hilight {
	$_ = Encode::decode('utf8', $_, Encode::FB_PERLQQ);
	my($msgs) = @_;

	notify("Msg from $msgs->[0]", $msgs->[1], 0, -2);

	return Xchat::EAT_NONE;
}

sub notify {
	my($title, $description, $sticky, $priority) = @_;
	PostNotification($appname, $notification, $title, $description, $sticky, $priority);
}

1;
