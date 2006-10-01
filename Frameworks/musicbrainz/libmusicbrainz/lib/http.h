/* --------------------------------------------------------------------------

   MusicBrainz -- The Internet music metadatabase

   Copyright (C) 2000 Emusic.com
   
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

     $Id: http.h 311 2000-09-22 14:15:03Z robert $

----------------------------------------------------------------------------*/
#ifndef __HTTP_H__
#define __HTTP_H__

#include "types.h"
#include "errors.h"
#include <string>

using namespace std;

class MBHttp
{

    public:
     
               MBHttp(void);
      virtual ~MBHttp(void);

      Error        DownloadToFile(const string &url, 
                                  const string &xml,
                                  const string &destPath);
      Error        DownloadToString(const string &url, 
                                    const string &xml,
                                    string &page);
      virtual void Progress(unsigned int bytesReceived, unsigned int maxBytes);
      void         SetProxyURL(const string &proxy); 

    private:

      Error    Download(const string &url, const string &xml, bool fileDownload);
      int      WriteToFile(unsigned char *buffer, unsigned int size);
      int      WriteToBuffer(unsigned char *buffer, unsigned int size);

      int32    GetContentLengthFromHeader(const char* buffer);
      bool     IsHTTPHeaderComplete(char* buffer, uint32 length);
      Error    Connect(int hHandle, const struct sockaddr *pAddr, int &iRet);
      Error    Recv(int hHandle, char *pBuffer, int iSize, 
                    int iFlags, int &iRead);
      Error    Send(int hHandle, char *pBuffer, int iSize, 
                    int iFlags, int &iSend);

      bool           m_exit;
      unsigned char *m_buffer;
      uint32         m_bufferSize, m_bytesInBuffer;
      FILE          *m_file;
      string         m_destPath, m_proxy;
};

#endif
