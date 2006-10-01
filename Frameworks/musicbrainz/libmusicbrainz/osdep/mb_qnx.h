/* --------------------------------------------------------------------------

   MusicBrainz -- The Internet music metadatabase

   Copyright (C) 2000 Robert Kaye
   Copyright (C) 2000 Relatable
   
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

     $Id: mb_qnx.h 316 2000-09-27 19:39:23Z ijr $

----------------------------------------------------------------------------*/

#if !defined(_CDI_QNX_H_)
#define _CDI_QNX_H_


#define OS "QNX"

// 
//  QNX CD-audio declarations
//

//#include <linux/cdrom.h>

typedef char* MUSICBRAINZ_DEVICE;



// 
//  QNX specific prototypes
// 

int ReadTOCHeader(int fd, 
                  int& first, 
                  int& last);

int ReadTOCEntry(int fd, 
                 int track, 
                 int& lba);

#endif
