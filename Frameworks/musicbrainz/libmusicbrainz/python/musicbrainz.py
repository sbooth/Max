#!/usr/bin/env python

"""
Search and submit data to the MusicBrainz database

The MusicBrainz client library serves as a tool to allow developers to
integrate MusicBrainz searches and metadata exchange functionality into
their applications.

The client library includes the following features: 

 * Lookup Audio CD metadata using CD Index diskids 
 * Calculate Relatable TRM acoustic fingerprints 
 * Search for artist/album/track titles 
 * Lookup metadata by name, TRM ids or MusicBrainz Ids 

See http://mm.musicbrainz.org/client_howto.html for more info
"""

__version__ = "2.1.4"

import os, types, sys

from ctypes import *

class MusicBrainzError(Exception):
    pass
Error = MusicBrainzError

def _openLibrary(libName, version):
    """Opens a library using the ctypes cdll loader.

    The dynamic linker (ld.so on Un*x systems) is used to load the library,
    so it has to be in the linker search path. On some systems, such as
    Linux, the search path can be influenced using the C{LD_LIBRARY_PATH}
    environement variable.

    @param libName: library name without 'lib' prefix or version number
    @param version: a string containing a version number

    @return: a C{ctypes.CDLL} object, representing the opened library

    @raise NotImplementedError: if the library can't be opened
    """
    # This only works for ctypes >= 0.9.9.3. Any library with the given
    # name and version number is found, no matter how it's called on this
    # platform.
    try:
        if hasattr(cdll, 'load_version'):
            if sys.platform == 'win32':
                lib = cdll.load('lib%s' % (libName,))
            else:
                lib = cdll.load_version(libName, version)
            return lib
    except OSError, e:
        raise NotImplementedError('Error opening library: ' + str(e))

    # For compatibility with ctypes < 0.9.9.3 try to figure out the library
    # name without the help of ctypes. We use cdll.LoadLibrary() below,
    # which isn't available for ctypes == 0.9.9.3.
    #
    if sys.platform == 'linux2':
        fullName = 'lib%s.so.%s' % (libName, version)
    elif sys.platform == 'darwin':
        fullName = 'lib%s.%s.dylib' % (libName, version)
    elif sys.platform == 'win32':
        fullName = 'lib%s.dll' % (libName,)
    else:
        # This should at least work for Un*x-style operating systems
        fullName = 'lib%s.so.%s' % (libName, version)

    try:
        lib = cdll.LoadLibrary(fullName)
        return lib
    except OSError, e:
        raise NotImplementedError('Error opening library: ' + str(e))

    assert False # not reached

try:
    mbdll = _openLibrary('musicbrainz', '4')
except NotImplementedError, e:
    raise MusicBrainzError(str(e))

if sys.platform == 'win32':
    mbdll.mb_WSAInit.argtypes = [c_void_p]
    mbdll.mb_WSAStop.argtypes = [c_void_p]     

