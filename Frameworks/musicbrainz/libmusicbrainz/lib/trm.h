/* --------------------------------------------------------------------------

   MusicBrainz -- The Internet music metadatabase

   Copyright (C) 2000 Robert Kaye
   Copyright (C) Relatable
   
   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.
   
   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free Software
   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

     $Id: trm.h 657 2003-08-18 20:34:52Z robert $

----------------------------------------------------------------------------*/
#ifndef _TRM_H_
#define _TRM_H_

#include <string>
#include <vector>

using namespace std;

class TRM
{
    public:

                TRM(void);
       virtual ~TRM(void);

       bool  SetProxy          (const string &proxyAddr, short proxyPort);
	
       bool  SetPCMDataInfo    (int samplesPerSecond, int numChannels,
		                int bitsPerSample);
       bool  GenerateSignature (char *data, int size);
       int   FinalizeSignature(string &strGUID, string &collID);
       void  ConvertSigToASCII(char sig[17], char ascii_sig[37]);

       void  SetSongLength(long seconds); 
        
    private:

       void DownmixPCM(void);
       int  CountBeats(void); 

       int             m_bits_per_sample;
       int             m_samples_per_second;
       int             m_number_of_channels;
       long            m_downmix_size;
       int             m_finishedFFTs;
       signed short   *m_downmixBuffer;
       char           *m_storeBuffer;
       long            m_numBytesNeeded;
       long            m_numBytesWritten;
       long            m_numSamplesWritten;

       double          fWin[64];
       double          fftBuffer[64];
       double          fftBuffer2[64];
       double          freqs[32];
       float           fLastFFT[32];
       float          *beatStore;
       int             beatindex;
       
       string          m_proxy;
       short           m_proxyPort;

#ifdef WIN32
       __int64         m_song_samples;
#else
       long long       m_song_samples;
#endif
       long            m_song_seconds;
};

#endif
