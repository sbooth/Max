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

class ParseArtistTest : public CppUnit::TestFixture
{
	CPPUNIT_TEST_SUITE(ParseArtistTest);
	CPPUNIT_TEST(testArtistBasic);
	CPPUNIT_TEST(testArtistAliases);
	CPPUNIT_TEST(testArtistReleases);
	CPPUNIT_TEST(testArtistIncompleteReleaseList);
	CPPUNIT_TEST(testArtistRelations);
	CPPUNIT_TEST(testArtistTags);
	CPPUNIT_TEST(testSearchResults);
	CPPUNIT_TEST_SUITE_END();
	
protected:

	void testArtistBasic()
	{
		Metadata *md = MbXmlParser().parse(get_file_contents("../test-data/valid/artist/Tori_Amos_1.xml"));
		Artist *artist = md->getArtist();
		
		CPPUNIT_ASSERT(artist);
		CPPUNIT_ASSERT_EQUAL(string("http://musicbrainz.org/artist/c0b2500e-0cef-4130-869d-732b23ed9df5"), artist->getId());
		CPPUNIT_ASSERT_EQUAL(string("Tori Amos"), artist->getName());
		CPPUNIT_ASSERT_EQUAL(string("Amos, Tori"), artist->getSortName());
		CPPUNIT_ASSERT_EQUAL(string("1963-08-22"), artist->getBeginDate());
		CPPUNIT_ASSERT_EQUAL(0, int(artist->getReleases().size()));
	}
	
	void testArtistAliases()
	{
		Metadata *md = MbXmlParser().parse(get_file_contents("../test-data/valid/artist/Tori_Amos_4.xml"));
		const ArtistAliasList &al = md->getArtist()->getAliases();
		
		CPPUNIT_ASSERT_EQUAL(3, int(al.size()));
		CPPUNIT_ASSERT_EQUAL(string("Myra Ellen Amos"), al[0]->getValue());
		CPPUNIT_ASSERT_EQUAL(string("Latn"), al[2]->getScript());
		CPPUNIT_ASSERT_EQUAL(string(NS_MMD_1 + "Misspelling"), al[2]->getType());
	}
	
	void testArtistTags()
	{
		Metadata *md = MbXmlParser().parse(get_file_contents("../test-data/valid/artist/Tchaikovsky-2.xml"));
		const TagList &t = md->getArtist()->getTags();
		
		CPPUNIT_ASSERT_EQUAL(4, int(t.size()));
		CPPUNIT_ASSERT_EQUAL(string("classical"), t[0]->getName());
		CPPUNIT_ASSERT_EQUAL(100, t[0]->getCount());
		CPPUNIT_ASSERT_EQUAL(string("composer"), t[3]->getName());
		CPPUNIT_ASSERT_EQUAL(120, t[3]->getCount());
	}
	
	void testArtistReleases()
	{
		Metadata *md = MbXmlParser().parse(get_file_contents("../test-data/valid/artist/Tori_Amos_2.xml"));
		const ReleaseList &re = md->getArtist()->getReleases();
		
		CPPUNIT_ASSERT_EQUAL(3, int(re.size()));
		CPPUNIT_ASSERT_EQUAL(string("To Venus and Back (disc 1: Orbiting)"), re[1]->getTitle());
		CPPUNIT_ASSERT_EQUAL(3, int(re[1]->getReleaseEvents().size()));
		CPPUNIT_ASSERT_EQUAL(string("DE"), re[2]->getReleaseEvents()[0]->getCountry());
	}
	
	void testArtistIncompleteReleaseList()
	{
		Metadata *md = MbXmlParser().parse(get_file_contents("../test-data/valid/artist/Tori_Amos_5.xml"));
		Artist *artist = md->getArtist();
		CPPUNIT_ASSERT(artist);
		CPPUNIT_ASSERT_EQUAL(6, artist->getReleasesOffset());
		CPPUNIT_ASSERT_EQUAL(9, artist->getReleasesCount());
	}
	
	void testSearchResults()
	{
		Metadata *md = MbXmlParser().parse(get_file_contents("../test-data/valid/artist/search_result_1.xml"));
		ArtistResultList &results = md->getArtistResults();
		CPPUNIT_ASSERT_EQUAL(3, int(results.size()));
		CPPUNIT_ASSERT_EQUAL(100, results[0]->getScore());
		CPPUNIT_ASSERT_EQUAL(string("Tori Amos"), results[0]->getArtist()->getName());
	}
	
	void testArtistRelations()
	{
		Metadata *md = MbXmlParser().parse(get_file_contents("../test-data/valid/artist/Tori_Amos_3.xml"));
		const RelationList &re = md->getArtist()->getRelations();
		
		CPPUNIT_ASSERT_EQUAL(3, int(re.size()));
		CPPUNIT_ASSERT_EQUAL(NS_REL_1 + "Married", re[0]->getType());
		CPPUNIT_ASSERT_EQUAL(NS_REL_1 + "Discography", re[1]->getType());
		CPPUNIT_ASSERT_EQUAL(string("1998"), re[0]->getBeginDate());
		
		Artist *ar = static_cast<Artist *>(re[0]->getTarget());
		CPPUNIT_ASSERT_EQUAL(string("Mark Hawley"), ar->getName());
		
		CPPUNIT_ASSERT_EQUAL(string("http://www.yessaid.com/albums.html"), re[1]->getTargetId());
	}
	
};

CPPUNIT_TEST_SUITE_REGISTRATION(ParseArtistTest); 

