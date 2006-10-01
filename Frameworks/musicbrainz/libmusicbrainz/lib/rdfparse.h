/* rdfparse.h - RDF Parser Toolkit (repat) interface
 *
 * Copyright (C) 2000 Jason Diamond - http://injektilo.org/
 *
 *    This package is Free Software available under either of two licenses:
 * 
 * 1. The GNU Lesser General Public License (LGPL)
 * 
 *    See http://www.gnu.org/copyleft/lesser.html or COPYING.LIB for the
 *    full license text.
 *      _________________________________________________________________
 * 
 *      Copyright (C) 2000 Jason Diamond. All Rights Reserved.
 * 
 *      This library is free software; you can redistribute it and/or
 *      modify it under the terms of the GNU Lesser General Public License
 *      as published by the Free Software Foundation; either version 2 of
 *      the License, or (at your option) any later version.
 * 
 *      This library is distributed in the hope that it will be useful, but
 *      WITHOUT ANY WARRANTY; without even the implied warranty of
 *      MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 *      Lesser General Public License for more details.
 * 
 *      You should have received a copy of the GNU Lesser General Public
 *      License along with this library; if not, write to the Free Software
 *      Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307
 *      USA
 *      _________________________________________________________________
 * 
 *    NOTE - under Term 3 of the LGPL, you may choose to license the entire
 *    library under the GPL. See COPYING for the full license text.
 * 
 * 2. The Mozilla Public License
 * 
 *    See http://www.mozilla.org/MPL/MPL-1.1.html or MPL.html for the full
 *    license text.
 * 
 *    Under MPL section 13. I declare that all of the Covered Code is
 *    Multiple Licensed:
 *      _________________________________________________________________
 * 
 *      The contents of this file are subject to the Mozilla Public License
 *      version 1.1 (the "License"); you may not use this file except in
 *      compliance with the License. You may obtain a copy of the License
 *      at http://www.mozilla.org/MPL/
 * 
 *      Software distributed under the License is distributed on an "AS IS"
 *      basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
 *      the License for the specific language governing rights and
 *      limitations under the License.
 * 
 *      The Initial Developer of the Original Code is Jason Diamond.
 *      Portions created by Jason Diamond are Copyright (C) 2000 Jason
 *      Diamond. All Rights Reserved.
 * 
 *      Alternatively, the contents of this file may be used under the
 *      terms of the GNU Lesser General Public License, in which case the
 *      provisions of the LGPL License are applicable instead of those
 *      above. If you wish to allow use of your version of this file only
 *      under the terms of the LGPL License and not to allow others to use
 *      your version of this file under the MPL, indicate your decision by
 *      deleting the provisions above and replace them with the notice and
 *      other provisions required by the LGPL License. If you do not delete
 *      the provisions above, a recipient may use your version of this file
 *      under either the MPL or the LGPL License.
 */

#ifndef RDFPARSE_INCLUDED
#define RDFPARSE_INCLUDED 1

