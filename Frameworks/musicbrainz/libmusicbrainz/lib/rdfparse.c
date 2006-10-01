/* rdfparse.c - RDF Parser Toolkit (repat) implementation
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


#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <stdarg.h>
#include <stdlib.h>
#include <assert.h>

#ifdef WIN32
#define XML_STATIC
#endif
#include "rdfparse.h"

#define XML_NAMESPACE_URI        T( "http://www.w3.org/XML/1998/namespace" )
#define XML_LANG                 T( "lang" )

#define RDF_NAMESPACE_URI        T( "http://www.w3.org/1999/02/22-rdf-syntax-ns#" )
#define RDF_RDF                  T( "RDF" )
#define RDF_DESCRIPTION          T( "Description" )
#define RDF_ID                   T( "ID" )
#define RDF_ABOUT                T( "about" )
#define RDF_ABOUT_EACH           T( "aboutEach" )
#define RDF_ABOUT_EACH_PREFIX    T( "aboutEachPrefix" )
#define RDF_BAG_ID               T( "bagID" )
#define RDF_RESOURCE             T( "resource" )
#define RDF_VALUE                T( "value" )
#define RDF_PARSE_TYPE           T( "parseType" )
#define RDF_PARSE_TYPE_LITERAL   T( "Literal" )
#define RDF_PARSE_TYPE_RESOURCE  T( "Resource" )
#define RDF_TYPE                 T( "type" )
#define RDF_BAG                  T( "Bag" )
#define RDF_SEQ                  T( "Seq" )
#define RDF_ALT                  T( "Alt" )
#define RDF_LI                   T( "li" )
#define RDF_STATEMENT            T( "Statement" )
#define RDF_SUBJECT              T( "subject" )
#define RDF_PREDICATE            T( "predicate" )
#define RDF_OBJECT               T( "object" )

#define NAMESPACE_SEPARATOR_CHAR    T( '^' )
#define NAMESPACE_SEPARATOR_STRING  T( "^" )

#define FALSE 0
#define TRUE  1

#define ASSIGN_STRING( _X, _Y ) if( _X ) free( _X ); _X = tcsdup( _Y );
#define FREE_STRING( _X ) if( _X ) free( _X ); ( _X ) = NULL;

typedef enum _rdf_state
{
    IN_TOP_LEVEL,
    IN_RDF,
    IN_DESCRIPTION,
    IN_PROPERTY_UNKNOWN_OBJECT, 
    IN_PROPERTY_RESOURCE,
    IN_PROPERTY_EMPTY_RESOURCE,
    IN_PROPERTY_LITERAL,
    IN_PROPERTY_PARSE_TYPE_LITERAL,
    IN_PROPERTY_PARSE_TYPE_RESOURCE,
    IN_XML,
    IN_UNKNOWN
}
_rdf_state;

typedef struct _rdf_element
{
    struct _rdf_element*  parent;
    _rdf_state            state;
    int                   has_property_attributes;
    int                   has_member_attributes;
    int                   subject_type;
    XML_Char*             subject;
    XML_Char*             predicate;
    int                   ordinal;
    int                   members;
    XML_Char*             data;
    XML_Char*             xml_lang;
    XML_Char*             bag_id;
    int                   statements;
    XML_Char*             statement_id;
}
_rdf_element;

typedef struct _rdf_parser
{
    void*                             user_data;
    XML_Parser                        xml_parser;
    _rdf_element*                     top;
    _rdf_element*                     free;
    int                               anonymous_id;
    XML_Char*                         base_uri;
    RDF_StatementHandler              statement_handler;
    RDF_StartParseTypeLiteralHandler  start_parse_type_literal_handler;
    RDF_EndParseTypeLiteralHandler    end_parse_type_literal_handler;
    XML_StartElementHandler           start_element_handler;
    XML_EndElementHandler             end_element_handler;
    XML_CharacterDataHandler          character_data_handler;
    RDF_WarningHandler                warning_handler;
}
_rdf_parser;

/* internal prototypes */

    static _rdf_element* 
new_element();

    static void 
copy_element( 
    _rdf_element*  source, 
    _rdf_element*  destination );

    static void 
clear_element( 
    _rdf_element*  e );

    static void 
push_element( 
    _rdf_parser*  rdf_parser );

    static void 
pop_element( 
    _rdf_parser*  rdf_parser );

    static void 
delete_elements( 
    _rdf_parser*  rdf_parser );

    static int 
is_rdf_property_attribute_resource( 
    const  XML_Char*  local_name );

    static int 
is_rdf_property_attribute_literal( 
    const  XML_Char*  local_name );

    static int 
is_rdf_ordinal( 
    const  XML_Char*  local_name );

    static int 
is_rdf_property_attribute( 
    const  XML_Char*  local_name );

    static int 
is_rdf_property_element( 
    const  XML_Char*  local_name );

    static int
is_absolute_uri(
    const  XML_Char*  uri );

	static void
parse_uri(
	const  XML_Char*   uri,
	       XML_Char*   buffer,
		   size_t      len,
		   XML_Char**  scheme,
		   XML_Char**  authority,
		   XML_Char**  path,
		   XML_Char**  query,
		   XML_Char**  fragment );

	static void
resolve_uri_reference(
	const  XML_Char*  base_uri,
	const  XML_Char*  reference_uri,
	       XML_Char*  buffer,
		   size_t     length );

	static int
is_valid_id(
	const  XML_Char*  id );

	static void
resolve_id(
	      _rdf_parser*  rdf_parser,
	const  XML_Char*    id,
	       XML_Char*    buffer,
		   size_t       length );

    static void 
split_name( 
    const  XML_Char*   name, 
           XML_Char*   buffer, 
           size_t      len,
           XML_Char**  namespace_uri, 
           XML_Char**  local_name );

    static void 
generate_anonymous_uri( 
    _rdf_parser*  rdf_parser, 
     XML_Char*    buf,
     size_t       len );

    static void 
report_statement( 
          _rdf_parser*      rdf_parser, 
           RDF_SubjectType  subject_type, 
    const  XML_Char*        subject, 
    const  XML_Char*        predicate, 
           int              ordinal, 
           RDF_ObjectType   object_type, 
    const  XML_Char*        object,
    const  XML_Char*        xml_lang,
    const  XML_Char*        bag_id,
           int*             statements,
    const  XML_Char*        statement_id );

    static void
report_start_parse_type_literal( 
    _rdf_parser*  rdf_parser );

    static void
report_end_parse_type_literal( 
    _rdf_parser*  rdf_parser );

    static void 
handle_property_attributes( 
          _rdf_parser*      rdf_parser, 
           RDF_SubjectType  subject_type, 
    const  XML_Char*        subject, 
    const  XML_Char**       attributes, 
    const  XML_Char*        xml_lang,
    const  XML_Char*        bag_id, 
           int*             statements );

    static void
report_start_element( 
          _rdf_parser*   rdf_parser, 
    const  XML_Char*     name, 
    const  XML_Char**    attributes );

    static void 
report_end_element( 
          _rdf_parser*  rdf_parser, 
    const  XML_Char*    name );

    static void
report_character_data(
          _rdf_parser*  rdf_parser,
    const  XML_Char*    s,
           int          len );

    static void 
