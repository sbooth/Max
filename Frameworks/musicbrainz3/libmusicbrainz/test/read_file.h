inline string
get_file_contents(char *filename)
{
	ifstream file(filename, ios::in | ios::ate);
	if (!file.is_open())
		return string();
	streampos sz = file.tellg();
	file.seekg(0, ios::beg);
	vector<char> v(sz);
	file.read(&v[0], sz);
	file.close();
	string data(v.empty() ? string() : string (v.begin(), v.end()).c_str());
	return data;
}

