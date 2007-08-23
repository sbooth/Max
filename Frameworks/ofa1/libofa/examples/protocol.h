/* ------------------------------------------------------------------

   libofa -- the Open Fingerprint Architecture library

   Public Domain (PD) 2006 MusicIP Corporation
   No rights reserved.

-------------------------------------------------------------------*/
#ifndef __PROTOCOL_H__
#define __PROTOCOL_H__

#include <string>
#include "ofa1/ofa.h"

using namespace std;

// This object must be filled out completely prior to making any
// calls to the server.  On return, some fields will be filled out.
class TrackInformation {
private:
    string puid;
    string print;
    string encoding;        // All other strings must honor this encoding
    int    bitrate;         // i.e. "192kbps", use 0 for VBR or freeformat
    string format;          // File extension
    long   length_in_ms;    // In milliseconds
    string artist;
    string track;
    string album;
    int    trackNum;        // use 0 if not known
    string genre;
    string year;
public:
    TrackInformation() :
	bitrate(0), length_in_ms(0), trackNum(0) {}
    ~TrackInformation() {}
    void setPrint(string p) { print = p; }
    string getPrint() const { return print; }
    // Only supported encodings are UTF-8 (default) and ISO-8859-15
    void setEncoding(string e) { encoding = e; }
    string getEncoding() const { return encoding; }
    void setBitrate(int b) { bitrate = b; }
    int getBitrate() const { return bitrate; }
    void setFormat(string fmt) { format = fmt; }
    string getFormat() const { return format; }
    void setLengthInMS(long ms) { length_in_ms = ms; }
    long getLengthInMS() const { return length_in_ms; }
    void setArtist(string name) { artist = name; }
    string getArtist() const { return artist; }
    void setTrack(string name) { track = name; }
    string getTrack() const { return track; }
    void setAlbum(string name) { album = name; }
    string getAlbum() const { return album; }
    void setTrackNum(int t) { trackNum = t; }
    int getTrackNum() const { return trackNum; }
    void setGenre(string g) { genre = g; }
    string getGenre() const { return genre; }
    void setYear(string y) { year = y; }
    string getYear() const { return year; }
    void setPUID(string id)  { puid = id; }
    string getPUID() const { return puid; }
};

// Get your unique key at http://www.musicdns.org
bool retrieve_metadata(string client_key, string client_verstion,
	TrackInformation *info, bool getMetadata);

class AudioData {
private:
    unsigned char *samples;
    int byteOrder;
    long size;
    int sRate;
    bool stereo;
public:
    TrackInformation info;
    AudioData() : samples(0), size(0), sRate(0), stereo(false) {}
    ~AudioData() {
	delete[] samples;
    }
    // size is number of samples (half the number of bytes)
    void setData(unsigned char*_samples, int _byteOrder, long _size,
	   	 int _sRate, bool _stereo, int _ms, string _fmt) {
	samples = _samples;
	byteOrder = _byteOrder;
	size = _size;
	sRate = _sRate;
	stereo = _stereo;
	// These two fields are used later for the protocol layer
	info.setLengthInMS(_ms);
	info.setFormat(_fmt);
    }
    int getByteOrder() const { return byteOrder; }
    long getSize() const { return size; }
    int getSRate() const { return sRate; }
    bool getStereo() const { return stereo; }
    bool createPrint() {
	const char *print = ofa_create_print(samples, byteOrder, size, sRate, stereo);
	if (!print)
	    return false;
	info.setPrint(print);
	return true;
    }
    // Get your unique key at http://www.musicdns.org
    TrackInformation *getMetadata(string client_key, string client_version, 
	    bool metadataFlag)
    {
	if (!retrieve_metadata(client_key, client_version, &info, metadataFlag))
	    return 0;
	return &info;
    }
};

#endif
