/*
 *	MP3 quantization
 *
 *	Copyright (c) 1999-2000 Mark Taylor
 *	Copyright (c) 2000-2005 Robert Hegemann
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

/* $Id: vbrquantize.c,v 1.103.2.1 2005/11/20 14:08:25 bouvigne Exp $ */

#ifdef HAVE_CONFIG_H
#  include <config.h>
#endif

#include <assert.h>
#include "util.h"
#include "l3side.h"
#include "quantize_pvt.h"
#include "vbrquantize.h"

#ifdef WITH_DMALLOC
#  include <dmalloc.h>
#endif



struct algo_s;
typedef struct algo_s algo_t;

typedef void (*quantize_f) (const algo_t *);

typedef int (*find_f) (const FLOAT *, const FLOAT *, FLOAT, int, int);

typedef int (*alloc_sf_f) (const algo_t *, int *, const int *, int);

struct algo_s {
    find_f  find;
    quantize_f quantize;
    alloc_sf_f alloc;
    const FLOAT *xr34orig;
    lame_internal_flags *gfc;
    gr_info *cod_info;
    int mingain_l;
    int mingain_s[3];
};



/*  Remarks on optimizing compilers:
 *
 *  the MSVC compiler may get into aliasing problems when accessing
 *  memory through the fi_union. declaring it volatile does the trick here
 *
 *  the calc_sfb_noise_* functions are not inlined because the intel compiler
 *  optimized executeables won't work as expected anymore
 */

#ifdef _MSC_VER
#  define VOLATILE volatile
#else
#  define VOLATILE
#endif

typedef VOLATILE union {
    float   f;
    int     i;
} fi_union;



#define DOUBLEX double

#define MAGIC_FLOAT_def (65536*(128))
#define MAGIC_INT_def    0x4b000000

#ifdef TAKEHIRO_IEEE754_HACK
#  define ROUNDFAC_def -0.0946f
#else
/*********************************************************************
 * XRPOW_FTOI is a macro to convert floats to ints.
 * if XRPOW_FTOI(x) = nearest_int(x), then QUANTFAC(x)=adj43asm[x]
 *                                         ROUNDFAC= -0.0946
 *
 * if XRPOW_FTOI(x) = floor(x), then QUANTFAC(x)=asj43[x]
 *                                   ROUNDFAC=0.4054
 *********************************************************************/
#  define QUANTFAC(rx)  adj43[rx]
#  define ROUNDFAC_def 0.4054f
#  define XRPOW_FTOI(src,dest) ((dest) = (int)(src))
#endif

static int const MAGIC_INT = MAGIC_INT_def;
static DOUBLEX const ROUNDFAC = ROUNDFAC_def;
static DOUBLEX const MAGIC_FLOAT = (65536 * (128));
static DOUBLEX const ROUNDFAC_plus_MAGIC_FLOAT = ROUNDFAC_def + MAGIC_FLOAT_def;



static int
valid_sf(int sf)
{
    return (sf >= 0 ? (sf <= 255 ? sf : 255) : 0);
}



static  FLOAT
max_x34(const FLOAT * xr34, unsigned int bw)
{
    FLOAT   xfsf = 0;
    int     j = bw >> 1;
    int     remaining = j % 2;
    assert(bw >= 0);
    for (j >>= 1; j > 0; --j) {
        if (xfsf < xr34[0]) {
            xfsf = xr34[0];
        }
        if (xfsf < xr34[1]) {
            xfsf = xr34[1];
        }
        if (xfsf < xr34[2]) {
            xfsf = xr34[2];
        }
        if (xfsf < xr34[3]) {
            xfsf = xr34[3];
        }
        xr34 += 4;
    }
    if (remaining) {
        if (xfsf < xr34[0]) {
            xfsf = xr34[0];
        }
        if (xfsf < xr34[1]) {
            xfsf = xr34[1];
        }
    }
    return xfsf;
}



static int
find_lowest_scalefac(const FLOAT xr34)
{
    FLOAT   xfsf;
    int     sf = 128, sf_ok = 10000, delsf = 128, i;
    for (i = 0; i < 8; ++i) {
        delsf >>= 1;
        xfsf = IPOW20(sf) * xr34;
        if (xfsf <= IXMAX_VAL) {
            sf_ok = sf;
            sf -= delsf;
        }
        else {
            sf += delsf;
        }
    }
    if (sf_ok < 255) {
        sf = sf_ok;
    }
    return sf;
}



static void
k_34_4(DOUBLEX x[4], int l3[4])
{
#ifdef TAKEHIRO_IEEE754_HACK
    fi_union fi[4];

    assert(x[0] <= IXMAX_VAL && x[1] <= IXMAX_VAL && x[2] <= IXMAX_VAL && x[3] <= IXMAX_VAL);
    x[0] += MAGIC_FLOAT;
    fi[0].f = x[0];
    x[1] += MAGIC_FLOAT;
    fi[1].f = x[1];
    x[2] += MAGIC_FLOAT;
    fi[2].f = x[2];
    x[3] += MAGIC_FLOAT;
    fi[3].f = x[3];
    fi[0].f = x[0] + adj43asm[fi[0].i - MAGIC_INT];
    fi[1].f = x[1] + adj43asm[fi[1].i - MAGIC_INT];
    fi[2].f = x[2] + adj43asm[fi[2].i - MAGIC_INT];
    fi[3].f = x[3] + adj43asm[fi[3].i - MAGIC_INT];
    l3[0] = fi[0].i - MAGIC_INT;
    l3[1] = fi[1].i - MAGIC_INT;
    l3[2] = fi[2].i - MAGIC_INT;
    l3[3] = fi[3].i - MAGIC_INT;
#else
    assert(x[0] <= IXMAX_VAL && x[1] <= IXMAX_VAL && x[2] <= IXMAX_VAL && x[3] <= IXMAX_VAL);
    XRPOW_FTOI(x[0], l3[0]);
    XRPOW_FTOI(x[1], l3[1]);
    XRPOW_FTOI(x[2], l3[2]);
    XRPOW_FTOI(x[3], l3[3]);
    x[0] += QUANTFAC(l3[0]);
    x[1] += QUANTFAC(l3[1]);
    x[2] += QUANTFAC(l3[2]);
    x[3] += QUANTFAC(l3[3]);
    XRPOW_FTOI(x[0], l3[0]);
    XRPOW_FTOI(x[1], l3[1]);
    XRPOW_FTOI(x[2], l3[2]);
    XRPOW_FTOI(x[3], l3[3]);
#endif
}



