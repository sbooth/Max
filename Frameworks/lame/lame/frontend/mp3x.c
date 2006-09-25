/* $Id: mp3x.c,v 1.19 2005/03/13 17:01:54 robert Exp $ */

#ifdef HAVE_CONFIG_H
# include <config.h>
#endif

#include "lame.h"

#include <stdio.h>

#include "lame-analysis.h"
#include <gtk/gtk.h>
#include "parse.h"
#include "get_audio.h"
#include "gtkanal.h"
#include "lametime.h"

#include "main.h"

#ifdef WITH_DMALLOC
#include <dmalloc.h>
#endif




/************************************************************************
*
* main
*
* PURPOSE:  MPEG-1,2 Layer III encoder with GPSYCHO 
* psychoacoustic model.
*
************************************************************************/
int main(int argc, char **argv)
{
  char mp3buffer[LAME_MAXMP3BUFFER];
  lame_global_flags *gf;  
  char outPath[PATH_MAX + 1];
  char inPath[PATH_MAX + 1];
  int ret;

  gf=lame_init();
  if(argc <=1 ) {
    usage(stderr, argv[0]);  /* no command-line args  */
    return -1;
  }
  ret = parse_args(gf,argc, argv, inPath, outPath,NULL,NULL); 
  if (ret < 0)
    return ret == -2 ? 0 : 1;
  
  (void) lame_set_analysis( gf, 1 );

  init_infile(gf,inPath);
  lame_init_params(gf);
  lame_print_config(gf);


  gtk_init (&argc, &argv);
  gtkcontrol(gf,inPath);

  lame_encode_finish(gf,mp3buffer,sizeof(mp3buffer));
  close_infile();
  return 0;
}

