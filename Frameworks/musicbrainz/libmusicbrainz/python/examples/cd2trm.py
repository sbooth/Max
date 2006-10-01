#!/usr/bin/env python

import sys, os, getopt, ConfigParser, webbrowser, getopt
import musicbrainz

import wave         # should come with python
from time import sleep

#so query names are shorter
q = musicbrainz

# SERVER = 'musicbrainz.eorbit.net'
SERVER = 'musicbrainz.org'

query = """\
<mq:SubmitTRMList>
  <mm:trmidList>
   <rdf:Bag>
   %s
   </rdf:Bag>
  </mm:trmidList>
  <mq:sessionId>@SESSID@</mq:sessionId>
  <mq:sessionKey>@SESSKEY@</mq:sessionKey>
  <mq:clientVersion>cd2trm/0.8.0</mq:clientVersion>
</mq:SubmitTRMList>
"""

queryItem = """\
    <rdf:li>
     <mq:trmTrackPair>
      <mm:trackid>%s</mm:trackid>
      <mm:trmid>%s</mm:trmid>
     </mq:trmTrackPair>
    </rdf:li>
"""

def getCDInfo(mbObj):
    """
    @returns: a list of tuples containing (track id, track length in secs)
    """
    print "Insert CD..."
    while os.system('cdparanoia -Qq 2>/dev/null'):
        sleep(0.5)
    mbObj.SetDepth(1)
    mbObj.Query(q.MBQ_GetCDTOC)

    trackLengths = {}
    first = mbObj.GetResultInt(q.MBE_TOCGetFirstTrack)
    last = mbObj.GetResultInt(q.MBE_TOCGetLastTrack)        

    for ii in xrange(first + 1, last + 2):
        sectors = mbObj.GetResultInt1(q.MBE_TOCGetTrackNumSectors, ii)
        offset = mbObj.GetResultInt1(q.MBE_TOCGetTrackSectorOffset, ii)
        trackLengths[ii-1] = sectors / 75

    cdid = mbObj.GetResultData(q.MBE_TOCGetCDIndexId)
    
    print "querying musicbrainz.org to see if this cd ('%s') is on there..." % cdid
    mbObj.QueryWithArgs(q.MBQ_GetCDInfoFromCDIndexId, [cdid])
    
    ret = []
    if mbObj.GetResultInt(q.MBE_GetNumAlbums) == 1:
        print "Yes and here's the info:"
        mbObj.Select1(q.MBS_SelectAlbum, 1)
        album = mbObj.GetResultData(q.MBE_AlbumGetAlbumName)
        artistId = mbObj.GetIDFromURL(mbObj.GetResultData(q.MBE_AlbumGetAlbumArtistId))
        if artistId == q.MBI_VARIOUS_ARTIST_ID:
            print "\t%s" % album
        else:    
            artist = mbObj.GetResultData1(q.MBE_AlbumGetArtistName, 1)
            print "\t%s / %s" % (artist, album)
        
        for ii in range(1, mbObj.GetResultInt(q.MBE_AlbumGetNumTracks) + 1):
            trackURI = mbObj.GetResultData1(q.MBE_AlbumGetTrackId, ii)
            trackId = mbObj.GetIDFromURL(trackURI)
            ret.append( (trackId, trackLengths[ii],) )
            name = mbObj.GetResultData1(q.MBE_AlbumGetTrackName, ii)
            track = mbObj.GetOrdinalFromList(q.MBE_AlbumGetTrackList, trackURI)
            dura = mbObj.GetResultInt1(q.MBE_AlbumGetTrackDuration, ii)
            mbdura = "%d:%02d" % divmod(int(dura / 1000), 60)
            ourdura = "%d:%02d" % divmod(trackLengths[ii], 60)
            if artistId == q.MBI_VARIOUS_ARTIST_ID:
                artist = mbObj.GetResultData1(q.MBE_AlbumGetArtistName, ii)
                print "\t%02d - %s - %s (%s) [%s]" % (track, artist, name, mbdura, ourdura) 
            else:
                print "\t%02d - %s (%s) [%s]" % (track, name, mbdura, ourdura) 
        print
        print "\thttp://musicbrainz.org/showalbum.html?discid=%s" % cdid
        print

        def _checkTrackLengths(mbObj, trackLengths):
            # check to make sure the length of these tracks matches up with what the 
            # db says they should be.
            for ii in range(1, mbObj.GetResultInt(q.MBE_AlbumGetNumTracks) + 1):
                dura = mbObj.GetResultInt1(q.MBE_AlbumGetTrackDuration, ii)
                diff = dura - (trackLengths[ii] * 1000)
                if abs(diff) > 3000:
                    return 0
            return 1
            
        if not _checkTrackLengths(mbObj, trackLengths):
            print """\
The time lengths on this CD do not match what the Musicbrainz database say 
they should be.  It could be that this CD is linked to the wrong album.

Go to the album's page that this CD is linked to and verify that it is the correct one

    http://musicbrainz.org/showalbum.html?discid=%s
    
If not you may want to delete this cd's CDIndex id %s from the album.
""" % (cdid, cdid)
            print "Should we go on?  [N/y]"
            choice = sys.stdin.readline().strip()
            if choice.lower() != 'y':
                return None

        return ret
    else:
        url = mbObj.GetWebSubmitURL()
        if url:
            print "opening web browser to '%s'..." % url
            webbrowser.open_new(url)
            print "Import this CD in your webbrowser and then come back here"
            os.system('eject %s' % device)
        else:
            print "Couldn't get cdid... maybe there's no cd in drive?"
        return None
        
