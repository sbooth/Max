/*
 * MusicBrainz -- The Internet music metadatabase
 *
 * Copyright (C) 2006 Lukas Lalinsky
 *	
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 * 
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	 See the GNU
 * Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
 *
 * $Id: mbxmlparser.cpp 9218 2007-06-25 20:11:09Z luks $
 */
 
// TODO: support for namespaces and full MMD 
 
#include <string>
#include <iostream>
#include <cctype>
#include <algorithm>
#include <cstring>
#include <musicbrainz3/utils.h>
#include <musicbrainz3/factory.h>
#include <musicbrainz3/mbxmlparser.h>
#include "xmlParser/xmlParser.h"

using namespace std;
using namespace MusicBrainz;

class MbXmlParser::MbXmlParserPrivate
{
public:
	MbXmlParserPrivate(/*IFactory *factory*/)/* : factory(factory)*/ {}

	Relation *createRelation(XMLNode node, const string &targetType);
	void addRelationsToEntity(XMLNode listNode, Entity *entity);
	
	template<typename T, typename TL>
	void addToList(XMLNode listNode, TL &resultList, T *(MbXmlParserPrivate::*creator)(XMLNode));
	
	void addArtistsToList(XMLNode listNode, ArtistList &resultList);
	void addArtistAliasesToList(XMLNode listNode, ArtistAliasList &resultList);
	void addDiscsToList(XMLNode listNode, DiscList &resultList);
	void addReleasesToList(XMLNode listNode, ReleaseList &resultList);
	void addReleaseEventsToList(XMLNode listNode, ReleaseEventList &resultList);
	void addTracksToList(XMLNode listNode, TrackList &resultList);
	void addUsersToList(XMLNode listNode, UserList &resultList);
	void addTagsToList(XMLNode listNode, TagList &resultList);
	void addLabelAliasesToList(XMLNode listNode, LabelAliasList &resultList);

	template<typename T, typename TL, typename TR>
	void addResults(XMLNode listNode, TL &resultList, T *(MbXmlParserPrivate::*creator)(XMLNode));
	
	void addArtistResults(XMLNode listNode, ArtistResultList &resultList);
	void addReleaseResults(XMLNode listNode, ReleaseResultList &resultList);
	void addTrackResults(XMLNode listNode, TrackResultList &resultList);
	
	Artist *createArtist(XMLNode artistNode);
	ArtistAlias *createArtistAlias(XMLNode artistAliasNode);
	Disc *createDisc(XMLNode artistNode);
	Release *createRelease(XMLNode releaseNode);
	ReleaseEvent *createReleaseEvent(XMLNode releaseNode);
	Track *createTrack(XMLNode releaseNode);
	User *createUser(XMLNode releaseNode);
	Tag *createTag(XMLNode releaseNode);
	Label *createLabel(XMLNode releaseNode);
	LabelAlias *createLabelAlias(XMLNode releaseNode);

	DefaultFactory factory;
};

static bool
getBoolAttr(XMLNode node, string name)
{
	const char *value = node.getAttribute(name.c_str());
	return value ? value == "true" : false;
}

static int
getIntAttr(XMLNode node, string name, int def = 0)
{
	const char *value = node.getAttribute(name.c_str());
	return value ? atoi(value) : def;
}

static string
getTextAttr(XMLNode node, string name, string def = "")
{
	const char *value = node.getAttribute(name.c_str());
	return value ? string(value) : string(def);
}

static string
getUriAttr(XMLNode node, string name, string ns = NS_MMD_1)
{
	const char *value = node.getAttribute(name.c_str());
	if (!value)
		return string();
	string text = string(value);
	return ns + extractFragment(text);
}

static string
getIdAttr(XMLNode node, string name, string typeName)
{
	string uriStr = getTextAttr(node, name);
	string prefix = "http://musicbrainz.org/" + typeName + "/"; 
	return prefix + uriStr; 
}

