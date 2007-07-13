#include <string>
#include <cppunit/extensions/HelperMacros.h>
#include <musicbrainz3/model.h>
#include <musicbrainz3/filters.h>

using namespace std;
using namespace MusicBrainz;

class ModelTest : public CppUnit::TestFixture
{
	CPPUNIT_TEST_SUITE(ModelTest);
	CPPUNIT_TEST(testArtistProperties);
	CPPUNIT_TEST(testArtistUniqueName);
	CPPUNIT_TEST(testArtistReleases);
	CPPUNIT_TEST(testArtistAliases);
	CPPUNIT_TEST(testTrackProperties);
	CPPUNIT_TEST(testReleaseEventProperties);
	CPPUNIT_TEST(testArtistAliasProperties);
	CPPUNIT_TEST(testUserTypes);
	CPPUNIT_TEST(testAddRelation);
	CPPUNIT_TEST(testGetRelations);
	CPPUNIT_TEST_SUITE_END();
	
protected:

	void testArtistProperties()
	{
		Artist a("86e2e2ad-6d1b-44fd-9463-b6683718a1cc", Artist::TYPE_PERSON, "Jean Michel Jarre", "Jarre, Jean Michel");
		CPPUNIT_ASSERT_EQUAL(string("86e2e2ad-6d1b-44fd-9463-b6683718a1cc"), a.getId());
		CPPUNIT_ASSERT_EQUAL(Artist::TYPE_PERSON, a.getType());
		CPPUNIT_ASSERT_EQUAL(string("Jean Michel Jarre"), a.getName());
		CPPUNIT_ASSERT_EQUAL(string("Jarre, Jean Michel"), a.getSortName());
		Artist b;
		b.setId("86e2e2ad-6d1b-44fd-9463-b6683718a1cc");
		b.setType(Artist::TYPE_PERSON);
		b.setName("Jean Michel Jarre");
		b.setSortName("Jarre, Jean Michel");
		b.setBeginDate("1948-08-24");
		b.setEndDate("1948-08-25");
		CPPUNIT_ASSERT_EQUAL(string("86e2e2ad-6d1b-44fd-9463-b6683718a1cc"), b.getId());
		CPPUNIT_ASSERT_EQUAL(Artist::TYPE_PERSON, b.getType());
		CPPUNIT_ASSERT_EQUAL(string("Jean Michel Jarre"), b.getName());
		CPPUNIT_ASSERT_EQUAL(string("Jarre, Jean Michel"), b.getSortName());
		CPPUNIT_ASSERT_EQUAL(string("1948-08-24"), b.getBeginDate());
		CPPUNIT_ASSERT_EQUAL(string("1948-08-25"), b.getEndDate());
	}
	
	void testArtistUniqueName()
	{
		Artist a("", Artist::TYPE_PERSON, "Jean Michel Jarre");
		CPPUNIT_ASSERT_EQUAL(string("Jean Michel Jarre"), a.getUniqueName());
		a.setDisambiguation("Test");
		CPPUNIT_ASSERT_EQUAL(string("Jean Michel Jarre (Test)"), a.getUniqueName());
	}
	
	void testArtistReleases()
	{
		Artist a("", Artist::TYPE_PERSON, "Jean Michel Jarre");
		a.addRelease(new Release("8813e1f4-18a6-4cc2-b723-35da00af622d"));
		a.addRelease(new Release("-"));
		CPPUNIT_ASSERT_EQUAL(2, int(a.getReleases().size()));
		CPPUNIT_ASSERT_EQUAL(2, a.getNumReleases());
		CPPUNIT_ASSERT_EQUAL(string("-"), a.getReleases()[1]->getId());
		CPPUNIT_ASSERT_EQUAL(string("-"), a.getRelease(1)->getId());
	}
	
	void testArtistAliases()
	{
		Artist a("", Artist::TYPE_PERSON, "Jean Michel Jarre");
		a.addAlias(new ArtistAlias("Jarre"));
		a.addAlias(new ArtistAlias("JMJ"));
		CPPUNIT_ASSERT_EQUAL(2, int(a.getAliases().size()));
		CPPUNIT_ASSERT_EQUAL(2, a.getNumAliases());
		CPPUNIT_ASSERT_EQUAL(string("JMJ"), a.getAliases()[1]->getValue());
		CPPUNIT_ASSERT_EQUAL(string("JMJ"), a.getAlias(1)->getValue());
	}
	
