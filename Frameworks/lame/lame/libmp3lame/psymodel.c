/*
 *	psymodel.c
 *
 *	Copyright (c) 1999-2000 Mark Taylor
 *	Copyright (c) 2001-2002 Naoki Shibata
 *	Copyright (c) 2000-2003 Takehiro Tominaga
 *	Copyright (c) 2000-2005 Robert Hegemann
 *	Copyright (c) 2000-2005 Gabriel Bouvigne
 *	Copyright (c) 2000-2005 Alexander Leidinger
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

/* $Id: psymodel.c,v 1.142.2.2 2006/08/18 18:22:20 bouvigne Exp $ */


/*
PSYCHO ACOUSTICS


This routine computes the psycho acoustics, delayed by one granule.  

Input: buffer of PCM data (1024 samples).  

This window should be centered over the 576 sample granule window.
The routine will compute the psycho acoustics for
this granule, but return the psycho acoustics computed
for the *previous* granule.  This is because the block
type of the previous granule can only be determined
after we have computed the psycho acoustics for the following
granule.  

Output:  maskings and energies for each scalefactor band.
block type, PE, and some correlation measures.  
The PE is used by CBR modes to determine if extra bits
from the bit reservoir should be used.  The correlation
measures are used to determine mid/side or regular stereo.
*/
/*
Notation:

barks:  a non-linear frequency scale.  Mapping from frequency to
        barks is given by freq2bark()

scalefactor bands: The spectrum (frequencies) are broken into 
                   SBMAX "scalefactor bands".  Thes bands
                   are determined by the MPEG ISO spec.  In
                   the noise shaping/quantization code, we allocate
                   bits among the partition bands to achieve the
                   best possible quality

partition bands:   The spectrum is also broken into about
                   64 "partition bands".  Each partition 
                   band is about .34 barks wide.  There are about 2-5
                   partition bands for each scalefactor band.

LAME computes all psycho acoustic information for each partition
band.  Then at the end of the computations, this information
is mapped to scalefactor bands.  The energy in each scalefactor
band is taken as the sum of the energy in all partition bands
which overlap the scalefactor band.  The maskings can be computed
in the same way (and thus represent the average masking in that band)
or by taking the minmum value multiplied by the number of
partition bands used (which represents a minimum masking in that band).
*/
/*
The general outline is as follows:

1. compute the energy in each partition band
2. compute the tonality in each partition band
3. compute the strength of each partion band "masker"
4. compute the masking (via the spreading function applied to each masker)
5. Modifications for mid/side masking.  

Each partition band is considiered a "masker".  The strength
of the i'th masker in band j is given by:

    s3(bark(i)-bark(j))*strength(i)

The strength of the masker is a function of the energy and tonality.
The more tonal, the less masking.  LAME uses a simple linear formula
(controlled by NMT and TMN) which says the strength is given by the
energy divided by a linear function of the tonality.
*/
/*
s3() is the "spreading function".  It is given by a formula
determined via listening tests.  

The total masking in the j'th partition band is the sum over
all maskings i.  It is thus given by the convolution of
the strength with s3(), the "spreading function."

masking(j) = sum_over_i  s3(i-j)*strength(i)  = s3 o strength

where "o" = convolution operator.  s3 is given by a formula determined
via listening tests.  It is normalized so that s3 o 1 = 1.

Note: instead of a simple convolution, LAME also has the
option of using "additive masking"

The most critical part is step 2, computing the tonality of each
partition band.  LAME has two tonality estimators.  The first
is based on the ISO spec, and measures how predictiable the
signal is over time.  The more predictable, the more tonal.
The second measure is based on looking at the spectrum of
a single granule.  The more peaky the spectrum, the more
tonal.  By most indications, the latter approach is better.

Finally, in step 5, the maskings for the mid and side
channel are possibly increased.  Under certain circumstances,
noise in the mid & side channels is assumed to also
be masked by strong maskers in the L or R channels.


Other data computed by the psy-model:

ms_ratio        side-channel / mid-channel masking ratio (for previous granule)
ms_ratio_next   side-channel / mid-channel masking ratio for this granule

percep_entropy[2]     L and R values (prev granule) of PE - A measure of how 
                      much pre-echo is in the previous granule
percep_entropy_MS[2]  mid and side channel values (prev granule) of percep_entropy
energy[4]             L,R,M,S energy in each channel, prev granule
blocktype_d[2]        block type to use for previous granule
*/




#ifdef HAVE_CONFIG_H
# include <config.h>
#endif

#include "util.h"
#include "encoder.h"
#include "psymodel.h"
#include "l3side.h"
#include <assert.h>
#include "tables.h"
#include "fft.h"
#include "machine.h"

#ifdef WITH_DMALLOC
#include <dmalloc.h>
#endif

#define NSFIRLEN 21

#ifdef M_LN10
#define		LN_TO_LOG10		(M_LN10/10)
#else
#define         LN_TO_LOG10             0.2302585093
#endif

#ifdef NON_LINEAR_PSY

static const float non_linear_psy_constant = .3;

#define NON_LINEAR_SCALE_ITEM(x)   pow((x), non_linear_psy_constant)
#define NON_LINEAR_SCALE_SUM(x)    pow((x), 1/non_linear_psy_constant)

#if 0
#define NON_LINEAR_SCALE_ENERGY(x) pow(10, (x)/10)
#else
#define NON_LINEAR_SCALE_ENERGY(x) (x)
#endif

#else

#define NON_LINEAR_SCALE_ITEM(x)   (x)
#define NON_LINEAR_SCALE_SUM(x)    (x)
#define NON_LINEAR_SCALE_ENERGY(x) (x)

#endif


/*
   L3psycho_anal.  Compute psycho acoustics.

   Data returned to the calling program must be delayed by one 
   granule. 

   This is done in two places.  
   If we do not need to know the blocktype, the copying
   can be done here at the top of the program: we copy the data for
   the last granule (computed during the last call) before it is
   overwritten with the new data.  It looks like this:
  
   0. static psymodel_data 
   1. calling_program_data = psymodel_data
   2. compute psymodel_data
    
   For data which needs to know the blocktype, the copying must be
   done at the end of this loop, and the old values must be saved:
   
   0. static psymodel_data_old 
   1. compute psymodel_data
   2. compute possible block type of this granule
   3. compute final block type of previous granule based on #2.
   4. calling_program_data = psymodel_data_old
   5. psymodel_data_old = psymodel_data
*/





/* psycho_loudness_approx
   jd - 2001 mar 12
in:  energy   - BLKSIZE/2 elements of frequency magnitudes ^ 2
     gfp      - uses out_samplerate, ATHtype (also needed for ATHformula)
returns: loudness^2 approximation, a positive value roughly tuned for a value
         of 1.0 for signals near clipping.
notes:   When calibrated, feeding this function binary white noise at sample
         values +32767 or -32768 should return values that approach 3.
         ATHformula is used to approximate an equal loudness curve.
future:  Data indicates that the shape of the equal loudness curve varies
         with intensity.  This function might be improved by using an equal
         loudness curve shaped for typical playback levels (instead of the
         ATH, that is shaped for the threshold).  A flexible realization might
         simply bend the existing ATH curve to achieve the desired shape.
         However, the potential gain may not be enough to justify an effort.
*/
static FLOAT
psycho_loudness_approx( FLOAT *energy, lame_internal_flags *gfc )
{
    int i;
    FLOAT loudness_power;

    loudness_power = 0.0;
    /* apply weights to power in freq. bands*/
    for( i = 0; i < BLKSIZE/2; ++i )
	loudness_power += energy[i] * gfc->ATH->eql_w[i];
    loudness_power *= VO_SCALE;

    return loudness_power;
}

static void
compute_ffts(
    lame_global_flags *gfp,
    FLOAT fftenergy[HBLKSIZE],
    FLOAT (*fftenergy_s)[HBLKSIZE_s],
    FLOAT (*wsamp_l)[BLKSIZE],
    FLOAT (*wsamp_s)[3][BLKSIZE_s],
    int gr_out,
    int chn,
    const sample_t *buffer[2]
    )
{
    int b, j;
    lame_internal_flags *gfc=gfp->internal_flags;
    if (chn<2) {
	fft_long ( gfc, *wsamp_l, chn, buffer);
	fft_short( gfc, *wsamp_s, chn, buffer);
    }
    /* FFT data for mid and side channel is derived from L & R */
    else if (chn == 2) {
	for (j = BLKSIZE-1; j >=0 ; --j) {
	    FLOAT l = wsamp_l[0][j];
	    FLOAT r = wsamp_l[1][j];
	    wsamp_l[0][j] = (l+r)*(FLOAT)(SQRT2*0.5);
	    wsamp_l[1][j] = (l-r)*(FLOAT)(SQRT2*0.5);
	}
	for (b = 2; b >= 0; --b) {
	    for (j = BLKSIZE_s-1; j >= 0 ; --j) {
		FLOAT l = wsamp_s[0][b][j];
		FLOAT r = wsamp_s[1][b][j];
		wsamp_s[0][b][j] = (l+r)*(FLOAT)(SQRT2*0.5);
		wsamp_s[1][b][j] = (l-r)*(FLOAT)(SQRT2*0.5);
	    }
	}
    }
	
    /*********************************************************************
     *  compute energies
     *********************************************************************/
    fftenergy[0]  = NON_LINEAR_SCALE_ENERGY(wsamp_l[0][0]);
    fftenergy[0] *= fftenergy[0];

    for (j=BLKSIZE/2-1; j >= 0; --j) {
	FLOAT re = (*wsamp_l)[BLKSIZE/2-j];
	FLOAT im = (*wsamp_l)[BLKSIZE/2+j];
	fftenergy[BLKSIZE/2-j] = NON_LINEAR_SCALE_ENERGY((re * re + im * im) * 0.5f);
    }
    for (b = 2; b >= 0; --b) {
	fftenergy_s[b][0]  = (*wsamp_s)[b][0];
	fftenergy_s[b][0] *=  fftenergy_s [b][0];
	for (j=BLKSIZE_s/2-1; j >= 0; --j) {
	    FLOAT re = (*wsamp_s)[b][BLKSIZE_s/2-j];
	    FLOAT im = (*wsamp_s)[b][BLKSIZE_s/2+j];
	    fftenergy_s[b][BLKSIZE_s/2-j] = NON_LINEAR_SCALE_ENERGY((re * re + im * im) * 0.5f);
	}
    }
    /* total energy */
    {FLOAT totalenergy=0.0;
    for (j=11;j < HBLKSIZE; j++)
	totalenergy += fftenergy[j];

    gfc->tot_ener[chn] = totalenergy;
    }

#if defined(HAVE_GTK)
    if (gfp->analysis) {
	for (j=0; j<HBLKSIZE ; j++) {
	    gfc->pinfo->energy[gr_out][chn][j]=gfc->energy_save[chn][j];
	    gfc->energy_save[chn][j]=fftenergy[j];
	}
 	gfc->pinfo->pe[gr_out][chn]=gfc->pe[chn];
    }
#endif
    /*********************************************************************
     * compute loudness approximation (used for ATH auto-level adjustment) 
     *********************************************************************/
    if (gfp->athaa_loudapprox == 2 && chn < 2) {/*no loudness for mid/side ch*/
	gfc->loudness_sq[gr_out][chn] = gfc->loudness_sq_save[chn];
	gfc->loudness_sq_save[chn]
	    = psycho_loudness_approx(fftenergy, gfc);
    }
}

