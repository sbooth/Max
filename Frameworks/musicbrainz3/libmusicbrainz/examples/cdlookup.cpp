// Search for a track by title (and optionally by artist name). 
//
// Usage:
//	cdlookup [device] 
//
// $Id: cdlookup.cpp 8790 2007-01-13 23:04:43Z luks $

#include <iostream>
#include <musicbrainz3/disc.h>
#include <musicbrainz3/webservice.h>
#include <musicbrainz3/query.h>
#include <musicbrainz3/model.h>

using namespace std;
using namespace MusicBrainz;

int
main(int argc, char **argv)
{
	if (argc < 1) {
		cout << "Usage: cdlookup [device]"  << endl;
		return 1;
	}

	string device;
	if (argc > 1)
		device = argv[1];

	Disc *disc;
	try {
		disc = readDisc(device);
	}
	catch (DiscError &e) {
		cout << "Error: " << e.what() << endl;
		return 1;
	}
	string discId = disc->getId();
	delete disc;
	cout << "Disc Id: " << discId << endl << endl;

	Query q;
	ReleaseResultList results;
	try {
    ReleaseFilter f = ReleaseFilter().discId(discId);
        results = q.getReleases(&f);
	}
	catch (WebServiceError &e) {
		cout << "Error: " << e.what() << endl;
		return 1;
	}

	for (ReleaseResultList::iterator i = results.begin(); i != results.end(); i++) {
		ReleaseResult *result = *i;
		Release *release;
		try {
			release = q.getReleaseById(result->getRelease()->getId(), &ReleaseIncludes().tracks().artist());
		}
		catch (WebServiceError &e) {
			cout << "Error: " << e.what() << endl;
			continue;
		}
		cout << "Id      : " << release->getId() << endl;
		cout << "Title   : " << release->getTitle() << endl;
		cout << "Tracks  : ";
		int trackno = 1;
		for (TrackList::iterator j = release->getTracks().begin(); j != release->getTracks().end(); j++) {
			Track *track = *j;
			Artist *artist = track->getArtist();
			if (!artist)
				artist = release->getArtist();
			cout << trackno++ << ". " << artist->getName() << " / " << track->getTitle() << endl;
			cout << "          ";
		}
		cout << endl;
		delete result;
	}

	return 0;
}
