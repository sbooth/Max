/* ------------------------------------------------------------------

   libofa -- the Open Fingerprint Architecture library

   Copyright (C) 2006 MusicIP Corporation
   All rights reserved.

-------------------------------------------------------------------*/
// FILE: "trackframe_op.cpp"
// MODULE: Implementation for class TrackFrame_op
// AUTHOR: Stephen Pope
// DATE CREATED: 01/12/06

#include <math.h>
#include "trackdata_op.h"
#include "trackframe_op.h"

// Constructor

TrackFrame_op::TrackFrame_op(float aTime)
{ 
	FrameTime = aTime;
	NumTracks = 0;
	BaseTr = 0;
	NextFr = 0;
}

// Delete the list of peaks on delete

TrackFrame_op::~TrackFrame_op()
{ 
	TrackData_op* trk = BaseTr;
	while (trk != 0) {
		TrackData_op* next = trk->getHigher();
		delete trk;
		trk = next;
	}
}

// Element add/remove

void 
TrackFrame_op::Add(TrackData_op* td)
{
	if (NumTracks == 0)
		BaseTr = td;
	NumTracks++;
}

// Answer the best-match (in frequency) track to the given value

TrackData_op* 
TrackFrame_op::getTrackNearestFreq(float freq)
{

	double diff;
	double minDiff = 10000;
	TrackData_op* answer;
	answer = 0;
	TrackData_op* ptr = BaseTr;
					// Iterate over the receiver's peaks
	while (ptr != 0) {
		if (!ptr->IsInTrack())
		{
						// Find minimum frequency difference
			diff = fabs (ptr->getPitch() - freq);
			if (diff < minDiff) {
				minDiff = diff;
				answer = ptr;
			}
		}
		ptr = ptr->getHigher();
	}
	return answer;
}

