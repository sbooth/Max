/***************************************************************************
                          MBCOMHTTPSocket.cpp  -  description
                             -------------------
    begin                : Sat Sep 29 2000
    copyright            : (C) 2000 by Relatable 
    written by           : Sean Ward
    email                : sward@relatable.com
 ***************************************************************************/
#ifdef WIN32
#pragma warning(disable:4786)
#endif

#include "comhttpsocket.h"
#ifdef WIN32
#include "../config_win32.h"
#include "wincomsocket.h"
#else
#include "../config.h"
#include "comsocket.h"
#endif
#include <stdlib.h>
#include <assert.h>

const char* g_strCOMVer = "libmusicbrainz/"VERSION;

MBCOMHTTPSocket::MBCOMHTTPSocket()
{
	m_pSock = new MBCOMSocket;
	m_pTempBuf = NULL;
	m_nBufLen = 0;
	memset(m_hostname, 0x00, 65);
	memset(m_proxyname, 0x00, 1025);
	m_pFile = NULL;
}
MBCOMHTTPSocket::~MBCOMHTTPSocket()
{
	if (m_pSock->IsConnected()) m_pSock->Disconnect();
	delete m_pSock;
	if (m_pTempBuf != NULL) delete [] m_pTempBuf;
}

/** Connects a socket to pIP, on nPort, of type nType. */
int MBCOMHTTPSocket::Connect(const char* pURL)
{
	assert(pURL != NULL);
	if (this->IsConnected()) this->Disconnect();
	if (m_pTempBuf != NULL)
	{
		delete [] m_pTempBuf;
		m_pTempBuf = NULL;
		m_nBufLen = 0;
	}
	// if its not an http:// based url, this can't deal with it
//	if (strncasecmp(pURL, "http://", 7)) return -1;
	if (strncmp(pURL, "http://", 7)) return -1;
	m_strURL = pURL;

	int nRes = 0;
	memset(m_hostname, 0x00, 65);
    	memset(m_proxyname, 0x00, 1025);
    	m_pFile = NULL;
	unsigned short nPort = 80;
	int nNumFields = 0;
	
	if (!m_strProxyAddr.empty())
	{
		nNumFields = sscanf(m_strProxyAddr.c_str(), 
				"http://%[^:/]:%hu", m_hostname, &nPort);
		strcpy(m_proxyname, pURL);
		
		m_pFile = m_proxyname;
	}
	else
	{
		nNumFields = sscanf(m_strURL.c_str(), 
				"http://%[^:/]:%hu", m_hostname, &nPort);
		
		m_pFile = strchr(m_strURL.c_str() + 7, '/');
	}
	
	if (nNumFields < 1)
	{
		return -1; // screwed url
	}
	if (nNumFields < 2)
	{
		nPort = 80;
	}
	
	nRes = m_pSock->Connect((const char*)m_hostname, nPort, SOCK_STREAM);
	return nRes;	
}

/** Disconnects the current socket */
int MBCOMHTTPSocket::Disconnect()
{
	return m_pSock->Disconnect();
}

/** Checks if there is a current open connection */
bool MBCOMHTTPSocket::IsConnected()
{
	return m_pSock->IsConnected();
}

/** Writes to a socket, from buffer pBuffer, up to nLen bytes, and returns the number of written bytes in pnBytesWritten. */
int MBCOMHTTPSocket::Write(const char* pBuffer, size_t nLen, size_t* pnBytesWritten)
{
	if (!m_pSock->IsConnected()) return -1; // no connection
	const char* pRequest = "POST %s HTTP/1.0\r\n"
                                "Host: %s\r\n"
                                "Accept: */*\r\n"
                                "User-Agent: %s\r\n"
                                "Content-type: application/octet-stream\r\n"
                                "Content-length: %d\r\n";
	
	size_t nReqLen = strlen(pRequest) + strlen(m_pFile)
			+ strlen(m_hostname)
			+ strlen(g_strCOMVer)
			+ nLen + 2;
	char* pReq = new char[nReqLen];
        memset(pReq, 0, nReqLen);
	assert(pReq != NULL);
	
	sprintf(pReq, pRequest, m_pFile, m_hostname, g_strCOMVer, nLen);
	
	strcat(pReq, "\r\n");
	
	memcpy(pReq + strlen(pReq), pBuffer, nLen);
	size_t nBytes = 0;
	int nRes = m_pSock->Write(pReq, nReqLen, &nBytes);
	delete [] pReq;
	
	if ((nRes == 0) && (nBytes == nReqLen))
	{
		*pnBytesWritten = nLen;
	}
	else
	{
		*pnBytesWritten = 0; // something weird happened
	}
	return nRes;
}