report_warning( 
          _rdf_parser*  rdf_parser, 
    const  XML_Char*    warning, 
           ... );

    static void
handle_resource_element( 
          _rdf_parser*   rdf_parser, 
    const  XML_Char*     namespace_uri, 
    const  XML_Char*     local_name, 
    const  XML_Char**    attributes, 
          _rdf_element*  parent );

    static void
handle_property_element( 
          _rdf_parser*  rdf_parser, 
    const  XML_Char*    namespace_uri, 
    const  XML_Char*    local_name, 
    const  XML_Char**   attributes );

    static void 
start_element_handler( 
           void*       user_data, 
    const  XML_Char*   name, 
    const  XML_Char**  attributes );

    static void 
end_empty_resource_property(
    _rdf_parser*  rdf_parser );

    static void 
end_literal_property( 
    _rdf_parser*  rdf_parser );

    static void 
end_element_handler( 
           void*      user_data, 
    const  XML_Char*  name );

    static void 
character_data_handler( 
           void*      user_data, 
    const  XML_Char*  s, 
           int        len );

/* internal functions */

    _rdf_element* 
new_element()
{
    _rdf_element* e = calloc( 1, sizeof( _rdf_element ) );
    return e;
}

    void 
copy_element( 
    _rdf_element*  source, 
    _rdf_element*  destination )
{
    if( source )
    {
        destination->parent = source;
        destination->state = source->state;
        destination->xml_lang = source->xml_lang;
    }
}

    void 
clear_element( 
    _rdf_element*  e )
{
    if( e )
    {
        FREE_STRING( e->subject );
        FREE_STRING( e->predicate );
        FREE_STRING( e->data );
        FREE_STRING( e->bag_id );
        FREE_STRING( e->statement_id );

        if( e->parent )
        {
            if( e->parent->xml_lang != e->xml_lang )
            {
                FREE_STRING( e->xml_lang );
            }
        }
        else
        {
            FREE_STRING( e->xml_lang );
        }

        memset( e, 0, sizeof( _rdf_element ) );
    }
}

    void 
push_element( 
    _rdf_parser*  rdf_parser )
{
    _rdf_element* e;

    if( rdf_parser->free )
    {
        e = rdf_parser->free;
        rdf_parser->free = e->parent;
    }
    else
    {
        e = new_element();
    }

    copy_element( rdf_parser->top, e );
    rdf_parser->top = e;
}

    void 
pop_element( 
    _rdf_parser*  rdf_parser )
{
    _rdf_element* e = rdf_parser->top;
    rdf_parser->top = e->parent;
    clear_element( e );
    e->parent = rdf_parser->free;
    rdf_parser->free = e;
}

    void 
delete_elements( 
    _rdf_parser*  rdf_parser )
{
    for( ;; )
    {
        _rdf_element* e;

        if( rdf_parser->top == 0 )
        {
            if( rdf_parser->free == 0 )
            {
                break;
            }

            rdf_parser->top = rdf_parser->free;
            rdf_parser->free = 0;
        }

        e = rdf_parser->top;
        rdf_parser->top = e->parent;
        clear_element( e );
        free( e );
    }
}

    int 
is_rdf_property_attribute_resource( 
    const  XML_Char*  local_name )
{
    return tcscmp( local_name, RDF_TYPE ) == 0;
}

    int 
is_rdf_property_attribute_literal( 
    const  XML_Char*  local_name )
{
    return tcscmp( local_name, RDF_VALUE ) == 0;
}

    int 
is_rdf_ordinal( 
    const  XML_Char*  local_name )
{
    int ordinal = -1;

    if( *local_name == T( '_' ) )
    {
        ordinal = ttoi( local_name + 1 );
    }

    return ( ordinal > 0 ) ? ordinal : 0;
}

    int 
is_rdf_property_attribute( 
    const  XML_Char*  local_name )
{
    return is_rdf_property_attribute_resource( local_name )
        || is_rdf_property_attribute_literal( local_name );
}

    int 
is_rdf_property_element( 
    const  XML_Char*  local_name )
{
    return ( tcscmp( local_name, RDF_TYPE ) == 0 )
        || ( tcscmp( local_name, RDF_SUBJECT ) == 0 )
        || ( tcscmp( local_name, RDF_PREDICATE ) == 0 )
        || ( tcscmp( local_name, RDF_OBJECT ) == 0 )
        || ( tcscmp( local_name, RDF_VALUE ) == 0 )
        || ( tcscmp( local_name, RDF_LI ) == 0 )
        || ( local_name[ 0 ] == T( '_' ) );
}

    int
is_absolute_uri(
    const  XML_Char*  uri )
{
	int result = FALSE;

	if( *uri && istalpha( *uri ) )
	{
		++uri;

		while( *uri 
			&& ( istalnum( *uri ) 
				|| ( *uri == T( '+' ) )
				|| ( *uri == T( '-' ) )
				|| ( *uri == T( '.' ) ) ) )
		{
			++uri;
		}

		result = ( *uri == T( ':' ) );
	}

    return result;
}

	void
parse_uri(
	const  XML_Char*   uri,
	       XML_Char*   buffer,
		   size_t      len,
		   XML_Char**  scheme,
		   XML_Char**  authority,
		   XML_Char**  path,
		   XML_Char**  query,
		   XML_Char**  fragment )
{
	const XML_Char* s = NULL;
	XML_Char* d = NULL;
	XML_Char* endp = NULL;

	*scheme = NULL;
	*authority = NULL;
	*path = NULL;
	*query = NULL;
	*fragment = NULL;

	s = uri;
	d = buffer;
	endp = d + len;

	if( is_absolute_uri( uri ) )
	{
		*scheme = d;

		while( *s != T( ':' ) )
		{
			if (d < endp)
				*d++ = *s++;
		}

		if (d < endp)
			*d++ = 0;

		++s;
	}

	if( *s && *( s + 1 ) && *s == T( '/' ) && *( s + 1 ) == T( '/' ) )
	{
		*authority = d;

		s += 2;

		while( *s != 0
			&& *s != T( '/' ) 
			&& *s != T( '\\' )
			&& *s != T( '?' ) 
			&& *s != T( '#' ) )
		{
			if (d < endp)
				*d++ = *s++;
		}

		if (d < endp)
			*d++ = 0;
	}

	if( *s != 0 && *s != T( '?' ) && *s != T( '#' ) )
	{
		*path = d;

		while( *s != 0
			&& *s != T( '?' ) 
			&& *s != T( '#' ) )
		{
			if (d < endp)
				*d++ = *s++;
		}

		if (d < endp)
			*d++ = 0;
	}

	if( *s != 0 && *s == T( '?' ) )
	{
		*query = d;

		++s;

		while( *s != 0 
			&& *s != T( '#' ) )
		{
			if (d < endp)
				*d++ = *s++;
		}

		if (d < endp)
			*d++ = 0;
	}

	if( *s != 0 && *s == T( '#' ) )
	{
		*fragment = d;

		++s;

		while( *s != 0 )
		{
			if (d < endp)
				*d++ = *s++;
		}

		if (d < endp)
			*d = 0;
	}
}

	void
