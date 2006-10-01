/* (PD) 2001 The Bitzi Corporation
 * Please see file COPYING or http://bitzi.com/publicdomain 
 * for more info.
 *
 * $Id: mp3.cpp 665 2003-10-16 22:21:10Z robert $
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "mp3.h"

#define DB printf("%s:%d\n", __FILE__, __LINE__);

#define NUMBITRATES 15
static int mpeg1Bitrates[3][16] = 
{
   // Layer I
   { 0, 32, 64, 96, 128,160, 192, 224, 256, 288, 320, 352, 384, 416, 448, -1 },
   // Layer II
   { 0, 32, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 384, -1 },
   // Layer III
   { 0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, -1 }
};

static int mpeg2Bitrates[3][16] = 
{
    // Layer I
    { 0, 32, 48, 56, 64, 80, 69, 112, 128, 144, 160, 176, 192, 224, 256, -1 },
    // Layer II
    { 0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160, -1 },
    // Layer III (same as Layer II)
    { 0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160, -1 }
};

static int mpeg1SampleRates[] = { 44100, 48000, 32000 };
static int mpeg2SampleRates[] = { 22050, 24000, 16000 };
static int mpegLayer[] = { 0, 3, 2, 1 };

#define ID3_TAG_LEN 128

int MP3Info::bitrate(const unsigned char *header)
{
   int id, br, ly;

   id = (header[1] & 0x8) >> 3;
   br = (header[2] & 0xF0) >> 4;
   ly = (header[1] & 0x07) >> 1;

   if (br >= NUMBITRATES)
     return 0;

   ly = 3 - ly;
   if (ly > 3 || ly < 1)
     return 0;

   return id ? mpeg1Bitrates[ly][br] : mpeg2Bitrates[ly][br];
}

int MP3Info::samplerate(const unsigned char *header)
{
   int id, sr;

   id = (header[1] & 0x8) >> 3;
   sr = (header[2] >> 2) & 0x3;

   return id ? mpeg1SampleRates[sr] : mpeg2SampleRates[sr];
}

int MP3Info::stereo(const unsigned char *header)
{
   return ((header[3] & 0xc0) >> 6) != 3;
}

int MP3Info::mpeg_ver(const unsigned char *header)
{
    int version = (header[1] >> 3) & 0x03;
    if (version == 3)
        return 1;
    if (version == 0 || version == 2)
        return 2;
    return 0;
}

int MP3Info::mpeg_layer(const unsigned char *header)
{
   return mpegLayer[((header[1] & 0x7) >> 1)]; 
}

int MP3Info::padding(const unsigned char *header)
{
   return (header[2] >> 1) & 0x1;
}

int MP3Info::framesync(const unsigned char *header) 
{
    if  (header[0] != 0xff || header[1] >> 5 != 0x07)
        return 0;

    return 1;
}

bool MP3Info::isFrame(unsigned char *ptr, int &layer, int &sampleRate, 
                      int &mpegVer, int &bitRate, int &frameSize)
{
    /* Find the frame marker */
    if (!framesync(ptr))
        return false;

    /* Extract sample rate and layer from this first frame */
    sampleRate = samplerate(ptr);
    layer = mpeg_layer(ptr);
    mpegVer = mpeg_ver(ptr);
    bitRate = bitrate(ptr);

    /* Check for invalid sample rates */
    if (sampleRate == 0)
        return false;

    /* Check for invalid bitrates rates */
    if (bitRate == 0) 
        return false;

    /* Check for invalid layer */
    if (layer == 0) 
        return false;

    /* Calculate the size of the frame from the header components */
    if (mpegVer == 1)
        frameSize = (144000 * bitRate) / sampleRate;
    else if (mpeg_ver(ptr) == 2)
        frameSize = (72000 * bitRate) / sampleRate;
    else 
        return false;

    if (frameSize <= 1 || frameSize > 2048)
        return false;

    frameSize += padding(ptr);

    return true;
}       

