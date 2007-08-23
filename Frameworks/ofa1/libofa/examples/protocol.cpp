/* ------------------------------------------------------------------

   libofa -- the Open Fingerprint Architecture library

   Public Domain (PD) 2006 MusicIP Corporation
   No rights reserved.

-------------------------------------------------------------------*/
#include <stdio.h>
#include <stdlib.h>
#include <string>
#include <map>
#include <expat.h>
#include <curl/curl.h>
#include <curl/types.h>
#include <curl/easy.h>

using namespace std;

#include "protocol.h"

const char *url = "http://ofa.musicdns.org/ofa/1/track"; 
const char *userAgent = "libofa_example";
const char *unknown = "unknown";

// Lookup by fingerprint
const char *request_format = 
    "cid=%s&"       // Client ID
    "cvr=%s&"       // Client Version
    "fpt=%s&"       // Fingerprint
    "rmd=%d&"       // m = 1: return metadata; m = 0: only return id 
    "brt=%d&"       // bitrate (kbps)
    "fmt=%s&"       // File extension (e.g. mp3, ogg, flac)
    "dur=%ld&"      // Length of track (milliseconds)
    "art=%s&"       // Artist name. If there is none, send "unknown"
    "ttl=%s&"       // Track title. If there is none, send "unknown"
    "alb=%s&"       // Album name. If there is none, send "unknown"
    "tnm=%d&"       // Track number in album. If there is none, send "0"
    "gnr=%s&"       // Genre. If there is none, send "unknown"
    "yrr=%s&"       // Year. If there is none, send "0"
    "enc=%s&"       // Encoding. e = true: ISO-8859-15; e = false: UTF-8 (default). Optional.
    "\r\n";

// Lookup by PUID (Most fields drop out)
const char *request_format2 =
    "cid=%s&"       // Client ID
    "cvr=%s&"       // Client Version
    "pid=%s&"       // PUID 
    "rmd=%d&"       // m = 1: return metadata; m = 0: only return id 
    "brt=%d&"       // bitrate (kbps)
    "fmt=%s&"       // File extension (e.g. mp3, ogg, flac)
    "dur=%ld&"      // Length of track (milliseconds)
    "art=%s&"       // Artist name. If there is none, send "unknown"
    "ttl=%s&"       // Track title. If there is none, send "unknown"
    "alb=%s&"       // Album name. If there is none, send "unknown"
    "tnm=%d&"       // Track number in album. If there is none, send "0"
    "gnr=%s&"       // Genre. If there is none, send "unknown"
    "yrr=%s&"       // Year. If there is none, send "0"
    "enc=%s&"       // Encoding. e = true: ISO-8859-15; e = false: UTF-8 (default). Optional.
    "\r\n";


// --------------------------------------------------------------------
// HTTP POST support using standard curl calls
// --------------------------------------------------------------------
size_t data_callback(void *ptr, size_t size, size_t num, void *arg)
{
    string *str = (string *)arg;
    (*str) += string((const char *)ptr, size * num);
    return size * num;
}

long http_post(const string &url, const string &userAgent, const string &postData, string &doc)
{
  CURL              *curl;
  long               ret = 0;
  struct curl_slist *headerlist=NULL;

  headerlist = curl_slist_append(headerlist, "Expect:"); 

  curl_global_init(CURL_GLOBAL_ALL);
  curl = curl_easy_init();
  curl_easy_setopt(curl, CURLOPT_URL, url.c_str());
  curl_easy_setopt(curl, CURLOPT_WRITEDATA, (void *)&doc);
  curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, data_callback);
  curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headerlist);
  curl_easy_setopt(curl, CURLOPT_POSTFIELDSIZE, postData.length());
  curl_easy_setopt(curl, CURLOPT_POSTFIELDS, postData.c_str());
  curl_easy_setopt(curl, CURLOPT_POST, 1);
  curl_easy_setopt(curl, CURLOPT_USERAGENT, userAgent.c_str());
  curl_easy_perform(curl);
  curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &ret);
  curl_easy_cleanup(curl);

  curl_slist_free_all (headerlist);

  return ret;
}

// --------------------------------------------------------------------
// XML Parsing support 
// --------------------------------------------------------------------

struct ParseInfo
{
    string path;
    string pcdata;
    TrackInformation *info;
};

void begin_element(void *data, const XML_Char *el, const XML_Char **attr)
{
    map<string, string> attrs;

    for(; *attr;) {
        string key = string((char *)*(attr++));
	string value = string((char *)*(attr++));
        attrs[key] = value;
    }

    ((ParseInfo *)data)->path += string("/") + string(el);
    if (((ParseInfo *)data)->path == "/metadata/track/puid-list/puid")
         ((ParseInfo *)data)->info->setPUID(attrs["id"]);

    ((ParseInfo *)data)->pcdata = "";
}