resolve_uri_reference(
	const  XML_Char*  base_uri,
	const  XML_Char*  reference_uri,
	       XML_Char*  buffer,
		   size_t     length )
{
	XML_Char base_buffer[ 256 ];
	XML_Char reference_buffer[ 256 ];
	XML_Char path_buffer[ 256 ];

	XML_Char* base_scheme;
	XML_Char* base_authority;
	XML_Char* base_path;
	XML_Char* base_query;
	XML_Char* base_fragment;

	XML_Char* reference_scheme;
	XML_Char* reference_authority;
	XML_Char* reference_path;
	XML_Char* reference_query;
	XML_Char* reference_fragment;

	XML_Char* result_scheme = NULL;
	XML_Char* result_authority = NULL;
	XML_Char* result_path = NULL;

	*buffer = 0;

	parse_uri(
		reference_uri,
		reference_buffer,
		sizeof( reference_buffer ),
		&reference_scheme,
		&reference_authority,
		&reference_path,
		&reference_query,
		&reference_fragment );

	if( reference_scheme == NULL
		&& reference_authority == NULL
		&& reference_path == NULL
		&& reference_query == NULL )
	{
		tcsncpy( buffer, base_uri, length - 1 );

		if( reference_fragment != NULL )
		{
			length -= tcslen(buffer);
			if ( length > 1 )
			{
				tcsncat( buffer, T( "#" ), length - 1 );
				if ( length > 2 )
				{
					tcsncat( buffer, reference_fragment, length - 1 );
				}
			}
		}
	}
	else if( reference_scheme != NULL )
	{
		tcsncpy( buffer, reference_uri, length - 1 );
	}
	else
	{
		parse_uri(
			base_uri,
			base_buffer,
			sizeof( base_buffer ),
			&base_scheme,
			&base_authority,
			&base_path,
			&base_query,
			&base_fragment );

		result_scheme = base_scheme;

		if( reference_authority != NULL )
		{
			result_authority = reference_authority;
		}
		else
		{
			result_authority = base_authority;

			if( reference_path != NULL 
				&& ( reference_path[ 0 ] == T( '/' ) 
					|| reference_path[ 0 ] == T( '\\' ) ) )
			{
				result_path = reference_path;
			}
			else
			{
				XML_Char* p = NULL;
				
				result_path = path_buffer;

				path_buffer[ 0 ] = 0;

				p = tcsrchr( base_path, T( '/' ) );

				if( p == NULL )
				{
					p = tcsrchr( base_path, T( '\\' ) );
				}

				if( p != NULL )
				{
					XML_Char* s = base_path;
					XML_Char* d = path_buffer;
					XML_Char* endp = d + 255;
					
					while( s <= p )
					{
						if (d < endp)
							*d++ = *s++;
					}

					*d++ = 0;
				}

				if( reference_path != NULL )
				{
					tcsncat( path_buffer, reference_path, 255 );
				}

				{
					/* remove all occurrences of "./" */

					XML_Char* p = path_buffer;
					XML_Char* s = path_buffer;

					while( *s != 0 )
					{
						if( *s == T( '/' ) || *s == T( '\\' ) )
						{
							if( p == ( s - 1 ) && *p == T( '.' ) )
							{
								XML_Char* d = p;
								XML_Char* endp = path_buffer + 255;

								++s;

								while( *s != 0 )
								{
									if (d < endp)
										*d++ = *s++;
								}

								*d = 0;
								s = p;
							}
							else
							{
								p = s + 1;
							}
						}

						++s;
					}

					/* if the path ends with ".", remove it */

					if( p == ( s - 1 ) && *p == T( '.' ) )
					{
						*p = 0;
					}
				}

				{
					/* remove all occurrences of "<segment>/../" */

					XML_Char* s = path_buffer;
					XML_Char* p = NULL;
					XML_Char* p2 = NULL;
					XML_Char* p0 = NULL;

					while( *s != 0 )
					{
						if( *s != T( '/' ) && *s != T( '\\' ) )
						{
							if( p == NULL )
							{
								p = s;
							}
							else if( p2 == NULL )
							{
								p2 = s;
							}
						}
						else
						{
							if( p != NULL && p2 != NULL )
							{
								if( p2 == ( s - 2 )
									&& *p2 == T( '.' )
									&& *( p2 + 1 ) == T( '.' ) )
								{

									if( *p != T( '.' )
										&& *( p + 1 ) != T( '.' ) )
									{
										XML_Char* d = p;
										XML_Char* endp = path_buffer + 255;

										++s;

										while( *s != 0 )
										{
											if (d < endp)
												*d++ = *s++;
										}

										*d = 0;

										if( p0 < p )
										{
											s = p - 1;

											p = p0;
											p2 = NULL;
										}
										else
										{
											s = path_buffer;
											p = NULL;
											p2 = NULL;
											p0 = NULL;
										}
									}
								}
								else
								{
									p0 = p;
									p = p2;
									p2 = NULL;
								}
							}
						}

						++s;
					}

					/* if the path ends with "<segment>/..", remove it */

					if( p2 == ( s - 2 )
						&& *p2 == T( '.' )
						&& *( p2 + 1 ) == T( '.' ) )
					{
						if( p != NULL )
						{
							*p = 0;
						}
					}
				}
			}
		}

		if( result_scheme != NULL )
		{
			tcscpy( buffer, result_scheme );
			tcscat( buffer, T( ":" ) );
		}

		if( result_authority != NULL )
		{
			tcscat( buffer, T( "//" ) );
			tcscat( buffer, result_authority );
		}

		if( result_path != NULL )
		{
			tcscat( buffer, result_path );
		}

		if( reference_query != NULL )
		{
			tcscat( buffer, T( "?" ) );
			tcscat( buffer, reference_query );
		}

		if( reference_fragment != NULL )
		{
			tcscat( buffer, T( "#" ) );
			tcscat( buffer, reference_fragment );
		}
	}
}

	int
is_valid_id(
	const  XML_Char*  id )
{
	int result = FALSE;
	const XML_Char* p = id;

	if( id != NULL )
	{
		if( istalpha( *p )
			|| *p == T( '_' )
			|| *p == T( ':' ) )
		{
			result = TRUE;

			while( result != FALSE && *( ++p ) != 0 )
			{
				if( ! ( istalnum( *p ) 
						|| *p == T( '.' ) 
						|| *p == T( '-' )
						|| *p == T( '_' )
						|| *p == T( ':' ) ) )
				{
					result = FALSE;
				}
			}
		}
	}

	return result;
}

	void
resolve_id(
	      _rdf_parser*  rdf_parser,
	const  XML_Char*    id,
	       XML_Char*    buffer,
		   size_t       length )
{
	XML_Char id_buffer[ 256 ];

	if( is_valid_id( id ) == TRUE )
	{
		stprintf( id_buffer, T( "#%s" ), id );
	}
	else
	{
		report_warning( rdf_parser, T( "bad ID attribute: \"%s\"" ), id );

		tcscpy( id_buffer, T( "#_bad_ID_attribute_" ) );
	}

	resolve_uri_reference( rdf_parser->base_uri, id_buffer, buffer, length );
}

    void 