static vector<string>
getUriListAttr(XMLNode node, string name, string ns = NS_MMD_1)
{
	vector<string> uriList;
	const char *value = node.getAttribute(name.c_str());
	if (!value)
		return uriList;
	string text = string(value);
	string::size_type pos = 0;
	while (pos < text.size()) {
		string::size_type end = text.find(' ', pos);
		if (pos == end) 
			break;
		string word = extractFragment(text.substr(pos, end - pos));
		uriList.push_back(ns + word);
		pos = text.find_first_not_of(' ', end);
	}
	return uriList;
}

static string
getText(XMLNode node)
{
	string text;
	for (int i = 0; i < node.nText(); i++) 
		text += node.getText(i);
	return text;
} 

static int
getInt(XMLNode node, int def = 0)
{
	string text = getText(node);
	return text.empty() ? def : atoi(text.c_str());
} 

Artist *
MbXmlParser::MbXmlParserPrivate::createArtist(XMLNode artistNode)
{
	Artist *artist = factory.newArtist();
	artist->setId(getIdAttr(artistNode, "id", "artist"));
	artist->setType(getUriAttr(artistNode, "type"));
	for (int i = 0; i < artistNode.nChildNode(); i++) {
		XMLNode node = artistNode.getChildNode(i);
		string name = node.getName(); 
		if (name == "name") {
			artist->setName(getText(node));
		}
		else if (name == "sort-name") {
			artist->setSortName(getText(node));
		}
		else if (name == "disambiguation") {
			artist->setDisambiguation(getText(node));
		}
		else if (name == "life-span") {
			const char *begin = node.getAttribute("begin");
			const char *end = node.getAttribute("end");
			if (begin)
				artist->setBeginDate(string(begin));
			if (end)
				artist->setEndDate(string(end));
		}
		else if (name == "alias-list") {
			addArtistAliasesToList(node, artist->getAliases());
		}
		else if (name == "release-list") {
			artist->setReleasesOffset(getIntAttr(node, "offset"));
			artist->setReleasesCount(getIntAttr(node, "count"));
			addReleasesToList(node, artist->getReleases());
		}
		else if (name == "relation-list") {
			addRelationsToEntity(node, artist);
		}
		else if (name == "tag-list") {
			addTagsToList(node, artist->getTags());
		}
	}
	return artist; 
}

ArtistAlias *
MbXmlParser::MbXmlParserPrivate::createArtistAlias(XMLNode node)
{
	ArtistAlias *alias = factory.newArtistAlias();
	alias->setType(getUriAttr(node, "type"));
	alias->setScript(getTextAttr(node, "script"));
	alias->setValue(getText(node));
	return alias;
}

Label *
MbXmlParser::MbXmlParserPrivate::createLabel(XMLNode labelNode)
{
	Label *label = factory.newLabel();
	label->setId(getIdAttr(labelNode, "id", "label"));
	label->setType(getUriAttr(labelNode, "type"));
	for (int i = 0; i < labelNode.nChildNode(); i++) {
		XMLNode node = labelNode.getChildNode(i);
		string name = node.getName(); 
		if (name == "name") {
			label->setName(getText(node));
		}
		else if (name == "sort-name") {
			label->setSortName(getText(node));
		}
		else if (name == "disambiguation") {
			label->setDisambiguation(getText(node));
		}
		else if (name == "life-span") {
			const char *begin = node.getAttribute("begin");
			const char *end = node.getAttribute("end");
			if (begin)
				label->setBeginDate(string(begin));
			if (end)
				label->setEndDate(string(end));
		}
		else if (name == "alias-list") {
			addLabelAliasesToList(node, label->getAliases());
		}
		else if (name == "release-list") {
			label->setReleasesOffset(getIntAttr(node, "offset"));
			label->setReleasesCount(getIntAttr(node, "count"));
			addReleasesToList(node, label->getReleases());
		}
		else if (name == "relation-list") {
			addRelationsToEntity(node, label);
		}
		else if (name == "tag-list") {
			addTagsToList(node, label->getTags());
		}
	}
	return label; 
}

LabelAlias *
MbXmlParser::MbXmlParserPrivate::createLabelAlias(XMLNode node)
{
	LabelAlias *alias = factory.newLabelAlias();
	alias->setType(getUriAttr(node, "type"));
	alias->setScript(getTextAttr(node, "script"));
	alias->setValue(getText(node));
	return alias;
}

