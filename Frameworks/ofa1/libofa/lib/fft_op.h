/* ------------------------------------------------------------------

   libofa -- the Open Fingerprint Architecture library

   Copyright (C) 2006 MusicIP Corporation
   All rights reserved.

-------------------------------------------------------------------*/
// FILE: "fft_op.h"
// MODULE: Class header for FFT_op
// AUTHOR: Frode Holm
// DATE CREATED: 1/12/06

#ifndef __FFT_OP_H
#define __FFT_OP_H 1

#ifdef WIN32
#include "../config_win32.h"
#else
#include "../config.h"
#endif
#include "signal_op.h"
#include "fftlib_op.h"

enum { RECTANGULAR, TRIANGULAR, HAMMING };
const double TwoPI = 2.0 * 3.14159265358979324;

class FFT_op : public FFTLib_op {
public:
	FFT_op();
	~FFT_op();
	void LoadSignal(Signal_op *sig);
	void SetSize(int N, bool optimize);
	void Compute(double ovlap);
	void SetWindowShape(int shape) { WindowShape = shape; }
	void ReSample(int nBins, bool melScale);
	long GetNumFrames() const { return NumFrames; }
	int GetNumBins() const { return NumBins; }
	float* GetFrame(int frNum) { return &TimeSpectra[frNum * NumBins]; }
	double GetFreqStep() { return (double)Rate/(GetNumBins()*2); }
	double GetStepDur() const { return StepSize * 1000.0 / Rate; }
	static int FreqToMidi(double hz);
private:
	void CreateBuffer(int numBins, int numFrames, bool init = false);
	void SetStep(int step);
	void WindowInit();
	void ComputeWindow(double* in);
	void SetNumFrames(long numFr) { NumFrames = numFr; }
	void SetNumBins(int bins) { NumBins = bins; }
	double GetFreq(int step) { return step * GetFreqStep(); }

	Signal_op* Signal;
	double* InBuf;			// Temporary holding buffer for fft input frames
	double* OutBuf;			// Temporary output buffer for one FFT frame
	double* AmpSpectWin;	// Buffer for amplitude spectrum of current frame
	float* TimeSpectra;		// Sequence of amp spectra for Signal, separated by NumBins
	long BufSize;			// Size of TimeSpectra buffer
	int FrameSize;			// in # of signal sample points
	int StepSize;			// in # of signal sample points
	int NumBins;			// # of spectrum points
	int NumFrames;			// # of analysis frames
	int Rate;				// Sample rate
	double Overlap;			// in percent (= 1 - StepSize/FrameSize)
	int WindowShape;		// Type of windowing
	double* Hamming;		// Hamming window

};



#endif
