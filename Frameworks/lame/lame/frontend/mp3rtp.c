/* $Id: mp3rtp.c,v 1.22 2004/12/31 11:26:25 takehiro Exp $ */

/* Still under work ..., need a client for test, where can I get one? */

/* 
 *  experimental translation:
 *
 *  gcc -I..\include -I..\libmp3lame -o mp3rtp mp3rtp.c ../libmp3lame/libmp3lame.a lametime.c get_audio.c portableio.c ieeefloat.c timestatus.c parse.c rtp.c -lm
 *
 *  wavrec -t 14400 -s 44100 -S /proc/self/fd/1 | ./mp3rtp 10.1.1.42 -V2 -b128 -B256 - my_mp3file.mp3
 */

#ifdef HAVE_CONFIG_H
# include <config.h>
#endif

#ifdef STDC_HEADERS
# include <stdlib.h>
# include <string.h>
#else
# ifndef HAVE_STRCHR
#  define strchr index
#  define strrchr rindex
# endif
char *strchr (), *strrchr ();
# ifndef HAVE_MEMCPY
#  define memcpy(d, s, n) bcopy ((s), (d), (n))
#  define memmove(d, s, n) bcopy ((s), (d), (n))
# endif
#endif

#include <time.h>

#ifdef HAVE_UNISTD_H
# include <unistd.h>
#endif

#include "lame.h"
#include "main.h"
#include "parse.h"
#include "lametime.h"
#include "timestatus.h"
#include "get_audio.h"
#include "rtp.h"

#ifdef WITH_DMALLOC
#include <dmalloc.h>
#endif

/*
 * Encode (via LAME) to mp3 with RTP streaming of the output.
 *
 * Author: Felix von Leitner <leitner@vim.org>
 *
 *   mp3rtp ip[:port[:ttl]] [lame encoding options] infile outfile
 *
 * examples:
 *   arecord -b 16 -s 22050 -w | ./mp3rtp 224.17.23.42:5004:2 -b 56 - /dev/null
 *   arecord -b 16 -s 44100 -w | ./mp3rtp 10.1.1.42 -V2 -b128 -B256 - my_mp3file.mp3
 *
 */

struct rtpheader    RTPheader;
struct sockaddr_in  rtpsi;
int                 rtpsocket;

void  rtp_output ( const char* mp3buffer, const int mp3size )
{
    sendrtp (rtpsocket, &rtpsi, &RTPheader, mp3buffer, mp3size);
    RTPheader.timestamp += 5;
    RTPheader.b.sequence++;
}

#if 0
struct rtpheader RTPheader;
SOCKET rtpsocket;

void rtp_output (char *mp3buffer, int mp3size)
{
    rtp_send (rtpsocket, &RTPheader,mp3buffer,mp3size) ;
    RTPheader.timestamp+=5;
    RTPheader.b.sequence++;
}
#endif




unsigned int  maxvalue ( int  Buffer [2] [1152] )
{
    unsigned int  max = 0;
    int  i;
    
    for ( i = 0; i < 1152; i++ ) {
        if ( abs (Buffer[0][i]) > max ) max = abs (Buffer[0][i]);
        if ( abs (Buffer[1][i]) > max ) max = abs (Buffer[1][i]);
    }
    
    return max;
}

void levelmessage ( unsigned int maxvalue )
{
    char buff[] = "|  .  |  .  |  .  |  .  |  .  |  .  |  .  |  .  |  .  |  .  |  \r";
    static int  max = 0;
    static int  tmp = 0;

    buff [tmp] = '+';
    tmp = (maxvalue*61 + 16384) / (32767 + 16384/61);
    if (tmp > sizeof(buff)-2)
	tmp = sizeof(buff)-2;
    if (max < tmp)
	max = tmp;
    buff [max] = 'x';
    buff [tmp] = '#';
    fwrite ( buff, 1, sizeof(buff)-1, stderr );
}


/************************************************************************
*
* main
*
* PURPOSE:  MPEG-1,2 Layer III encoder with GPSYCHO 
* psychoacoustic model.
*
************************************************************************/

