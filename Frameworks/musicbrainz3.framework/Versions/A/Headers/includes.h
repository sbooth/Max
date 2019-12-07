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
 * 
 */
 
#ifndef __MUSICBRAINZ3_INCLUDES_H__
#define __MUSICBRAINZ3_INCLUDES_H__

#include <string>
#include <vector>
#include <musicbrainz3/musicbrainz.h>

namespace MusicBrainz
{

	/**
	 * An interface implemented by include tag generators.
	 */
	class MB_API IIncludes
	{
	public:
		typedef std::vector<std::string> IncludeList;
		
		virtual ~IIncludes() {};
		
		/**
		 * Returns a list of strings containing include parameters for
		 * the WebService.
		 *
		 * @return a list of strings
		 */
		virtual IncludeList createIncludeTags() const = 0;
	};
	
	/**
	 * A specification on how much data to return with a artist.
	 *
	 * This implementation uses \e method \e chaining to define list of includes.
	 *
	 * Example usage:
	 * \code
	 * ArtistIncludes inc = ArtistIncludes().aliases().urlRelations();
	 * \endcode
	 */
	class MB_API ArtistIncludes : public IIncludes
	{
	public:
		//! Include aliases.
		ArtistIncludes &aliases();
		//! Include releases of speficied type.
		ArtistIncludes &releases(const std::string &type);
		//! Include VA releases of speficied type.
		ArtistIncludes &vaReleases(const std::string &type);
		//! Include release events for included releases.
		ArtistIncludes &releaseEvents();	
		//! Include artist relations.
		ArtistIncludes &artistRelations();	
		//! Include label relations.
		ArtistIncludes &labelRelations();	
		//! Include release relations.
		ArtistIncludes &releaseRelations();	
		//! Include track relations.
		ArtistIncludes &trackRelations();	
		//! Include URL relations.
		ArtistIncludes &urlRelations();
		//! Include ratings.
		ArtistIncludes &ratings();
		//! Include tags.
		ArtistIncludes &tags();
		IncludeList createIncludeTags() const;
	private:
		IncludeList includes;
	};
	
	/**
	 * A specification on how much data to return with a label.
	 *
	 * This implementation uses \e method \e chaining to define list of includes.
	 *
	 * Example usage:
	 * \code
	 * LabelIncludes inc = LabelIncludes().aliases().urlRelations();
	 * \endcode
	 */
	class MB_API LabelIncludes : public IIncludes
	{
	public:
		//! Include aliases.
		LabelIncludes &aliases();
		//! Include artist relations.
		LabelIncludes &artistRelations();	
		//! Include label relations.
		LabelIncludes &labelRelations();	
		//! Include release relations.
		LabelIncludes &releaseRelations();	
		//! Include track relations.
		LabelIncludes &trackRelations();	
		//! Include URL relations.
		LabelIncludes &urlRelations();
		//! Include ratings.
		LabelIncludes &ratings();
		//! Include tags.
		LabelIncludes &tags();
		IncludeList createIncludeTags() const;
	private:
		IncludeList includes;
	};
	
	/**
	 * A specification on how much data to return with a release.
	 *
	 * This implementation uses \e method \e chaining to define list of includes.
	 *
	 * Example usage:
	 * \code
	 * ReleaseIncludes inc = ReleaseIncludes().releaseEvents().disc();
	 * \endcode
	 */
	class MB_API ReleaseIncludes : public IIncludes
	{
	public:
		//! Include artist.
		ReleaseIncludes &artist();	
		//! Include counts.
		ReleaseIncludes &counts();	
		//! Include release events.
		ReleaseIncludes &releaseEvents();	
		//! Include discs.
		ReleaseIncludes &discs();	
		//! Include tracks.
		ReleaseIncludes &tracks();	
		//! Include artist relations.
		ReleaseIncludes &artistRelations();	
		//! Include label relations.
		ReleaseIncludes &labelRelations();	
		//! Include release relations.
		ReleaseIncludes &releaseRelations();	
		//! Include track relations.
		ReleaseIncludes &trackRelations();	
		//! Include URL relations.
		ReleaseIncludes &urlRelations();
		//! Include ISRCs.
		ReleaseIncludes &isrcs();
		//! Include ratings.
		ReleaseIncludes &ratings();
		//! Include tags.
		ReleaseIncludes &tags();
		IncludeList createIncludeTags() const;
	private:
		IncludeList includes;
	};
	
	/**
	 * A specification on how much data to return with a release group.
	 *
	 * This implementation uses \e method \e chaining to define list of includes.
	 *
	 * Example usage:
	 * \code
	 * ReleaseGroupIncludes inc = ReleaseGroupIncludes().releaseEvents().disc();
	 * \endcode
	 */
	class MB_API ReleaseGroupIncludes : public IIncludes
	{
	public:
		//! Include artist.
		ReleaseGroupIncludes &artist();
		//! Include release events.
		ReleaseGroupIncludes &releases();
		IncludeList createIncludeTags() const;
	private:
		IncludeList includes;
	};
	
	/**
	 * A specification on how much data to return with a track.
	 *
	 * This implementation uses \e method \e chaining to define list of includes.
	 *
	 * Example usage:
	 * \code
	 * TrackIncludes inc = TrackIncludes().artist().puids().trackRelations();
	 * \endcode
	 */
	class MB_API TrackIncludes : public IIncludes
	{
	public:
		//! Include artist.
		TrackIncludes &artist();	
		//! Include releases.
		TrackIncludes &releases();	
		//! Include PUIDs.
		TrackIncludes &puids();	
		//! Include artist relations.
		TrackIncludes &artistRelations();	
		//! Include label relations.
		TrackIncludes &labelRelations();	
		//! Include release relations.
		TrackIncludes &releaseRelations();	
		//! Include track relations.
		TrackIncludes &trackRelations();	
		//! Include URL relations.
		TrackIncludes &urlRelations();
		//! Include ISRCs.
		TrackIncludes &isrcs();
		//! Include ratings.
		TrackIncludes &ratings();
		//! Include tags.
		TrackIncludes &tags();
		IncludeList createIncludeTags() const;
	private:
		IncludeList includes;
	};
	
}

#endif
