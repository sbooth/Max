/* --------------------------------------------------------------------------

   MusicBrainz -- The Internet music metadatabase

   Portions Copyright (C) 2000 Relatable
   
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

   $Id: signature.cpp 680 2004-03-09 00:08:14Z robert $
----------------------------------------------------------------------------*/

#include "trm.h"
#include "sigfft.h"
#include "sigclient.h"
#include "sigxdr.h"
#include "uuid.h"
#include "haar.h"

#include <stdio.h>
#include <stdlib.h>

#include <stack>
#include <queue>
#include <deque>
using namespace std;

const int iFFTPoints = 64;
const int iNumSamplesNeeded = 288000;

#ifdef WIN32
   typedef __int64 llong;
#else
   typedef long long llong;
#endif

char silenceTRM[] = { 0x7d, 0x15, 0x4f, 0x52, 0xb5, 0x36, 0x4f, 0xae, 
                      0xb5, 0x8b, 0x06, 0x66, 0x82, 0x6c, 0x2b, 0xac, 0x00 };

TRM::TRM(void)
{
    m_downmixBuffer = NULL;
    m_storeBuffer = NULL;
    m_proxy = "";
    m_proxyPort = 80;
    m_song_samples = 0;
    m_song_seconds = -1;
}

TRM::~TRM(void)
{
    if (m_downmixBuffer) {
	delete [] m_downmixBuffer;
	m_downmixBuffer = NULL;
    }
    if (m_storeBuffer) {
        delete [] m_storeBuffer;
        m_storeBuffer = NULL;
    }
}

bool TRM::SetProxy(const string &proxyAddr, short proxyPort)
{
    m_proxy = proxyAddr;
    m_proxyPort = proxyPort;

    return true;
}

bool TRM::SetPCMDataInfo(int samplesPerSecond, int numChannels,
                         int bitsPerSample)
{
    m_samples_per_second = samplesPerSecond;

    if (numChannels != 1 && numChannels != 2) 
      return false;
    m_number_of_channels = numChannels;
    if (bitsPerSample != 8 && bitsPerSample != 16)
      return false;
    m_bits_per_sample = bitsPerSample;

    if (m_downmixBuffer) {
        delete [] m_downmixBuffer;
        m_downmixBuffer = NULL;
    }
    if (m_storeBuffer) {
        delete [] m_storeBuffer;
        m_storeBuffer = NULL;
    }
    m_numSamplesWritten = 0;

    float mult = (float)m_samples_per_second / 11025.0;
    mult *= (m_bits_per_sample / 8);
    mult *= (m_number_of_channels);
    mult = ceil(mult);

    m_numBytesWritten = 0;
    m_numBytesNeeded = iNumSamplesNeeded * (int)mult;
    m_storeBuffer = new char[m_numBytesNeeded + 20];

    m_song_samples = 0;
    m_song_seconds = -1;
    return true;
}

void TRM::SetSongLength(long seconds)
{
    m_song_seconds = seconds;
}

bool TRM::GenerateSignature(char *data, int size)
{
   if (m_numBytesWritten < m_numBytesNeeded) {
       int i = 0;
       while (i < size && m_numBytesWritten < m_numBytesNeeded) 
       {
           if (m_bits_per_sample == 8)
           {
               if (m_numBytesWritten == 0 && (abs(data[i]) == 0))
               {
               }
               else
               {
                   m_storeBuffer[m_numBytesWritten] = data[i];
                   m_numBytesWritten++;
               }
               i++;
           }
	   else
           {
               if (m_numBytesWritten == 0 && (abs(data[i]) == 0) &&
                   (abs(data[i+1]) == 0))
               {
               }
               else
               {
                   m_storeBuffer[m_numBytesWritten] = data[i];
                   m_numBytesWritten++;
                   m_storeBuffer[m_numBytesWritten] = data[i+1];
                   m_numBytesWritten++;
               }
               i += 2;
	   }
       }
   }

   if (m_bits_per_sample == 8)
       m_song_samples += size;
   else
       m_song_samples += size / 2;

   if (m_numBytesWritten < m_numBytesNeeded)
       return false;

   if (m_song_seconds > 0)
       return true;

   return false;
}

