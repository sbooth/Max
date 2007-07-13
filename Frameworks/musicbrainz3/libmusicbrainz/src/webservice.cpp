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
 * $Id: webservice.cpp 9130 2007-05-11 22:55:10Z luks $
 */
 
#include <config.h>
#include <string>
#include <map>
#include <iostream>
#include <string.h>
#include <ne_session.h>
#include <ne_request.h>
#include <ne_utils.h>
#include <ne_auth.h>
#include <ne_uri.h> 
#include <musicbrainz3/webservice.h>
#include <musicbrainz3/artist.h>
#include "utils_private.h"

using namespace std;
using namespace MusicBrainz;

class WebService::WebServicePrivate
{
public:
	WebServicePrivate()
		{}
		
	std::string host;
	int port;
	std::string pathPrefix;
	std::string username;
	std::string password;
	std::string realm;
	std::string proxyHost;
	int proxyPort;
	std::string proxyUserName;
	std::string proxyPassword;
};

static bool webServiceInitialized = false;
static string systemProxyHost = string();
static int systemProxyPort = 0;
static string systemProxyUserName = string();
static string systemProxyPassword = string();

static void
webServiceInit()
{
	if (webServiceInitialized)
		return;
	
	ne_sock_init();
	
	// Parse http_proxy environmnent variable	
	const char *http_proxy = getenv("http_proxy");
	if (http_proxy) {
		debug("Found http_proxy environmnent variable \"%s\"", http_proxy);
		ne_uri uri;
		if (!ne_uri_parse(http_proxy, &uri)) {
			if (uri.host)
				systemProxyHost = string(uri.host); 
			if (uri.port)
				systemProxyPort = uri.port;
// neon 0.26
#ifdef NE_FEATURE_I18N	
			if (uri.userinfo) {
				char *pos = strchr(uri.userinfo, ':');
				if (pos) {
					*pos = '\0';
					systemProxyUserName = string(uri.userinfo);
					systemProxyPassword = string(pos + 1);
				}
				else {
					systemProxyUserName = string(uri.userinfo);
				}
			}
// neon 0.25
#else
			if (uri.authinfo) {
				char *pos = strchr(uri.authinfo, ':');
				if (pos) {
					*pos = '\0';
					systemProxyUserName = string(uri.authinfo);
					systemProxyPassword = string(pos + 1);
				}
				else {
					systemProxyUserName = string(uri.authinfo);
				}
			}
#endif
		}
		ne_uri_free(&uri);
	}
	
	webServiceInitialized = true;
}

WebService::WebService(const std::string &host,
					   const int port,
					   const std::string &pathPrefix,
					   const std::string &username,
					   const std::string &password,
					   const std::string &realm)
{
	webServiceInit();
	
	d = new WebServicePrivate();
	d->host = host;
	d->port = port;
	d->pathPrefix = pathPrefix;
	d->username = username;
	d->password = password;
	d->realm = realm;
	d->proxyHost = systemProxyHost;
	d->proxyPort = systemProxyPort;
	d->proxyUserName = systemProxyUserName;
	d->proxyPassword = systemProxyPassword;
}

WebService::~WebService()
{
	delete d;
}

int
WebService::httpAuth(void *userdata, const char *realm, int attempts,
					 char *username, char *password)
{
	WebService *ws = (WebService *)userdata;
	strncpy(username, ws->d->username.c_str(), NE_ABUFSIZ);
	strncpy(password, ws->d->password.c_str(), NE_ABUFSIZ);
	return attempts;  	
}

int
WebService::proxyAuth(void *userdata, const char *realm, int attempts,
					 char *username, char *password)
{
	WebService *ws = (WebService *)userdata;
	strncpy(username, ws->d->proxyUserName.c_str(), NE_ABUFSIZ);
	strncpy(password, ws->d->proxyPassword.c_str(), NE_ABUFSIZ);
	return attempts;  	
}

int
WebService::httpResponseReader(void *userdata, const char *buf, size_t len)
{
	string *str = (string *)userdata;
	str->append(buf, len);
	return 0;
}

