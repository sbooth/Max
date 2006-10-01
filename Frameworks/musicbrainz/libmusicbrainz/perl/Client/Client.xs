/* --------------------------------------------------------------------------

   MusicBrainz Perl XS Interface -- The Internet music metadatabase
     $Id: Client.xs 754 2005-10-27 06:35:56Z sander $
----------------------------------------------------------------------------*/

#ifdef __cplusplus      
  extern "C" {
#endif    
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#ifdef __cplusplus
  }
#endif

#ifndef _MB_C_H_
#  include <musicbrainz/mb_c.h>
#endif       

#include "ppport.h"
        
#include "const-c.inc"
   
#define MB_ERROR_LENGTH    256
#define MB_RESULT_LENGTH   256
#define MB_ID_LENGTH       256
#define MB_FRAGMENT_LENGTH  64
#define MB_URL_LENGTH     1024
        
   
/* int* helper routines for default typemap T_ARRAY */
typedef int intArray;
void* intArrayPtr(int num) {
  SV* mortal;
  mortal = sv_2mortal( NEWSV(0, num * sizeof(intArray) ));
  return (intArray*) SvPVX(mortal);
}       

/* int* helper routines for default typemap T_PACKEDARRAY */
char** XS_unpack_charPtrPtr(SV* arg) {
  AV* avref;
  char** array;
  STRLEN len;
  SV** elem;
  int i;

  if(!SvROK(arg))
    croak("XS_unpack_charPtrPtr: arg is not a reference");
  if( SvTYPE(SvRV(arg)) != SVt_PVAV)
    croak("XS_unpack_charPtrPtr: arg is not an array");
  avref = (AV*)SvRV(arg);
  len = av_len( avref) + 1;
  array = (char **) SvPVX( sv_2mortal( NEWSV(0, (len +1) * sizeof( char*) )));
  for(i = 0; i < len; i++ ) {
    elem = av_fetch( avref, i, 0);
    array[i] = (char *) SvPV( *elem, PL_na);
  }
  array[len] = NULL;
  return array;
}

   
void XS_pack_charPtrPtr( SV* arg, char** array, int count) {
  int i;
  AV* avref;

  avref = (AV*) sv_2mortal((SV*) newAV() );
  for( i = 0; i < count; i++) {
    av_push(avref, newSVpv(array[i], strlen(array[i])) );
  }
  SvSetSV( arg, newRV((SV*) avref) );
}

/* Help perl find the deconstructor */
#define mb_DESTROY(mb)          mb_Delete(mb)
   
MODULE = MusicBrainz::Client    PACKAGE = MusicBrainz::Client PREFIX= mb_
 
PROTOTYPES: ENABLE

INCLUDE: const-xs.inc

musicbrainz_t
mb_new(char* CLASS)
PROTOTYPE: $
CODE:
  RETVAL = mb_New();
OUTPUT:
  RETVAL

void
mb_DESTROY(musicbrainz_t mb)
PROTOTYPE: $

void
mb_get_version(musicbrainz_t mb)
PROTOTYPE: $
PREINIT:
  int major = 0;
  int minor = 0;
  int rev = 0;
PPCODE:
  mb_GetVersion(mb,&major,&minor,&rev);
  XPUSHs(sv_2mortal(newSViv(major)));
  XPUSHs(sv_2mortal(newSViv(minor)));
  XPUSHs(sv_2mortal(newSViv(rev)));


int
mb_set_server(musicbrainz_t mb, char* serverAddr, short serverPort)
PROTOTYPE: $$$
CODE:
  RETVAL = mb_SetServer(mb,serverAddr,serverPort);  
OUTPUT:
  RETVAL  

void
mb_set_debug(musicbrainz_t mb, int debug)
PROTOTYPE: $$
CODE:
  mb_SetDebug(mb,debug);


int
mb_set_proxy(musicbrainz_t mb, char* serverAddr, short serverPort)
PROTOTYPE: $$$
CODE:
  RETVAL= mb_SetProxy(mb,serverAddr,serverPort);
OUTPUT:
  RETVAL

#
# XXX: WINDOWS ONLY

#ifdef WIN32

void  
mb_WSAInit(musicbrainz_t mb)
PROTOTYPE: $

void       
mb_WSAStop(musicbrainz_t mb)
PROTOTYPE: $

#endif

int
mb_authenticate(musicbrainz_t mb, char* userName, char* password) 
PROTOTYPE: $$$
CODE:
  RETVAL = mb_Authenticate(mb,userName,password);
OUTPUT:
  RETVAL

int
mb_set_device(musicbrainz_t mb, char* device)
PROTOTYPE: $$
CODE:
  RETVAL = mb_SetDevice(mb,device); 
OUTPUT:
  RETVAL

void
mb_use_utf8(musicbrainz_t mb, int useUTF8)
PROTOTYPE: $$
CODE:
  mb_UseUTF8(mb,useUTF8);

void
mb_set_depth(musicbrainz_t mb, int depth)
PROTOTYPE: $$
CODE:
  mb_SetDepth(mb,depth);

void
mb_set_max_items(musicbrainz_t mb, int maxItems)
PROTOTYPE: $$
CODE:
  mb_SetMaxItems(mb,maxItems);


int
mb_query(musicbrainz_t mb, char* rdfObject)
PROTOTYPE: $$
CODE:
  RETVAL = mb_Query(mb,rdfObject);
OUTPUT:
  RETVAL
   
int
mb_query_with_args(musicbrainz_t mb, char* rdfObject, char **args)
PROTOTYPE: $$\@
CODE:
  RETVAL = mb_QueryWithArgs(mb,rdfObject, args);
OUTPUT:
  RETVAL

char*
mb_get_web_submit_url(musicbrainz_t mb)
PROTOTYPE: $
PREINIT:
   char url[MB_URL_LENGTH];
   int status;
