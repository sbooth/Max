/*____________________________________________________________________________

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

  $Id: sigfft.cpp 532 2002-09-19 17:31:53Z robert $
____________________________________________________________________________*/

//------------------------------------
//  fft.cpp
//  The implementation of the 
//  Fast Fourier Transform algorithm
//  modified by Sean Ward 2000
//  portions (c) Reliable Software, 1996 
//------------------------------------
#include "sigfft.h"
#include <string.h>

// log (1) = 0, log(2) = 1, log(3) = 2, log(4) = 2 ...
#ifdef PI
#undef PI
#endif
#define PI (2.0 * asin(1.0))

// Points must be a power of 2

FFT::FFT (int Points, long sampleRate)
: _Points (Points), _sampleRate (sampleRate)
{
    _aTape = new double [_Points];
#if 0
    // 1 kHz calibration wave
    for (int i = 0; i < _Points; i++)
        _aTape[i] = 1600 * sin (2 * PI * 1000. * i / _sampleRate);
#else
    int i = 0;
    for (i = 0; i < _Points; i++)
        _aTape[i] = 0;
#endif
    _sqrtPoints = sqrt((double)_Points);
    // calculate binary log
    _logPoints = 0;
    Points--;
    while (Points != 0)
    {
        Points >>= 1;
        _logPoints++;
    }

    _aBitRev = new int [_Points];
    _Bleh = new Complex[_Points];
    _W = new Complex* [_logPoints+1];
    // Precompute complex exponentials
    int _2_l = 2;
    for (int l = 1; l <= _logPoints; l++)
    {
        _W[l] = new Complex [_Points];

        for ( int i = 0; i < _Points; i++ )
        {
            double re =  cos (2. * PI * i / _2_l);
            double im = -sin (2. * PI * i / _2_l);
            _W[l][i] = Complex (re, im);
        }
        _2_l *= 2;
    }

    // set up bit reverse mapping
    int rev = 0;
    int halfPoints = _Points/2;
    for (i = 0; i < _Points - 1; i++)
    {
        _aBitRev[i] = rev;
        int mask = halfPoints;
        // add 1 backwards
        while (rev >= mask)
        {
            rev -= mask; // turn off this bit
            mask >>= 1;
        }
        rev += mask;
    }
    _aBitRev [_Points-1] = _Points-1;
    _winFac = new double[_Points];
    SetWindowFunc();
}

FFT::~FFT()
{
    delete []_aTape;
    delete []_aBitRev;
    for (int l = 1; l <= _logPoints; l++)
    {
        delete []_W[l];
    }
    delete []_W;
    delete []_Bleh;
    delete []_winFac;
}

//void Fft::CopyIn (SampleIter& iter)
void FFT::CopyIn(double* pBuffer, int nNumSamples)
{
    if (nNumSamples > _Points)
        return;

    // make space for cSample samples at the end of tape
    // shifting previous samples towards the beginning
    memmove (_aTape, &_aTape[nNumSamples], 
              (_Points - nNumSamples) * sizeof(double));
    // copy samples from iterator to tail end of tape
    int iTail  = _Points - nNumSamples;
    int i = 0;
    for (i = 0; i < nNumSamples; i++)
    {
        _aTape [i + iTail] = pBuffer[i];
    }
    // Initialize the FFT buffer
    for (i = 0; i < _Points; i++)
        PutAt (i, _aTape[i]);
}

void FFT::CopyIn2(double* pBuf, double* pBuf2, int nNumSamples)
{
    if (nNumSamples > _Points)
        return;

    int i = 0;

    // Initialize the FFT buffer
    for (i = 0; i < _Points; i++)
        PutAt2 (i, pBuf[i], pBuf2[i]);
}

//
//               0   1   2   3   4   5   6   7
//  level   1
//  step    1                                     0
//  increm  2                                   W 
//  j = 0        <--->   <--->   <--->   <--->   1
//  level   2
//  step    2
//  increm  4                                     0
//  j = 0        <------->       <------->      W      1
//  j = 1            <------->       <------->   2   W
//  level   3                                         2
//  step    4
//  increm  8                                     0
//  j = 0        <--------------->              W      1
//  j = 1            <--------------->           3   W      2
//  j = 2                <--------------->            3   W      3
//  j = 3                    <--------------->             3   W
//                                                              3
//

void FFT::Transform ()
{
    // step = 2 ^ (level-1)
    // increm = 2 ^ level;
    int step = 1;
    for (int level = 1; level <= _logPoints; level++)
    {
        int increm = step * 2;
        for (int j = 0; j < step; j++)
        {
            // U = exp ( - 2 PI j / 2 ^ level )
            Complex U = _W [level][j];
            for (int i = j; i < _Points; i += increm)
            {
                // butterfly
                Complex T = U;
                T *= _Bleh[i+step];
                _Bleh[i+step] = _Bleh[i];
                _Bleh[i+step] -= T;
                _Bleh[i] += T;
            }
        }
        step *= 2;
    }
}

