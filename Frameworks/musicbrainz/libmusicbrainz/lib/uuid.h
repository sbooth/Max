/* --------------------------------------------------------------------------

   MusicBrainz -- The Internet music metadatabase

   Copyright (C) 2000 Relatable.com
   
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

     $Id: uuid.h 311 2000-09-22 14:15:03Z robert $

----------------------------------------------------------------------------*/
#ifndef _UUID_H_
#define _UUID_H_

#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef unsigned char uuid_t1[17];

typedef unsigned int __u32;
typedef unsigned short __u16;
typedef unsigned char __u8;

struct uuid {
   __u32 time_low;
   __u16 time_mid;
   __u16 time_hi_and_version;
   __u16 clock_seq;
   __u8  node[6];
};

void uuid_clear(uuid_t1 uu);
int uuid_parse(char *in, uuid_t1 uu);
void uuid_pack(struct uuid *uu, uuid_t1 ptr);
void uuid_unpack(uuid_t1 in, struct uuid *uu);
void uuid_ascii(uuid_t1 in, char ascii[37]);
  
#endif
