/******************************************************************
 * CopyPolicy: GNU Public License 2 applies
 * Copyright (C) 1998 Monty xiphmont@mit.edu
 * derived from code (C) 1994-1996 Heiko Eissfeldt
 * 
 * Table of contents convenience functions
 *
 ******************************************************************/

#include "low_interface.h"
#include "utils.h"

long cdda_track_firstsector(cdrom_drive *d,int track){
  if(!d->opened){
    cderror(d,"400: Device not open\n");
    return(-1);
  }

  if (track == 0) {
    if (d->disc_toc[0].dwStartSector == 0) {
      /* first track starts at lba 0 -> no pre-gap */
      cderror(d,"401: Invalid track number\n");
      return(-1);
    }
    else {
      return 0; /* pre-gap of first track always starts at lba 0 */
    }
  }

  if(track<0 || track>d->tracks){
    cderror(d,"401: Invalid track number\n");
    return(-1);
  }
  return(d->disc_toc[track-1].dwStartSector);
}

long cdda_disc_firstsector(cdrom_drive *d){
  int i;
  if(!d->opened){
    cderror(d,"400: Device not open\n");
    return(-1);
  }

  /* look for an audio track */
  for(i=0;i<d->tracks;i++)
    if(cdda_track_audiop(d,i+1)==1) {
      if (i == 0) /* disc starts at lba 0 if first track is an audio track */
       return 0;
      else
       return(cdda_track_firstsector(d,i+1));
    }

  cderror(d,"403: No audio tracks on disc\n");  
  return(-1);
}

long cdda_track_lastsector(cdrom_drive *d,int track){
  if(!d->opened){
    cderror(d,"400: Device not open\n");
    return(-1);
  }

  if (track == 0) {
    if (d->disc_toc[0].dwStartSector == 0) {
      /* first track starts at lba 0 -> no pre-gap */
      cderror(d,"401: Invalid track number\n");
      return(-1);
    }
    else {
      return d->disc_toc[0].dwStartSector-1;
    }
  }

  if(track<1 || track>d->tracks){
    cderror(d,"401: Invalid track number\n");
    return(-1);
  }
  /* Safe, we've always the leadout at disc_toc[tracks] */
  return(d->disc_toc[track].dwStartSector-1);
}

long cdda_disc_lastsector(cdrom_drive *d){
  int i;
  if(!d->opened){
    cderror(d,"400: Device not open\n");
    return(-1);
  }

  /* look for an audio track */
  for(i=d->tracks-1;i>=0;i--)
    if(cdda_track_audiop(d,i+1)==1)
      return(cdda_track_lastsector(d,i+1));

  cderror(d,"403: No audio tracks on disc\n");  
  return(-1);
}

long cdda_tracks(cdrom_drive *d){
  if(!d->opened){
    cderror(d,"400: Device not open\n");
    return(-1);
  }
  return(d->tracks);
}

int cdda_sector_gettrack(cdrom_drive *d,long sector){
  if(!d->opened){
    cderror(d,"400: Device not open\n");
    return(-1);
  }else{
    int i;

    if (sector < d->disc_toc[0].dwStartSector)
      return 0; /* We're in the pre-gap of first track */

    for(i=0;i<d->tracks;i++){
      if(d->disc_toc[i].dwStartSector<=sector &&
	 d->disc_toc[i+1].dwStartSector>sector)
	return (i+1);
    }

    cderror(d,"401: Invalid track number\n");
    return -1;
  }
}

int cdda_track_bitmap(cdrom_drive *d,int track,int bit,int set,int clear){
  if(!d->opened){
    cderror(d,"400: Device not open\n");
    return(-1);
  }

  if (track == 0)
    track = 1; /* map to first track number */

  if(track<1 || track>d->tracks){
    cderror(d,"401: Invalid track number\n");
    return(-1);
  }
  if ((d->disc_toc[track-1].bFlags & bit))
    return(set);
  else
    return(clear);
}


int cdda_track_channels(cdrom_drive *d,int track){
  return(cdda_track_bitmap(d,track,8,4,2));
}

int cdda_track_audiop(cdrom_drive *d,int track){
  return(cdda_track_bitmap(d,track,4,0,1));
}

int cdda_track_copyp(cdrom_drive *d,int track){
  return(cdda_track_bitmap(d,track,2,1,0));
}

int cdda_track_preemp(cdrom_drive *d,int track){
  return(cdda_track_bitmap(d,track,1,1,0));
}

