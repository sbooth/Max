#include <cppunit/TestResult.h>
#include <cppunit/TestResultCollector.h> 
#include <cppunit/TestRunner.h>
#include <cppunit/extensions/TestFactoryRegistry.h>
#include <cppunit/BriefTestProgressListener.h> 
#include <cppunit/CompilerOutputter.h> 

int 
main(int argc, char **argv)
{
	// Create the event manager and test controller
	CppUnit::TestResult controller;		
	
	// Add a listener that colllects test result
	CppUnit::TestResultCollector result;
	controller.addListener(&result);		

	// Add a listener that print dots as test run.
	CppUnit::BriefTestProgressListener progress;
	controller.addListener(&progress);	 

	// Add the top suite to the test runner	  
	CppUnit::TestRunner runner;
	runner.addTest(CppUnit::TestFactoryRegistry::getRegistry().makeTest());
	runner.run(controller);
 
	// Print test in a compiler compatible format.
	CppUnit::CompilerOutputter outputter( &result, std::cerr );
	outputter.write();
	
	return result.wasSuccessful() ? 0 : 1;
}

