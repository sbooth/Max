// Display data about a MusicBrainz user (user name and password required).  
//
// Usage:
//	getuser 
//
// $Id: getuser.cpp 8247 2006-07-22 19:29:52Z luks $

#include <iostream>
#include <musicbrainz3/webservice.h>
#include <musicbrainz3/query.h>
#include <musicbrainz3/model.h>
#include <musicbrainz3/utils.h>

using namespace std;
using namespace MusicBrainz;

int
main(int argc, char **argv)
{
	string username;
	cout << "User name: ";
	cin >> username;
	
	string passwd;
	cout << "Password: ";
	cin >> passwd;
	
	User *user;
	try {
		WebService ws("musicbrainz.org", 80, "/ws", username, passwd);
		Query q(&ws);
		user = q.getUserByName(username);
	}
	catch (WebServiceError &e) {
		cout << "Error: " << e.what() << endl;
		return 1;
	}

	cout << "Name      : " << user->getName() << endl;
	cout << "ShowNag   : " << user->getShowNag() << endl;
	cout << "Types     :";
	vector<string> types = user->getTypes();
	for (vector<string>::iterator i = types.begin(); i != types.end(); i++) 
		cout << " " << extractFragment(*i);
	cout << endl;
	
	delete user;
	
	return 0;
}