/** Reads in a non blocking fashion (ie, selects and polls) for nTimeout seconds */
int MBCOMHTTPSocket::NBRead(char* pBuffer, size_t nLen, size_t* nBytesWritten, int nTimeout)
{
	if (!m_pSock->IsConnected()) return -1; // no connection
	
	char HeaderBuffer[1024];	// read up to 1024 bytes for the header
	memset(HeaderBuffer, 0x00, 1024);
	size_t nBytes = 0;
	size_t nTotal = 0;
	
	int nRes = m_pSock->NBRead(HeaderBuffer, 1023, &nBytes, nTimeout);
	if (nRes != 0) return -1;	// error reading from socket. server crash?
	
	nTotal = nBytes;
	if (!IsHTTPHeaderComplete(HeaderBuffer, nTotal))
	{
		if (nTotal == 1023) 
		{	// the header is larger than the header buffer. TODO: deal with this case 
			return -1;
		}
		// get more data since there isn't a complete header yet
		while (!IsHTTPHeaderComplete(HeaderBuffer, nTotal) && (nTotal <= 1023) && (nRes == 0))
		{
			nRes = m_pSock->NBRead(HeaderBuffer + nTotal, 1023 - nTotal, &nBytes, nTimeout);
			nTotal += nBytes;
		}
		
		if ((nRes != 0) || (!IsHTTPHeaderComplete(HeaderBuffer, nTotal))) // socket error or bad header
		{
			return -1;
		}
	}

        // Check to see if the sigserver is happy/busy
        char *ptr = strchr(HeaderBuffer, ' ');
        if (ptr)
        {
             int status;

             ptr++;
             status = atoi(ptr);
             if (status == 503)
                 return -2;
             if (status != 200)
                 return -1;
        }
        else
             return -1;
	
	// advance to the data now, if there is any in this first buffer. 
	char* pData = strstr(HeaderBuffer, "\r\n\r\n");
	if (pData) pData += 4;
	size_t nOffset = pData - HeaderBuffer;
	if (nTotal - nOffset >= nLen) // case 1: entire requested read is in header chunk
	{
		memcpy(pBuffer, pData, nLen);
		*nBytesWritten = nLen;
		
		// case 1: b. if excess data, store for the next read.
		if (nTotal > (nOffset + nLen))
		{
			m_nBufLen = nTotal - (nOffset + nLen);
			m_pTempBuf = new char[m_nBufLen]; // could clobber if non null already
			memcpy(m_pTempBuf, pData + nLen, m_nBufLen);
		}
		return 0;
	}
	else
	{	// case 2: entire requested read is NOT in header chunk
		memcpy(pBuffer, pData, nTotal - nOffset);
		nOffset = nTotal - nOffset;

		// only try one attempt to finish the read request
		nRes = m_pSock->NBRead(pBuffer + nOffset, nLen - nOffset, &nBytes, nTimeout);
		if (nRes != 0) return -1;	// socket error
		
		*nBytesWritten = nBytes + nOffset;
		return 0;
	}
}

/** Reads from a socket, into pbuffer, up to a max of nLen byte, and writes how many were actually written to nBytesWritten. */
int MBCOMHTTPSocket::Read(char* pBuffer, size_t nLen, size_t* nBytesWritten)
{
	if (!m_pSock->IsConnected()) return -1; // no connection
	size_t nOffset = 0;
	int nRes = 0;

	if (m_pTempBuf != NULL) // case 1: leftover bits from header stripping
	{
		if (m_nBufLen >= nLen)	// easy case: just copy from bit bucket and reduce its size
		{
			memcpy(pBuffer, m_pTempBuf, nLen);
			*nBytesWritten = nLen;
			if (nLen < m_nBufLen) // shift the bit bucket
			{
				memmove(m_pTempBuf, m_pTempBuf + nLen, m_nBufLen - nLen);
				m_nBufLen -= nLen;
			}
			else
			{
				delete [] m_pTempBuf;
				m_pTempBuf = NULL;
				m_nBufLen = 0;
			}
			return 0;	// success from bit bucket
		}
		else // bit bucket doesn't store it all
		{
			memcpy(pBuffer, m_pTempBuf, m_nBufLen);
			nOffset = m_nBufLen;
			*nBytesWritten = nOffset;
			
			delete [] m_pTempBuf;
			m_pTempBuf = NULL;
			m_nBufLen = 0;
		}
	}
	
	// general case: more bits are needed
	nRes = m_pSock->Read(pBuffer + nOffset, nLen - nOffset, nBytesWritten);
	*nBytesWritten += nOffset;
	
	return nRes;
}
 
/** Sets the proxy address. Use NULL to disable. */
int MBCOMHTTPSocket::SetProxy(const char* pURL)
{
	if (pURL == NULL) m_strProxyAddr = ""; // empty string
	else
	m_strProxyAddr = pURL;
	return 0;
}


bool MBCOMHTTPSocket::IsHTTPHeaderComplete(char* buffer, unsigned int length)
{
    bool result = false;

    for(char* cp = buffer; cp < buffer + length; cp++)
    {
        if(!strncmp(cp, "\n\n", 2) || !strncmp(cp, "\r\n\r\n", 4))
        {
            result = true;
            break;
        }
    }

    return result;
}

