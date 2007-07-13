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
 * $Id: artist.cpp 9189 2007-06-20 19:41:06Z luks $
 */
 
#include <string>
#include <musicbrainz3/model.h>
#include "utils_private.h"

using namespace std;
using namespace MusicBrainz;

const string Artist::TYPE_PERSON = NS_MMD_1 + "Person"; 
const string Artist::TYPE_GROUP = NS_MMD_1 + "Group"; 

class Artist::ArtistPrivate
{
public:
	ArtistPrivate() :
		releasesCount(0),
		releasesOffset(0)
		{}
	
	std::string type;
	std::string name;
	std::string sortName;
	std::string disambiguation;
	std::string beginDate;
	std::string endDate;
	ReleaseList releases;
	int releasesCount;
	int releasesOffset;
	ArtistAliasList aliases;
};

Artist::Artist(const string &id, const string &type, const string &name, const string &sortName)
    : Entity(id)
{
	d = new ArtistPrivate();
	
	d->type = type;
	d->name = name;
	d->sortName = sortName;
}

Artist::~Artist()
{
	for (ReleaseList::iterator i = d->releases.begin(); i != d->releases.end(); i++) 
		delete *i;
	d->releases.clear();
 	
	for (ArtistAliasList::iterator i = d->aliases.begin(); i != d->aliases.end(); i++) 
		delete *i;
	d->aliases.clear();

	delete d; 	
}

SIMPLE_STRING_SETTER_GETTER(Artist, Type, type);
SIMPLE_STRING_SETTER_GETTER(Artist, Name, name);
SIMPLE_STRING_SETTER_GETTER(Artist, SortName, sortName);
SIMPLE_STRING_SETTER_GETTER(Artist, Disambiguation, disambiguation);
SIMPLE_STRING_SETTER_GETTER(Artist, BeginDate, beginDate);
SIMPLE_STRING_SETTER_GETTER(Artist, EndDate, endDate);

string
Artist::getUniqueName() const
{
    return d->disambiguation.empty() ? d->name : d->name + " (" + d->disambiguation +")";
}

ReleaseList &
Artist::getReleases()
{
    return d->releases;
}

void
Artist::addRelease(Release *release)
{
    d->releases.push_back(release);
}

ArtistAliasList &
Artist::getAliases()
{
    return d->aliases;
}

void
Artist::addAlias(ArtistAlias *alias)
{
    d->aliases.push_back(alias);
}

int
Artist::getNumReleases() const
{
	return d->releases.size();
}

Release * 
Artist::getRelease(int i)
{
	return d->releases[i];
}

int
Artist::getReleasesOffset() const
{
    return d->releasesOffset;
}

void
Artist::setReleasesOffset(const int releasesOffset)
{
    d->releasesOffset = releasesOffset;
}

int
Artist::getReleasesCount() const
{
    return d->releasesCount;
}

void
Artist::setReleasesCount(const int releasesCount)
{
    d->releasesCount = releasesCount;
}

int
Artist::getNumAliases() const
{
	return d->aliases.size();
}

ArtistAlias *
Artist::getAlias(int i)
{
	return d->aliases[i];
}
