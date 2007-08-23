/* ------------------------------------------------------------------

   libofa -- the Open Fingerprint Architecture library

   Copyright (C) 2006 MusicIP Corporation
   All rights reserved.

-------------------------------------------------------------------*/
// FILE: "frametracker_op.cpp"
// MODULE: Implementation for class FrameTracker
// AUTHOR: Stephen Pope, Frode Holm
// DATE CREATED: 01/12/06

#include <math.h>
#include "frametracker_op.h"
#include "trackdata_op.h"

// Constructor

FrameTracker_op::FrameTracker_op(float peakT, float fThresh, float lenT, int maxTrax)
{
	PeakThreshold = peakT;
	FreqThreshold = fThresh;
	LengthThreshold = lenT;
	MaxTracks = maxTrax;
	PeakWidth = 2;		// width of peak interval (on one side)
	BaseFr = 0;
}

// Destructor

FrameTracker_op::~FrameTracker_op() 
{ 
	BaseFr = 0;
}


void 
FrameTracker_op::Compute(FFT_op& spectra) 
{
	double sdur = spectra.GetStepDur();

	int numFrames = spectra.GetNumFrames();

	// Detect the peaks in each frame
	for (int i = 0; i < numFrames; i++) 
	{		
		float realTime = (float)(i * sdur);
		TrackFrame_op* thePeaks = new TrackFrame_op(realTime);

		FindPeaks(spectra, i, thePeaks);
		Tracks.Add(thePeaks);				// add the frame to the track list
	}
					
	TrackPeaks();							// Track the peaks between frames
	ContinuePeaks();						// Try to extend the tracks
}

// Find the peaks in a single frame;
// use local-max detection over the min threshold
void 
FrameTracker_op::FindPeaks(FFT_op& data, int frameNum, TrackFrame_op* thePeaks) 
{

	int numBins = data.GetNumBins();
	float* frame = data.GetFrame(frameNum);
	int npeak = 0;
	double realTime = frameNum * data.GetStepDur();
	TrackData_op* prevP = 0;
	float prevPV = * frame++;			// previous previous sample
	float prevV = * frame++;			// previous sample
	float thisV = * frame++;			// this sample
	float nextV = * frame++;			// next sample
	for (int i = 4; i < (numBins - 2); i++) 
	{
		float nextNV = * frame++;		// next next sample

									// check for peak relatively > PeakThreshold
		bool found = (thisV > PeakThreshold) && (thisV > prevV) && (thisV > nextV);

		if (found && (PeakWidth > 1))	// if using wide peaks, compare prevPV and nextNV
			found = found && (thisV > prevPV) && (thisV > nextNV);

		if (found) 
		{
									// If peak detected, do cubic interpolation for index, 									// freq, and magnitude -- first calculate "real" index
			double realIndex = ((prevV - nextV) * 0.5) / (prevV - (2.0 * thisV) + nextV);
									// then interpolate the real magnitude and frequency
			double realPeak = thisV - ((prevV - nextV) * 0.25 * realIndex);
			double realFreq = data.GetFreqStep() * (float)(i-2);
									// Add the new peak to the list and link it in
			TrackData_op* thisP = new TrackData_op((float)realTime, (float)realFreq, (float)realPeak, (float)data.GetStepDur());
			if (prevP != 0)
				prevP->linkHigher(thisP);
			prevP = thisP;
			thePeaks->Add(thisP);
			npeak++;
		}
		prevPV = prevV;				// step the values to the next freq. bin
		prevV = thisV;
		thisV = nextV;
		nextV = nextNV;
	}
}

// Answer the best match for the given frequency in the given frame
TrackData_op* 
FrameTracker_op::GetBestMatch(float pitch, TrackFrame_op* frame) 
{
	TrackData_op* match =  frame->getTrackNearestFreq(pitch);
	if (match != 0) {				// If it's within the freq. range FreqThreshold
		double frqDiff = fabs(log(match->getPitch()) - log(pitch));
		if (frqDiff < FreqThreshold)
			return match;
	}
	return 0;
}

// Track and group peaks in the given data set;
// do a running forward/backward comparison of all peaks in a track

void 
FrameTracker_op::TrackPeaks() 
{

	TrackFrame_op* prevFr = Tracks.getBaseFrame();
	TrackFrame_op* thisFr = prevFr->getNext();
	TrackFrame_op* nextFr = thisFr->getNext();
	TrackFrame_op* lastFr = nextFr->getNext();
	while (thisFr != 0) {				// Iterate over the frames trying to track peaks
		TrackData_op* baseTr = prevFr->getBaseTrack();
										// Try to track the previous frame's peaks into this frame
		while (baseTr != 0) {			// Find the best freq. match between track and current pks
			float baseP = baseTr->getPitch();
			TrackData_op* match =  GetBestMatch(baseP, thisFr);
			if (match != 0) {
				baseTr->linkTo(match);					// create double links
			} 
			baseTr = baseTr->getHigher();
		}								 // end of current frame
		prevFr = thisFr;
		thisFr = nextFr;
		nextFr = lastFr;
		if (lastFr != 0)
			lastFr = lastFr->getNext();
	}									// end of all tracks
}

// Continue track groups, and gather track statistics

void 
FrameTracker_op::ContinuePeaks() 
{

	TrackFrame_op* base = Tracks.getBaseFrame();
	while (base != 0) {			// Iterate over all frames
		TrackData_op* td = base->getBaseTrack();
		while (td != 0) {		// Iterate over peaks in a frame
			if (td->isHead()) {
				float am = td->getAmplitude();
				float pc = td->getPitch();
				float avgA = am;
				float avgP = pc;
				int i = 1;
				TrackData_op* tl = td->getNext();
				while (tl != 0) {		// Iterate forward over peaks in a track
					am = tl->getAmplitude();
					pc = tl->getPitch();
					avgA += am;
					avgP += pc;
					td->setEndPitch(pc);
					tl = tl->getNext();
					i++;
				}		// end of links
				td->setAvgAmplitude(avgA / (float) i);
				td->setAvgPitch(avgP / (float) i);
			}			// end of track
			td = td->getHigher();			// go to next peak in frame
		}				// end of frame
		base = base->getNext();				// go to next frame
	}
}

