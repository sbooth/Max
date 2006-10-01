/*__________________________________________________________________________

  MusicBrainz -- The Internet music metadatabase

  Portions Copyright (C) 2000 Relatable

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

  $Id: sigxdr.h 469 2001-07-06 21:32:13Z robert $
____________________________________________________________________________*/

#ifndef _SIGXDR_H_
#define _SIGXDR_H_

#ifdef WIN32
#include "config_win32.h"
#else
#include "config.h"
#endif

#include "audiosig.h"
#include "types.h"
#include <limits.h>

#include <string>
using namespace std;

#define FIELDSIZE 4

#ifndef __BEOS__
#ifndef int32
#if UINT_MAX == 0xfffffffful
typedef int             int32;
#elif ULONG_MAX == 0xfffffffful
typedef long            int32;
#elif USHRT_MAX == 0xfffffffful
typedef short           int32;
#else
#error This machine has no 32-bit type
#endif
#endif

#endif //BEOS

class SigXDR
{
public:
    SigXDR();
   ~SigXDR();

    char  *FromSig(AudioSig *sig);
    string ToStrGUID(char *buffer, long size);
 
private:
    void PutInt32(int32 *data);
    void GetInt32(int32 *data);

    void PutFloat(float *data);
    void GetFloat(float *data);

    char *m_buffer;
    char *m_position;
    long  m_size;
};

#endif
