/* ------------------------------------------------------------------

   libofa -- the Open Fingerprint Architecture library

   Copyright (C) 2006 MusicIP Corporation
   All rights reserved.

-------------------------------------------------------------------*/
// FILE: "mainprint.cpp"
// MODULE: Top level calling code and main functions
// AUTHOR: Frode Holm
// DATE CREATED: 1/12/06

#include <vector>
#include "ofa1/ofa.h"
#include "signal_op.h"
#include "fft_op.h"
#include "frametracker_op.h"
#include "error_op.h"

#include "JAMA/jama_svd.h"

using namespace TNT;
using namespace JAMA;

typedef float Real;

// Print size
const int Dim = 7;
const int Res = 40;

const long SongLen = 120000;	// length to analyze (ms)
const int FrameSize = 8192;	// FFT framesize

void preprocessing(short* samples, long size, int sRate, bool stereo, Signal_op& sig);
void core_print(Signal_op& sig, unsigned char *out);
void pitch_print(Signal_op& sig, unsigned char *out);
char *base64encode(const char *input, int lentext);

// Retreive the version of the library
extern "C"
void ofa_get_version(int *major, int *minor, int *rev)
{
    sscanf(VERSION, "%d.%d.%d", major, minor, rev);
}

// ofa_create_print is the top level function generating the fingerprint.
// NOTE THAT THE PASSED IN DATA MAY BE BYTE SWAPPED DURING THE METHOD.
// ASSUME THAT DATA IN THE INPUT BUFFER IS DESTROYED AS A SIDE-EFFECT OF 
// CALLING THIS FUNCTION
//
// data: a buffer of 16-bit samples in interleaved format (if stereo), i.e. L,R,L,R, etc.
//		This buffer is destroyed during processing.
//		Ideally, this buffer should contain the entire song to be analyzed, but the process will only
//		need the first 2min + 10sec + any silence prepending the actual audio. Since the precise silence
//		interval will only be known after a couple of processing steps, the caller must make adequate
//		allowance for this. Caveat emptor.
// byteOrder: OFA_LITTLE_ENDIAN, or OFA_BIG_ENDIAN - indicates the byte
//            order of the data being passed in.
// size: the size of the buffer, in number of samples.
// sRate: the sample rate of the signal. This can be an arbitrary rate, as long as it can be expressed
//		as an integer (in samples per second). If this is different from 44100, rate conversion will
//		be performed during preprocessing, which will add significantly to the overhead.
// stereo: 1 if there are left and right channels stored, 0 if the data is mono
//
// On success, a valid text representation of the fingerprint is returned.
// The returned buffer will remain valid until the next call to ofa_create_print

extern "C"
const char *ofa_create_print(unsigned char *data, int byteOrder, long size, int sRate, int stereo)
{
    short *samples = (short *) data;
#ifdef BIG_ENDIAN
    if (byteOrder == OFA_LITTLE_ENDIAN) {
	for (int i = 0; i < size; ++i) {
	    samples[i] = data[2*i+1] << 8 | data[2*i];
	}
    }
#else
    if (byteOrder == OFA_BIG_ENDIAN) {
	for (int i = 0; i < size; ++i) {
	    samples[i] = data[2*i] << 8 | data[2*i+1];
	}
    }
#endif
    try {
	Signal_op sig;
	unsigned char bytes[Dim * Res * 2 + 5];

	preprocessing(samples, size, sRate, stereo, sig);
	bytes[0] = 1; // version marker
	core_print(sig, bytes + 1);
	pitch_print(sig, bytes + (Dim * Res * 2 + 1));
	return base64encode((char*) bytes, Dim * Res * 2 + 5);
    } catch (OnePrintError e) {
	return 0;
    }
}


void
preprocessing(short* samples, long size, int sRate, bool stereo, Signal_op& sig)
{
	int ch = stereo ? 2 : 1;
	long sec135 = 135 * sRate * ch;
	if (size > sec135) size = sec135; 

	sig.Load(samples, size, sRate, stereo);

	if (stereo)
		sig.PrepareStereo(44100, 50);
	else
		sig.PrepareMono(44100, 50);

	if (sig.GetDuration() > SongLen+10000)
		sig.CutSignal(10000, SongLen);
}

void
core_print(Signal_op& sig, unsigned char *out)
{
	FFT_op fft;

	fft.LoadSignal(&sig);
	fft.SetSize(FrameSize,false);
	fft.SetWindowShape(HAMMING);
	fft.Compute(0);

	fft.ReSample(Res, true);

	if (fft.GetNumFrames() < Res)
		throw OnePrintError(FILETOOSHORT);

	// Compute SVD
	int i,j;
	float* fr;
	int numBins = fft.GetNumBins();
	int numFrames = fft.GetNumFrames();

	Array2D<Real> in2D(numFrames, numBins);
	Array2D<Real> v(numBins, numBins);

	// copy into Array2D
	for (i = 0; i < numFrames; i++)
	{
		fr = fft.GetFrame(i);
		for (j = 0; j < numBins; j++)
			in2D[i][j] = fr[j];
	}

	SVD<Real> s(in2D);
	s.getV(v);

	int pos = 0;
	for (i = 0; i < Dim; i++) {
	    for (j = 0; j < Res; j++) {
		short value = short(v[j][i] * 32767);
		out[pos++] = ((value & 0xff00) >> 8);
		out[pos++] = (value & 0x00ff);
	    }
	}
}


