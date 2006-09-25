/*
 * presets.c -- Apply presets
 *
 *	Copyright (c) 2002-2005 Gabriel Bouvigne
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307, USA.
 */

#include "set_get.h"

#ifdef HAVE_CONFIG_H
# include <config.h>
#endif
#include "util.h"


#define SET_OPTION(opt, val, def) if (enforce) \
    lame_set_##opt(gfp, val); \
    else if (lame_get_##opt(gfp) == def) \
    lame_set_##opt(gfp, val);



int apply_abr_preset(lame_global_flags*  gfp, int preset, int enforce)
{
    int k; 

    typedef struct {
        int    abr_kbps;
        int    quant_comp;
        int    quant_comp_s;
        int    safejoint;
        FLOAT  nsmsfix;
        FLOAT  st_lrm; /*short threshold*/
        FLOAT  st_s;
        FLOAT  nsbass;
        FLOAT  scale;
        FLOAT  masking_adj;
        FLOAT  ath_lower;
        FLOAT  ath_curve;
        FLOAT  interch;
        int sfscale;
    } abr_presets_t;



    /* Switch mappings for ABR mode */
    const abr_presets_t abr_switch_map [] = {
        /* kbps  quant q_s safejoint nsmsfix st_lrm  st_s  ns-bass scale   msk ath_lwr ath_curve  interch , sfscale */
        {   8,   9,    9,  0,        0   ,    6.60, 145  ,  0,      0.95,    0, -30.0,        11,  0.0012 ,       1}, /*   8, impossible to use in stereo */
        {  16,   9,    9,  0,        0   ,    6.60, 145  ,  0,      0.95,    0, -25.0,        11,  0.0010 ,       1}, /*  16 */
        {  24,   9,    9,  0,        0   ,    6.60, 145  ,  0,      0.95,    0, -20.0,        11,  0.0010 ,       1}, /*  24 */
        {  32,   9,    9,  0,        0   ,    6.60, 145  ,  0,      0.95,    0, -15.0,        11,  0.0010 ,       1}, /*  32 */
        {  40,   9,    9,  0,        0   ,    6.60, 145  ,  0,      0.95,    0, -10.0,        11,  0.0009 ,       1}, /*  40 */
        {  48,   9,    9,  0,        0   ,    6.60, 145  ,  0,      0.95,    0, -10.0,        11,  0.0009 ,       1}, /*  48 */
        {  56,   9,    9,  0,        0   ,    6.60, 145  ,  0,      0.95,    0,  -6.0,        11,  0.0008 ,       1}, /*  56 */
        {  64,   9,    9,  0,        0   ,    6.60, 145  ,  0,      0.95,    0,  -2.0,        11,  0.0008 ,       1}, /*  64 */
        {  80,   9,    9,  0,        0   ,    6.60, 145  ,  0,      0.95,    0,    .0,         8,  0.0007 ,       1}, /*  80 */
        {  96,   9,    9,  0,        2.50,    6.60, 145  ,  0,      0.95,    0,   1.0,       5.5,  0.0006 ,       1}, /*  96 */
        { 112,   9,    9,  0,        2.25,    6.60, 145  ,  0,      0.95,    0,   2.0,       4.5,  0.0005 ,       1}, /* 112 */
        { 128,   9,    9,  0,        1.95,    6.40, 140  ,  0,      0.95,    0,   3.0,         4,  0.0002 ,       1}, /* 128 */
        { 160,   9,    9,  1,        1.79,    6.00, 135  ,  0,      0.95,   -2,   5.0,       3.5,  0      ,       1}, /* 160 */
        { 192,   9,    9,  1,        1.49,    5.60, 125  ,  0,      0.97,   -4,   7.0,         3,  0      ,       0}, /* 192 */
        { 224,   9,    9,  1,        1.25,    5.20, 125  ,  0,      0.98,   -6,   9.0,         2,  0      ,       0}, /* 224 */
        { 256,   9,    9,  1,        0.97,    5.20, 125  ,  0,      1.00,   -8,  10.0,         1,  0      ,       0}, /* 256 */
        { 320,   9,    9,  1,        0.90,    5.20, 125  ,  0,      1.00,  -10,  12.0,         0,  0      ,       0}  /* 320 */
                                       };

    
    /* Variables for the ABR stuff */
    int r;
    int actual_bitrate = preset;

    r= nearestBitrateFullIndex(preset);


    lame_set_VBR(gfp, vbr_abr); 
    lame_set_VBR_mean_bitrate_kbps(gfp, (actual_bitrate));
    lame_set_VBR_mean_bitrate_kbps(gfp, Min(lame_get_VBR_mean_bitrate_kbps(gfp), 320)); 
    lame_set_VBR_mean_bitrate_kbps(gfp, Max(lame_get_VBR_mean_bitrate_kbps(gfp), 8)); 
    lame_set_brate(gfp, lame_get_VBR_mean_bitrate_kbps(gfp));


    SET_OPTION(psy_model, PSY_NSPSYTUNE, -1);


    /* parameters for which there is no proper set/get interface */
    if (abr_switch_map[r].safejoint > 0)
        lame_set_exp_nspsytune(gfp, lame_get_exp_nspsytune(gfp) | 2); /* safejoint */

    if (abr_switch_map[r].sfscale > 0)
        lame_set_sfscale(gfp, 1);

    /* ns-bass tweaks */
    if (abr_switch_map[r].nsbass != 0) {
        k = (int)(abr_switch_map[r].nsbass * 4);
        if (k < 0) k += 64;
        lame_set_exp_nspsytune(gfp, lame_get_exp_nspsytune(gfp) | (k << 2));
    }




    SET_OPTION(quant_comp, abr_switch_map[r].quant_comp, -1);
    SET_OPTION(quant_comp_short, abr_switch_map[r].quant_comp_s, -1);

    SET_OPTION(msfix, abr_switch_map[r].nsmsfix, -1);

    SET_OPTION(short_threshold_lrm, abr_switch_map[r].st_lrm, -1);
    SET_OPTION(short_threshold_s, abr_switch_map[r].st_s, -1);

    /* ABR seems to have big problems with clipping, especially at low bitrates */
    /* so we compensate for that here by using a scale value depending on bitrate */
    SET_OPTION(scale, abr_switch_map[r].scale, -1);

    SET_OPTION(maskingadjust, abr_switch_map[r].masking_adj , 0);
    if (abr_switch_map[r].masking_adj > 0) {
        SET_OPTION(maskingadjust_short, abr_switch_map[r].masking_adj * .9 , 0);
    } else {
        SET_OPTION(maskingadjust_short, abr_switch_map[r].masking_adj * 1.1 , 0);
    }


    SET_OPTION(ATHlower, abr_switch_map[r].ath_lower, 0);
    SET_OPTION(ATHcurve, abr_switch_map[r].ath_curve, -1);

    SET_OPTION(interChRatio, abr_switch_map[r].interch, -1);


    return preset;
}





int apply_preset(lame_global_flags*  gfp, int preset, int enforce)
{
    /*translate legacy presets*/
    switch (preset) {
    case R3MIX: {
        preset = V3;
        lame_set_VBR(gfp, vbr_mtrh);
        break;
    }
    case MEDIUM: {
        preset = V4;
        lame_set_VBR(gfp, vbr_rh);
        break;
    }
    case MEDIUM_FAST: {
        preset = V4;
        lame_set_VBR(gfp, vbr_mtrh);
        break;
    }
    case STANDARD: {
        preset = V2;
        lame_set_VBR(gfp, vbr_rh);
        break;
    }
    case STANDARD_FAST: {
        preset = V2;
        lame_set_VBR(gfp, vbr_mtrh);
        break;
    }
    case EXTREME: {
        preset = V0;
        lame_set_VBR(gfp, vbr_rh);
        break;
    }
    case EXTREME_FAST: {
        preset = V0;
        lame_set_VBR(gfp, vbr_mtrh);
        break;
    }
    case INSANE: {
        preset = 320;
        break;
    }
    }
    
    
    gfp->preset = preset;

    switch (preset) {
    case V9: {
        lame_set_VBR_q(gfp, 9);
        switch (lame_get_VBR(gfp)) {
        case vbr_rh: {
            SET_OPTION(short_threshold_lrm, 6.60f, -1);
            SET_OPTION(short_threshold_s, 145.0f, -1);
            SET_OPTION(quant_comp, 9, -1);
            SET_OPTION(quant_comp_short, 9, -1);
            SET_OPTION(psy_model, PSY_NSPSYTUNE, -1);
            SET_OPTION(maskingadjust, 1.6, 0);
            SET_OPTION(maskingadjust_short, 1.6, 0);
            SET_OPTION(interChRatio, 0.0008, -1);
            SET_OPTION(ATHlower, -36, 0);
            SET_OPTION(ATHcurve, 11, -1);
            SET_OPTION(athaa_sensitivity, -25, 0);

            lame_set_experimentalY(gfp, 1);

            return preset;
        }
        default: {
            SET_OPTION(short_threshold_lrm, 6.60f, -1);
            SET_OPTION(short_threshold_s, 145.0f, -1);
            SET_OPTION(quant_comp, 0, -1);
            SET_OPTION(quant_comp_short, 0, -1);
            SET_OPTION(psy_model, PSY_NSPSYTUNE, -1);
            SET_OPTION(maskingadjust, 1.75, 0);
            SET_OPTION(maskingadjust_short, 1.75, 0);
            SET_OPTION(interChRatio, 0.0008, -1);
            SET_OPTION(ATHlower, -39.5, 0);
            SET_OPTION(ATHcurve, 11, -1);
            SET_OPTION(athaa_sensitivity, -25, 0);

            lame_set_experimentalY(gfp, 1);

            return preset;
        }
        }
    }
    case V8: {
        lame_set_VBR_q(gfp, 8);
        switch (lame_get_VBR(gfp)) {
        case vbr_rh: {
            SET_OPTION(short_threshold_lrm, 6.60f, -1);
            SET_OPTION(short_threshold_s, 145.0f, -1);
            SET_OPTION(quant_comp, 9, -1);
            SET_OPTION(quant_comp_short, 9, -1);
            SET_OPTION(psy_model, PSY_NSPSYTUNE, -1);
            SET_OPTION(maskingadjust, 1.2, 0);
            SET_OPTION(maskingadjust_short, 1.15, 0);
            SET_OPTION(interChRatio, 0.0007, -1);
            SET_OPTION(ATHlower, -27.5, 0);
            SET_OPTION(ATHcurve, 10, -1);
            SET_OPTION(athaa_sensitivity, -23, 0);

            lame_set_experimentalY(gfp, 1);

            return preset;
        }
        default: {
            SET_OPTION(short_threshold_lrm, 6.60f, -1);
            SET_OPTION(short_threshold_s, 145.0f, -1);
            SET_OPTION(quant_comp, 0, -1);
            SET_OPTION(quant_comp_short, 0, -1);
            SET_OPTION(psy_model, PSY_NSPSYTUNE, -1);
            SET_OPTION(maskingadjust, 1.2, 0);
            SET_OPTION(maskingadjust_short, 1.15, 0);
            SET_OPTION(interChRatio, 0.0007, -1);
            SET_OPTION(ATHlower, -30, 0);
            SET_OPTION(ATHcurve, 10, -1);
            SET_OPTION(athaa_sensitivity, -23, 0);

            lame_set_experimentalY(gfp, 1);

            return preset;
        }
        }
    }
    case V7: {
        lame_set_VBR_q(gfp, 7);
        switch (lame_get_VBR(gfp)) {
        case vbr_rh: {
            SET_OPTION(short_threshold_lrm, 6.60f, -1);
            SET_OPTION(short_threshold_s, 145.0f, -1);
            SET_OPTION(quant_comp, 9, -1);
            SET_OPTION(quant_comp_short, 9, -1);
            SET_OPTION(psy_model, PSY_NSPSYTUNE, -1);
            SET_OPTION(msfix, 2.70, -1);
            SET_OPTION(maskingadjust, .8, 0);
            SET_OPTION(maskingadjust_short, .75, 0);
            SET_OPTION(interChRatio, 0.0006, -1);
            SET_OPTION(ATHlower, -19.7, 0);
            SET_OPTION(ATHcurve, 8, -1);
            SET_OPTION(athaa_sensitivity, -22, 0);

            lame_set_experimentalY(gfp, 1);

            return preset;
        }
        default: {
            SET_OPTION(short_threshold_lrm, 6.60f, -1);
            SET_OPTION(short_threshold_s, 145.0f, -1);
            SET_OPTION(quant_comp, 0, -1);
            SET_OPTION(quant_comp_short, 0, -1);
            SET_OPTION(psy_model, PSY_NSPSYTUNE, -1);
            SET_OPTION(msfix, 2.70, -1);
            SET_OPTION(maskingadjust, 0.8, 0);
            SET_OPTION(maskingadjust_short, 0.78, 0);
            SET_OPTION(interChRatio, 0.0006, -1);
            SET_OPTION(ATHlower, -22, 0);
            SET_OPTION(ATHcurve, 8, -1);
            SET_OPTION(athaa_sensitivity, -22, 0);

            lame_set_experimentalY(gfp, 1);

            return preset;
        }
        }
    }
    case V6: {
        lame_set_VBR_q(gfp, 6);
        switch (lame_get_VBR(gfp)) {
        case vbr_rh: {
            SET_OPTION(short_threshold_lrm, 6.60f, -1);
            SET_OPTION(short_threshold_s, 145.0f, -1);
            SET_OPTION(quant_comp, 9, -1);
            SET_OPTION(quant_comp_short, 9, -1);
            SET_OPTION(psy_model, PSY_NSPSYTUNE, -1);
            SET_OPTION(msfix, 2.30, -1);
            SET_OPTION(maskingadjust, .67, 0);
            SET_OPTION(maskingadjust_short, .65, 0);
            SET_OPTION(interChRatio, 0.0004, -1);
            SET_OPTION(ATHlower, -14.7, 0);
            SET_OPTION(ATHcurve, 6.5, -1);
            SET_OPTION(athaa_sensitivity, -19, 0);

            lame_set_experimentalY(gfp, 1);

            return preset;
        }
        default: {
            SET_OPTION(short_threshold_lrm, 6.60f, -1);
            SET_OPTION(short_threshold_s, 145.0f, -1);
            SET_OPTION(quant_comp, 0, -1);
            SET_OPTION(quant_comp_short, 0, -1);
            SET_OPTION(psy_model, PSY_NSPSYTUNE, -1);
            SET_OPTION(msfix, 2.30, -1);
            SET_OPTION(maskingadjust, 0.67, 0);
            SET_OPTION(maskingadjust_short, 0.65, 0);
            SET_OPTION(interChRatio, 0.0004, -1);
            SET_OPTION(ATHlower, -14.5, 0);
            SET_OPTION(ATHcurve, 6.5, -1);
            SET_OPTION(athaa_sensitivity, -19, 0);

            lame_set_experimentalY(gfp, 1);

            return preset;
        }
        }
    }
    case V5: {
        lame_set_VBR_q(gfp, 5);
        switch (lame_get_VBR(gfp)) {
            case vbr_rh: {
            SET_OPTION(short_threshold_lrm, 6.40f, -1);
            SET_OPTION(short_threshold_s, 140.0f, -1);
            SET_OPTION(quant_comp, 9, -1);
            SET_OPTION(quant_comp_short, 9, -1);
            SET_OPTION(psy_model, PSY_NSPSYTUNE, -1);
            SET_OPTION(msfix, 1.95, -1);
            SET_OPTION(maskingadjust, .5, 0);
            SET_OPTION(maskingadjust_short, .4, 0);
            SET_OPTION(interChRatio, 0.0002, -1);
            SET_OPTION(ATHlower, -7.5, 0);
            SET_OPTION(ATHcurve, 4, -1);
            SET_OPTION(athaa_sensitivity, -12, 0);

            lame_set_experimentalY(gfp, 1);

            return preset;
        }
        default: {
            SET_OPTION(short_threshold_lrm, 6.40f, -1);
            SET_OPTION(short_threshold_s, 140.0f, -1);
            SET_OPTION(quant_comp, 0, -1);
            SET_OPTION(quant_comp_short, 0, -1);
            SET_OPTION(psy_model, PSY_NSPSYTUNE, -1);
            SET_OPTION(msfix, 1.95, -1);
            SET_OPTION(maskingadjust, 0.45, 0);
            SET_OPTION(maskingadjust_short, 0.35, 0);
            SET_OPTION(interChRatio, 0.0002, -1);
            SET_OPTION(ATHlower, -7.7, 0);
            SET_OPTION(ATHcurve, 4, -1);
            SET_OPTION(athaa_sensitivity, -12, 0);

            lame_set_experimentalY(gfp, 1);

            return preset;
        }
        }
    }
    case V4: { /*MEDIUM*/
        lame_set_VBR_q(gfp, 4);
        switch (lame_get_VBR(gfp)) {
        case vbr_rh: {
            SET_OPTION(short_threshold_lrm, 6.00f, -1);
            SET_OPTION(short_threshold_s, 135.0f, -1);
            SET_OPTION(quant_comp, 9, -1);
            SET_OPTION(quant_comp_short, 9, -1);
            SET_OPTION(psy_model, PSY_NSPSYTUNE, -1);
            lame_set_exp_nspsytune(gfp, lame_get_exp_nspsytune(gfp) | 2); /* safejoint */
            SET_OPTION(msfix, 1.79, -1);
            SET_OPTION(maskingadjust, -.7, 0);
            SET_OPTION(maskingadjust_short, -1.1, 0);
            SET_OPTION(ATHlower, 1.1, 0);
            SET_OPTION(ATHcurve, 3.5, -1);
            SET_OPTION(athaa_sensitivity, -8, 0);

            lame_set_experimentalY(gfp, 1);

            return preset;
        }
        default: {
            SET_OPTION(short_threshold_lrm, 6.00f, -1);
            SET_OPTION(short_threshold_s, 135.0f, -1);
            SET_OPTION(quant_comp, 0, -1);
            SET_OPTION(quant_comp_short, 0, -1);
            SET_OPTION(psy_model, PSY_NSPSYTUNE, -1);
            lame_set_exp_nspsytune(gfp, lame_get_exp_nspsytune(gfp) | 2); /* safejoint */
            SET_OPTION(msfix, 1.79, -1);
            SET_OPTION(maskingadjust, -.7, 0);
            SET_OPTION(maskingadjust_short, -1.1, 0);
            SET_OPTION(ATHlower, 0, 0);
            SET_OPTION(ATHcurve, 3.5, -1);
            SET_OPTION(athaa_sensitivity, -8, 0);

            lame_set_experimentalY(gfp, 1);

            return preset;
        }
        }
    }
    case V3: {
        lame_set_VBR_q(gfp, 3);
        switch (lame_get_VBR(gfp)) {
        case vbr_rh: {
            SET_OPTION(short_threshold_lrm, 5.80f, -1);
            SET_OPTION(short_threshold_s, 130.0f, -1);
            SET_OPTION(quant_comp, 9, -1);
            SET_OPTION(quant_comp_short, 9, -1);
            SET_OPTION(psy_model, PSY_NSPSYTUNE, -1);
            lame_set_exp_nspsytune(gfp, lame_get_exp_nspsytune(gfp) | 2); /* safejoint */
            SET_OPTION(msfix, 1.64, -1);
            SET_OPTION(maskingadjust, -1.8, 0);
            SET_OPTION(maskingadjust_short, -2.8, 0);
            SET_OPTION(ATHlower, 2.6, 0);
            SET_OPTION(ATHcurve, 3, -1);
            SET_OPTION(athaa_sensitivity, -4, 0);

            /* modify sfb21 by 5 dB plus ns-treble=0                  */
            lame_set_exp_nspsytune(gfp, lame_get_exp_nspsytune(gfp) | (20 << 20));
            lame_set_experimentalY(gfp, 1);

            return preset;
        }
        default: {
            SET_OPTION(short_threshold_lrm, 5.80f, -1);
            SET_OPTION(short_threshold_s, 130.0f, -1);
            SET_OPTION(quant_comp, 0, -1);
            SET_OPTION(quant_comp_short, 0, -1);
            SET_OPTION(psy_model, PSY_NSPSYTUNE, -1);
            lame_set_exp_nspsytune(gfp, lame_get_exp_nspsytune(gfp) | 2); /* safejoint */
            SET_OPTION(msfix, 1.64, -1);
            SET_OPTION(maskingadjust, -1.45, 0);
            SET_OPTION(maskingadjust_short, -2.45, 0);
            SET_OPTION(ATHlower, 1.1, 0);
            SET_OPTION(ATHcurve, 3, -1);
            SET_OPTION(athaa_sensitivity, -4, 0);

            /* modify sfb21 by 3.75 dB plus ns-treble=0                  */
            lame_set_exp_nspsytune(gfp, lame_get_exp_nspsytune(gfp) | (15 << 20));
            lame_set_experimentalY(gfp, 1);

            return preset;
        }
        }
    }
    case V2: { /*STANDARD*/
        lame_set_VBR_q(gfp, 2);
        switch (lame_get_VBR(gfp)) {
        case vbr_rh: {
            SET_OPTION(short_threshold_lrm, 5.6f, -1);
            SET_OPTION(short_threshold_s, 125.0f, -1);
            SET_OPTION(quant_comp, 9, -1);
            SET_OPTION(quant_comp_short, 9, -1);
            SET_OPTION(psy_model, PSY_NSPSYTUNE, -1);
            lame_set_exp_nspsytune(gfp, lame_get_exp_nspsytune(gfp) | 2); /* safejoint */
            SET_OPTION(msfix, 1.49, -1);
            SET_OPTION(maskingadjust, -2.2, 0);
            SET_OPTION(maskingadjust_short, -3.5, 0);
            SET_OPTION(ATHlower, 2.8, 0);
            SET_OPTION(ATHcurve, 2, -1);
            /* modify sfb21 by 5.25 dB plus ns-treble=0                  */
            lame_set_exp_nspsytune(gfp, lame_get_exp_nspsytune(gfp) | (21 << 20));
 
            return preset;
        }
        default: {
            SET_OPTION(short_threshold_lrm, 5.6f, -1);
            SET_OPTION(short_threshold_s, 125.0f, -1);
            SET_OPTION(quant_comp, 0, -1);
            SET_OPTION(quant_comp_short, 0, -1);
            SET_OPTION(psy_model, PSY_NSPSYTUNE, -1);
            lame_set_exp_nspsytune(gfp, lame_get_exp_nspsytune(gfp) | 2); /* safejoint */
            SET_OPTION(msfix, 1.49, -1);
            SET_OPTION(maskingadjust, -1.7, 0);
            SET_OPTION(maskingadjust_short, -3.2, 0);
            SET_OPTION(ATHlower, 2, 0);
            SET_OPTION(ATHcurve, 2, -1);
            /* modify sfb21 by 4.5 dB plus ns-treble=0                  */
            lame_set_exp_nspsytune(gfp, lame_get_exp_nspsytune(gfp) | (18 << 20));

            return preset;
        }
        }
    }
    case V1: {
        lame_set_VBR_q(gfp, 1);
        switch (lame_get_VBR(gfp)) {
        case vbr_rh: {
            SET_OPTION(short_threshold_lrm, 5.3f, -1);
            SET_OPTION(short_threshold_s, 125.0f, -1);
            SET_OPTION(quant_comp, 9, -1);
            SET_OPTION(quant_comp_short, 9, -1);
            SET_OPTION(psy_model, PSY_NSPSYTUNE, -1);
            lame_set_exp_nspsytune(gfp, lame_get_exp_nspsytune(gfp) | 2); /* safejoint */
            SET_OPTION(msfix, 1.35, -1);
            SET_OPTION(maskingadjust, -3.6, 0);
            SET_OPTION(maskingadjust_short, -5.6, 0);
            SET_OPTION(ATHlower, 4.5, 0);
            SET_OPTION(ATHcurve, 1.5, -1);
            /* modify sfb21 by 5.25 dB plus ns-treble=0                  */
            lame_set_exp_nspsytune(gfp, lame_get_exp_nspsytune(gfp) | (21 << 20));

            return preset;
        }
        default: {
            SET_OPTION(short_threshold_lrm, 5.3f, -1);
            SET_OPTION(short_threshold_s, 125.0f, -1);
            SET_OPTION(quant_comp, 0, -1);
            SET_OPTION(quant_comp_short, 0, -1);
            SET_OPTION(psy_model, PSY_NSPSYTUNE, -1);
            lame_set_exp_nspsytune(gfp, lame_get_exp_nspsytune(gfp) | 2); /* safejoint */
            SET_OPTION(msfix, 1.35, -1);
            SET_OPTION(maskingadjust, -3.4, 0);
            SET_OPTION(maskingadjust_short, -5.4, 0);
            SET_OPTION(ATHlower, 4.5, 0);
            SET_OPTION(ATHcurve, 1.5, -1);
            /* modify sfb21 by 5.25 dB plus ns-treble=0                  */
            lame_set_exp_nspsytune(gfp, lame_get_exp_nspsytune(gfp) | (21 << 20));

            return preset;
        }
        }
    }
    case V0: { /*EXTREME*/
        lame_set_VBR_q(gfp, 0);
        switch (lame_get_VBR(gfp)) {
        case vbr_rh: {
            SET_OPTION(short_threshold_lrm, 5.2f, -1);
            SET_OPTION(short_threshold_s, 125.0f, -1);
            SET_OPTION(quant_comp, 9, -1);
            SET_OPTION(quant_comp_short, 9, -1);
            SET_OPTION(psy_model, PSY_NSPSYTUNE, -1);
            lame_set_exp_nspsytune(gfp, lame_get_exp_nspsytune(gfp) | 2); /* safejoint */
            SET_OPTION(msfix, .97, -1);
            SET_OPTION(maskingadjust, -4.2, 0);
            SET_OPTION(maskingadjust_short, -6.3, 0);
            SET_OPTION(ATHlower, 4.8, 0);
            SET_OPTION(ATHcurve, 1, -1);
            /* modify sfb21 by 5 dB plus ns-treble=0                  */
            lame_set_exp_nspsytune(gfp, lame_get_exp_nspsytune(gfp) | (21 << 20));

            return preset;
        }
        default: {
            SET_OPTION(short_threshold_lrm, 5.2f, -1);
            SET_OPTION(short_threshold_s, 125.0f, -1);
            SET_OPTION(quant_comp, 0, -1);
            SET_OPTION(quant_comp_short, 0, -1);
            SET_OPTION(psy_model, PSY_NSPSYTUNE, -1);
            lame_set_exp_nspsytune(gfp, lame_get_exp_nspsytune(gfp) | 2); /* safejoint */
            SET_OPTION(msfix, .97, -1);
            SET_OPTION(maskingadjust, -3.6, 0);
            SET_OPTION(maskingadjust_short, -5.6, 0);
            SET_OPTION(ATHlower, 7.5, 0);
            SET_OPTION(ATHcurve, 1, -1);
            /* modify sfb21 by 6.5 dB plus ns-treble=0                  */
            lame_set_exp_nspsytune(gfp, lame_get_exp_nspsytune(gfp) | (26 << 20));

            return preset;
        }
        }
    }
    default:
	break;
    }

    if ((preset >= 8) && (preset <=320))
        return apply_abr_preset(gfp, preset, enforce);


    gfp->preset = 0; /*no corresponding preset found*/
    return preset;
}

