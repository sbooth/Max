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
 * $Id: relation.cpp 9189 2007-06-20 19:41:06Z luks $
 */
 
#include <string>
#include <musicbrainz3/model.h>
#include "utils_private.h"

using namespace std;
using namespace MusicBrainz;

const string Relation::TO_ARTIST = NS_MMD_1 + "Artist"; 
const string Relation::TO_RELEASE = NS_MMD_1 + "Release"; 
const string Relation::TO_TRACK = NS_MMD_1 + "Track"; 
const string Relation::TO_URL = NS_MMD_1 + "Url"; 

class Relation::RelationPrivate
{
public:
	RelationPrivate()
		{}
	
	std::string type;
	std::string targetType;
	std::string targetId;
	Direction direction;
	Attributes attributes;
	std::string beginDate;
	std::string endDate;
	Entity *target;
};

Relation::Relation(const std::string &relationType,
				   const std::string &targetType,
				   const std::string &targetId,
				   const Direction direction,
				   const std::vector<std::string> &attributes,
				   const std::string &beginDate,
				   const std::string &endDate,
				   Entity *target)
{
	d = new RelationPrivate();
	
	d->type = relationType;
	d->targetType = targetType;
	d->targetId = targetId;
	d->direction = direction;
	d->attributes = attributes;
	d->beginDate = beginDate;
	d->endDate = endDate;
	d->target = target;
}

Relation::~Relation()
{
	if (d->target)
		delete d->target;
	
	delete d;
}

SIMPLE_STRING_SETTER_GETTER(Relation, Type, type);
SIMPLE_STRING_SETTER_GETTER(Relation, TargetId, targetId);
SIMPLE_STRING_SETTER_GETTER(Relation, TargetType, targetType);
SIMPLE_STRING_SETTER_GETTER(Relation, BeginDate, beginDate);
SIMPLE_STRING_SETTER_GETTER(Relation, EndDate, endDate);

Relation::Direction
Relation::getDirection() const
{
	return d->direction;
}

void
Relation::setDirection(const Relation::Direction value)
{
	d->direction = value;
}

Entity *
Relation::getTarget() const
{
	return d->target;
}

void
Relation::setTarget(Entity *value)
{
	d->target = value;
}

Relation::Attributes &
Relation::getAttributes()
{
	return d->attributes;
}

void
Relation::addAttribute(const string &value)
{
	d->attributes.push_back(value);
}

int
Relation::getNumAttributes() const
{
	return d->attributes.size();
}

string
Relation::getAttribute(int i) const
{
	return d->attributes[i];
}

