#ifndef __APPLE__
#include <endian.h>
#else
#include <unistd.h>		/* STDERR_FILENO */
#include <stdlib.h>		/* realloc */
#endif /* __APPLE__ */
#include <stdio.h>
#include <errno.h>
#include <string.h>

/* I wonder how many alignment issues this is gonna trip in the
   future...  it shouldn't trip any...  I guess we'll find out :) */

static inline int bigendianp(void){
  int test=1;
  char *hack=(char *)(&test);
  if(hack[0])return(0);
  return(1);
}

static inline int32_t swap32(int32_t x){
  return((((u_int32_t)x & 0x000000ffU) << 24) | 
	 (((u_int32_t)x & 0x0000ff00U) <<  8) | 
	 (((u_int32_t)x & 0x00ff0000U) >>  8) | 
	 (((u_int32_t)x & 0xff000000U) >> 24));
}

static inline int16_t swap16(int16_t x){
  return((((u_int16_t)x & 0x00ffU) <<  8) | 
	 (((u_int16_t)x & 0xff00U) >>  8));
}

#if BYTE_ORDER == LITTLE_ENDIAN

static inline int32_t be32_to_cpu(int32_t x){
  return(swap32(x));
}

static inline int16_t be16_to_cpu(int16_t x){
  return(swap16(x));
}

static inline int32_t le32_to_cpu(int32_t x){
  return(x);
}

static inline int16_t le16_to_cpu(int16_t x){
  return(x);
}

#else

static inline int32_t be32_to_cpu(int32_t x){
  return(x);
}

static inline int16_t be16_to_cpu(int16_t x){
  return(x);
}

static inline int32_t le32_to_cpu(int32_t x){
  return(swap32(x));
}

static inline int16_t le16_to_cpu(int16_t x){
  return(swap16(x));
}


#endif

static inline int32_t cpu_to_be32(int32_t x){
  return(be32_to_cpu(x));
}

static inline int32_t cpu_to_le32(int32_t x){
  return(le32_to_cpu(x));
}

static inline int16_t cpu_to_be16(int16_t x){
  return(be16_to_cpu(x));
}

static inline int16_t cpu_to_le16(int16_t x){
  return(le16_to_cpu(x));
}

static inline char *copystring(const char *s){
  if(s){
    char *ret=malloc((strlen(s)+9)*sizeof(char)); /* +9 to get around a linux
						     libc 5 bug. below too */
    strcpy(ret,s);
    return(ret);
  }
  return(NULL);
}

static inline char *catstring(char *buff,const char *s){
  if(s){
    if(buff)
      buff=realloc(buff,strlen(buff)+strlen(s)+9);
    else
      buff=calloc(strlen(s)+9,1);
    strcat(buff,s);
  }
  return(buff);
}

static void cderror(cdrom_drive *d,const char *s){
  if(s && d){
    switch(d->errordest){
    case CDDA_MESSAGE_PRINTIT:
      write(STDERR_FILENO,s,strlen(s));
      break;
    case CDDA_MESSAGE_LOGIT:
      d->errorbuf=catstring(d->errorbuf,s);
      break;
    case CDDA_MESSAGE_FORGETIT:
    default:
#ifdef __APPLE__
      break;
#endif /* __APPLE__ */
    }
  }
}

static void cdmessage(cdrom_drive *d,const char *s){
  if(s && d){
    switch(d->messagedest){
    case CDDA_MESSAGE_PRINTIT:
      write(STDERR_FILENO,s,strlen(s));
      break;
    case CDDA_MESSAGE_LOGIT:
      d->messagebuf=catstring(d->messagebuf,s);
      break;
    case CDDA_MESSAGE_FORGETIT:
    default:
#ifdef __APPLE__
      break;
#endif /* __APPLE__ */
    }
  }
}

static void idperror(int messagedest,char **messages,const char *f,
		      const char *s){

  char *buffer;
  int malloced=0;
  if(!f)
    buffer=(char *)s;
  else
    if(!s)
      buffer=(char *)f;
    else{
      buffer=malloc(strlen(f)+strlen(s)+9);
      sprintf(buffer,f,s);
      malloced=1;
    }

  if(buffer){
    switch(messagedest){
    case CDDA_MESSAGE_PRINTIT:
      write(STDERR_FILENO,buffer,strlen(buffer));
      if(errno){
	write(STDERR_FILENO,": ",2);
	write(STDERR_FILENO,strerror(errno),strlen(strerror(errno)));
	write(STDERR_FILENO,"\n",1);
      }
      break;
    case CDDA_MESSAGE_LOGIT:
      if(messages){
	*messages=catstring(*messages,buffer);
	if(errno){
	  *messages=catstring(*messages,": ");
	  *messages=catstring(*messages,strerror(errno));
	  *messages=catstring(*messages,"\n");
	}
      }
      break;
    case CDDA_MESSAGE_FORGETIT:
    default:
#ifdef __APPLE__
      break;
#endif /* __APPLE__ */
    }
  }
  if(malloced)free(buffer);
}


static void idmessage(int messagedest,char **messages,const char *f,
		      const char *s){
  char *buffer;
  int malloced=0;
  if(!f)
    buffer=(char *)s;
  else
    if(!s)
      buffer=(char *)f;
    else{
      buffer=malloc(strlen(f)+strlen(s)+10);
      sprintf(buffer,f,s);
      strcat(buffer,"\n");
      malloced=1;
    }

  if(buffer){
    switch(messagedest){
    case CDDA_MESSAGE_PRINTIT:
      write(STDERR_FILENO,buffer,strlen(buffer));
      if(!malloced)write(STDERR_FILENO,"\n",1);
      break;
    case CDDA_MESSAGE_LOGIT:
      if(messages){
	*messages=catstring(*messages,buffer);
	if(!malloced)*messages=catstring(*messages,"\n");
	}
      break;
    case CDDA_MESSAGE_FORGETIT:
    default:
#ifdef __APPLE__
      break;
#endif /* __APPLE__ */
    }
  }
  if(malloced)free(buffer);
}

