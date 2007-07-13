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
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
 *
 * $Id: utils.cpp 8784 2007-01-11 14:06:47Z luks $
 */

#include <string>
#include <map>
#include <musicbrainz3/utils.h>

using namespace std;
using namespace MusicBrainz;

std::string
MusicBrainz::extractFragment(const string &uri)
{
	// FIXME: proper URI parsing
	string::size_type pos = uri.find_last_of('#');
	if (pos == string::npos)
		return uri;
	else
		return uri.substr(pos + 1);
}

std::string
MusicBrainz::extractUuid(const string &uri)
{
	if (uri.empty())
		return uri;
	string types[] = {"artist/", "release/", "track/"};
	for (int i = 0; i < 3; i++) {
		string::size_type pos = uri.find(types[i]);
		if (pos != string::npos) {
			pos += types[i].size();
			if (pos + 36 == uri.size()) {
				return uri.substr(pos, 36);
			}
		}
	}
	// FIXME: ugh...
	if (uri.size() == 36)
		return uri;
	throw ValueError(uri + "is not a valid MusicBrainz ID.");
}

#include "utils_countrynames.h"

string 
MusicBrainz::getCountryName(const string &id)
{
	static bool countryNamesMapBuilt = false;
	static map<string, string> countryNamesMap;
	
	if (!countryNamesMapBuilt) {
		for (int i = 0; i < (int)(sizeof(countryNames) / sizeof(countryNames[0])); i++) 
			countryNamesMap[countryNames[i][0]] = countryNames[i][1];	
		countryNamesMapBuilt = true;
	}
	
	map<string, string>::iterator i = countryNamesMap.find(id);
	return i == countryNamesMap.end() ? string() : i->second; 
}

#include "utils_languagenames.h"

string 
MusicBrainz::getLanguageName(const string &id)
{
	static bool languageNamesMapBuilt = false;
	static map<string, string> languageNamesMap;
	
	if (!languageNamesMapBuilt) {
		for (int i = 0; i < (int)(sizeof(languageNames) / sizeof(languageNames[0])); i++) 
			languageNamesMap[languageNames[i][0]] = languageNames[i][1];	
		languageNamesMapBuilt = true;
	}
	
	map<string, string>::iterator i = languageNamesMap.find(id);
	return i == languageNamesMap.end() ? string() : i->second; 
}

#include "utils_scriptnames.h"

string 
MusicBrainz::getScriptName(const string &id)
{
	static bool scriptNamesMapBuilt = false;
	static map<string, string> scriptNamesMap;
	
	if (!scriptNamesMapBuilt) {
		for (int i = 0; i < (int)(sizeof(scriptNames) / sizeof(scriptNames[0])); i++) 
			scriptNamesMap[scriptNames[i][0]] = scriptNames[i][1];	
		scriptNamesMapBuilt = true;
	}
	
	map<string, string>::iterator i = scriptNamesMap.find(id);
	return i == scriptNamesMap.end() ? string() : i->second; 
}

#include "utils_releasetypenames.h"

string 
MusicBrainz::getReleaseTypeName(const string &id)
{
	static bool releaseTypeNamesMapBuilt = false;
	static map<string, string> releaseTypeNamesMap;
	
	if (!releaseTypeNamesMapBuilt) {
		for (int i = 0; i < (int)(sizeof(releaseTypeNames) / sizeof(releaseTypeNames[0])); i++) 
			releaseTypeNamesMap[releaseTypeNames[i][0]] = releaseTypeNames[i][1];	
		releaseTypeNamesMapBuilt = true;
	}

	map<string, string>::iterator i = releaseTypeNamesMap.find(id);
	return i == releaseTypeNamesMap.end() ? string() : i->second; 
}

