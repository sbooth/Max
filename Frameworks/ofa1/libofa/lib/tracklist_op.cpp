/* ------------------------------------------------------------------

   libofa -- the Open Fingerprint Architecture library

   Copyright (C) 2006 MusicIP Corporation
   All rights reserved.

-------------------------------------------------------------------*/
// FILE: "tracklist_op.cpp"
// MODULE: Implementation for class TrackList
// AUTHOR: Stephen Pope
// DATE CREATED: 01/12/06


#include "trackdata_op.h"
#include "tracklist_op.h"

// Constructor

TrackList_op::TrackList_op() 
{ 
	NumFrames = 0; 
	BaseFr = 0;
	LastFr = 0;
}

// Delete the list of frames on delete

TrackList_op::~TrackList_op() 
{
	TrackFrame_op* frm = BaseFr;
	while (frm != 0) {
		TrackFrame_op* next = frm->getNext();
		delete frm;
		frm = next;
	}
}

// Element add/remove

void 
TrackList_op::Add(TrackFrame_op* td) 
{
	if (NumFrames == 0) {
		BaseFr = td;
		LastFr = td;
	} else {
		LastFr->setNext(td);
		LastFr = td;
	}
	NumFrames++;
}