/*************************************************************** 
 * compute interchannel masking effects
 ***************************************************************/
static void
calc_interchannel_masking(
    lame_global_flags * gfp,
    FLOAT ratio
    )
{
    lame_internal_flags *gfc=gfp->internal_flags;
    int sb, sblock;
    FLOAT l, r;
    if (gfc->channels_out > 1){
        for ( sb = 0; sb < SBMAX_l; sb++ ) {
	        l = gfc->thm[0].l[sb];
	        r = gfc->thm[1].l[sb];
	        gfc->thm[0].l[sb] += r*ratio;
	        gfc->thm[1].l[sb] += l*ratio;
        }
        for ( sb = 0; sb < SBMAX_s; sb++ ) {
	        for ( sblock = 0; sblock < 3; sblock++ ) {
	            l = gfc->thm[0].s[sb][sblock];
	            r = gfc->thm[1].s[sb][sblock];
	            gfc->thm[0].s[sb][sblock] += r*ratio;
	            gfc->thm[1].s[sb][sblock] += l*ratio;
	        }
        }
    }
}



/*************************************************************** 
 * compute M/S thresholds from Johnston & Ferreira 1992 ICASSP paper
 ***************************************************************/
static void
msfix1(
    lame_internal_flags *gfc
    )
{
    int sb, sblock;
    FLOAT rside,rmid,mld;
    for ( sb = 0; sb < SBMAX_l; sb++ ) {
	/* use this fix if L & R masking differs by 2db or less */
	/* if db = 10*log10(x2/x1) < 2 */
	/* if (x2 < 1.58*x1) { */
	if (gfc->thm[0].l[sb] > 1.58*gfc->thm[1].l[sb]
	 || gfc->thm[1].l[sb] > 1.58*gfc->thm[0].l[sb])
	    continue;

	mld = gfc->mld_l[sb]*gfc->en[3].l[sb];
	rmid = Max(gfc->thm[2].l[sb], Min(gfc->thm[3].l[sb],mld));

	mld = gfc->mld_l[sb]*gfc->en[2].l[sb];
	rside = Max(gfc->thm[3].l[sb], Min(gfc->thm[2].l[sb],mld));
	gfc->thm[2].l[sb]=rmid;
	gfc->thm[3].l[sb]=rside;
    }

    for ( sb = 0; sb < SBMAX_s; sb++ ) {
	for ( sblock = 0; sblock < 3; sblock++ ) {
	    if (gfc->thm[0].s[sb][sblock] > 1.58*gfc->thm[1].s[sb][sblock]
	     || gfc->thm[1].s[sb][sblock] > 1.58*gfc->thm[0].s[sb][sblock])
		continue;

	    mld = gfc->mld_s[sb]*gfc->en[3].s[sb][sblock];
	    rmid = Max(gfc->thm[2].s[sb][sblock],
		       Min(gfc->thm[3].s[sb][sblock],mld));

	    mld = gfc->mld_s[sb]*gfc->en[2].s[sb][sblock];
	    rside = Max(gfc->thm[3].s[sb][sblock],
			Min(gfc->thm[2].s[sb][sblock],mld));

	    gfc->thm[2].s[sb][sblock]=rmid;
	    gfc->thm[3].s[sb][sblock]=rside;
	}
    }
}

/*************************************************************** 
 * Adjust M/S maskings if user set "msfix"
 ***************************************************************/
/* Naoki Shibata 2000 */
static void
ns_msfix(
    lame_internal_flags *gfc,
    FLOAT msfix,
    FLOAT athadjust
    )
{
    int sb, sblock;
    FLOAT msfix2 = msfix;
    FLOAT athlower = pow(10, athadjust);

    msfix *= 2.0;
    msfix2 *= 2.0;
    for ( sb = 0; sb < SBMAX_l; sb++ ) {
	FLOAT thmLR,thmM,thmS,ath;
	ath  = (gfc->ATH->cb[gfc->bm_l[sb]])*athlower;
	thmLR = Min(Max(gfc->thm[0].l[sb],ath), Max(gfc->thm[1].l[sb],ath));
	thmM = Max(gfc->thm[2].l[sb],ath);
	thmS = Max(gfc->thm[3].l[sb],ath);

	if (thmLR*msfix < thmM+thmS) {
	    FLOAT f = thmLR * msfix2 / (thmM+thmS);
	    thmM *= f;
	    thmS *= f;
	}
	gfc->thm[2].l[sb] = Min(thmM,gfc->thm[2].l[sb]);
	gfc->thm[3].l[sb] = Min(thmS,gfc->thm[3].l[sb]);
    }

    athlower *= ((FLOAT)BLKSIZE_s / BLKSIZE);
    for ( sb = 0; sb < SBMAX_s; sb++ ) {
	for ( sblock = 0; sblock < 3; sblock++ ) {
	    FLOAT thmLR,thmM,thmS,ath;
	    ath  = (gfc->ATH->cb[gfc->bm_s[sb]])*athlower;
	    thmLR = Min(Max(gfc->thm[0].s[sb][sblock],ath),
			Max(gfc->thm[1].s[sb][sblock],ath));
	    thmM = Max(gfc->thm[2].s[sb][sblock],ath);
	    thmS = Max(gfc->thm[3].s[sb][sblock],ath);

	    if (thmLR*msfix < thmM+thmS) {
		FLOAT f = thmLR*msfix / (thmM+thmS);
		thmM *= f;
		thmS *= f;
	    }
	    gfc->thm[2].s[sb][sblock] = Min(gfc->thm[2].s[sb][sblock],thmM);
	    gfc->thm[3].s[sb][sblock] = Min(gfc->thm[3].s[sb][sblock],thmS);
	}
    }
}

/* longblock threshold calculation (part 2) */
static void convert_partition2scalefac_l(
    lame_internal_flags *gfc,
    FLOAT *eb,
    FLOAT *thr,
    int chn
    )
{
    FLOAT enn, thmm;
    int sb, b;
    enn = thmm = 0.0;
    sb = b = 0;
    for (;;) {
	while (b < gfc->bo_l[sb]) {
	    enn  += eb[b];
	    thmm += thr[b];
	    b++;
	}

	if (sb == SBMAX_l - 1)
	    break;

    assert( enn >= 0 );
    assert( thmm >= 0 );
	gfc->en [chn].l[sb] = enn  + 0.5 * eb [b];
	gfc->thm[chn].l[sb] = thmm + 0.5 * thr[b];

	enn  = 0.5 *  eb[b];
	thmm = 0.5 * thr[b];
    assert( enn >= 0 );
    assert( thmm >= 0 );
	b++;
	sb++;
    }

    gfc->en [chn].l[SBMAX_l-1] = enn;
    gfc->thm[chn].l[SBMAX_l-1] = thmm;
}

static void
compute_masking_s(
    lame_internal_flags *gfc,
    FLOAT (*fftenergy_s)[HBLKSIZE_s],
    FLOAT *eb,
    FLOAT *thr,
    int chn,
    int sblock,
    FLOAT athlower
    )
{
    int j, b;
    athlower *= ((FLOAT)BLKSIZE_s / BLKSIZE);
    for (j = b = 0; b < gfc->npart_s; b++) {
	FLOAT ecb = fftenergy_s[sblock][j++];
	int kk = gfc->numlines_s[b];
	while (--kk > 0)
	    ecb += fftenergy_s[sblock][j++];
	eb[b] = ecb;
    }
    for (j = b = 0; b < gfc->npart_s; b++) {
	int kk = gfc->s3ind_s[b][0];
	FLOAT ecb = gfc->s3_ss[j++] * eb[kk++];
	while (kk <= gfc->s3ind_s[b][1])
	    ecb += gfc->s3_ss[j++] * eb[kk++];

	thr[b] = Min( ecb, rpelev_s  * gfc->nb_s1[chn][b] );
	if (gfc->blocktype_old[chn & 1] == SHORT_TYPE ) {
	    thr[b] = Min(thr[b], rpelev2_s * gfc->nb_s2[chn][b]);
	}
	thr[b] = Max( thr[b],
                  Min(gfc->ATH->cb[gfc->bm_s[b]] * athlower,
                      thr[b] * 2) );
	gfc->nb_s2[chn][b] = gfc->nb_s1[chn][b];
	gfc->nb_s1[chn][b] = ecb;
    assert( thr[b] >= 0 );
    }
}