split_name( 
    const  XML_Char*   name, 
           XML_Char*   buffer, 
           size_t      len,
           XML_Char**  namespace_uri, 
           XML_Char**  local_name )
{
    XML_Char* separator;
    static XML_Char nul = 0;

    tcsncpy( buffer, name, len );

    if( buffer[ len - 1 ] == 0 )
    {
        if( ( separator = tcschr( buffer, NAMESPACE_SEPARATOR_CHAR ) ) != 0 )
        {
            *namespace_uri = buffer;
            *separator = 0;
            *local_name = separator + 1;
        }
        else
        {
            if( ( buffer[ 0 ] == T( 'x' ) )
                && ( buffer[ 1 ] == T( 'm' ) )
                && ( buffer[ 2 ] == T( 'l' ) )
                && ( buffer[ 3 ] == T( ':' ) ) )
            {
                *namespace_uri = XML_NAMESPACE_URI;
                *local_name = &buffer[ 4 ];
            }
            else
            {
                *namespace_uri = &nul;
                *local_name = buffer;
            }
        }
    }
    else
    {
        assert( ! "buffer overflow" );
    }
}

    void 
generate_anonymous_uri( 
    _rdf_parser*  rdf_parser, 
     XML_Char*    buf,
     size_t       len )
{
    XML_Char id[ 64 ];
    
	++rdf_parser->anonymous_id;

	if( buf != NULL )
	{
	    stprintf( id, T( "#genid%d" ), rdf_parser->anonymous_id );
		resolve_uri_reference( rdf_parser->base_uri, id, buf, len );
	}
}

    void 
report_statement( 
          _rdf_parser*      rdf_parser, 
           RDF_SubjectType  subject_type, 
    const  XML_Char*        subject, 
    const  XML_Char*        predicate, 
           int              ordinal, 
           RDF_ObjectType   object_type, 
    const  XML_Char*        object,
    const  XML_Char*        xml_lang,
    const  XML_Char*        bag_id,
           int*             statements,
    const  XML_Char*        statement_id )
{
    RDF_SubjectType statement_id_type = RDF_SUBJECT_TYPE_URI;
    XML_Char statement_id_buffer[ 256 ];
	XML_Char predicate_buffer[ 256 ];

    if( rdf_parser->statement_handler )
    {
        ( *rdf_parser->statement_handler )(
            rdf_parser->user_data,
            subject_type,
            subject,
            predicate,
            ordinal,
            object_type,
            object,
            xml_lang );

        if( bag_id )
        {
            if( *statements == 0 )
            {
                report_statement(
                    rdf_parser,
                    RDF_SUBJECT_TYPE_URI,
                    bag_id,
                    RDF_NAMESPACE_URI RDF_TYPE,
                    0,
                    RDF_OBJECT_TYPE_RESOURCE,
                    RDF_NAMESPACE_URI RDF_BAG,
                    NULL,
                    NULL,
                    NULL,
                    NULL );
            }

            if( ! statement_id )
            {
                statement_id_type = RDF_SUBJECT_TYPE_ANONYMOUS;
                generate_anonymous_uri( 
                    rdf_parser, 
                    statement_id_buffer, 
                    sizeof( statement_id_buffer ) );
                statement_id = statement_id_buffer;
            }

			stprintf( predicate_buffer, RDF_NAMESPACE_URI T( "_%d" ), ++( *statements ) );

            report_statement(
                rdf_parser,
                RDF_SUBJECT_TYPE_URI,
                bag_id,
                predicate_buffer,
                *statements,
                RDF_OBJECT_TYPE_RESOURCE,
                statement_id,
                NULL,
                NULL,
                NULL,
                NULL );
        }

        if( statement_id )
        {
            /* rdf:type = rdf:Statement */
            report_statement(
                rdf_parser,
                statement_id_type,
                statement_id,
                RDF_NAMESPACE_URI RDF_TYPE,
                0,
                RDF_OBJECT_TYPE_RESOURCE,
                RDF_NAMESPACE_URI RDF_STATEMENT,
                NULL,
                NULL,
                NULL,
                NULL );

            /* rdf:subject */
            report_statement( 
                rdf_parser,
                statement_id_type,
                statement_id,
                RDF_NAMESPACE_URI RDF_SUBJECT,
                0,
                RDF_OBJECT_TYPE_RESOURCE,
                subject,
                NULL,
                NULL,
                NULL,
                NULL );

            /* rdf:predicate */
            report_statement(
                rdf_parser,
                statement_id_type,
                statement_id,
                RDF_NAMESPACE_URI RDF_PREDICATE,
                0,
                RDF_OBJECT_TYPE_RESOURCE,
                predicate,
                NULL,
                NULL,
                NULL,
                NULL );

            /* rdf:object */
            report_statement(
                rdf_parser,
                statement_id_type,
                statement_id,
                RDF_NAMESPACE_URI RDF_OBJECT,
                0,
                object_type,
                object,
                NULL,
                NULL,
                NULL,
                NULL );
        }
    }
}

    void
report_start_parse_type_literal( 
    _rdf_parser*  rdf_parser )
{
    if( rdf_parser->start_parse_type_literal_handler )
    {
        ( *rdf_parser->start_parse_type_literal_handler )(
            rdf_parser->user_data );
    }
}

    void
report_end_parse_type_literal( 
    _rdf_parser*  rdf_parser )
{
    if( rdf_parser->end_parse_type_literal_handler )
    {
        ( *rdf_parser->end_parse_type_literal_handler )(
            rdf_parser->user_data );
    }
}

    void 
handle_property_attributes( 
          _rdf_parser*      rdf_parser, 
           RDF_SubjectType  subject_type, 
    const  XML_Char*        subject, 
    const  XML_Char**       attributes, 
    const  XML_Char*        xml_lang,
    const  XML_Char*        bag_id, 
           int*             statements )
{
    int i;

    XML_Char attribute[ 256 ];
    XML_Char predicate[ 256 ];

    XML_Char* attribute_namespace_uri;
    XML_Char* attribute_local_name;
    const XML_Char* attribute_value;

    int ordinal;

    for( i = 0; attributes[ i ]; i += 2 )
    {
        split_name( 
            attributes[ i ], 
            attribute, 
            sizeof( attribute ),
            &attribute_namespace_uri, 
            &attribute_local_name );

        attribute_value = attributes[ i + 1 ];

        tcscpy( predicate, attribute_namespace_uri );
        tcscat( predicate, attribute_local_name );

        if( tcscmp( RDF_NAMESPACE_URI, attribute_namespace_uri ) == 0 )
        {
            if( is_rdf_property_attribute_literal( attribute_local_name ) )
            {
                report_statement( rdf_parser, 
                    subject_type, 
                    subject, 
                    predicate, 
                    0,
                    RDF_OBJECT_TYPE_LITERAL, 
                    attribute_value,
                    xml_lang,
                    bag_id,
                    statements,
                    NULL );
            }
            else if( is_rdf_property_attribute_resource( attribute_local_name ) )
            {
                report_statement( rdf_parser, 
                    subject_type, 
                    subject, 
                    predicate, 
                    0,
                    RDF_OBJECT_TYPE_RESOURCE, 
                    attribute_value,
                    NULL,
                    bag_id,
                    statements,
                    NULL );
            }
            else if( ( ordinal = is_rdf_ordinal( attribute_local_name ) ) != 0 )
            {
                report_statement( rdf_parser, 
                    subject_type, 
                    subject, 
                    predicate, 
                    ordinal,
                    RDF_OBJECT_TYPE_LITERAL, 
                    attribute_value,
                    xml_lang,
                    bag_id,
                    statements,
                    NULL );
            }
        }
        else if( tcscmp( XML_NAMESPACE_URI, attribute_namespace_uri ) == 0 )
        {
            /* do nothing */
        }
        else if( *attribute_namespace_uri )
        {
            /* is it required that property attributes be in an explicit namespace? */

            report_statement( rdf_parser, 
                subject_type, 
                subject, 
                predicate, 
                0,
                RDF_OBJECT_TYPE_LITERAL, 
                attribute_value,
                xml_lang,
                bag_id,
                statements,
                NULL );
        }
    }
}

    void 
