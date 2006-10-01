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

     $Id: rdfextract.cpp 8441 2006-08-21 12:21:04Z luks $

----------------------------------------------------------------------------*/
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <list>
#include <string>

#ifdef WIN32
#define XML_STATIC
#endif

#include "rdfextract.h"

using namespace std;

#undef DEBUG

void statement_handler(void*           user_data,
                       RDF_SubjectType subject_type,
                       const XML_Char* subject,
                       const XML_Char* predicate,
                       int             ordinal,
                       RDF_ObjectType  object_type,
                       const XML_Char* object,
                       const XML_Char* xml_lang)
{
    ((RDFExtract *)user_data)->StatementHandler(subject_type,
        subject, predicate, ordinal, object_type, object);
}

RDFExtract::RDFExtract(const string &rdfDocument, bool useUTF8)
{
   RDF_Parser parser;

   hasError = false;
   this->useUTF8 = useUTF8;

   parser = RDF_ParserCreate(NULL);
   RDF_SetUserData(parser, (void *)this);
   RDF_SetStatementHandler(parser, statement_handler);
   RDF_SetBase(parser, "musicbrainz");
   if (!RDF_Parse(parser, rdfDocument.c_str(), rdfDocument.length(), 1))
   {
       char line[10];

       sprintf(line, " on line %d.",
               XML_GetCurrentLineNumber(RDF_GetXmlParser(parser)));
       error = string("Error: ") + 
               string(XML_ErrorString(XML_GetErrorCode(
                      RDF_GetXmlParser(parser)))) +
               string(line);
       hasError = true;
   }
   RDF_ParserFree(parser); 
}

RDFExtract::~RDFExtract(void)
{

}

void RDFExtract::StatementHandler(RDF_SubjectType subject_type,
                                  const XML_Char* subject,
                                  const XML_Char* predicate,
                                  int             ordinal,
                                  RDF_ObjectType  object_type,
                                  const XML_Char* object)
{
    RDFStatement statement;

    if (useUTF8)
        statement.subject = string((char *)subject);
    else
        statement.subject = ConvertToISO(subject);

    if (useUTF8)
        statement.object = string((char *)object);
    else
        statement.object = ConvertToISO(object);

    if (ordinal == 0)
    {
        if (useUTF8)
            statement.predicate = string((char *)predicate);
        else
            statement.predicate = ConvertToISO(predicate);
        statement.ordinal = 0;
    }
    else
        statement.ordinal = ordinal;

    statement.subjectType = subject_type;
    statement.objectType = object_type;

#ifdef DEBUG
    printf("%s\n%s\n%s\n\n", 
       statement.subject.c_str(),
       statement.predicate.c_str(),
       statement.object.c_str());
#endif

    triples.push_back(statement);
}

int RDFExtract::GetNumTriples(void)
{
    return triples.size();
}

void RDFExtract::GetTriples(vector<RDFStatement> *triplesArg)
{
    *triplesArg = triples;
}

const string &RDFExtract::Extract(const string &startURI, 
                                  const string &query, 
                                  int ordinal)
{
    list<int> ordinalList;

    ordinalList.push_back(ordinal);
    return Extract(startURI, query, &ordinalList);
}

