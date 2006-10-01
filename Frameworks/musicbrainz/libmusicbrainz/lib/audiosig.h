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

   $Id: audiosig.h 542 2002-10-08 20:37:13Z robert $

----------------------------------------------------------------------------*/
#ifndef AUDIOSIG_H
#define AUDIOSIG_H

#define NUMSIGFIELDS 135

class AudioSig
{
public:
    AudioSig(float meansquareratio, float zxing, float *spectrum,
             float spectraldiffsum, float beatimpulses, float *avgfftdelta,
	     float *haar, float energydiff, int energyzc, long seconds) 
    { m_fMeanSquare = meansquareratio; m_fZXing = zxing; 
      for (int i = 0; i < 32; i++) 
      {
          m_fSpectrum[i] = spectrum[i]; 
          m_fAvgFFTDelta[i] = avgfftdelta[i];
      }
      for (int j = 0; j < 64; j++)
      {
          m_fHaar[j] = haar[j];
      }
      m_fEnergyDiff = energydiff; m_iEnergyZC = energyzc;
      m_fSpectralSum = spectraldiffsum, m_fBeats = beatimpulses;
      m_song_seconds = seconds;
    }
   ~AudioSig() {}

    float  MeanSquare()  { return m_fMeanSquare; }
    float  ZXing()       { return m_fZXing; }
    float *Spectrum()    { return m_fSpectrum; }
    float  SpectralSum() { return m_fSpectralSum; }
    float  Beats()       { return m_fBeats; }
    float *AvgFFTDelta() { return m_fAvgFFTDelta; }
    float *Haar()        { return m_fHaar; }
    float  EnergyDiff()  { return m_fEnergyDiff; }
    short  EnergyZC()    { return m_iEnergyZC; }
    long   Seconds()     { return m_song_seconds; }    

private:
    float m_fMeanSquare;
    float m_fZXing;
    float m_fSpectrum[32];
    float m_fSpectralSum;
    float m_fBeats;
    float m_fAvgFFTDelta[32];
    float m_fHaar[64];
    float m_fEnergyDiff;
    int   m_iEnergyZC;
    long  m_song_seconds;
};

#endif /* AUDIOSIG_H */