class mb:
    mbdll.mb_New.argtypes = []
    mbdll.mb_New.restype = c_void_p
    mbdll.mb_UseUTF8.argtypes = [c_void_p, c_int]
    def __init__(self):
        self.mb = mbdll.mb_New();
        # for ctypes 0.9.6
        if not isinstance(self.mb, c_void_p):
            self.mb = c_void_p(self.mb) 
        mbdll.mb_UseUTF8(self.mb, True)
        # need to hold ref for __del__ to work
        self.mbdll = mbdll

        if sys.platform == "win32":
            mbdll.mb_WSAInit(self.mb)
            
        # Parse http_proxy environment variable
        if os.environ.has_key('http_proxy'):
            from urlparse import urlparse
            netloc = urlparse(os.environ['http_proxy'])[1]
            if ':' in netloc:
                host, port = netloc.split(':')
                port = int(port)
            else:
                host = netloc
                port = 80
            if host:
                self.SetProxy(host, port)

    mbdll.mb_Delete.argtypes = [c_void_p]
    def __del__(self):
        if sys.platform == "win32":
            self.mbdll.mb_WSAStop(self.mb)
            
        self.mbdll.mb_Delete(self.mb)
        self.mbdll = None

    mbdll.mb_SetDepth.argtypes = [c_void_p, c_int]
    def SetDepth(self, depth):
        mbdll.mb_SetDepth(self.mb, depth)
    
    mbdll.mb_GetVersion.argtypes = [c_void_p, c_void_p, c_void_p, c_void_p]
    def GetVersion(self):
        major = c_int()
        minor = c_int()
        rev = c_int()
        mbdll.mb_GetVersion(self.mb, byref(major), byref(minor), byref(rev))
        return (major.value, minor.value, rev.value,)

    mbdll.mb_SetServer.argtypes = [c_void_p, c_char_p, c_int]
    def SetServer(self, addr, port):
        if not mbdll.mb_SetServer(self.mb, addr, port):
            raise Error("Could not set server to \"%s\", port %d" % (addr, port,))

    mbdll.mb_SetDebug.argtypes = [c_void_p, c_int]
    def SetDebug(self, debug):
        mbdll.mb_SetDebug(self.mb, debug)
    
    mbdll.mb_SetProxy.argtypes = [c_void_p, c_char_p, c_int]
    def SetProxy(self, addr, port):
        if not mbdll.mb_SetProxy(self.mb, c_char_p(addr), c_int(port)):
            raise Error("Could not set proxy to \"%s\", port %d" % (addr, port,))

    mbdll.mb_GetQueryError.argtypes = [c_void_p, c_char_p, c_int]
    def GetQueryError(self):
        BUFSIZE = 256
        msg = c_buffer(BUFSIZE)
        mbdll.mb_GetQueryError(self.mb, msg, BUFSIZE)
        return msg.value
    
    mbdll.mb_Authenticate.argtypes = [c_void_p, c_char_p, c_char_p]
    def Authenticate(self, username, password):
        if not mbdll.mb_Authenticate(self.mb, username, password):
            raise Error("Authentication failed: %s" % self.GetQueryError())
        
    mbdll.mb_SetDevice.argtypes = [c_void_p, c_char_p]
    def SetDevice(self, device):
        if not mbdll.mb_SetDevice(self.mb, device):
            raise Error("Could not set the device to \"%s\"" % device)
    
    mbdll.mb_SetMaxItems.argtypes = [c_void_p, c_int]
    def SetMaxItems(self, maxitems):
        mbdll.mb_SetMaxItems(self.mb, maxitems)
        
    mbdll.mb_Query.argtypes = [c_void_p, c_char_p]
    def Query(self, query):
        if not mbdll.mb_Query(self.mb, query):
            raise Error("Query failed: %s" % self.GetQueryError())
    
    mbdll.mb_QueryWithArgs.argtypes = [c_void_p, c_char_p, c_void_p]
    def QueryWithArgs(self, query, args):
        if type(args) in types.StringTypes:
            args = (args,)
        arrayClass = c_char_p * (len(args) + 1)
        ary = arrayClass()
        for idx in xrange(len(args)):
            if type(args[idx]) is types.UnicodeType:
                ary[idx] = args[idx].encode('utf-8')
            else:
                ary[idx] = args[idx]
        ary[len(args)] = None
        if not mbdll.mb_QueryWithArgs(self.mb, query, ary):
            raise Error("Query failed: %s" % self.GetQueryError())

    mbdll.mb_GetWebSubmitURL.argtypes = [c_void_p, c_char_p, c_int]
    def GetWebSubmitURL(self):
        BUFSIZE = 1024
        url = c_buffer(BUFSIZE)
        if not mbdll.mb_GetWebSubmitURL(self.mb, url, BUFSIZE):
            raise Error("GetWebSubmitURL failed")
        return url.value

    mbdll.mb_Select.argtypes = [c_void_p, c_char_p]
    def Select(self, query):
        return mbdll.mb_Select(self.mb, query)
    
    mbdll.mb_Select1.argtypes = [c_void_p, c_char_p, c_int]
    def Select1(self, query, ord):
        return mbdll.mb_Select1(self.mb, query, ord)

    mbdll.mb_SelectWithArgs.argtypes = [c_void_p, c_char_p, c_void_p]
    def SelectWithArgs(self, query, args):
        arrayClass = c_int * (len(args) + 1)
        ary = arrayClass()
        for idx in xrange(len(args)):
            ary[idx] = args[idx]
        ary[len(args)] = None
        return mbdll.mb_Select(self.mb, query, args)
   
    mbdll.mb_GetResultData.argtypes = [c_void_p, c_char_p, c_char_p, c_int]
    def GetResultData(self, query):
        BUFSIZE = 1024
        data = c_buffer(BUFSIZE)
        if not mbdll.mb_GetResultData(self.mb, query, data, BUFSIZE):
            raise Error("Error in GetResultData")
        return data.value.decode('utf-8')

    mbdll.mb_GetResultData1.argtypes = [c_void_p, c_char_p, c_char_p, c_int, c_int]
    def GetResultData1(self, query, ord):
        BUFSIZE = 1024
        data = c_char_p('\x00' * BUFSIZE)
        if not mbdll.mb_GetResultData1(self.mb, query, data, BUFSIZE, ord):
            raise Error("Error in GetResultData1")
        return data.value.decode('utf-8')

    mbdll.mb_DoesResultExist.argtypes = [c_void_p, c_char_p]
    def DoesResultExist(self, query):
        return mbdll.mb_DoesResultExist(self.mb, query)

    mbdll.mb_DoesResultExist1.argtypes = [c_void_p, c_char_p, c_int]
    def DoesResultExist1(self, query, ord):
        return mbdll.mb_DoesResultExist1(self.mb, query, ord)
        
    mbdll.mb_GetResultInt.argtypes = [c_void_p, c_char_p]
    def GetResultInt(self, query):
        return mbdll.mb_GetResultInt(self.mb, query)

    mbdll.mb_GetResultInt1.argtypes = [c_void_p, c_char_p, c_int]
    def GetResultInt1(self, query, ord):
        return mbdll.mb_GetResultInt1(self.mb, query, ord)

    mbdll.mb_GetResultRDF.argtypes = [c_void_p, c_char_p, c_int]
    mbdll.mb_GetResultRDFLen.argtypes = [c_void_p]
    def GetResultRDF(self):
        BUFSIZE = mbdll.mb_GetResultRDFLen(self.mb)
        data = c_buffer(BUFSIZE)
        if not mbdll.mb_GetResultRDF(self.mb, data, BUFSIZE):
            raise Error("Couldn't return RDF")
        return data.value.decode('utf-8')

    mbdll.mb_SetResultRDF.argtypes = [c_void_p, c_char_p]
    def SetResultRDF(self, rdf):
        if not mbdll.mb_SetResultRDF(self.mb, rdf):
            raise Error("Couldn't set RDF")
    
    mbdll.mb_GetIDFromURL.argtypes = [c_void_p, c_char_p, c_char_p, c_int]
    def GetIDFromURL(self, url):
        BUFSIZE = 256
        ret = c_buffer(BUFSIZE)
        mbdll.mb_GetIDFromURL(self.mb, url.encode('utf-8'), ret, BUFSIZE)
        return ret.value

    mbdll.mb_GetFragmentFromURL.argtypes = [c_void_p, c_char_p, c_char_p, c_int]
    def GetFragmentFromURL(self, url):
        BUFSIZE = 256
        ret = c_buffer(BUFSIZE)
        mbdll.mb_GetFragmentFromURL(self.mb, url.encode('utf-8'), ret, BUFSIZE)
        return ret.value

    mbdll.mb_GetOrdinalFromList.argtypes = [c_void_p, c_char_p, c_char_p]
    def GetOrdinalFromList(self, resultList, url):
        return mbdll.mb_GetOrdinalFromList(self.mb, resultList, url.encode('utf-8'))

    mbdll.mb_GetMP3Info.argtypes = [c_void_p, c_char_p, c_void_p, c_void_p, c_void_p, c_void_p]
    def GetMP3Info(self, fileName):
        duration = c_int()
        bitrate = c_int()
        stereo = c_int()
        samplerate = c_int()
        
        ret = mbdll.mb_GetMP3Info(self.mb, fileName, byref(duration), byref(bitrate), byref(stereo), byref(samplerate))
        if not ret:
            raise Error("Couldn't examine mp3 file")
        
        info = {}
        info["duration"] = duration.value
        info["bitrate"] = bitrate.value
        info["stereo"] = stereo.value
        info["samplerate"] = samplerate.value
        
        return info
        
