/* ------------------------------------------------------------------

   libofa -- the Open Fingerprint Architecture library

   Copyright (C) 2006 MusicIP Corporation
   All rights reserved.

-------------------------------------------------------------------*/
// FILE: "fftlibvdsp_op.cpp"
// MODULE: Wrapper for Mac vDSP library calls
// AUTHOR: Frode Holm
// DATE CREATED: 1/12/06

#include "../config.h"
#include "fftlib_op.h"


void 
FFTLib_op::Initialize(int N, bool optimize)
{
        Exp = (int) log2(N);
	if (Init)
	{
		delete[] A.realp;
		delete[] A.imagp;
		destroy_fftsetupD(SetupReal);
	}
		
	A.realp = new double[ N/2];
	A.imagp = new double[ N/2];
	SetupReal = create_fftsetupD(Exp, 0);
	Init = true;
}

void
FFTLib_op::Destroy()
{
}

void
FFTLib_op::SetSize(int N, bool optimize, double *in, double *out)
{
	Initialize(N, optimize);
}

void 
FFTLib_op::ComputeFrame(int N, double *in, double *out)
{
	ctozD ((DSPDoubleComplex*) in, 2, &A, 1, N/2 );
	
	fft_zripD(SetupReal, &A, 1, Exp, FFT_FORWARD);
	
	int i,j;
	for (i=0; i<N/2; i++)
		out[i] = A.realp[i]*0.5;
	out[N/2] = A.imagp[0]*0.5;
	for (i=1, j=N-1; i<N/2; i++, j--)
		out[j] = A.imagp[i]*0.5;

}

