/* ------------------------------------------------------------------

   libofa -- the Open Fingerprint Architecture library

   Copyright (C) 2006 MusicIP Corporation
   All rights reserved.

-------------------------------------------------------------------*/
// FILE: "frametracker_op.h"
// MODULE: Class header for FrameTracker_op
// AUTHOR: Stephen Pope, Frode Holm
// DATE CREATED: 01/12/06


#ifndef FRAME_TRACKER_OP_H
#define FRAME_TRACKER_OP_H 1

#include "fft_op.h"
#include "tracklist_op.h"
#include "trackdata_op.h"

class FrameTracker_op {
public:

// Constructor -- here are the defaults for the thresholds

	FrameTracker_op(
			float peakT = 0.001f,	// min ampl for peak detection
			float fThresh = 0.2,	// max freq ratio for tracking between peaks
			float lenT = 0.1f,		// min length for track (in sec) (ignored in this version)
			int maxTrax = 500);		// max # of tracks at a time (ignored in this version)
	~FrameTracker_op();

// Accessing

	TrackList_op* getTracks() { return &Tracks; }

// The big do-it method -- run the peak-tracking

	void Compute(FFT_op& spectra);

private:	
	TrackList_op Tracks;		// list of tracked frames
	float PeakThreshold;	// min peak magnitude for detection
	float FreqThreshold;	// max step between peaks for tracking
	float LengthThreshold;	// shortest track
	int MaxTracks;			// max # of peaks to track
	int PeakWidth;			// min sample width for peaks (+- x)
	TrackFrame_op* BaseFr;

// Private methods

	void FindPeaks(FFT_op& spectra, int frameNum, TrackFrame_op* thePeaks);
	TrackData_op* GetBestMatch(float pitch, TrackFrame_op* frame);
	void TrackPeaks();
	void ContinuePeaks();
};

#endif
