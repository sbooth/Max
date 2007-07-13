#include <vector>
#include <algorithm>
#include <cppunit/extensions/HelperMacros.h>
#include <musicbrainz3/filters.h>
#include <musicbrainz3/webservice.h>
#include <musicbrainz3/query.h>

using namespace std;
using namespace MusicBrainz;

#ifdef BUILD_WS_TESTS

class WebServiceTest : public CppUnit::TestFixture
{
	CPPUNIT_TEST_SUITE(WebServiceTest);
	CPPUNIT_TEST(testGetArtistById);
	CPPUNIT_TEST(testGetUserByName);
	CPPUNIT_TEST(testAuthenticationError);
	CPPUNIT_TEST(testResourceNotFoundError);
	CPPUNIT_TEST(testRequestError);
	CPPUNIT_TEST(testConnectionError);
	CPPUNIT_TEST_SUITE_END();
	
protected:

	void testGetArtistById()
	{
		WebService::init();
		WebService ws("test.musicbrainz.org");
		Query q(&ws, "test-1");
		Artist *a = q.getArtistById("72c536dc-7137-4477-a521-567eeb840fa8");
		CPPUNIT_ASSERT(a != NULL);
		CPPUNIT_ASSERT_EQUAL(string("Bob Dylan"), a->getName());
	}
		
	void testGetUserByName()
	{
		WebService::init();
		WebService ws("test.musicbrainz.org", 80, "/ws", "libmb_test", "libmb_test");
		Query q(&ws, "test-1");
		User *a = q.getUserByName("libmb_test");
		CPPUNIT_ASSERT(a != NULL);
		CPPUNIT_ASSERT_EQUAL(string("libmb_test"), a->getName());
	}
		
	void testAuthenticationError()
	{
		WebService::init();
		WebService ws("test.musicbrainz.org", 80, "/ws", "libmb_test", "bad_password");
		Query q(&ws, "test-1");
		CPPUNIT_ASSERT_THROW(q.getUserByName("libmb_test"), AuthenticationError);
	}
		
	void testResourceNotFoundError()
	{
		WebService::init();
		WebService ws("test.musicbrainz.org");
		Query q(&ws, "test-1");
		CPPUNIT_ASSERT_THROW(q.getArtistById("99999999-9999-9999-9999-999999999999"), ResourceNotFoundError);
	}
		
	void testRequestError()
	{
		WebService::init();
		WebService ws("test.musicbrainz.org");
		Query q(&ws, "test-1");
		TrackFilter f = TrackFilter().title("test");
		CPPUNIT_ASSERT_THROW(q.getArtists(&ArtistFilter()), RequestError);
	}
	
	void testConnectionError()
	{
		WebService::init();
		WebService ws("0.0.0.0");
		Query q(&ws, "test-1");
		CPPUNIT_ASSERT_THROW(q.getArtistById("72c536dc-7137-4477-a521-567eeb840fa8"), ConnectionError);
	}
	
};

CPPUNIT_TEST_SUITE_REGISTRATION(WebServiceTest); 

#endif
