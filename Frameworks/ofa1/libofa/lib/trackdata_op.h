/* ------------------------------------------------------------------

   libofa -- the Open Fingerprint Architecture library

   Copyright (C) 2006 MusicIP Corporation
   All rights reserved.

-------------------------------------------------------------------*/
// FILE: "trackdata_op.h"
// MODULE: Specification file for track data elements
// AUTHOR: Stephen Pope
// DATE CREATED: 01/12/06

#ifndef TRACK_DATA_OP_H
#define TRACK_DATA_OP_H 1


class TrackData_op {

public:
	TrackData_op();
	TrackData_op(float time, float frequency, float amplitude, float frDur);
	~TrackData_op();

// Accessing methods

	float getTime() const { return StartTime; }
	float getAmplitude() const { return Amplitude; }
	float getPitch() const { return Pitch;}
	float getEndPitch() const { return EndPitch;}
	float getAvgAmplitude() const { return AvgAmplitude; }
	float getAvgPitch() const { return AvgPitch;}
	void setAvgAmplitude(float val) { AvgAmplitude = val; }
	void setAvgPitch(float val) { AvgPitch = val;}
	void setEndPitch(float val) { EndPitch = val;}

	float getDuration();
	float getStartTime() const { return StartTime; }

	void SetInTrack(bool in) { InTrack = in; }
	bool IsInTrack() { return InTrack; }

// Data/frame/list structure

	void linkTo(TrackData_op* pr);
	void linkPrevious(TrackData_op* pr) { previous = pr; }
	void linkNext(TrackData_op* pr) { next = pr; }

	TrackData_op* getPrev() const { return previous; }
	TrackData_op* getNext() const { return next; }
	TrackData_op* getHigher() const { return higher; }
	void linkHigher(TrackData_op* pr) { higher = pr; }
	TrackData_op* getHead();
	TrackData_op* getTail();

// Inquiry

	bool isOrphan() const { return ((previous == 0) && (next == 0)); }
	bool isHead() const { return ((previous == 0) && (next != 0)); }
	bool isTail() const { return ((previous != 0) && (next == 0)); }

private:

// Instance variables

	float Amplitude;		// single values
	float Pitch;
	float StartTime;
	float EndTime;
	float AvgAmplitude;
	float AvgPitch;
	float EndPitch;
	float FrameDur;

// Inter-item links

	TrackData_op* previous;
	TrackData_op* next;
	TrackData_op* higher;

// State
	bool InTrack;
};

#endif
