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
 * $Id: release.cpp 9191 2007-06-20 19:55:32Z luks $
 */
 
#include <string>
#include <musicbrainz3/model.h>
#include "utils_private.h"

using namespace std;
using namespace MusicBrainz;

const string Release::TYPE_NONE = NS_MMD_1 + "None";
	
const string Release::TYPE_ALBUM = NS_MMD_1 + "Album";
const string Release::TYPE_SINGLE = NS_MMD_1 + "Single";
const string Release::TYPE_EP = NS_MMD_1 + "EP";
const string Release::TYPE_COMPILATION = NS_MMD_1 + "Compilation";	
const string Release::TYPE_SOUNDTRACK = NS_MMD_1 + "Soundtrack";
const string Release::TYPE_SPOKENWORD = NS_MMD_1 + "Spokenword";
const string Release::TYPE_INTERVIEW = NS_MMD_1 + "Interview";
const string Release::TYPE_AUDIOBOOK = NS_MMD_1 + "Audiobook";
const string Release::TYPE_LIVE = NS_MMD_1 + "Live";
const string Release::TYPE_REMIX = NS_MMD_1 + "Remix";	
const string Release::TYPE_OTHER = NS_MMD_1 + "Other";

const string Release::TYPE_OFFICIAL = NS_MMD_1 + "Official";
const string Release::TYPE_PROMOTION = NS_MMD_1 + "Promotion";
const string Release::TYPE_BOOTLEG = NS_MMD_1 + "Bootleg";	
const string Release::TYPE_PSEUDO_RELEASE = NS_MMD_1 + "Pseudo-Release";	

class Release::ReleasePrivate
{
public:
	ReleasePrivate() :
		artist(NULL),
		tracksOffset(0),
		tracksCount(0)
		{}
	
	std::string title;
	std::string textLanguage;
	std::string textScript;
	std::string asin;
	vector<string> types;
	Artist *artist;
	TrackList tracks;
	int tracksOffset;
	int tracksCount;
	DiscList discs;
	ReleaseEventList releaseEvents;
};

Release::Release(const string &id, const string &title)
	: Entity(id)
{
	d = new ReleasePrivate();
	
	d->title = title;
}

Release::~Release()
{
	if (d->artist)
		delete d->artist;
	
	for (TrackList::iterator i = d->tracks.begin(); i != d->tracks.end(); i++) 
		delete *i;
	d->tracks.clear();
	
	for (DiscList::iterator i = d->discs.begin(); i != d->discs.end(); i++) 
		delete *i;
	d->discs.clear();
	
	for (ReleaseEventList::iterator i = d->releaseEvents.begin(); i != d->releaseEvents.end(); i++) 
		delete *i;
	d->releaseEvents.clear();
	
	delete d;
}

SIMPLE_STRING_SETTER_GETTER(Release, Title, title);
SIMPLE_STRING_SETTER_GETTER(Release, TextLanguage, textLanguage);
SIMPLE_STRING_SETTER_GETTER(Release, TextScript, textScript);
SIMPLE_STRING_SETTER_GETTER(Release, Asin, asin);

Artist *
Release::getArtist()
{
	return d->artist;
}

void
Release::setArtist(Artist *value)
{
	if (d->artist)
		delete d->artist;
	d->artist = value;
}

TrackList &
Release::getTracks()
{
	return d->tracks;
}

int
Release::getTracksOffset() const
{
	return d->tracksOffset;
}

void
Release::setTracksOffset(const int value)
{
	d->tracksOffset = value;
}

int
Release::getTracksCount() const
{
    return d->tracksCount;
}

void
Release::setTracksCount(const int tracksCount)
{
    d->tracksCount = tracksCount;
}

DiscList &
Release::getDiscs()
{
	return d->discs;
}

ReleaseEventList &
Release::getReleaseEvents()
{
	return d->releaseEvents;
}

int
Release::getNumReleaseEvents() const
{
	return d->releaseEvents.size();
}

ReleaseEvent * 
Release::getReleaseEvent(int i)
{
	return d->releaseEvents[i];
}

int
Release::getNumDiscs() const
{
	return d->discs.size();
}

Disc * 
Release::getDisc(int i)
{
	return d->discs[i];
}

int
Release::getNumTracks() const
{
	return d->tracks.size();
}

Track * 
Release::getTrack(int i)
{
	return d->tracks[i];
}

void
Release::setTypes(const vector<string> &types)
{
	d->types = types;
}

vector<string> &
Release::getTypes()
{
	return d->types;
}

int
Release::getNumTypes() const
{
	return d->types.size();
}

string
Release::getType(int i) const
{
	return d->types[i];
}
