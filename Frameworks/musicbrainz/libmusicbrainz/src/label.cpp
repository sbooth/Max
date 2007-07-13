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
 * $Id: label.cpp 9218 2007-06-25 20:11:09Z luks $
 */
 
#include <string>
#include <musicbrainz3/model.h>
#include "utils_private.h"

using namespace std;
using namespace MusicBrainz;

const string Label::TYPE_PERSON = NS_MMD_1 + "Person"; 
const string Label::TYPE_GROUP = NS_MMD_1 + "Group"; 

class Label::LabelPrivate
{
public:
	LabelPrivate() :
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
	LabelAliasList aliases;
};

Label::Label(const string &id, const string &type, const string &name, const string &sortName)
    : Entity(id)
{
	d = new LabelPrivate();
	
	d->type = type;
	d->name = name;
	d->sortName = sortName;
}

Label::~Label()
{
	for (ReleaseList::iterator i = d->releases.begin(); i != d->releases.end(); i++) 
		delete *i;
	d->releases.clear();
 	
	for (LabelAliasList::iterator i = d->aliases.begin(); i != d->aliases.end(); i++) 
		delete *i;
	d->aliases.clear();

	delete d; 	
}

SIMPLE_STRING_SETTER_GETTER(Label, Type, type);
SIMPLE_STRING_SETTER_GETTER(Label, Name, name);
SIMPLE_STRING_SETTER_GETTER(Label, SortName, sortName);
SIMPLE_STRING_SETTER_GETTER(Label, Disambiguation, disambiguation);
SIMPLE_STRING_SETTER_GETTER(Label, BeginDate, beginDate);
SIMPLE_STRING_SETTER_GETTER(Label, EndDate, endDate);

string
Label::getUniqueName() const
{
    return d->disambiguation.empty() ? d->name : d->name + " (" + d->disambiguation +")";
}

ReleaseList &
Label::getReleases()
{
    return d->releases;
}

void
Label::addRelease(Release *release)
{
    d->releases.push_back(release);
}

LabelAliasList &
Label::getAliases()
{
    return d->aliases;
}

void
Label::addAlias(LabelAlias *alias)
{
    d->aliases.push_back(alias);
}

int
Label::getNumReleases() const
{
	return d->releases.size();
}

Release * 
Label::getRelease(int i)
{
	return d->releases[i];
}

int
Label::getReleasesOffset() const
{
    return d->releasesOffset;
}

void
Label::setReleasesOffset(const int releasesOffset)
{
    d->releasesOffset = releasesOffset;
}

int
Label::getReleasesCount() const
{
    return d->releasesCount;
}

void
Label::setReleasesCount(const int releasesCount)
{
    d->releasesCount = releasesCount;
}

int
Label::getNumAliases() const
{
	return d->aliases.size();
}

LabelAlias *
Label::getAlias(int i)
{
	return d->aliases[i];
}
