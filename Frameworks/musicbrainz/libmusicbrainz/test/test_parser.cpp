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

class BaseParserTest : public CppUnit::TestFixture
{
	CPPUNIT_TEST_SUITE(BaseParserTest);
	CPPUNIT_TEST(testEmptyValid);
	CPPUNIT_TEST(testEmptyInvalid);
	CPPUNIT_TEST_SUITE_END();

protected:

	void testEmptyValid()
	{
		try {
			MbXmlParser().parse(get_file_contents("../test-data/valid/artist/empty_1.xml"));
		}
		catch (ParseError) {
			CPPUNIT_FAIL("empty_1.xml");
		}
		
		try {
			MbXmlParser().parse(get_file_contents("../test-data/valid/artist/empty_2.xml"));
		}
		catch (ParseError) {
			CPPUNIT_FAIL("empty_2.xml");
		}
	}

	void testEmptyInvalid()
	{
		bool error = false;
		try { 
			MbXmlParser().parse(get_file_contents("../test-data/invalid/artist/empty_1.xml"));
		}
		catch (ParseError) { 
			error = true;
		}
		if (!error)
			CPPUNIT_FAIL("empty_1.xml");

		error = false;
		try {
			MbXmlParser().parse(get_file_contents("../test-data/invalid/artist/empty_2.xml"));
		}
		catch (ParseError) { 
			error = true;
		}
		if (!error)
			CPPUNIT_FAIL("empty_2.xml");

		/*error = false;
		try { 
			MbXmlParser().parse(get_file_contents("../test-data/invalid/artist/empty_3.xml"));
		}
		catch (ParseError) { 
			error = true;
		}
		if (!error)
			CPPUNIT_FAIL("empty_3.xml");*/
	}

};

CPPUNIT_TEST_SUITE_REGISTRATION(BaseParserTest);