static void
k_34_2(DOUBLEX x[2], int l3[2])
{
#ifdef TAKEHIRO_IEEE754_HACK
    fi_union fi[2];

    assert(x[0] <= IXMAX_VAL && x[1] <= IXMAX_VAL);
    x[0] += MAGIC_FLOAT;
    fi[0].f = x[0];
    x[1] += MAGIC_FLOAT;
    fi[1].f = x[1];
    fi[0].f = x[0] + adj43asm[fi[0].i - MAGIC_INT];
    fi[1].f = x[1] + adj43asm[fi[1].i - MAGIC_INT];
    l3[0] = fi[0].i - MAGIC_INT;
    l3[1] = fi[1].i - MAGIC_INT;
#else
    assert(x[0] <= IXMAX_VAL && x[1] <= IXMAX_VAL);
    XRPOW_FTOI(x[0], l3[0]);
    XRPOW_FTOI(x[1], l3[1]);
    x[0] += QUANTFAC(l3[0]);
    x[1] += QUANTFAC(l3[1]);
    XRPOW_FTOI(x[0], l3[0]);
    XRPOW_FTOI(x[1], l3[1]);
#endif
}



static void
k_iso_4(DOUBLEX x[4], int l3[4])
{
#ifdef TAKEHIRO_IEEE754_HACK
    fi_union fi[4];

    assert(x[0] <= IXMAX_VAL && x[1] <= IXMAX_VAL && x[2] <= IXMAX_VAL && x[3] <= IXMAX_VAL);
    x[0] += ROUNDFAC_plus_MAGIC_FLOAT;
    fi[0].f = x[0];
    x[1] += ROUNDFAC_plus_MAGIC_FLOAT;
    fi[1].f = x[1];
    x[2] += ROUNDFAC_plus_MAGIC_FLOAT;
    fi[2].f = x[2];
    x[3] += ROUNDFAC_plus_MAGIC_FLOAT;
    fi[3].f = x[3];
    l3[0] = fi[0].i - MAGIC_INT;
    l3[1] = fi[1].i - MAGIC_INT;
    l3[2] = fi[2].i - MAGIC_INT;
    l3[3] = fi[3].i - MAGIC_INT;
#else
    l3[0] = x[0] + ROUNDFAC;
    l3[1] = x[1] + ROUNDFAC;
    l3[2] = x[2] + ROUNDFAC;
    l3[3] = x[3] + ROUNDFAC;
#endif
}



static void
k_iso_2(DOUBLEX x[2], int l3[2])
{
#ifdef TAKEHIRO_IEEE754_HACK
    fi_union fi[2];

    assert(x[0] <= IXMAX_VAL && x[1] <= IXMAX_VAL);
    x[0] += ROUNDFAC_plus_MAGIC_FLOAT;
    fi[0].f = x[0];
    x[1] += ROUNDFAC_plus_MAGIC_FLOAT;
    fi[1].f = x[1];
    l3[0] = fi[0].i - MAGIC_INT;
    l3[1] = fi[1].i - MAGIC_INT;
#else
    l3[0] = x[0] + ROUNDFAC;
    l3[1] = x[1] + ROUNDFAC;
#endif
}



/*  do call the calc_sfb_noise_* functions only with sf values
 *  for which holds: sfpow34*xr34 <= IXMAX_VAL
 */

static  FLOAT
calc_sfb_noise_x34(const FLOAT * xr, const FLOAT * xr34, unsigned int bw, int sf)
{
    DOUBLEX x[4];
    int     l3[4];
    const int SF = valid_sf(sf);
    const FLOAT sfpow = POW20(SF); /*pow(2.0,sf/4.0); */
    const FLOAT sfpow34 = IPOW20(SF); /*pow(sfpow,-3.0/4.0); */

    FLOAT   xfsf = 0;
    int     j = bw >> 1;
    int     remaining = j % 2;
    assert(bw >= 0);
    for (j >>= 1; j > 0; --j) {
        x[0] = sfpow34 * xr34[0];
        x[1] = sfpow34 * xr34[1];
        x[2] = sfpow34 * xr34[2];
        x[3] = sfpow34 * xr34[3];

        k_34_4(x, l3);

        x[0] = fabs(xr[0]) - sfpow * pow43[l3[0]];
        x[1] = fabs(xr[1]) - sfpow * pow43[l3[1]];
        x[2] = fabs(xr[2]) - sfpow * pow43[l3[2]];
        x[3] = fabs(xr[3]) - sfpow * pow43[l3[3]];
        xfsf += (x[0] * x[0] + x[1] * x[1]) + (x[2] * x[2] + x[3] * x[3]);

        xr += 4;
        xr34 += 4;
    }
    if (remaining) {
        x[0] = sfpow34 * xr34[0];
        x[1] = sfpow34 * xr34[1];

        k_34_2(x, l3);

        x[0] = fabs(xr[0]) - sfpow * pow43[l3[0]];
        x[1] = fabs(xr[1]) - sfpow * pow43[l3[1]];
        xfsf += x[0] * x[0] + x[1] * x[1];
    }
    return xfsf;
}



