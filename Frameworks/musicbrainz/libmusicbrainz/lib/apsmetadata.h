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

  $Id: apsmetadata.h 295 2000-09-19 12:25:58Z robert $
____________________________________________________________________________*/

/***************************************************************************
                          apsmetadata.h  -  description
                             -------------------
    begin                : Fri Jan 7 2000
    copyright            : (C) 2000 by Sean Ward
    email                : sward@relatable.com
 ***************************************************************************/

#ifndef APS_METADATA_HEADER
#define APS_METADATA_HEADER

#ifdef WIN32
#pragma warning (disable :4786)
#endif

#include <iostream>
#ifdef WIN32
#include <ostream>
#endif
#include <string>
#include <stdlib.h>
#include <time.h>
#include <strstream>

using namespace std;

/*
#define APS_NOERROR 0
#define APS_EMPTYLIST 1
#define APS_ITEMNOTINLIST 2
#define APS_PARAMERROR 3
#define APS_ENDLIST 4
#define APS_MEMERROR 6
#define APS_NETWORKERROR 7
#define APS_GENERALERROR 8
*/

// Class APSMetaData is used for all communications of track information to the
// APSInterface class. A derived class can be used to allow application specific
// data to be translated.
class APSMetaData
{
  public:
    APSMetaData()
    {
	m_nYear = 0;
	m_nTrack = 0;
	m_nPlayCount = 0;
	m_nLength = 0;
    }

    virtual ~APSMetaData() {}

    const string &Artist() const { return m_strArtist; }
    void SetArtist(const char *pczNewArtist) { m_strArtist = pczNewArtist; }

    const string &Title() const { return m_strTitle; }
    void SetTitle(const char *pczNewTitle) { m_strTitle = pczNewTitle; }

    const string &Album() const { return m_strAlbum; }
    void SetAlbum(const char *pczNewAlbum) { m_strAlbum = pczNewAlbum; }

    const string &Genre() const { return m_strGenre; }
    void SetGenre(const char *pczNewGenre) { m_strGenre = pczNewGenre; }

    const string &Comment() const { return m_strComment; }
    void SetComment(const char *pczNewComment) { m_strComment = pczNewComment; }

    const string &GUID() const { return m_strGUID; }
    void SetGUID(const char *pczNewGUID) { m_strGUID = pczNewGUID; }

    const string &Filename() const { return m_strFilename; }
    void SetFilename(const char *pczNewFilename) { m_strFilename = pczNewFilename; }

    int Year() const { return m_nYear; }
    void SetYear(int nNewYear) { m_nYear = nNewYear; }

    int Track() const { return m_nTrack; }
    void SetTrack(int nNewTrack) { m_nTrack = nNewTrack; }

    int PlayCount() const { return m_nPlayCount; }
    void SetPlayCount(int nNewPlayCount) { m_nPlayCount = nNewPlayCount; }

    int Length() const { return m_nLength; }
    void SetLength(int nNewLength) { m_nLength = nNewLength; }

    void stream_insert(ostream &out_stream) const
    {
        char temp[256];
        memset (temp, 0, sizeof (char) * 256);

        out_stream << 11 << " ";
        out_stream << m_strAlbum.size () << " ";
        out_stream << m_strArtist.size () << " ";
        out_stream << m_strComment.size () << " ";
        out_stream << m_strFilename.size () << " ";
        out_stream << m_strGenre.size () << " ";
        out_stream << m_strGUID.size () << " ";

        sprintf(temp, "%d", m_nLength);
        out_stream << strlen (temp) << " ";

        sprintf(temp, "%d", m_nPlayCount);
        out_stream << strlen (temp) << " ";

        out_stream << m_strTitle.size () << " ";

        sprintf(temp, "%d", m_nTrack);
        out_stream << strlen (temp) << " ";

        sprintf(temp, "%d", m_nYear);
        out_stream << strlen (temp) << " ";

        out_stream << m_strAlbum;
        out_stream << m_strArtist;
        out_stream << m_strComment;
        out_stream << m_strFilename;
        out_stream << m_strGenre;
        out_stream << m_strGUID;
        out_stream << m_nLength;
        out_stream << m_nPlayCount;
        out_stream << m_strTitle;
        out_stream << m_nTrack;
        out_stream << m_nYear;
        out_stream << endl;
    }

