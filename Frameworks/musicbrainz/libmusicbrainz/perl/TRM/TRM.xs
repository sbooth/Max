/* --------------------------------------------------------------------------

   MusicBrainz Perl XS Interface -- The Internet music metadatabase
     $Id: TRM.xs 777 2005-11-20 03:57:01Z sander $
----------------------------------------------------------------------------*/

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#ifndef _MB_C_H_
#  include <musicbrainz/mb_c.h>
#endif

/* define some string lengths */
#define MB_SIG_LENGTH		17
#define MB_SIG_ASCII_LENGTH 	37

/* Help perl find the deconstructor */
#define trm_DESTROY(mb)          trm_Delete(mb)

MODULE = MusicBrainz::TRM		PACKAGE = MusicBrainz::TRM		PREFIX = trm_

PROTOTYPES: ENABLE

trm_t
trm_new(char* CLASS)
PROTOTYPE: $
CODE:
  RETVAL = trm_New();
OUTPUT:
  RETVAL

void
trm_DESTROY(trm_t trm)
PROTOTYPE: $

int
trm_set_proxy(trm_t trm, char* serverAddr, short serverPort)
PROTOTYPE: $$$
PREINIT:
CODE:
  RETVAL = trm_SetProxy(trm,serverAddr,serverPort);
OUTPUT:
  RETVAL

void
trm_set_pcm_data_info(trm_t o, int samplesPerSecond, int numChannels, int bitsPerSample)
PROTOTYPE: $$$$
CODE:
  trm_SetPCMDataInfo(o,samplesPerSecond,numChannels,bitsPerSample);

void
trm_set_song_length(trm_t o, long seconds)
PROTOTYPE: $$
CODE:
  trm_SetSongLength(o,seconds);

int
trm_generate_signature(trm_t o, SV* data)
PROTOTYPE: $$
CODE:
  RETVAL = trm_GenerateSignature(o,SvPV_nolen(data),SvLEN(data));
OUTPUT:
  RETVAL


char*
trm_finalize_signature(trm_t o, char* collectionId = NULL)
PROTOTYPE: $;$
PREINIT:
  char signature[MB_SIG_LENGTH];
  int success;
CODE:
  success = trm_FinalizeSignature(o,signature,collectionId);
  RETVAL = signature;
OUTPUT:
  RETVAL
CLEANUP:
  if(success != 0)
    XSRETURN_UNDEF;
  
  
char*
trm_convert_sig_to_ascii(trm_t o, char* signature)
PROTOTYPE: $$
PREINIT:
  char ascii_sig[MB_SIG_ASCII_LENGTH];
CODE:
  trm_ConvertSigToASCII(o,signature, ascii_sig);
  RETVAL = ascii_sig;
OUTPUT:
  RETVAL
CLEANUP:
  if(strlen(signature) > MB_SIG_ASCII_LENGTH) {
    warn("MusicBrainz::TRM::convert_sig_to_ascii: signature is larger then allowed ", 
         MB_SIG_ASCII_LENGTH, " chars");
    XSRETURN_UNDEF;
  }