class trm:
    mbdll.trm_New.argtypes = []
    mbdll.trm_New.restype = c_void_p
    def __init__(self):
        self.trm = mbdll.trm_New()
        # only used for __del__
        self.mbdll = mbdll
        
    mbdll.trm_Delete.argtypes = [c_void_p]
    def __del__(self):
        self.mbdll.trm_Delete(self.trm)
        self.mbdll = None

    mbdll.trm_SetProxy.argtypes = [c_void_p, c_char_p, c_int]
    def SetProxy(self, addr, port):
        if not mbdll.trm_SetProxy(self.trm, addr, port):
            raise Error("Could not set proxy to \"%s\", port %d" % (addr, port,))
        
    mbdll.trm_SetPCMDataInfo.argtypes = [c_void_p, c_int, c_int, c_int]
    def SetPCMDataInfo(self, samplesPerSecond, numChannels, bitsPerSample):
        mbdll.trm_SetPCMDataInfo(self.trm, samplesPerSecond, numChannels, bitsPerSample)
    
    mbdll.trm_GenerateSignature.argtypes = [c_void_p, c_char_p, c_int]
    def GenerateSignature(self, data):
        buf = c_buffer(len(data))
        buf.raw = str(data)
        
        return mbdll.trm_GenerateSignature(self.trm, buf, len(buf))        

    mbdll.trm_FinalizeSignature.argtypes = [c_void_p, c_char_p, c_char_p]
    mbdll.trm_ConvertSigToASCII.argtypes = [c_void_p, c_char_p, c_char_p]
    def FinalizeSignature(self):
        sig = c_buffer(17)
        mbdll.trm_FinalizeSignature(self.trm, sig, None)
        asciiSig = c_buffer(37)
        mbdll.trm_ConvertSigToASCII(self.trm, sig, asciiSig)
        return asciiSig.value

    mbdll.trm_SetSongLength.argtypes = [c_void_p, c_long]
    def SetSongLength(self, seconds):
        mbdll.trm_SetSongLength(self.trm, seconds)
        
    
