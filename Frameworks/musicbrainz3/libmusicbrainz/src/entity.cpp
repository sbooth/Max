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
 * $Id: entity.cpp 9216 2007-06-25 19:42:20Z luks $
 */
 
#include <string>
#include <musicbrainz3/entity.h>
#include "utils_private.h"

using namespace std;
using namespace MusicBrainz;

class Entity::EntityPrivate
{
public:
	EntityPrivate()
		{}
	
	std::string id;
	RelationList relations;
	TagList tags;
};

Entity::Entity(const string &id)
{
	d = new EntityPrivate();
	
	d->id = id;
}

Entity::~Entity()
{
	for (RelationList::iterator i = d->relations.begin(); i != d->relations.end(); i++) 
		delete *i;
	d->relations.clear();
	
	delete d;
}

SIMPLE_STRING_SETTER_GETTER(Entity, Id, id);

RelationList 
Entity::getRelations(const std::string &targetType,
					 const std::string &relationType) const
{
	if (targetType.empty() && relationType.empty())
		return d->relations;
	
	RelationList result;
	
	if (targetType.empty()) {
		for (RelationList::const_iterator i = d->relations.begin(); i != d->relations.end(); i++) {
			if ((*i)->getType() == relationType) {
				result.push_back(*i);
			}
		}
	}
	else if (relationType.empty()) {
		for (RelationList::const_iterator i = d->relations.begin(); i != d->relations.end(); i++) {
			if ((*i)->getTargetType() == targetType) {
				result.push_back(*i);
			}
		}
	}
	else {
		for (RelationList::const_iterator i = d->relations.begin(); i != d->relations.end(); i++) {
			if ((*i)->getType() == relationType && (*i)->getTargetType() == targetType) {
				result.push_back(*i);
			}
		}
	}
	
	return result;	
}

void
Entity::addRelation(Relation *relation)
{
	d->relations.push_back(relation);
}

int
Entity::getNumRelations() const
{
	return d->relations.size();
}

Relation * 
Entity::getRelation(int i)
{
	return d->relations[i];
}

int
Entity::getNumTags() const
{
	return d->tags.size();
}

Tag * 
Entity::getTag(int i)
{
	return d->tags[i];
}

TagList &
Entity::getTags()
{
	return d->tags;
}

