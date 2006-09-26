#!/usr/bin/env python

# cueconvert.cgi - use HTML form to drive cueconvert

import os
import cgi
# error reporting
#import cgitb; cgitb.enable()

# cueconvert path
CUECONVERT = "./cueconvert"

def print_form(iformat, oformat, text, errors):
	# input format radio buttons
	# one "" and one "checked"
	iformat_cue = ""
	iformat_toc = ""
	# output format radio buttons
	oformat_cue = ""
	oformat_toc = ""

	if iformat == "cue":
		iformat_cue = "checked"
	else:
		iformat_toc = "checked"

	if oformat == "cue":
		oformat_cue = "checked"
	else:
		oformat_toc = "checked"

	# print HTML form
	print "Content-type: text/html"
	print
	print """
<html>
<head>
	<title>cueconvert</title>
</head>
<body>
	<h1>cueconvert</h1>
	<form action="cueconvert.cgi" method="post">
		<p>
			Cue Sheet/TOC File<br />
			<textarea name="text" cols="80" rows="12">%s</textarea>
		</p>
		<p>
			Input Format
			<input type="radio" name="iformat" value="cue" %s>cue</input>
			<input type="radio" name="iformat" value="toc" %s>toc</input>
		</p>
		<p>
			Output Format
			<input type="radio" name="oformat" value="cue" %s>cue</input>
			<input type="radio" name="oformat" value="toc" %s>toc</input>
		</p>
		<input type="submit" value="Submit">
	</form>
	<pre>%s</pre>
	<hr />
	<p>cueconvert is part of the <a href="http://cuetools.berlios.de">cuetools</a> project.</p>
</body>
</html>
	""" % (cgi.escape(text), iformat_cue, iformat_toc, oformat_cue, oformat_toc, cgi.escape(errors))

def convert(iformat, oformat, text):
	"""convert - convert a cue or toc file

	returns converted text, and any error messages"""

	command = CUECONVERT

	# append flags to command
	if iformat == "cue":
		command += " -i cue"
	elif iformat == "toc":
		command += " -i toc"
	
	if oformat == "cue":
		command += " -o cue"
	elif oformat == "toc":
		command += " -o toc"

	ifile, ofile, efile = os.popen3(command)
	ifile.write(text)
	ifile.close()
	text = ofile.read()
	errors = efile.read()
	ofile.close()
	efile.close()

	return text, errors

def main():
	iformat = "cue"		# input format
	oformat = "toc"		# output format
	text = ""		# input file content
	errors = ""		# cueconvert error messages

	form = cgi.FieldStorage()
	if form:
		iformat = form.getfirst("iformat")
		oformat = form.getfirst("oformat")
		text = form.getfirst("text", "")

		text, errors = convert(iformat, oformat, text)
		# switch input and output formats for next pass
		iformat, oformat = oformat, iformat

	print_form(iformat, oformat, text, errors)

if __name__ == '__main__':
	main()
