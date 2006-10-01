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

  $Id: sigclient.cpp 7521 2006-05-11 18:46:54Z luks $
____________________________________________________________________________*/

/***************************************************************************
sigclient.cpp  -  description
-------------------
copyright            : (C) 2000 by Relatable 
written by           : Isaac Richards
email                : ijr@relatable.com
***************************************************************************/

#ifdef WIN32
#pragma warning(disable:4786)
#endif

#include "sigclient.h"
#include "comhttpsocket.h"

#include "sigxdr.h"

char tooShortTRM[] = { 0xf9, 0x80, 0x9a, 0xb1, 0x2b, 0x0f, 0x4d, 0x78, 
                       0x88, 0x62, 0xfb, 0x42, 0x5a, 0xde, 0x8a, 0xb9 };
char sigserverBusyTRM[] = { 0xc4, 0x57, 0xa4, 0xa8, 0xb3, 0x42, 0x4e, 0xc9, 
                            0x8f, 0x13, 0xb6, 0xbd, 0x26, 0xc0, 0xe4, 0x00 };

namespace SigClientVars
{
    static const char cGetGUID = 'N';
    static const char cDisconnect = 'E';

    static const int nGUIDSize = 16;
    static const int nTimeout = 15;
    static const int nVersion = 3;
    static const int nHeaderSize = sizeof(char) + sizeof(int);
}

using namespace std;

SigClient::SigClient()
{
    m_pSocket = new MBCOMHTTPSocket;
    m_nNumFailures = 0;
}

SigClient::~SigClient()
{
    if (m_pSocket->IsConnected()) 
        this->Disconnect();
    if (m_pSocket != NULL) 
        delete m_pSocket;
}

#define REVERSE_LONG_BYTE_ORDER(a_long)  ((a_long & 0xFF000000) >> 24) + ((a_long & 0x00FF0000) >>  8) + ((a_long & 0x0000FF00) << 8) + ((a_long & 0x000000FF) << 24)

int SigClient::GetSignature(AudioSig *sig, string &strGUID, 
                            string strCollectionID)
{
    int nConRes = this->Connect(m_strIP, m_nPort);
    if (nConRes != 0) 
        return -1;

    SigXDR converter;

    size_t nOffSet = sizeof(char) + sizeof(int);
    int nGUIDLen = strCollectionID.size() * sizeof(char) + sizeof(char);
    int iSigEncodeSize = sizeof(int) + NUMSIGFIELDS * sizeof(int32) + nGUIDLen;
    int nTotalSize = nOffSet + iSigEncodeSize;

    char* pBuffer = new char[nTotalSize + 1];
    char* pBlank = new char[nTotalSize + 1];
    memset(pBuffer, 0, nTotalSize);
    memcpy(&pBuffer[0], &SigClientVars::cGetGUID, sizeof(char));
#ifdef WORDS_BIGENDIAN
    int temp = REVERSE_LONG_BYTE_ORDER(iSigEncodeSize);
    memcpy(&pBuffer[1], &temp, sizeof(int));
    temp = REVERSE_LONG_BYTE_ORDER(SigClientVars::nVersion);
    memcpy(&pBuffer[nOffSet], &temp, sizeof(int));
#else
    memcpy(&pBuffer[1], &iSigEncodeSize, sizeof(int));
    memcpy(&pBuffer[nOffSet], &SigClientVars::nVersion, sizeof(int));
#endif

    nOffSet += sizeof(int);

    iSigEncodeSize -= (nGUIDLen + sizeof(int));

    char *sigencode = converter.FromSig(sig);
    memcpy(&pBuffer[nOffSet], sigencode, iSigEncodeSize);

    memcpy(&pBuffer[nOffSet + iSigEncodeSize], strCollectionID.c_str(),
           nGUIDLen - sizeof(char));
    pBuffer[nOffSet + iSigEncodeSize + nGUIDLen - sizeof(char)] = '\0';

    size_t nBytes = 0;
    int ret = m_pSocket->Write(pBuffer, nTotalSize, &nBytes);

    memset(pBuffer, 0, nTotalSize);
    memset(pBlank, 0, nTotalSize);
    size_t iGUIDSize = 16 * sizeof(int32);

    ret = m_pSocket->NBRead(pBuffer, iGUIDSize, &nBytes, 
                            SigClientVars::nTimeout);

   
    // If NBRead returned -2 then sigserver is busy
    if (ret == -2)
    {
        ret = 0;
        strGUID = sigserverBusyTRM;
    }
    else
    if ((ret != -1) && (nBytes == iGUIDSize)) {
        ret = 0;
        if (memcmp(pBuffer, pBlank, nBytes))
            strGUID = converter.ToStrGUID(pBuffer, nBytes);
        else
            strGUID = tooShortTRM;

        if (strGUID == "") 
        {
            printf("Your MusicBrainz client library is too old to talk to\n"
                   "the signature server.  Please go to www.musicbrainz.org\n"
                   "and upgrade to the latest version, or upgrade whatever\n"
                   "software package your are currently using.\n");
	}
    }
    else 
    {
        ret = -1;
        strGUID = "";
    }
    this->Disconnect();

    delete [] pBuffer;
    delete [] pBlank;
    delete [] sigencode;

    return ret;
}

int SigClient::Connect(string& strIP, int nPort)
{
    if (m_nNumFailures > 5) 
        return -1;  // server probably down.

    if (m_proxyAddr.empty())
    {
        m_pSocket->SetProxy(NULL);
    }
    else {
        char *proxyurl = new char[m_proxyAddr.size() + 128];
        sprintf(proxyurl, "http://%s:%d", m_proxyAddr.c_str(), m_proxyPort);
        m_pSocket->SetProxy(proxyurl);

        delete [] proxyurl;
    }
        
    char *url = new char[strIP.size() + 128]; // ample space..
    sprintf(url, "http://%s/cgi-bin/gateway/gateway?%d", strIP.c_str(), nPort);
    int nErr = m_pSocket->Connect(url);

    delete [] url;

    if (nErr == -1)
    {
        m_nNumFailures++;
        return -1;
    }
    m_nNumFailures = 0;
    return 0;
}

int SigClient::Disconnect()
{
    m_pSocket->Disconnect();	
	
    return 0;
}