string
WebService::get(const std::string &entity,
				const std::string &id,
				const IIncludes::IncludeList &include,
				const IFilter::ParameterList &filter,
				const std::string &version)
{
	ne_session *sess;
	ne_request *req;
	
	debug("Connecting to http://%s:%d", d->host.c_str(), d->port);
	
	sess = ne_session_create("http", d->host.c_str(), d->port);
	if (!sess) 
		throw WebServiceError("ne_session_create() failed.");
	ne_set_server_auth(sess, httpAuth, this);
	ne_set_useragent(sess, PACKAGE"/"VERSION);
	
	// Use proxy server
	if (!d->proxyHost.empty()) {
		ne_session_proxy(sess, d->proxyHost.c_str(), d->proxyPort);
		ne_set_proxy_auth(sess, proxyAuth, this);
	}

	vector<pair<string, string> > params;
	params.push_back(pair<string, string>("type", "xml"));
	
	string inc;
	for (IIncludes::IncludeList::const_iterator i = include.begin(); i != include.end(); i++) {
		if (!inc.empty())
			inc += " ";
		inc += *i;
	}
	if (!inc.empty())
		params.push_back(pair<string, string>("inc", inc));
	
	for (IFilter::ParameterList::const_iterator i = filter.begin(); i != filter.end(); i++)  
		params.push_back(pair<string, string>(i->first, i->second));

	string uri = d->pathPrefix + "/" + version + "/" + entity + "/" + id + "?" + urlEncode(params);
	
	debug("GET %s", uri.c_str());
	
	string response;
	req = ne_request_create(sess, "GET", uri.c_str());	
	ne_add_response_body_reader(req, ne_accept_2xx, httpResponseReader, &response);		
	int result = ne_request_dispatch(req);
	int status = ne_get_status(req)->code;
	ne_request_destroy(req); 
	
	string errorMessage = ne_get_error(sess);
	ne_session_destroy(sess);
		
	debug("Result: %d (%s)", result, errorMessage.c_str());
	debug("Status: %d", status);
	debug("Response:\n%s", response.c_str());
	
	switch (result) {
	case NE_OK:
		break;
	case NE_CONNECT:
		throw ConnectionError(errorMessage);
	case NE_TIMEOUT:
		throw TimeOutError(errorMessage);
	case NE_AUTH:
		throw AuthenticationError(errorMessage);
	default:
		throw WebServiceError(errorMessage);
	}

	switch (status) {
	case 200:
		break;
	case 400:
		throw RequestError(errorMessage);
	case 401:
		throw AuthenticationError(errorMessage);
	case 404:
		throw ResourceNotFoundError(errorMessage);
	default:
		throw WebServiceError(errorMessage);
	}
	
	return response; 
}

void
WebService::post(const std::string &entity,
				 const std::string &id,
				 const std::string &data,
				 const std::string &version)
{
	ne_session *sess;
	ne_request *req;
	
	debug("Connecting to http://%s:%d", d->host.c_str(), d->port);
	
	sess = ne_session_create("http", d->host.c_str(), d->port);
	if (!sess) 
		throw WebServiceError("ne_session_create() failed.");
	ne_set_server_auth(sess, httpAuth, this);
	ne_set_useragent(sess, PACKAGE"/"VERSION);

	// Use proxy server
	if (!d->proxyHost.empty()) {
		ne_session_proxy(sess, d->proxyHost.c_str(), d->proxyPort);
		ne_set_proxy_auth(sess, proxyAuth, this);
	}

	string uri = d->pathPrefix + "/" + version + "/" + entity + "/" + id;
	
	debug("POST %s", uri.c_str());
	debug("POST-BODY:\n%s", data.c_str());
	
	req = ne_request_create(sess, "POST", uri.c_str());
// neon 0.26 and higher
#ifdef NE_FEATURE_I18N	
	ne_set_request_flag(req, NE_REQFLAG_IDEMPOTENT, 0);
#endif
	ne_add_request_header(req, "Content-type", "application/x-www-form-urlencoded");
	ne_set_request_body_buffer(req, data.c_str(), data.size());	
	int result = ne_request_dispatch(req);
	int status = ne_get_status(req)->code;
	ne_request_destroy(req); 
	
	string errorMessage = ne_get_error(sess);
	ne_session_destroy(sess);
	
	debug("Result: %d (%s)", result, errorMessage.c_str());
	debug("Status: %d", status);
	
	switch (result) {
	case NE_OK:
		break;
	case NE_CONNECT:
		throw ConnectionError(errorMessage);
	case NE_TIMEOUT:
		throw TimeOutError(errorMessage);
	case NE_AUTH:
		throw AuthenticationError(errorMessage);
	default:
		throw WebServiceError(errorMessage);
	}

	switch (status) {
	case 200:
		break;
	case 400:
		throw RequestError(errorMessage);
	case 401:
		throw AuthenticationError(errorMessage);
	case 404:
		throw ResourceNotFoundError(errorMessage);
	default:
		throw WebServiceError(errorMessage);
	}
}

void
WebService::setHost(const std::string &value)
{
	d->host = value;
}

std::string
WebService::getHost() const
{
	return d->host;
}

void
WebService::setPort(const int value)
{
	d->port = value;
}

int
WebService::getPort() const
{
	return d->port;
}

void
WebService::setPathPrefix(const std::string &value)
{
	d->pathPrefix = value;
}

std::string
WebService::getPathPrefix() const
{
	return d->pathPrefix;
}

void
WebService::setUserName(const std::string &value)
{
	d->username = value;
}

std::string
WebService::getUserName() const
{
	return d->username;
}

void
WebService::setPassword(const std::string &value)
{
	d->password = value;
}

std::string
WebService::getPassword() const
{
	return d->password;
}

void
WebService::setRealm(const std::string &value)
{
	d->realm = value;
}

std::string
WebService::getRealm() const
{
	return d->realm;
}

void
WebService::setProxyHost(const std::string &value)
{
	d->proxyHost = value;
}

std::string
WebService::getProxyHost() const
{
	return d->proxyHost;
}

void
WebService::setProxyPort(const int value)
{
	d->proxyPort = value;
}

int
WebService::getProxyPort() const
{
	return d->proxyPort;
}

void
WebService::setProxyUserName(const std::string &value)
{
	d->proxyUserName = value;
}

std::string
WebService::getProxyPassword() const
{
	return d->proxyPassword;
}

void
WebService::setProxyPassword(const std::string &value)
{
	d->proxyPassword = value;
}


