#include <fstream>
#include <string>
#include <iostream>
#include <cppunit/extensions/HelperMacros.h>
#include <musicbrainz3/mbxmlparser.h>
#include <musicbrainz3/metadata.h>
#include <musicbrainz3/model.h>

using namespace std;
using namespace MusicBrainz;

#include "read_file.h"

class ParseReleaseTest : public CppUnit::TestFixture
{
	CPPUNIT_TEST_SUITE(ParseReleaseTest);
	CPPUNIT_TEST(testReleaseBasic);
	CPPUNIT_TEST(testReleaseIncompleteTrackList);
	CPPUNIT_TEST(testReleaseArtist);
	CPPUNIT_TEST(testReleaseDiscs);
	CPPUNIT_TEST(testReleaseEvents);
	CPPUNIT_TEST(testReleaseEvents2);
	CPPUNIT_TEST(testReleaseTracks);
	CPPUNIT_TEST(testReleaseTracksVA);
	CPPUNIT_TEST(testReleaseSearch);
	CPPUNIT_TEST(testReleaseTags);
	CPPUNIT_TEST_SUITE_END();
	
protected:

	void testReleaseBasic()
	{
		Metadata *md = MbXmlParser().parse(get_file_contents("../test-data/valid/release/Under_the_Pink_1.xml"));
		Release *release = md->getRelease();
		CPPUNIT_ASSERT(release);
		CPPUNIT_ASSERT_EQUAL(string("http://musicbrainz.org/release/290e10c5-7efc-4f60-ba2c-0dfc0208fbf5"), release->getId());
		CPPUNIT_ASSERT_EQUAL(string("Under the Pink"), release->getTitle());
		CPPUNIT_ASSERT_EQUAL(string("B000002IXU"), release->getAsin());
		CPPUNIT_ASSERT_EQUAL(string("ENG"), release->getTextLanguage());
		CPPUNIT_ASSERT_EQUAL(string("Latn"), release->getTextScript());
		CPPUNIT_ASSERT_EQUAL(2, release->getNumTypes());
		CPPUNIT_ASSERT_EQUAL(NS_MMD_1 + string("Album"), release->getType(0));
		CPPUNIT_ASSERT_EQUAL(0, release->getTracksOffset());
	}
	
	void testReleaseIncompleteTrackList()
	{
		Metadata *md = MbXmlParser().parse(get_file_contents("../test-data/valid/release/Under_the_Pink_2.xml"));
		Release *release = md->getRelease();
		CPPUNIT_ASSERT(release);
		CPPUNIT_ASSERT_EQUAL(1, release->getTracksOffset());
		CPPUNIT_ASSERT_EQUAL(12, release->getTracksCount());
	}
	
	void testReleaseArtist()
	{
		Metadata *md = MbXmlParser().parse(get_file_contents("../test-data/valid/release/Under_the_Pink_1.xml"));
		Release *release = md->getRelease();
		CPPUNIT_ASSERT(release);
		Artist *artist = release->getArtist();
		CPPUNIT_ASSERT(artist);
		CPPUNIT_ASSERT_EQUAL(string("http://musicbrainz.org/artist/c0b2500e-0cef-4130-869d-732b23ed9df5"), artist->getId());
		CPPUNIT_ASSERT_EQUAL(string("Tori Amos"), artist->getName());
	}
	
	void testReleaseDiscs()
	{
		Metadata *md = MbXmlParser().parse(get_file_contents("../test-data/valid/release/Little_Earthquakes_1.xml"));
		Release *release = md->getRelease();
		CPPUNIT_ASSERT(release);
		DiscList &discs = release->getDiscs();
		CPPUNIT_ASSERT_EQUAL(3, int(discs.size()));
		CPPUNIT_ASSERT_EQUAL(string("ejdrdtX1ZyvCb0g6vfJejVaLIK8-"), discs[1]->getId());
	}
	
	void testReleaseEvents()
	{
		Metadata *md = MbXmlParser().parse(get_file_contents("../test-data/valid/release/Little_Earthquakes_1.xml"));
		Release *release = md->getRelease();
		CPPUNIT_ASSERT(release);
		ReleaseEventList &re = release->getReleaseEvents();
		CPPUNIT_ASSERT_EQUAL(3, int(re.size()));
		CPPUNIT_ASSERT_EQUAL(string("DE"), re[1]->getCountry());
		CPPUNIT_ASSERT_EQUAL(string("1992-02-25"), re[2]->getDate());
	}
	
