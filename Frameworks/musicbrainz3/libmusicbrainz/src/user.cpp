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
 * $Id: user.cpp 9189 2007-06-20 19:41:06Z luks $
 */
 
#include <string>
#include <musicbrainz3/user.h>
#include "utils_private.h"

using namespace std;
using namespace MusicBrainz;

class User::UserPrivate
{
public:
	UserPrivate() :
		showNag(false)
		{}
		
	std::string name;
	bool showNag;
	std::vector<std::string> types;
};

User::User()
{
	d = new UserPrivate();
}

User::~User()
{
	delete d;
}

SIMPLE_STRING_SETTER_GETTER(User, Name, name);

bool
User::getShowNag() const
{
	return d->showNag;
}

void
User::setShowNag(bool value)
{
	d->showNag = value;
}

std::vector<std::string> &
User::getTypes()
{
	return d->types;
}

void
User::addType(const string &type)
{
	d->types.push_back(type);
}

int
User::getNumTypes() const
{
	return d->types.size();
}

string 
User::getType(int i) const
{
	return d->types[i];
}

