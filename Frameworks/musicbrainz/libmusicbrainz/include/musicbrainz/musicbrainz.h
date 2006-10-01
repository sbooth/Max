/* --------------------------------------------------------------------------

   MusicBrainz -- The Internet music metadatabase

   Copyright (C) 2000 Robert Kaye
   Portions Copyright (C) 2000 David Gray
   
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

     $Id: musicbrainz.h 665 2003-10-16 22:21:10Z robert $

----------------------------------------------------------------------------*/
#ifndef _MUSICBRAINZ_H_
#define _MUSICBRAINZ_H_

#include <string>
#include <vector>
#include <list>

#include "errors.h"
#include "queries.h"

using namespace std;

class RDFExtract;

#if defined(_WIN32) && defined(MUSICBRAINZ_EXPORTS)
#define EXPORT __declspec(dllexport)
#else
#define EXPORT
#endif

class MusicBrainz
{
    public: 
       EXPORT          MusicBrainz(void);
       EXPORT virtual ~MusicBrainz(void);

       EXPORT void     GetVersion       (int &major, int &minor, int &rev);
       EXPORT bool     SetServer        (const string &serverAddr, 
                                         short serverPort);
       EXPORT bool     SetProxy         (const string &proxyAddr, 
                                         short proxyPort);

       EXPORT bool     Authenticate     (const string &userName,
                                         const string &password);

       EXPORT bool     SetDevice        (const string &device);
       EXPORT bool     SetDepth         (int depth);
       EXPORT bool     SetMaxItems      (int maxItems);
       EXPORT void     UseUTF8          (bool bUse) { m_useUTF8 = bUse; };

       EXPORT bool     Query            (const string &rdfObject, 
                                         vector<string> *args = NULL);
       EXPORT void     GetQueryError    (string &ErrorText);
       EXPORT bool     GetWebSubmitURL  (string &url);
  
       EXPORT bool     Select           (const string &selectQuery,
                                         int           ordinal = 0);
       EXPORT bool     Select           (const string &selectQuery,
                                         list<int>    *ordinalList);

       EXPORT bool     DoesResultExist  (const string &resultName, 
                                         int Index = 0);
       EXPORT bool     GetResultData    (const string &resultName, 
                                         int Index, 
                                         string &data);
       EXPORT const string &Data        (const string &resultName, 
                                         int Index = 0);
       EXPORT int      DataInt          (const string &resultName, 
                                         int Index = 0);

       EXPORT bool     GetResultRDF     (string &RDFObject);
       EXPORT bool     SetResultRDF     (string &RDFObject);

       EXPORT void     GetIDFromURL     (const string &url, string &id);
       EXPORT void     GetFragmentFromURL(const string &url, string &fragment);
       EXPORT int      GetOrdinalFromList(const string &resultList, const string &URI);

       /* These functions are helper functions that may be useful for clients */
       EXPORT bool     GetMP3Info       (const string &fileName, 
                                         int          &duration,
                                         int          &bitrate,
                                         int          &stereo,
                                         int          &samplerate);

#ifdef WIN32
       EXPORT void     WSAInit          (void);
       EXPORT void     WSAStop          (void);
#endif

       EXPORT void     SetDebug         (bool debug);

    private:

       const string EscapeArg(const string &xml);
       void         SubstituteArgs(string &xml, vector<string> *args);
       void         ReplaceArg(string &rdf, const string &from, 
                               const string &to);
       void         ReplaceIntArg(string &rdf, const string &from, int to);
       void         SetError(Error ret);
       void         MakeRDFQuery(string &rdf);

       vector<string>  m_contextHistory;
       string          m_error, m_empty; 
       string          m_server, m_proxy;
       string          m_sessionKey, m_sessionId, m_versionString;
       short           m_serverPort, m_proxyPort;
       string          m_device, m_currentURI, m_baseURI, m_response; 
       RDFExtract     *m_rdf;
       bool            m_useUTF8, m_debug;
       int             m_depth, m_maxItems;
};

#endif
