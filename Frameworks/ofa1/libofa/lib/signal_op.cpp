/* ------------------------------------------------------------------

   libofa -- the Open Fingerprint Architecture library

   Copyright (C) 2006 MusicIP Corporation
   All rights reserved.

-------------------------------------------------------------------*/
// FILE: "signal_op.cpp"
// MODULE: Implementation for class Signal_op
// AUTHOR: Frode Holm
// DATE CREATED: 1/12/06


#include <math.h>
#include "signal_op.h"
#include "AFLIB/aflibConverter.h"
#include "error_op.h"


Signal_op::Signal_op()
{
	Data = 0;
	iOwnData = false;
	NumChannels = 0;
	BufSize = 0;
	NumBlocks = 0;
	Rate = 0;
}

Signal_op::~Signal_op()
{
	if (iOwnData)
		delete[] Data;
}


void
Signal_op::Load(short* samples, long size, int sRate, bool stereo)
{
	Data = samples;
	iOwnData = false;
	NumChannels = stereo ? 2 : 1;
	BufSize = size;
	NumBlocks = BufSize / NumChannels;
	Rate = sRate;
}


// CutSignal deletes samples from the sample buffer
void
Signal_op::CutSignal(double start, double dur)
{
	int i, n;
	short* samples = Data;

	long startS = (long)(start * Rate / 1000.0);
	long stopS = (long)(startS + dur * Rate / 1000.0);

	NumBlocks = (stopS-startS);
	if (NumBlocks <= 0)
		throw OnePrintError("Programming error: CutSignal");

	BufSize = NumBlocks * NumChannels;
	short* tmpBuf = new short[BufSize];

	startS *= NumChannels;
	stopS *= NumChannels;

	// Copy to new buffer
	for (i=startS, n=0; i<stopS; i++, n++)
		tmpBuf[n] = samples[i];
	if (iOwnData)
		delete[] Data;
	Data = tmpBuf;
	iOwnData = true;
}


void
Signal_op::PrepareStereo(long newRate, double silTh)
{
	// Convert to mono
	if (GetCrossCorrelation() < -0.98)
		LMinusR();
	else
		LPlusR();

	PrepareMono(newRate, silTh);
}


void
Signal_op::PrepareMono(long newRate, double silTh)
{
	RemoveSilence(silTh, silTh);

	RemoveDCOffset();

	// Check for rate conversion
	if (newRate != Rate)
		ConvertSampleRate(newRate);

	Normalize();

}

// Add left and right channels

void Signal_op::LPlusR() 
{
	if (NumChannels != 2) 
		return;
	short* tmpBuf = new short[NumBlocks];
	short* samples = Data;
	for (long i=0, n=0; i<NumBlocks*2; i+=2, n++) 
	{
		int sum = samples[i] + samples[i+1];
		tmpBuf[n] = sum / 2;
	}
	if (iOwnData)
		delete[] Data;
	Data = tmpBuf;
	iOwnData = true;
	NumChannels = 1;
	BufSize = NumBlocks;
}


// Subtract left and right channels.

void Signal_op::LMinusR() 
{
	if (NumChannels != 2) 
		return;
	short * tmpBuf = new short[NumBlocks];
	short * samples = Data;
	for (long i=0, n=0; i<NumBlocks*2; i+=2, n++) 
	{
		int sum = samples[i] - samples[i+1];
		tmpBuf[n] = sum / 2;
	}
	if (iOwnData)
		delete[] Data;
	Data = tmpBuf;
	iOwnData = true;
	NumChannels = 1;
	BufSize = NumBlocks;
}


void 
Signal_op::RemoveSilence(double startTh, double endTh)
{
	long i, n;

	short* samples = Data;

	// Truncate leading and trailing silence
	long stop = NumBlocks;
	int silBlock = (int) (Rate*2.2/400);
	int count = 0;
	long sum = 0;
	long start = 0;

	// Front silence removal
	while (start < stop) 
	{
		sum += abs(samples[start]);
		count++;
		if (count >= silBlock)
		{
			double av = (double)sum/silBlock;
			if (av > startTh)
			{
				start -= count-1;
				break;
			}
			count = 0;
			sum = 0;
		}

		start++;
	}
    if (start < 0) start = 0;

	// Back silence removal
	count = 0;
	sum = 0;
	while (stop > start) 
	{
		sum += abs(samples[stop-1]);
		count++;
		if (count >= silBlock)
		{
			double av = (double)sum/silBlock;
			if (av > endTh)
			{
				stop += count;
				break;
			}
			count = 0;
			sum = 0;
		}

	    stop--;
	}
	if (stop > NumBlocks) stop = NumBlocks;
	
	if (stop-start <= 0)
		throw OnePrintError("Signal has silence only", SILENCEONLY);

    NumBlocks = (stop-start);
	if (NumBlocks <= 0)
		throw OnePrintError("Signal is corrupt");

	BufSize = NumBlocks;
	short* tmpBuf = new short[BufSize];

	// Copy to new buffer
	for (i=start, n=0; i<stop; i++, n++)
		tmpBuf[n] = samples[i];
	if (iOwnData)
		delete[] Data;
	Data = tmpBuf;
	iOwnData = true;
}


