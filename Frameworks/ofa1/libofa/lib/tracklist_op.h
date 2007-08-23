/* ------------------------------------------------------------------

   libofa -- the Open Fingerprint Architecture library

   Copyright (C) 2006 MusicIP Corporation
   All rights reserved.

-------------------------------------------------------------------*/
// FILE: "tracklist_op.h"
// MODULE: Specification file for composite track list objects
// AUTHOR: Stephen Pope
// DATE CREATED: 01/12/06

#include "trackframe_op.h"

class TrackList_op {

public:
// Constructor
	TrackList_op();
	~TrackList_op();

// Accessing methods
	void Add(TrackFrame_op* td);
	TrackFrame_op* getBaseFrame() { return BaseFr; }
	int getSize() { return NumFrames; }

private:
	int NumFrames;
	TrackFrame_op* BaseFr;
	TrackFrame_op* LastFr;
};
