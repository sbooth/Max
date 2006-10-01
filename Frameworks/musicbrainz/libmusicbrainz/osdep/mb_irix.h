
/* --------------------------------------------------------------------------

   MusicBrainz -- The Internet music metadatabase

   Copyright (C) 2000 Robert Kaye
   Copyright (C) 1999 Marc E E van Woerkom
   Copyright (C) 1999 Ben Wong
   
   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.
   
   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free Software
   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

     $Id: mb_irix.h 311 2000-09-22 14:15:03Z robert $

----------------------------------------------------------------------------*/

#if !defined(_CDI_IRIX_H_)
#define _CDI_IRIX_H_


#define OS "Irix"



// 
//  SGI CD audio declarations
//

// note that this requires compling with -lcdaudio -lmediad -lds
// this is taken care of in configure.in

#include <sys/types.h>        // cdaudio.h needs 'unchar'
#include <dmedia/cdaudio.h>

typedef char* MUSICBRAINZ_DEVICE;


// 
//  Irix specific prototypes
// 

int ReadTOCHeader(CDPLAYER* fd, 
                  int& first, 
                  int& last);

int ReadTOCEntry(CDPLAYER* fd, 
                 int track, 
                 int& lba);
#endif
