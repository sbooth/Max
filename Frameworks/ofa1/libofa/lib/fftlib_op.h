/* ------------------------------------------------------------------

   libofa -- the Open Fingerprint Architecture library

   Copyright (C) 2006 MusicIP Corporation
   All rights reserved.

-------------------------------------------------------------------*/
// FILE: "fftlib_op.h"
// MODULE: Generic wrapper class for external FFT library calls
// AUTHOR: Frode Holm
// DATE CREATED: 1/12/06


#ifndef __FFTLIB_OP_H
#define __FFTLIB_OP_H 1


#ifdef FFTW
#include "rfftw.h"

class FFTLib_op {
protected:
	FFTLib_op() { PlanF = 0; }
	void Initialize(int N, bool optimize);
	void Destroy();
	void SetSize(int N, bool optimize, double *in, double *out);
	void ComputeFrame(int N, double *in, double *out);

	rfftw_plan PlanF;	// Forward plan: real to complex (time to frequency)
};
#endif

#ifdef FFTW3
#include "fftw3.h"

class FFTLib_op {
protected:
	FFTLib_op() { PlanF = 0; }
	void Initialize(int N, bool optimize);
	void Destroy();
	void SetSize(int N, bool optimize, double *in, double *out);
	void ComputeFrame(int N, double *in, double *out);

	unsigned Flags;

	fftw_plan PlanF;	// Forward plan: real to complex (time to frequency)
};
#endif


#ifdef MKL

class FFTLib_op {
protected:
	FFTLib_op() { WSave = 0; }
	void Initialize(int N, bool optimize);
	void Destroy();
	void SetSize(int N, bool optimize, double *in, double *out);
	void ComputeFrame(int N, double *in, double *out);

	double* WSave;
};
#endif

#ifdef VDSP
#include <Accelerate/Accelerate.h>

class FFTLib_op {
protected:
	FFTLib_op() { Init = false; }
	void Initialize(int N, bool optimize);
	void Destroy();
	void SetSize(int N, bool optimize, double *in, double *out);
	void ComputeFrame(int N, double *in, double *out);
private:
	FFTSetupD SetupReal;
	DSPDoubleSplitComplex A;
	int Exp;
	bool Init;
};
#endif


#endif

