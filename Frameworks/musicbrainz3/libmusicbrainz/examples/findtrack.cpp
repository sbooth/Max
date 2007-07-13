// Search for a track by title (and optionally by artist name). 
//
// Usage:
//	findtrack 'track name' ['artist name'] 
//
// $Id: findtrack.cpp 8247 2006-07-22 19:29:52Z luks $

#include <iostream>
#include <musicbrainz3/webservice.h>
#include <musicbrainz3/query.h>
#include <musicbrainz3/model.h>

using namespace std;
using namespace MusicBrainz;

int
main(int argc, char **argv)
{
	if (argc < 2) {
		cout << "Usage: findtrack 'track name' ['artist name']"  << endl;
		return 1;
	}
	
	string artistName;
	if (argc > 2) 
		artistName = argv[2];
	
	Query q;
	TrackResultList results;
	
	try {
		TrackFilter f = TrackFilter().title(argv[1]).artistName(artistName);
		results = q.getTracks(&f);
	}
	catch (WebServiceError &e) {
		cout << "Error: " << e.what() << endl;
		return 1;
	}

	for (TrackResultList::iterator i = results.begin(); i != results.end(); i++) {
		TrackResult *result = *i;
		Track *track = result->getTrack();
		cout << "Score   : " << result->getScore() << endl;
		cout << "Id      : " << track->getId() << endl;
		cout << "Title   : " << track->getTitle() << endl;
		cout << "Artist  : " << track->getArtist()->getName() << endl;
		cout << endl;
	}

	return 0;
}

