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
 * $Id: releaseevent.cpp 9218 2007-06-25 20:11:09Z luks $
 */
 
#include <string>
#include <musicbrainz3/label.h>
#include <musicbrainz3/releaseevent.h>
#include "utils_private.h"

using namespace std;
using namespace MusicBrainz;

class ReleaseEvent::ReleaseEventPrivate
{
public:
	ReleaseEventPrivate()
		: label(NULL)
		{}
		
	string country;
	string dateStr;
	string catalogNumber;
	string barcode;
	Label *label;
};

ReleaseEvent::ReleaseEvent(const string &country, const string &dateStr)
{
	d = new ReleaseEventPrivate();
	
	d->country = country;
	d->dateStr = dateStr;
}

ReleaseEvent::~ReleaseEvent()
{
	if (d->label)
		delete d->label;

	delete d;
}

SIMPLE_STRING_SETTER_GETTER(ReleaseEvent, Country, country);
SIMPLE_STRING_SETTER_GETTER(ReleaseEvent, CatalogNumber, catalogNumber);
SIMPLE_STRING_SETTER_GETTER(ReleaseEvent, Barcode, barcode);
SIMPLE_STRING_SETTER_GETTER(ReleaseEvent, Date, dateStr);

void
ReleaseEvent::setLabel(Label *label)
{
	if (d->label)
		delete d->label;

	d->label = label;
}

Label *
ReleaseEvent::getLabel()
{
	return d->label;
}
