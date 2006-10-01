/*________________________________________________________________________        
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
        
        $Id: wincomsocket.h 7522 2006-05-11 19:02:35Z luks $
____________________________________________________________________________*/

/// TODO: implement multicast connections (to allow single packet, multiple receiver connections)

#ifndef WINMBCOMSocket_H
#define WINMBCOMSocket_H
//#include <sys/socket.h>
//#include <netinet/in.h>
//#include <netdb.h>
//#include "mutex.h"
#include <stdio.h>
#include <string>
#include "apsutility.h"

//class COMServerSocket;

/**Wraps the OS specifics of a client socket.
  *@author Sean Ward
  */
class MBCOMSocket {
public:
    MBCOMSocket(int nSocket = INVALID_SOCKET, int nSockType = SOCK_STREAM);
   ~MBCOMSocket();

friend class COMServerSocket;
    /** Connects a socket to pIP, on nPort, of type nType. */
    int Connect(const char* pIP, int nPort, int nType, 
                bool bBroadcast = false);
    /** Checks if there is a current open connection */
    bool IsConnected();
    /** Disconnects the current socket */
    int Disconnect();
    /** Reads from a socket, into pbuffer, up to a max of nLen byte, and writes 
      * how many were actually written to nBytesWritten. */
    int Read(char* pBuffer, size_t nLen, size_t* nBytesWritten);
    /** Reads in a non blocking fashion (ie, selects and polls) for nTimeout 
      * seconds */
    int NBRead(char* pBuffer, size_t nLen, size_t* nBytesWritten, int nTimeout);
    /** Writes to a socket, from buffer pBuffer, up to nLen bytes, and returns 
      * the number of written bytes in pnBytesWritten. */
    int Write(const char* pBuffer, size_t nLen, size_t* pnBytesWritten);
    int GetSocket() { return m_nSocket; }

private: // Private attributes

    /** The file descriptor for this socket */
    int m_nSocket;
    /** boolean to store connected state */
    bool m_bConnected;
    /** Stores the type of socket connection. IE, multicast, stream, datagram */
    int m_nSockType;
    /** Stores the sockaddr describing this socket */
    sockaddr_in m_SockAddr;
};

#endif
