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
 * $Id: artistalias.cpp 8466 2006-09-05 08:59:44Z luks $
 */
 
#include <musicbrainz3/artistalias.h>

using namespace std;
using namespace MusicBrainz;

class ArtistAlias::ArtistAliasPrivate
{
public:
	ArtistAliasPrivate()
		{}
	
	std::string value;
	std::string type;
	std::string script;
};

ArtistAlias::ArtistAlias(const string &value, const string &type, const string &script)
{
	d = new ArtistAliasPrivate();
	
	d->value = value;
	d->type = type;
	d->script = script;
}

ArtistAlias::~ArtistAlias()
{
	delete d;
}

string
ArtistAlias::getType() const
{
	return d->type;
}

void
ArtistAlias::setType(const string &type)
{
	d->type = type;
}

string
ArtistAlias::getValue() const
{
	return d->value;
}

void
ArtistAlias::setValue(const string &value)
{
	d->value = value;
}

string
ArtistAlias::getScript() const
{
	return d->script;
}

void
ArtistAlias::setScript(const string &script)
{
	d->script = script;
}

