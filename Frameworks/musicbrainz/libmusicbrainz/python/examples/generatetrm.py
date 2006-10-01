#!/usr/bin/env python

import sys, os, getopt
import musicbrainz
import ogg.vorbis   # get this from http://www.andrewchatham.com/pyogg/
import ao           # get this from http://www.andrewchatham.com/pyogg/
import mad          # get this from http://spacepants.org/src/pymad/
import wave         # should come with python

def getSignature(filename, playWhileReading = None): 
    (path, ext) = os.path.splitext(filename)
    if ext.lower() == '.ogg':
        ff = ogg.vorbis.VorbisFile(filename)
    elif ext.lower() == '.mp3':
        ff = MadWrapper(filename)
    elif ext.lower() == '.wav':
        ff = WavWrapper(filename)
    else:
        raise SystemError, "Unsupported audio file."

    if playWhileReading:
        device = 'esd'
        id = ao.driver_id(device)
        aodev = ao.AudioDevice(id)

    info = ff.info()
    trm = musicbrainz.trm()
    trm.SetPCMDataInfo(info.rate, info.channels, 16)
    while 1:
        (buff, bytes, bit) = ff.read()
        if bytes == 0:
            break
        if trm.GenerateSignature(buff):
            break
        if playWhileReading:
            aodev.play(buff, bytes)

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

class MadWrapper:
    """
    Make the mad module act more like ogg.vorbis.VorbisFile
    """
    def __init__(self, filename):
        self.ff = mad.MadFile(filename)
    
    def read(self):
        """
        These docs are from ogg.vorbis.VorbisFile.read()
        
        @returns: Returns a tuple: (x,y,y) where x is a buffer object of the
            data read, y is the number of bytes read, and z is whatever the
            bitstream value means (no clue).
        @returntype: tuple
        """
        buff = self.ff.read()
        if buff:
            return (buff, len(buff), None)
        else:
            return ('', 0, None)
            
    def info(self):
        if self.ff.mode() == mad.MODE_SINGLE_CHANNEL:
            channels = 1
        else:
            channels = 2
        return AudioInfo(self.ff.samplerate(), channels)


class AudioInfo:
    def __init__(self, rate, channels):
        self.rate = rate
        self.channels = channels

def usage():
    print "%s: generate a MusicBrainz TRM signature" % sys.argv[0]
    print "     --play      play the file while decoding"
    print "     --help      show this message"
    
    
def main():
    playWhileReading = None

    try:
        opts, args = getopt.getopt(sys.argv[1:], "hp", ["help", "play"])
    except getopt.GetoptError:
        # print help information and exit:
        usage()
        sys.exit(2)
    for o, a in opts:
        if o in ("-h", "--help"):
            usage()
            sys.exit()
        if o in ("-p", "--play"):
            playWhileReading = 1

    for filename in args:
        print getSignature(filename, playWhileReading)

if __name__ == '__main__':
    main()