static void
block_type_set(
    lame_global_flags * gfp,
    int *uselongblock,
    int *blocktype_d,
    int *blocktype
    )
{
    lame_internal_flags *gfc=gfp->internal_flags;
    int chn;

    if (gfp->short_blocks == short_block_coupled
	/* force both channels to use the same block type */
	/* this is necessary if the frame is to be encoded in ms_stereo.  */
	/* But even without ms_stereo, FhG  does this */
	&& !(uselongblock[0] && uselongblock[1]))
        uselongblock[0] = uselongblock[1] = 0;

    /* update the blocktype of the previous granule, since it depends on what
     * happend in this granule */
    for (chn=0; chn<gfc->channels_out; chn++) {
	blocktype[chn] = NORM_TYPE;
	/* disable short blocks */
	if (gfp->short_blocks == short_block_dispensed)
	    uselongblock[chn]=1;
	if (gfp->short_blocks == short_block_forced)
	    uselongblock[chn]=0;

	if (uselongblock[chn]) {
	    /* no attack : use long blocks */
	    assert( gfc->blocktype_old[chn] != START_TYPE );
	    if (gfc->blocktype_old[chn] == SHORT_TYPE)
		blocktype[chn] = STOP_TYPE;
	} else {
	    /* attack : use short blocks */
	    blocktype[chn] = SHORT_TYPE;
	    if (gfc->blocktype_old[chn] == NORM_TYPE) {
		gfc->blocktype_old[chn] = START_TYPE;
	    }
	    if (gfc->blocktype_old[chn] == STOP_TYPE)
		gfc->blocktype_old[chn] = SHORT_TYPE;
	}

	blocktype_d[chn] = gfc->blocktype_old[chn];  /* value returned to calling program */
	gfc->blocktype_old[chn] = blocktype[chn];    /* save for next call to l3psy_anal */
    }
}

static void 
determine_block_type( lame_global_flags * gfp, FLOAT fftenergy_s[3][HBLKSIZE_s], int uselongblock[],
    int chn, int gr_out, FLOAT* pe )
{
    lame_internal_flags* gfc = gfp->internal_flags;
    int j;
	/*************************************************************** 
	 * determine the block type (window type) based on L & R channels
	 ***************************************************************/
	/* compute PE for all 4 channels */
	    FLOAT mn,mx,ma=0,mb=0,mc=0;
            for ( j = HBLKSIZE_s/2; j < HBLKSIZE_s; j ++) {
		ma += fftenergy_s[0][j];
		mb += fftenergy_s[1][j];
		mc += fftenergy_s[2][j];
	    }
	    mn = Min(ma,mb);
	    mn = Min(mn,mc);
	    mx = Max(ma,mb);
	    mx = Max(mx,mc);
#if defined(HAVE_GTK)
	    if (gfp->analysis) {
		gfc->pinfo->ers[gr_out][chn]=gfc->ers_save[chn];
		gfc->ers_save[chn]=(mx/(1e-12+mn));
	    }
#endif
	    /* bit allocation is based on pe.  */
	    if (mx>mn) {
		FLOAT tmp = FAST_LOG_X(mx/(1e-12+mn), 400.0);
		if (tmp > *pe) *pe = tmp;
	    }

	    /* block type is based just on L or R channel */      
	    if (chn<2) {
		uselongblock[chn] = 1;

		/* tuned for t1.wav.  doesnt effect most other samples */
		if (*pe > 3000) 
		    uselongblock[chn]=0;
	
		if ( mx > 30*mn ) 
		{/* big surge of energy - always use short blocks */
		    uselongblock[chn] = 0;
		}
		else if ((mx > 10*mn) && (*pe > 1000))
		{/* medium surge, medium pe - use short blocks */
		    uselongblock[chn] = 0;
		}
	    }
}

