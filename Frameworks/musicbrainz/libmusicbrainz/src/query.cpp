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
 * $Id: query.cpp 8789 2007-01-13 23:01:56Z luks $
 */
 
#include <string>
#include <map>
#include <iostream>
#include <musicbrainz3/utils.h>
#include <musicbrainz3/query.h>
#include <musicbrainz3/mbxmlparser.h>
#include "utils_private.h"

using namespace std;
using namespace MusicBrainz;

class Query::QueryPrivate
{
public:
	QueryPrivate() :
		ws(NULL),
		ownWs(false)
		{}
	
	IWebService *ws;
	bool ownWs;
	std::string clientId;		
};

Query::Query(IWebService *ws, const string &clientId)
{
	d = new QueryPrivate();
	
	d->ws = ws;
	d->clientId = clientId;
	
	if (!d->ws) {
		d->ws = new WebService();
		d->ownWs = true;
	}
}

Query::~Query()
{
	if (d->ownWs && d->ws)
		delete d->ws;
	
	delete d;
}

Artist *
Query::getArtistById(const string &id,
					 const ArtistIncludes *include)
{
	string uuid;
	try {
		uuid = extractUuid(id);
	}
	catch (ValueError &e) {
		throw RequestError(e.what());
	}
	Metadata *metadata = getFromWebService("artist", uuid, include); 
	Artist *artist = metadata->getArtist(true);
	delete metadata;
	return artist;
}

Release *
Query::getReleaseById(const string &id,
					 const ReleaseIncludes *include)
{
	string uuid;
	try {
		uuid = extractUuid(id);
	}
	catch (ValueError &e) {
		throw RequestError(e.what());
	}
	Metadata *metadata = getFromWebService("release", uuid, include); 
	Release *release = metadata->getRelease(true);
	delete metadata;
	return release;
}

Track *
Query::getTrackById(const string &id,
					 const TrackIncludes *include)
{
	string uuid;
	try {
		uuid = extractUuid(id);
	}
	catch (ValueError &e) {
		throw RequestError(e.what());
	}
	Metadata *metadata = getFromWebService("track", uuid, include); 
	Track *track = metadata->getTrack(true);
	delete metadata;
	return track;
}

User *
Query::getUserByName(const string &name)
{
	Metadata *metadata = getFromWebService("user", "", NULL, &UserFilter().name(name));
	UserList list = metadata->getUserList(true);
	delete metadata;
	if (list.size() > 0) 
		return list[0];
	else
		throw ResponseError("response didn't contain user data");
}

ArtistResultList 
Query::getArtists(const ArtistFilter *filter)
{
	Metadata *metadata = getFromWebService("artist", "", NULL, filter);
	ArtistResultList list = metadata->getArtistResults(true);
	delete metadata;
	return list;
}

ReleaseResultList 
Query::getReleases(const ReleaseFilter *filter)
{
	Metadata *metadata = getFromWebService("release", "", NULL, filter);
	ReleaseResultList list = metadata->getReleaseResults(true);
	delete metadata;
	return list;
}

TrackResultList 
Query::getTracks(const TrackFilter *filter)
{
	Metadata *metadata = getFromWebService("track", "", NULL, filter);
	TrackResultList list = metadata->getTrackResults(true);
	delete metadata;
	return list;
}

Metadata *
Query::getFromWebService(const string &entity,
						 const string &id,
						 const IIncludes *include,
						 const IFilter *filter)
{
	const IIncludes::IncludeList includeParams(include ? include->createIncludeTags() : IIncludes::IncludeList());
	const IFilter::ParameterList filterParams(filter ? filter->createParameters() : IFilter::ParameterList());
	string content = d->ws->get(entity, id, includeParams, filterParams);
	try {
		MbXmlParser parser;
		return parser.parse(content);
	}
	catch (ParseError &e) {
		throw ResponseError(e.what());
	}
}

void
Query::submitPuids(const map<string, string> &tracks2puids)
{
	if (d->clientId.empty())
		throw WebServiceError("Please supply a client ID");
	vector<pair<string, string> > params;
	params.push_back(pair<string, string>("client", d->clientId));
	for (map<string, string>::const_iterator i = tracks2puids.begin(); i != tracks2puids.end(); i++) 
		params.push_back(pair<string, string>("puid", extractUuid(i->first) + " " + i->second));
	d->ws->post("track", "", urlEncode(params));	
}