Tag *
MbXmlParser::MbXmlParserPrivate::createTag(XMLNode node)
{
	Tag *tag = factory.newTag();
	tag->setCount(getIntAttr(node, "count"));
	tag->setName(getText(node));
	return tag;
}


string
getResourceType(const string &type)
{
	string resType = extractFragment(type);
	transform(resType.begin(), resType.end(), resType.begin(), (int(*)(int))tolower);
	return resType;
}

Relation *
MbXmlParser::MbXmlParserPrivate::createRelation(XMLNode node, const string &targetType)
{
	Relation *relation = factory.newRelation();
	
	relation->setType(getUriAttr(node, "type", NS_REL_1));
	relation->setTargetType(targetType);
	if (targetType == Relation::TO_URL)
		relation->setTargetId(getTextAttr(node, "target"));
	else
		relation->setTargetId(getIdAttr(node, "target", getResourceType(targetType)));

	Relation::Direction direction = Relation::DIR_BOTH; 
	string dirStr = getTextAttr(node, "direction");
	if (dirStr == "forward")
		direction = Relation::DIR_FORWARD;
	if (dirStr == "backward")
		direction = Relation::DIR_BACKWARD;
	relation->setDirection(direction);

	relation->setBeginDate(getTextAttr(node, "begin"));
	relation->setEndDate(getTextAttr(node, "end"));
	
	vector<string> attributes = getUriListAttr(node, "attributes", NS_REL_1);
	for (vector<string>::iterator i = attributes.begin(); i != attributes.end(); i++) 
		relation->addAttribute(*i);

	Entity *target = NULL;
	if (node.nChildNode() > 0) {
		XMLNode childNode = node.getChildNode(0);
		if (string(childNode.getName()) == string("artist")) 
			target = createArtist(childNode);
		else if (string(childNode.getName()) == string("release"))  
			target = createRelease(childNode);
		else if (string(childNode.getName()) == string("track")) 
			target = createTrack(childNode);
	}
	relation->setTarget(target);
	
	return relation;
}

void
MbXmlParser::MbXmlParserPrivate::addRelationsToEntity(XMLNode node, Entity *entity)
{
	string targetType = getUriAttr(node, "target-type");
	if (targetType.empty())
		return;
	
	for (int i = 0; i < node.nChildNode(); i++) {
		XMLNode childNode = node.getChildNode(i);
		if (string(childNode.getName()) == string("relation")) {
			Relation *relation = createRelation(childNode, targetType);
			if (relation)
				entity->addRelation(relation);
		}
	}
}

Release *
MbXmlParser::MbXmlParserPrivate::createRelease(XMLNode releaseNode)
{
	Release *release = factory.newRelease();
	release->setId(getIdAttr(releaseNode, "id", "release"));
	release->setTypes(getUriListAttr(releaseNode, "type"));
	for (int i = 0; i < releaseNode.nChildNode(); i++) {
		XMLNode node = releaseNode.getChildNode(i);
		string name = node.getName(); 
		if (name == "title") {
			release->setTitle(getText(node));
		}
		else if (name == "text-representation") {
			release->setTextLanguage(getTextAttr(node, "language"));
			release->setTextScript(getTextAttr(node, "script"));
		}
		else if (name == "asin") {
			release->setAsin(getText(node));
		}
		else if (name == "artist") {
			release->setArtist(createArtist(node));
		}
		else if (name == "release-event-list") {
			addReleaseEventsToList(node, release->getReleaseEvents());
		}
		else if (name == "disc-list") {
			addDiscsToList(node, release->getDiscs());
		}
		else if (name == "track-list") {
			release->setTracksOffset(getIntAttr(node, "offset"));
			release->setTracksCount(getIntAttr(node, "count"));
			addTracksToList(node, release->getTracks());
		}
		else if (name == "relation-list") {
			addRelationsToEntity(node, release);
		}
		else if (name == "tag-list") {
			addTagsToList(node, release->getTags());
		}
	}
	return release;
}