struct pitchPacket {
	pitchPacket() { dur = 0; tracks = 0; amp = 0; }
	double dur;
	int tracks;
	double amp;
};


void 
pitch_print(Signal_op& sig, unsigned char *out)
{
	if (sig.GetDuration() > 40000)
		sig.CutSignal(0, 30000);

	FFT_op fft;

	fft.LoadSignal(&sig);
	fft.SetSize(FrameSize,false);
	fft.SetWindowShape(HAMMING);
	fft.Compute(0.8);

	FrameTracker_op fTrk(0.005f, 0.03f,  0.1f);
	fTrk.Compute(fft);

	vector<pitchPacket> notes(128);
	double loFreq = 50;
	double hiFreq = 1500;

	// Collect track statistics
	TrackList_op* trl = fTrk.getTracks();
	TrackFrame_op* base = trl->getBaseFrame();
	double dur, amp;
	int avPitch;
	int totalTracks = 0;
	while (base != 0) 
	{
		TrackData_op* td = base->getBaseTrack();
		while (td != 0) 
		{
			if (td->isHead() && td->getAvgPitch() > loFreq && td->getAvgPitch() < hiFreq) 
			{
				dur = td->getDuration();
				avPitch = fft.FreqToMidi(td->getAvgPitch());
				amp = td->getAvgAmplitude();
				notes[avPitch].dur += dur;
				notes[avPitch].tracks++;
				notes[avPitch].amp += amp;
				totalTracks++;
			}
			td = td->getHigher();
		}
		base = base->getNext();
	}

	// Find the 4 most prominent notes
	double maxStrength[4];
	int index[4];
	int i;

	for (i=0; i<4; i++)
	{
		maxStrength[i] = 0;
		index[i] = 0;
	}
	for (i=0; i<128; i++)
	{
		if (notes[i].tracks == 0) continue;

		double strength = notes[i].amp + notes[i].dur/10000.0;			// "linear" spread

		// "manual" sort
		if (strength > maxStrength[0])
		{
			maxStrength[3] = maxStrength[2];
			maxStrength[2] = maxStrength[1];
			maxStrength[1] = maxStrength[0];
			maxStrength[0] = strength;
			index[3] = index[2];
			index[2] = index[1];
			index[1] = index[0];
			index[0] = i;
		}
		else if (strength > maxStrength[1])
		{
			maxStrength[3] = maxStrength[2];
			maxStrength[2] = maxStrength[1];
			maxStrength[1] = strength;
			index[3] = index[2];
			index[2] = index[1];
			index[1] = i;
		}
		else if (strength > maxStrength[2])
		{
			maxStrength[3] = maxStrength[2];
			maxStrength[2] = strength;
			index[3] = index[2];
			index[2] = i;
		}
		else if (strength > maxStrength[3])
		{
			maxStrength[3] = strength;
			index[3] = i;
		}
	}

	for (i=0; i<4; i++)
	{
		out[i] = index[i];
	}
}

static char encodingTable[64] = {
    'A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P',    
    'Q','R','S','T','U','V','W','X','Y','Z','a','b','c','d','e','f',    
    'g','h','i','j','k','l','m','n','o','p','q','r','s','t','u','v',    
    'w','x','y','z','0','1','2','3','4','5','6','7','8','9','+','/'
};


// The return buffer is only valid until the next call to this method
char *base64encode(const char *input, int lentext) {
    static char out[758];
    unsigned char inbuf[3], outbuf[4];
    int i, ctcopy, pos = 0, ixtext = 0;
    
    while (true) {
        int ctremaining = lentext - ixtext;
        if (ctremaining <= 0)
            break;
        for (i = 0; i < 3; i++) { 
            int ix = ixtext + i;
            if (ix < lentext)
                inbuf[i] = (unsigned char) input[ix];
            else
                inbuf[i] = 0;
        }
        outbuf[0] = (unsigned char) ((inbuf [0] & 0xFC) >> 2);
        outbuf[1] = (unsigned char) (((inbuf [0] & 0x03) << 4) | ((inbuf [1] & 0xF0) >> 4));
        outbuf[2] = (unsigned char) (((inbuf [1] & 0x0F) << 2) | ((inbuf [2] & 0xC0) >> 6));
        outbuf[3] = (unsigned char) (inbuf [2] & 0x3F);
	
        switch (ctremaining) {
        case 1: 
            ctcopy = 2; 
            break;
        case 2: 
            ctcopy = 3; 
            break;
        default:
            ctcopy = 4;
            break;
        }
        for (i = 0; i < ctcopy; i++) {
            out[pos++] = encodingTable[outbuf[i]];
        }
        for (i = ctcopy; i < 4; i++) {
            out[pos++] = '=';
        }
        ixtext += 3;
    }
    out[pos] = 0;
    return out;
}