int L3psycho_anal( lame_global_flags * gfp,
                    const sample_t *buffer[2], int gr_out, 
                    FLOAT *ms_ratio,
                    FLOAT *ms_ratio_next,
		    III_psy_ratio masking_ratio[2][2],
		    III_psy_ratio masking_MS_ratio[2][2],
		    FLOAT percep_entropy[2],FLOAT percep_MS_entropy[2], 
                    FLOAT energy[4],
                    int blocktype_d[2])
{
    lame_internal_flags *gfc=gfp->internal_flags;

    /* fft and energy calculation   */
    FLOAT wsamp_L[2][BLKSIZE];
    FLOAT wsamp_S[2][3][BLKSIZE_s];
    FLOAT fftenergy[HBLKSIZE];
    FLOAT fftenergy_s[3][HBLKSIZE_s];

    /* convolution   */
    FLOAT eb[CBANDS+1];
    FLOAT cb[CBANDS];
    FLOAT thr[CBANDS+1];

    /* ratios    */
    FLOAT ms_ratio_l=0, ms_ratio_s=0;

    /* block type  */
    int blocktype[2],uselongblock[2];

    /* usual variables like loop indices, etc..    */
    int numchn, chn;
    int b, i, j, k;
    int sb,sblock;

    /*  rh 20040301: the following loops do access one off the limits
     *  so I increase  the array dimensions by one and initialize the
     *  accessed values to zero
     */
    assert( gfc->npart_s <= CBANDS );
    assert( gfc->npart_l <= CBANDS );
    eb [gfc->npart_s] = 0;
    thr[gfc->npart_s] = 0;
    eb [gfc->npart_l] = 0;
    thr[gfc->npart_l] = 0;

    numchn = gfc->channels_out;
    /* chn=2 and 3 = Mid and Side channels */
    if (gfp->mode == JOINT_STEREO) numchn=4;

    for (chn=0; chn<numchn; chn++) {
	FLOAT (*wsamp_l)[BLKSIZE];
	FLOAT (*wsamp_s)[3][BLKSIZE_s];
	energy[chn] = gfc->tot_ener[chn];

	/* there is a one granule delay.  Copy maskings computed last call
	 * into masking_ratio to return to calling program.
	 */
	if (chn < 2) {
	    /* LR maskings  */
	    percep_entropy            [chn]       = gfc -> pe  [chn];
	    masking_ratio    [gr_out] [chn]  .en  = gfc -> en  [chn];
	    masking_ratio    [gr_out] [chn]  .thm = gfc -> thm [chn];
	} else {
	    /* MS maskings  */
	    percep_MS_entropy         [chn-2]     = gfc -> pe  [chn]; 
	    masking_MS_ratio [gr_out] [chn-2].en  = gfc -> en  [chn];
	    masking_MS_ratio [gr_out] [chn-2].thm = gfc -> thm [chn];
	}

	/*********************************************************************
	 *  compute FFTs
	 *********************************************************************/
	wsamp_s = wsamp_S+(chn & 1);
	wsamp_l = wsamp_L+(chn & 1);
	compute_ffts(gfp, fftenergy, fftenergy_s,
		     wsamp_l, wsamp_s, gr_out, chn, buffer);

	/*********************************************************************
	 *    compute unpredicatability of first six spectral lines
	 *********************************************************************/
	for ( j = 0; j < CW_LOWER_INDEX; j++ ) {
	    /* calculate unpredictability measure cw */
	    FLOAT a2, b2, r1, r2;
	    FLOAT numre, numim, den;

	    a2 = gfc-> ax_sav[chn][1][j];
	    b2 = gfc-> bx_sav[chn][1][j];

	    r2 = gfc-> rx_sav[chn][1][j];
	    r1 = gfc-> rx_sav[chn][1][j] = gfc-> rx_sav[chn][0][j];

	    /* square (x1,y1) */
	    if (r1 != 0.0) {
		FLOAT a1 = gfc-> ax_sav[chn][1][j] = gfc-> ax_sav[chn][0][j];
		FLOAT b1 = gfc-> bx_sav[chn][1][j] = gfc-> bx_sav[chn][0][j];
		den = r1*r1;
		numre = a1*b1;
		numim = den-b1*b1;
	    } else {
		/* no aging is needed for ax_sav[chn][0][j] and that of bx
		   because if r1=0, r2 should be 0 for next time. */
		den = numre = 1.0;
		numim = 0.0;
	    }

	    /* multiply by (x2,-y2) */
	    if (r2 != 0.0) {
		FLOAT tmp2 = (numim+numre)*(a2+b2)*0.5f;
		FLOAT tmp1 = -a2*numre+tmp2;
		numre =      -b2*numim+tmp2;
		numim = tmp1;
		den *= r2;
	    }

	    r1 = 2.0f*r1-r2;
	    r2 = gfc-> rx_sav[chn][0][j] = sqrt(fftenergy[j]);
	    r2 = r2+fabs(r1);
	    if (r2 != 0) {
		FLOAT an = gfc-> ax_sav[chn][0][j] = wsamp_l[0][j];
		FLOAT bn = gfc-> bx_sav[chn][0][j] = j==0 ? wsamp_l[0][0] : wsamp_l[0][BLKSIZE-j];  
		den = r1/den*2.0;
		numre = (an+bn)-numre*den;
		numim = (an-bn)-numim*den;
		r2 = sqrt(numre*numre+numim*numim)/(r2*2.0);
	    }
	    gfc->cw[j] = r2;
	}

	/**********************************************************************
	 *     compute unpredicatibility of next 200 spectral lines
	 *********************************************************************/
	for (; j < gfc->cw_upper_index; j += 4 ) {
	    /* calculate unpredictability measure cw */
	    FLOAT rn, r1, r2;
	    FLOAT numre, numim, den;
	    k = (j+2) / 4;
	    /* square (x1,y1) */
	    r1 = fftenergy_s[0][k];
	    if (r1 != 0.0) {
		FLOAT a1 = (*wsamp_s)[0][k]; 
		FLOAT b1 = (*wsamp_s)[0][BLKSIZE_s-k]; /* k is never 0 */
		numre = a1*b1;
		numim = r1-b1*b1;
		den = r1;
		r1 = sqrt(r1);
	    } else {
		den = numre = 1.0;
		numim = 0.0;
	    }

	    /* multiply by (x2,-y2) */
	    r2 = fftenergy_s[2][k];
	    if (r2 != 0.0) {
		FLOAT a2 = (*wsamp_s)[2][k]; 
		FLOAT b2 = (*wsamp_s)[2][BLKSIZE_s-k];

		FLOAT tmp2 = (numim+numre)*(a2+b2)*0.5f;
		FLOAT tmp1 = tmp2-a2*numre;
		numre =      tmp2-b2*numim;
		numim = tmp1;

		r2 = sqrt(r2);
		den *= r2;
	    }

	    /* r-prime factor */
	    rn = sqrt(fftenergy_s[1][k])+fabs(2*r1-r2);
	    if (rn != 0) {
		FLOAT an = (*wsamp_s)[1][k]; 
		FLOAT bn = (*wsamp_s)[1][BLKSIZE_s-k];
		den = (2*r1-r2)/den*2.0f;
		numre = (an+bn)-numre*den;
		numim = (an-bn)-numim*den;
		rn = sqrt(numre*numre+numim*numim)/(rn*2.0f);
	    }
	    gfc->cw[j+1] = gfc->cw[j+2] = gfc->cw[j+3] = gfc->cw[j] = rn;
	}

	/**********************************************************************
	 *    Calculate the energy and the unpredictability in the threshold
	 *    calculation partitions
	 *********************************************************************/
	b = 0;
	for (j = 0; j < gfc->cw_upper_index
		 && gfc->numlines_l[b] && b < gfc->npart_l; ) {
	    FLOAT ebb, cbb;

	    ebb = NON_LINEAR_SCALE_ITEM(fftenergy[j]);
	    cbb = NON_LINEAR_SCALE_ITEM(fftenergy[j] * gfc->cw[j]);
	    j++;

	    for (i = gfc->numlines_l[b] - 1; i > 0; i--) {
		ebb += NON_LINEAR_SCALE_ITEM(fftenergy[j]);
		/* XXX: should "* gfc->cw[j])" be outside of the scaling? */
		cbb += NON_LINEAR_SCALE_ITEM(fftenergy[j] * gfc->cw[j]);
		j++;
	    }
	    eb[b] = NON_LINEAR_SCALE_SUM(ebb);
	    cb[b] = NON_LINEAR_SCALE_SUM(cbb);
	    b++;
	}

	for (; b < gfc->npart_l; b++ ) {
	    FLOAT ebb = NON_LINEAR_SCALE_ITEM(fftenergy[j++]);
	    assert(gfc->numlines_l[b]);
	    for (i = gfc->numlines_l[b] - 1; i > 0; i--) {
		ebb += NON_LINEAR_SCALE_ITEM(fftenergy[j++]);
	    }
	    eb[b] = NON_LINEAR_SCALE_SUM(ebb);
	    /* XXX: should the "* .4" be outside of the scaling? */
	    cb[b] = NON_LINEAR_SCALE_SUM(ebb * 0.4);
	}

	/**********************************************************************
	 *      convolve the partitioned energy and unpredictability
	 *      with the spreading function, s3_l[b][k](packed into s3_ll)
	 *********************************************************************/
	/*  calculate percetual entropy */
	gfc->pe[chn] = 0;
	k = 0;
	for ( b = 0;b < gfc->npart_l; b++ ) {
	    FLOAT tbb,ecb,ctb;
	    int kk;
	    ecb = ctb = 0.;
	    for (kk = gfc->s3ind[b][0]; kk <= gfc->s3ind[b][1]; kk++ ) {
		/* sprdngf for Layer III */
		ecb += gfc->s3_ll[k] * eb[kk];
		ctb += gfc->s3_ll[k] * cb[kk];
		k++;
	    }

/* calculate the tonality of each threshold calculation partition 
 * calculate the SNR in each threshold calculation partition 
 * tonality = -0.299 - .43*log(ctb/ecb);
 * tonality = 0:           use NMT   (lots of masking)
 * tonality = 1:           use TMN   (little masking)
 */
	    tbb = ecb;
	    if (tbb != 0.0) {
		tbb = ctb / tbb;
		/* convert to tonality index */
		/* tonality small:   tbb=1 */
		/* tonality large:   tbb=-.299 */
		tbb = CONV1 + FAST_LOG_X(tbb, CONV2);
		if (tbb < 0.0) tbb = exp(-LN_TO_LOG10*NMT);
		else if (tbb > 1.0) tbb = exp(-LN_TO_LOG10*TMN);
		else tbb = exp(-LN_TO_LOG10 * ( (TMN-NMT)*tbb + NMT ));
	    }

/* at this point, tbb represents the amount the spreading function
 * will be reduced.  The smaller the value, the less masking.
 * minval[] = 1 (0db)     says just use tbb.
 * minval[]= .01 (-20db)  says reduce spreading function by at least 20db.
 */
	    tbb = Min(gfc->minval[b], tbb);
	    /* stabilize tonality estimation */
	    if (gfc->PSY->tonalityPatch && b > 5) {
		FLOAT const x = 1.8699422;
		FLOAT w = gfc->PSY->prvTonRed[b/2] * x;
		if (tbb > w) 
		    tbb = w;
		gfc->PSY->prvTonRed[b] = tbb;
	    }
	    ecb *= tbb;

	    /* long block pre-echo control.   */
	    /* rpelev=2.0, rpelev2=16.0 */
	    /* note: all surges in PE are because of this pre-echo formula
	     * for thr[b].  If it this is not used, PE is always around 600
	     */
	    /* dont use long block pre-echo control if previous granule was
	     * a short block.  This is to avoid the situation:   
	     * frame0:  quiet (very low masking)  
	     * frame1:  surge  (triggers short blocks)
	     * frame2:  regular frame. looks like pre-echo when compared to
	     *          frame0, but all pre-echo was in frame1.
	     */
	    /* chn=0,1   L and R channels
	       chn=2,3   S and M channels.  
	    */
	    thr[b] = Min(ecb, rpelev*gfc->nb_1[chn][b]);
	    if (gfc->blocktype_old[chn & 1] != SHORT_TYPE
		&& thr[b] > rpelev2*gfc->nb_2[chn][b])
		thr[b] = rpelev2*gfc->nb_2[chn][b];

	    gfc->nb_2[chn][b] = gfc->nb_1[chn][b];
	    gfc->nb_1[chn][b] = ecb;

	    ecb = Max(thr[b], gfc->ATH->cb[b]*gfc->ATH->adjust);
	    if (ecb < eb[b])
		gfc->pe[chn] -= gfc->numlines_l[b] * FAST_LOG(ecb / eb[b]);
	}

    determine_block_type( gfp, fftenergy_s, uselongblock, chn, gr_out, &gfc->pe[chn] );

	/* compute masking thresholds for long blocks */
	convert_partition2scalefac_l(gfc, eb, thr, chn);

	/* compute masking thresholds for short blocks */
	for (sblock = 0; sblock < 3; sblock++) {
	    FLOAT enn, thmm;
	    compute_masking_s(gfc, fftenergy_s, eb, thr, chn,
			      sblock,gfp->ATHlower*gfc->ATH->adjust);
	    b = -1;
	    enn = thmm = 0.0;
	    for (sb = 0; sb < SBMAX_s; sb++) {
		while (++b < gfc->bo_s[sb]) {
		    enn  += eb[b];
		    thmm += thr[b];
		}
		enn  += 0.5 * eb[b];    /* for the last sfb b is larger than npart_s!! */
		thmm += 0.5 * thr[b];   /* rh 20040301 */
        assert( enn >= 0 );
        assert( thmm >= 0 );
		gfc->en [chn].s[sb][sblock] = enn;
		gfc->thm[chn].s[sb][sblock] = thmm;
		enn  = 0.5 * eb[b];
		thmm = 0.5 * thr[b];
        assert( enn >= 0 );
        assert( thmm >= 0 );
	    }
	    gfc->en [chn].s[sb-1][sblock] += enn;
	    gfc->thm[chn].s[sb-1][sblock] += thmm;
	}
    } /* end loop over chn */

    if (gfp->interChRatio != 0.0)
	calc_interchannel_masking(gfp, gfp->interChRatio);

    if (gfp->mode == JOINT_STEREO) {
	FLOAT db,x1,x2,sidetot=0,tot=0;
	msfix1(gfc);
	if (gfp->msfix != 0.0)
	    ns_msfix(gfc, gfp->msfix, gfp->ATHlower*gfc->ATH->adjust);

	/* determin ms_ratio from masking thresholds*/
	/* use ms_stereo (ms_ratio < .35) if average thresh. diff < 5 db */
	for (sb= SBMAX_l/4 ; sb< SBMAX_l; sb ++ ) {
	    x1 = Min(gfc->thm[0].l[sb],gfc->thm[1].l[sb]);
	    x2 = Max(gfc->thm[0].l[sb],gfc->thm[1].l[sb]);
	    /* thresholds difference in db */
	    if (x2 >= 1000*x1)  db=3;
	    else db = FAST_LOG10(x2/x1);  
	    /*  DEBUGF(gfc,"db = %f %e %e  \n",db,gfc->thm[0].l[sb],gfc->thm[1].l[sb]);*/
	    sidetot += db;
	    tot++;
	}
	ms_ratio_l= (sidetot/tot)*0.7; /* was .35*(sidetot/tot)/5.0*10 */
	ms_ratio_l = Min(ms_ratio_l,0.5);

	sidetot=0; tot=0;
	for ( sblock = 0; sblock < 3; sblock++ )
	    for ( sb = SBMAX_s/4; sb < SBMAX_s; sb++ ) {
		x1 = Min(gfc->thm[0].s[sb][sblock],gfc->thm[1].s[sb][sblock]);
		x2 = Max(gfc->thm[0].s[sb][sblock],gfc->thm[1].s[sb][sblock]);
		/* thresholds difference in db */
		if (x2 >= 1000*x1)  db=3;
		else db = FAST_LOG10(x2/x1);
		sidetot += db;
		tot++;
	    }
	ms_ratio_s = (sidetot/tot)*0.7; /* was .35*(sidetot/tot)/5.0*10 */
	ms_ratio_s = Min(ms_ratio_s,.5);
    }

    /*************************************************************** 
     * determine final block type
     ***************************************************************/
    block_type_set(gfp, uselongblock, blocktype_d, blocktype);

    if (blocktype_d[0]==SHORT_TYPE && blocktype_d[1]==SHORT_TYPE)
	*ms_ratio = gfc->ms_ratio_s_old;
    else
	*ms_ratio = gfc->ms_ratio_l_old;

    gfc->ms_ratio_s_old = ms_ratio_s;
    gfc->ms_ratio_l_old = ms_ratio_l;

    /* we dont know the block type of this frame yet - assume long */
    *ms_ratio_next = ms_ratio_l;

    return 0;
}



