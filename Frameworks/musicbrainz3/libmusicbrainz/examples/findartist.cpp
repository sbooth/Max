// Search for an artist by name.
//
// Usage:
//	findartist 'artist-name' 
//
// $Id: findartist.cpp 8247 2006-07-22 19:29:52Z luks $

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
		cout << "Usage: findartist 'artist name'" << endl;
		return 1;
	}
	
	Query q;
	ArtistResultList results;
	
	try {
		// Search for all artists matching the given name. Limit the results
		// to the 5 best matches.
		
		ArtistFilter f = ArtistFilter().name(argv[1]).limit(5);
		results = q.getArtists(&f);
	}
	catch (WebServiceError &e) {
		cout << "Error: " << e.what() << endl;
		return 1;
	}

	// No error occurred, so display the results of the search. It consists of
	// ArtistResult objects, where each contains an artist.
	
	for (ArtistResultList::iterator i = results.begin(); i != results.end(); i++) {
		ArtistResult *result = *i;
		Artist *artist = result->getArtist();
		cout << "Score   : " << result->getScore() << endl;
		cout << "Id      : " << artist->getId() << endl;
		cout << "Name    : " << artist->getName() << endl;
		cout << "SortName: " << artist->getSortName() << endl;
		cout << endl;
	}

	// Now that you have artist IDs, you can request an artist in more detail, for
	// example to display all official albums by that artist. See the 'getartist.cpp'
	// example on how achieve that. 
	
	return 0;
}