static  FLOAT
calc_sfb_noise_ISO(const FLOAT * xr, const FLOAT * xr34, unsigned int bw, int sf)
{
    DOUBLEX x[4];
    int     l3[4];
    const int SF = valid_sf(sf);
    const FLOAT sfpow = POW20(SF); /*pow(2.0,sf/4.0); */
    const FLOAT sfpow34 = IPOW20(SF); /*pow(sfpow,-3.0/4.0); */

    FLOAT   xfsf = 0;
    int     j = bw >> 1;
    int     remaining = j % 2;
    assert(bw >= 0);
    for (j >>= 1; j > 0; --j) {
        x[0] = sfpow34 * xr34[0];
        x[1] = sfpow34 * xr34[1];
        x[2] = sfpow34 * xr34[2];
        x[3] = sfpow34 * xr34[3];

        k_iso_4(x, l3);

        x[0] = fabs(xr[0]) - sfpow * pow43[l3[0]];
        x[1] = fabs(xr[1]) - sfpow * pow43[l3[1]];
        x[2] = fabs(xr[2]) - sfpow * pow43[l3[2]];
        x[3] = fabs(xr[3]) - sfpow * pow43[l3[3]];

        xfsf += (x[0] * x[0] + x[1] * x[1]) + (x[2] * x[2] + x[3] * x[3]);

        xr += 4;
        xr34 += 4;
    }
    if (remaining) {
        x[0] = sfpow34 * xr34[0];
        x[1] = sfpow34 * xr34[1];

        k_iso_2(x, l3);

        x[0] = fabs(xr[0]) - sfpow * pow43[l3[0]];
        x[1] = fabs(xr[1]) - sfpow * pow43[l3[1]];
        xfsf += x[0] * x[0] + x[1] * x[1];
    }
    return xfsf;
}



/* the find_scalefac* routines calculate
 * a quantization step size which would
 * introduce as much noise as is allowed.
 * The larger the step size the more
 * quantization noise we'll get. The
 * scalefactors are there to lower the
 * global step size, allowing limited
 * differences in quantization step sizes
 * per band (shaping the noise).
 */

static int
find_scalefac_x34(const FLOAT * xr, const FLOAT * xr34, FLOAT l3_xmin, int bw, int sf_min)
{
    int     sf = 128, sf_ok = 10000, delsf = 128, i;
    for (i = 0; i < 8; ++i) {
        delsf >>= 1;
        if (sf <= sf_min) {
            sf += delsf;
        }
        else {
            if ((sf < 255 && calc_sfb_noise_x34(xr, xr34, bw, sf + 1) > l3_xmin)
                || calc_sfb_noise_x34(xr, xr34, bw, sf) > l3_xmin
                || calc_sfb_noise_x34(xr, xr34, bw, sf - 1) > l3_xmin) {
                /* distortion.  try a smaller scalefactor */
                sf -= delsf;
            }
            else {
                sf_ok = sf;
                sf += delsf;
            }
        }
    }
    /*  returning a scalefac without distortion, if possible
     */
    if (sf_ok <= 255) {
        sf = sf_ok;
    }
    return sf;
}



static int
find_scalefac_ISO(const FLOAT * xr, const FLOAT * xr34, FLOAT l3_xmin, int bw, int sf_min)
{
    int     sf = 128, sf_ok = 10000, delsf = 128, i;
    for (i = 0; i < 8; ++i) {
        delsf >>= 1;
        if (sf <= sf_min) {
            sf += delsf;
        }
        else {
            if ((sf < 255 && calc_sfb_noise_ISO(xr, xr34, bw, sf + 1) > l3_xmin)
                || calc_sfb_noise_ISO(xr, xr34, bw, sf) > l3_xmin
                || calc_sfb_noise_ISO(xr, xr34, bw, sf - 1) > l3_xmin) {
                /* distortion.  try a smaller scalefactor */
                sf -= delsf;
            }
            else {
                sf_ok = sf;
                sf += delsf;
            }
        }
    }
    /*  returning a scalefac without distortion, if possible
     */
    if (sf_ok <= 255) {
        sf = sf_ok;
    }
    return sf;
}



/***********************************************************************
 *
 *      calc_short_block_vbr_sf()
 *      calc_long_block_vbr_sf()
 *
 *  Mark Taylor 2000-??-??
 *  Robert Hegemann 2000-10-25 made functions of it
 *
 ***********************************************************************/