/* mask_add optimization */
/* init the limit values used to avoid computing log in mask_add when it is not necessary */

/* For example, with i = 10*log10(m2/m1)/10*16         (= log10(m2/m1)*16)
 *
 * abs(i)>8 is equivalent (as i is an integer) to
 * abs(i)>=9
 * i>=9 || i<=-9
 * equivalent to (as i is the biggest integer smaller than log10(m2/m1)*16 
 * or the smallest integer bigger than log10(m2/m1)*16 depending on the sign of log10(m2/m1)*16)
 * log10(m2/m1)>=9/16 || log10(m2/m1)<=-9/16
 * exp10 is strictly increasing thus this is equivalent to
 * m2/m1 >= 10^(9/16) || m2/m1<=10^(-9/16) which are comparisons to constants
 */


#define I1LIMIT 8   /* as in if(i>8)  */ 
#define I2LIMIT 23  /* as in if(i>24) -> changed 23 */ 
#define MLIMIT  15  /* as in if(m<15) */ 

static FLOAT ma_max_i1;
static FLOAT ma_max_i2;
static FLOAT ma_max_m;



static void init_mask_add_max_values(void)
{
    ma_max_i1 = pow(10,(I1LIMIT+1)/16.0);
    ma_max_i2 = pow(10,(I2LIMIT+1)/16.0);
    ma_max_m  = pow(10,(MLIMIT)/10.0);
}






/* addition of simultaneous masking   Naoki Shibata 2000/7 */
inline static FLOAT mask_add(FLOAT m1,FLOAT m2,int k,int b, lame_internal_flags * const gfc)
{
  static const FLOAT table1[] = {
    3.3246 *3.3246 ,3.23837*3.23837,3.15437*3.15437,3.00412*3.00412,2.86103*2.86103,2.65407*2.65407,2.46209*2.46209,2.284  *2.284  ,
    2.11879*2.11879,1.96552*1.96552,1.82335*1.82335,1.69146*1.69146,1.56911*1.56911,1.46658*1.46658,1.37074*1.37074,1.31036*1.31036,
    1.25264*1.25264,1.20648*1.20648,1.16203*1.16203,1.12765*1.12765,1.09428*1.09428,1.0659 *1.0659 ,1.03826*1.03826,1.01895*1.01895,
    1
  };

  static const FLOAT table2[] = {
    1.33352*1.33352,1.35879*1.35879,1.38454*1.38454,1.39497*1.39497,1.40548*1.40548,1.3537 *1.3537 ,1.30382*1.30382,1.22321*1.22321,
    1.14758*1.14758,
    1
  };

  static const FLOAT table3[] = {
    2.35364*2.35364,2.29259*2.29259,2.23313*2.23313,2.12675*2.12675,2.02545*2.02545,1.87894*1.87894,1.74303*1.74303,1.61695*1.61695,
    1.49999*1.49999,1.39148*1.39148,1.29083*1.29083,1.19746*1.19746,1.11084*1.11084,1.03826*1.03826
  };


  int i;
  FLOAT ratio;


  if (m2 > m1) {
      if (m2 < (m1*ma_max_i2))
        ratio = m2/m1;
      else
        return (m1+m2);
  } else {
      if (m1 >= (m2*ma_max_i2))
          return (m1+m2);
      ratio = m1/m2;
  }
  /*i = abs(10*log10(m2 / m1)/10*16);
  m = 10*log10((m1+m2)/gfc->ATH->cb[k]);*/


  /* Should always be true, just checking */
  assert(m1>=0);
  assert(m2>=0);
  assert(gfc->ATH->cb[k]>=0);


  m1 += m2;

  if ((unsigned int)(b+3) <= 3+3) {  /* approximately, 1 bark = 3 partitions */
      /* 65% of the cases */
      /* originally 'if(i > 8)' */
      if (ratio >= ma_max_i1) {
	  /* 43% of the total */
	  return m1;
      }

      /* 22% of the total */
      i = FAST_LOG10_X(ratio,16.0);
      return m1*table2[i];
  }

  /* m<15 equ log10((m1+m2)/gfc->ATH->cb[k])<1.5
   * equ (m1+m2)/gfc->ATH->cb[k]<10^1.5
   * equ (m1+m2)<10^1.5 * gfc->ATH->cb[k]
   */

  i = FAST_LOG10_X(ratio, 16.0);
  m2 = gfc->ATH->cb[k]*gfc->ATH->adjust;
  if (m1 < ma_max_m*m2)  {
      /* 3% of the total */
      /* Originally if (m > 0) { */
      if (m1 > m2) {
	  FLOAT f, r;

	  f = 1.0;
	  if (i <= 13) f = table3[i];

	  r = FAST_LOG10_X(m1 / m2, 10.0/15.0);
	  return m1 * ((table1[i]-f)*r+f);
      }

      if (i > 13) return m1;

      return m1*table3[i];
  }


  /* 10% of total */
  return m1*table1[i];
}



static inline FLOAT NS_INTERP(FLOAT x, FLOAT y, FLOAT r)
{
    /* was pow((x),(r))*pow((y),1-(r))*/
    if(r==1.0)
        return x;              /* 99.7% of the time */
    if(r==0.0)
	return y;
    if(y>0.0)
        return pow(x/y,r)*y;   /* rest of the time */ 
    return 0.0;                /* never happens */ 
}



static void nsPsy2dataRead(
    FILE *fp,
    FLOAT *eb2,
    FLOAT *eb,
    int chn,
    int npart_l
    )
{
    int b;
    for(;;) {
	static const char chname[] = {'L','R','M','S'};
	char c;

	fscanf(fp, "%c",&c);
	for (b=0; b < npart_l; b++) {
	    double e;
	    fscanf(fp, "%lf",&e);
	    eb2[b] = e;
	}

	if (feof(fp)) abort();
	if (c == chname[chn]) break;
	abort();
    }

    eb2[62] = eb2[61];
    for (b=0; b < npart_l; b++ )
	eb2[b] = eb2[b] * eb[b];
}

static FLOAT
pecalc_s(
    III_psy_ratio *mr,
    FLOAT masking_lower
    )
{
    FLOAT pe_s;
    const static FLOAT regcoef_s[] = {
	11.8, /* these values are tuned only for 44.1kHz... */
	13.6,
	17.2,
	32,
	46.5,
	51.3,
	57.5,
	67.1,
	71.5,
	84.6,
	97.6,
	130,
/*	255.8 */
    };
    int sb, sblock;

    pe_s = 1236.28/4;
    for (sb = 0; sb < SBMAX_s - 1; sb++) {
	for (sblock=0;sblock<3;sblock++) {
	    FLOAT x;
	    if (regcoef_s[sb] == 0.0
		|| mr->thm.s[sb][sblock] <= 0.0
		|| mr->en.s[sb][sblock]
		<= (x = mr->thm.s[sb][sblock] * masking_lower))
		continue;

	    if (mr->en.s[sb][sblock] > x*1e10)
		pe_s += regcoef_s[sb] * (10.0 * LOG10);
	    else
		pe_s += regcoef_s[sb] * FAST_LOG10(mr->en.s[sb][sblock] / x);
	}
    }

    return pe_s;
}

static FLOAT
pecalc_l(
    III_psy_ratio *mr,
    FLOAT masking_lower
    )
{
    FLOAT pe_l;
    const static FLOAT regcoef_l[] = {
	6.8, /* these values are tuned only for 44.1kHz... */
	5.8,
	5.8,
	6.4,
	6.5,
	9.9,
	12.1,
	14.4,
	15,
	18.9,
	21.6,
	26.9,
	34.2,
	40.2,
	46.8,
	56.5,
	60.7,
	73.9,
	85.7,
	93.4,
	126.1,
/*	241.3 */
    };
    int sb;

    pe_l = 1124.23/4;
    for (sb = 0; sb < SBMAX_l - 1; sb++) {
	FLOAT x;
	if (mr->thm.l[sb] <= 0.0
	    || mr->en.l[sb] <= (x = mr->thm.l[sb]*masking_lower))
	    continue;

	if (mr->en.l[sb] > x*1e10)
	    pe_l += regcoef_l[sb] * (10.0 * LOG10);
	else
	    pe_l += regcoef_l[sb] * FAST_LOG10(mr->en.l[sb] / x);
    }

    return pe_l;
}





