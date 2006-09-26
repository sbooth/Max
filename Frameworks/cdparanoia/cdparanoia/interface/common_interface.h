/******************************************************************
 * CopyPolicy: GNU Public License 2 applies
 * Copyright (C) 1998 Monty xiphmont@mit.edu
 *
 ******************************************************************/

#ifndef _cdda_common_interface_h_
#define _cdda_common_interface_h_

#include "low_interface.h"

extern int ioctl_ping_cdrom(int fd);
extern char *atapi_drive_info(int fd);
extern int data_bigendianp(cdrom_drive *d);
extern int FixupTOC(cdrom_drive *d,int tracks);

#endif
