#include <string>
#include <cppunit/extensions/HelperMacros.h>
#include <musicbrainz3/disc.h>

using namespace std;
using namespace MusicBrainz;

class DiscTest : public CppUnit::TestFixture
{
	CPPUNIT_TEST_SUITE(DiscTest);
	CPPUNIT_TEST(testDiscProperties);
	CPPUNIT_TEST(testGetSubmissionUrl);
	CPPUNIT_TEST_SUITE_END();
	
protected:

	void testDiscProperties()
	{
		Disc a("X64QNQ5GVfJUFF9MKTe3AD0wbag-");
		a.setFirstTrackNum(1);
		a.setLastTrackNum(12);
		a.setSectors(260075);
		a.addTrack(Disc::Track(150, 19912));
		a.addTrack(Disc::Track(20062, 32335));
		CPPUNIT_ASSERT_EQUAL(string("X64QNQ5GVfJUFF9MKTe3AD0wbag-"), a.getId());
		CPPUNIT_ASSERT_EQUAL(1, a.getFirstTrackNum());
		CPPUNIT_ASSERT_EQUAL(12, a.getLastTrackNum());
		CPPUNIT_ASSERT_EQUAL(260075, a.getSectors());
		CPPUNIT_ASSERT_EQUAL(2, int(a.getTracks().size()));
		CPPUNIT_ASSERT_EQUAL(150, a.getTracks()[0].first);
		CPPUNIT_ASSERT_EQUAL(32335, a.getTracks()[1].second);
	}
	
	void testGetSubmissionUrl()
	{
		Disc a("X64QNQ5GVfJUFF9MKTe3AD0wbag-");
		a.setFirstTrackNum(1);
		a.setLastTrackNum(2);
		a.setSectors(250);
		a.addTrack(Disc::Track(150, 50));
		a.addTrack(Disc::Track(200, 50));
		CPPUNIT_ASSERT_EQUAL(string("http://mm.musicbrainz.org/bare/cdlookup.html?id=X64QNQ5GVfJUFF9MKTe3AD0wbag-&toc=1+2+250+150+200&tracks=2"),
			getSubmissionUrl(&a));
	}
	
};

CPPUNIT_TEST_SUITE_REGISTRATION(DiscTest); 