Track *
MbXmlParser::MbXmlParserPrivate::createTrack(XMLNode trackNode)
{
	Track *track = factory.newTrack();
	track->setId(getIdAttr(trackNode, "id", "track"));
	for (int i = 0; i < trackNode.nChildNode(); i++) {
		XMLNode node = trackNode.getChildNode(i);
		string name = node.getName(); 
		if (name == "title") {
			track->setTitle(getText(node));
		}
		else if (name == "artist") {
			track->setArtist(createArtist(node));
		}
		else if (name == "duration") {
			track->setDuration(getInt(node));
		}
		else if (name == "release-list") {
			track->setReleasesOffset(getIntAttr(node, "offset"));
			track->setReleasesCount(getIntAttr(node, "count"));
			addReleasesToList(node, track->getReleases());
		}
		else if (name == "relation-list") {
			addRelationsToEntity(node, track);
		}
		else if (name == "tag-list") {
			addTagsToList(node, track->getTags());
		}
	}
	return track;
}

User *
MbXmlParser::MbXmlParserPrivate::createUser(XMLNode userNode)
{
	User *user = factory.newUser();
	vector<string> typeList = getUriListAttr(userNode, "type", NS_EXT_1);
	for (vector<string>::iterator i = typeList.begin(); i != typeList.end(); i++) 
		user->addType(*i);
	for (int i = 0; i < userNode.nChildNode(); i++) {
		XMLNode node = userNode.getChildNode(i);
		string name = node.getName();
		if (name == "name") { 
			user->setName(getText(node));
		}
		else if (name == "ext:nag") {
			user->setShowNag(getBoolAttr(node, "show"));
		}
	}
	return user;
}

Disc *
MbXmlParser::MbXmlParserPrivate::createDisc(XMLNode discNode)
{
	Disc *disc = factory.newDisc();
	disc->setId(getTextAttr(discNode, "id"));
	return disc;
}

ReleaseEvent *
MbXmlParser::MbXmlParserPrivate::createReleaseEvent(XMLNode releaseEventNode)
{
	ReleaseEvent *releaseEvent = factory.newReleaseEvent();
	releaseEvent->setCountry(getTextAttr(releaseEventNode, "country"));
	releaseEvent->setDate(getTextAttr(releaseEventNode, "date"));
	releaseEvent->setCatalogNumber(getTextAttr(releaseEventNode, "catalog-number"));
	releaseEvent->setBarcode(getTextAttr(releaseEventNode, "barcode"));
	for (int i = 0; i < releaseEventNode.nChildNode(); i++) {
		XMLNode node = releaseEventNode.getChildNode(i);
		string name = node.getName();
		if (name == "label") {
			releaseEvent->setLabel(createLabel(node));
		}
	}
	return releaseEvent;
}

template<typename T, typename TL, typename TR>
void
MbXmlParser::MbXmlParserPrivate::addResults(XMLNode listNode, TL &resultList, T *(MbXmlParserPrivate::*creator)(XMLNode))
{
	for (int i = 0; i < listNode.nChildNode(); i++) {
		XMLNode node = listNode.getChildNode(i);
		T *entity = (this->*creator)(node);
		int score = getIntAttr(node, "ext:score");
		resultList.push_back(new TR(entity, score));
	}
}

void
MbXmlParser::MbXmlParserPrivate::addArtistResults(XMLNode listNode, ArtistResultList &resultList)
{
	addResults<Artist, ArtistResultList, ArtistResult>(listNode, resultList, &MbXmlParserPrivate::createArtist);
}

void
MbXmlParser::MbXmlParserPrivate::addReleaseResults(XMLNode listNode, ReleaseResultList &resultList)
{
	addResults<Release, ReleaseResultList, ReleaseResult>(listNode, resultList, &MbXmlParserPrivate::createRelease);
}

void
MbXmlParser::MbXmlParserPrivate::addTrackResults(XMLNode listNode, TrackResultList &resultList)
{
	addResults<Track, TrackResultList, TrackResult>(listNode, resultList, &MbXmlParserPrivate::createTrack);
}

