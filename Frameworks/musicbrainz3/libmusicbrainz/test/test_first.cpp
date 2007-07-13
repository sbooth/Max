#include <cppunit/extensions/HelperMacros.h>

class First : public CppUnit::TestFixture
{
	CPPUNIT_TEST_SUITE(First);
	CPPUNIT_TEST(testRun);
	CPPUNIT_TEST_SUITE_END();
	
protected:

	void testRun()
	{
		CPPUNIT_ASSERT(true);
	}
	
};

CPPUNIT_TEST_SUITE_REGISTRATION(First); 
