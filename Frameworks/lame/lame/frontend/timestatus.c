/*
 *	time status related function source file
 *
 *	Copyright (c) 1999 Mark Taylor
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	 See the GNU
 * Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public
 * License along with this library; if not, write to the
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 */

/* $Id: timestatus.c,v 1.40 2005/02/25 01:21:54 robert Exp $ */

#ifdef HAVE_CONFIG_H
# include <config.h>
#endif


/* Hope it works now, otherwise complain or flame ;-)
 */


#if 1
# define SPEED_CHAR	"x" /* character x */
# define SPEED_MULT	1.
#else
# define SPEED_CHAR	"%%"
# define SPEED_MULT	100.
#endif

#include <assert.h>
#include <time.h>

#include "lame.h"
#include "main.h"
#include "lametime.h"
#include "timestatus.h"

#if defined(BRHIST)
# include "brhist.h"
#endif

#ifdef WITH_DMALLOC
#include <dmalloc.h>
#endif

typedef struct {
    double  last_time;       /* result of last call to clock */
    double  elapsed_time;    /* total time */
    double  estimated_time;  /* estimated total duration time [s] */
    double  speed_index;     /* speed relative to realtime coding [100%] */
} timestatus_t;

/*
 *  Calculates from the input (see below) the following values:
 *    - total estimated time
 *    - a speed index
 */

static void
ts_calc_times(timestatus_t * const tstime, /* tstime->elapsed_time: elapsed time */
              const int sample_freq, /* sample frequency [Hz/kHz]  */
              const int frameNum, /* Number of the current Frame */
              const int totalframes, /* total umber of Frames */
              const int framesize)
{                       /* Size of a frame [bps/kbps] */
    assert(sample_freq >= 8000 && sample_freq <= 48000);

    if (frameNum > 0 && tstime->elapsed_time > 0) {
        tstime->estimated_time = tstime->elapsed_time * totalframes / frameNum;
        tstime->speed_index = framesize * frameNum / (sample_freq * tstime->elapsed_time);
    }
    else {
        tstime->estimated_time = 0.;
        tstime->speed_index = 0.;
    }
}

/* Decomposes a given number of seconds into a easy to read hh:mm:ss format
 * padded with an additional character
 */

static void
ts_time_decompose(const unsigned long time_in_sec, const char padded_char)
{
    const unsigned long hour = time_in_sec / 3600;
    const unsigned int min = time_in_sec / 60 % 60;
    const unsigned int sec = time_in_sec % 60;

    if (hour == 0)
        fprintf(stderr, "   %2u:%02u%c", min, sec, padded_char);
    else if (hour < 100)
        fprintf(stderr, "%2lu:%02u:%02u%c", hour, min, sec, padded_char);
    else
        fprintf(stderr, "%6lu h%c", hour, padded_char);
}

