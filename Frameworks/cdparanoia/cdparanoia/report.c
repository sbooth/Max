#include <stdio.h>
#include "interface/cdda_interface.h"

int quiet=0;
int verbose=CDDA_MESSAGE_FORGETIT;

void report(char *s){
  if(!quiet){
    fprintf(stderr,s);
    fputc('\n',stderr);
  }
}

void report2(char *s, char *s2){
  if(!quiet){
    fprintf(stderr,s,s2);
    fputc('\n',stderr);
  }
}

void report3(char *s, char *s2, char *s3){
  if(!quiet){
    fprintf(stderr,s,s2,s3);
    fputc('\n',stderr);
  }
}
