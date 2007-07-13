/*
 * MusicBrainz -- The Internet music metadatabase
 *
 * Copyright (C) 2006 Lukas Lalinsky
 *  
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 * 
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
 *
 * $Id: utils_private.h 9189 2007-06-20 19:41:06Z luks $
 */
 
#ifndef __MUSICBRAINZ3_UTILSPRIV_H__
#define __MUSICBRAINZ3_UTILSPRIV_H__

#include <string>
#include <vector>
#include <musicbrainz3/musicbrainz.h>

namespace MusicBrainz
{

#ifndef NDEBUG 
	void debug(const char *fmt, ...);
#else
	inline void debug(const char *fmt, ...) {}
#endif
	
	std::string intToString(const int i);
	int stringToInt(const std::string &s);

	std::string uriEscape(const std::string &uri);
	std::string urlEncode(const std::vector<std::pair<std::string, std::string> > &params);
	
}

#define SIMPLE_STRING_SETTER_GETTER(class, name, name2) \
	string \
	class::get##name() const \
	{ \
		return d->name2; \
	} \
	void \
	class::set##name(const string &value) \
	{ \
		d->name2 = value; \
	}

#define SIMPLE_INT_SETTER_GETTER(class, name, name2) \
	int \
	class::get##name() const \
	{ \
		return d->name2; \
	} \
	void \
	class::set##name(const int value) \
	{ \
		d->name2 = value; \
	}

#endif
