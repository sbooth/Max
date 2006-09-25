/*
 *  LAME MP3 encoder for DirectShow
 *  LAME encoder wrapper
 *
 *  Copyright (c) 2000-2005 Marie Orlova, Peter Gubanov, Vitaly Ivanov, Elecard Ltd.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 * Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public
 * License along with this library; if not, write to the
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 */

#include <streams.h>
#include "Encoder.h"


//////////////////////////////////////////////////////////////////////
// Construction/Destruction
//////////////////////////////////////////////////////////////////////
CEncoder::CEncoder() :
    m_bInpuTypeSet(FALSE),
    m_bOutpuTypeSet(FALSE),
    m_bFinished(FALSE),
    m_outOffset(0),
    m_outReadOffset(0),
    m_frameCount(0),
    pgf(NULL)
{
    m_outFrameBuf = new unsigned char[OUT_BUFFER_SIZE];
}

CEncoder::~CEncoder()
{
    Close();

    if (m_outFrameBuf)
        delete [] m_outFrameBuf;
}

//////////////////////////////////////////////////////////////////////
// SetInputType - check if given input type is supported
//////////////////////////////////////////////////////////////////////
HRESULT CEncoder::SetInputType(LPWAVEFORMATEX lpwfex, bool bJustCheck)
{
    CAutoLock l(&m_lock);

    if (lpwfex->wFormatTag == WAVE_FORMAT_PCM)
    {
        if (lpwfex->nChannels == 1 || lpwfex->nChannels == 2)
        {
            if (lpwfex->nSamplesPerSec  == 48000 ||
                lpwfex->nSamplesPerSec  == 44100 ||
                lpwfex->nSamplesPerSec  == 32000 ||
                lpwfex->nSamplesPerSec  == 24000 ||
                lpwfex->nSamplesPerSec  == 22050 ||
                lpwfex->nSamplesPerSec  == 16000 ||
                lpwfex->nSamplesPerSec  == 12000 ||
                lpwfex->nSamplesPerSec  == 11025 ||
                lpwfex->nSamplesPerSec  ==  8000)
            {
                if (lpwfex->wBitsPerSample == 16)
                {
                    if (!bJustCheck)
                    {
                        memcpy(&m_wfex, lpwfex, sizeof(WAVEFORMATEX));
                        m_bInpuTypeSet = true;
                    }

                    return S_OK;
                }
            }
        }
    }

    if (!bJustCheck)
        m_bInpuTypeSet = false;

    return E_INVALIDARG;
}

//////////////////////////////////////////////////////////////////////
// SetOutputType - try to initialize encoder with given output type
//////////////////////////////////////////////////////////////////////
HRESULT CEncoder::SetOutputType(MPEG_ENCODER_CONFIG &mabsi)
{
    CAutoLock l(&m_lock);

    m_mabsi = mabsi;
    m_bOutpuTypeSet = true;

    return S_OK;
}

//////////////////////////////////////////////////////////////////////
// SetDefaultOutputType - sets default MPEG audio properties according
// to input type
//////////////////////////////////////////////////////////////////////
HRESULT CEncoder::SetDefaultOutputType(LPWAVEFORMATEX lpwfex)
{
    CAutoLock l(&m_lock);

    if(lpwfex->nChannels == 1 || m_mabsi.bForceMono)
        m_mabsi.ChMode = MONO;

    if((lpwfex->nSamplesPerSec < m_mabsi.dwSampleRate) || (lpwfex->nSamplesPerSec % m_mabsi.dwSampleRate != 0))
        m_mabsi.dwSampleRate = lpwfex->nSamplesPerSec;

    return S_OK;
}

