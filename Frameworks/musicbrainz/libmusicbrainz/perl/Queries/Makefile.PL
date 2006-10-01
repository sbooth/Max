use 5.6.1;
use strict;
use ExtUtils::MakeMaker;

# $Id: Makefile.PL 8062 2006-07-03 22:39:35Z svanzoest $

sub MY::postamble {

  return <<'EOT';
ck_version :
	@perl -MExtUtils::MakeMaker -le 'print "Version: " . MM->parse_version(shift)' $(VERSION_FROM)

svn_export :
	svn export -rHEAD $(SVN_PACKAGE)/tags/cpan_$(NAME_SYM)_$(VERSION_SYM) $(DISTVNAME)

svn_tag :
	svn copy $(SVN_PACKAGE)/trunk $(SVN_PACKAGE)/tags/cpan_$(NAME_SYM)_$(VERSION_SYM)
	@echo tagged all files with cpan_$(NAME_SYM)_$(VERSION_SYM)

EOT
}



# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'MusicBrainz::Queries',
    'VERSION_FROM'	=> 'Queries.pm', # finds $VERSION
    'PREREQ_PM'		=> {'Test::More' => 0 }, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM => 'Queries.pm', # retrieve abstract from module
       AUTHOR     => 'Sander van Zoest <svanzoest@cpan.org>') : ()),
    'LIBS'		=> [''], # e.g., '-lm'
    'DEFINE'		=> '', # e.g., '-DHAVE_SOMETHING'
    'CCFLAGS'           => '',
    'INC'		=> '-I../../include -I/usr/local/include -I.', # e.g., '-I. -I/usr/include/other'
    'dist'              => {
        COMPRESS        => 'gzip -9f',
        SUFFIX          => 'gz',
        CI              => 'cvs commit'
                           },
     'realclean'        => {
        FILES           => 'const-c.inc const-xs.inc MANIFEST.bak'
                           },
     macro              => {
        SVN_PACKAGE     => 'http://svn.musicbrainz.org/libmusicbrainz',
        SVN_PATH        => '/perl/Queries'
                           },
);
if  (eval {require ExtUtils::Constant; 1}) {
  # If you edit these definitions to change the constants used by this module,
  # you will need to use the generated const-c.inc and const-xs.inc
  # files to replace their "fallback" counterparts before distributing your
  # changes.
  my @names = (qw(MBE_AlbumGetAlbumArtistId MBE_AlbumGetAlbumId
		 MBE_AlbumGetAlbumName MBE_AlbumGetAlbumStatus
		 MBE_AlbumGetAlbumType MBE_AlbumGetAmazonAsin
		 MBE_AlbumGetArtistId
		 MBE_AlbumGetArtistName MBE_AlbumGetArtistSortName
		 MBE_AlbumGetNumCdindexIds MBE_AlbumGetNumReleaseDates
		 MBE_AlbumGetNumTracks MBE_AlbumGetTrackDuration
		 MBE_AlbumGetTrackId MBE_AlbumGetTrackList
		 MBE_AlbumGetTrackName MBE_AlbumGetTrackNum
		 MBE_ArtistGetAlbumId MBE_ArtistGetAlbumName
		 MBE_ArtistGetArtistId MBE_ArtistGetArtistName
		 MBE_ArtistGetArtistSortName MBE_AuthGetChallenge
		 MBE_AuthGetSessionId MBE_GetError MBE_GetNumAlbums
		 MBE_GetNumArtists MBE_GetNumLookupResults MBE_GetNumTracks
		 MBE_GetNumTrmids MBE_GetStatus MBE_LookupGetAlbumArtistId
		 MBE_LookupGetAlbumId MBE_LookupGetArtistId
		 MBE_LookupGetRelevance MBE_LookupGetTrackArtistId
		 MBE_LookupGetTrackId MBE_LookupGetType MBE_QuerySubject
		 MBE_QuickGetAlbumName MBE_QuickGetArtistId
		 MBE_QuickGetArtistName MBE_QuickGetArtistSortName
		 MBE_QuickGetTrackDuration MBE_QuickGetTrackId
		 MBE_QuickGetTrackName MBE_QuickGetTrackNum
		 MBE_ReleaseGetCountry MBE_ReleaseGetDate MBE_TOCGetCDIndexId
		 MBE_TOCGetFirstTrack MBE_TOCGetLastTrack
		 MBE_TOCGetTrackNumSectors MBE_TOCGetTrackSectorOffset
		 MBE_TrackGetArtistId MBE_TrackGetArtistName
		 MBE_TrackGetArtistSortName MBE_TrackGetTrackDuration
		 MBE_TrackGetTrackId MBE_TrackGetTrackName MBE_TrackGetTrackNum
		 MBE_GetRelationshipType MBE_GetRelationshipDirection MBE_GetRelationshipArtistId
  		 MBE_GetRelationshipArtistName MBE_GetRelationshipAlbumId
		 MBE_GetRelationshipAlbumName MBE_GetRelationshipTrackId
		 MBE_GetRelationshipTrackName MBE_GetRelationshipURL
		 MBI_VARIOUS_ARTIST_ID MBQ_AssociateCD MBQ_Authenticate
		 MBQ_FileInfoLookup MBQ_FindAlbumByName MBQ_FindArtistByName
		 MBQ_FindDistinctTRMId MBQ_FindTrackByName MBQ_GetAlbumById
		 MBQ_GetArtistById MBQ_GetCDInfo MBQ_GetCDInfoFromCDIndexId
		 MBQ_GetCDTOC MBQ_GetTrackById MBQ_GetTrackByTRMId
		 MBQ_QuickTrackInfoFromTrackId MBQ_SubmitTrack
		 MBQ_SubmitTrackTRMId MBQ_TrackInfoFromTRMId 
		 MBQ_GetArtistRelationsById MBQ_GetAlbumRelationsById
		 MBQ_GetTrackRelationsById MBS_Back MBS_Rewind 
		 MBS_SelectAlbum MBS_SelectArtist
		 MBS_SelectCdindexid MBS_SelectLookupResult
		 MBS_SelectLookupResultAlbum MBS_SelectLookupResultArtist
		 MBS_SelectLookupResultTrack MBS_SelectReleaseDate
		 MBS_SelectRelationship MBS_SelectTrack 
		 MBS_SelectTrackAlbum MBS_SelectTrackArtist MBS_SelectTrmid
		 MBS_SelectAlbumArtist MBE_AlbumGetCdindexId
		 MBE_AlbumGetAlbumArtistName MBE_AlbumGetAlbumArtistSortName
		 MBE_GetRelationshipAttribute
		 ));
  ExtUtils::Constant::WriteConstants(
                                     NAME         => 'MusicBrainz::Queries',
                                     NAMES        => \@names,
                                     DEFAULT_TYPE => 'PV',
                                     C_FILE       => 'const-c.inc',
                                     XS_FILE      => 'const-xs.inc',
                                  );

}
else {
  use File::Copy;
  use File::Spec;
  foreach my $file ('const-c.inc', 'const-xs.inc') {
    my $fallback = File::Spec->catfile('fallback', $file);
    copy ($fallback, $file) or die "Can't copy $fallback to $file: $!";
  }
}
