/* ------------------------------------------------------------------

   libofa -- the Open Fingerprint Architecture library

   Copyright (C) 2006 MusicIP Corporation
   All rights reserved.

-------------------------------------------------------------------*/
// FILE: "fftlibw3_op.cpp"
// MODULE: Wrapper for MIT FFTW ver 3.0 library calls
// AUTHOR: Frode Holm
// DATE CREATED: 1/12/06

#ifdef WIN32
#include "../config_win32.h"
#else
#include "../config.h"
#endif
#include "fftlib_op.h"


void 
FFTLib_op::Initialize(int N, bool optimize)
{
	if (optimize)
		Flags = FFTW_MEASURE;
	else
		Flags = FFTW_ESTIMATE;

}

void
FFTLib_op::Destroy()
{
    fftw_destroy_plan(PlanF);
}

void
FFTLib_op::SetSize(int N, bool optimize, double *in, double *out)
{
	if (optimize)
		Flags = FFTW_MEASURE;
	else
		Flags = FFTW_ESTIMATE;

	if (PlanF != 0)
	{
		fftw_destroy_plan(PlanF);
		PlanF = 0;
	}

	PlanF = fftw_plan_r2r_1d(N, in, out, FFTW_R2HC, Flags);
}

void 
FFTLib_op::ComputeFrame(int N, double *in, double *out)
{
	fftw_execute(PlanF);
}