void TRM::DownmixPCM(void)
{
   // DC Offset fix
   long int lsum = 0, rsum = 0;
   long int numsamps = 0;
   int lDC = 0, rDC = 0;
   signed short lsample, rsample;
   int readpos = 0;
#ifdef WORDS_BIGENDIAN
   char temp, *lsample_b1, *lsample_b2, *rsample_b1, *rsample_b2;

   lsample_b1 = (char *)&lsample;
   lsample_b2 = ((char *)&lsample) + 1;
   rsample_b1 = (char *)&rsample;
   rsample_b2 = ((char *)&rsample) + 1;
#endif
   
#ifdef TRM_DEBUG
    FILE *blah = fopen("/tmp/one.raw", "w+");
    fwrite(m_storeBuffer, m_numBytesWritten, sizeof(unsigned char), blah);
    fclose(blah);
#endif

   if (m_bits_per_sample == 16) {
       if (m_number_of_channels == 2) {
           while (readpos < (m_numBytesWritten / 2)) {
               lsample = ((signed short *)m_storeBuffer)[readpos];

#ifdef WORDS_BIGENDIAN
               temp = *lsample_b1;
               *lsample_b1 = *lsample_b2; 
               *lsample_b2 = temp;
               ((signed short *)m_storeBuffer)[readpos] = lsample;
#endif

               readpos++;

               rsample = ((signed short *)m_storeBuffer)[readpos];

#ifdef WORDS_BIGENDIAN
               temp = *rsample_b1;
               *rsample_b1 = *rsample_b2; 
               *rsample_b2 = temp;
               ((signed short *)m_storeBuffer)[readpos] = rsample;
#endif

               readpos++;

               lsum += lsample; 
               rsum += rsample;
               numsamps++;
           }
           lDC = -(lsum / numsamps);
           rDC = -(rsum / numsamps);

           readpos = 0;
           while (readpos < (m_numBytesWritten / 2)) {
               ((signed short *)m_storeBuffer)[readpos] = 
                   ((signed short *)m_storeBuffer)[readpos] + lDC;
               readpos++;
               ((signed short *)m_storeBuffer)[readpos] =
                   ((signed short *)m_storeBuffer)[readpos] + rDC;
               readpos++;
           }
       }
       else {
           while (readpos < m_numBytesWritten / 2) {
               lsample = ((signed short *)m_storeBuffer)[readpos];

#ifdef WORDS_BIGENDIAN
               temp = *lsample_b1;
               *lsample_b1 = *lsample_b2; 
               *lsample_b2 = temp;
               ((signed short *)m_storeBuffer)[readpos] = lsample;
#endif
               readpos++;

               lsum += lsample;
               numsamps++;
           }

           lDC = -(lsum / numsamps);
 
           readpos = 0;
           while (readpos < m_numBytesWritten / 2) {
               ((signed short *)m_storeBuffer)[readpos] =
                    ((signed short *)m_storeBuffer)[readpos] + lDC;
               readpos++;
           }
       }
    }
    else {
       if (m_number_of_channels == 2) {
           while (readpos < (m_numBytesWritten)) {
               lsample = ((char *)m_storeBuffer)[readpos++];
               rsample = ((char *)m_storeBuffer)[readpos++];

               lsum += lsample;
               rsum += rsample;
               numsamps++;
           }

           lDC = -(lsum / numsamps);
           rDC = -(rsum / numsamps);

           readpos = 0;
           while (readpos < (m_numBytesWritten)) {
               ((char *)m_storeBuffer)[readpos] =
                    ((char *)m_storeBuffer)[readpos] + lDC;
               readpos++;
               ((char *)m_storeBuffer)[readpos] =
                    ((char *)m_storeBuffer)[readpos] + rDC;
               readpos++;
           }
       }
       else {
           while (readpos < m_numBytesWritten) {
               lsample = ((char *)m_storeBuffer)[readpos++];

               lsum += lsample;
               numsamps++;
           }

           lDC = -(lsum / numsamps);

           readpos = 0;
           while (readpos < m_numBytesWritten) {
               ((char *)m_storeBuffer)[readpos] =
                    ((char *)m_storeBuffer)[readpos] + lDC;
               readpos++;
           }
       }
    }

#ifdef TRM_DEBUG
    blah = fopen("/tmp/two.raw", "w+");
    fwrite(m_storeBuffer, m_numBytesWritten, sizeof(unsigned char), blah);
    fclose(blah);
#endif

   if (!m_downmixBuffer)
       m_downmixBuffer = new signed short[iNumSamplesNeeded];

   m_downmix_size = m_numBytesWritten;

   if (m_samples_per_second != 11025)
       m_downmix_size = (int)((float)m_downmix_size * 
                            (11025.0 / (float)m_samples_per_second));

   if (m_bits_per_sample == 16)
       m_downmix_size /= 2;

   if (m_number_of_channels != 1)
       m_downmix_size /= 2;

   int maxwrite = m_downmix_size;
   int writepos = 0;
   float rate_change = m_samples_per_second / 11025.0;

   if (m_bits_per_sample == 8) {
       signed short *tempbuf = new signed short[m_numBytesWritten];
       readpos = 0;
       while (readpos < m_numBytesWritten) {
          long int samp = ((unsigned char *)m_storeBuffer)[readpos];

          samp = (samp - 128) * 256;

          if (samp >= SHRT_MAX)
              samp = SHRT_MAX;
          else if (samp <= SHRT_MIN)
              samp = SHRT_MIN;

          tempbuf[readpos] = samp;
          readpos++;
      }
 
      delete [] m_storeBuffer;
      m_numBytesWritten *= 2;
      m_storeBuffer = (char *)tempbuf;

      m_bits_per_sample = 16;
   }

   if (m_number_of_channels == 2) {
       signed short *tempbuf = new signed short[m_numBytesWritten / 4];
       readpos = 0;
       writepos = 0;
       while (writepos < m_numBytesWritten / 4) {
          long ls = ((signed short *)m_storeBuffer)[readpos++];
          long rs = ((signed short *)m_storeBuffer)[readpos++];

          tempbuf[writepos] = (ls + rs) / 2;
          writepos++;
      }

      delete [] m_storeBuffer;
      m_numBytesWritten /= 2;
      m_storeBuffer = (char *)tempbuf;
   }

#ifdef TRM_DEBUG
    blah = fopen("/tmp/three.raw", "w+");
    fwrite(m_storeBuffer, m_numBytesWritten, sizeof(unsigned char), blah);
    fclose(blah);
#endif

   writepos = 0;
   while ((writepos < maxwrite) &&
          (m_numSamplesWritten < iNumSamplesNeeded))
   {
       readpos = (int)((float)writepos * rate_change);
       
       long ls = ((signed short *)m_storeBuffer)[readpos++];

       m_downmixBuffer[m_numSamplesWritten] = ls;
       m_numSamplesWritten++;
       writepos++;
   }

   delete [] m_storeBuffer;
   m_storeBuffer = NULL;
}

