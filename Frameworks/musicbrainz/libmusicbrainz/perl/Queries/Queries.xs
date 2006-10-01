#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include <musicbrainz/queries.h>

#include "const-c.inc"

MODULE = MusicBrainz::Queries		PACKAGE = MusicBrainz::Queries		

INCLUDE: const-xs.inc