/* a variation for vbr-mtrh */
static int
block_sf(algo_t * that, const FLOAT l3_xmin[576], int vbrsf[SFBMAX], int vbrsfmin[SFBMAX])
{
    FLOAT   max_xr34;
    const FLOAT *xr = &that->cod_info->xr[0];
    const FLOAT *xr34_orig = &that->xr34orig[0];
    const int *width = &that->cod_info->width[0];
    const int max_nonzero_coeff = that->cod_info->max_nonzero_coeff;
    int     maxsf = 0;
    int     sfb = 0, j = 0, i = 0;
    int const psymax = that->cod_info->psymax;

    that->mingain_l = 0;
    that->mingain_s[0] = 0;
    that->mingain_s[1] = 0;
    that->mingain_s[2] = 0;
    while (j <= max_nonzero_coeff) {
        int l, w = l = width[sfb];
        int m = max_nonzero_coeff - j + 1, m1, m2;
        if (l > m) {
            l = m;
        }
        max_xr34 = max_x34(&xr34_orig[j], l);
        
        m1 = find_lowest_scalefac(max_xr34);
        vbrsfmin[sfb] = m1;
        if (that->mingain_l < m1) {
            that->mingain_l = m1;
        }
        if (that->mingain_s[i] < m1) {
            that->mingain_s[i] = m1;
        }
        if (i < 2) {
            ++i;
        }
        else {
            i = 0;
        }
        if (sfb < psymax) {
            m2 = that->find(&xr[j], &xr34_orig[j], l3_xmin[sfb], l, m1);
            if (maxsf < m2) {
                maxsf = m2;
            }
        }
        else {
            if (maxsf < m1) {
                maxsf = m1;
            }
            m2 = maxsf;
        }
        vbrsf[sfb] = m2;
        ++sfb;
        j += w;
    }
    for (; sfb < SFBMAX; ++sfb) {
        vbrsf[sfb] = maxsf;
        vbrsfmin[sfb] = 0;
    }
    return maxsf;
}



/***********************************************************************
 *
 *  quantize xr34 based on scalefactors
 *
 *  block_xr34
 *
 *  Mark Taylor 2000-??-??
 *  Robert Hegemann 2000-10-20 made functions of them
 *
 ***********************************************************************/

static void
quantize_x34(const algo_t * that)
{
    DOUBLEX x[4];
    const FLOAT *xr34_orig = that->xr34orig;
    gr_info *cod_info = that->cod_info;
    int    *l3 = cod_info->l3_enc;
    int     j = 0, sfb = 0;
    const int max_nonzero_coeff = cod_info->max_nonzero_coeff;

    while (j <= max_nonzero_coeff) {
        const int s = ((cod_info->scalefac[sfb] + (cod_info->preflag ? pretab[sfb] : 0))
                       << (cod_info->scalefac_scale + 1))
            + cod_info->subblock_gain[cod_info->window[sfb]] * 8;
        const int sfac = valid_sf(cod_info->global_gain - s);
        const FLOAT sfpow34 = IPOW20(sfac);
        int     remaining;
        int     l , w = l = cod_info->width[sfb];
        int     m = max_nonzero_coeff - j + 1;
        if (l > m) {
            l = m;
        }
        j += w;
        ++sfb;
        l >>= 1;
        remaining = l % 2;

        for (l >>= 1; l > 0; --l) {
            x[0] = sfpow34 * xr34_orig[0];
            x[1] = sfpow34 * xr34_orig[1];
            x[2] = sfpow34 * xr34_orig[2];
            x[3] = sfpow34 * xr34_orig[3];

            k_34_4(x, l3);

            l3 += 4;
            xr34_orig += 4;
        }
        if (remaining) {
            x[0] = sfpow34 * xr34_orig[0];
            x[1] = sfpow34 * xr34_orig[1];

            k_34_2(x, l3);

            l3 += 2;
            xr34_orig += 2;
        }
    }
}



static void
quantize_ISO(const algo_t * that)
{
    DOUBLEX x[4];
    const FLOAT *xr34_orig = that->xr34orig;
    gr_info *cod_info = that->cod_info;
    int    *l3 = cod_info->l3_enc;
    int     j = 0, sfb = 0;
    const int max_nonzero_coeff = cod_info->max_nonzero_coeff;

    while (j <= max_nonzero_coeff) {
        const int s = ((cod_info->scalefac[sfb] + (cod_info->preflag ? pretab[sfb] : 0))
                       << (cod_info->scalefac_scale + 1))
            + cod_info->subblock_gain[cod_info->window[sfb]] * 8;
        const int sfac = valid_sf(cod_info->global_gain - s);
        const FLOAT sfpow34 = IPOW20(sfac);
        int     remaining;
        int     l, w = l = cod_info->width[sfb];
        int     m = max_nonzero_coeff - j + 1;
        if (l > m) {
            l = m;
        }
        j += w;
        ++sfb;
        l >>= 1;
        remaining = l % 2;

        for (l >>= 1; l > 0; --l) {
            x[0] = sfpow34 * xr34_orig[0];
            x[1] = sfpow34 * xr34_orig[1];
            x[2] = sfpow34 * xr34_orig[2];
            x[3] = sfpow34 * xr34_orig[3];

            k_iso_4(x, l3);

            l3 += 4;
            xr34_orig += 4;
        }
        if (remaining) {
            x[0] = sfpow34 * xr34_orig[0];
            x[1] = sfpow34 * xr34_orig[1];

            k_iso_2(x, l3);

            l3 += 2;
            xr34_orig += 2;
        }
    }
}




static const int max_range_short[SBMAX_s * 3] = {
    15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15,
    7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
    0, 0, 0
};

static const int max_range_long[SBMAX_l] =
    { 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
    0
};

static const int max_range_long_lsf_pretab[SBMAX_l] =
    { 7, 7, 7, 7, 7, 7, 3, 3, 3, 3, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };



/*
    sfb=0..5  scalefac < 16
    sfb>5     scalefac < 8

    ifqstep = ( cod_info->scalefac_scale == 0 ) ? 2 : 4;
    ol_sf =  (cod_info->global_gain-210.0);
    ol_sf -= 8*cod_info->subblock_gain[i];
    ol_sf -= ifqstep*scalefac[gr][ch].s[sfb][i];
*/

