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

#ifndef __MUSICBRAINZ3_RELEASEGROUP_H__
#define __MUSICBRAINZ3_RELEASEGROUP_H__

#include <string>
#include <musicbrainz3/musicbrainz.h>
#include <musicbrainz3/entity.h>
#include <musicbrainz3/lists.h>

namespace MusicBrainz
{

	class Artist;
	
	/**
	 * Represents a Release Group.
	 *
	 */
	class MB_API ReleaseGroup : public Entity
	{
	public:
	
		static const std::string TYPE_NONE;
	
		static const std::string TYPE_ALBUM;
		static const std::string TYPE_SINGLE;
		static const std::string TYPE_EP;
		static const std::string TYPE_COMPILATION;
		static const std::string TYPE_SOUNDTRACK;
		static const std::string TYPE_SPOKENWORD;
		static const std::string TYPE_INTERVIEW;
		static const std::string TYPE_AUDIOBOOK;
		static const std::string TYPE_LIVE;
		static const std::string TYPE_REMIX;
		static const std::string TYPE_OTHER;
	
		/**
		 * Constructor.
		 *
		 * @param id a string containing an absolute URI 
		 * @param title a string containing the title 
		 */
		ReleaseGroup(const std::string &id = std::string(),
				const std::string &title = std::string());
		
		/**
		 * Destructor.
		 */
		~ReleaseGroup();
		
		/**
		 * Returns the release group's title.
		 *
		 * The style and format of this attribute is specified by the
		 * style guide.
		 *
		 * @return a string containing an absolute URI
		 * 
		 * @see <a href="http://musicbrainz.org/style.html">The MusicBrainz
		 *		Style Guidelines</a> 
		 */
		std::string getTitle() const;
		
		/**
		 * Sets the release group's title.
		 *
		 * @param title: a string containing the release group's title
		 *
		 * @see getTitle
		 */
		void setTitle(const std::string &title);

		/**
		 * Returns the main artist of this release group.
		 *
		 * @return a pointer to Artist object, or NULL 
		 */
		Artist *getArtist();
		
		/** 
		 * Sets this release group's main artist.
		 *
		 * @param artist a pointer to Artist object 
		 */
		void setArtist(Artist *artist);

		/**
		 * Sets the release group's type.
		 *
		 * @param type
		 */
		void setType(const std::string &type);

		/**
		 * Returns the release group's type.
		 *
		 * @return a string
		 *
		 * @see getType
		 */
		std::string getType() const;

		ReleaseList &getReleases();
		int getNumReleases() const;
		Release *getRelease(int index);

	private:
		
		class ReleaseGroupPrivate;
		ReleaseGroupPrivate *d;
	};
	
}

#endif