void
timestatus(int samp_rate, int frameNum, int totalframes, int framesize)
{
    static timestatus_t real_time;
    static timestatus_t proc_time;
    int     percent;
    static int init = 0;     /* What happens here? A work around instead of a bug fix ??? */
    double  tmx, delta;

    if (totalframes < frameNum) {
        totalframes = frameNum;
    }
    if (frameNum == 0) {
        real_time.last_time = GetRealTime();
        proc_time.last_time = GetCPUTime();
        real_time.elapsed_time = 0;
        proc_time.elapsed_time = 0;
    }

    /* we need rollover protection for GetCPUTime, and maybe GetRealTime(): */
    tmx = GetRealTime();
    delta = tmx - real_time.last_time;
    if (delta < 0)
        delta = 0;      /* ignore, clock has rolled over */
    real_time.elapsed_time += delta;
    real_time.last_time = tmx;


    tmx = GetCPUTime();
    delta = tmx - proc_time.last_time;
    if (delta < 0)
        delta = 0;      /* ignore, clock has rolled over */
    proc_time.elapsed_time += delta;
    proc_time.last_time = tmx;

    if (frameNum == 0 && init == 0) {
        fprintf(stderr,
                "\r"
                "    Frame          |  CPU time/estim | REAL time/estim | play/CPU |    ETA \n"
                "     0/       ( 0%%)|    0:00/     :  |    0:00/     :  |         " SPEED_CHAR
                "|     :  \r"
                /* , Console_IO.str_clreoln, Console_IO.str_clreoln */ );
        init = 1;
        return;
    }
    /* reset init counter for next time we are called with frameNum==0 */
    if (frameNum > 0)
        init = 0;

    ts_calc_times(&real_time, samp_rate, frameNum, totalframes, framesize);
    ts_calc_times(&proc_time, samp_rate, frameNum, totalframes, framesize);

    if (frameNum < totalframes) {
        percent = (int) (100. * frameNum / totalframes + 0.5);
    }
    else {
        percent = 100;
    }

    fprintf(stderr, "\r%6i/%-6i", frameNum, totalframes);
    fprintf(stderr, percent < 100 ? " (%2d%%)|" : "(%3.3d%%)|", percent);
    ts_time_decompose((unsigned long) proc_time.elapsed_time, '/');
    ts_time_decompose((unsigned long) proc_time.estimated_time, '|');
    ts_time_decompose((unsigned long) real_time.elapsed_time, '/');
    ts_time_decompose((unsigned long) real_time.estimated_time, '|');
    fprintf(stderr, proc_time.speed_index <= 1. ?
            "%9.4f" SPEED_CHAR "|" : "%#9.5g" SPEED_CHAR "|", SPEED_MULT * proc_time.speed_index);
    ts_time_decompose((unsigned long) (real_time.estimated_time - real_time.elapsed_time), ' ');
    fflush(stderr);
}

void
timestatus_finish(void)
{
    fprintf(stderr, "\n");
    fflush(stderr);
}

void
timestatus_klemm(const lame_global_flags * const gfp)
{
    static double last_time = 0.;

    if (silent <= 0)
        if (lame_get_frameNum(gfp) == 0 ||
            lame_get_frameNum(gfp) == 9 ||
            GetRealTime() - last_time >= update_interval || GetRealTime() - last_time < 0) {
#ifdef BRHIST
            brhist_jump_back();
#endif
            timestatus(lame_get_out_samplerate(gfp),
                       lame_get_frameNum(gfp), lame_get_totalframes(gfp), lame_get_framesize(gfp));
#ifdef BRHIST
            if (brhist) {
                brhist_disp(gfp);
            }
#endif
            last_time = GetRealTime(); /* from now! disp_time seconds */
        }
}

/* these functions are used in get_audio.c */

void
decoder_progress(const lame_global_flags * const gfp, const mp3data_struct * const mp3data)
{
    static int last;
    fprintf(stderr, "\rFrame#%6i/%-6i %3i kbps",
            mp3data->framenum, mp3data->totalframes, mp3data->bitrate);

    /* Programmed with a single frame hold delay */
    /* Attention: static data */

    /* MP2 Playback is still buggy. */
    /* "'00' subbands 4-31 in intensity_stereo, bound==4" */
    /* is this really intensity_stereo or is it MS stereo? */

    if (mp3data->mode == JOINT_STEREO) {
        int     curr = mp3data->mode_ext;
        fprintf(stderr, "  %s  %c",
                curr & 2 ? last & 2 ? " MS " : "LMSR" : last & 2 ? "LMSR" : "L  R",
                curr & 1 ? last & 1 ? 'I' : 'i' : last & 1 ? 'i' : ' ');
        last = curr;
    }
    else {
        fprintf(stderr, "         ");
        last = 0;
    }
/*    fprintf ( stderr, "%s", Console_IO.str_clreoln ); */
    fprintf(stderr, "        \b\b\b\b\b\b\b\b");
    fflush(stderr);
}

void
decoder_progress_finish(const lame_global_flags * const gfp)
{
    fprintf(stderr, "\n");
}