### -------------- don't edit below this line -------------------- ###

# auto generated.  run ./setup.py build_queries to update
MBE_AlbumGetAlbumArtistId = """\
http://purl.org/dc/elements/1.1/creator"""

MBE_AlbumGetAlbumArtistName = """\
http://purl.org/dc/elements/1.1/creator http://purl.org/dc/elements/1.1/title"""

MBE_AlbumGetAlbumArtistSortName = """\
http://purl.org/dc/elements/1.1/creator http://musicbrainz.org/mm/mm-2.1#sortName"""

MBE_AlbumGetAlbumId = """\
"""

MBE_AlbumGetAlbumName = """\
http://purl.org/dc/elements/1.1/title"""

MBE_AlbumGetAlbumStatus = """\
http://musicbrainz.org/mm/mm-2.1#releaseStatus"""

MBE_AlbumGetAlbumType = """\
http://musicbrainz.org/mm/mm-2.1#releaseType"""

MBE_AlbumGetAmazonAsin = """\
http://www.amazon.com/gp/aws/landing.html#Asin"""

MBE_AlbumGetArtistId = """\
http://musicbrainz.org/mm/mm-2.1#trackList [] http://purl.org/dc/elements/1.1/creator"""

MBE_AlbumGetArtistName = """\
http://musicbrainz.org/mm/mm-2.1#trackList [] http://purl.org/dc/elements/1.1/creator http://purl.org/dc/elements/1.1/title"""