//////////////////////////////////////////////////////////////////////
// Init - initialized or reiniyialized encoder SDK with given input 
// and output settings
//////////////////////////////////////////////////////////////////////
HRESULT CEncoder::Init()
{
    CAutoLock l(&m_lock);

    m_outOffset     = 0;
    m_outReadOffset = 0;

    m_bFinished     = FALSE;

    m_frameCount    = 0;

    if (!pgf)
    {
        if (!m_bInpuTypeSet || !m_bOutpuTypeSet)
            return E_UNEXPECTED;

        // Init Lame library
        // note: newer, safer interface which doesn't 
        // allow or require direct access to 'gf' struct is being written
        // see the file 'API' included with LAME.
        if (pgf = lame_init())
        {
            pgf->num_channels = m_wfex.nChannels;

            pgf->in_samplerate = m_wfex.nSamplesPerSec;
            pgf->out_samplerate = m_mabsi.dwSampleRate;
            if ((pgf->out_samplerate >= 32000) && (m_mabsi.dwBitrate < 32))
                pgf->brate = 32;
            else
                pgf->brate = m_mabsi.dwBitrate;

            pgf->VBR = m_mabsi.vmVariable;
            pgf->VBR_min_bitrate_kbps = m_mabsi.dwVariableMin;
            pgf->VBR_max_bitrate_kbps = m_mabsi.dwVariableMax;

            pgf->copyright = m_mabsi.bCopyright;
            pgf->original = m_mabsi.bOriginal;
            pgf->error_protection = m_mabsi.bCRCProtect;

            pgf->bWriteVbrTag = m_mabsi.dwXingTag;
            pgf->strict_ISO = m_mabsi.dwStrictISO;
            pgf->VBR_hard_min = m_mabsi.dwEnforceVBRmin;

            if (pgf->num_channels == 2 && !m_mabsi.bForceMono)
            {
                int act_br = pgf->VBR ? pgf->VBR_min_bitrate_kbps + pgf->VBR_max_bitrate_kbps / 2 : pgf->brate;

                // Disabled. It's for user's consideration now
                //int rel = pgf->out_samplerate / (act_br + 1);
                //pgf->mode = rel < 200 ? m_mabsi.ChMode : JOINT_STEREO;

                pgf->mode = m_mabsi.ChMode;
            }
            else
                pgf->mode = MONO;

            if (pgf->mode == JOINT_STEREO)
                pgf->force_ms = m_mabsi.dwForceMS;
            else
                pgf->force_ms = 0;

            pgf->mode_fixed = m_mabsi.dwModeFixed;

            if (m_mabsi.dwVoiceMode != 0)
            {
                pgf->lowpassfreq = 12000;
                pgf->VBR_max_bitrate_kbps = 160;
            }

            if (m_mabsi.dwKeepAllFreq != 0)
            {
                pgf->lowpassfreq = -1;
                pgf->highpassfreq = -1;
            }

            pgf->quality = m_mabsi.dwQuality;
            pgf->VBR_q = m_mabsi.dwVBRq;

            lame_init_params(pgf);

            // encoder delay compensation
            {
                short * start_padd = (short *)calloc(48, pgf->num_channels * sizeof(short));

                if (pgf->num_channels == 2)
                    lame_encode_buffer_interleaved(pgf, start_padd, 48, m_outFrameBuf, OUT_BUFFER_SIZE);
                else
                    lame_encode_buffer(pgf, start_padd, start_padd, 48, m_outFrameBuf, OUT_BUFFER_SIZE);

                free(start_padd);
            }

            return S_OK;
        }

        return E_FAIL;
    }

    return S_OK;
}

//////////////////////////////////////////////////////////////////////
// Close - closes encoder
//////////////////////////////////////////////////////////////////////
HRESULT CEncoder::Close()
{
    CAutoLock l(&m_lock);

    if (pgf)
    {
        lame_close(pgf);
        pgf = NULL;
    }

    return S_OK;
}

