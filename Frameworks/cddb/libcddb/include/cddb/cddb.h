/*
    $Id: cddb.h,v 1.12 2005/05/29 08:06:11 airborne Exp $

    Copyright (C) 2003, 2004, 2005 Kris Verbeeck <airborne@advalvas.be>

    This library is free software; you can redistribute it and/or
    modify it under the terms of the GNU Library General Public
    License as published by the Free Software Foundation; either
    version 2 of the License, or (at your option) any later version.

    This library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    Library General Public License for more details.

    You should have received a copy of the GNU Library General Public
    License along with this library; if not, write to the
    Free Software Foundation, Inc., 59 Temple Place - Suite 330,
    Boston, MA  02111-1307, USA.
*/

#ifndef CDDB_H
#define CDDB_H 1

#include <cddb/version.h>

#ifdef __cplusplus
    extern "C" {
#endif


#include <cddb/cddb_config.h>
#include <cddb/cddb_error.h>
#include <cddb/cddb_track.h>
#include <cddb/cddb_disc.h>
#include <cddb/cddb_site.h>
#include <cddb/cddb_conn.h>
#include <cddb/cddb_cmd.h>
#include <cddb/cddb_log.h>


/**
 * \mainpage libCDDB, a C API for CDDB server access
 */


/**
 * Initializes the library.  This is used to setup any globally used
 * variables.  The first time you create a new CDDB connection structure
 * the library will automatically initialize itself.  So, there is no
 * need to explicitly call this function.
 */
void libcddb_init(void);

/**
 * Frees up any global (cross connection) resources.  You should call
 * this function before terminating your program.  Using any library
 * calls after shutting down are bound to give problems.
 */
void libcddb_shutdown(void);


#ifdef __cplusplus
    }
#endif

#endif /* CDDB_H */