CODE:
  status = mb_GetWebSubmitURL(mb,url, MB_URL_LENGTH);
  RETVAL = url;
OUTPUT:
  RETVAL
CLEANUP:
  if(status == 0) 
    XSRETURN_UNDEF;

char *
mb_get_query_error(musicbrainz_t mb)
PROTOTYPE: $
PREINIT:
   char error[MB_ERROR_LENGTH];
CODE:
  mb_GetQueryError(mb,error, MB_ERROR_LENGTH);
  RETVAL = error;
OUTPUT:
  RETVAL

int
mb_select(musicbrainz_t mb, char* selectQuery)
PROTOTYPE: $$
CODE:
  RETVAL = mb_Select(mb,selectQuery);
OUTPUT:
  RETVAL
   
int
mb_select1(musicbrainz_t mb, char* selectQuery, int ord)
PROTOTYPE: $$$
CODE:
  RETVAL = mb_Select1(mb,selectQuery,ord);
OUTPUT:
  RETVAL

# XXX: Still needs work here.
#int
#mb_select_with_args(musicbrainz_t mb, char* selectQuery, intArray* ordinals)
#PROTOTYPE: $$@
#CODE:
#  RETVAL = mb_SelectWithArgs(mb,selectQuery,ordinals);
#OUTPUT:
#  RETVAL


char *
mb_get_result_data(musicbrainz_t mb, char* resultName)
PROTOTYPE: $$
PREINIT:
  char data[MB_RESULT_LENGTH];
  int status;
CODE:
  status = mb_GetResultData(mb,resultName, data, MB_RESULT_LENGTH);
  RETVAL = data;
OUTPUT:
  RETVAL
CLEANUP:
  if(status == 0) 
    XSRETURN_UNDEF;

char *
mb_get_result_data1(musicbrainz_t mb, char* resultName, int ordinal)
PROTOTYPE: $$$
PREINIT:
  char data[MB_RESULT_LENGTH];
  int status;
CODE:
  status = mb_GetResultData1(mb,resultName, data, MB_RESULT_LENGTH, ordinal);
  RETVAL = data;
OUTPUT:
  RETVAL
CLEANUP:
  if(status == 0)
    XSRETURN_UNDEF;

int
mb_does_result_exist(musicbrainz_t mb, char* resultName)
PROTOTYPE: $$
CODE:
  RETVAL = mb_DoesResultExist(mb,resultName);
OUTPUT:
  RETVAL

int
mb_does_result_exist1(musicbrainz_t mb, char* resultName, int ordinal)
PROTOTYPE: $$$
CODE:
  RETVAL = mb_DoesResultExist1(mb,resultName,ordinal);
OUTPUT:
  RETVAL

int
mb_get_result_int(musicbrainz_t mb, char* resultName)
PROTOTYPE: $$
CODE:
  RETVAL = mb_GetResultInt(mb,resultName);
OUTPUT:
  RETVAL

int
mb_get_result_int1(musicbrainz_t mb, char* resultName, int ordinal)
PROTOTYPE: $$$
CODE:
  RETVAL = mb_GetResultInt1(mb,resultName,ordinal);
OUTPUT:
  RETVAL
  
SV*
mb_get_result_rdf(musicbrainz_t mb)         
PROTOTYPE: $ 
PREINIT:
  SV* rdf;     
  char* rdfPtr;
  int status;
CODE:
  rdf =  sv_2mortal( NEWSV(0, mb_GetResultRDFLen(mb) ));
  rdfPtr = SvPVX( rdf);
  status = mb_GetResultRDF(mb, rdfPtr, strlen(rdfPtr));
  RETVAL = rdf;
OUTPUT:
  RETVAL
CLEANUP:
  if(status == 0)
    XSRETURN_UNDEF;

# No need to expose this to perl.
#int
#mb_GetResultRDFLen(musicbrainz_t mb)
#PROTOTYPE: $

int
mb_set_result_rdf(musicbrainz_t mb, char* RDF)
PROTOTYPE: $$
CODE:
  RETVAL = mb_SetResultRDF(mb,RDF);
OUTPUT:
  RETVAL

char*
mb_get_id_from_url(musicbrainz_t mb, char* url)
PROTOTYPE: $$
PREINIT:
  char id[MB_ID_LENGTH];
CODE:
  mb_GetIDFromURL(mb,url,id, MB_ID_LENGTH);
  RETVAL = id;
OUTPUT:
  RETVAL
  

char*
mb_get_fragment_from_url(musicbrainz_t mb, char* url)
PROTOTYPE: $$
PREINIT:
  char fragment[MB_FRAGMENT_LENGTH]; 
CODE:
  mb_GetFragmentFromURL(mb,url,fragment,MB_FRAGMENT_LENGTH);
  RETVAL = fragment;
OUTPUT:
  RETVAL

int
mb_get_ordinal_from_list(musicbrainz_t mb, char* listType, char* URI)
PROTOTYPE: $$$
CODE:
  RETVAL = mb_GetOrdinalFromList(mb,listType,URI);
OUTPUT:
  RETVAL

void
mb_get_mp3_info(musicbrainz_t mb, char* filename)
PROTOTYPE: $$
PREINIT:
  int duration = 0;
  int bitrate  = 0;
  int stereo   = 0;
  int samplerate = 0;   
PPCODE:  
  mb_GetMP3Info(mb,filename,&duration,&bitrate,&stereo,&samplerate);
  XPUSHs(sv_2mortal(newSViv(duration)));
  XPUSHs(sv_2mortal(newSViv(bitrate)));
  XPUSHs(sv_2mortal(newSViv(stereo)));
  XPUSHs(sv_2mortal(newSViv(samplerate)));