//////////////////////////////////////////////////////////////////////
// Encode - encodes data placed on pdata and returns
// the number of processed bytes
//////////////////////////////////////////////////////////////////////
int CEncoder::Encode(const short * pdata, int data_size)
{
    CAutoLock l(&m_lock);

    if (!pgf || !m_outFrameBuf || !pdata || data_size < 0 || (data_size & (sizeof(short) - 1)))
        return -1;

    // some data left in the buffer, shift to start
    if (m_outReadOffset > 0)
    {
        if (m_outOffset > m_outReadOffset)
            memmove(m_outFrameBuf, m_outFrameBuf + m_outReadOffset, m_outOffset - m_outReadOffset);

        m_outOffset -= m_outReadOffset;
    }

    m_outReadOffset = 0;



    m_bFinished = FALSE;

    int bytes_processed = 0;

    while (1)
    {
        int nsamples = (data_size - bytes_processed) / (sizeof(short) * pgf->num_channels);

        if (nsamples <= 0)
            break;

        if (nsamples > 1152)
            nsamples = 1152;

        if (m_outOffset >= OUT_BUFFER_MAX)
            break;

        int out_bytes = 0;

        if (pgf->num_channels == 2)
            out_bytes = lame_encode_buffer_interleaved(
                                            pgf,
                                            (short *)(pdata + (bytes_processed / sizeof(short))),
                                            nsamples,
                                            m_outFrameBuf + m_outOffset,
                                            OUT_BUFFER_SIZE - m_outOffset);
        else
            out_bytes = lame_encode_buffer(
                                            pgf,
                                            pdata + (bytes_processed / sizeof(short)),
                                            pdata + (bytes_processed / sizeof(short)),
                                            nsamples,
                                            m_outFrameBuf + m_outOffset,
                                            OUT_BUFFER_SIZE - m_outOffset);

        if (out_bytes < 0)
            return -1;

        m_outOffset     += out_bytes;
        bytes_processed += nsamples * pgf->num_channels * sizeof(short);
    }

    return bytes_processed;
}

//
// Finsh - flush the buffered samples
//
HRESULT CEncoder::Finish()
{
    CAutoLock l(&m_lock);

    if (!pgf || !m_outFrameBuf || (m_outOffset >= OUT_BUFFER_MAX))
        return E_FAIL;

    m_outOffset += lame_encode_flush(pgf, m_outFrameBuf + m_outOffset, OUT_BUFFER_SIZE - m_outOffset);

    m_bFinished = TRUE;

    return S_OK;
}


int getFrameLength(const unsigned char * pdata)
{
    if (!pdata || pdata[0] != 0xff || (pdata[1] & 0xe0) != 0xe0)
        return -1;

    const int sample_rate_tab[4][4] =
    {
        {11025,12000,8000,1},
        {1,1,1,1},
        {22050,24000,16000,1},
        {44100,48000,32000,1}
    };

#define MPEG_VERSION_RESERVED   1
#define MPEG_VERSION_1          3

#define LAYER_III               1

#define BITRATE_FREE            0
#define BITRATE_RESERVED        15

#define SRATE_RESERVED          3

#define EMPHASIS_RESERVED       2

    int version_id      = (pdata[1] & 0x18) >> 3;
    int layer           = (pdata[1] & 0x06) >> 1;
    int bitrate_id      = (pdata[2] & 0xF0) >> 4;
    int sample_rate_id  = (pdata[2] & 0x0C) >> 2;
    int padding         = (pdata[2] & 0x02) >> 1;
    int emphasis        =  pdata[3] & 0x03;

    if (version_id      != MPEG_VERSION_RESERVED &&
        layer           == LAYER_III &&
        bitrate_id      != BITRATE_FREE &&
        bitrate_id      != BITRATE_RESERVED &&
        sample_rate_id  != SRATE_RESERVED &&
        emphasis        != EMPHASIS_RESERVED)
    {
        int spf         = (version_id == MPEG_VERSION_1) ? 1152 : 576;
        int sample_rate = sample_rate_tab[version_id][sample_rate_id];
        int bitrate     = dwBitRateValue[version_id != MPEG_VERSION_1][bitrate_id - 1] * 1000;

        return (bitrate * spf) / (8 * sample_rate) + padding;
    }

    return -1;
}


int CEncoder::GetFrame(const unsigned char ** pframe)
{
    if (!pgf || !m_outFrameBuf || !pframe)
        return -1;

    while ((m_outOffset - m_outReadOffset) > 4)
    {
        int frame_length = getFrameLength(m_outFrameBuf + m_outReadOffset);

        if (frame_length < 0)
        {
            m_outReadOffset++;
        }
        else if (frame_length <= (m_outOffset - m_outReadOffset))
        {
            *pframe = m_outFrameBuf + m_outReadOffset;
            m_outReadOffset += frame_length;

            m_frameCount++;

            // don't deliver the first and the last frames
            if (m_frameCount != 1 && !(m_bFinished && (m_outOffset - m_outReadOffset) < 5))
                return frame_length;
        }
        else
            break;
    }

    return 0;
}





