    void stream_extract(FILE * pFile)
    {
        int nIndex[12];
        memset(nIndex, 0, sizeof (int) * 12);

        fscanf (pFile, "%d", &(nIndex[0]));
        if (nIndex[0] != 11)
            return;

        for (int i = 0; i < 11; i++)
        {
            fscanf(pFile, "%d", &(nIndex[i]));
            nIndex[11] += nIndex[i];
        }

	string strTemp;
	char *pBuffer = new char[nIndex[11] + 2];
	fseek (pFile, sizeof (char), SEEK_CUR);
	fread (pBuffer, sizeof (char), nIndex[11] + 1, pFile);
	pBuffer[nIndex[11]] = '\0';

	strTemp = pBuffer;

	SetYear(atoi(strTemp.substr(nIndex[11] - nIndex[10], nIndex[10]).c_str()));
	nIndex[11] -= nIndex[10];

	SetTrack(atoi(strTemp.substr(nIndex[11] - nIndex[9], nIndex[9]).c_str()));
	nIndex[11] -= nIndex[9];

	SetTitle(strTemp.substr(nIndex[11] - nIndex[8], nIndex[8]).c_str());
	nIndex[11] -= nIndex[8];

	SetPlayCount(atoi(strTemp.substr(nIndex[11] - nIndex[7], nIndex[7]).c_str()));
	nIndex[11] -= nIndex[7];

	SetLength(atoi(strTemp.substr(nIndex[11] - nIndex[6], nIndex[6]).c_str()));
	nIndex[11] -= nIndex[6];

	SetGUID(strTemp.substr(nIndex[11] - nIndex[5], nIndex[5]).c_str());
	nIndex[11] -= nIndex[5];

	SetGenre(strTemp.substr(nIndex[11] - nIndex[4], nIndex[4]).c_str());
	nIndex[11] -= nIndex[4];

	SetFilename(strTemp.substr(nIndex[11] - nIndex[3], nIndex[3]).c_str());
	nIndex[11] -= nIndex[3];

	SetComment(strTemp.substr(nIndex[11] - nIndex[2], nIndex[2]).c_str());
	nIndex[11] -= nIndex[2];

	SetArtist(strTemp.substr(nIndex[11] - nIndex[1], nIndex[1]).c_str());
	nIndex[11] -= nIndex[1];

	SetAlbum(strTemp.substr(nIndex[11] - nIndex[0], nIndex[0]).c_str());
	nIndex[11] -= nIndex[0];

	delete[]pBuffer;

	return;
    }

    string GetField(int nField)
    {
	strstream streamtemp;
	string strReturn;

	switch(nField)
	{
            case 0: return m_strArtist;
	    case 1: return m_strTitle;
	    case 2: return m_strAlbum;
	    case 3: return m_strGenre;
	    case 4: return m_strComment;
	    case 5: return m_strGUID;
	    case 6: return m_strFilename;
	    case 7: streamtemp << m_nYear;
	            streamtemp >> strReturn;
	            return strReturn;
	    case 8: streamtemp << m_nTrack;
	            streamtemp >> strReturn;
	            return strReturn;
	    case 9: streamtemp << m_nPlayCount;
	            streamtemp >> strReturn;
	            return strReturn;
	    case 10: streamtemp << m_nLength;
	             streamtemp >> strReturn;
	             return strReturn;
	    default: return "";
	}
    }

    void SetField(int nField, string & strValue)
    {
	switch (nField)
	{
	    case 0: m_strArtist = strValue;
	            break;
	    case 1: m_strTitle = strValue;
	            break;
	    case 2: m_strAlbum = strValue;
	            break;
	    case 3: m_strGenre = strValue;
	            break;
	    case 4: m_strComment = strValue;
	            break;
            case 5: m_strGUID = strValue;
	            break;
	    case 6: m_strFilename = strValue;
	            break;
	    case 7: m_nYear = atoi(strValue.c_str ());
	            break;
	    case 8: m_nTrack = atoi(strValue.c_str ());;
	            break;
	    case 9: m_nPlayCount = atoi(strValue.c_str ());
	            break;
            case 10: m_nLength = atoi(strValue.c_str ());
	             break;
	    default: return;
	  }
    }

    bool IsNull(int nField) { return GetField (nField).empty(); }

    int NumFields() { return 11; }

private:
    string m_strArtist;
    string m_strTitle;
    string m_strAlbum;
    string m_strGenre;
    string m_strComment;
    string m_strGUID;
    string m_strFilename;
    int m_nYear;
    int m_nTrack;
    int m_nPlayCount;
    int m_nLength;
};

#endif