int L3psycho_anal_ns( lame_global_flags * gfp,
                    const sample_t *buffer[2], int gr_out, 
                    FLOAT *ms_ratio,
                    FLOAT *ms_ratio_next,
		    III_psy_ratio masking_ratio[2][2],
		    III_psy_ratio masking_MS_ratio[2][2],
		    FLOAT percep_entropy[2],FLOAT percep_MS_entropy[2], 
		    FLOAT energy[4], 
                    int blocktype_d[2])
{
/* to get a good cache performance, one has to think about
 * the sequence, in which the variables are used.  
 * (Note: these static variables have been moved to the gfc-> struct,
 * and their order in memory is layed out in util.h)
 */
    lame_internal_flags *gfc=gfp->internal_flags;

    /* fft and energy calculation   */
    FLOAT wsamp_L[2][BLKSIZE];
    FLOAT wsamp_S[2][3][BLKSIZE_s];

    /* block type  */
    int blocktype[2],uselongblock[2];

    /* usual variables like loop indices, etc..    */
    int numchn, chn;
    int b, i, j, k;
    int	sb,sblock;

    /* variables used for --nspsytune */
    FLOAT ns_hpfsmpl[2][576];
    FLOAT pcfact;

    numchn = gfc->channels_out;
    /* chn=2 and 3 = Mid and Side channels */
    if (gfp->mode == JOINT_STEREO) numchn=4;

    if (gfp->VBR==vbr_off) pcfact = gfc->ResvMax == 0 ? 0 : ((FLOAT)gfc->ResvSize)/gfc->ResvMax*0.5;
    else if (gfp->VBR == vbr_rh  ||  gfp->VBR == vbr_mtrh  ||  gfp->VBR == vbr_mt) {
	    /*static const FLOAT pcQns[10]={1.0,1.0,1.0,0.8,0.6,0.5,0.4,0.3,0.2,0.1};
	    pcfact = pcQns[gfp->VBR_q];*/
	    pcfact = 0.6;
    } else pcfact = 1.0;

    /**********************************************************************
     *  Apply HPF of fs/4 to the input signal.
     *  This is used for attack detection / handling.
     **********************************************************************/
    /* Don't copy the input buffer into a temporary buffer */
    /* unroll the loop 2 times */
    for(chn=0;chn<gfc->channels_out;chn++) {
	static const FLOAT fircoef[] = {
	    -8.65163e-18*2, -0.00851586*2, -6.74764e-18*2, 0.0209036*2,
	    -3.36639e-17*2, -0.0438162 *2, -1.54175e-17*2, 0.0931738*2,
	    -5.52212e-17*2, -0.313819  *2
	};

	/* apply high pass filter of fs/4 */
	const sample_t * const firbuf = &buffer[chn][576-350-NSFIRLEN+192];
	for (i=0;i<576;i++) {
	    FLOAT sum1, sum2;
	    sum1 = firbuf[i + 10];
	    sum2 = 0.0;
	    for (j=0;j<(NSFIRLEN-1)/2;j+=2) {
		sum1 += fircoef[j  ] * (firbuf[i+j  ]+firbuf[i+NSFIRLEN-j  ]);
		sum2 += fircoef[j+1] * (firbuf[i+j+1]+firbuf[i+NSFIRLEN-j-1]);
	    }
	    ns_hpfsmpl[chn][i] = sum1 + sum2;
	}
	masking_ratio    [gr_out] [chn]  .en  = gfc -> en  [chn];
	masking_ratio    [gr_out] [chn]  .thm = gfc -> thm [chn];
	if (numchn > 2) {
	    /* MS maskings  */
	    /*percep_MS_entropy         [chn-2]     = gfc -> pe  [chn];  */
	    masking_MS_ratio [gr_out] [chn].en  = gfc -> en  [chn+2];
	    masking_MS_ratio [gr_out] [chn].thm = gfc -> thm [chn+2];
	}
    }

    for (chn=0; chn<numchn; chn++) {
	FLOAT (*wsamp_l)[BLKSIZE];
	FLOAT (*wsamp_s)[3][BLKSIZE_s];
	FLOAT en_subshort[12];
    FLOAT   en_short[4] = { 0 };
	FLOAT attack_intensity[12];
	int ns_uselongblock = 1;
	FLOAT attackThreshold;
	FLOAT max[CBANDS],avg[CBANDS];
	int ns_attacks[4] = {0};
	FLOAT fftenergy[HBLKSIZE];
	FLOAT fftenergy_s[3][HBLKSIZE_s];
	/* convolution   */
	FLOAT eb[CBANDS+1],eb2[CBANDS];
	FLOAT thr[CBANDS+1];


    /*This is the masking table:
      According to tonality, values are going from 0dB (TMN)
      to 9.3dB (NMT).
      After additive masking computation, 8dB are added, so
      final values are going from 8dB to 17.3dB
    */
    static const FLOAT tab[] = {
        1.0/*pow(10, -0)*/,
        0.79433/*pow(10, -0.1)*/,
        0.63096/*pow(10, -0.2)*/,
        0.63096/*pow(10, -0.2)*/,
        0.63096/*pow(10, -0.2)*/,
        0.63096/*pow(10, -0.2)*/,
        0.63096/*pow(10, -0.2)*/,
        0.25119/*pow(10, -0.6)*/,
	    0.11749/*pow(10, -0.93)*/
	};

    /*  rh 20040301: the following loops do access one off the limits
     *  so I increase  the array dimensions by one and initialize the
     *  accessed values to zero
     */
    assert( gfc->npart_s <= CBANDS );
    assert( gfc->npart_l <= CBANDS );
    eb [gfc->npart_s] = 0;
    thr[gfc->npart_s] = 0;
    eb [gfc->npart_l] = 0;
    thr[gfc->npart_l] = 0;
    
	/*************************************************************** 
	 * determine the block type (window type)
	 ***************************************************************/
	/* calculate energies of each sub-shortblocks */
	for (i=0; i<3; i++) {
	    en_subshort[i] = gfc->nsPsy.last_en_subshort[chn][i+6];
	    attack_intensity[i]
		= en_subshort[i] / gfc->nsPsy.last_en_subshort[chn][i+4];
        en_short[0] += en_subshort[i];
	}

	if (chn == 2) {
	    for(i=0;i<576;i++) {
		FLOAT l, r;
		l = ns_hpfsmpl[0][i];
		r = ns_hpfsmpl[1][i];
		ns_hpfsmpl[0][i] = l+r;
		ns_hpfsmpl[1][i] = l-r;
	    }
	}
	{
        FLOAT const *pf = ns_hpfsmpl[chn & 1];
        for (i = 0; i < 9; i++) {
            FLOAT const *const pfe = pf + 576 / 9;
            FLOAT   p = 1.;
            for (; pf < pfe; pf++)
                if (p < fabs(*pf))
                    p = fabs(*pf);

            gfc->nsPsy.last_en_subshort[chn][i] = en_subshort[i + 3] = p;
            en_short[1 + i / 3] += p;
            if (p > en_subshort[i + 3 - 2])
                p = p / en_subshort[i + 3 - 2];
            else if (en_subshort[i + 3 - 2] > p * 10.0)
                p = en_subshort[i + 3 - 2] / (p * 10.0);
            else
                p = 0.0;
            attack_intensity[i + 3] = p;
	    }
	}
#if defined(HAVE_GTK)
	if (gfp->analysis) {
	    FLOAT x = attack_intensity[0];
	    for (i=1;i<12;i++) 
		if (x < attack_intensity[i])
		    x = attack_intensity[i];
	    gfc->pinfo->ers[gr_out][chn] = gfc->ers_save[chn];
	    gfc->ers_save[chn] = x;
	}
#endif
        /* compare energies between sub-shortblocks */
        attackThreshold = (chn == 3)
            ? gfc->nsPsy.attackthre_s : gfc->nsPsy.attackthre;
        for (i = 0; i < 12; i++)
            if (!ns_attacks[i / 3] && attack_intensity[i] > attackThreshold)
                ns_attacks[i / 3] = (i % 3) + 1;

        /* should have energy change between short blocks,
           in order to avoid periodic signals */
        for (i = 1; i < 4; i++) {
            float   ratio;
            if (en_short[i - 1] > en_short[i])
                ratio = en_short[i - 1] / en_short[i];
            else
                ratio = en_short[i] / en_short[i - 1];
            if (ratio < 1.7) {
                ns_attacks[i] = 0;
                if (i == 1)
                    ns_attacks[0] = 0;
            }
        }

        if (ns_attacks[0] && gfc->nsPsy.last_attacks[chn])
            ns_attacks[0] = 0;

        if (gfc->nsPsy.last_attacks[chn] == 3 ||
            ns_attacks[0] + ns_attacks[1] + ns_attacks[2] + ns_attacks[3]) {
            ns_uselongblock = 0;

            if (ns_attacks[1] && ns_attacks[0])
                ns_attacks[1] = 0;
            if (ns_attacks[2] && ns_attacks[1])
                ns_attacks[2] = 0;
            if (ns_attacks[3] && ns_attacks[2])
                ns_attacks[3] = 0;
        }

    if (chn < 2) {
        uselongblock[chn] = ns_uselongblock;
    }
    else {
        if (ns_uselongblock == 0) {
            uselongblock[0] = uselongblock[1] = 0;
        }
    }

	/* there is a one granule delay.  Copy maskings computed last call
	 * into masking_ratio to return to calling program.
	 */
	energy[chn]=gfc->tot_ener[chn];

	/*********************************************************************
	 *  compute FFTs
	 *********************************************************************/
	wsamp_s = wsamp_S+(chn & 1);
	wsamp_l = wsamp_L+(chn & 1);
	compute_ffts(gfp, fftenergy, fftenergy_s,
		     wsamp_l, wsamp_s, gr_out, chn, buffer);

	/* compute masking thresholds for short blocks */
	for (sblock = 0; sblock < 3; sblock++) {
	    FLOAT enn, thmm;
	    compute_masking_s(gfc, fftenergy_s, eb, thr, chn, sblock,
			      gfp->ATHlower*gfc->ATH->adjust);
        b = -1;
	    for (sb = 0; sb < SBMAX_s; sb++) {
		enn = thmm = 0.0;
		while (++b < gfc->bo_s[sb]) {
		    enn  += eb[b];
		    thmm += thr[b];
		}
		enn  += 0.5 * eb[b];    /* for the last sfb b is larger than npart_s!! */
		thmm += 0.5 * thr[b];   /* rh 20040301 */
		gfc->en [chn].s[sb][sblock] = enn;
        
        assert( enn >= 0 );
        assert( thmm >= 0 );
        
		/****   short block pre-echo control   ****/
		thmm *= NS_PREECHO_ATT0;
		if (ns_attacks[sblock] >= 2 || ns_attacks[sblock+1] == 1) {
		    int idx = (sblock != 0) ? sblock-1 : 2;
		    double p = NS_INTERP(gfc->thm[chn].s[sb][idx],
					 thmm, NS_PREECHO_ATT1*pcfact);
		    thmm = Min(thmm,p);
		}

		if (ns_attacks[sblock] == 1) {
		    int idx = (sblock != 0) ? sblock-1 : 2;
		    double p = NS_INTERP(gfc->thm[chn].s[sb][idx],
					 thmm,NS_PREECHO_ATT2*pcfact);
		    thmm = Min(thmm,p);
		} else if ((sblock != 0 && ns_attacks[sblock-1] == 3)
			|| (sblock == 0 && gfc->nsPsy.last_attacks[chn] == 3)) {
		    int idx = (sblock != 2) ? sblock+1 : 0;
		    double p = NS_INTERP(gfc->thm[chn].s[sb][idx],
					 thmm,NS_PREECHO_ATT2*pcfact);
		    thmm = Min(thmm,p);
		}

		/* pulse like signal detection for fatboy.wav and so on */
		enn = en_subshort[sblock*3+3] + en_subshort[sblock*3+4]
		    + en_subshort[sblock*3+5];
		if (en_subshort[sblock*3+5]*6 < enn) {
		    thmm *= 0.5;
		    if (en_subshort[sblock*3+4]*6 < enn)
			thmm *= 0.5;
		}

		gfc->thm[chn].s[sb][sblock] = thmm;
	    }
	}
	gfc->nsPsy.last_attacks[chn] = ns_attacks[2];

	/*********************************************************************
	 *    Calculate the energy and the tonality of each partition.
	 *********************************************************************/
	for (b = j = 0; b<gfc->npart_l; b++) {
	    FLOAT ebb,m;
	    m = ebb = fftenergy[j++];
	    for (i = gfc->numlines_l[b] - 1; i > 0; --i) {
		FLOAT el = fftenergy[j++];
		ebb += el;
		if (m < el)
		    m = el;
	    }
	    eb[b] = ebb;
	    max[b] = m;
	    avg[b] = ebb * gfc->rnumlines_l[b];
	}

	if (gfc->nsPsy.pass1fp)
	    nsPsy2dataRead(gfc->nsPsy.pass1fp, eb2, eb, chn, gfc->npart_l);
	else {
	    FLOAT m,a;
	    a = avg[0] + avg[1];
	    if (a != 0.0) {
		m = max[0]; if (m < max[1]) m = max[1];
		a = 20.0 * (m*2.0-a)
		    / (a*(gfc->numlines_l[0] + gfc->numlines_l[1] - 1));
		k = (int) a;
		if (k > sizeof(tab)/sizeof(tab[0]) - 1)
		    k = sizeof(tab)/sizeof(tab[0]) - 1;
		a = eb[0] * tab[k];
	    }
	    eb2[0] = a;

	    for (b = 1; b < gfc->npart_l-1; b++) {
		a = avg[b-1] + avg[b] + avg[b+1];
		if (a != 0.0) {
		    m = max[b-1];
		    if (m < max[b  ]) m = max[b];
		    if (m < max[b+1]) m = max[b+1];
		    a = 20.0 * (m*3.0-a)
			/ (a*(gfc->numlines_l[b-1] + gfc->numlines_l[b] + gfc->numlines_l[b+1] - 1));
		    k = (int) a;
		    if (k > sizeof(tab)/sizeof(tab[0]) - 1)
			k = sizeof(tab)/sizeof(tab[0]) - 1;
		    a = eb[b] * tab[k];
		}
		eb2[b] = a;
	    }

	    a = avg[gfc->npart_l-2] + avg[gfc->npart_l-1];
	    if (a != 0.0) {
		m = max[gfc->npart_l-2];
		if (m < max[gfc->npart_l-1])
		    m = max[gfc->npart_l-1];

		a = 20.0 * (m*2.0-a)
		    / (a*(gfc->numlines_l[gfc->npart_l-2] + gfc->numlines_l[gfc->npart_l-1] - 1));
		k = (int) a;
		if (k > sizeof(tab)/sizeof(tab[0]) - 1)
		    k = sizeof(tab)/sizeof(tab[0]) - 1;
		a = eb[b] * tab[k];
	    }
	    eb2[b] = a;
	}

	/*********************************************************************
	 *      convolve the partitioned energy and unpredictability
	 *      with the spreading function, s3_l[b][k]
	 ******************************************************************* */
#undef GPSYCHO_BLOCK_TYPE_DECISION
#ifdef GPSYCHO_BLOCK_TYPE_DECISION
   {
    FLOAT pe = 0;
#endif
	k = 0;
	for ( b = 0;b < gfc->npart_l; b++ ) {
	    FLOAT ecb;
	    /* convolve the partitioned energy with the spreading function */
	    int kk = gfc->s3ind[b][0];
	    ecb = gfc->s3_ll[k++] * eb2[kk];
	    while (++kk <= gfc->s3ind[b][1])
		ecb = mask_add(ecb, gfc->s3_ll[k++] * eb2[kk], kk, kk-b, gfc);

	    ecb *= 0.158489319246111; /* pow(10,-0.8) */

	    /****   long block pre-echo control   ****/
	    /* dont use long block pre-echo control if previous granule was 
	     * a short block.  This is to avoid the situation:   
	     * frame0:  quiet (very low masking)  
	     * frame1:  surge  (triggers short blocks)
	     * frame2:  regular frame.  looks like pre-echo when compared to 
	     *          frame0, but all pre-echo was in frame1.
	     */
	    /* chn=0,1   L and R channels
	       chn=2,3   S and M channels.
	    */

	    if (gfc->blocktype_old[chn & 1] == SHORT_TYPE)
		thr[b] = ecb; /* Min(ecb, rpelev*gfc->nb_1[chn][b]); */
	    else
		thr[b] = NS_INTERP(Min(ecb,
				       Min(rpelev*gfc->nb_1[chn][b],
					   rpelev2*gfc->nb_2[chn][b])),
				   ecb, pcfact);

	    gfc->nb_2[chn][b] = gfc->nb_1[chn][b];
	    gfc->nb_1[chn][b] = ecb;
#ifdef GPSYCHO_BLOCK_TYPE_DECISION
        /* this pe does not match GPSYCHO's pe, because of difference in 
         * convolution calculation, (mask_add etc.). Therefore the block
         * switching does not happen exactly as in GPSYCHO.
         */
		pe -= gfc->numlines_l[b] * FAST_LOG(ecb / eb[b]);
#endif
    }
#ifdef GPSYCHO_BLOCK_TYPE_DECISION
    determine_block_type( gfp, fftenergy_s, uselongblock, chn, gr_out, &pe );
   }
#endif
	/* compute masking thresholds for long blocks */
	convert_partition2scalefac_l(gfc, eb, thr, chn);

    } /* end loop over chn */

    if (gfp->interChRatio != 0.0)
	calc_interchannel_masking(gfp, gfp->interChRatio);

    if (gfp->mode == JOINT_STEREO) {
	FLOAT msfix;
	msfix1(gfc);
	msfix = gfp->msfix;
	if (msfix != 0.0)
	    ns_msfix(gfc, msfix, gfp->ATHlower*gfc->ATH->adjust);
    }

    /*************************************************************** 
     * determine final block type
     ***************************************************************/
    block_type_set(gfp, uselongblock, blocktype_d, blocktype);

    /*********************************************************************
     * compute the value of PE to return ... no delay and advance
     *********************************************************************/
    for(chn=0;chn<numchn;chn++) {
	FLOAT *ppe;
	int type;
	III_psy_ratio *mr;

	if (chn > 1) {
	    ppe = percep_MS_entropy - 2;
	    type = NORM_TYPE;
	    if (blocktype_d[0] == SHORT_TYPE || blocktype_d[1] == SHORT_TYPE)
		type = SHORT_TYPE;
	    mr = &masking_MS_ratio[gr_out][chn-2];
	} else {
	    ppe = percep_entropy;
	    type = blocktype_d[chn];
	    mr = &masking_ratio[gr_out][chn];
	}

	if (type == SHORT_TYPE)
	    ppe[chn] = pecalc_s(mr, gfc->masking_lower);
	else
	    ppe[chn] = pecalc_l(mr, gfc->masking_lower);

#if defined(HAVE_GTK)
	if (gfp->analysis) gfc->pinfo->pe[gr_out][chn] = ppe[chn];
#endif
    }
    return 0;
}