static void
set_subblock_gain(gr_info * cod_info, const int mingain_s[3], int sf[])
{
    const int maxrange1 = 15, maxrange2 = 7;
    const int ifqstepShift = (cod_info->scalefac_scale == 0) ? 1 : 2;
    int    *sbg = cod_info->subblock_gain;
    int     psymax = cod_info->psymax;
    int     psydiv = 18;
    int     sbg0, sbg1, sbg2;
    int     sfb, i;

    if (psydiv > psymax) {
        psydiv = psymax;
    }
    for (i = 0; i < 3; ++i) {
        int     maxsf1 = 0, maxsf2 = 0, minsf = 1000;
        /* see if we should use subblock gain */
        for (sfb = i; sfb < psydiv; sfb += 3) { /* part 1 */
            int     v = -sf[sfb];
            if (maxsf1 < v) {
                maxsf1 = v;
            }
            if (minsf > v) {
                minsf = v;
            }
        }
        for (; sfb < SFBMAX; sfb += 3) { /* part 2 */
            int     v = -sf[sfb];
            if (maxsf2 < v) {
                maxsf2 = v;
            }
            if (minsf > v) {
                minsf = v;
            }
        }

        /* boost subblock gain as little as possible so we can
         * reach maxsf1 with scalefactors
         * 8*sbg >= maxsf1
         */
        {
            int     m1 = maxsf1 - (maxrange1 << ifqstepShift);
            int     m2 = maxsf2 - (maxrange2 << ifqstepShift);

            maxsf1 = Max(m1, m2);
        }
        if (minsf > 0) {
            sbg[i] = minsf >> 3;
        }
        else {
            sbg[i] = 0;
        }
        if (maxsf1 > 0) {
            int     m1 = sbg[i];
            int     m2 = (maxsf1 + 7) >> 3;
            sbg[i] = Max(m1, m2);
        }
        if (sbg[i] > 0 && mingain_s[i] > (cod_info->global_gain - sbg[i] * 8)) {
            sbg[i] = (cod_info->global_gain - mingain_s[i]) >> 3;
        }
        if (sbg[i] > 7) {
            sbg[i] = 7;
        }
    }
    sbg0 = sbg[0] << 3;
    sbg1 = sbg[1] << 3;
    sbg2 = sbg[2] << 3;
    for (sfb = 0; sfb < SFBMAX; sfb += 3) {
        sf[sfb + 0] += sbg0;
        sf[sfb + 1] += sbg1;
        sf[sfb + 2] += sbg2;
    }
}



/*
	  ifqstep = ( cod_info->scalefac_scale == 0 ) ? 2 : 4;
	  ol_sf =  (cod_info->global_gain-210.0);
	  ol_sf -= ifqstep*scalefac[gr][ch].l[sfb];
	  if (cod_info->preflag && sfb>=11)
	  ol_sf -= ifqstep*pretab[sfb];
*/
static void
set_scalefacs(gr_info * cod_info, const int *vbrsfmin, int sf[], const int *max_range)
{
    const int ifqstep = (cod_info->scalefac_scale == 0) ? 2 : 4;
    const int ifqstepShift = (cod_info->scalefac_scale == 0) ? 1 : 2;
    int    *scalefac = cod_info->scalefac;
    int     sfb, sfbmax = cod_info->sfbmax;
    int    *sbg = cod_info->subblock_gain;
    int    *window = cod_info->window;
    int     preflag = cod_info->preflag;

    if (preflag) {
        for (sfb = 11; sfb < sfbmax; ++sfb) {
            sf[sfb] += pretab[sfb] << ifqstepShift;
        }
    }
    for (sfb = 0; sfb < sfbmax; ++sfb) {
        int     gain = cod_info->global_gain - (sbg[window[sfb]] << 3)
            - ((preflag ? pretab[sfb] : 0) << ifqstepShift);

        if (sf[sfb] < 0) {
            int     m = gain - vbrsfmin[sfb];
            /* ifqstep*scalefac >= -sf[sfb], so round UP */
            scalefac[sfb] = (ifqstep - 1 - sf[sfb]) >> ifqstepShift;

            if (scalefac[sfb] > max_range[sfb]) {
                scalefac[sfb] = max_range[sfb];
            }
            if (scalefac[sfb] > 0 && (scalefac[sfb] << ifqstepShift) > m) {
                scalefac[sfb] = m >> ifqstepShift;
            }
        }
        else {
            scalefac[sfb] = 0;
        }
    }
    for (; sfb < SFBMAX; ++sfb) {
        scalefac[sfb] = 0; /* sfb21 */
    }
}



static int
checkScalefactor(const gr_info * cod_info, const int vbrsfmin[SFBMAX])
{
    int     sfb;
    for (sfb = 0; sfb < cod_info->psymax; ++sfb) {
        const int s =
            ((cod_info->scalefac[sfb] +
              (cod_info->preflag ? pretab[sfb] : 0)) << (cod_info->
                                                         scalefac_scale + 1)) +
            cod_info->subblock_gain[cod_info->window[sfb]] * 8;

        if ((cod_info->global_gain - s) < vbrsfmin[sfb]) {
            /*
               fprintf( stdout, "sf %d\n", sfb );
               fprintf( stdout, "min %d\n", vbrsfmin[sfb] );
               fprintf( stdout, "ggain %d\n", cod_info->global_gain );
               fprintf( stdout, "scalefac %d\n", cod_info->scalefac[sfb] );
               fprintf( stdout, "pretab %d\n", (cod_info->preflag ? pretab[sfb] : 0) );
               fprintf( stdout, "scale %d\n", (cod_info->scalefac_scale + 1) );
               fprintf( stdout, "subgain %d\n", cod_info->subblock_gain[cod_info->window[sfb]] * 8 );
               fflush( stdout );
               exit(-1);
             */
            return 0;
        }
    }
    return 1;
}



