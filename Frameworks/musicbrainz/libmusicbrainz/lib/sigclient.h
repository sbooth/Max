/*_______________________________________________________________________        
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

  $Id: sigclient.h 321 2000-09-29 12:15:05Z ijr $
____________________________________________________________________________*/

/***************************************************************************
                          sigclient.h  -  description
                             -------------------
    copyright            : (C) 2000 by Relatable
    written by           : Isaac Richards
    email                : ijr@relatable.com
 ***************************************************************************/

#ifndef SIGCLIENT_H
#define SIGCLIENT_H

#include <iostream>
#include <string>
#include <map>
#include <vector>

#include "audiosig.h"

using namespace std;

class MBCOMHTTPSocket;
class Mutex;

class SigClient
{
public:
    SigClient();
   ~SigClient();
    int GetSignature(AudioSig *sig, string &strGUID, 
       	             string strCollectionID = "EMPTY_COLLECTION");
    void SetAddress(string strIP, int nPort) 
    { m_strIP = strIP; m_nPort = nPort; }
    void SetProxy(string strAddr, int nPort)
    { m_proxyAddr = strAddr; m_proxyPort = nPort; }

protected:
    int Connect(string& strIP, int nPort);
    int Disconnect();

private:
    MBCOMHTTPSocket* m_pSocket;
    Mutex* m_pMutex;
    string m_strIP;
    int m_nPort;
    string m_proxyAddr;
    int m_proxyPort;
    int m_nNumFailures;
};

#endif

