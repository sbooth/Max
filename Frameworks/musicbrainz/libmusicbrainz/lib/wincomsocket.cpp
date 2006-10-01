/*__________________________________________________________________________

        FreeAmp - The Free MP3 Player

        Portions Copyright (C) 2000 Relatable

        This program is free software; you can redistribute it and/or modify
        it under the terms of the GNU General Public License as published by
        the Free Software Foundation; either version 2 of the License, or
        (at your option) any later version.

        This program is distributed in the hope that it will be useful,
        but WITHOUT ANY WARRANTY; without even the implied warranty of
        MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
        GNU General Public License for more details.

        You should have received a copy of the GNU General Public License
        along with this program; if not, Write to the Free Software
        Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
        
        $Id: wincomsocket.cpp 7522 2006-05-11 19:02:35Z luks $
____________________________________________________________________________*/

#include "wincomsocket.h"

#if !defined(WIN32) && !defined(__BEOS__)
#define closesocket(s) close(s)
#endif

MBCOMSocket::MBCOMSocket(int nSocket, int nSockType)
{
    m_nSocket = nSocket;
    m_bConnected = true;
    if (m_nSocket != INVALID_SOCKET) 
        m_bConnected = true;
    m_nSockType = nSockType;
}

MBCOMSocket::~MBCOMSocket()
{
    if (IsConnected()) Disconnect();
}

/** Connects a socket to pIP, on nPort, of type nType. */
int MBCOMSocket::Connect(const char* pIP, int nPort, int nType, bool bBroadcast)
{
    if (IsConnected()) 
        Disconnect();

    sockaddr_in  addr;
    hostent     *pServer;
    int          nErr = 0;

    m_nSockType = nType;
    m_nSocket = socket(AF_INET, nType, 0);
    if (m_nSocket == INVALID_SOCKET)
	{
        return INVALID_SOCKET;
	}

    memset((char*)&addr, 0, sizeof(addr));
    pServer = gethostbyname(pIP);
    if (pServer)
	{
        memcpy((char *)&addr.sin_addr.s_addr, (char*)(pServer->h_addr), pServer->h_length);   /* set address */
	}
	else
	{
        unsigned long uAddr = inet_addr(pIP);
	}
    
    addr.sin_family = AF_INET;
    addr.sin_port = htons(nPort);

    nErr = connect(m_nSocket, (sockaddr*)&addr, sizeof(sockaddr_in));
    if (nErr == SOCKET_ERROR)
    {
        closesocket(m_nSocket);
        m_nSocket = INVALID_SOCKET;
        return INVALID_SOCKET;
    }

    m_bConnected = true;
    return 0;
}

/** Disconnects the current socket */
int MBCOMSocket::Disconnect()
{
    int nErr = 0;
    if (!IsConnected()) 
        return SOCKET_ERROR;

    if (m_nSockType == SOCK_STREAM)
    {
        nErr = shutdown(m_nSocket, 2);
    }

    nErr = closesocket(m_nSocket);
    m_nSocket = INVALID_SOCKET;
    m_bConnected = false;
    return (nErr != SOCKET_ERROR) - 1;
}

/** Checks if there is a current open connection */
bool MBCOMSocket::IsConnected()
{
    return m_bConnected;
}

/** Reads from a socket, into pbuffer, up to a max of nLen byte, and writes 
  * how many were actually written to nBytesWritten. */
int MBCOMSocket::Read(char* pBuffer, size_t nLen, size_t* nBytesWritten)
{
    if (!IsConnected()) 
        return SOCKET_ERROR;  // no connection
    int nErr = 0;

    nErr = recv(m_nSocket, pBuffer, nLen, 0);
    //nErr = recv(m_nSocket, (void*)pBuffer, nLen, 0);
    if ((nErr != SOCKET_ERROR) && (nBytesWritten != NULL))
    {
        *nBytesWritten = (size_t) nErr;
    }
    return (nErr != SOCKET_ERROR) - 1;
}

/** Reads in a non blocking fashion (ie, selects and polls) for nTimeout seconds */
int MBCOMSocket::NBRead(char* pBuffer, size_t nLen, size_t* nBytesWritten, int nTimeout)
{
    timeval tval;
    tval.tv_sec = nTimeout;
    tval.tv_usec = 0;
    fd_set rset;
    int nErr = 0;

    FD_ZERO(&rset);
    FD_SET(m_nSocket, &rset);
    int nResSelect = select(m_nSocket + 1, &rset, NULL, NULL, &tval);
    if ((nResSelect != 0) && (nResSelect != SOCKET_ERROR) && 
        (FD_ISSET(m_nSocket, &rset)))
    {
        if ((nErr = Read(pBuffer, nLen, nBytesWritten)) == 0)
        {
            return 0;
        }
    }
    else
    {
        return -1;  // FD_ISSET failed.
    }
    return 0;
}

/** Writes to a socket, from buffer pBuffer, up to nLen bytes, and returns the number of written bytes in pnBytesWritten. */
int MBCOMSocket::Write(const char* pBuffer, size_t nLen, size_t* pnBytesWritten)
{
    if (!IsConnected()) 
        return SOCKET_ERROR; // no connection
    int nErr = 0;

    nErr = send(m_nSocket, pBuffer, nLen, 0);
    //nErr = send(m_nSocket, (void*)pBuffer, nLen, 0);
    if ((nErr != SOCKET_ERROR) && (pnBytesWritten != NULL))
    {
        *pnBytesWritten = (size_t) nErr;
    }
    return (nErr != SOCKET_ERROR) - 1;
}
