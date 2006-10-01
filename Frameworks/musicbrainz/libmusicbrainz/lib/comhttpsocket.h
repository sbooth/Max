/***************************************************************************
                          MBCOMHTTPSocket.h  -  description
                             -------------------
    begin                : Sat Jun 3 2000
    copyright            : (C) 2000 by Relatable
    written by           : Sean Ward
    email                : sward@relatable.com
 ***************************************************************************/

#ifndef MBCOMHTTPSocket_H
#define MBCOMHTTPSocket_H
#include <stdio.h>
#include <string>

using namespace std;

class MBCOMSocket;
/**Wraps the OS specifics of an http based proxiable client socket.
  *@author Sean Ward
  */
class MBCOMHTTPSocket {
public: 

	MBCOMHTTPSocket();
	~MBCOMHTTPSocket();
	/** Connects a socket to pIP, on nPort, of type nType. */
	int Connect(const char* pURL);
	/** Checks if there is a current open connection */
	bool IsConnected();
	/** Disconnects the current socket */
	int Disconnect();
	/** Reads in a non blocking fashion (ie, selects and polls) for nTimeout seconds */
	int NBRead(char* pBuffer, size_t nLen, size_t* nBytesWritten, int nTimeout);
        /** Reads from a socket, into pbuffer, up to a max of nLen byte, and writes how many were actually written to nBytesWritten. */
        int Read(char* pBuffer, size_t nLen, size_t* nBytesWritten);
	/** Writes to a socket, from buffer pBuffer, up to nLen bytes, and returns the number of written bytes in pnBytesWritten. */
	int Write(const char* pBuffer, size_t nLen, size_t* pnBytesWritten);
	/** Sets the proxy address. Use NULL to disable. */
	int SetProxy(const char* pURL);

protected:
	/** Internal validation function */
	bool IsHTTPHeaderComplete(char* buffer, unsigned int length);

private: // Private attributes
	/** socket used for transport */
	MBCOMSocket* m_pSock;
	/** URL of proxy */
	string m_strProxyAddr;
	/** URL of current connection */
	string m_strURL;
        /** hostname field for current request */
	char m_hostname[65];
        /** proxy URL for current request */
	char m_proxyname[1025];
        /** file to request or post to */
	const char* m_pFile;
	/** temp buffer for excess data when parsing header */
	char* m_pTempBuf;
	size_t m_nBufLen;
};

#endif