MBE_AlbumGetArtistSortName = """\
http://musicbrainz.org/mm/mm-2.1#trackList [] http://purl.org/dc/elements/1.1/creator http://musicbrainz.org/mm/mm-2.1#sortName"""

MBE_AlbumGetNumCdindexIds = """\
http://musicbrainz.org/mm/mm-2.1#cdindexidList [COUNT]"""

MBE_AlbumGetCdindexId = """\
http://musicbrainz.org/mm/mm-2.1#cdindexidList []"""

MBE_AlbumGetNumReleaseDates = """\
http://musicbrainz.org/mm/mm-2.1#releaseDateList [COUNT]"""

MBE_AlbumGetNumTracks = """\
http://musicbrainz.org/mm/mm-2.1#trackList [COUNT]"""

MBE_AlbumGetTrackDuration = """\
http://musicbrainz.org/mm/mm-2.1#trackList [] http://musicbrainz.org/mm/mm-2.1#duration"""

MBE_AlbumGetTrackId = """\
http://musicbrainz.org/mm/mm-2.1#trackList []"""

MBE_AlbumGetTrackList = """\
http://musicbrainz.org/mm/mm-2.1#trackList"""

MBE_AlbumGetTrackName = """\
http://musicbrainz.org/mm/mm-2.1#trackList [] http://purl.org/dc/elements/1.1/title"""

MBE_AlbumGetTrackNum = """\
http://musicbrainz.org/mm/mm-2.1#trackList [?] http://musicbrainz.org/mm/mm-2.1#trackNum"""

MBE_ArtistGetAlbumId = """\
http://musicbrainz.org/mm/mm-2.1#albumList []"""

MBE_ArtistGetAlbumName = """\
http://musicbrainz.org/mm/mm-2.1#albumList [] http://purl.org/dc/elements/1.1/title"""

MBE_ArtistGetArtistId = """\
"""

MBE_ArtistGetArtistName = """\
http://purl.org/dc/elements/1.1/title"""

MBE_ArtistGetArtistSortName = """\
http://musicbrainz.org/mm/mm-2.1#sortName"""

MBE_AuthGetChallenge = """\
http://musicbrainz.org/mm/mq-1.1#authChallenge"""

MBE_AuthGetSessionId = """\
http://musicbrainz.org/mm/mq-1.1#sessionId"""

MBE_GetError = """\
http://musicbrainz.org/mm/mq-1.1#error"""

MBE_GetNumAlbums = """\
http://musicbrainz.org/mm/mm-2.1#albumList [COUNT]"""

MBE_GetNumArtists = """\
http://musicbrainz.org/mm/mm-2.1#artistList [COUNT]"""

MBE_GetNumLookupResults = """\
http://musicbrainz.org/mm/mq-1.1#lookupResultList [COUNT]"""

MBE_GetNumTracks = """\
http://musicbrainz.org/mm/mm-2.1#trackList [COUNT]"""

MBE_GetNumTrmids = """\
http://musicbrainz.org/mm/mm-2.1#trmidList [COUNT]"""

MBE_GetStatus = """\
http://musicbrainz.org/mm/mq-1.1#status"""

MBE_LookupGetAlbumArtistId = """\
http://musicbrainz.org/mm/mq-1.1#album  http://purl.org/dc/elements/1.1/creator"""

MBE_LookupGetAlbumId = """\
http://musicbrainz.org/mm/mq-1.1#album"""

MBE_LookupGetArtistId = """\
http://musicbrainz.org/mm/mq-1.1#artist"""

