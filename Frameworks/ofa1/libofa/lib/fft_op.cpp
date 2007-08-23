/* ------------------------------------------------------------------

   libofa -- the Open Fingerprint Architecture library

   Copyright (C) 2006 MusicIP Corporation
   All rights reserved.

-------------------------------------------------------------------*/
// FILE: "fft_op.cpp"
// MODULE: Implementation for class FFT_op
// AUTHOR: Frode Holm
// DATE CREATED: 1/12/06

#include <vector>
#include <math.h>
#include "ofa1/ofa.h"
#include "fft_op.h"
#include "error_op.h"

#define ROUND(x) ((x>0)? (long)floor(x + 0.5) : (long)(ceil(x - 0.5)) )

FFT_op::FFT_op()
{
	FrameSize = 0;
	NumBins = 0;
	NumFrames = 0;
	TimeSpectra = 0;
	BufSize = 0;
	OutBuf = 0;
	InBuf = 0;
	AmpSpectWin = 0;
	Hamming = 0;
	Overlap = 0;
	Rate = 0;
}

FFT_op::~FFT_op()
{
	FFTLib_op::Destroy();

	if (OutBuf)
		delete[] OutBuf;
	if (InBuf)
		delete[] InBuf;
	if (AmpSpectWin)
		delete[] AmpSpectWin;
        if (TimeSpectra) 
                delete[] TimeSpectra;
        if (Hamming) 
                delete[] Hamming;
}


void 
FFT_op::LoadSignal(Signal_op *sig)
{
	Signal = sig;
	Rate = Signal->GetRate();

	if (TimeSpectra)
	{
		delete[] TimeSpectra;
		TimeSpectra = 0;
	}
}


void
FFT_op::SetSize(int N, bool optimize)
{

	if (OutBuf)
		delete[] OutBuf;
	if (InBuf)
		delete[] InBuf;
	if (AmpSpectWin)
		delete[] AmpSpectWin;
	FrameSize = N;
	OutBuf = new double[FrameSize+128];
	InBuf = new double[FrameSize+128];
	FFTLib_op::SetSize(N, optimize, InBuf, OutBuf);
	SetNumBins(FrameSize/2 + 1);
	AmpSpectWin = new double[GetNumBins()];
	WindowInit();
}

void 
FFT_op::SetStep(int step) {
	if (Rate==0)
		throw OnePrintError("SetStep:programming error:Rate");
	if (step<=0)
		throw OnePrintError("SetStep:programming error:Step");

	StepSize = step;
}


void
FFT_op::WindowInit()
{
	if (Hamming)
		delete[] Hamming;

	Hamming = new double[FrameSize];
	for (int i=0; i<FrameSize; i++)
		Hamming[i] = 0.54 - 0.46*cos(i*(TwoPI/(FrameSize-1)));
}

void 
FFT_op::CreateBuffer(int numBins, int numFrames, bool init) 
{
	NumFrames = numFrames;
	NumBins = numBins;
	BufSize = NumFrames * NumBins;
	if (TimeSpectra) delete[] TimeSpectra;
	TimeSpectra = new float[BufSize];

	if (init)
	{
		for (int i=0; i<BufSize; i++)
			TimeSpectra[i] = 0;
	}
}



// Mono signals only
void 
FFT_op::Compute(double ovlap)
{
	long i;
	int j,k,m;

	if (ovlap != Overlap || !TimeSpectra) 
	{
		Overlap = ovlap;
		if (TimeSpectra)
			delete[] TimeSpectra;
		SetStep(int(FrameSize * (1.0 - Overlap)));	// # of signal samples per step
		SetNumFrames(((Signal->GetLength()-FrameSize) / StepSize) + 1);
		CreateBuffer(GetNumBins(), GetNumFrames());	// allocates spectrum storage
	}

	short* sdata = Signal->GetBuffer();
	j = BufSize;		// safety

	// m counts # of StepSize's we've made
	for (i=0, m=0; i<=Signal->GetLength()-FrameSize; i+=StepSize, m++) 
	{
		for (j=0; j<FrameSize; j++) {
			// copy and normalize samples into fft input buffer
			InBuf[j] = (double)sdata[i+j]/(double)MaxSample;
		}

		// Do the FFT
		ComputeWindow(InBuf);

		// Copy resulting spectrum into the larger array
		long start = m * GetNumBins();
		for (j=start, k=0; k < GetNumBins(); j++, k++) {
			TimeSpectra[j] = (float)AmpSpectWin[k];
		}
	}
	// zero out remaining entries
	for ( ; j<BufSize; j++)
		TimeSpectra[j] = (float) 0.0;
}