report_start_element( 
          _rdf_parser*  rdf_parser, 
    const  XML_Char*    name, 
    const  XML_Char**   attributes )
{
    if( rdf_parser->start_element_handler )
    {
        ( *rdf_parser->start_element_handler )(
            rdf_parser->user_data,
            name,
            attributes );
    }
}

    void 
report_end_element( 
          _rdf_parser*  rdf_parser, 
    const  XML_Char*    name )
{
    if( rdf_parser->end_element_handler )
    {
        ( *rdf_parser->end_element_handler )(
            rdf_parser->user_data,
            name );
    }
}

    void
report_character_data(
          _rdf_parser*  rdf_parser,
    const  XML_Char*    s,
    int len )
{
    if( rdf_parser->character_data_handler )
    {
        ( *rdf_parser->character_data_handler )(
            rdf_parser->user_data,
            s,
            len );
    }
}

    void 
report_warning( 
          _rdf_parser*  rdf_parser, 
    const  XML_Char*    warning, 
           ... )
{
    va_list arguments;
    XML_Char buffer[ 256 ];

    /* rdf_parser->top->state = IN_UNKNOWN; */

    if( rdf_parser->warning_handler )
    {
        va_start( arguments, warning );

        if( warning )
        {
            vstprintf( buffer, warning, arguments );

            ( *rdf_parser->warning_handler )(
                rdf_parser->user_data,
                buffer );
        }

        va_end( arguments );
    }
}

    void
handle_resource_element( 
          _rdf_parser*   rdf_parser, 
    const  XML_Char*     namespace_uri, 
    const  XML_Char*     local_name, 
    const  XML_Char**    attributes, 
          _rdf_element*  parent )
{
    int subjects_found = 0;

    const XML_Char* id = NULL;
    const XML_Char* about = NULL;
    const XML_Char* about_each = NULL;
    const XML_Char* about_each_prefix = NULL;

    const XML_Char* bag_id = NULL;

    int i;

    XML_Char attribute[ 256 ];

    XML_Char* attribute_namespace_uri;
    XML_Char* attribute_local_name;
    const XML_Char* attribute_value;

    XML_Char id_buffer[ 256 ];

    XML_Char type[ 256 ];

    rdf_parser->top->has_property_attributes = FALSE;
    rdf_parser->top->has_member_attributes = FALSE;

    /* examine each attribute for the standard RDF "keywords" */
    for( i = 0; attributes[ i ]; i += 2 )
    {
        split_name( 
            attributes[ i ], 
            attribute, 
            sizeof( attribute ),
            &attribute_namespace_uri, 
            &attribute_local_name );

        attribute_value = attributes[ i + 1 ];

        /* if the attribute is not in any namespace
           or the attribute is in the RDF namespace */
        if( ( *attribute_namespace_uri == 0 )
            || ( tcscmp( attribute_namespace_uri, RDF_NAMESPACE_URI ) == 0 ) )
        {
            if( tcscmp( attribute_local_name, RDF_ID ) == 0 )
            {
                id = attribute_value;
                ++subjects_found;
            }
            else if( tcscmp( attribute_local_name, RDF_ABOUT ) == 0 )
            {
                about = attribute_value;
                ++subjects_found;
            }
            else if( tcscmp( attribute_local_name, RDF_ABOUT_EACH ) == 0 )
            {
                about_each = attribute_value;
                ++subjects_found;
            }
            else if( tcscmp( attribute_local_name, RDF_ABOUT_EACH_PREFIX ) == 0 )
            {
                about_each_prefix = attribute_value;
                ++subjects_found;
            }
            else if( tcscmp( attribute_local_name, RDF_BAG_ID ) == 0 )
            {
                bag_id = attribute_value;
            }
            else if( is_rdf_property_attribute( attribute_local_name ) )
            {
                rdf_parser->top->has_property_attributes = TRUE;
            }
            else if( is_rdf_ordinal( attribute_local_name ) )
            {
                rdf_parser->top->has_property_attributes = TRUE;
                rdf_parser->top->has_member_attributes = TRUE;
            }
            else
            {
                report_warning( 
                    rdf_parser, 
                    T( "unknown or out of context rdf attribute: %s" ), 
                    attribute_local_name );
            }
        }
        else if( tcscmp( attribute_namespace_uri, XML_NAMESPACE_URI ) == 0 )
        {
            if( tcscmp( attribute_local_name, XML_LANG ) == 0 )
            {
                rdf_parser->top->xml_lang = tcsdup( attribute_value );
            }
        }
        else if( *attribute_namespace_uri )
        {
            rdf_parser->top->has_property_attributes = TRUE;
        }
    }

    /* if no subjects were found, generate one. */
    if( subjects_found == 0 )
    {
        generate_anonymous_uri( rdf_parser, id_buffer, sizeof( id_buffer ) );
        ASSIGN_STRING( rdf_parser->top->subject, id_buffer );
        rdf_parser->top->subject_type = RDF_SUBJECT_TYPE_ANONYMOUS;
    }
    else if( subjects_found > 1 )
    {
        report_warning( 
            rdf_parser, 
            "ID, about, aboutEach, and aboutEachPrefix are mutually exclusive" );
        return;
    }
    else if( id )
    {
        resolve_id( rdf_parser, id, id_buffer, sizeof( id_buffer ) );
        rdf_parser->top->subject_type = RDF_SUBJECT_TYPE_URI;
        ASSIGN_STRING( rdf_parser->top->subject, id_buffer );
    }
    else if( about )
    {
		resolve_uri_reference( rdf_parser->base_uri, about, id_buffer, sizeof( id_buffer ) );
        rdf_parser->top->subject_type = RDF_SUBJECT_TYPE_URI;
        ASSIGN_STRING( rdf_parser->top->subject, id_buffer );
    }
    else if( about_each )
    {
        rdf_parser->top->subject_type = RDF_SUBJECT_TYPE_DISTRIBUTED;
        ASSIGN_STRING( rdf_parser->top->subject, about_each );
    }
    else if( about_each_prefix )
    {
        rdf_parser->top->subject_type = RDF_SUBJECT_TYPE_PREFIX;
        ASSIGN_STRING( rdf_parser->top->subject, about_each_prefix );
    }

    /* if the subject is empty, assign it the document uri */
    if( rdf_parser->top->subject[ 0 ] == 0 )
    {
        int len = 0;

        ASSIGN_STRING( rdf_parser->top->subject, rdf_parser->base_uri );

        /* now remove the trailing '#' */

        len = tcslen( rdf_parser->top->subject );

        if( len > 0 )
        {
            rdf_parser->top->subject[ len - 1 ] = 0;
        }
    }

    if( bag_id )
    {
        resolve_id( rdf_parser, bag_id, id_buffer, sizeof( id_buffer ) );
        ASSIGN_STRING( rdf_parser->top->bag_id, id_buffer );
    }

    /* only report the type for non-rdf:Description elements. */
    if( tcscmp( local_name, RDF_DESCRIPTION ) 
        || tcscmp( namespace_uri, RDF_NAMESPACE_URI ) )
    {
        tcscpy( type, namespace_uri );
        tcscat( type, local_name );        

        report_statement(
            rdf_parser,
            rdf_parser->top->subject_type,
            rdf_parser->top->subject,
            RDF_NAMESPACE_URI RDF_TYPE,
            0,
            RDF_OBJECT_TYPE_RESOURCE,
            type,
            NULL,
            rdf_parser->top->bag_id,
            &rdf_parser->top->statements,
            NULL );

    }

    /* if this element is the child of some property,
       report the appropriate statement. */
    if( parent )
    {
        report_statement(
            rdf_parser,
            parent->parent->subject_type,
            parent->parent->subject,
            parent->predicate,
            parent->ordinal,
            RDF_OBJECT_TYPE_RESOURCE,
            rdf_parser->top->subject,
            NULL,
            parent->parent->bag_id,
            &parent->parent->statements,
            parent->statement_id );

    }

    if( rdf_parser->top->has_property_attributes )
    {
        handle_property_attributes( rdf_parser, 
            rdf_parser->top->subject_type, 
            rdf_parser->top->subject, 
            attributes,
            rdf_parser->top->xml_lang,
            rdf_parser->top->bag_id,
            &rdf_parser->top->statements );
    }
}

    void
