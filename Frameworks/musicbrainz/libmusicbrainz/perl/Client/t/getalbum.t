BEGIN { $| =1;  print "1..1\n"; }
END { print "not ok 1\n" unless $loaded; }
#
# $Id: getalbum.t 636 2003-04-16 11:02:44Z sander $
#
use strict;
use MusicBrainz::Client qw(MB_CDINDEX_ID_LEN);
use MusicBrainz::Queries qw(MBQ_GetAlbumById
                            MBQ_GetCDInfoFromCDIndexId
                            MBS_SelectAlbum
                            MBE_AlbumGetAlbumId
                            MBE_AlbumGetAlbumName
                            MBE_AlbumGetNumTracks
                            MBE_AlbumGetArtistId
                            MBE_AlbumGetArtistName
                            MBE_AlbumGetTrackName
                            MBE_AlbumGetTrackId
                            MBE_AlbumGetTrackList);

use constant ID => "dd4ff740-2a73-444d-8b55-d16fde79f429";

use constant MB_SERVER => "mm.musicbrainz.org";
use constant MB_PORT   => 80;
use constant MB_DEBUG  =>  0;
use constant MB_DEPTH  =>  4;

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

# Execute the MB_GetALbumById or a GetCDInfoFromCDIndexId query
my $ret;
if( length(ID) != MB_CDINDEX_ID_LEN ) {
  $ret = $mb->query_with_args( MBQ_GetAlbumById, [ ID ]);
} else {
  $ret = $mb->query_with_args( MBQ_GetCDInfoFromCDIndexId, [ ID ]);
}

if( !$ret) {
   print "Query failed: ", $mb->get_query_error(), "\n";
   exit(0);
}

# Select the first album
$mb->select1(MBS_SelectAlbum, 1);

my $data;
# Pull back the album id to see if we got the album
unless( $data = $mb->get_result_data( MBE_AlbumGetAlbumId ) ) {
  print "Album not found.\n";
  exit(0);
}
print "  AlbumId: ", $mb->get_id_from_url( $data ) || "", "\n";

# Extract the album name
if( $data = $mb->get_result_data( MBE_AlbumGetAlbumName ) ) {
  print "  Name: ", $data, "\n";
}

# Extract the number of tracks
my $num_tracks = $mb->get_result_int( MBE_AlbumGetNumTracks );
if( $num_tracks > 0 && $num_tracks < 100 ) {
  print "  NumTracks: ", $num_tracks, "\n";
}

# Check to see if there is more than one artist for this album
my $is_multiple_artist = 0;
for(my $i = 1; $i <= $num_tracks; $i++) {
  unless( $data = $mb->get_result_data1( MBE_AlbumGetArtistId, $i ) ) {
    next;
  }
  my $temp = $data  if( $i == 1 );
  if( $temp eq $data ) {
    $is_multiple_artist = 1;
    last;
  }
}
unless( $is_multiple_artist ) {
  # Extract the artist name from the album
  if( $data = $mb->get_result_data1( MBE_AlbumGetArtistName, 1 ) ){
    print "AlbumArtist: ", $data, "\n";
  }
  if( $data = $mb->get_result_data1( MBE_AlbumGetArtistId, 1 ) ) {
    print "AlbumId    : ", $data, "\n";
  }
}
print "\n";

for( my $i = 1; $i <= $num_tracks; $i++ ) {
  # Extract the track name from the album.
  if( $data = $mb->get_result_data1( MBE_AlbumGetTrackName, $i ) ) {
    print "Track: ", $data, "\n";
  } else { 
    next;
  }
  # Extract the album id from the track. Just use the first album that
  # this track appreas on
  if( $data = $mb->get_result_data1( MBE_AlbumGetTrackId, $i ) ) {
    print "TrackId    : ", $mb->get_id_from_url($data) || "", "\n";
    # Extract the track number
    my $track_num = $mb->get_ordinal_from_list(MBE_AlbumGetTrackList, $data);
    if( $track_num > 0 && $track_num < 100 ) {
      print "TrackNum   : ", $track_num, "\n";
    }
  }
  
  # If its a multiple artist album, print out the artist for each track
  if( $is_multiple_artist ) {
    # Extract the artist name from this track
    if( $data = $mb->get_result_data1( MBE_AlbumGetArtistName, $i ) ) {
      print "TrackArtist   : ", $data, "\n";
    }
    if( $data = $mb->get_result_data1( MBE_AlbumGetArtistId, $i ) ) {
      print "ArtistId   : ", $mb->get_id_from_url($data) || "", "\n";
    }
  }
  print "\n";
}
  
if( $^O eq "MSWin32" )
{
    $mb->WSAStop();
}

our $loaded = 1;
print "ok 1\n";