MBE_LookupGetRelevance = """\
http://musicbrainz.org/mm/mq-1.1#relevance"""

MBE_LookupGetTrackArtistId = """\
http://musicbrainz.org/mm/mq-1.1#track  http://purl.org/dc/elements/1.1/creator"""

MBE_LookupGetTrackId = """\
http://musicbrainz.org/mm/mq-1.1#track"""

MBE_LookupGetType = """\
http://www.w3.org/1999/02/22-rdf-syntax-ns#type"""

MBE_QuerySubject = """\
http://musicbrainz.org/mm/mq-1.1#Result"""

MBE_QuickGetAlbumName = """\
http://musicbrainz.org/mm/mq-1.1#albumName"""

MBE_QuickGetArtistId = """\
http://musicbrainz.org/mm/mm-2.1#artistid"""

MBE_QuickGetArtistName = """\
http://musicbrainz.org/mm/mq-1.1#artistName"""

MBE_QuickGetArtistSortName = """\
http://musicbrainz.org/mm/mm-2.1#sortName"""

MBE_QuickGetTrackDuration = """\
http://musicbrainz.org/mm/mm-2.1#duration"""

MBE_QuickGetTrackId = """\
http://musicbrainz.org/mm/mm-2.1#trackid"""

MBE_QuickGetTrackName = """\
http://musicbrainz.org/mm/mq-1.1#trackName"""

MBE_QuickGetTrackNum = """\
http://musicbrainz.org/mm/mm-2.1#trackNum"""

MBE_ReleaseGetCountry = """\
http://musicbrainz.org/mm/mm-2.1#country"""

MBE_ReleaseGetDate = """\
http://purl.org/dc/elements/1.1/date"""

MBE_TOCGetCDIndexId = """\
http://musicbrainz.org/mm/mm-2.1#cdindexid"""

MBE_TOCGetFirstTrack = """\
http://musicbrainz.org/mm/mm-2.1#firstTrack"""

MBE_TOCGetLastTrack = """\
http://musicbrainz.org/mm/mm-2.1#lastTrack"""

MBE_TOCGetTrackNumSectors = """\
http://musicbrainz.org/mm/mm-2.1#toc [] http://musicbrainz.org/mm/mm-2.1#numSectors"""

MBE_TOCGetTrackSectorOffset = """\
http://musicbrainz.org/mm/mm-2.1#toc [] http://musicbrainz.org/mm/mm-2.1#sectorOffset"""

MBE_TrackGetArtistId = """\
http://purl.org/dc/elements/1.1/creator"""

MBE_TrackGetArtistName = """\
http://purl.org/dc/elements/1.1/creator http://purl.org/dc/elements/1.1/title"""

MBE_TrackGetArtistSortName = """\
http://purl.org/dc/elements/1.1/creator http://musicbrainz.org/mm/mm-2.1#sortName"""

MBE_TrackGetTrackDuration = """\
http://musicbrainz.org/mm/mm-2.1#duration"""

MBE_TrackGetTrackId = """\
"""

MBE_TrackGetTrackName = """\
http://purl.org/dc/elements/1.1/title"""

MBE_TrackGetTrackNum = """\
http://musicbrainz.org/mm/mm-2.1#trackNum"""

MBE_GetRelationshipType = """\
http://www.w3.org/1999/02/22-rdf-syntax-ns#type"""

MBE_GetRelationshipDirection = """\
http://musicbrainz.org/ar/ar-1.0#direction"""

MBE_GetRelationshipArtistId = """\
http://musicbrainz.org/ar/ar-1.0#toArtist"""

MBE_GetRelationshipArtistName = """\
http://musicbrainz.org/ar/ar-1.0#toArtist http://purl.org/dc/elements/1.1/title"""

MBE_GetRelationshipAlbumId = """\
http://musicbrainz.org/ar/ar-1.0#toAlbum"""

MBE_GetRelationshipAlbumName = """\
http://musicbrainz.org/ar/ar-1.0#toAlbum http://purl.org/dc/elements/1.1/title"""