	void testReleaseEvents2()
	{
		Metadata *md = MbXmlParser().parse(get_file_contents("../test-data/valid/release/Under_the_Pink_3.xml"));
		Release *release = md->getRelease();
		CPPUNIT_ASSERT(release);
		ReleaseEventList &re = release->getReleaseEvents();
		CPPUNIT_ASSERT_EQUAL(1, int(re.size()));
		CPPUNIT_ASSERT_EQUAL(string("82567-2"), re[0]->getCatalogNumber());
		CPPUNIT_ASSERT_EQUAL(string("07567825672"), re[0]->getBarcode());
		CPPUNIT_ASSERT(re[0]->getLabel());
		CPPUNIT_ASSERT_EQUAL(string("Atlantic Records"), re[0]->getLabel()->getName());
	}
	
	void testReleaseTracks()
	{
		Metadata *md = MbXmlParser().parse(get_file_contents("../test-data/valid/release/Highway_61_Revisited_1.xml"));
		Release *release = md->getRelease();
		CPPUNIT_ASSERT(release);
		TrackList &tracks = release->getTracks();
		CPPUNIT_ASSERT_EQUAL(9, int(tracks.size()));
		CPPUNIT_ASSERT_EQUAL(373333, tracks[0]->getDuration());
		CPPUNIT_ASSERT_EQUAL(string("Tombstone Blues"), tracks[1]->getTitle());
		CPPUNIT_ASSERT_EQUAL(string("http://musicbrainz.org/track/525dc658-e6cb-4923-80d9-a77e93ef4d33"), tracks[2]->getId());
	}
	
	void testReleaseTracksVA()
	{
		Metadata *md = MbXmlParser().parse(get_file_contents("../test-data/valid/release/Mission_Impossible_2.xml"));
		Release *release = md->getRelease();
		CPPUNIT_ASSERT(release);
		TrackList &tracks = release->getTracks();
		CPPUNIT_ASSERT_EQUAL(16, int(tracks.size()));
		Artist *artist = tracks[1]->getArtist();
		CPPUNIT_ASSERT(artist);
		CPPUNIT_ASSERT_EQUAL(string("1981"), artist->getBeginDate());
		CPPUNIT_ASSERT_EQUAL(string("Metallica"), artist->getName());
		CPPUNIT_ASSERT_EQUAL(string("Metallica"), artist->getSortName());
		CPPUNIT_ASSERT_EQUAL(Artist::TYPE_GROUP, artist->getType());
	}
	
	void testReleaseSearch()
	{
		Metadata *md = MbXmlParser().parse(get_file_contents("../test-data/valid/release/search_result_1.xml"));
		ReleaseResultList r = md->getReleaseResults();
		
		CPPUNIT_ASSERT_EQUAL(2, int(r.size()));
		CPPUNIT_ASSERT_EQUAL(100, r[0]->getScore());
		CPPUNIT_ASSERT_EQUAL(80, r[1]->getScore());
		CPPUNIT_ASSERT_EQUAL(string("http://musicbrainz.org/release/005fe18b-144b-4fee-81c0-e04737a23500"), r[1]->getRelease()->getId());
	}
	
	void testReleaseTags()
	{
		Metadata *md = MbXmlParser().parse(get_file_contents("../test-data/valid/release/Highway_61_Revisited_2.xml"));
		const TagList &t = md->getRelease()->getTags();
		
		CPPUNIT_ASSERT_EQUAL(4, int(t.size()));
		CPPUNIT_ASSERT_EQUAL(string("rock"), t[0]->getName());
		CPPUNIT_ASSERT_EQUAL(100, t[0]->getCount());
		CPPUNIT_ASSERT_EQUAL(string("dylan"), t[3]->getName());
		CPPUNIT_ASSERT_EQUAL(4, t[3]->getCount());
	}
	
};

CPPUNIT_TEST_SUITE_REGISTRATION(ParseReleaseTest); 

