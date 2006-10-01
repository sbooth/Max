#!/usr/bin/env python

import sys
import musicbrainz
import difflib

#so query names are shorter
q = musicbrainz

def main(artistName):
    mb = musicbrainz.mb()
    mb.SetServer('musicbrainz.org', 80)
    mb.SetDepth(4)

    ret = mb.QueryWithArgs(q.MBQ_FindArtistByName, artistName)
    if not ret:
        error = mb.GetQueryError()
        print "Query failed: %s" % error

    # Check to see how many items were returned from the server
    numArtists = mb.GetResultInt(q.MBE_GetNumArtists)
    if numArtists < 1:
        print "No artists found."
    
    print "Found %d artists." % numArtists

    for ii in range(1, numArtists+1):
        # Start at the top of the query and work our way down
        mb.Select(q.MBS_Rewind)  

        # Select the ith artist
        mb.Select1(q.MBS_SelectArtist, ii)  

        # Extract the artist name from the ith track
        data = mb.GetResultData(q.MBE_ArtistGetArtistName)
        print "    Artist: %r" % data

        # Extract the artist id from the ith track
        data = mb.GetResultData(q.MBE_ArtistGetArtistId)
        temp = mb.GetIDFromURL(data)
        print "  ArtistId: '%s'" % temp

        # Extract the number of albums 
        numAlbums = mb.GetResultInt(q.MBE_GetNumAlbums)
        print "Num Albums: %d" % numAlbums

        for jj in range(1, numAlbums+1):
            # Select the jth album in the album list
            mb.Select1(q.MBS_SelectAlbum, jj)  

            # Extract the album name 
            data = mb.GetResultData(q.MBE_AlbumGetAlbumName)
            print "     Album: %r" % data,
            
            data = mb.GetResultData(q.MBE_AlbumGetAlbumId)
            temp = mb.GetIDFromURL(data)
            print " (%s)" % temp
        
            # Back up one level and go back to the artist level 
            mb.Select(q.MBS_Back)  

        print ""

    
    
    



if __name__ == '__main__':
    if len(sys.argv) == 1:
        print "findartist.py <artistname>"
        sys.exit(0)
    main(sys.argv[1])
