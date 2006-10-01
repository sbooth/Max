package MusicBrainz::TRM;

use 5.006001;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use MusicBrainz::TRM ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	
);

our $VERSION = do { my @r = (q$Revision: 778 $ =~ /\d+/g); $r[0]--;sprintf "%d."."%02d" x $#r, @r }; # must be all one line, for MakeMaker

require XSLoader;
XSLoader::load('MusicBrainz::TRM', $VERSION);

# Preloaded methods go here.

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

MusicBrainz::TRM - MusicBrainz TRM Acoustic Fingerprint API

=head1 SYNOPSIS

  use MusicBrainz::TRM;

  my $trm = MusicBrainz::TRM->new();

  $trm->set_pcm_data_info($samples,$channels,$bits);
  $trm->set_song_length($seconds);

  while( (! $pcmfh->eof() && 
         (! $trm->generate_signature($pcmfh->getline()) );
  my $sig = $trm->finalize_signature();
  my $ascii_sig = $trm->convert_sig_to_ascii($sig) if( $sig);
  print "Signature: '", $ascii_sig, "'\n";


=head1 DESCRIPTION

This module provides access to the musicbrainz client TRM API using a perl-ish
OO interface.

=head2 methods

=over 4


=item new


$trm = MusicBrainz::TRM->new();


Create a new MusicBrainz TRM object.


=item set_proxy

$trm->set_proxy($serverAddr, $serverPort);

Set the name of the HTTP Proxy to use to access the Internet.

=item set_pcm_data_info

$trm->set_pcm_data_info($samplesPerSecond, $numChannels, $bitsPerSample);

Called to set the type of audio being sent to be signatured.
This MUST be called before attempting to generate a signature.

=item set_song_length

$trm->set_song_length($seconds);

Called to set the total length of the song in seconds.  Optional, but if this
method is not used, generate_signature() will calculate the length of
the audio instead.  Must be called after set_pcm_data_info() but before
any calls to generate_signature().

=item generate_signature

$enough = $trm->generate_signature($pcm_data);

The main functionality of the TRM class.  Audio is passed to this method
and stored for analysis. set_pcm_data_info() needs to be called before
calling this method.  finalize_signature() needs to be called after
this method when generate_signature()  has returned a '1' or there is 
no more audio data to be passed in.

=item finalize_signature


$signature = $trm->finalize_signature();

$signature = $trm->finalize_signature($collectionId);


Used when there is no more audio data available or generate_signature() 
has returned a '1'.  This method finishes the  generation of a 
signature from the data already sent via generate_signature().

This method will access the Relatable signature server to generate 
the signature itself. Windows only: You will need to call $mb->WSAInit() before 
you can use this function. If your program already uses sockets, you will 
not need to call $mb->WSAInit and $mb->WSAStop from MusicBrainz::Client.
The $collectionID is an optional 16-byte string to associate the signature
with a particular collection in the Relatable Engine.  Generally this is
not needed.

The method will return undef on failure to generate the signature.

=item convert_sig_to_ascii

$ascii_sig = $trm->convert-sig_to_ascii($trm, $signature);

This translates the 16 character raw signature into a 36 character 
human-readable string containing only letters and numbers.  Used after 
generate_signature().

=back

For more information see http://www.musicbrainz.org/client_howto.html

=head2 EXPORT

None by default.



=head1 SEE ALSO

MusicBrainz::Client

MusicBrainz::Queries

http://www.musicbrainz.org/client_howto.html

=head1 AUTHOR

Sander van Zoest, E<lt>svanzoest@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2003 by Alexander van Zoest

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
