/* --------------------------------------------------------------------------

   MusicBrainz -- The Internet music metadatabase

   Copyright (C) 2000 Robert Kaye
   
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

     $Id: rdfextract.h 562 2003-02-04 23:18:43Z robert $

----------------------------------------------------------------------------*/
#ifndef _RDFEXTRACT_H_
#define _RDFEXTRACT_H_

#include <string>
#include <vector>
#include <list>
#include "rdfparse.h"

using namespace std;

typedef struct
{
    string          object;
    string          predicate;
    string          subject;
    int             ordinal;
    RDF_SubjectType subjectType;
    RDF_ObjectType  objectType;
} RDFStatement;

class RDFExtract
{
    public:

                 RDFExtract             (const string &rdfDocument,
                                         bool          useUTF8);
        virtual ~RDFExtract             (void);

        int      GetNumTriples          (void);
        void     GetTriples             (vector<RDFStatement> *triples);

        const string &Extract           (const string &startURI,
                                         const string &query,
                                         int           ordinal = 0);
        const string &Extract           (const string &startURI,
                                         const string &query,
                                         list<int>    *ordinalList);
        bool     GetSubjectFromObject   (const string &object,
                                         string       &subject);
        bool     GetFirstSubject        (string &subject);
        int      GetOrdinalFromList     (const string &startURI, 
                                         const string &listQuery,
                                         const string &id);

        bool     GetError               (string &error);
        bool     HasError               (void) { return hasError; };

    private:

        vector<RDFStatement>  triples;
        string                error, empty, retValue, count;
        bool                  useUTF8, hasError;

    public:

        const string ConvertToISO(const char *UTF8);

        void     StatementHandler(RDF_SubjectType subject_type,
                                  const XML_Char* subject,
                                  const XML_Char* predicate,
                                  int             ordinal,
                                  RDF_ObjectType  object_type,
                                  const XML_Char* object);
};

#endif
