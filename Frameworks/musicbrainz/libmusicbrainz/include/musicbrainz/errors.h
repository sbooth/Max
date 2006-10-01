/* --------------------------------------------------------------------------

   MusicBrainz -- The Internet music metadatabase

   Copyright (C) 2000 Robert Kaye
   Copyright (C) 2000 EMusic.com
   
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

     $Id: errors.h 346 2000-10-12 23:48:44Z robert $

----------------------------------------------------------------------------*/
#ifndef INCLUDED_ERROR_H
#define INCLUDED_ERROR_H

typedef enum _Error
{
    kError_NoErr                = 0,
    kError_UnknownErr           = 1,
    kError_InvalidParam         = 2,
    kError_NoFiles              = 5,
    kError_BufferTooSmall       = 7,
    kError_OutOfMemory          = 8,
    kError_FileNoAccess         = 9,
    kError_FileExists           = 10,
    kError_FileInvalidArg       = 11,
    kError_FileNotFound         = 12,
    kError_FileNoHandles        = 13,
    kError_NullValueInvalid     = 15,
    kError_InvalidError         = 16,
    kError_ReadTOCError         = 17,
    kError_HTTPFileNotFound     = 30,
    kError_DownloadDenied       = 31,
    kError_Interrupt            = 32,
    kError_ConnectFailed        = 33,
    kError_UserCancel           = 34,
    kError_CantCreateSocket     = 35,
    kError_CannotSetSocketOpts  = 36,
    kError_CannotBind           = 37,
    kError_ParseError           = 39,
    kError_NotFound             = 40,
    kError_ProtocolNotSupported = 48,
    kError_InvalidURL           = 49,
    kError_CantFindHost         = 50,
    kError_IOError              = 51,
    kError_UnknownServerError   = 52,
    kError_BadHTTPRequest       = 53,
    kError_AccessNotAuthorized  = 54,
    kError_AccessForbidden      = 55,  
    kError_RangeNotExceptable   = 56,
    kError_WriteFile            = 57,
    kError_ReadFile             = 58,
    kError_InvalidVersion       = 59,
    kError_Timeout              = 60,
    kError_LastError            = 9999
} Error;


#define IsError( err )		( (err) != kError_NoErr )
#define IsntError( err )	( (err) == kError_NoErr )

#endif /* INCLUDED_ERROR_H */
