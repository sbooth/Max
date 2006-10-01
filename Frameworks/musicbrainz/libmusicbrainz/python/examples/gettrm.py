#!/usr/bin/env python

import sys
import musicbrainz

#so query names are shorter
q = musicbrainz

def main():
    mb = musicbrainz.mb()
    mb.SetDepth(6)

    mb.QueryWithArgs(q.MBQ_GetTrackByTRMId, [sys.argv[1]])

    print mb.GetResultRDF().encode('latin-1')
    
    # Check to see how many items were returned from the server
    numTracks = mb.GetResultInt(q.MBE_GetNumTracks)
    if numTracks < 1:
        print "No tracks found."
    
    print "Found %d track(s)." % numTracks

    for ii in range(1, numTracks+1):
        # Start at the top of the query and work our way down
        mb.Select(q.MBS_Rewind)  

        # Select the ith artist
        mb.Select1(q.MBS_SelectTrack, ii)  

        # Extract the artist name from the ith track
        print "    Artist: %r" % mb.GetResultData(q.MBE_TrackGetArtistName)

        # Extract the track name from the ith track
        print "     Title: %r" % mb.GetResultData(q.MBE_TrackGetTrackName)

        # Extract the track name from the ith track
        print "  Duration: %r" % mb.GetResultInt(q.MBE_TrackGetTrackDuration)


        # Extract the artist id from the ith track
        temp = mb.GetResultData(q.MBE_TrackGetArtistId)
        print "  ArtistId: %r" % mb.GetIDFromURL(temp)

        # Extract the number of albums 
        numAlbums = mb.GetResultInt(q.MBE_GetNumAlbums)
        print "Num Albums: %r" % numAlbums

        for jj in range(1, numAlbums+1):
            # Select the jth album in the album list
            mb.Select1(q.MBS_SelectAlbum, jj)  

            # Extract the album name 
            print "     Album: %r" % mb.GetResultData(q.MBE_AlbumGetAlbumName),
            
            temp = mb.GetResultData(q.MBE_AlbumGetAlbumId)
            print " (%s)" % mb.GetIDFromURL(temp),
        
            # How many tracks on this cd
            print "has %s tracks" % mb.GetResultInt(q.MBE_AlbumGetNumTracks)
            
            # Back up one level and go back to the artist level 
            mb.Select(q.MBS_Back)  

            print ""

if __name__ == '__main__':
    main()