/******************************************************************
 *
 *  short block scalefacs
 *
 ******************************************************************/

static int
short_block_constrain(const algo_t * that, int vbrsf[SFBMAX],
                      const int vbrsfmin[SFBMAX], int vbrmax)
{
    gr_info *cod_info = that->cod_info;
    lame_internal_flags *gfc = that->gfc;
    int const maxminsfb = that->mingain_l;
    int     mover, maxover0 = 0, maxover1 = 0, delta = 0;
    int     v, v0, v1;
    int     sfb;
    int     psymax = cod_info->psymax;

    for (sfb = 0; sfb < psymax; ++sfb) {
        assert( vbrsf[sfb] >= vbrsfmin[sfb] );
        v  = vbrmax - vbrsf[sfb];
        if (delta < v) {
            delta = v;
        }
        v0 = v - (4 * 14 + 2 * max_range_short[sfb]);
        v1 = v - (4 * 14 + 4 * max_range_short[sfb]);
        if (maxover0 < v0) {
            maxover0 = v0;
        }
        if (maxover1 < v1) {
            maxover1 = v1;
        }
    }
    if (gfc->noise_shaping == 2) {
        /* allow scalefac_scale=1 */
        mover = Min(maxover0, maxover1);
    }
    else {
        mover = maxover0;
    }
    if (delta > mover) {
        delta = mover;
    }
    vbrmax -= delta;
    maxover0 -= mover;
    maxover1 -= mover;

    if (maxover0 == 0) {
        cod_info->scalefac_scale = 0;
    }
    else if (maxover1 == 0) {
        cod_info->scalefac_scale = 1;
    }
    if (vbrmax < maxminsfb) {
        vbrmax = maxminsfb;
    }
    cod_info->global_gain = vbrmax;

    if (cod_info->global_gain < 0) {
        cod_info->global_gain = 0;
    }
    else if (cod_info->global_gain > 255) {
        cod_info->global_gain = 255;
    }
    for (sfb = 0; sfb < SFBMAX; ++sfb) {
        vbrsf[sfb] -= vbrmax;
    }
    set_subblock_gain(cod_info, &that->mingain_s[0], vbrsf);
    set_scalefacs(cod_info, vbrsfmin, vbrsf, max_range_short);
    assert(checkScalefactor(cod_info, vbrsfmin));
    return checkScalefactor(cod_info, vbrsfmin);
}



/******************************************************************
 *
 *  long block scalefacs
 *
 ******************************************************************/

static int
long_block_constrain(const algo_t * that, int vbrsf[SFBMAX], const int vbrsfmin[SFBMAX], int vbrmax)
{
    gr_info *cod_info = that->cod_info;
    lame_internal_flags *gfc = that->gfc;
    const int *max_rangep;
    int const maxminsfb = that->mingain_l;
    int     sfb;
    int     maxover0, maxover1, maxover0p, maxover1p, mover, delta = 0;
    int     v, v0, v1, v0p, v1p, vm0p = 1, vm1p = 1;
    int     psymax = cod_info->psymax;

    max_rangep = gfc->mode_gr == 2 ? max_range_long : max_range_long_lsf_pretab;

    maxover0 = 0;
    maxover1 = 0;
    maxover0p = 0;      /* pretab */
    maxover1p = 0;      /* pretab */

    for (sfb = 0; sfb < psymax; ++sfb) {
        assert( vbrsf[sfb] >= vbrsfmin[sfb] );
        v = vbrmax - vbrsf[sfb];
        if (delta < v) {
            delta = v;
        }
        v0 = v - 2 * max_range_long[sfb];
        v1 = v - 4 * max_range_long[sfb];
        v0p = v - 2 * (max_rangep[sfb] + pretab[sfb]);
        v1p = v - 4 * (max_rangep[sfb] + pretab[sfb]);
        if (maxover0 < v0) {
            maxover0 = v0;
        }
        if (maxover1 < v1) {
            maxover1 = v1;
        }
        if (maxover0p < v0p) {
            maxover0p = v0p;
        }
        if (maxover1p < v1p) {
            maxover1p = v1p;
        }
    }
    if (vm0p == 1) {
        int     gain = vbrmax - maxover0p;
        if (gain < maxminsfb) {
            gain = maxminsfb;
        }
        for (sfb = 0; sfb < psymax; ++sfb) {
            int     a = (gain - vbrsfmin[sfb]) - 2 * pretab[sfb];
            if (a <= 0) {
                vm0p = 0;
                vm1p = 0;
                break;
            }
        }
    }
    if (vm1p == 1) {
        int     gain = vbrmax - maxover1p;
        if (gain < maxminsfb) {
            gain = maxminsfb;
        }
        for (sfb = 0; sfb < psymax; ++sfb) {
            int     b = (gain - vbrsfmin[sfb]) - 4 * pretab[sfb];
            if (b <= 0) {
                vm1p = 0;
                break;
            }
        }
    }
    if (vm0p == 0) {
        maxover0p = maxover0;
    }
    if (vm1p == 0) {
        maxover1p = maxover1;
    }
    if (gfc->noise_shaping != 2) {
        maxover1 = maxover0;
        maxover1p = maxover0p;
    }
    mover = Min(maxover0, maxover0p);
    mover = Min(mover, maxover1);
    mover = Min(mover, maxover1p);

    if (delta > mover) {
        delta = mover;
    }
    vbrmax -= delta;
    if (vbrmax < maxminsfb) {
        vbrmax = maxminsfb;
    }
    maxover0 -= mover;
    maxover0p -= mover;
    maxover1 -= mover;
    maxover1p -= mover;

    if (maxover0 == 0) {
        cod_info->scalefac_scale = 0;
        cod_info->preflag = 0;
        max_rangep = max_range_long;
    }
    else if (maxover0p == 0) {
        cod_info->scalefac_scale = 0;
        cod_info->preflag = 1;
    }
    else if (maxover1 == 0) {
        cod_info->scalefac_scale = 1;
        cod_info->preflag = 0;
        max_rangep = max_range_long;
    }
    else if (maxover1p == 0) {
        cod_info->scalefac_scale = 1;
        cod_info->preflag = 1;
    }
    else {
        assert(0);      /* this should not happen */
    }
    cod_info->global_gain = vbrmax;
    if (cod_info->global_gain < 0) {
        cod_info->global_gain = 0;
    }
    else if (cod_info->global_gain > 255) {
        cod_info->global_gain = 255;
    }
    for (sfb = 0; sfb < SFBMAX; ++sfb) {
        vbrsf[sfb] -= vbrmax;
    }
    set_scalefacs(cod_info, vbrsfmin, vbrsf, max_rangep);
    assert(checkScalefactor(cod_info, vbrsfmin));
    return checkScalefactor(cod_info, vbrsfmin);
}



