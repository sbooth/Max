/*
  $Id: cddb_log.c,v 1.5 2005/03/11 21:29:30 airborne Exp $

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


#include "cddb/cddb_ni.h"


#ifdef LOGLEVEL
    static int _min_level = LOGLEVEL;
#else
    static int _min_level = CDDB_LOG_WARN;
#endif

static const char *_level_str[5] = { "debug", "info", "warning", "error", "critical" };

static void default_cddb_log_handler(cddb_log_level_t level, const char *message)
{
    if (level >= _min_level) {
        fprintf(stderr, "%s: %s\n", _level_str[level - 1], message);
        fflush(stderr);
    }
}

static cddb_log_handler_t _handler = default_cddb_log_handler;


void cddb_log_set_level(cddb_log_level_t level)
{
    _min_level = level;
}

cddb_log_handler_t cddb_log_set_handler(cddb_log_handler_t new_handler)
{
    cddb_log_handler_t old_handler = _handler;

    if (!new_handler) {
        new_handler = default_cddb_log_handler;
    }
    _handler = new_handler;
    return old_handler;
}

static void cddb_logv(cddb_log_level_t level, const char *format, va_list args)
{
    char buf[1024] = { 0, };

    vsnprintf(buf, sizeof(buf)-1, format, args);
    _handler(level, buf);
}

void cddb_log(cddb_log_level_t level, const char *format, ...)
{
    va_list args;
    va_start(args, format);
    cddb_logv(level, format, args);
    va_end(args);
}