MBE_GetRelationshipTrackId = """\
http://musicbrainz.org/ar/ar-1.0#toTrack"""

MBE_GetRelationshipTrackName = """\
http://musicbrainz.org/ar/ar-1.0#toTrack http://purl.org/dc/elements/1.1/title"""

MBE_GetRelationshipURL = """\
http://musicbrainz.org/ar/ar-1.0#toUrl"""

MBE_GetRelationshipAttribute = """\
http://musicbrainz.org/ar/ar-1.0#attributeList []"""

MBI_VARIOUS_ARTIST_ID = """\
89ad4ac3-39f7-470e-963a-56509c546377"""

MBQ_AssociateCD = """\
@CDINFOASSOCIATECD@"""

MBQ_Authenticate = """\
<mq:AuthenticateQuery>
    <mq:username>@1@</mq:username>
 </mq:AuthenticateQuery>"""

MBQ_FileInfoLookup = """\
<mq:FileInfoLookup>
    <mm:trmid>@1@</mm:trmid>
    <mq:artistName>@2@</mq:artistName>
    <mq:albumName>@3@</mq:albumName>
    <mq:trackName>@4@</mq:trackName>
    <mm:trackNum>@5@</mm:trackNum>
    <mm:duration>@6@</mm:duration>
    <mq:fileName>@7@</mq:fileName>
    <mm:artistid>@8@</mm:artistid>
    <mm:albumid>@9@</mm:albumid>
    <mm:trackid>@10@</mm:trackid>
    <mq:maxItems>@MAX_ITEMS@</mq:maxItems>
 </mq:FileInfoLookup>"""

MBQ_FindAlbumByName = """\
<mq:FindAlbum>
    <mq:depth>@DEPTH@</mq:depth>
    <mq:maxItems>@MAX_ITEMS@</mq:maxItems>
    <mq:albumName>@1@</mq:albumName>
 </mq:FindAlbum>"""

MBQ_FindArtistByName = """\
<mq:FindArtist>
    <mq:depth>@DEPTH@</mq:depth>
    <mq:artistName>@1@</mq:artistName>
    <mq:maxItems>@MAX_ITEMS@</mq:maxItems>
 </mq:FindArtist>"""

MBQ_FindDistinctTRMId = """\
<mq:FindDistinctTRMID>
    <mq:depth>@DEPTH@</mq:depth>
    <mq:artistName>@1@</mq:artistName>
    <mq:trackName>@2@</mq:trackName>
 </mq:FindDistinctTRMID>"""

MBQ_FindTrackByName = """\
<mq:FindTrack>
    <mq:depth>@DEPTH@</mq:depth>
    <mq:maxItems>@MAX_ITEMS@</mq:maxItems>
    <mq:trackName>@1@</mq:trackName>
 </mq:FindTrack>"""

MBQ_GetAlbumById = """\
http://@URL@/mm-2.1/album/@1@/@DEPTH@"""

MBQ_GetArtistById = """\
http://@URL@/mm-2.1/artist/@1@/@DEPTH@"""

MBQ_GetCDInfo = """\
@CDINFO@"""

MBQ_GetCDInfoFromCDIndexId = """\
<mq:GetCDInfo>
    <mq:depth>@DEPTH@</mq:depth>
    <mm:cdindexid>@1@</mm:cdindexid>
 </mq:GetCDInfo>"""

MBQ_GetCDTOC = """\
@LOCALCDINFO@"""

MBQ_GetTrackById = """\
http://@URL@/mm-2.1/track/@1@/@DEPTH@"""

MBQ_GetTrackByTRMId = """\
http://@URL@/mm-2.1/trmid/@1@/@DEPTH@"""

MBQ_QuickTrackInfoFromTrackId = """\
<mq:QuickTrackInfoFromTrackId>
    <mm:trackid>@1@</mm:trackid>
    <mm:albumid>@2@</mm:albumid>
 </mq:QuickTrackInfoFromTrackId>"""