handle_property_element( 
          _rdf_parser*  rdf_parser, 
    const  XML_Char*    namespace_uri, 
    const  XML_Char*    local_name, 
    const  XML_Char**   attributes )
{
    XML_Char buffer[ 256 ];

    int i;

    XML_Char* attribute_namespace_uri;
    XML_Char* attribute_local_name;
    const XML_Char* attribute_value = NULL;

    const XML_Char* resource = NULL;
    const XML_Char* statement_id = NULL;
    const XML_Char* bag_id = NULL;
    const XML_Char* parse_type = NULL;

    rdf_parser->top->ordinal = 0;

    if( ( tcscmp( namespace_uri, RDF_NAMESPACE_URI ) == 0 ) )
    {
        if( ( rdf_parser->top->ordinal = is_rdf_ordinal( local_name ) ) != 0 )
        {
            if( rdf_parser->top->ordinal > rdf_parser->top->parent->members )
            {
                rdf_parser->top->parent->members = rdf_parser->top->ordinal;
            }
        }
        else if( ! is_rdf_property_element( local_name ) )
        {
            report_warning( 
                rdf_parser, 
                "unknown or out of context rdf property element: %s", 
                local_name );
            return;
        }
    }

    tcscpy( buffer, namespace_uri );

    if( ( tcscmp( namespace_uri, RDF_NAMESPACE_URI ) == 0 ) 
        && ( tcscmp( local_name, RDF_LI ) == 0 ) )
    {
        XML_Char ordinal[ 64 ];

        rdf_parser->top->ordinal = ++rdf_parser->top->parent->members;

        ordinal[ 0 ] = T( '_' );
        sprintf(&ordinal[1], "%d", rdf_parser->top->ordinal);
        tcscat( buffer, ordinal );
    }
    else
    {
        tcscat( buffer, local_name );
    }

    ASSIGN_STRING( rdf_parser->top->predicate, buffer );

    rdf_parser->top->has_property_attributes = FALSE;
    rdf_parser->top->has_member_attributes = FALSE;

    for( i = 0; attributes[ i ]; i += 2 )
    {
        split_name( 
            attributes[ i ], 
            buffer, 
            sizeof( buffer ),
            &attribute_namespace_uri, 
            &attribute_local_name );

        attribute_value = attributes[ i + 1];

        /* if the attribute is not in any namespace
           or the attribute is in the RDF namespace */
        if( ( *attribute_namespace_uri == 0 )
            || ( tcscmp( attribute_namespace_uri, RDF_NAMESPACE_URI ) == 0 ) )
        {
            if( tcscmp( attribute_local_name, RDF_ID ) == 0 )
            {
                statement_id = attribute_value;
            }
            else if( tcscmp( attribute_local_name, RDF_PARSE_TYPE ) == 0 )
            {
                parse_type = attribute_value;
            }
            else if( tcscmp( attribute_local_name, RDF_RESOURCE ) == 0 )
            {
                resource = attribute_value;
            }
            else if( tcscmp( attribute_local_name, RDF_BAG_ID ) == 0 )
            {
                bag_id = attribute_value;
            }
            else if( is_rdf_property_attribute( attribute_local_name ) )
            {
                rdf_parser->top->has_property_attributes = TRUE;
            }
            else
            {
                report_warning( 
                    rdf_parser, 
                    "unknown rdf attribute: %s", 
                    attribute_local_name );
                return;
            }
        }
        else if( tcscmp( attribute_namespace_uri, XML_NAMESPACE_URI ) == 0 )
        {
            if( tcscmp( attribute_local_name, XML_LANG ) == 0 )
            {
                rdf_parser->top->xml_lang = tcsdup( attribute_value );
            }
        }
        else if( *attribute_namespace_uri )
        {
            rdf_parser->top->has_property_attributes = TRUE;
        }
    }

    /* this isn't allowed by the M&S but I think it should be */
    if( statement_id && resource )
    {
        report_warning( 
            rdf_parser, 
            T( "rdf:ID and rdf:resource are mutually exclusive" ) );
        return;
    }

    if( statement_id )
    {
		resolve_id( rdf_parser, statement_id, buffer, sizeof( buffer ) );
        ASSIGN_STRING( rdf_parser->top->statement_id, buffer );
    }

    if( parse_type )
    {
        if( resource )
        {
            report_warning( 
                rdf_parser, 
                T( "property elements with rdf:parseType do not allow rdf:resource" ) );
            return;
        }

        if( bag_id )
        {
            report_warning( 
                rdf_parser, 
                T( "property elements with rdf:parseType do not allow rdf:bagID" ) );
            return;
        }

        if( rdf_parser->top->has_property_attributes )
        {
            report_warning( 
                rdf_parser, 
                T( "property elements with rdf:parseType do not allow property attributes" ) );
            return;
        }

        if( tcscmp( attribute_value, RDF_PARSE_TYPE_RESOURCE ) == 0 )
        {
            generate_anonymous_uri( rdf_parser, buffer, sizeof( buffer ) );

            /* since we are sure that this is now a resource property we can report it */
            report_statement(
                rdf_parser,
                rdf_parser->top->parent->subject_type,
                rdf_parser->top->parent->subject,
                rdf_parser->top->predicate,
                0,
                RDF_OBJECT_TYPE_RESOURCE,
                buffer,
                NULL,
                rdf_parser->top->parent->bag_id,
                &rdf_parser->top->parent->statements,
                statement_id );

            push_element( rdf_parser );

            rdf_parser->top->state = IN_PROPERTY_PARSE_TYPE_RESOURCE;
            rdf_parser->top->subject_type = RDF_SUBJECT_TYPE_ANONYMOUS;
            ASSIGN_STRING( rdf_parser->top->subject, buffer );
            FREE_STRING( rdf_parser->top->bag_id );
        }
        else
        {
            report_statement(
                rdf_parser,
                rdf_parser->top->parent->subject_type,
                rdf_parser->top->parent->subject,
                rdf_parser->top->predicate,
                0,
                RDF_OBJECT_TYPE_XML,
                NULL,
                NULL,
                rdf_parser->top->parent->bag_id,
                &rdf_parser->top->parent->statements,
                statement_id );

            rdf_parser->top->state = IN_PROPERTY_PARSE_TYPE_LITERAL;
            report_start_parse_type_literal( rdf_parser );
        }
    }
    else if( resource || bag_id || rdf_parser->top->has_property_attributes )
    {
        RDF_SubjectType subject_type;

        if( resource != NULL )
        {
            subject_type = RDF_SUBJECT_TYPE_URI;
            resolve_uri_reference( rdf_parser->base_uri, resource, buffer, sizeof( buffer ) );
        }
        else
        {
            subject_type = RDF_SUBJECT_TYPE_ANONYMOUS;
			generate_anonymous_uri( rdf_parser, buffer, sizeof( buffer ) );
        }

        rdf_parser->top->state = IN_PROPERTY_EMPTY_RESOURCE;

        /* since we are sure that this is now a resource property we can report it. */
        report_statement(
            rdf_parser,
            rdf_parser->top->parent->subject_type,
            rdf_parser->top->parent->subject,
            rdf_parser->top->predicate,
            rdf_parser->top->ordinal,
            RDF_OBJECT_TYPE_RESOURCE,
            buffer,
            NULL,
            rdf_parser->top->parent->bag_id,
            &rdf_parser->top->parent->statements,
            NULL ); /* should we allow IDs? */

        if( bag_id )
        {
            resolve_id( rdf_parser, bag_id, buffer, sizeof( buffer ) );
            ASSIGN_STRING( rdf_parser->top->bag_id, buffer);
        }

        if( rdf_parser->top->has_property_attributes )
        {
            handle_property_attributes( 
                rdf_parser,
                subject_type,
                buffer,
                attributes,
                rdf_parser->top->xml_lang,
                rdf_parser->top->bag_id,
                &rdf_parser->top->statements );
        }
    }
}

    void 
