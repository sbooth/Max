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

class ParseUserTest : public CppUnit::TestFixture
{
	CPPUNIT_TEST_SUITE(ParseUserTest);
	CPPUNIT_TEST(testUser);
	CPPUNIT_TEST(testUserTypes);
	CPPUNIT_TEST_SUITE_END();
	
protected:

	void testUser()
	{
		Metadata *md = MbXmlParser().parse(get_file_contents("../test-data/valid/user/User_1.xml"));
		UserList &ul = md->getUserList();
		CPPUNIT_ASSERT_EQUAL(1, int(ul.size()));
		CPPUNIT_ASSERT_EQUAL(string("matt"), ul[0]->getName());
		CPPUNIT_ASSERT_EQUAL(false, ul[0]->getShowNag());
	}
	
	void testUserTypes()
	{
		Metadata *md = MbXmlParser().parse(get_file_contents("../test-data/valid/user/User_1.xml"));
		const vector<string> &types = md->getUserList()[0]->getTypes();
		bool isAutoEditor = false;
		bool isRelationshipEditor = false;
		for (vector<string>::const_iterator i = types.begin(); i != types.end(); i++) {
			if (*i == NS_EXT_1 + "AutoEditor")
				isAutoEditor = true;
			else if (*i == NS_EXT_1 + "RelationshipEditor")
				isRelationshipEditor = true;
			else
				CPPUNIT_FAIL(*i);
		}
		CPPUNIT_ASSERT(isAutoEditor);
		CPPUNIT_ASSERT(isRelationshipEditor);
	}
	
};

CPPUNIT_TEST_SUITE_REGISTRATION(ParseUserTest); 