MBQ_SubmitTrack = """\
<mq:SubmitTrack>
    <mq:artistName>@1@</mq:artistName>
    <mq:albumName>@2@</mq:albumName>
    <mq:trackName>@3@</mq:trackName>
    <mm:trmid>@4@</mm:trmid>
    <mm:trackNum>@5@</mm:trackNum>
    <mm:duration>@6@</mm:duration>
    <mm:issued>@7@</mm:issued>
    <mm:genre>@8@</mm:genre>
    <dc:description>@9@</dc:description>
    <mm:link>@10@</mm:link>
    <mq:sessionId>@SESSID@</mq:sessionId>
    <mq:sessionKey>@SESSKEY@</mq:sessionKey>
 </mq:SubmitTrack>"""

MBQ_SubmitTrackTRMId = """\
<mq:SubmitTRMList>
  <mm:trmidList>
   <rdf:Bag>
    <rdf:li>
     <mq:trmTrackPair>
      <mm:trackid>@1@</mm:trackid>
      <mm:trmid>@2@</mm:trmid>
     </mq:trmTrackPair>
    </rdf:li>
   </rdf:Bag>
  </mm:trmidList>
  <mq:sessionId>@SESSID@</mq:sessionId>
  <mq:sessionKey>@SESSKEY@</mq:sessionKey>
  <mq:clientVersion>@CLIENTVER@</mq:clientVersion>
 </mq:SubmitTRMList>"""

MBQ_TrackInfoFromTRMId = """\
<mq:TrackInfoFromTRMId>
    <mm:trmid>@1@</mm:trmid>
    <mq:artistName>@2@</mq:artistName>
    <mq:albumName>@3@</mq:albumName>
    <mq:trackName>@4@</mq:trackName>
    <mm:trackNum>@5@</mm:trackNum>
    <mm:duration>@6@</mm:duration>
 </mq:TrackInfoFromTRMId>"""


MBQ_GetArtistRelationsById ="""\
http://@URL@/mm-2.1/artistrel/@1@"""

MBQ_GetAlbumRelationsById ="""\
http://@URL@/mm-2.1/albumrel/@1@"""

MBQ_GetTrackRelationsById ="""\
http://@URL@/mm-2.1/trackrel/@1@"""

MBS_Back = """\
[BACK]"""

MBS_Rewind = """\
[REWIND]"""

MBS_SelectAlbum = """\
http://musicbrainz.org/mm/mm-2.1#albumList []"""

MBS_SelectAlbumArtist = """\
http://purl.org/dc/elements/1.1/creator"""

MBS_SelectArtist = """\
http://musicbrainz.org/mm/mm-2.1#artistList []"""

MBS_SelectCdindexid = """\
http://musicbrainz.org/mm/mm-2.1#cdindexidList []"""

MBS_SelectLookupResult = """\
http://musicbrainz.org/mm/mq-1.1#lookupResultList []"""

MBS_SelectLookupResultAlbum = """\
http://musicbrainz.org/mm/mq-1.1#album"""

MBS_SelectLookupResultArtist = """\
http://musicbrainz.org/mm/mq-1.1#artist"""

MBS_SelectLookupResultTrack = """\
http://musicbrainz.org/mm/mq-1.1#track"""

MBS_SelectReleaseDate = """\
http://musicbrainz.org/mm/mm-2.1#releaseDateList []"""

MBS_SelectTrack = """\
http://musicbrainz.org/mm/mm-2.1#trackList []"""

MBS_SelectTrackAlbum = """\
http://musicbrainz.org/mm/mq-1.1#album"""

MBS_SelectTrackArtist = """\
http://purl.org/dc/elements/1.1/creator"""

MBS_SelectTrmid = """\
http://musicbrainz.org/mm/mm-2.1#trmidList []"""

MBS_SelectRelationship = """\
http://musicbrainz.org/ar/ar-1.0#relationshipList []"""