void end_element(void *data, const XML_Char *el)
{
    string::size_type pos;

    if (((ParseInfo *)data)->path == "/metadata/track/title")
         ((ParseInfo *)data)->info->setTrack(((ParseInfo *)data)->pcdata);
    if (((ParseInfo *)data)->path == "/metadata/track/artist/name")
         ((ParseInfo *)data)->info->setArtist(((ParseInfo *)data)->pcdata);

    pos = ((ParseInfo *)data)->path.rfind("/");
    if (pos != string::npos)
       ((ParseInfo *)data)->path = ((ParseInfo *)data)->path.substr(0, pos);
}

void pc_data(void *data, const XML_Char *charData, int len)
{
    char *temp;

    temp = new char[len + 1];
    strncpy(temp, (char *)charData, len);
    temp[len] = 0;
    ((ParseInfo *)data)->pcdata += string(temp);
    delete temp;
}

bool parse_xml(const string &doc, TrackInformation *info, string &err) 
{
    ParseInfo pinfo;

    err = "";
    pinfo.info = info;
    XML_Parser parser = XML_ParserCreate(NULL);
    XML_SetUserData(parser, (void *)&pinfo);
    XML_SetElementHandler(parser, ::begin_element, ::end_element);
    XML_SetCharacterDataHandler(parser, ::pc_data);
    int ret = XML_Parse(parser, doc.c_str(), doc.length(), 1);

    if (ret)
    {
        XML_ParserFree(parser);
        return true;
    }

    err = string(XML_ErrorString(XML_GetErrorCode(parser)));
    char num[10];
    sprintf(num, "%d", XML_GetCurrentLineNumber(parser));
    err += string(" on line ") + string(num);
    XML_ParserFree(parser);

    return false;
}

// --------------------------------------------------------------------
// Retrieve metadata for fingerprint
// --------------------------------------------------------------------

// Returns true on success
bool retrieve_metadata(string client_key, string client_version,
	TrackInformation *info, bool getMetadata) 
{
    if (!info)
	return false;

    // All metadata fields must be provided before this call if the
    // information is available, as part of the Terms of Service.
    // This helps create a better database for all users of the system.
    //
    // If the fields are not available, you can use default values.
    // Here we check for fields which have no default values.
    if (client_key.length() == 0)
	return false;
    if (client_version.length() == 0)
	return false;

    bool lookupByPrint = false;
    if (info->getPUID().length() == 0) {
	// Lookup by fingerprint
	if (info->getPrint().length() == 0)
	    return false;
	if (info->getFormat().length() == 0)
	    return false;
	if (info->getLengthInMS() == 0)
	    return false;

        lookupByPrint = true;
    }

    // Sloppily estimate the size of the resultant URL. Err on the side of making the string too big.
    int bufSize = strlen(lookupByPrint ? request_format : request_format2) +
            client_key.length() + client_version.length() +
            (lookupByPrint ? info->getPrint().length() : info->getPUID().length()) + 
            16 + // getMetadata ? 1 : 0, 
            16 + // info->getBitrate(),
            16 + //info->getFormat().c_str(), 
            16 + //info->getLengthInMS(), 
            ((info->getArtist().c_str() == 0) ? strlen(unknown) : info->getArtist().length()) +
            ((info->getTrack().c_str() == 0) ?  strlen(unknown) : info->getTrack().length()) +
            ((info->getAlbum().c_str() == 0) ?  strlen(unknown) : info->getAlbum().length()) +
            16 + // info->getTrackNum() + 
            ((info->getGenre().c_str() == 0) ?  strlen(unknown) : info->getGenre().length()) +
            ((info->getYear().c_str() == 0) ? 1 : info->getYear().length()) +
            info->getEncoding().length();
        
    char *buf = new char[bufSize];
    sprintf(buf, lookupByPrint ? request_format : request_format2, 
            client_key.c_str(), 
            client_version.c_str(),
            lookupByPrint ? info->getPrint().c_str() : info->getPUID().c_str(), 
            getMetadata ? 1 : 0, 
            info->getBitrate(),
            info->getFormat().c_str(), 
            info->getLengthInMS(), 
            (info->getArtist().length() == 0) ? unknown : info->getArtist().c_str(),
            (info->getTrack().length() == 0) ? unknown : info->getTrack().c_str(),
            (info->getAlbum().length() == 0) ? unknown : info->getAlbum().c_str(),
            info->getTrackNum(), 
            (info->getGenre().length() == 0) ? unknown : info->getGenre().c_str(),
            (info->getYear().length() == 0) ? "0" : info->getYear().c_str(),
            info->getEncoding().c_str());

    string response;
    // printf("request: '%s'\n", buf);
    long ret = http_post(url, userAgent, buf, response);
    delete [] buf;

    if (ret != 200)
    {
        // printf("Error: %ld\n", ret);
        // printf("response: %s\n\n", response.c_str());
        return false;
    }
    // printf("response: %s\n\n", response.c_str());

    unsigned int q = response.find("<?xml");
    if (q != string::npos) {
        response = response.substr(q);
    }
    string err;
    if (!parse_xml(response, info, err)) {
        // Clears title if it wasn't returned
        info->setTrack("");

        // Clears artists if it wasn't returned
        info->setArtist("");
    }
    return true;
}