start_element_handler( 
           void*       user_data, 
    const  XML_Char*   name, 
    const  XML_Char**  attributes )
{
    _rdf_parser* rdf_parser = ( _rdf_parser* )user_data;

    XML_Char buffer[ 256 ];

    XML_Char* namespace_uri;
    XML_Char* local_name;

/*
	if( rdf_parser->top != NULL && rdf_parser->top->state != IN_TOP_LEVEL )
	{
		++rdf_parser->anonymous_id;
	}
*/

    push_element( rdf_parser );

    split_name( 
        name, 
        buffer, 
        sizeof( buffer ),
        &namespace_uri, 
        &local_name );

    switch( rdf_parser->top->state )
    {
    case IN_TOP_LEVEL:
        if( tcscmp( RDF_NAMESPACE_URI NAMESPACE_SEPARATOR_STRING RDF_RDF, name ) == 0 )
        {
            rdf_parser->top->state = IN_RDF;
        }
        else
        {
            report_start_element( rdf_parser, name, attributes );
        }
        break;
    case IN_RDF:
        rdf_parser->top->state = IN_DESCRIPTION;
        handle_resource_element( rdf_parser, namespace_uri, local_name, attributes, NULL );
        break;
    case IN_DESCRIPTION:
    case IN_PROPERTY_PARSE_TYPE_RESOURCE:
        rdf_parser->top->state = IN_PROPERTY_UNKNOWN_OBJECT;
        handle_property_element( rdf_parser, namespace_uri, local_name, attributes );
        break;
    case IN_PROPERTY_UNKNOWN_OBJECT:
        /* if we're in a property with an unknown object type and we encounter
           an element, the object must be a resource, */
        FREE_STRING( rdf_parser->top->data );
        rdf_parser->top->parent->state = IN_PROPERTY_RESOURCE;
        rdf_parser->top->state = IN_DESCRIPTION;
        handle_resource_element( rdf_parser, 
            namespace_uri, 
            local_name, 
            attributes, 
            rdf_parser->top->parent );
        break;
    case IN_PROPERTY_LITERAL:
        report_warning( rdf_parser, "no markup allowed in literals" );
        break;
    case IN_PROPERTY_PARSE_TYPE_LITERAL:
        rdf_parser->top->state = IN_XML;
        /* fall through */
    case IN_XML:
        report_start_element( rdf_parser, name, attributes );
        break;
    case IN_PROPERTY_RESOURCE:
        report_warning( 
            rdf_parser, 
            T( "only one element allowed inside a property element" ) );
        break;
    case IN_PROPERTY_EMPTY_RESOURCE:
        report_warning( 
            rdf_parser, 
            T( "no content allowed in property with rdf:resource, rdf:bagID, or property attributes" ) );
        break;
    case IN_UNKNOWN:
        break;
    }
}

/* 
    this is only called when we're in the IN_PROPERTY_UNKNOWN_OBJECT state.
    the only time we won't know what type of object a statement has is
    when we encounter property statements without property attributes or
    content:

        <foo:property />
        <foo:property ></foo:property>
        <foo:property>    </foo:property>

    notice that the state doesn't switch to IN_PROPERTY_LITERAL when
    there is only whitespace between the start and end tags. this isn't
    a very useful statement since the object is anonymous and can't
    have any statements with it as the subject but it is allowed.
*/
    void 
end_empty_resource_property(
    _rdf_parser*  rdf_parser )
{
	XML_Char buffer[ 256 ];

	generate_anonymous_uri( rdf_parser, buffer, sizeof( buffer ) );

    report_statement(
        rdf_parser,
        rdf_parser->top->parent->subject_type,
        rdf_parser->top->parent->subject,
        rdf_parser->top->predicate,
        rdf_parser->top->ordinal,
        RDF_OBJECT_TYPE_RESOURCE,
        buffer,
        rdf_parser->top->xml_lang,
        rdf_parser->top->parent->bag_id,
        &rdf_parser->top->parent->statements, 
        rdf_parser->top->statement_id );
}

/*
    property elements with text only as content set the state to
    IN_PROPERTY_LITERAL. as character data is received from expat,
    it is saved in a buffer and reported when the end tag is
    received.
*/
    void 
end_literal_property( 
    _rdf_parser*  rdf_parser )
{
    report_statement(
        rdf_parser,
        rdf_parser->top->parent->subject_type,
        rdf_parser->top->parent->subject,
        rdf_parser->top->predicate,
        rdf_parser->top->ordinal,
        RDF_OBJECT_TYPE_LITERAL,
        rdf_parser->top->data,
        rdf_parser->top->xml_lang,
        rdf_parser->top->parent->bag_id,
        &rdf_parser->top->parent->statements, 
        rdf_parser->top->statement_id );
}

    void 
