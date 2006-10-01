# -*- perl -*-

package Bundle::MusicBrainz::Client;

$VERSION = do { my @r = (q$Revision: 608 $ =~ /\d+/g); $r[0]--;sprintf "%d."."%02d" x $#r, @r }; # must be all one line, for MakeMaker

1;

__END__

=head1 NAME

Bundle::MusicBrainz::Client - A bundle to install MusicBrainz::Client and required modules.

=head1 SYNOPSIS

  perl -MCPAN -e 'install Bundle::MusicBrainz::Client'

=head1 CONTENTS

MusicBrainz::Client  - for to get to know thyself

MusicBrainz::Queries 0.05 - The RDF Query Constants

MusicBrainz::TRM 0.01 - The Relatible Audio FingerPrint API

=head1 DESCRIPTION

This bundle includes all the modules used by the Perl Bindings
for the MusicBrainz Client library (MusicBrainz::Client) module, 
created by Sander van Zoest.

A I<Bundle> is a module that simply defines a collection of other
modules.  It is used by the L<CPAN> module to automate the fetching,
building and installing of modules from the CPAN ftp archive sites.

This bundle does not deal with the actual MusicBrainz client library
(libmusicbrainz), that is available from sources other than CPAN. 
You'll need to fetch and build the library yourself.

=head1 AUTHOR

Sander van Zoest

=cut

