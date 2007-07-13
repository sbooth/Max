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
 * $Id: track.cpp 9189 2007-06-20 19:41:06Z luks $
 */
 
#include <string>
#include <musicbrainz3/model.h>
#include "utils_private.h"

using namespace std;
using namespace MusicBrainz;

class Track::TrackPrivate
{
public:
	TrackPrivate() :
		artist(0),
		duration(0)
		{}
		
	std::string title;
	Artist *artist;
	int duration;
	ReleaseList releases;
	int releasesCount;
	int releasesOffset;
};

Track::Track(const string &id, const string &title)
    : Entity(id)
{
	d = new TrackPrivate();
	
	d->title = title;
}

Track::~Track()
{
	if (d->artist)
		delete d->artist;
	
	delete d;
}

SIMPLE_STRING_SETTER_GETTER(Track, Title, title);
SIMPLE_INT_SETTER_GETTER(Track, Duration, duration);

Artist *
Track::getArtist()
{
	return d->artist;
}

void
Track::setArtist(Artist *value)
{
	if (d->artist)
		delete d->artist;
	d->artist = value;
}

ReleaseList &
Track::getReleases()
{
	return d->releases;
}

void
Track::addRelease(Release *release)
{
	d->releases.push_back(release);
}

int
Track::getNumReleases() const
{
	return d->releases.size();
}

Release *
Track::getRelease(int i)
{
	return d->releases[i];
}

int
Track::getReleasesOffset() const
{
	return d->releasesOffset;
}

void
Track::setReleasesOffset(const int releasesOffset)
{
	d->releasesOffset = releasesOffset;
}

int
Track::getReleasesCount() const
{
	return d->releasesCount;
}

void
Track::setReleasesCount(const int releasesCount)
{
	d->releasesCount = releasesCount;
}
