package MusicBrainz::Client;
# --------------------------------------------------------------------------
#
#   MusicBrainz::Client -- The Internet music metadatabase
#
#   Copyright (C) 2003-2006 Alexander van Zoest
#   
#   $Id: Client.pm 8065 2006-07-03 22:49:35Z svanzoest $
#
#----------------------------------------------------------------------------*/

use 5.006_001; 
use strict;
use warnings;
use Carp;

require Exporter;
require DynaLoader;
use AutoLoader;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use MusicBrainz::Client ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(MB_CDINDEX_ID_LEN MB_ID_LEN
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
);

our $VERSION = 0.11;


sub AUTOLOAD {
    # This AUTOLOAD is used to 'autoload' constants from the constant()
    # XS function.

    my $constname;
    our $AUTOLOAD;
    ($constname = $AUTOLOAD) =~ s/.*:://;
    croak "&MusicBrainz::Client::constant not defined" if $constname eq 'constant';
    my ($error, $val) = constant($constname);
    if ($error) { croak $error; }
    {
        no strict 'refs';
        # Fixed between 5.005_53 and 5.005_61
#XXX    if ($] >= 5.00561) {
#XXX        *$AUTOLOAD = sub () { $val };
#XXX    }
#XXX    else {
            *$AUTOLOAD = sub { $val };
#XXX    }
    }
    goto &$AUTOLOAD;
}

require XSLoader;
XSLoader::load('MusicBrainz::Client', $VERSION);

# Preloaded methods go here.

# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__


=head1 NAME

MusicBrainz::Client - MusicBrainz Client API

=head1 SYNOPSIS

  use MusicBrainz::Client;
  use MusicBrainz::Queries qw(:all);

  my $mb = MusicBrainz::Client->new(); 
  if(! $mb->query_with_args( MBQ_FindArtistByName, [ "Pink Floyd" ]) ) {
    die("Query failed: ", $mb->get_query_error(), "\n");
  }
  print "Found ", $mb->get_result_int(MBE_GetNumArtists), " artists\n";

=head1 DESCRIPTION

This module provides access to the musicbrainz client API using a perl-ish
OO interface.

=head2 Methods
  

=over 4


=item new

$mb->new();

Create a new handle to the MusicBrainz object.

=item get_version

($major, $minor, $revision) = $mb->get_version();

Get the version number of the libmusicbrainz library in use.

=item set_server

$success = $mb->set_server($serverAddr, $serverPort);

Set the name and the port of the MusicBrainz server to use.
If this function is not called, the default www.musicbrainz.org server on port 80 will be used.

See also: L<set_proxy>

=item set_debug

$mb->set_debug($debug);

Enable debug out to stdout by sending a non-zero value to this function.


=item set_proxy

$success = $mb->set_proxy($serverAddr, $serverPort);

Set the name of the HTTP Proxy to use.
This function must be called anytime the client library must communicate via a proxy firewall.

See also: L<set_server>


=item authenticate

$success = $mb->authenticate($userName, $password);

This function must be called if you want to submit data to the server 
and give the user credit for the submission. If you're looking up data 
from the server, you do not need to call authenticate. If you are 
submitting data to the MB server and you want your submissions be submitted 
anonymously, then do not call this function.

returns true if the server authentication was correctly initiated.

Note: the password is sent in plaintext.


=item set_device

$success = $mb->set_device($device);

Call this function to set the CD-ROM drive device if you plan to use the 
client library to identify and look up CD-ROMs using MusicBrainz. 
Unix: specify a device such as /dev/cdrom. Defaults to /dev/cdrom 
Windows: specify a drive letter of a CD-ROM drive. e.g. E:

Always returns true.


=item use_utf8

$mb->use_utf8( 1 );

Use this function to set the output returned by the Get function. 
The Get functions can return data in ISO-8859-1 encoding or in UTF-8. 
Defaults to ISO-8859-1.

=item set_depth

$mb->set_depth($depth);
 