template<typename T, typename TL>
void
MbXmlParser::MbXmlParserPrivate::addToList(XMLNode listNode, TL &resultList, T *(MbXmlParserPrivate::*creator)(XMLNode))
{
	for (int i = 0; i < listNode.nChildNode(); i++) {
		XMLNode node = listNode.getChildNode(i);
		resultList.push_back((this->*creator)(node));
	}
}

void
MbXmlParser::MbXmlParserPrivate::addArtistsToList(XMLNode listNode, ArtistList &resultList)
{
	addToList<Artist, ArtistList>(listNode, resultList, &MbXmlParserPrivate::createArtist);
}

void
MbXmlParser::MbXmlParserPrivate::addArtistAliasesToList(XMLNode listNode, ArtistAliasList &resultList)
{
	addToList<ArtistAlias, ArtistAliasList>(listNode, resultList, &MbXmlParserPrivate::createArtistAlias);
}

void
MbXmlParser::MbXmlParserPrivate::addDiscsToList(XMLNode listNode, DiscList &resultList)
{
	addToList<Disc, DiscList>(listNode, resultList, &MbXmlParserPrivate::createDisc);
}

void
MbXmlParser::MbXmlParserPrivate::addReleasesToList(XMLNode listNode, ReleaseList &resultList)
{
	addToList<Release, ReleaseList>(listNode, resultList, &MbXmlParserPrivate::createRelease);
}

void
MbXmlParser::MbXmlParserPrivate::addReleaseEventsToList(XMLNode listNode, ReleaseEventList &resultList)
{
	addToList<ReleaseEvent, ReleaseEventList>(listNode, resultList, &MbXmlParserPrivate::createReleaseEvent);
}

void
MbXmlParser::MbXmlParserPrivate::addTracksToList(XMLNode listNode, TrackList &resultList)
{
	addToList<Track, TrackList>(listNode, resultList, &MbXmlParserPrivate::createTrack);
}

void
MbXmlParser::MbXmlParserPrivate::addUsersToList(XMLNode listNode, UserList &resultList)
{
	addToList<User, UserList>(listNode, resultList, &MbXmlParserPrivate::createUser);
}

void
MbXmlParser::MbXmlParserPrivate::addTagsToList(XMLNode listNode, TagList &resultList)
{
	addToList<Tag, TagList>(listNode, resultList, &MbXmlParserPrivate::createTag);
}

void
MbXmlParser::MbXmlParserPrivate::addLabelAliasesToList(XMLNode listNode, LabelAliasList &resultList)
{
	addToList<LabelAlias, LabelAliasList>(listNode, resultList, &MbXmlParserPrivate::createLabelAlias);
}

MbXmlParser::MbXmlParser(/*IFactory &factory*/)
{
	d = new MbXmlParserPrivate();
}

MbXmlParser::~MbXmlParser()
{
	delete d;
}

Metadata *
MbXmlParser::parse(const std::string &data)
{
	XMLNode root = XMLNode::parseString(data.c_str(), "metadata");
	
	if (root.isEmpty() || root.getName() != string("metadata")) {
		throw ParseError();
	}
	
	Metadata *md = new Metadata();
	try {
		for (int i = 0; i < root.nChildNode(); i++) {
			XMLNode node = root.getChildNode(i);
			string name = node.getName(); 
			if (name == string("artist")) {
				md->setArtist(d->createArtist(node));
			}
			else if (name == string("track")) {
				md->setTrack(d->createTrack(node));
			}
			else if (name == string("release")) {
				md->setRelease(d->createRelease(node));
			}
			else if (name == string("label")) {
				md->setLabel(d->createLabel(node));
			}
			else if (name == string("artist-list")) {
				d->addArtistResults(node, md->getArtistResults());
			}
			else if (name == string("track-list")) {
				d->addTrackResults(node, md->getTrackResults());
			}
			else if (name == string("release-list")) {
				d->addReleaseResults(node, md->getReleaseResults());
			}
			else if (name == string("ext:user-list")) {
				d->addUsersToList(node, md->getUserList());
			}
		}
	}
	catch (...) {
		delete md;
		throw ParseError();
	}
	
	return md;
}


