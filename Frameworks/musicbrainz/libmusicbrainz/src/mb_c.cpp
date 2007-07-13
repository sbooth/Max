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
 * $Id: mb_c.cpp 9246 2007-07-07 06:40:33Z luks $
 */
 
#include <string.h>
#include <musicbrainz3/query.h>
#include <musicbrainz3/mb_c.h>

extern "C" {

using namespace std;
using namespace MusicBrainz;

/* A little bit of cpp goodness :) */

#define MB_C_NEW_NOARGS(TYPE1, TYPE2) \
	Mb##TYPE1 \
	mb_##TYPE2##_new() \
	{ \
		TYPE1 *o = new TYPE1(); \
		return (Mb##TYPE1)o; \
	} 

#define MB_C_FREE(TYPE1, TYPE2) \
	void \
	mb_##TYPE2##_free(Mb##TYPE1 o) \
	{ \
		delete (TYPE1 *)o; \
	} 

#define MB_C_STR_SETTER(TYPE1, TYPE2, PROP1, PROP2) \
	void \
	mb_##TYPE2##_set_##PROP2(Mb##TYPE1 o, const char *str) \
	{ \
		try { \
			((TYPE1 *)o)->set##PROP1(str); \
		} \
		catch (...) { \
		} \
	} 

#define MB_C_INT_SETTER(TYPE1, TYPE2, PROP1, PROP2) \
	void \
	mb_##TYPE2##_set_##PROP2(Mb##TYPE1 o, int i) \
	{ \
		try { \
			((TYPE1 *)o)->set##PROP1(i); \
		} \
		catch (...) { \
		} \
	} 

#define MB_C_STR_GETTER(TYPE1, TYPE2, PROP1, PROP2) \
	void \
	mb_##TYPE2##_get_##PROP2(Mb##TYPE1 o, char *str, int len) \
	{ \
		try { \
			strncpy(str, ((TYPE1 *)o)->get##PROP1().c_str(), len); \
		} \
		catch (...) { \
			str[0] = '\0'; \
		} \
	} 

#define MB_C_INT_GETTER(TYPE1, TYPE2, PROP1, PROP2) \
	int \
	mb_##TYPE2##_get_##PROP2(Mb##TYPE1 o) \
	{ \
		try { \
			return ((TYPE1 *)o)->get##PROP1(); \
		} \
		catch (...) { \
			return 0; \
		} \
	} 

#define MB_C_BOOL_GETTER(TYPE1, TYPE2, PROP1, PROP2) \
	int \
	mb_##TYPE2##_get_##PROP2(Mb##TYPE1 o) \
	{ \
		try { \
			return ((TYPE1 *)o)->get##PROP1() ? 1 : 0; \
		} \
		catch (...) { \
			return 0; \
		} \
	} 

#define MB_C_OBJ_GETTER(TYPE1, TYPE2, PROP1, PROP2, OBJTYPE) \
	OBJTYPE \
	mb_##TYPE2##_get_##PROP2(Mb##TYPE1 o) \
	{ \
		try { \
			return (OBJTYPE)((TYPE1 *)o)->get##PROP1(); \
		} \
		catch (...) { \
			return (OBJTYPE)0; \
		} \
	} 

#define MB_C_OBJ_LIST_GETTER(TYPE1, TYPE2, PLR1, PLR2, SNG1, SNG2, RTYPE) \
	int \
	mb_##TYPE2##_get_num_##PLR2(Mb##TYPE1 o) \
	{ \
		try { \
			return ((TYPE1 *)o)->getNum##PLR1(); \
		} \
		catch (...) { \
			return 0; \
		} \
	} \
	Mb##RTYPE \
	mb_##TYPE2##_get_##SNG2(Mb##TYPE1 o, int index) \
	{ \
		try { \
			return (Mb##RTYPE)((TYPE1 *)o)->get##SNG1(index); \
		} \
		catch (...) { \
			return (Mb##RTYPE)0; \
		} \
	} 

#define MB_C_STR_LIST_GETTER(TYPE1, TYPE2, PLR1, PLR2, SNG1, SNG2) \
	int \
	mb_##TYPE2##_get_num_##PLR2(Mb##TYPE1 o) \
	{ \
		try { \
			return ((TYPE1 *)o)->getNum##PLR1(); \
		} \
		catch (...) { \
			return 0; \
		} \
	} \
	void \
	mb_##TYPE2##_get_##SNG2(Mb##TYPE1 o, int index, char *str, int len) \
	{ \
		try { \
			strncpy(str, ((TYPE1 *)o)->get##SNG1(index).c_str(), len); \
		} \
		catch (...) { \
			str[0] = '\0'; \
		} \
	} 

#define MB_C_INCLUDES(TYPE1, TYPE2, INC1, INC2) \
	Mb##TYPE1 \
	mb_##TYPE2##_##INC2(Mb##TYPE1 o) \
	{ \
		((TYPE1 *)o)->INC1(); \
		return o; \
	}
	
#define MB_C_INT_FILTER(TYPE1, TYPE2, INC1, INC2) \
	Mb##TYPE1 \
	mb_##TYPE2##_##INC2(Mb##TYPE1 o, int i) \
	{ \
		((TYPE1 *)o)->INC1(i); \
		return o; \
	} 

#define MB_C_STR_FILTER(TYPE1, TYPE2, INC1, INC2) \
	Mb##TYPE1 \
	mb_##TYPE2##_##INC2(Mb##TYPE1 o, const char *s) \
	{ \
		((TYPE1 *)o)->INC1(s); \
		return o; \
	} 

/* === MusicBrainz::WebService === */

MB_C_NEW_NOARGS(WebService, webservice)
MB_C_FREE(WebService, webservice)
MB_C_STR_SETTER(WebService, webservice, Host, host)
MB_C_INT_SETTER(WebService, webservice, Port, port)
MB_C_STR_SETTER(WebService, webservice, PathPrefix, path_prefix)
MB_C_STR_SETTER(WebService, webservice, UserName, username)
MB_C_STR_SETTER(WebService, webservice, Password, password)
MB_C_STR_SETTER(WebService, webservice, Realm, realm)
MB_C_STR_SETTER(WebService, webservice, ProxyHost, proxy_host)
MB_C_INT_SETTER(WebService, webservice, ProxyPort, proxy_port)
MB_C_STR_SETTER(WebService, webservice, ProxyUserName, proxy_username)
MB_C_STR_SETTER(WebService, webservice, ProxyPassword, proxy_password)

/* === MusicBrainz::Query === */

MbQuery
mb_query_new(MbWebService ws, const char *client_id)
{
	Query *query = new Query((WebService *)ws, client_id ? client_id : "");
	return (MbQuery)query;
}

MB_C_FREE(Query, query)

MbArtist
mb_query_get_artist_by_id(MbQuery q, const char *id, MbArtistIncludes inc)
{
	Query *query = (Query *)q;
	return (MbArtist)query->getArtistById(id, (ArtistIncludes *)inc);
}

MbRelease
mb_query_get_release_by_id(MbQuery q, const char *id, MbReleaseIncludes inc)
{
	Query *query = (Query *)q;
	return (MbRelease)query->getReleaseById(id, (ReleaseIncludes *)inc);
}

MbTrack
mb_query_get_track_by_id(MbQuery q, const char *id, MbTrackIncludes inc)
{
	Query *query = (Query *)q;
	return (MbTrack)query->getTrackById(id, (TrackIncludes *)inc);
}

MbUser
mb_query_get_user_by_name(MbQuery q, const char *name)
{
	Query *query = (Query *)q;
	return (MbUser)query->getUserByName(name);
}

void
mb_result_list_free(MbResultList list)
{
    delete (ResultList *)list;
}

int
mb_result_list_get_size(MbResultList list)
{
    return ((ResultList *)list)->size();
}

int
mb_result_list_get_score(MbResultList list, int index)
{
    return (*((ResultList *)list))[index]->getScore();
}

MbArtist
mb_result_list_get_artist(MbResultList list, int index)
{
    return (MbArtist)(*((ArtistResultList *)list))[index]->getArtist();
}

MbRelease
mb_result_list_get_release(MbResultList list, int index)
{
    return (*((ReleaseResultList *)list))[index]->getRelease();
}

MbTrack
mb_result_list_get_track(MbResultList list, int index)
{
    return (*((TrackResultList *)list))[index]->getTrack();
}

MB_API MbResultList
mb_query_get_artists(MbQuery q, MbArtistFilter flt)
{
	Query *query = (Query *)q;
	ArtistResultList *results = new ArtistResultList(query->getArtists((ArtistFilter *)flt));
    return (MbResultList)results;
}

MB_API MbResultList
mb_query_get_releases(MbQuery q, MbReleaseFilter flt)
{
	Query *query = (Query *)q;
	ReleaseResultList *results = new ReleaseResultList(query->getReleases((ReleaseFilter *)flt));
    return (MbResultList)results;
}

MB_API MbResultList
mb_query_get_tracks(MbQuery q, MbTrackFilter flt)
{
	Query *query = (Query *)q;
	TrackResultList *results = new TrackResultList(query->getTracks((TrackFilter *)flt));
    return (MbResultList)results;
}


/* === MusicBrainz::Artist === */

MB_C_FREE(Artist, artist)

MB_C_STR_GETTER(Artist, artist, Id, id)
MB_C_STR_GETTER(Artist, artist, Type, type)
MB_C_STR_GETTER(Artist, artist, Name, name)
MB_C_STR_GETTER(Artist, artist, SortName, sortname)
MB_C_STR_GETTER(Artist, artist, Disambiguation, disambiguation)
MB_C_STR_GETTER(Artist, artist, UniqueName, unique_name)
MB_C_STR_GETTER(Artist, artist, BeginDate, begin_date)
MB_C_STR_GETTER(Artist, artist, EndDate, end_date)
MB_C_INT_GETTER(Artist, artist, ReleasesOffset, releases_offset)
MB_C_INT_GETTER(Artist, artist, ReleasesCount, releases_count)
MB_C_OBJ_LIST_GETTER(Artist, artist, Aliases, aliases, Alias, alias, ArtistAlias)
MB_C_OBJ_LIST_GETTER(Artist, artist, Releases, releases, Release, release, Release)
MB_C_OBJ_LIST_GETTER(Artist, artist, Relations, relations, Relation, relation, Relation)

/* === MusicBrainz::Release === */

MB_C_FREE(Release, release)

MB_C_STR_GETTER(Release, release, Id, id)
MB_C_STR_GETTER(Release, release, Title, title)
MB_C_STR_GETTER(Release, release, TextLanguage, text_language)
MB_C_STR_GETTER(Release, release, TextScript, text_script)
MB_C_STR_GETTER(Release, release, Asin, asin)
MB_C_INT_GETTER(Release, release, TracksOffset, tracks_offset)
MB_C_INT_GETTER(Release, release, TracksCount, tracks_count)
MB_C_OBJ_LIST_GETTER(Release, release, Tracks, tracks, Track, track, Track)
MB_C_OBJ_LIST_GETTER(Release, release, Discs, discs, Disc, disc, Disc)
MB_C_OBJ_LIST_GETTER(Release, release, ReleaseEvents, release_events, ReleaseEvent, release_event, ReleaseEvent)
MB_C_OBJ_LIST_GETTER(Release, release, Relations, relations, Relation, relation, Relation)
MB_C_STR_LIST_GETTER(Release, release, Types, types, Type, type)

MB_API MbArtist
mb_release_get_artist(MbRelease r)
{
	Release *release = (Release *)r;
	return (MbArtist)release->getArtist();
}

/* === MusicBrainz::Track === */

MB_C_FREE(Track, track)

MB_C_STR_GETTER(Track, track, Id, id)
MB_C_STR_GETTER(Track, track, Title, title)
MB_C_INT_GETTER(Track, track, Duration, duration)
MB_C_OBJ_LIST_GETTER(Track, track, Relations, relations, Relation, relation, Relation)

/* === MusicBrainz::ArtistAlias === */

MB_C_STR_GETTER(ArtistAlias, artist_alias, Value, value)
MB_C_STR_GETTER(ArtistAlias, artist_alias, Type, type)
MB_C_STR_GETTER(ArtistAlias, artist_alias, Script, script)

/* === MusicBrainz::User === */

MB_C_FREE(User, user)

MB_C_STR_GETTER(User, user, Name, name)
MB_C_BOOL_GETTER(User, user, ShowNag, show_nag)
MB_C_STR_LIST_GETTER(User, user, Types, types, Type, type)

/* === MusicBrainz::ArtistIncludes === */

MB_C_NEW_NOARGS(ArtistIncludes, artist_includes)
MB_C_FREE(ArtistIncludes, artist_includes)

MB_C_INCLUDES(ArtistIncludes, artist_includes, aliases, aliases)
MB_C_INCLUDES(ArtistIncludes, artist_includes, artistRelations, artist_relations)
MB_C_INCLUDES(ArtistIncludes, artist_includes, releaseRelations, release_relations)
MB_C_INCLUDES(ArtistIncludes, artist_includes, trackRelations, track_relations)
MB_C_INCLUDES(ArtistIncludes, artist_includes, urlRelations, url_relations)
MB_C_INCLUDES(ArtistIncludes, artist_includes, releaseEvents, release_events)

MbArtistIncludes
mb_artist_includes_releases(MbArtistIncludes o, const char *str) 
{ 
	((ArtistIncludes *)o)->releases(str ? string(str) : string()); 
	return o; 
} 

MbArtistIncludes
mb_artist_includes_va_releases(MbArtistIncludes o, const char *str) 
{ 
	((ArtistIncludes *)o)->vaReleases(str ? string(str) : string()); 
	return o; 
} 

/* === MusicBrainz::ReleaseIncludes === */

MB_C_NEW_NOARGS(ReleaseIncludes, release_includes)
MB_C_FREE(ReleaseIncludes, release_includes)

MB_C_INCLUDES(ReleaseIncludes, release_includes, artist, artist)
MB_C_INCLUDES(ReleaseIncludes, release_includes, counts, counts)
MB_C_INCLUDES(ReleaseIncludes, release_includes, releaseEvents, release_events)
MB_C_INCLUDES(ReleaseIncludes, release_includes, discs, discs)
MB_C_INCLUDES(ReleaseIncludes, release_includes, tracks, tracks)
MB_C_INCLUDES(ReleaseIncludes, release_includes, artistRelations, artist_relations)
MB_C_INCLUDES(ReleaseIncludes, release_includes, releaseRelations, release_relations)
MB_C_INCLUDES(ReleaseIncludes, release_includes, trackRelations, track_relations)
MB_C_INCLUDES(ReleaseIncludes, release_includes, urlRelations, url_relations)

/* === MusicBrainz::TrackIncludes === */

MB_C_NEW_NOARGS(TrackIncludes, track_includes)
MB_C_FREE(TrackIncludes, track_includes)

MB_C_INCLUDES(TrackIncludes, track_includes, artist, artist)
MB_C_INCLUDES(TrackIncludes, track_includes, releases, releases)
MB_C_INCLUDES(TrackIncludes, track_includes, puids, puids)
MB_C_INCLUDES(TrackIncludes, track_includes, artistRelations, artist_relations)
MB_C_INCLUDES(TrackIncludes, track_includes, releaseRelations, release_relations)
MB_C_INCLUDES(TrackIncludes, track_includes, trackRelations, track_relations)
MB_C_INCLUDES(TrackIncludes, track_includes, urlRelations, url_relations)

/* === MusicBrainz::ReleaseEvent === */

MB_C_STR_GETTER(ReleaseEvent, release_event, Country, country)
MB_C_STR_GETTER(ReleaseEvent, release_event, Date, date)

/* === MusicBrainz::Relation === */

MB_C_STR_GETTER(Relation, relation, Type, type)
MB_C_STR_GETTER(Relation, relation, TargetId, target_id)
MB_C_STR_GETTER(Relation, relation, TargetType, target_type)
MB_C_STR_GETTER(Relation, relation, BeginDate, begin_date)
MB_C_STR_GETTER(Relation, relation, EndDate, end_date)
MB_C_INT_GETTER(Relation, relation, Direction, direction)
MB_C_OBJ_GETTER(Relation, relation, Target, target, MbEntity)
MB_C_STR_LIST_GETTER(Relation, relation, Attributes, attributes, Attribute, attribute)

/* === MusicBrainz::Disc === */

MB_C_STR_GETTER(Disc, disc, Id, id)
MB_C_INT_GETTER(Disc, disc, Sectors, sectors)
MB_C_INT_GETTER(Disc, disc, FirstTrackNum, first_track_num)
MB_C_INT_GETTER(Disc, disc, LastTrackNum, last_track_num)

MbDisc
mb_read_disc(const char *device_name)
{
	try {
		return (MbDisc)readDisc(device_name);
	}
	catch (...) {
		return NULL;
	}
}

void
mb_get_submission_url(MbDisc disc, const char *host, int port, char *str, int len)
{
	try {
		if (host && port) {
			strncpy(str, getSubmissionUrl((Disc *)disc, host, port).c_str(), len); 
		}
		else if (host) {
			strncpy(str, getSubmissionUrl((Disc *)disc, host).c_str(), len); 
		}
		else {
			strncpy(str, getSubmissionUrl((Disc *)disc).c_str(), len); 
		}
	} 
	catch (...) { 
		str[0] = '\0'; 
	}
}

/* === MusicBrainz::ArtistFilter === */

MB_C_NEW_NOARGS(ArtistFilter, artist_filter)
MB_C_FREE(ArtistFilter, artist_filter)

MB_C_STR_FILTER(ArtistFilter, artist_filter, name, name)
MB_C_INT_FILTER(ArtistFilter, artist_filter, limit, limit)

/* === MusicBrainz::ReleaseFilter === */

MB_C_NEW_NOARGS(ReleaseFilter, release_filter)
MB_C_FREE(ReleaseFilter, release_filter)

MB_C_STR_FILTER(ReleaseFilter, release_filter, title, title)
MB_C_STR_FILTER(ReleaseFilter, release_filter, discId, disc_id)
MB_C_STR_FILTER(ReleaseFilter, release_filter, releaseType, release_type)
MB_C_STR_FILTER(ReleaseFilter, release_filter, artistName, artist_name)
MB_C_STR_FILTER(ReleaseFilter, release_filter, artistId, artist_id)
MB_C_INT_FILTER(ReleaseFilter, release_filter, limit, limit)

/* === MusicBrainz::TrackFilter === */

MB_C_NEW_NOARGS(TrackFilter, track_filter)
MB_C_FREE(TrackFilter, track_filter)

MB_C_STR_FILTER(TrackFilter, track_filter, title, title)
MB_C_STR_FILTER(TrackFilter, track_filter, releaseTitle, release_title)
MB_C_STR_FILTER(TrackFilter, track_filter, releaseId, release_id)
MB_C_STR_FILTER(TrackFilter, track_filter, artistName, artist_name)
MB_C_STR_FILTER(TrackFilter, track_filter, artistId, artist_id)
MB_C_INT_FILTER(TrackFilter, track_filter, duration, duration)
MB_C_STR_FILTER(TrackFilter, track_filter, puid, puid)
MB_C_INT_FILTER(TrackFilter, track_filter, limit, limit)

/* === MusicBrainz::UserFilter === */

MB_C_NEW_NOARGS(UserFilter, user_filter)
MB_C_FREE(UserFilter, user_filter)

MB_C_STR_FILTER(UserFilter, user_filter, name, name)


}
