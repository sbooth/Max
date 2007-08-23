/* ------------------------------------------------------------------

   libofa -- the Open Fingerprint Architecture library

   Copyright (C) 2006 MusicIP Corporation
   All rights reserved.

-------------------------------------------------------------------*/
// FILE: "signal_op.h"
// MODULE: Class header for Signal_op
// AUTHOR: Frode Holm
// DATE CREATED: 1/12/06

#ifndef __SIGNAL_OP_H
#define __SIGNAL_OP_H 1


const int MaxSample = 32767;
const int MinSample = -32768;

class Signal_op {
public:
	Signal_op();
	~Signal_op();
	void Load(short* samples, long size, int sRate, bool stereo);
	void CutSignal(double start, double dur);
	void PrepareStereo(long rate, double silTh);
	void PrepareMono(long rate, double silTh);
	void LPlusR();
	void LMinusR();
	void RemoveSilence(double startTh, double endTh);
	void RemoveDCOffset();
	void Normalize();
	void ConvertSampleRate(long targetSR);
	double GetCrossCorrelation();
	double GetDuration() { return (double) NumBlocks * 1000.0 / (double) Rate; }		// In msec
	short* GetBuffer() { return Data; }
	long GetLength() { return NumBlocks; }
	long GetRate() { return Rate; }

private:
	short* Data;		// buffer
	bool iOwnData;
	long BufSize;		// Total size of Data in terms of # of data items (short or float)
	long NumBlocks;		// number of data blocks (= number of sample points)
	long Rate;			// Sample rate
	int NumChannels;	// number of channels
};




#endif


