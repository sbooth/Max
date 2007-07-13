#include <vector>
#include <algorithm>
#include <cppunit/extensions/HelperMacros.h>
#include <musicbrainz3/release.h>
#include <musicbrainz3/filters.h>

using namespace std;
using namespace MusicBrainz;

class FiltersTest : public CppUnit::TestFixture
{
	CPPUNIT_TEST_SUITE(FiltersTest);
	CPPUNIT_TEST(testArtistFilter1);
	CPPUNIT_TEST(testArtistFilter2);
	CPPUNIT_TEST(testArtistFilter3);
	CPPUNIT_TEST(testReleaseTypeFilter);
	CPPUNIT_TEST(testUserFilter);
	CPPUNIT_TEST_SUITE_END();
	
protected:

	void testArtistFilter1()
	{
		ArtistFilter flt1 = ArtistFilter().name("Jean Michel Jarre");
		ArtistFilter::ParameterList pars1 = flt1.createParameters();
		CPPUNIT_ASSERT_EQUAL(string("name"), pars1[0].first);
		CPPUNIT_ASSERT_EQUAL(string("Jean Michel Jarre"), pars1[0].second);
	}
		
	void testArtistFilter2()
	{
		ArtistFilter flt2 = ArtistFilter().limit(33);
		ArtistFilter::ParameterList pars2 = flt2.createParameters();
		CPPUNIT_ASSERT(string("name") != pars2[0].first);
		CPPUNIT_ASSERT(string("Jean Michel Jarre") != pars2[0].second);
	}
		
	void testArtistFilter3()
	{
		ArtistFilter flt3 = ArtistFilter().limit(33);
		ArtistFilter::ParameterList pars3 = flt3.createParameters();
		CPPUNIT_ASSERT_EQUAL(string("limit"), pars3[0].first);
		CPPUNIT_ASSERT_EQUAL(string("33"), pars3[0].second);
	}
	
	void testReleaseTypeFilter()
	{
		ReleaseFilter flt3 = ReleaseFilter().releaseType(Release::TYPE_ALBUM).releaseType(Release::TYPE_OFFICIAL);
		ReleaseFilter::ParameterList pars3 = flt3.createParameters();
		CPPUNIT_ASSERT_EQUAL(string("releasetypes"), pars3[0].first);
		CPPUNIT_ASSERT_EQUAL(string("Album Official"), pars3[0].second);
	}
	
	void testUserFilter()
	{
		UserFilter flt1 = UserFilter().name("lukz");
		UserFilter::ParameterList pars1 = flt1.createParameters();
		CPPUNIT_ASSERT_EQUAL(string("name"), pars1[0].first);
		CPPUNIT_ASSERT_EQUAL(string("lukz"), pars1[0].second);
	}
	
};

CPPUNIT_TEST_SUITE_REGISTRATION(FiltersTest); 