static int
bitcount(const algo_t * that)
{
    if (that->gfc->mode_gr == 2) {
        return scale_bitcount(that->cod_info);
    }
    else {
        return scale_bitcount_lsf(that->gfc, that->cod_info);
    }
}



static int
quantizeAndCountBits(const algo_t * that)
{
    that->quantize(that);
    that->cod_info->part2_3_length = noquant_count_bits(that->gfc, that->cod_info, 0);
    return that->cod_info->part2_3_length;
}



static int
tryScalefacColor(const algo_t * that, int vbrsf[SFBMAX],
                 const int vbrsf2[SFBMAX], const int vbrsfmin[SFBMAX], int I, int M, int target)
{
    FLOAT   xrpow_max = that->cod_info->xrpow_max;
    int     i, nbits;
    int     gain, vbrmax = 0;

    for (i = 0; i < SFBMAX; ++i) {
        gain = target + (vbrsf2[i] - target) * I / M;
        if (gain < vbrsfmin[i]) {
            gain = vbrsfmin[i];
        }
        if (gain > 255) {
            gain = 255;
        }
        if (vbrmax < gain) {
            vbrmax = gain;
        }
        vbrsf[i] = gain;
    }
    if (!that->alloc(that, vbrsf, vbrsfmin, vbrmax)) {
        return LARGE_BITS;
    }
    bitcount(that);
    nbits = quantizeAndCountBits(that);
    that->cod_info->xrpow_max = xrpow_max;
    return nbits;
}



static void
searchScalefacColorMax(const algo_t * that, int sfwork[SFBMAX],
                       const int sfcalc[SFBMAX], const int vbrsfmin[SFBMAX], int bits)
{
    int const psymax = that->cod_info->psymax;
    int     nbits, last, i, ok = -1, l = 0, r, vbrmin = 255, vbrmax = 0, M, target;
    for (i = 0; i < psymax; ++i) {
        if (vbrmin > sfcalc[i]) {
            vbrmin = sfcalc[i];
        }
        if (vbrmax < sfcalc[i]) {
            vbrmax = sfcalc[i];
        }
    }
    M = vbrmax - vbrmin;

    if (M == 0) {
        return;
    }
    target = vbrmax;
    for (l = 0, r = M, last = i = M / 2; l <= r; i = (l + r) / 2) {
        nbits = tryScalefacColor(that, sfwork, sfcalc, vbrsfmin, i, M, target);
        if (nbits < bits) {
            ok = i;
            l = i + 1;
        }
        else {
            r = i - 1;
        }
        last = i;
    }
    if (last != ok) {
        if (ok == -1) {
            ok = 0;
        }
        nbits = tryScalefacColor(that, sfwork, sfcalc, vbrsfmin, ok, M, target);
    }
}


#if 0
static void
searchScalefacColorMin(const algo_t * that, int sfwork[SFBMAX],
                       const int sfcalc[SFBMAX], const int vbrsfmin[SFBMAX], int bits)
{
    int const psymax = that->cod_info->psymax;
    int     nbits, last, i, ok = -1, l = 0, r, vbrmin = 255, vbrmax = 0, M, target;
    for (i = 0; i < psymax; ++i) {
        if (vbrmin > sfcalc[i]) {
            vbrmin = sfcalc[i];
        }
        if (vbrmax < sfcalc[i]) {
            vbrmax = sfcalc[i];
        }
    }
    M = vbrmax - vbrmin;

    if (M == 0) {
        return;
    }
    target = vbrmin;
    for (l = 0, r = M, last = i = M / 2; l <= r; i = (l + r) / 2) {
        nbits = tryScalefacColor(that, sfwork, sfcalc, vbrsfmin, i, M, target);
        if (nbits > bits) {
            ok = i;
            r = i - 1;
        }
        else {
            l = i + 1;
        }
        last = i;
    }
    if (last != ok) {
        if (ok == -1) {
            ok = 0;
        }
        nbits = tryScalefacColor(that, sfwork, sfcalc, vbrsfmin, ok, M, target);
    }
}
#endif


