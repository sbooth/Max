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
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	 See the GNU
 * Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
 *
 * $Id: filters.cpp 8466 2006-09-05 08:59:44Z luks $
 */
 
#include <cstring>
#include <string>
#include <musicbrainz3/utils.h>
#include <musicbrainz3/filters.h>
#include "utils_private.h"

using namespace std;
using namespace MusicBrainz;

ArtistFilter::ParameterList
ArtistFilter::createParameters() const
{
	return parameters;
}

ArtistFilter &
ArtistFilter::name(const string &value)
{
	parameters.push_back(pair<string, string>(string("name"), value));
	return *this;
}

ArtistFilter &
ArtistFilter::limit(const int value)
{
	parameters.push_back(pair<string, string>(string("limit"), intToString(value)));
	return *this;
}

ReleaseFilter::ParameterList
ReleaseFilter::createParameters() const
{
	return parameters;
}

ReleaseFilter &
ReleaseFilter::title(const string &value)
{
	parameters.push_back(pair<string, string>(string("title"), value));
	return *this;
}

ReleaseFilter &
ReleaseFilter::discId(const string &value)
{
	parameters.push_back(pair<string, string>(string("discid"), value));
	return *this;
}

ReleaseFilter &
ReleaseFilter::releaseType(const string &value)
{
	string type = extractFragment(value);
	for (ParameterList::iterator i = parameters.begin(); i != parameters.end(); i++) {
		if (i->first == string("releasetypes")) {
			i->second += string(" ") + type;
			return *this;
		}
	}
	parameters.push_back(pair<string, string>(string("releasetypes"), type));
	return *this;
}

ReleaseFilter &
ReleaseFilter::artistName(const string &value)
{
	parameters.push_back(pair<string, string>(string("artist"), value));
	return *this;
}

ReleaseFilter &
ReleaseFilter::artistId(const string &value)
{
	parameters.push_back(pair<string, string>(string("artistid"), value));
	return *this;
}

ReleaseFilter &
ReleaseFilter::limit(const int value)
{
	parameters.push_back(pair<string, string>(string("limit"), intToString(value)));
	return *this;
}

TrackFilter::ParameterList
TrackFilter::createParameters() const
{
	return parameters;
}

TrackFilter &
TrackFilter::title(const string &value)
{
	parameters.push_back(pair<string, string>(string("title"), value));
	return *this;
}

TrackFilter &
TrackFilter::artistName(const string &value)
{
	parameters.push_back(pair<string, string>(string("artist"), value));
	return *this;
}

TrackFilter &
TrackFilter::artistId(const string &value)
{
	parameters.push_back(pair<string, string>(string("artistid"), value));
	return *this;
}

TrackFilter &
TrackFilter::releaseTitle(const string &value)
{
	parameters.push_back(pair<string, string>(string("release"), value));
	return *this;
}

TrackFilter &
TrackFilter::releaseId(const string &value)
{
	parameters.push_back(pair<string, string>(string("releaseid"), value));
	return *this;
}

TrackFilter &
TrackFilter::duration(const int value)
{
	parameters.push_back(pair<string, string>(string("duration"), intToString(value)));
	return *this;
}

TrackFilter &
TrackFilter::puid(const string &value)
{
	parameters.push_back(pair<string, string>(string("puid"), value));
	return *this;
}

TrackFilter &
TrackFilter::limit(const int value)
{
	parameters.push_back(pair<string, string>(string("limit"), intToString(value)));
	return *this;
}

UserFilter::ParameterList
UserFilter::createParameters() const
{
	return parameters;
}

UserFilter &
UserFilter::name(const string &value)
{
	parameters.push_back(pair<string, string>(string("name"), value));
	return *this;
}