def getSignature(filename, songLength=None): 
    (path, ext) = os.path.splitext(filename)
    if ext.lower() == '.wav':
        ff = WavWrapper(filename)
    else:
        raise SystemError, "Unsupported audio file."

    info = ff.info()
    trm = musicbrainz.trm()
    trm.SetPCMDataInfo(info.rate, info.channels, 16)
    if songLength:
        trm.SetSongLength(songLength)
    while 1:
        (buff, bytes, bit) = ff.read()
        if bytes == 0:
            break
        if trm.GenerateSignature(buff):
            break
    sig = trm.FinalizeSignature()

    return sig

class WavWrapper:
    """
    Make the wave module act more like ogg.vorbis.VorbisFile
    """
    def __init__(self, filename):
        self.ff = wave.open(filename, 'r')
    
    def read(self):
        """
        These docs are from ogg.vorbis.VorbisFile.read()
        
        @returns: Returns a tuple: (x,y,y) where x is a buffer object of the
            data read, y is the number of bytes read, and z is whatever the
            bitstream value means (no clue).
        @returntype: tuple
        """
        buff = self.ff.readframes(4096)
        return (buff, len(buff), None)

    def info(self):
        return AudioInfo(self.ff.getframerate(), self.ff.getnchannels())

class AudioInfo:
    def __init__(self, rate, channels):
        self.rate = rate
        self.channels = channels

def usage():
    print "%s: generate a MusicBrainz TRM signature" % sys.argv[0]
    print "     --help      show this message"
    
def writeDefaultConfig():
    cp = ConfigParser.ConfigParser()
    cp.add_section('cd2trm')
    cp.set('cd2trm', 'server', SERVER)
    cp.set('cd2trm', 'username', '')
    cp.set('cd2trm', 'password', '')
    ff = open('cd2trm.ini', 'w')
    cp.write(ff)

def auth(mb, cp):
    mb.Authenticate(cp.get('cd2trm', 'username'), cp.get('cd2trm', 'password'))

def main():
    device = '/dev/cdrom'
    
    optlist, args = getopt.getopt(sys.argv[1:], 'd:', ['device='])
    for o, a in optlist:
        if o in ("-d", "--device"):
            device = a

    if not os.path.isfile('cd2trm.ini'):
        writeDefaultConfig()
        raise SystemExit, "Fill out your username/password in 'cd2trm.ini'"
    cp = ConfigParser.ConfigParser()
    cp.read('cd2trm.ini')
    
    mb = musicbrainz.mb()
    mb.SetServer(cp.get('cd2trm', 'server'), 80)
    mb.SetDepth(2)
    mb.SetDevice(device)
    # mb.SetDebug(1)

    auth(mb, cp)
     
    while 1:
        trackIds = None
        while not trackIds:
            trackIds = getCDInfo(mb)
        
        queryItems = []
        for ii in xrange(len(trackIds)):
            ii = ii + 1
            print "Ripping track %d of %d..." % (ii, len(trackIds))
            
            tempfilename = 'temp%s-%d.wav' % (device.replace('/', '-'), ii)
            #retval = os.system('cdparanoia --abort-on-skip --output-wav %d temp%d.wav' % (ii, ii))
            retval = os.system('cdparanoia --force-cdrom-device=%s --abort-on-skip --output-wav %d-%d[0:40] %s' 
                % (device, ii, ii, tempfilename))
            if os.WTERMSIG(retval) == 2:
                raise SystemExit
            if not os.path.isfile(tempfilename):
                print "skipping because cdparanoia couldn't read the disk perfectly"
                continue
            print "Getting TRM for track %d..." % ii

            sig = getSignature(tempfilename, songLength=trackIds[ii - 1][1])

            os.unlink(tempfilename)

            queryItems.append(queryItem % (trackIds[ii - 1][0], sig))
        
        print "Submiting all track TRM sigs..."
        
        try:
            myquery = query % ''.join(queryItems)
            mb.Query(myquery)
        except musicbrainz.MusicBrainzError, err:
            if str(err) == "Query failed: Session key expired. Please Authenticate again.":
                auth(mb, cp)
                mb.Query(myquery)
            else:
                raise

        print "Ejecting cd..."
        os.system('eject %s' % device)

if __name__ == '__main__':
    main()