	void testTrackProperties()
	{
		Track a("8813e1f4-18a6-4cc2-b723-35da00af622d", "Aerozone");
		CPPUNIT_ASSERT_EQUAL(string("8813e1f4-18a6-4cc2-b723-35da00af622d"), a.getId());
		CPPUNIT_ASSERT_EQUAL(string("Aerozone"), a.getTitle());
		Track b;
		b.setId("8813e1f4-18a6-4cc2-b723-35da00af622d");
		b.setTitle("Aerozone");
		CPPUNIT_ASSERT_EQUAL(string("8813e1f4-18a6-4cc2-b723-35da00af622d"), b.getId());
		CPPUNIT_ASSERT_EQUAL(string("Aerozone"), b.getTitle());
	}
	
	void testReleaseEventProperties()
	{
		ReleaseEvent a("SK", "2006-05-26");
		CPPUNIT_ASSERT_EQUAL(string("SK"), a.getCountry());
		CPPUNIT_ASSERT_EQUAL(string("2006-05-26"), a.getDate());
		ReleaseEvent b;
		b.setCountry("SK");
		b.setDate("2006-05-26");
		CPPUNIT_ASSERT_EQUAL(string("SK"), b.getCountry());
		CPPUNIT_ASSERT_EQUAL(string("2006-05-26"), b.getDate());
	}
	
	void testArtistAliasProperties()
	{
		ArtistAlias a("小室哲哉", NS_MMD_1 + "Name", "Hrkt");
		CPPUNIT_ASSERT_EQUAL(string("小室哲哉"), a.getValue());
		CPPUNIT_ASSERT_EQUAL(NS_MMD_1 + string("Name"), a.getType());
		CPPUNIT_ASSERT_EQUAL(string("Hrkt"), a.getScript());
		ArtistAlias b;
		b.setValue("小室哲哉");
		b.setType(NS_MMD_1 + string("Name"));
		b.setScript("Hrkt");
		CPPUNIT_ASSERT_EQUAL(string("小室哲哉"), b.getValue());
		CPPUNIT_ASSERT_EQUAL(NS_MMD_1 + string("Name"), b.getType());
		CPPUNIT_ASSERT_EQUAL(string("Hrkt"), b.getScript());
	}
	
	void testAddRelation()
	{
		Relation *rel = new Relation("Producer", Relation::TO_RELEASE, "al_id");
		Artist artist("ar_id", "Tori Amos", Artist::TYPE_PERSON);
		artist.addRelation(rel);

		Relation *rel2 = artist.getRelations()[0];
		CPPUNIT_ASSERT_EQUAL(rel->getType(), rel2->getType());
		CPPUNIT_ASSERT_EQUAL(rel->getTargetType(), rel2->getTargetType());
		CPPUNIT_ASSERT_EQUAL(rel->getTargetId(), rel2->getTargetId());
		CPPUNIT_ASSERT_EQUAL(rel->getAttributes().size(), rel2->getAttributes().size());
		CPPUNIT_ASSERT_EQUAL(rel->getBeginDate(), rel2->getBeginDate());
		CPPUNIT_ASSERT_EQUAL(rel->getEndDate(), rel2->getEndDate());
	}
	
	void testGetRelations()
	{
		Relation *rel = new Relation("Producer", Relation::TO_RELEASE, "al_id");
		Relation *rel2 = new Relation("Wikipedia", Relation::TO_URL, "http://en.wikipedia.org/Tori_Amos");
		Artist artist("ar_id", "Tori Amos", Artist::TYPE_PERSON);
		artist.addRelation(rel);
		artist.addRelation(rel2);

		RelationList list1 = artist.getRelations();
		RelationList list2 = artist.getRelations(Relation::TO_RELEASE);
		RelationList list3 = artist.getRelations("", "Producer");
		RelationList list4 = artist.getRelations(Relation::TO_RELEASE, "Producer");
		RelationList list5 = artist.getRelations(Relation::TO_RELEASE, "Wikipedia");
		RelationList list6 = artist.getRelations("", "Wikipedia");
		CPPUNIT_ASSERT_EQUAL(2, int(list1.size()));
		CPPUNIT_ASSERT_EQUAL(1, int(list2.size()));
		CPPUNIT_ASSERT_EQUAL(1, int(list3.size()));
		CPPUNIT_ASSERT_EQUAL(1, int(list4.size()));
		CPPUNIT_ASSERT_EQUAL(0, int(list5.size()));
		CPPUNIT_ASSERT_EQUAL(1, int(list6.size()));
	}
	
	void testUserTypes()
	{
		User a;
		a.addType(NS_MMD_1 + "AutoEditor");
		a.addType(NS_MMD_1 + "NotNaggable");
		CPPUNIT_ASSERT_EQUAL(2, int(a.getTypes().size()));
		CPPUNIT_ASSERT_EQUAL(NS_MMD_1 + "NotNaggable", a.getTypes()[1]);
	}	
	
};

CPPUNIT_TEST_SUITE_REGISTRATION(ModelTest); 