end_element_handler( 
          void*      user_data, 
    const XML_Char*  name )
{
    _rdf_parser* rdf_parser = ( _rdf_parser* )user_data;

    switch( rdf_parser->top->state )
    {
    case IN_TOP_LEVEL:
        /* fall through */
    case IN_XML:
        report_end_element( rdf_parser, name );
        break;
    case IN_PROPERTY_UNKNOWN_OBJECT:
        end_empty_resource_property( rdf_parser );
        break;
    case IN_PROPERTY_LITERAL:
        end_literal_property( rdf_parser );
        break;
    case IN_PROPERTY_PARSE_TYPE_RESOURCE:
        pop_element( rdf_parser );
        break;
    case IN_PROPERTY_PARSE_TYPE_LITERAL:
        report_end_parse_type_literal( rdf_parser );
        break;
    case IN_RDF:
    case IN_DESCRIPTION:
    case IN_PROPERTY_RESOURCE:
    case IN_PROPERTY_EMPTY_RESOURCE:
    case IN_UNKNOWN:
        break;
    }

    pop_element( rdf_parser );
}

    void 
character_data_handler( 
           void*      user_data, 
    const  XML_Char*  s, 
           int        len )
{
    _rdf_parser* rdf_parser = ( _rdf_parser* )user_data;

    int n;
    int i;

    switch( rdf_parser->top->state )
    {
    case IN_PROPERTY_LITERAL:
    case IN_PROPERTY_UNKNOWN_OBJECT:
        if( rdf_parser->top->data ) 
        {
            n = tcslen( rdf_parser->top->data );
            rdf_parser->top->data = 
                realloc( rdf_parser->top->data, n + len + sizeof( XML_Char ) );
            tcsncat( rdf_parser->top->data, s, len );
            rdf_parser->top->data[ n + len ] = 0;
        }
        else
        {
            rdf_parser->top->data = malloc( len + sizeof( XML_Char ) );
            tcsncpy( rdf_parser->top->data, s, len );
            rdf_parser->top->data[len] = 0;
        }

        if( rdf_parser->top->state == IN_PROPERTY_UNKNOWN_OBJECT )
        {
            /* look for non-whitespace */
            for( i = 0; ( i < len ) && ( istspace( s[ i ] ) ); ++i );

            /* if we found non-whitespace, this is a literal */
            if( i < len )
            {
                rdf_parser->top->state = IN_PROPERTY_LITERAL;
            }
        }

        break;
    case IN_TOP_LEVEL:
    case IN_PROPERTY_PARSE_TYPE_LITERAL:
    case IN_XML:
        report_character_data(
            rdf_parser,
            s,
            len );
        break;
    case IN_RDF:
    case IN_DESCRIPTION:
    case IN_PROPERTY_RESOURCE:
    case IN_PROPERTY_EMPTY_RESOURCE:
    case IN_PROPERTY_PARSE_TYPE_RESOURCE:
    case IN_UNKNOWN:
        break;
    }
}

/* public functions */

    RDF_Parser
RDF_ParserCreate( 
    const XML_Char*  encoding )
{
    XML_Parser parser;

    /* check for out of memory */
    _rdf_parser* rdf_parser = calloc( 1, sizeof( _rdf_parser ) );

    /* check for out of memory */
    parser = XML_ParserCreateNS( encoding, NAMESPACE_SEPARATOR_CHAR );
    rdf_parser->xml_parser = parser;

    XML_SetUserData( parser, rdf_parser );
    XML_SetElementHandler( parser, start_element_handler, end_element_handler );
    XML_SetCharacterDataHandler( parser, character_data_handler );

    return rdf_parser;
}

    void 
RDF_ParserFree( 
    RDF_Parser  parser )
{
    _rdf_parser* rdf_parser = ( _rdf_parser* )parser;

    XML_ParserFree( rdf_parser->xml_parser );
    
    FREE_STRING( rdf_parser->base_uri );

    delete_elements( rdf_parser );

    free( rdf_parser );
}

    void
RDF_SetUserData(
    RDF_Parser  parser,
    void*       user_data )
{
    ( ( _rdf_parser* )parser )->user_data = user_data;
}

    void*
RDF_GetUserData(
    RDF_Parser  parser )
{
    return ( ( _rdf_parser* )parser )->user_data;
}

    void
RDF_SetStatementHandler(
    RDF_Parser            parser,
    RDF_StatementHandler  handler )
{
    _rdf_parser* rdf_parser = ( _rdf_parser* )parser;
    rdf_parser->statement_handler = handler;
}

    void 
RDF_SetParseTypeLiteralHandler(
    RDF_Parser                        parser,
    RDF_StartParseTypeLiteralHandler  start,
    RDF_EndParseTypeLiteralHandler    end )
{
    _rdf_parser* rdf_parser = ( _rdf_parser* )parser;
    rdf_parser->start_parse_type_literal_handler = start;
    rdf_parser->end_parse_type_literal_handler = end;
}

    void
RDF_SetElementHandler(
    RDF_Parser               parser,
    XML_StartElementHandler  start,
    XML_EndElementHandler    end)
{
    _rdf_parser* rdf_parser = ( _rdf_parser* )parser;
    rdf_parser->start_element_handler = start;
    rdf_parser->end_element_handler = end;
}

    void
RDF_SetCharacterDataHandler(
    RDF_Parser                parser,
    XML_CharacterDataHandler  handler)
{
    _rdf_parser* rdf_parser = ( _rdf_parser* )parser;
    rdf_parser->character_data_handler = handler;
}

    void
RDF_SetWarningHandler(
    RDF_Parser          parser,
    RDF_WarningHandler  handler )
{
    _rdf_parser* rdf_parser = ( _rdf_parser* )parser;
    rdf_parser->warning_handler = handler;
}

    int 
RDF_Parse( 
           RDF_Parser  parser, 
    const  char*       s, 
           int         len, 
           int         is_final )
{
    _rdf_parser* rdf_parser = ( _rdf_parser* )parser;
    return XML_Parse( rdf_parser->xml_parser, s, len, is_final );
}

    XML_Parser
RDF_GetXmlParser(
    RDF_Parser  parser )
{
    return ( ( _rdf_parser* )parser )->xml_parser;
}

    int 
RDF_SetBase( 
    RDF_Parser       parser, 
    const XML_Char*  base )
{
    _rdf_parser* rdf_parser = ( _rdf_parser* )parser;
    XML_Char buffer[ 256 ];

    tcscpy( buffer, base );

/*
    if( buffer[ tcslen( buffer ) - 1 ] != T( '#' ) )
    {
        tcscat( buffer, T( "#" ) );
    }
*/

    /* check for out of memory */
    ASSIGN_STRING( rdf_parser->base_uri, buffer );

    return 0;
}

    const XML_Char*
RDF_GetBase( 
    RDF_Parser  parser )
{
    _rdf_parser* rdf_parser = ( _rdf_parser* )parser;
    return rdf_parser->base_uri;
}

	void
RDF_ResolveURI(
	       RDF_Parser  parser,
	const  XML_Char*   uri_reference,
	       XML_Char*   buffer,
	       size_t      length )
{
    _rdf_parser* rdf_parser = ( _rdf_parser* )parser;
	resolve_uri_reference( rdf_parser->base_uri, uri_reference, buffer, length );
}
