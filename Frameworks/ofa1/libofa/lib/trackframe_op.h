/* ------------------------------------------------------------------

   libofa -- the Open Fingerprint Architecture library

   Copyright (C) 2006 MusicIP Corporation
   All rights reserved.

-------------------------------------------------------------------*/
// FILE: "trackframe_op.h"
// MODULE: Specification file for composite track frame objects
// AUTHOR: Stephen Pope
// DATE CREATED: 01/12/06

class TrackData_op;

class TrackFrame_op {

public:

// Constructor

	TrackFrame_op(float aTime = 0.0f);
	~TrackFrame_op();

// Accessing methods

	void Add(TrackData_op* td);
	inline TrackData_op* getBaseTrack() { return BaseTr; }
	inline TrackFrame_op* getNext() { return NextFr; }
	inline void setNext(TrackFrame_op* td) { NextFr = td; }
	inline float getTime() { return FrameTime; }

	TrackData_op* getTrackNearestFreq(float freq);

private:

// Instance variables

	int NumTracks;
	float FrameTime;
	TrackData_op* BaseTr;
	TrackFrame_op* NextFr;

};