/* 
 *   The spreading function.  Values returned in units of energy
 */
static FLOAT s3_func(FLOAT bark) {
    FLOAT tempx,x,tempy,temp;
    tempx = bark;
    if (tempx>=0) tempx *= 3;
    else tempx *=1.5; 

    if (tempx>=0.5 && tempx<=2.5)
      {
	temp = tempx - 0.5;
	x = 8.0 * (temp*temp - 2.0 * temp);
      }
    else x = 0.0;
    tempx += 0.474;
    tempy = 15.811389 + 7.5*tempx - 17.5*sqrt(1.0+tempx*tempx);

    if (tempy <= -60.0) return  0.0;

    tempx = exp( (x + tempy)*LN_TO_LOG10 ); 

    /* Normalization.  The spreading function should be normalized so that:
         +inf
           /
           |  s3 [ bark ]  d(bark)   =  1
           /
         -inf
    */
    tempx /= .6609193;
    return tempx;
}

static int
init_numline(
    int *numlines, int *bo, int *bm,
    FLOAT *bval, FLOAT *bval_width, FLOAT *mld,

    FLOAT sfreq, int blksize, int *scalepos,
    FLOAT deltafreq, int sbmax
    )
{
    int partition[HBLKSIZE];
    int i, j, k;
    int sfb;

    sfreq /= blksize;
    j = 0;
    /* compute numlines, the number of spectral lines in each partition band */
    /* each partition band should be about DELBARK wide. */
    for (i=0;i<CBANDS;i++) {
	FLOAT bark1;
	int j2;
	bark1 = freq2bark(sfreq*j);
	for (j2 = j; freq2bark(sfreq*j2) - bark1 < DELBARK && j2 <= blksize/2;
	     j2++)
	    ;

	numlines[i] = j2 - j;
	while (j<j2)
	    partition[j++]=i;
	if (j > blksize/2) break;
    }

    for ( sfb = 0; sfb < sbmax; sfb++ ) {
	int i1,i2,start,end;
	FLOAT arg;
	start = scalepos[sfb];
	end   = scalepos[sfb+1];

	i1 = floor(.5 + deltafreq*(start-.5));
	if (i1<0) i1=0;
	i2 = floor(.5 + deltafreq*(end-.5));
	if (i2>blksize/2) i2=blksize/2;

	bm[sfb] = (partition[i1]+partition[i2])/2;
	bo[sfb] = partition[i2];

	/* setup stereo demasking thresholds */
	/* formula reverse enginerred from plot in paper */
	arg = freq2bark(sfreq*scalepos[sfb]*deltafreq);
	arg = (Min(arg, 15.5)/15.5);

	mld[sfb] = pow(10.0, 1.25*(1-cos(PI*arg))-2.5);
    }

    /* compute bark values of each critical band */
    j = 0;
    for (k = 0; k < i+1; k++) {
	int w = numlines[k];
	FLOAT  bark1,bark2;

	bark1 = freq2bark (sfreq*(j    ));
	bark2 = freq2bark (sfreq*(j+w-1));
	bval[k] = .5*(bark1+bark2);

	bark1 = freq2bark (sfreq*(j  -.5));
	bark2 = freq2bark (sfreq*(j+w-.5));
	bval_width[k] = bark2-bark1;
	j += w;
    }

    return i+1;
}

