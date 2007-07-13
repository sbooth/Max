#include <vector>
#include <algorithm>
#include <cppunit/extensions/HelperMacros.h>
#include <musicbrainz3/includes.h>

using namespace std;
using namespace MusicBrainz;

class ArtistIncludesTest : public CppUnit::TestFixture
{
	CPPUNIT_TEST_SUITE(ArtistIncludesTest);
	CPPUNIT_TEST(testIncludes1);
	CPPUNIT_TEST(testIncludes2);
	CPPUNIT_TEST(testIncludes3);
	CPPUNIT_TEST_SUITE_END();
	
protected:

	void testIncludes1()
	{
		ArtistIncludes inc1 = ArtistIncludes().aliases().releaseRelations();
		vector<string> tags1 = inc1.createIncludeTags();
		sort(tags1.begin(), tags1.end());
		CPPUNIT_ASSERT_EQUAL(string("aliases"), tags1[0]);
		CPPUNIT_ASSERT_EQUAL(string("release-rels"), tags1[1]);
	}
		
	void testIncludes2()
	{
		ArtistIncludes inc2 = ArtistIncludes().releaseRelations();
		vector<string> tags2 = inc2.createIncludeTags();
		sort(tags2.begin(), tags2.end());
		CPPUNIT_ASSERT(string("aliases") != tags2[0]);
	}
		
	void testIncludes3()
	{
		ArtistIncludes inc3 = ArtistIncludes().aliases().vaReleases("Bootleg").releases("Official");
		vector<string> tags3 = inc3.createIncludeTags();
		sort(tags3.begin(), tags3.end());
		CPPUNIT_ASSERT_EQUAL(string("aliases"), tags3[0]);
		CPPUNIT_ASSERT_EQUAL(string("sa-Official"), tags3[1]);
		CPPUNIT_ASSERT_EQUAL(string("va-Bootleg"), tags3[2]);
	}
	
};

CPPUNIT_TEST_SUITE_REGISTRATION(ArtistIncludesTest); 

