// Retrieve an artist by ID and display all official albums. 
//
// Usage:
//	getartist 'artist id' 
//
// $Id: getartist.cpp 8247 2006-07-22 19:29:52Z luks $

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
		cout << "Usage: getartist 'artist id'" << endl;
		return 1;
	}
	
	Query q;
	Artist *artist;
	
	try {
		ArtistIncludes inc = ArtistIncludes()
			.releases(Release::TYPE_OFFICIAL)
			.releases(Release::TYPE_ALBUM);
		artist = q.getArtistById(argv[1], &inc);
	}
	catch (WebServiceError &e) {
		cout << "Error: " << e.what() << endl;
		return 1;
	}

	cout << "Id        : " << artist->getId() << endl;
	cout << "Name      : " << artist->getName() << endl;
	cout << "SortName  : " << artist->getSortName() << endl;
	cout << "Type      : " << artist->getType() << endl;
	cout << "BeginDate : " << artist->getBeginDate() << endl;
	cout << "EndDate   : " << artist->getEndDate() << endl;
	cout << endl;
	
	ReleaseList releases = artist->getReleases();
	if (releases.size() == 0)
		cout << "No releases found." << endl;
	else
		cout << "Releases:" << endl;
	
	for (ReleaseList::iterator i = releases.begin(); i != releases.end(); i++) {
		Release *release = *i;
		cout << endl;
		cout << "Id        : " << release->getId() << endl;
		cout << "Title     : " << release->getTitle() << endl;
		cout << "ASIN      : " << release->getAsin() << endl;
		cout << "Text      : " << release->getTextLanguage() << " / " << release->getTextScript() << endl;
	}
	
	delete artist;
	
	return 0;
}