const string &RDFExtract::Extract(const string &startURI, 
                                  const string &query, 
                                  list<int> *ordinalList)
{
    vector<RDFStatement>::iterator i;
    list<string>                   predicateList;
    string                         currentURI = startURI;
    char                          *queryString, *ptr;
    bool                           done;

    if (query.length() == 0)
    {
        retValue = startURI;
        return retValue;
    }

    queryString = strdup(query.c_str());
    ptr = strtok(queryString, " \t\n");
    for(; ptr != NULL; ptr = strtok(NULL, " \t\n"))
    {
       if (strlen(ptr) > 0)
       {
          //printf("pl: '%s'\n", ptr);
          predicateList.push_back(string(ptr));
       }
    }
    free(queryString);

#ifdef DEBUG
    printf("-----------------------------------------------\n");
    printf(" Base: %s\n", startURI.c_str());
    printf("Query: %s\n\n", query.c_str());
#endif

    for(;;)
    {
       done = false;
#ifdef DEBUG
       printf("Curr URI %s: Pred: %s / [%d]\n", 
                 currentURI.c_str(),
                 (*predicateList.begin()).c_str(),
                 *(ordinalList->begin()));
#endif
       for(i = triples.begin(); i != triples.end() && !done; i++)
       {
#ifdef DEBUG
          if ((*i).subject == currentURI)
          {
              if ((*i).ordinal > 0)
                 printf("   pred: [%d]\n", (*i).ordinal);
              else
                 printf("   pred: %s\n", (*i).predicate.c_str());
          }
#endif
          //printf("Subject: '%s'\n", (*i).subject.c_str());
          if ((*i).subject == currentURI && 
             ((*i).predicate == *(predicateList.begin()) ||
             ((*i).ordinal > 0 && (*i).ordinal == *(ordinalList->begin()))))
          {
              currentURI = (*i).object;

              predicateList.pop_front();
              if ((*i).ordinal > 0)
                 ordinalList->pop_front();

              if (predicateList.size() > 0 &&
                  *(predicateList.begin()) == string("[COUNT]"))
              {
                 int num = 0;
                 char temp[10];

                 vector<RDFStatement>::iterator j;
                 for(j = triples.begin(); j != triples.end(); j++)
                 {
                    if ((*j).subject == currentURI && (*j).ordinal > 0)
                        num++;
                 }
                 sprintf(temp, "%d", num);
                 count = string(temp);
#ifdef DEBUG
                 printf("Count: %d\n\b", num);
#endif
                 return count;
              }
   
              // Force to exit the loop
              done = true;
              break;
          }
          //printf("\n");
       }
       // If we walked through all the statements and we didn't find
       // a matching predicate for the next transition, then the
       // query failed.
       if (i == triples.end())
       {
#ifdef DEBUG
          printf("-------------------------------------------\n");
          printf("Not found.\n\n");
#endif
          return empty;
       }
       // If we found a matching predicate and there are not more
       // predicate transitons, then we've arrived at the end of
       // the query. Return the last subject.
       if (done && predicateList.size() == 0)
       {
#ifdef DEBUG
          printf("-------------------------------------------\n");
          printf("Value: %s\n\n", (*i).object.c_str());
#endif
          return (*i).object;
       }
    }
}

bool RDFExtract::GetSubjectFromObject(const string &object,
                                      string       &subject)
{
    vector<RDFStatement>::iterator i;

    for(i = triples.begin(); i != triples.end(); i++)
    {
       if ((*i).object == object)
       {
           subject = (*i).subject;
           return true;
       }
    }
    return false;
}

bool RDFExtract::GetFirstSubject(string &subject)
{
    if (triples.size() > 0)
    {
        subject = (*(triples.begin())).subject;
        return true;
    }
    return false;
}

int RDFExtract::GetOrdinalFromList(const string &startURI, 
                                   const string &listType,
                                   const string &id)
{
    vector<RDFStatement>::iterator i, j;

    for(i = triples.begin(); i != triples.end(); i++)
        if ((*i).subject == startURI && (*i).predicate == listType)
            for(j = triples.begin(); j != triples.end(); j++)
                if ((*i).object == (*j).subject && (*j).object == id)
                    return (*j).ordinal;
    return -1;
}

bool RDFExtract::GetError(string &error)
{
    error = this->error;
    return error.length() > 0;
}

const string RDFExtract::ConvertToISO(const char *UTF8)
{
   unsigned char *in, *buf;
   unsigned char *out, *end;
   string               ret;

   in = (unsigned char *)UTF8;
   buf = out = new unsigned char[strlen(UTF8) + 1];
   end = in + strlen(UTF8);
   for(;*in != 0x00 && in <= end; in++, out++)
   {
       if (*in < 0x80)
       {  /* lower 7-bits unchanged */
          *out = *in;
       }
       else
       if (*in > 0xC3)
       { /* discard anything above 0xFF */
          *out = '?';
       }
       else
       if (*in & 0xC0)
       { /* parse upper 7-bits */
          if (in >= end)
            *out = 0;
          else
          {
			// The following used to be in one block, but the math would end up 
		    // wrong if compiled with MSVC++ in release mode. Using the left and right
			// intermediates fixes the problem. Gotta love M$ crap.
			unsigned char left, right;
            left = (((*in) & 0x1F) << 6); 
			right = (0x3F & (*(++in)));
            *out = right | left;
          }
       }
       else
       {
          *out = '?';  /* this should never happen */
       }
   }
   *out = 0x00; /* append null */
   ret = string((char *)buf);
   delete[] buf;

   return ret;
}
