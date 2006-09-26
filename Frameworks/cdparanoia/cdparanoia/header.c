/******************************************************************
 * CopyPolicy: GNU Public License 2 applies
 * Copyright (C) 1998 Monty xiphmont@mit.edu
 * and Heiko Eissfeldt heiko@escape.colossus.de
 *
 * Writes wav and aifc headers
 *
 ******************************************************************/

#include <unistd.h>
#include <stdio.h>
#include <string.h>

static void PutNum(long num,int f,int endianness,int bytes){
  int i;
  unsigned char c;

  if(!endianness)
    i=0;
  else
    i=bytes-1;
  while(bytes--){
    c=(num>>(i<<3))&0xff;
    if(write(f,&c,1)==-1){
      perror("Could not write to output.");
      exit(1);
    }
    if(endianness)
      i--;
    else
      i++;
  }
}

void WriteWav(int f,long bytes){
  /* quick and dirty */

  write(f,"RIFF",4);               /*  0-3 */
  PutNum(bytes+44-8,f,0,4);        /*  4-7 */
  write(f,"WAVEfmt ",8);           /*  8-15 */
  PutNum(16,f,0,4);                /* 16-19 */
  PutNum(1,f,0,2);                 /* 20-21 */
  PutNum(2,f,0,2);                 /* 22-23 */
  PutNum(44100,f,0,4);             /* 24-27 */
  PutNum(44100*2*2,f,0,4);         /* 28-31 */
  PutNum(4,f,0,2);                 /* 32-33 */
  PutNum(16,f,0,2);                /* 34-35 */
  write(f,"data",4);               /* 36-39 */
  PutNum(bytes,f,0,4);             /* 40-43 */
}

void WriteAiff(int f,long bytes){
  long size=bytes+54;
  long frames=bytes/4;

  /* Again, quick and dirty */

  write(f,"FORM",4);             /*  4 */
  PutNum(size-8,f,1,4);          /*  8 */
  write(f,"AIFF",4);             /* 12 */

  write(f,"COMM",4);             /* 16 */
  PutNum(18,f,1,4);              /* 20 */
  PutNum(2,f,1,2);               /* 22 */
  PutNum(frames,f,1,4);          /* 26 */    
  PutNum(16,f,1,2);              /* 28 */
  write(f,"@\016\254D\0\0\0\0\0\0",10); /* 38 (44.100 as a float) */

  write(f,"SSND",4);             /* 42 */
  PutNum(bytes+8,f,1,4);         /* 46 */
  PutNum(0,f,1,4);               /* 50 */
  PutNum(0,f,1,4);               /* 54 */

}

void WriteAifc(int f,long bytes){
  long size=bytes+86;
  long frames=bytes/4;

  /* Again, quick and dirty */

  write(f,"FORM",4);             /*  4 */
  PutNum(size-8,f,1,4);          /*  8 */
  write(f,"AIFC",4);             /* 12 */
  write(f,"FVER",4);             /* 16 */
  PutNum(4,f,1,4);               /* 20 */
  PutNum(2726318400UL,f,1,4);    /* 24 */

  write(f,"COMM",4);             /* 28 */
  PutNum(38,f,1,4);              /* 32 */
  PutNum(2,f,1,2);               /* 34 */
  PutNum(frames,f,1,4);          /* 38 */    
  PutNum(16,f,1,2);              /* 40 */
  write(f,"@\016\254D\0\0\0\0\0\0",10); /* 50 (44.100 as a float) */

  write(f,"NONE",4);             /* 54 */
  PutNum(14,f,1,1);              /* 55 */
  write(f,"not compressed",14);  /* 69 */
  PutNum(0,f,1,1);               /* 70 */

  write(f,"SSND",4);             /* 74 */
  PutNum(bytes+8,f,1,4);         /* 78 */
  PutNum(0,f,1,4);               /* 82 */
  PutNum(0,f,1,4);               /* 86 */

}