static int
init_s3_values(
    lame_internal_flags *gfc,
    FLOAT **p,
    int (*s3ind)[2],
    int npart,
    FLOAT *bval,
    FLOAT *bval_width,
    FLOAT *norm
    )
{
    FLOAT s3[CBANDS][CBANDS];
    /* The s3 array is not linear in the bark scale.
     * bval[x] should be used to get the bark value.
     */
    int i, j, k;
    int numberOfNoneZero = 0;

    /* s[i][j], the value of the spreading function,
     * centered at band j (masker), for band i (maskee)
     *
     * i.e.: sum over j to spread into signal barkval=i
     * NOTE: i and j are used opposite as in the ISO docs
     */
    for (i = 0; i < npart; i++)
	for (j = 0; j < npart; j++)
	    s3[i][j] = s3_func(bval[i] - bval[j]) * bval_width[j] * norm[i];

    for (i = 0; i < npart; i++) {
	for (j = 0; j < npart; j++) {
	    if (s3[i][j] != 0.0)
		break;
	}
	s3ind[i][0] = j;

	for (j = npart - 1; j > 0; j--) {
	    if (s3[i][j] != 0.0)
		break;
	}
	s3ind[i][1] = j;
	numberOfNoneZero += (s3ind[i][1] - s3ind[i][0] + 1);
    }
    *p = malloc(sizeof(FLOAT)*numberOfNoneZero);
    if (!*p)
	return -1;

    k = 0;
    for (i = 0; i < npart; i++)
	for (j = s3ind[i][0]; j <= s3ind[i][1]; j++)
	    (*p)[k++] = s3[i][j];

    return 0;
}

int psymodel_init(lame_global_flags *gfp)
{
    lame_internal_flags *gfc=gfp->internal_flags;
    int i,j,b,sb,k;

    FLOAT bval[CBANDS];
    FLOAT bval_width[CBANDS];
    FLOAT norm[CBANDS];
    FLOAT sfreq = gfp->out_samplerate;

    gfc->ms_ener_ratio_old=.25;
    gfc->blocktype_old[0] = gfc->blocktype_old[1] = NORM_TYPE; /* the vbr header is long blocks*/

    for (i=0; i<4; ++i) {
	for (j=0; j<CBANDS; ++j) {
	    gfc->nb_1[i][j]=1e20;
	    gfc->nb_2[i][j]=1e20;
	    gfc->nb_s1[i][j] = gfc->nb_s2[i][j] = 1.0;
	}
	for ( sb = 0; sb < SBMAX_l; sb++ ) {
	    gfc->en[i].l[sb] = 1e20;
	    gfc->thm[i].l[sb] = 1e20;
	}
	for (j=0; j<3; ++j) {
	    for ( sb = 0; sb < SBMAX_s; sb++ ) {
		gfc->en[i].s[sb][j] = 1e20;
		gfc->thm[i].s[sb][j] = 1e20;
	    }
	    gfc->nsPsy.last_attacks[i] = 0;
	}
	for(j=0;j<9;j++)
	    gfc->nsPsy.last_en_subshort[i][j] = 10.;
    }



    j = gfc->PSY->cwlimit/(sfreq/BLKSIZE);
    if (j > HBLKSIZE-4) /* j+3 < HBLKSIZE-1 */
	j = HBLKSIZE-4;
    if (j < CW_LOWER_INDEX)
	j = CW_LOWER_INDEX;
    gfc->cw_upper_index = j;

    for (j = 0; j < HBLKSIZE; j++)
	gfc->cw[j] = 0.4f;

    /* init. for loudness approx. -jd 2001 mar 27*/
    gfc->loudness_sq_save[0] = gfc->loudness_sq_save[1] = 0.0;




    /*************************************************************************
     * now compute the psychoacoustic model specific constants
     ************************************************************************/
    /* compute numlines, bo, bm, bval, bval_width, mld */
    gfc->npart_l
	= init_numline(gfc->numlines_l, gfc->bo_l, gfc->bm_l,
		       bval, bval_width, gfc->mld_l,
		       sfreq, BLKSIZE, 
		       gfc->scalefac_band.l, BLKSIZE/(2.0*576), SBMAX_l);
    assert(gfc->npart_l <= CBANDS);
    /* compute the spreading function */
    for(i=0;i<gfc->npart_l;i++) {
	norm[i]=1.0;
	gfc->rnumlines_l[i] = 1.0 / gfc->numlines_l[i];
    }
    i = init_s3_values(gfc, &gfc->s3_ll, gfc->s3ind,
		       gfc->npart_l, bval, bval_width, norm);
    if (i)
	return i;

    /* compute long block specific values, ATH and MINVAL */
    j = 0;
    for ( i = 0; i < gfc->npart_l; i++ ) {
	double x;

	/* ATH */
	x = FLOAT_MAX;
	for (k=0; k < gfc->numlines_l[i]; k++, j++) {
	    FLOAT  freq = sfreq*j/(1000.0*BLKSIZE);
	    FLOAT  level;
	    /*	freq = Min(.1,freq);*/      /* ATH below 100 Hz constant, not further climbing */
	    level  = ATHformula (freq*1000, gfp) - 20;   /* scale to FFT units; returned value is in dB */
	    level  = pow ( 10., 0.1*level );   /* convert from dB -> energy */
	    level *= gfc->numlines_l [i];
	    if (x > level)
		x = level;
	}
	gfc->ATH->cb[i] = x;

	/* MINVAL.
	   For low freq, the strength of the masking is limited by minval
	   this is an ISO MPEG1 thing, dont know if it is really needed */
	x = (-20+bval[i]*20.0/10.0);
	if (bval[i]>10) x = 0;
	gfc->minval[i]=pow(10.0,x/10);
	gfc->PSY->prvTonRed[i] = gfc->minval[i];
    }


    /************************************************************************
     * do the same things for short blocks
     ************************************************************************/
    gfc->npart_s
	= init_numline(gfc->numlines_s, gfc->bo_s, gfc->bm_s,
		       bval, bval_width, gfc->mld_s,
		       sfreq, BLKSIZE_s,
		       gfc->scalefac_band.s, BLKSIZE_s/(2.0*192), SBMAX_s);
    assert(gfc->npart_s <= CBANDS);

    /* SNR formula. short block is normalized by SNR. is it still right ? */
    for(i=0;i<gfc->npart_s;i++) {
	double snr=-8.25;
	if (bval[i]>=13)
	    snr = -4.5 * (bval[i]-13)/(24.0-13.0)
		-8.25*(bval[i]-24)/(13.0-24.0);

	norm[i]=pow(10.0,snr/10.0);
    }
    i = init_s3_values(gfc, &gfc->s3_ss, gfc->s3ind_s,
		       gfc->npart_s, bval, bval_width, norm);
    if (i)
	return i;


    init_mask_add_max_values();
    init_fft(gfc);

    /* setup temporal masking */
    gfc->decay = exp(-1.0*LOG10/(temporalmask_sustain_sec*sfreq/192.0));

    if (gfp->psymodel == PSY_NSPSYTUNE) {
        FLOAT msfix;
        msfix = NS_MSFIX;
        if (gfp->exp_nspsytune & 2) msfix = 1.0;
        if (gfp->msfix != 0.0) msfix = gfp->msfix;
        gfp->msfix = msfix;

        /* spread only from npart_l bands.  Normally, we use the spreading
        * function to convolve from npart_l down to npart_l bands 
        */
        for (b=0;b<gfc->npart_l;b++)
            if (gfc->s3ind[b][1] > gfc->npart_l-1)
                gfc->s3ind[b][1] = gfc->npart_l-1;
    }

    /*  prepare for ATH auto adjustment:
     *  we want to decrease the ATH by 12 dB per second
     */
#define  frame_duration (576. * gfc->mode_gr / sfreq)
    gfc->ATH->decay = pow(10., -12./10. * frame_duration);
    gfc->ATH->adjust = 0.01; /* minimum, for leading low loudness */
    gfc->ATH->adjust_limit = 1.0; /* on lead, allow adjust up to maximum */
#undef  frame_duration

    gfc->bo_s[SBMAX_s-1]--;
    assert(gfc->bo_l[SBMAX_l-1] <= gfc->npart_l);
    assert(gfc->bo_s[SBMAX_s-1] <= gfc->npart_s);

    if (gfp->ATHtype != -1) { 
	/* compute equal loudness weights (eql_w) */
	FLOAT freq;
	FLOAT freq_inc = gfp->out_samplerate / (BLKSIZE);
	FLOAT eql_balance = 0.0;
	freq = 0.0;
	for( i = 0; i < BLKSIZE/2; ++i ) {
	    /* convert ATH dB to relative power (not dB) */
	    /*  to determine eql_w */
	    freq += freq_inc;
	    gfc->ATH->eql_w[i] = 1. / pow( 10, ATHformula( freq, gfp ) / 10 );
	    eql_balance += gfc->ATH->eql_w[i];
	}
	eql_balance = 1.0 / eql_balance;
	for( i = BLKSIZE/2; --i >= 0; ) { /* scale weights */
	    gfc->ATH->eql_w[i] *= eql_balance;
	}
    }

    return 0;
}