void
Signal_op::RemoveDCOffset()
{
	long len = GetLength();
	short* x = Data;
	double yn=0, yn1=0;
	double sum = 0;
	long cnt = 0;
	double ramp = 1000.0;					// Ramp-up time (ms)
	long lim = (long) ((ramp/1000)*GetRate());
	double k = 1000.0/(GetRate()*ramp);
	double maxP = 0, maxN = 0;
	for (long n=1; n<=len; n++)
	{
		yn = yn1 + k*((double)x[n-1] - yn1);
		yn1 = yn;
		if (n > lim*3)
		{
			sum += yn;
			cnt++;
		}
		if (x[n-1] > maxP)
			maxP = x[n-1];
		if (x[n-1] < maxN)
			maxN = x[n-1];
	}

	double dcOffset = sum/(double)cnt;

	// Remove if greater than this
	if (fabs(dcOffset) > 15)	// otherwise don't bother
	{
		// Check to se if we have to "denormalize" to make sure there's headroom for the DC removal
		double factorP=0, factorN=0, factor=0;
		if (maxP - dcOffset > MaxSample)
			factorP = ((double)MaxSample - dcOffset) / maxP;
		if (maxN - dcOffset < MinSample)
			factorN = ((double)MinSample + dcOffset) / maxN;
		// only one can apply
		if (factorP > 0)
			factor = factorP;
		else if (factorN > 0)
			factor = factorN;

		for (long i=0; i<len; i++)
		{
			double sample = (double)x[i];
			if (factor > 0)
				sample *= factor;
			sample -= dcOffset;
			// round sample
			if (sample > 0)
				x[i] = (short) floor(sample + 0.5);
			else
				x[i] = (short) ceil(sample - 0.5);
		}
	}
}


void
Signal_op::Normalize()
{
	short* samples = Data;

	long i;
	int max = 0;
	double factor;
	
	for (i=0; i<NumBlocks; i++)
	{
		if (abs(samples[i]) > max)
			max = abs(samples[i]);
	}

	if (max >= MaxSample) {
		factor = 1;
	} else {
		factor = MaxSample / (double) max;
		for (i=0; i<NumBlocks; i++)
		{
			double tmp = (double)samples[i] * factor;
			// round sample
			if (tmp > 0)
				samples[i] = (short) floor(tmp + 0.5);
			else
				samples[i] = (short) ceil(tmp - 0.5);
		}
	}
}



// Mono signals only
void 
Signal_op::ConvertSampleRate(long targetSR)
{
	if (NumChannels > 1) return;

	aflibConverter srConv(true, false, true);	// Large filter with coefficients interpolation

	double factor = (double)targetSR/(double)Rate;

	long tmpSize = (long) (BufSize * factor + 2);
	short* tmpBuf = new short[tmpSize];

	srConv.initialize(factor, 1);

	int inCount = BufSize;
	int outCount = (int) (BufSize * factor);
	int outRet;
	outRet = srConv.resample(inCount, outCount, GetBuffer(), tmpBuf);

	if (iOwnData)
		delete[] Data;
	Data = tmpBuf;
	iOwnData = true;
	Rate = targetSR;
	NumBlocks = BufSize = outRet;
}


double
Signal_op::GetCrossCorrelation()
{
	// Cross Channel Correlation - stereo signals only
	long k;
	double C12 = 0, C11 = 0, C22 = 0;
	short* samples = Data;

	for (k=0; k<NumBlocks*2; k+=2) 
	{
		C12 += samples[k]*samples[k+1];
		C11 += samples[k]*samples[k];
		C22 += samples[k+1]*samples[k+1];
	}

	return C12/sqrt(C11*C22);
}
