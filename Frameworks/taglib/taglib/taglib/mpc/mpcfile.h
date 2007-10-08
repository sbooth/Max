/***************************************************************************
    copyright            : (C) 2004 by Allan Sandfeld Jensen
    email                : kde@carewolf.org
 ***************************************************************************/

/***************************************************************************
 *   This library is free software; you can redistribute it and/or modify  *
 *   it  under the terms of the GNU Lesser General Public License version  *
 *   2.1 as published by the Free Software Foundation.                     *
 *                                                                         *
 *   This library is distributed in the hope that it will be useful, but   *
 *   WITHOUT ANY WARRANTY; without even the implied warranty of            *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU     *
 *   Lesser General Public License for more details.                       *
 *                                                                         *
 *   You should have received a copy of the GNU Lesser General Public      *
 *   License along with this library; if not, write to the Free Software   *
 *   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  *
 *   USA                                                                   *
 ***************************************************************************/

#ifndef TAGLIB_MPCFILE_H
#define TAGLIB_MPCFILE_H

#include "taglib_export.h"
#include "tfile.h"

#include "mpcproperties.h"

namespace TagLib {

  class Tag;

  namespace ID3v1 { class Tag; }
  namespace APE { class Tag; }

  //! An implementation of MPC metadata

  /*!
   * This is implementation of MPC metadata.
   *
   * This supports ID3v1 and APE (v1 and v2) style comments as well as reading stream
   * properties from the file. ID3v2 tags are invalid in MPC-files, but will be skipped
   * and ignored.
   */

  namespace MPC {

    //! An implementation of TagLib::File with MPC specific methods

    /*!
     * This implements and provides an interface for MPC files to the
     * TagLib::Tag and TagLib::AudioProperties interfaces by way of implementing
     * the abstract TagLib::File API as well as providing some additional
     * information specific to MPC files.
     * The only invalid tag combination supported is an ID3v1 tag after an APE tag.
     */

    class TAGLIB_EXPORT File : public TagLib::File
    {
    public:
      /*!
       * This set of flags is used for various operations and is suitable for
       * being OR-ed together.
       */
      enum TagTypes {
        //! Empty set.  Matches no tag types.
        NoTags  = 0x0000,
        //! Matches ID3v1 tags.
        ID3v1   = 0x0001,
        //! Matches ID3v2 tags.
        ID3v2   = 0x0002,
        //! Matches APE tags.
        APE     = 0x0004,
        //! Matches all tag types.
        AllTags = 0xffff
      };

      /*!
       * Contructs an MPC file from \a file.  If \a readProperties is true the
       * file's audio properties will also be read using \a propertiesStyle.  If
       * false, \a propertiesStyle is ignored.
       */
      File(const char *file, bool readProperties = true,
           Properties::ReadStyle propertiesStyle = Properties::Average);

      /*!
       * Destroys this instance of the File.
       */
      virtual ~File();

      /*!
       * Returns the Tag for this file.  This will be an APE tag, an ID3v1 tag
       * or a combination of the two.
       */
      virtual TagLib::Tag *tag() const;

      /*!
       * Returns the MPC::Properties for this file.  If no audio properties
       * were read then this will return a null pointer.
       */
      virtual Properties *audioProperties() const;

      /*!
       * Saves the file.
       */
      virtual bool save();

      /*!
       * Returns a pointer to the ID3v1 tag of the file.
       *
       * If \a create is false (the default) this will return a null pointer
       * if there is no valid ID3v1 tag.  If \a create is true it will create
       * an ID3v1 tag if one does not exist. If there is already an APE tag, the
       * new ID3v1 tag will be placed after it.
       *
       * \note The Tag <b>is still</b> owned by the APE::File and should not be
       * deleted by the user.  It will be deleted when the file (object) is
       * destroyed.
       */
      ID3v1::Tag *ID3v1Tag(bool create = false);

      /*!
       * Returns a pointer to the APE tag of the file.
       *
       * If \a create is false (the default) this will return a null pointer
       * if there is no valid APE tag.  If \a create is true it will create
       * a APE tag if one does not exist. If there is already an ID3v1 tag, thes
       * new APE tag will be placed before it.
       *
       * \note The Tag <b>is still</b> owned by the APE::File and should not be
       * deleted by the user.  It will be deleted when the file (object) is
       * destroyed.
       */
      APE::Tag *APETag(bool create = false);

      /*!
       * This will remove the tags that match the OR-ed together TagTypes from the
       * file.  By default it removes all tags.
       *
       * \note This will also invalidate pointers to the tags
       * as their memory will be freed.
       * \note In order to make the removal permanent save() still needs to be called
       */
      void remove(int tags = AllTags);

    private:
      File(const File &);
      File &operator=(const File &);

      void read(bool readProperties, Properties::ReadStyle propertiesStyle);
      void scan();
      long findAPE();
      long findID3v1();
      long findID3v2();

      class FilePrivate;
      FilePrivate *d;
    };
  }
}

#endif
