#include <string>
#include <cppunit/extensions/HelperMacros.h>
#include <musicbrainz3/model.h>
#include <musicbrainz3/utils.h>

using namespace std;
using namespace MusicBrainz;

class UtilsTest : public CppUnit::TestFixture
{
	CPPUNIT_TEST_SUITE(UtilsTest);
	CPPUNIT_TEST(testExtractUuidArtist);
	CPPUNIT_TEST(testExtractUuidRelease);
	CPPUNIT_TEST(testExtractUuidTrack);
	CPPUNIT_TEST(testExtractFragment);
	CPPUNIT_TEST(testGetCountryName);
	CPPUNIT_TEST(testGetLanguageName);
	CPPUNIT_TEST(testGetScriptName);
	CPPUNIT_TEST(testGetReleaseTypeName);
	CPPUNIT_TEST_SUITE_END();
	
protected:

	void testExtractUuidArtist()
	{
		string artistPrefix = "http://musicbrainz.org/artist/";
		string uuid = "c0b2500e-0cef-4130-869d-732b23ed9df5";
		string mbid = artistPrefix + uuid;
		CPPUNIT_ASSERT_EQUAL(string(), extractUuid(string()));
		CPPUNIT_ASSERT_EQUAL(uuid, extractUuid(uuid));
		CPPUNIT_ASSERT_EQUAL(uuid, extractUuid(mbid));
	}

	void testExtractUuidRelease()
	{
		string artistPrefix = "http://musicbrainz.org/release/";
		string uuid = "c0b2500e-0cef-4130-869d-732b23ed9df5";
		string mbid = artistPrefix + uuid;
		CPPUNIT_ASSERT_EQUAL(string(), extractUuid(string()));
		CPPUNIT_ASSERT_EQUAL(uuid, extractUuid(uuid));
		CPPUNIT_ASSERT_EQUAL(uuid, extractUuid(mbid));
	}

    void testExtractUuidTrack()
	{
		string artistPrefix = "http://musicbrainz.org/track/";
		string uuid = "c0b2500e-0cef-4130-869d-732b23ed9df5";
		string mbid = artistPrefix + uuid;
		CPPUNIT_ASSERT_EQUAL(string(), extractUuid(string()));
		CPPUNIT_ASSERT_EQUAL(uuid, extractUuid(uuid));
		CPPUNIT_ASSERT_EQUAL(uuid, extractUuid(mbid));
	}

	void testExtractFragment()
	{
		string fragment = "Album";
		string uri = NS_MMD_1 + fragment;
		CPPUNIT_ASSERT_EQUAL(string(), extractFragment(string()));
		CPPUNIT_ASSERT_EQUAL(fragment, extractFragment(fragment));
		CPPUNIT_ASSERT_EQUAL(fragment, extractFragment(uri));
	}
	
	void testGetCountryName()
	{
		CPPUNIT_ASSERT_EQUAL(string(), getCountryName("00"));
		CPPUNIT_ASSERT_EQUAL(string("Slovakia"), getCountryName("SK"));
		CPPUNIT_ASSERT_EQUAL(string("Czechoslovakia (historical, 1918-1992)"), getCountryName("XC"));
	}
	
	void testGetLanguageName()
	{
		CPPUNIT_ASSERT_EQUAL(string(), getLanguageName("000"));
		CPPUNIT_ASSERT_EQUAL(string("Slovak"), getLanguageName("SLK"));
		CPPUNIT_ASSERT_EQUAL(string("Czech"), getLanguageName("CES"));
	}
	
	void testGetScriptName()
	{
		CPPUNIT_ASSERT_EQUAL(string(), getScriptName("-"));
		CPPUNIT_ASSERT_EQUAL(string("Latin"), getScriptName("Latn"));
		CPPUNIT_ASSERT_EQUAL(string("Cyrillic"), getScriptName("Cyrl"));
	}
	
	void testGetReleaseTypeName()
	{
		CPPUNIT_ASSERT_EQUAL(string(), getReleaseTypeName("-"));
		CPPUNIT_ASSERT_EQUAL(string("Album"), getReleaseTypeName(Release::TYPE_ALBUM));
		CPPUNIT_ASSERT_EQUAL(string("Compilation"), getReleaseTypeName(Release::TYPE_COMPILATION));
	}
};

CPPUNIT_TEST_SUITE_REGISTRATION(UtilsTest); 