int  main ( int argc, char **argv )
{
    unsigned char       mp3buffer [LAME_MAXMP3BUFFER];
    char       inPath    [PATH_MAX + 1];
    char       outPath   [PATH_MAX + 1];
    int        Buffer [2] [1152];

    lame_global_flags *gf;
    
    int        ret;
    int        wavsamples;
    int        mp3bytes;
    FILE*      outf;

    char       ip [16];
    unsigned   port = 5004;
    unsigned   ttl  =    2;
    char       dummy;

    if ( argc <= 2 ) {
        fprintf ( stderr, 
"Encode (via LAME) to mp3 with RTP streaming of the output\n"
"\n"
"    mp3rtp ip[:port[:ttl]] [lame encoding options] infile outfile\n"
"\n"
"    examples:\n"
"      arecord -b 16 -s 22050 -w | ./mp3rtp 224.17.23.42:5004:2 -b 56 - /dev/null\n"
"      arecord -b 16 -s 44100 -w | ./mp3rtp 10.1.1.42 -V2 -b128 -B256 - my_mp3file.mp3\n"
"\n" );

	return 1;
    }

    switch (sscanf ( argv[1], "%11[.0-9]:%u:%u%c", ip, &port, &ttl, &dummy )) {
    case 1:
    case 2:
    case 3: 
        break;
    default:
        fprintf (stderr, "Illegal destination selector '%s', must be ip[:port[:ttl]]\n", argv[1] );
	return -1;
    }

    rtpsocket = makesocket ( ip, port, ttl, &rtpsi );
    srand ( getpid () ^ time (NULL) );
    initrtp ( &RTPheader );

    /* initialize encoder */
    gf=lame_init();

    /* Remove the argumets that are rtp related, and then 
     * parse the command line arguments, setting various flags in the
     * struct pointed to by 'gf'.  If you want to parse your own arguments,
     * or call libmp3lame from a program which uses a GUI to set arguments,
     * skip this call and set the values of interest in the gf struct.  
     * (see lame.h for documentation about these parameters)
     */
     
    argv[1] = argv[0]; 
    parse_args(gf, argc - 1, argv + 1, inPath, outPath,NULL,NULL);

    /* open the output file.  Filename parsed into gf.inPath */
    if ( 0 == strcmp ( outPath, "-" ) ) {
        lame_set_stream_binary_mode (outf = stdout);
    }
    else {
        if ((outf = fopen (outPath, "wb+")) == NULL) {
            fprintf (stderr, "Could not create \"%s\".\n", outPath);
            return 1;
        }
    }


    /* open the wav/aiff/raw pcm or mp3 input file.  This call will
     * open the file with name gf.inFile, try to parse the headers and
     * set gf.samplerate, gf.num_channels, gf.num_samples.
     * if you want to do your own file input, skip this call and set
     * these values yourself.  
     */
    init_infile(gf,inPath);


    /* Now that all the options are set, lame needs to analyze them and
     * set some more options 
     */
    ret = lame_init_params(gf);
    if ( ret < 0 ) {
        if (ret == -1) display_bitrates (stderr);
        fprintf (stderr, "fatal error during initialization\n");
        return -1;
    }

    lame_print_config(gf); /* print useful information about options being used */

    if (update_interval < 0.)
        update_interval = 2.;

    /* encode until we hit EOF */
    while ( (wavsamples = get_audio(gf, Buffer)) > 0 ) { /* read in 'wavsamples' samples */
        levelmessage ( maxvalue (Buffer) );
        mp3bytes = lame_encode_buffer_int(gf,            /* encode the frame */
	                                Buffer[0], Buffer[1], wavsamples, 
					mp3buffer, sizeof (mp3buffer) );

        rtp_output ( mp3buffer, mp3bytes );       /* write MP3 output to RTP port */
        fwrite ( mp3buffer, 1, mp3bytes, outf );  /* write the MP3 output to file */
    }

    mp3bytes = lame_encode_flush(gf,           /* may return one or more mp3 frame */ 
                                   mp3buffer, sizeof (mp3buffer) ); 
    rtp_output ( mp3buffer, mp3bytes );           /* write MP3 output to RTP port */
    fwrite ( mp3buffer, 1, mp3bytes, outf );      /* write the MP3 output to file */
    
    lame_mp3_tags_fid(gf, outf ); /* add VBR tags to mp3 file */
    
    lame_close(gf);
    fclose(outf);
    close_infile();                 /* close the sound input file */
    
    return 0;
}

/* end of mp3rtp.c */
