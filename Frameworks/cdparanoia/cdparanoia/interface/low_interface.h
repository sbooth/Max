/******************************************************************
 * CopyPolicy: GNU Public License 2 applies
 * Copyright (C) 1998 Monty xiphmont@mit.edu
 * 
 * internal include file for cdda interface kit for Linux 
 *
 ******************************************************************/

#ifndef _cdda_low_interface_
#define _cdda_low_interface_


#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>
#include <fcntl.h>

#include <sys/ioctl.h>
#include <sys/stat.h>
#include <sys/ipc.h>
#include <sys/sem.h>
#include <sys/shm.h>
#include <sys/time.h>
#include <sys/types.h>

#ifndef __APPLE__
#include <linux/major.h>
#include <linux/version.h>
#endif /* __APPLE__ */

/* some include file locations have changed with newer kernels */

#ifdef SBPCD_H
#include <linux/sbpcd.h>
#endif

#ifdef UCDROM_H
#include <linux/ucdrom.h>
#endif

#ifndef CDROMAUDIOBUFSIZ      
#define CDROMAUDIOBUFSIZ        0x5382 /* set the audio buffer size */
#endif

#ifndef __APPLE__
#include <scsi/sg.h>
#include <scsi/scsi.h>

#include <linux/cdrom.h>
#include <linux/major.h>
#endif /* __APPLE__ */

#include "cdda_interface.h"

#define MAX_RETRIES 8
#define MAX_BIG_BUFF_SIZE 65536
#define MIN_BIG_BUFF_SIZE 4096
#define SG_OFF sizeof(struct sg_header)

#ifndef SG_EMULATED_HOST
/* old kernel version; the check for the ioctl is still runtime, this
   is just to build */
#define SG_EMULATED_HOST 0x2203
#define SG_SET_TRANSFORM 0x2204
#define SG_GET_TRANSFORM 0x2205
#endif

extern int  cooked_init_drive (cdrom_drive *d);
extern unsigned char *scsi_inquiry (cdrom_drive *d);
extern int  scsi_init_drive (cdrom_drive *d);
#ifdef CDDA_TEST
extern int  test_init_drive (cdrom_drive *d);
#endif
#endif

