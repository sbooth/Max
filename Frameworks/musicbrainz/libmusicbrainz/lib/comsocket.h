/*__________________________________________________________________________

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

  $Id: comsocket.h 7521 2006-05-11 18:46:54Z luks $
____________________________________________________________________________*/
/***************************************************************************
                          comsocket.h  -  description
                             -------------------
    begin                : Thu Mar 23 2000
    copyright            : (C) 2000 by Relatable, LLC
    programed by         : Sean Ward
    email                : sward@relatable.com
 ***************************************************************************/
/// TODO: implement multicast connections (to allow single packet, multiple receiver connections)

#ifndef COMSOCKET_H
#define COMSOCKET_H
#include <stdio.h>
#include <string>

#ifdef WIN32
#include <winsock.h>

#else // ! WIN32

#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netdb.h>
#include <unistd.h>
#define INVALID_SOCKET -1

#endif // ! WIN32

class MBCOMServerSocket;

/**Wraps the OS specifics of a client socket.
  *@author Sean Ward
  */
class MBCOMSocket {
public: 

	MBCOMSocket(int nSocket = INVALID_SOCKET, int nSockType = SOCK_STREAM);
	~MBCOMSocket();
	friend class MBCOMServerSocket;
	/** Connects a socket to pIP, on nPort, of type nType. */
	int Connect(const char* pIP, int nPort, int nType, bool
		bBroadcast = false);
	/** Checks if there is a current open connection */
	bool IsConnected();
	/** Disconnects the current socket */
	int Disconnect();
	/** Reads from a socket, into pbuffer, up to a max of nLen byte, and writes how many were actually written to nBytesWritten. */
	int Read(char* pBuffer, size_t nLen, size_t* nBytesWritten);
	/** Reads in a non blocking fashion (ie, selects and polls) for nTimeout seconds */
	int NBRead(char* pBuffer, size_t nLen, size_t* nBytesWritten, int nTimeout);
	/** Writes to a socket, from buffer pBuffer, up to nLen bytes, and returns the number of written bytes in pnBytesWritten. */
	int Write(const char* pBuffer, size_t nLen, size_t* pnBytesWritten);
	/** Sets TCPNODELAY to nFlag */
	int SetNoDelay(int nFlag);
	/** Sets NonBlocking status */ 
	int SetNonBlocking(bool bType);
	/** Connects in a non blocking fashion, to pIp, on port nPort, using a connection of type nType, with a timeout of nTimeout seconds */
	int NBConnect(const char* pIP, int nPort, int nType, int nTimeout);
  /** Sets multicast packets to only go through the NIC labeled pNIC */
  int SetMCastInterface(const char* pNIC);

private: // Private attributes
	/** The file descriptor for this socket */
	int m_nSocket;
	/** boolean to store connected state */
	bool m_bConnected;
	/** Stores the type of socket connection. IE, multicast, stream, datagram.  */
	int m_nSockType;
	/** Stores the sockaddr describing this socket */
	sockaddr_in m_SockAddr;
};

#endif