static int
tryGlobalStepsize(const algo_t * that, const int sfwork[SFBMAX],
                  const int vbrsfmin[SFBMAX], int delta)
{
    FLOAT   xrpow_max = that->cod_info->xrpow_max;
    int     sftemp[SFBMAX], i, nbits;
    int     gain, vbrmax = 0;
    for (i = 0; i < SFBMAX; ++i) {
        gain = sfwork[i] + delta;
        if (gain < vbrsfmin[i]) {
            gain = vbrsfmin[i];
        }
        if (gain > 255) {
            gain = 255;
        }
        if (vbrmax < gain) {
            vbrmax = gain;
        }
        sftemp[i] = gain;
    }
    if (!that->alloc(that, sftemp, vbrsfmin, vbrmax)) {
        return LARGE_BITS;
    }
    bitcount(that);
    nbits = quantizeAndCountBits(that);
    that->cod_info->xrpow_max = xrpow_max;
    return nbits;
}



static void
searchGlobalStepsizeMax(const algo_t * that, const int sfwork[SFBMAX],
                        const int vbrsfmin[SFBMAX], int target)
{
    gr_info *cod_info = that->cod_info;
    const int gain = cod_info->global_gain;
    int     curr = gain;
    int     gain_ok = 1024;
    int     nbits = LARGE_BITS;
    int     l = gain, r = 512;

    assert(gain >= 0);
    while (l <= r) {
        curr = (l + r) >> 1;
        nbits = tryGlobalStepsize(that, sfwork, vbrsfmin, curr - gain);
        if (cod_info->part2_length >= LARGE_BITS || nbits >= LARGE_BITS) {
            l = curr + 1;
            continue;
        }
        if (nbits + cod_info->part2_length < target) {
            r = curr - 1;
            gain_ok = curr;
        }
        else {
            l = curr + 1;
            if (gain_ok == 1024) {
                gain_ok = curr;
            }
        }
    }
    if (gain_ok != curr) {
        curr = gain_ok;
        nbits = tryGlobalStepsize(that, sfwork, vbrsfmin, curr - gain);
    }
}

#if 0
static void
searchGlobalStepsizeMin(const algo_t * that, const int sfwork[SFBMAX],
                        const int vbrsfmin[SFBMAX], int target)
{
    gr_info *cod_info = that->cod_info;
    const int gain = cod_info->global_gain;
    int     curr = gain;
    int     gain_ok = 1024;
    int     nbits = LARGE_BITS;
    int     l = 0, r = gain;

    assert(gain >= 0);
    while (l <= r) {
        curr = (l + r) >> 1;
        nbits = tryGlobalStepsize(that, sfwork, vbrsfmin, curr - gain);
        if (cod_info->part2_length >= LARGE_BITS || nbits >= LARGE_BITS) {
            l = curr + 1;
            continue;
        }
        if (nbits + cod_info->part2_length < target) {
            l = curr + 1;
            if (gain_ok == 1024) {
                gain_ok = curr;
            }
        }
        else {
            r = curr - 1;
            gain_ok = curr;
        }
    }
    if (gain_ok != curr) {
        curr = gain_ok;
        nbits = tryGlobalStepsize(that, sfwork, vbrsfmin, curr - gain);
    }
}
#endif


/************************************************************************
 *
 *  VBR_noise_shaping()
 *
 *  may result in a need of too many bits, then do it CBR like
 *
 *  Robert Hegemann 2000-10-25
 *
 ***********************************************************************/

int
VBR_noise_shaping(lame_internal_flags * gfc, const FLOAT xr34orig[576],
                  const FLOAT l3_xmin[576], int maxbits, int gr, int ch)
{
    int     sfwork[SFBMAX];
    int     sfcalc[SFBMAX];
    int     vbrsfmin[SFBMAX];
    algo_t  that;
    int     vbrmax;
    gr_info *cod_info = &gfc->l3_side.tt[gr][ch];

    that.xr34orig = xr34orig;
    if (gfc->quantization) {
        that.find = find_scalefac_x34;
        that.quantize = quantize_x34;
    }
    else {
        that.find = find_scalefac_ISO;
        that.quantize = quantize_ISO;
    }
    if (cod_info->block_type == SHORT_TYPE) {
        that.alloc = short_block_constrain;
    }
    else {
        that.alloc = long_block_constrain;
    }
    that.gfc = gfc;
    that.cod_info = &gfc->l3_side.tt[gr][ch];

    memset(cod_info->l3_enc, 0, 576 * sizeof(int));

    vbrmax = block_sf(&that, l3_xmin, sfcalc, vbrsfmin);
    memcpy(sfwork, sfcalc, SFBMAX * sizeof(int));
    that.alloc(&that, sfwork, vbrsfmin, vbrmax);
    if (0 != bitcount(&that)) {
        /*  this should not happen due to the way the scalefactors are selected
         */
        cod_info->part2_3_length = LARGE_BITS;
        return -1;
    }
    quantizeAndCountBits(&that);
    if (cod_info->part2_3_length > maxbits - cod_info->part2_length) {
        searchScalefacColorMax(&that, sfwork, sfcalc, vbrsfmin, maxbits);
    }
    if (cod_info->part2_3_length > maxbits - cod_info->part2_length) {
        searchGlobalStepsizeMax(&that, sfwork, vbrsfmin, maxbits);
    }
    if (gfc->use_best_huffman == 2) {
        best_huffman_divide(gfc, cod_info);
    }
    assert(cod_info->global_gain < 256u);

    if (cod_info->part2_3_length + cod_info->part2_length >= LARGE_BITS) {
        cod_info->part2_3_length = LARGE_BITS;
        return -2;      /* Houston, we have a problem */
    }
    return 0;
}