#ifdef __cplusplus
extern "C" {
#endif

#include "expat.h"

#ifndef RDFPARSEAPI
#define RDFPARSEAPI /* as nothing */
#endif

typedef void* RDF_Parser;

typedef enum
{
	RDF_SUBJECT_TYPE_URI          =  0,
	RDF_SUBJECT_TYPE_DISTRIBUTED  =  1,
	RDF_SUBJECT_TYPE_PREFIX       =  2,
	RDF_SUBJECT_TYPE_ANONYMOUS    =  3
}
RDF_SubjectType;

typedef enum 
{
	RDF_OBJECT_TYPE_RESOURCE  =  0,
	RDF_OBJECT_TYPE_LITERAL   =  1,
	RDF_OBJECT_TYPE_XML       =  2
} 
RDF_ObjectType;

/* handlers */

	typedef void 
( *RDF_StatementHandler )(
         void*            user_data,
         RDF_SubjectType  subject_type,
  const  XML_Char*        subject,
/*       int              id,*/
  const  XML_Char*        predicate,
         int              ordinal,
         RDF_ObjectType   object_type,
  const  XML_Char*        object,
  const  XML_Char*        xml_lang );

	typedef void 
( *RDF_StartParseTypeLiteralHandler )( 
	void  *user_data );

	typedef void 
( *RDF_EndParseTypeLiteralHandler )( 
	void  *user_data );

	typedef void
( *RDF_WarningHandler )(
	      void*      user_data,
	const XML_Char*  warning );

/* functions */

/* encoding is forwarded to XML_ParserCreate. */
	RDF_Parser RDFPARSEAPI
RDF_ParserCreate( 
	const  XML_Char*  encoding );

	void RDFPARSEAPI
RDF_ParserFree(
	RDF_Parser  parser );

/* do NOT use XML_SetUserData. */
	void RDFPARSEAPI
RDF_SetUserData(
	RDF_Parser  parser,
	void*       user_data );

	void RDFPARSEAPI *
RDF_GetUserData(
	RDF_Parser  parser );

	void RDFPARSEAPI
RDF_SetStatementHandler(
	RDF_Parser            parser,
	RDF_StatementHandler  handler );

	void RDFPARSEAPI
RDF_SetParseTypeLiteralHandler(
	RDF_Parser                        parser,
	RDF_StartParseTypeLiteralHandler  start,
	RDF_EndParseTypeLiteralHandler    end );

/* do NOT use XML_SetElementHandler as rdfparse needs to
   intercept all elements in order to know when to start
   and stop RDF processing. */
	void RDFPARSEAPI
RDF_SetElementHandler( 
	RDF_Parser               parser,
	XML_StartElementHandler  start,
	XML_EndElementHandler    end );

/* do NOT use XML_SetCharacterDataHandler. */
	void RDFPARSEAPI
RDF_SetCharacterDataHandler( 
	RDF_Parser                parser,
	XML_CharacterDataHandler  handler );

	void RDFPARSEAPI
RDF_SetWarningHandler(
	RDF_Parser          parser,
	RDF_WarningHandler  handler );

/* returns 0 on error. */
	int RDFPARSEAPI
RDF_Parse( 
	      RDF_Parser  parser, 
	const char*       s, 
	      int         len, 
	      int         is_final );

/* useful for XML_GetCurrentXxx functions. */
	XML_Parser RDFPARSEAPI
RDF_GetXmlParser(
	RDF_Parser  parser );

/* set the base URI for the document. anonymous and
   internal resources will be prefixed with this URI. */
	int RDFPARSEAPI
RDF_SetBase( 
	       RDF_Parser  parser, 
	const  XML_Char*   base );

	const XML_Char RDFPARSEAPI *
RDF_GetBase( 
	RDF_Parser  parser );

	void RDFPARSEAPI
RDF_ResolveURI(
	       RDF_Parser  parser,
	const  XML_Char*   uri_reference,
	       XML_Char*   buffer,
	       size_t      length );

#ifdef __cplusplus
}
#endif


#ifdef XML_UNICODE

#ifndef XML_UNICODE_WCHAR_T
#error rdfparse requires a 16-bit Unicode-compatible wchar_t 
#endif

#define T(x)       L ## x
#define ftprintf   fwprintf
#define tfopen    _wfopen
#define fputts     fputws
#define puttc      putwc
#define tcscmp     wcscmp
#define tcscpy     wcscpy
#define tcscat     wcscat
#define tcschr     wcschr
#define tcsrchr    wcsrchr
#define tcslen     wcslen
#define tperror   _wperror
#define topen     _wopen
#define tmain      wmain
#define tremove   _wremove
#define tcsdup     wcsdup
#define tcsncmp    wcsncmp
#define tcsncat    wcsncat
#define tcsncpy    wcsncpy
#define istspace   iswspace
#define stprintf   swprintf
#define istdigit   iswdigit
#define ttoi       wtoi
#define vstprintf  vswprintf
#define itot       itow
#define istalpha   iswalpha
#define istalnum   iswalnum

#else /* not XML_UNICODE */

#define T(x)       x
#define ftprintf   fprintf
#define tfopen     fopen
#define fputts     fputs
#define puttc      putc
#define tcscmp     strcmp
#define tcscpy     strcpy
#define tcscat     strcat
#define tcschr     strchr
#define tcsrchr    strrchr
#define tcslen     strlen
#define tperror    perror
#define topen      open
#define tmain      main
#define tremove    remove
#define tcsdup     strdup
#define tcsncmp    strncmp
#define tcsncat    strncat
#define tcsncpy    strncpy
#define istspace   isspace
#define stprintf   sprintf
#define istdigit   isdigit
#define ttoi       atoi
#define vstprintf  vsprintf
#define itot       itoa
#define istalpha   isalpha
#define istalnum   isalnum

#endif /* not XML_UNICODE */


#endif /* not RDFPARSE_INCLUDED */
