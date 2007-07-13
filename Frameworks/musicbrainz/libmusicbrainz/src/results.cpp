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
 * $Id: results.cpp 8466 2006-09-05 08:59:44Z luks $
 */
 
#include <musicbrainz3/results.h>

using namespace MusicBrainz;

Result::Result(int score)
	: score(score)
{
}

int
Result::getScore()
{
	return score;
}

void
Result::setScore(int value)
{
	score = value;
}

ArtistResult::ArtistResult(Artist *artist, int score)
	: Result(score), artist(artist)
{
}

ArtistResult::~ArtistResult()
{
	if (artist)
		delete artist;
}

Artist *
ArtistResult::getArtist()
{
	return artist;
}

void
ArtistResult::setArtist(Artist *value)
{
	if (artist)
		delete artist;
	artist = value;
}

ReleaseResult::ReleaseResult(Release *release, int score)
	: Result(score), release(release)
{
}

ReleaseResult::~ReleaseResult()
{
	if (release)
		delete release;
}

Release *
ReleaseResult::getRelease()
{
	return release;
}

void
ReleaseResult::setRelease(Release *value)
{
	if (release)
		delete release;
	release = value;
}

TrackResult::TrackResult(Track *track, int score)
	: Result(score), track(track)
{
}

TrackResult::~TrackResult()
{
	if (track)
		delete track;
}

Track *
TrackResult::getTrack()
{
	return track;
}

void
TrackResult::setTrack(Track *value)
{
	if (track)
		delete track;
	track = value;
}


