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
 * $Id: includes.cpp 9187 2007-06-20 19:11:15Z luks $
 */
 
#include <string>
#include <musicbrainz3/utils.h>
#include <musicbrainz3/includes.h>

using namespace std;
using namespace MusicBrainz;

#define INCLUDES_METHOD(class, name, name2) \
	class##Includes & \
	class##Includes::name() \
	{ \
		includes.push_back(#name2); \
		return *this; \
	} \

INCLUDES_METHOD(Track, artist, artist)
INCLUDES_METHOD(Track, releases, releases)
INCLUDES_METHOD(Track, puids, puids)
INCLUDES_METHOD(Track, artistRelations, artist-rels)
INCLUDES_METHOD(Track, releaseRelations, release-rels)
INCLUDES_METHOD(Track, trackRelations, track-rels)
INCLUDES_METHOD(Track, urlRelations, url-rels)

TrackIncludes::IncludeList
TrackIncludes::createIncludeTags() const
{
	return includes;
}

INCLUDES_METHOD(Release, artist, artist)
INCLUDES_METHOD(Release, counts, counts)
INCLUDES_METHOD(Release, releaseEvents, release-events)
INCLUDES_METHOD(Release, discs, discs)
INCLUDES_METHOD(Release, tracks, tracks)
INCLUDES_METHOD(Release, artistRelations, artist-rels)
INCLUDES_METHOD(Release, releaseRelations, release-rels)
INCLUDES_METHOD(Release, trackRelations, track-rels)
INCLUDES_METHOD(Release, urlRelations, url-rels)

ReleaseIncludes::IncludeList
ReleaseIncludes::createIncludeTags() const
{
	return includes;
}

INCLUDES_METHOD(Artist, aliases, aliases)
INCLUDES_METHOD(Artist, artistRelations, artist-rels)
INCLUDES_METHOD(Artist, releaseRelations, release-rels)
INCLUDES_METHOD(Artist, trackRelations, track-rels)
INCLUDES_METHOD(Artist, urlRelations, url-rels)
INCLUDES_METHOD(Artist, releaseEvents, release-events)

ArtistIncludes::IncludeList
ArtistIncludes::createIncludeTags() const
{
	return includes;
}

ArtistIncludes &
ArtistIncludes::releases(const string &type)
{
	includes.push_back(string("sa-") + extractFragment(type));
	return *this;
}

ArtistIncludes &
ArtistIncludes::vaReleases(const string &type)
{
	includes.push_back(string("va-") + extractFragment(type));
	return *this;
}
