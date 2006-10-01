/*___________________________________________________________________________

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

  $Id: sigxdr.cpp 542 2002-10-08 20:37:13Z robert $
____________________________________________________________________________*/

#ifdef WIN32
#include "config_win32.h"
#else
#include "config.h"
#endif

#include "sigxdr.h"

#ifdef WIN32
#include <winsock.h>
#else
#undef socklen_t
#include <sys/types.h>
#include <netinet/in.h>
#endif

SigXDR::SigXDR(void)
{
    m_buffer = m_position = NULL;
    m_size = 0;
}

SigXDR::~SigXDR(void)
{
}

char *SigXDR::FromSig(AudioSig *sig)
{
    m_size = NUMSIGFIELDS * FIELDSIZE;
    m_buffer = new char[m_size];
    m_position = m_buffer;

    float temp;
    int32 tempi, i;

    temp = sig->MeanSquare();
    PutFloat(&temp);

    temp = sig->ZXing();
    PutFloat(&temp);

    for (i = 0; i < 32; i++)  
        PutFloat(&sig->Spectrum()[i]);

    temp = sig->SpectralSum();
    PutFloat(&temp);

    temp = sig->Beats();
    PutFloat(&temp);

    for (i = 0; i < 32; i++)
        PutFloat(&sig->AvgFFTDelta()[i]);

    for (i = 0; i < 64; i++)
        PutFloat(&sig->Haar()[i]);

    temp = sig->EnergyDiff();
    PutFloat(&temp);

    tempi = sig->EnergyZC();
    PutInt32(&tempi);

    temp = sig->Seconds();
    PutFloat(&temp);

    return m_buffer;
}

string SigXDR::ToStrGUID(char *buffer, long size)
{
    string ret;

    m_size = 16 * FIELDSIZE;
    if (size != m_size)
        return ret;
 
    int c = 0; 
    char uid[16];
 
    m_position = m_buffer = buffer;
    for (int i = 0; i < 16; i++) 
    {
        GetInt32((int32 *)&c);
        uid[i] = (char)c;
    }

    ret = string(uid, 16);
    return ret;
}

void SigXDR::PutInt32(int32 *data)
{
    if ((m_size -= 4) < 0)
        return;
 
    *(int32 *)m_position = htonl(*data);
    m_position += 4;
}

void SigXDR::GetInt32(int32 *data)
{
    if ((m_size -= 4) < 0)
        return;
   
    *data = (int32)ntohl((*((int32 *)(m_position))));
    m_position += 4;
}

void SigXDR::PutFloat(float *data)
{
    if (sizeof(float) == sizeof(int32))
        PutInt32((int32 *)data);
    else if (sizeof(float) == sizeof(int)) {
        int32 tmp = *(int *)data;
        PutInt32(&tmp);
    }
}

void SigXDR::GetFloat(float *data)
{
    if (sizeof(float) == sizeof(int32))
        GetInt32((int32 *)data);
    else if (sizeof(float) == sizeof(int)) {
        int32 tmp;
        GetInt32(&tmp);
        *(int *)data = tmp;
    }
}

