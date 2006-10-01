#!/usr/bin/env python

import sys, os
import musicbrainz
import webbrowser

#so query names are shorter
q = musicbrainz

def main():
    mb = musicbrainz.mb()
    mb.SetDepth(2)

    while 1:
        print "Insert CD and hit enter..."
        choice = sys.stdin.readline().strip()
        
        try:
            mb.Query(q.MBQ_GetCDTOC)
        except musicbrainz.MusicBrainzError, e:
            print "The following error occurred: %s" % e
            print "Please make sure there is a CD in your CD drive."
            continue

        cdid = mb.GetResultData(q.MBE_TOCGetCDIndexId)
        
        print "querying musicbrainz.org to see if this cd is on there..."
        mb.QueryWithArgs(q.MBQ_GetCDInfoFromCDIndexId, [cdid])
        
        if mb.GetResultInt(q.MBE_GetNumAlbums) == 1:
            print "Yes and here's the info:"
            mb.Select1(q.MBS_SelectAlbum, 1)
            album = mb.GetResultData(q.MBE_AlbumGetAlbumName)
            artist = mb.GetResultData1(q.MBE_AlbumGetArtistName, 1)
            print "\t%s / %s" % (artist, album)
            for ii in range(1, mb.GetResultInt(q.MBE_AlbumGetNumTracks) + 1):
                name = mb.GetResultData1(q.MBE_AlbumGetTrackName, ii)
                dura = mb.GetResultInt1(q.MBE_AlbumGetTrackDuration, ii)
                track = mb.GetResultInt1(q.MBE_AlbumGetTrackNum, ii)
                dura = "%d:%02d" % divmod(int(dura / 1000), 60)
                
                print "\t%02d - %s (%s)" % (track, name, dura) 
            print "Ejecting cd..."
            os.system('eject')
            continue
        
        url = mb.GetWebSubmitURL()
        if url:
            print "opening web browser to '%s'..." % url
            webbrowser.open_new(url)
        else:
            print "Couldn't get cdid... maybe there's no cd in drive?"
            

#
# Main program starts here
#
if __name__ == "__main__":
    main()
    