int TRM::CountBeats(void)
{
    int i, j;
    float maxpeak = 0;
    float minimum = 99999;
    bool isbeat;
    int lastbeat = 0;

    for (i = 0; i < beatindex; i++)
        if (beatStore[i] < minimum)
            minimum = beatStore[i];

    for (i = 0; i < beatindex; i++)
        beatStore[i] -= minimum;

    for (i = 0; i < beatindex; i++)
        if (beatStore[i] > maxpeak)
            maxpeak = beatStore[i];

    int beats = 0;
    maxpeak *= (float)0.80;

    for (i = 3; i < (beatindex - 4); i++)
    {
        if (beatStore[i] > maxpeak)
        {
            if (i > lastbeat + 14)
            {
                isbeat = true;
                for  (j = i - 3; j < i; j++)
                    if (beatStore[j] > beatStore[i])
                       isbeat = false;
                for (j = i + 1; j < i + 4; j++)
                    if (beatStore[j] > beatStore[i])
                       isbeat = false;

                if (isbeat)
                {
                    beats++;
                    lastbeat = i;
                }
            }
        }
    }
    return beats;
}

int TRM::FinalizeSignature(string &strGUID, string &collID)
{
    if (m_numBytesWritten < 2)
    {
        strGUID = string(silenceTRM);
        return 0;
    }

    DownmixPCM();

#ifdef TRM_DEBUG
    FILE *blah = fopen("/tmp/test.raw", "w+");
    fwrite(m_downmixBuffer, m_numSamplesWritten, sizeof(unsigned char), blah);
    fclose(blah);
#endif

    signed short *sample = m_downmixBuffer;  
    bool bLastNeg = false;
    if(!sample)
	    return -1;

    if (*sample <= 0)
          bLastNeg = true;

    signed short *pCurrent = m_downmixBuffer;
    signed short *pBegin = pCurrent;
    int iFFTs = (m_numSamplesWritten / 32) - 2;
    int j, k, q;

    float fSpectrum[32];
    float fAvgFFTDelta[32];
    for (j = 0; j < 32; j++)
        fLastFFT[j] = fSpectrum[j] = fAvgFFTDelta[j] = 0;

    int iZeroCrossings = 0;
    llong sum = 0, sumsquared = 0;
    int iFinishedFFTs = 0;

    float *energys = new float[10];
    for (j = 0; j < 9; j++)
        energys[j] = 0.0;

    int energySub = 0;
    int energyCounter = 0;

    double mag = 0;
    double tempf = 0;
    float bandDelta = 0;
    float beatavg = 0;

    FFT *pFFT = new FFT(iFFTPoints, 11025);

    beatStore = new float[iFFTs + 2];
    beatindex = 0;

    float haar[iFFTPoints];
    for (k = 0; k < iFFTPoints; k++)
        haar[k] = 0;
    HaarWavelet *wavelet = new HaarWavelet(64, 6);

    for (j = 0; j < iFFTs; j++) 
    {
        for (k = 0; k < iFFTPoints; k++)
        {
            fftBuffer[k] = (pCurrent[k]);
            fftBuffer2[k] = (pCurrent[k + 32]);
        }

        wavelet->Transform(fftBuffer);
        for (k = 0; k < 64; k++)
        {
            haar[k] += (wavelet->GetCoef(k));
        }

        wavelet->Transform(fftBuffer2);
        for (k = 0; k < 64; k++)
        {
            haar[k] += (wavelet->GetCoef(k));
        }

        for (k = 0; k < iFFTPoints; k++)
        {
            fftBuffer[k] = pCurrent[k];
            fftBuffer2[k] = pCurrent[k + 32];
        }

        pFFT->CopyIn2(fftBuffer, fftBuffer2, iFFTPoints);
        pFFT->Transform();

        for (k = 0; k < 32; k++)
        {
            mag = pFFT->GetPower1(k);
            if (mag <= 0)
                freqs[k] = 0;
            else 
                freqs[k] = log10(mag / 4096) + 6;
            freqs[k] = freqs[k] * 6;
        }
       
        for (k = 0; k < 32; k++)
        {
            tempf = freqs[k];
            bandDelta = fabs(freqs[k] - fLastFFT[k]);
            if (k == 2)
            {
                beatavg = (tempf + freqs[k - 1]) * 5;
                beatStore[beatindex] = beatavg;
                beatindex++;
            }
            fSpectrum[k] += tempf;
            fAvgFFTDelta[k] += bandDelta;
            fLastFFT[k] = freqs[k];
        }

        j++;

        for (k = 0; k < 32; k++)
        {
            mag = pFFT->GetPower2(k);
            if (mag <= 0)
                freqs[k] = 0;
            else
                freqs[k] = log10(mag / 4096) + 6;
            freqs[k] = freqs[k] * 6;
        }

        for (k = 0; k < 32; k++)
        {
            tempf = freqs[k];
            bandDelta = fabs(freqs[k] - fLastFFT[k]);
            if (k == 2)
            {
                beatavg = (tempf + freqs[k - 1]) * 5;
                beatStore[beatindex] = beatavg;
                beatindex++;
            }
            fSpectrum[k] += tempf;
            fAvgFFTDelta[k] += bandDelta;
            fLastFFT[k] = freqs[k];
        }

        iFinishedFFTs += 2;

        while (pCurrent < pBegin + iFFTPoints)
        {
            signed short value = *pCurrent;
            double energy = (value * value);
            sum += abs(value);
            sumsquared += (long)energy;

            energys[energySub] += energy;
            energyCounter++;
            if (energyCounter >= 1000 * 32)
            {
                energys[energySub] = energys[energySub] / energyCounter;
                energyCounter = 0;
                energySub++;
            }   

            if (bLastNeg && (*pCurrent > 0))
            {
                bLastNeg = false;
                iZeroCrossings++;
            }
            else if (!bLastNeg && (*pCurrent <= 0))
                bLastNeg = true;
            pCurrent++;
        }
        pBegin = pCurrent;
    }

    if (energyCounter != 0 && energySub < 9)
        energys[energySub] = energys[energySub] / energyCounter;
    if (energySub >= 9)
        energySub = 8;

    FFT *fft1 = new FFT(512, 1);
    FFT *fft2 = new FFT(512, 1);
    double *dbuffer = new double[512];
    deque<double> f2buffer;
    int i, f1count = 0, f2count = 0;
   
    float f2Spec[32];
    for (i = 0; i < 32; i++)
        f2Spec[i] = 0;

    for (j = 0; j < m_numSamplesWritten;)
    {
        for (i = 0; i < 512; i++)
            dbuffer[i] = m_downmixBuffer[j];

        fft1->CopyIn(dbuffer, 512);
        fft1->Transform();
        f2buffer.push_back(fft1->GetLogPower(3));

        if (f2buffer.size() == 512)
            f1count++;

        if (f1count > 0 && (f1count % 44) == 0)
        {
            double avg = 0;
            for (i = 0; i < 512; i++)
               avg += (dbuffer[i] = f2buffer[i]);
            avg /= 512;
            for (i = 0; i < 512; i++)
               dbuffer[i] -= avg;
            fft2->CopyIn(dbuffer, 512);
            fft2->Transform();
            for (int i = 0; i < 32; i++)
                f2Spec[i] += fft2->GetLogPower(i);
	    f2count++;
        }

        if (f2buffer.size() == 512)
            f2buffer.pop_front();

        j += 64;
    }

    delete fft1;
    delete fft2;
    delete [] dbuffer;
   
    for (i = 0; i < 32; i++)
    {
        f2Spec[i] /= f2count;
    }

    float fLength = m_numSamplesWritten / (float)11025;
    float fAverageZeroCrossing = iZeroCrossings / fLength;

    float smallest = 9999;
    for (j = 0; j < 32; j++)
    {
        fSpectrum[j] = fSpectrum[j] / iFinishedFFTs;
        if ((j <= 28) && (fSpectrum[j] < smallest))
            smallest = fSpectrum[j];
    }

    for (j = 0; j < 32; j++)
    {
        fSpectrum[j] = fSpectrum[j] - smallest;
        if (fSpectrum[j] < 0)
            fSpectrum[j] = 0;
    }
	
    smallest = 9999;
    priority_queue<float, deque<float>, greater<float> > m_haarList;
    for (j = 0; j < 64; j++)
    {
        haar[j] = haar[j] / iFinishedFFTs;
        if (fabs(haar[j]) < smallest)
            smallest = fabs(haar[j]);
    }

    for (j = 0; j < 64; j++)
    {
        if (haar[j] > 0)
            haar[j] = haar[j] - smallest;
        else
            haar[j] = haar[j] + smallest;
        if (fabs(haar[j]) < 1)
            haar[j] = 0;
        else
            haar[j] = 20 * log10(fabs(haar[j]));
        m_haarList.push(haar[j]);
    }

    for (j = 0; j < 64; j++)
    {
        haar[j] = m_haarList.top();
        m_haarList.pop();
    }

    double RMS = sqrt((float)sumsquared / (float)m_numSamplesWritten);
    double avg = (float)sum / (float)m_numSamplesWritten;
    float msratio = avg / RMS;

    float specsum = 0;
    for (j = 0; j < 31; j++)
        specsum += fabs(fSpectrum[j + 1] - fSpectrum[j]);
    
    for (j = 0; j < 32; j++)
        fAvgFFTDelta[j] = fAvgFFTDelta[j] / (iFinishedFFTs - 1);

    int *energydiffs = new int[8];
    for (q = 0; q < 8; q++)
        energydiffs[q] = 0;

    for (q = 0; q < energySub; q++)
        energydiffs[q] = (int)(energys[q + 1] - energys[q]);

    float avgdiff = 0;
    int numsignchanges = 0;
    bool lastdiffneg = (energydiffs[0] < 0);

    for (q = 0; q < 8; q++)
    {
        avgdiff += energydiffs[q];
        if (lastdiffneg && energydiffs[q] > 0)
        {
            switch (q)
            {
                case 0:
                case 1:  numsignchanges |= (1 << 0); break;
                case 2:
                case 3:  numsignchanges |= (1 << 1); break;
                case 4:
                case 5:  numsignchanges |= (1 << 2); break;
                case 6:  numsignchanges |= (1 << 3); break;
                default: numsignchanges |= (1 << 4); break;
            }
            lastdiffneg = false;
        }
        else if (!lastdiffneg && energydiffs[q] <= 0)
        {
            lastdiffneg = true;
        }
    }
    avgdiff /= 8;

    int beats = CountBeats();
    float estBPM = beats;

    if (m_song_seconds == -1)
        m_song_seconds = (int)(ceil((m_song_samples * 1.0 / 
                                    m_number_of_channels) / 
                                    m_samples_per_second));

#ifdef TRM_DEBUG
    cout << fLength << " " << msratio << " " << fAverageZeroCrossing << " ";
    cout << estBPM << " " << avgdiff << " " << numsignchanges << " : ";
    for (j = 0; j < 32; j++)
        cout << fSpectrum[j] << " ";
    cout << ": ";
    for (j = 0; j < 32; j++)
        cout << fAvgFFTDelta[j] << " ";
    cout << ": " << specsum << " : ";
    for (j = 0; j < 64; j++)
        cout << haar[j] << " ";
    cout << endl;
#endif

    AudioSig *signature = new AudioSig(msratio, fAverageZeroCrossing,
                                       f2Spec, specsum, estBPM, 
                                       fAvgFFTDelta, haar, 
                                       avgdiff, numsignchanges, m_song_seconds);

    SigClient *sigClient = new SigClient();
    sigClient->SetAddress("trm.musicbrainz.org", 4447);
    sigClient->SetProxy(m_proxy, m_proxyPort);

    if (collID == "")
        collID = "EMPTY_COLLECTION";

    int ret = sigClient->GetSignature(signature, strGUID, collID);

    delete wavelet;
    delete pFFT;
    delete signature;
    delete sigClient;
    delete [] m_downmixBuffer;
    delete [] energys;
    delete [] energydiffs;
    delete [] beatStore;

    m_downmixBuffer = NULL;
    m_numSamplesWritten = 0;

    return ret;
}

void TRM::ConvertSigToASCII(char sig[17], char ascii_sig[37])
{
    uuid_ascii((unsigned char *)sig, ascii_sig);
}