Set the search depth of the query. 
Please refer to the "Query Depth" section in the MusicBrainz HOWTO 
(http://www.musicbrainz.org/client_howto.html) for an explanation of this value. 
Defaults to 2.

=item set_max_items

$mb->set_max_items($maxItems);

Set the maximum number of items to return to the client. 
If a search query yields more items than this max number, 
the server will omit the excess items and not return them to the client. 
This value defaults to 25.

See also: L<query>

=item query

$success = $mb->query($rdfObject);

Query the MusicBrainz server. 
Use this function if your query requires no arguments other than the query itself. 
Please refer to the MusicBrainz::Queries module for the documentation 
on the available queries.

Returns true if the query succeeded (even if no items are returned) 
and false if the query failed. 
Call $mb->get_query_error(); for details on the error that occurred.
 
 See also: L<get_query_error> , L<query_with_args>
 

=item query_with_args
 

$sucess = $mb->query_with_args($rdfObject, \@args);

Query the MusicBrainz server. 
Use this function if your query requires one or more arguments. 
The arguments are as an anonymous array.

$rdfObject is one of the exportable constants defined in MusicBrainz::Queries
  
Returns true if the query succeeded (even if no items are returned) 
and false if the query failed. 
Call $mb->get_query_error(); for details on the error that occurred.
  
See also: L<get_query_error> , L<query>
  

=item get_web_submit_url
  

$url = $mb->get_web_submit_url();
  
Use this function to query the current CD-ROM and to calculate the web 
submit URL that can be opened in a browser in order to start the web 
based CD-ROM Submission to MusicBrainz. The CD-ROM in the CD-ROM drive 
set by $mb->set_device(); will be queried.
  
Returns true if the url was successfully generated, false if an error occurred.
  
See also: L<set_device>
  

=item get_query_error
  

$error = $mb->get_query_error();
  
Retrieve the error message that was generated during the last call 
to $mb->query(); or $mb->query_with_args();
  
See also: L<query> , L<query_with_args>
  

=item select
  

$success = $mb->select($selectQuery);
  
Select a context in the result query. Use this function if your Select requires 
no ordinal arguments. Pass this function a select query (starts with MBS_) from MusicBrainz::Queries. 
Please refer to the MusicBrainz HOWTO (http://www.musicbrainz.org/client_howto.html)
for more details on why you need to do a Select and what types of Selects are available. 
  
Returns true if the select succeeded, false otherwise.
  
See also: L<select1> 
  

=item select1
  

$success = $mb->select1($selectQuery, $ord);
  
Select a context in the result query. Use this function if your Select 
requires one ordinal argument. Pass this function a selectQuery 
(usually start with MBS_) from MusicBrainz::Queries.
Please refer to the MusicBrainz HOWTO (http://www.musicbrainz.org/client_howto.html)
for more details on why you need to do a Select and what types of Selects are available. 
  
Returns true if the select succeeded, false otherwise. 
  
See also: L<select>
  

=item get_result_data
  

$data = $mb->get_result_data($resultName);
  
Extract a piece of information from the data returned by a successful query. 
This function takes a resultName (usually named starting with MBE_) from MusicBrainz::Queries.
Please refer to the MusicBrainz HOWTO (http://www.musicbrainz.org/client_howto.html)
  
Returns true if the correct piece of data was returned and found, false otherwise.
  
See also: L<get_result_data1>
  

=item get_result_data1


$data1 = $mb->get_result_data1($resultName, $ordinal);

Extract a piece of information from the data returned by a successful query. 
This function takes a resultName (usually named starting with MBE_) from MusicBrainz::Queries.
See the MusicBrainz HOWTO (http://www.musicbrainz.org/client_howto.html).
$ordinal is the position of the data you wish to retrieve.

Returns true if the correct piece of data was returned and found, false otherwise.

See also: L<get_result_data> 


=item does_result_exist


$success = $mb->does_result_exist($resultName);

Check to see if a piece of information exists in data returned by a successful query. 
This function takes the same resultName argument as L<get_result_data>

Returns true if the result data exists, false otherwise 

See also: L<get_result_data> 
  

=item does_result_exist1


$success $mb->does_result_exist1($resultName, $ordinal);

Check to see if a piece of information exists in data returned by a 
successful query. This function takes the same resultName and ordinal 
arguments as L<get_result_data1>

Returns true if the result data exists, false otherwise 

See also: L<get_result_data1> 


=item get_result_int


$result = $mb->get_result_int($resultName);

Return the integer value of a result from the data returned 
by a successful Query. This function takes the same resultName 
argument as L<get_result_data>

Returns the integer value of the result 

See also: L<get_result_data> 


=item get_result_int1


$result = $mb->get_result_int1($resultName, $ordinal);

Return the integer value of a result from the data returned 
by a successful Query. This function takes the same resultName and ordinal
arguments as L<get_result_data1>

Returns the integer value of the result 

See also: L<get_result_data1>


=item get_result_rdf


$rdfstr = $mb->get_result_rdf();

Retrieve the RDF that was returned by the server. 
Most users will not want to use this function!


=item set_result_rdf


$success = $mb->set_result_rdf($rdfstr);

Set an RDF object for so that the Get functions can be used to 
extract data from the RDF. Advanced users only!

See also: L<get_result_rdf>


=item get_id_from_url


$id = $mb->get_id_from_url($url);

Extract the actual artist/album/track ID from a MBE_GETxxxxxId query. 
The MBE_GETxxxxxId functions return a URL to where the more RDF metadata 
for the given ID can be retrieved. Callers may wish to extract only the 
ID of an artist/album/track for reference elsewhere.

See also: L<get_result_data>


=item get_fragment_from_url


$fragment = $mb->get_fragment_from_url($url);

Extract the identifier fragment from a URI. Given a URI this function will 
return the string that follows the # seperator. 
(e.g. when passed 'http://musicbrainz.org/mm/mq-1.1#ArtistResult', this function
will return 'ArtistResult' 
  

=item get_ordinal_from_list


$ord = $mb->get_ordinal_from_list($listType, $URI);

Get the ordinal (list position) of an item in a list. 
This function is normally used to retrieve the track number out 
of a list of tracks in an album using a list query (usually MBE_AlbumGetTrackList)

See also: MBE_AlbumGetTrackList in MusicBrainz::Queries


=item get_mp3_info


($duration, $bitrate, $stereo, $samplerate) =  $mb->get_mp3_info($filename);

This helper function calculates the crucial pieces of information for a
MP3 files. $duration = duration of the MP3 in milliseconds, which is handy for 
passing the length of the track to the TRM generation routines. Beware: The 
TRM routines are expecting the duratin in SECONDS, so you will need to divide the 
duration returned by this function by 1000 before you pass it to the TRM routines.

=back

=head2 Windows Platform

Since this module makes use of Sockets, be sure to call $mb->WSAInit() and $mb->WSAStop().
  
=head2 Examples

For examples on how to use this API please see the test scripts provided and the
C client library documentation at http://www.musicbrainz.org/client_howto.html

=head2 EXPORT

None by default.

=head2 Exportable constants

  MB_CDINDEX_ID_LEN
  MB_ID_LEN

=head1 SEE ALSO

  MusicBrainz::Queries
  MusicBrainz::TRM
  http://www.musicbrainz.org/client_howto.html
  http://www.musicbrainz.org/
  perl(1) 

=head1 AUTHOR

Sander van Zoest <svanzoest@cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright 2003-2006 by Alexander van Zoest.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