// If windowing other than RECTANGULAR is in effect, the input buffer will be altered
void
FFT_op::ComputeWindow(double* in)
{
	int i;

	if (WindowShape == HAMMING)
	{
		for (i=0; i < FrameSize; i++)
			in[i] *= Hamming[i];
	}

	FFTLib_op::ComputeFrame(FrameSize, in, OutBuf);

	// Normalize
	for (i=0; i < FrameSize; i++)
		OutBuf[i] /= FrameSize;

	// Compute amplitude spectrum for window
	// We only got half the values, because the rest was thrown away in the (identical)
	// complex conjugate part (negative frequencies). To get the amplitude back 
	// we must multiply by 2.
	AmpSpectWin[0] = 2*sqrt(OutBuf[0]*OutBuf[0]);		// DC component
	for (int k=1; k<(FrameSize+1)/2; ++k)		// (k < N/2 rounded up)
		AmpSpectWin[k] = 2*sqrt(OutBuf[k]*OutBuf[k] + OutBuf[FrameSize-k]*OutBuf[FrameSize-k]);
	if (FrameSize % 2 == 0) // N is even
		AmpSpectWin[FrameSize/2] = 2*sqrt(OutBuf[FrameSize/2]*OutBuf[FrameSize/2]);  // Nyquist freq.
}


// Resample the frames to a new reduced size
void 
FFT_op::ReSample(int nBins, bool melScale)
{
	double hiFreq = 8000.0;			// Everything above 8 KHz is ignored
	double halfFreq;
	if (melScale)
		halfFreq = 1000.0;
	else
		halfFreq = hiFreq/2;

	if (GetFreqStep() > halfFreq/(nBins/2) || nBins>=GetNumBins())
		throw OnePrintError("Oversampling not supported in ReSample");

	int j;
	float* fr;
	int srcInd, curInd;
	double fStep, maxAmp, curHz, srcHz;

	// Pre-calculate frequencies
	vector<double> freq(GetNumBins());
	for (j=0; j<GetNumBins(); j++)
		freq[j] = GetFreq(j);

	float* tmpBuf = new float[nBins*GetNumFrames()];

	// Approximate the Barks scale: 1/2 the bins from 0-halfFreq Hz, 1/2 from halfFreq-hiFreq Hz
	for (long i=0; i<GetNumFrames(); i++)
	{
		fr = GetFrame(i);
		curHz = 0;
		srcInd = 0;
		curInd = 0;
		srcHz = freq[srcInd];
		fStep = halfFreq/(nBins/2);
		for (j=0; j<nBins/2; j++)
		{
			curHz += fStep;
			maxAmp = 0;
			while (srcHz < curHz)
			{
				if (fr[srcInd] > maxAmp) maxAmp = fr[srcInd];
				srcInd++;
				srcHz = freq[srcInd];
			}
			tmpBuf[i*nBins+j] = (float)maxAmp;
		}

		fStep = (hiFreq-halfFreq)/(nBins/2);
		for (j=nBins/2; j<nBins; j++)
		{
			curHz += fStep;
			maxAmp = 0;
			while (srcHz < curHz)
			{
				if (fr[srcInd] > maxAmp) maxAmp = fr[srcInd];
				srcInd++;
				srcHz = freq[srcInd];
			}
			tmpBuf[i*nBins+j] = (float)maxAmp;
		}
	}

	delete[] TimeSpectra;
	TimeSpectra = tmpBuf;
	SetNumBins(nBins);
	BufSize = GetNumFrames() * GetNumBins();
}


// convert Hz to MIDI note number. 
int
FFT_op::FreqToMidi(double hz)
{
	const double nFact = 17.31234049067;	// 12/ln(2)
	double Nd;

	Nd = nFact*log(hz/27.5);

	return ROUND(Nd);
}

