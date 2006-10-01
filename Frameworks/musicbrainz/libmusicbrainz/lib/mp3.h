/* (PD) 2001 The Bitzi Corporation
 * Please see file COPYING or http://bitzi.com/publicdomain 
 * for more info.
 *
 * $Id: mp3.h 665 2003-10-16 22:21:10Z robert $
 */
#ifndef MP3_H
#define MP3_H

#include <string>
using namespace std;

class MP3Info
{
    public:

        MP3Info(void) {};
       ~MP3Info(void) {};

         bool analyze(const string &fileName);

         int  getBitrate(void) { return m_bitrate; };
         int  getSamplerate(void) { return m_samplerate; };
         int  getStereo(void) { return m_stereo; };
         int  getDuration(void) { return m_duration; };
         int  getFrames(void) { return m_frames; };
         int  getMpegVer(void) { return m_mpegver; };
         int  getAvgBitrate(void) { return m_avgbitrate; };

    private:

         int   findStart(FILE *fp, unsigned offset);
         bool  scanFile(FILE *fp);

         int   framesync(const unsigned char *header);
         int   padding(const unsigned char *header);
         int   mpeg_layer(const unsigned char *header);
         int   mpeg_ver(const unsigned char *header);
         int   stereo(const unsigned char *header);
         int   samplerate(const unsigned char *header);
         int   bitrate(const unsigned char *header);

         bool  isFrame(unsigned char *ptr, int &layer, int &sampleRate, 
                       int &mpegVer, int &bitRate, int &frameSize);

         int   m_goodBytes, m_badBytes;
         int   m_bitrate, m_samplerate, m_stereo, m_duration, 
               m_frames, m_mpegver, m_avgbitrate;
};

#define MP3_HEADER_SIZE 4

#endif
