# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl 1.t'

# $Id: 1.t 597 2003-02-25 02:11:51Z sander $
#########################

# change 'tests => 2' to 'tests => last_test_to_print';

use Test::More tests => 2;
use strict;
BEGIN { use_ok('MusicBrainz::Client', qw@:all@) };


my $fail = 0;
foreach my $constname (qw(
	MB_CDINDEX_ID_LEN MB_ID_LEN)) {
  next if (eval "my \$a = $constname; 1");
  if ($@ =~ /^Your vendor has not defined MusicBrainz::Client macro $constname/) {
    print "# pass: $@";
  } else {
    print "# fail: $@";
    $fail = 1;
  }

}

ok( $fail == 0 , 'Constants' );
#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

