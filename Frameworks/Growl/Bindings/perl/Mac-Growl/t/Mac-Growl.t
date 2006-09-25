# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Mac-Growl.t'

use warnings;
use strict;

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 11;
BEGIN { use_ok('Mac::Growl') };

use Mac::Growl ':all';

#########################

my $encode = eval { require Encode; };
my $app    = 'Mac::Growl Test';
my $as_app = 'GrowlHelperApp.app';
my @names  = ('test 1', 'test 2');
my($image) = grep { -e } (
	'/Applications/Utilities/Installer.app/Contents/Resources/Caut.tiff',
	'/Applications/Utilities/Installer.app/Contents/Plugins/TargetSelect.bundle/Contents/Resources/Caut.tiff'
);

my %pkgs = map { $_ => 0 } qw(
	Foundation
	Mac::Glue
	Mac::OSA::Simple
	MacPerl
	Mac::AppleScript
);

for my $pkg (keys %pkgs) {
	eval "require $pkg";
	$pkgs{$pkg} = $@ ? 0 : 1;
}
$pkgs{osascript} = 1;


RegisterNotifications($app, \@names, [$names[0]], $as_app);
pass("register $app");
PostNotification($app, $names[0], 'Congratulations', 'Mac::Growl is working.');
pass("notify");
PostNotification($app, $names[0], 'If things are working...', 'This should "stick."', 1, 1);
pass("notify sticky");
PostNotification($app, $names[1], 'DON\'T PANIC.', 'You should not see this notification; please notify the Mac::Growl maintainers.', 1, 2);
pass("notify fail");

my $old = $Mac::Growl::base;
for my $pkg (sort keys %pkgs) {
	SKIP: {
		skip("Notify $pkg test", 1), next unless $pkgs{$pkg};
		$Mac::Growl::base = $pkg;
		Mac::Growl::_Define_Subs();

		if ($pkg eq 'Mac::Glue') {
			eval { $Mac::Growl::glue ||= Mac::Glue->new($Mac::Growl::helper) };
			next if $@;
		}

		my($title, $desc) = ("T\xE9st\xEE\xF1g $pkg", "Y\xE0y, $pkg w\xF6rks!");
		if ($encode) {
			Encode::from_to($_, 'iso-8859-1', 'utf8') for ($title, $desc);
		}

		Mac::Growl::PostNotification(
			$app, $names[0], $title, $desc, 0, -1, $image
		);
		pass("notify $pkg");
	}
}

$Mac::Growl::base = $old;
Mac::Growl::_Define_Subs();

__END__