int MP3Info::findStart(FILE *fp, unsigned offset)
{
   unsigned char ptr[4];
   unsigned      baseOffset;
   int           firstSampleRate = -1, firstLayer = -1, nextSampleRate = -1, nextLayer = -1;
   int           firstMpegVer = -1, nextMpegVer = -1;
   int           firstBitrate = -1, nextBitrate = -1;
   int           firstFrameSize = -1, nextFrameSize = -1;
   int           goodFrames = 0, ret;

   goodFrames = -1;
   baseOffset = offset - 1;
   m_badBytes--;

   /* Loop through the buffer trying to find frames */
   for(;;)
   {       
       // If goodframes is negative than its the first time
       // through the loop or we're resetting because of an error 
       // from an earlier pass
       if (goodFrames < 0)
       {
           baseOffset++;
           m_badBytes++;
           goodFrames = 0;

           ret = fseek(fp, baseOffset, SEEK_SET);
           if (ret < 0)
               return -1;
       }

       ret = fread(ptr, sizeof(char), 4, fp);
       if (ret != 4)
           return -1;

       // Check to see if we have a valid frame
       if (!isFrame(ptr, firstLayer, firstSampleRate, firstMpegVer, 
                    firstBitrate, firstFrameSize))
       {
           goodFrames = -1;
           continue;
       }

       //printf("First [%05lu]: br: %d sr: %d mp: %d sz: %d\n",
       //        ftell(fp)-4, (int)firstBitrate, firstSampleRate, 
       //        firstMpegVer, firstFrameSize);

       ret = fseek(fp, firstFrameSize - 4, SEEK_CUR);
       if (ret < 0)
           return -1;

       ret = fread(ptr, sizeof(char), 4, fp);
       if (ret != 4)
           return -1;

       // Check to see if we can find another frame where the next frame should be
       if (!isFrame(ptr, nextLayer, nextSampleRate, nextMpegVer, 
                    nextBitrate, nextFrameSize))
       {
           goodFrames = -1;
           continue;
       }
       //printf("secnd [%05lu] br: %d sr: %d mp: %d sz: %d (%d)\n",
       //          ftell(fp)-4, (int)nextBitrate, nextSampleRate, 
       //          nextMpegVer, nextFrameSize, goodFrames);

       if (firstSampleRate == nextSampleRate && 
           firstLayer == nextLayer &&
           firstMpegVer == nextMpegVer) 
       {
           // How do you move to the next iteration??
           goodFrames++;
           ret = fseek(fp, nextFrameSize - 4, SEEK_CUR);
           if (ret < 0)
               return -1;

           if (goodFrames == 6)
               return baseOffset;

           continue;
       }
       goodFrames = -1;
   }
   return -1;
}

bool MP3Info::scanFile(FILE *fp)
{
   unsigned char ptr[4];
   int           sampleRate, layer, mpegVer, frameSize, bitRate;
   long          start = 0;
   int           ret;

   m_frames = 0;

   for(;;)
   {       
       start = findStart(fp, start);
       if (start < 0)
           return (m_frames > 0) ? true : false;


       ret = fseek(fp, start, SEEK_SET);
       if (ret < 0)
           return false;

       for(;;)
       {
           ret = fread(ptr, sizeof(char), 4, fp);
           if (ret != 4)
               return true;

           // Check to see if we have a valid frame
           if (!isFrame(ptr, layer, sampleRate, mpegVer, bitRate, frameSize))
           {
               break;
           }
       
           //printf(" scan [%05lu] br: %d sr: %d mp: %d ly: %d sz: %d\n",
           //      ftell(fp)-4, (int)bitRate, sampleRate, 
           //      mpegVer, layer, frameSize);

           m_frames++;
           m_goodBytes += frameSize;
           start += frameSize;
           m_avgbitrate += frameSize;

           if (m_samplerate == 0)
           {
               m_samplerate = sampleRate;
               m_bitrate = bitRate;
               m_stereo = stereo(ptr);
               m_mpegver = mpegVer;
               m_bitrate = bitRate;
           }

           // Check for VBR, and if so, set bitrate to 0.
           if (m_bitrate != 0 && bitRate != m_bitrate)
               m_bitrate = 0;

           ret = fseek(fp, frameSize - 4, SEEK_CUR);
           if (ret < 0)
               return true;
       }
   }
}

bool MP3Info::analyze(const string &fileName)
{
    FILE *fp;

    m_goodBytes = 0;
    m_badBytes = 0;
    m_bitrate = -1;
    m_samplerate = 0;

    fp = fopen(fileName.c_str(), "rb");
    if (fp == NULL)
       return false;

    if (!scanFile(fp))
    {
        fclose(fp);
        return false;
    }
    fclose(fp);

    if (m_badBytes > m_goodBytes || m_goodBytes == 0)
        return false;

    if (m_mpegver == 1)
        m_duration = (m_frames * 1152 / (m_samplerate / 100)) * 10;
    else
        m_duration = (m_frames * 576 / (m_samplerate / 100)) * 10;

    m_avgbitrate /= m_frames;

    return true;
}
