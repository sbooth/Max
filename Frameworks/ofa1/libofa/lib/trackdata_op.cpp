/* ------------------------------------------------------------------

   libofa -- the Open Fingerprint Architecture library

   Copyright (C) 2006 MusicIP Corporation
   All rights reserved.

-------------------------------------------------------------------*/
// FILE: "trackdata_op.cpp"
// MODULE: Implementation for class TrackData
// AUTHOR: Stephen Pope
// DATE CREATED: 01/12/06

#include "trackdata_op.h"

#define max(a,b)    (((a) > (b)) ? (a) : (b))
#define min(a,b)    (((a) < (b)) ? (a) : (b))


// Constructor

TrackData_op::TrackData_op() { /* empty */ }

TrackData_op::TrackData_op(float aTime, float frequency, float amplitude, float frDur) 
{
	StartTime = aTime;
	EndTime = 0.0f;
	Pitch = AvgPitch = EndPitch = frequency;
	Amplitude = AvgAmplitude = amplitude;
	FrameDur = frDur;
	previous = 0;
	next = 0;
	higher = 0;
	InTrack = false;
}

TrackData_op::~TrackData_op() 
{
	previous = next = higher = 0;
}

float 
TrackData_op::getDuration() 
{
	if (isOrphan())
		return FrameDur;
	if ( ! (isHead()))
		return (StartTime);
	if (EndTime == 0.0f) {
		TrackData_op* trk = getTail();
		EndTime = trk->getTime() + FrameDur; 
	}
	return (EndTime - StartTime);
}


// Extend the receiver by the argument

void 
TrackData_op::linkTo(TrackData_op* tp) 
{
	tp->linkPrevious(this);
	linkNext(tp);
	InTrack = true;
	tp->SetInTrack(true);
}


// Walk the links back to the head of this track

TrackData_op* 
TrackData_op::getHead() 
{
	TrackData_op* trk;
	trk = this;
	while (trk->getPrev() != 0)
		trk = trk->getPrev();
	return trk;
}


// Walk the links forward to the tail of this track

TrackData_op* 
TrackData_op::getTail() 
{
	TrackData_op* trk;
	trk = this;
	while (trk->getNext() != 0)
		trk = trk->getNext();
	return trk;
}

