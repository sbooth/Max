BEGIN { $| =1;  print "1..1\n"; }
END { print "not ok 1\n" unless $loaded; }
#
# $Id: getartist.t 636 2003-04-16 11:02:44Z sander $
#
use strict;
use MusicBrainz::Client qw(MB_CDINDEX_ID_LEN);
use MusicBrainz::Queries qw(MBQ_GetArtistById
                            MBS_SelectArtist
                            MBE_ArtistGetArtistId
                            MBE_ArtistGetArtistName
                            MBE_ArtistGetArtistSortName);

use constant ARTIST_ID => "dd4ff740-2a73-444d-8b55-d16fde79f429";

use constant MB_SERVER => "mm.musicbrainz.org";
use constant MB_PORT   => 80;
use constant MB_DEBUG  =>  0;
use constant MB_DEPTH  =>  2;

my $mb = new MusicBrainz::Client();

if( $^O eq "MSWin32" )
{
    $mb->WSAInit();
}

# Tell the client library to return data in ISO8859-1 and not UTF-8
$mb->use_utf8(0);
# Tell the server to return 10 items.
$mb->set_max_items(10);
# Set the proper server to use. Defaults to mm.musicbrainz.org:80
$mb->set_server(MB_SERVER, MB_PORT);
# Check to see if the debug env var has been set
$mb->set_debug(MB_DEBUG);
# Tell the server to only return 2 levels of data, unless the MB_DEPTH var
# is set
$mb->set_depth(MB_DEPTH);

# Execute the MB_GetArtistById query
my $ret = $mb->query_with_args(MBQ_GetArtistById, [ ARTIST_ID ]);
unless( $ret) {
   print "Query failed: ", $mb->get_query_error(), "\n";
   exit(0);
}

# Select the first artist
$mb->select1( MBS_SelectArtist, 1 );

my $data;
# Pull back the artist id to see if we got the artist
unless( $data = $mb->get_result_data( MBE_ArtistGetArtistId ) ) {
  print "Artist not found.\n";
  exit(0);
}
my $temp = $mb->get_id_from_url($data) if ($data);
print "  ArtistId: ", $temp || "", "\n";

# Extract the artist name
if( $data = $mb->get_result_data( MBE_ArtistGetArtistName ) ) {
  print "  Name: ", $data, "\n";
}

# Extract the sort name
if( $data = $mb->get_result_data( MBE_ArtistGetArtistSortName ) ) {
  print " SortName: ", $data, "\n";
}

if( $^O eq "MSWin32" )
{
    $mb->WSAStop();
}

our $loaded = 1;
print "ok 1\n";
