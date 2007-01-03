# In order to generate the HTML documentation, xsltproc and the DocBook DTDs and
# XSL stylesheets need to be installed. The PDFs additionally require fop.
#
# Those packages can be installed via fink:
#   fink install libxslt docbook-dtd docbook-xsl fop
#

all: html documentation.pdf documentation-a4.pdf

html: documentation.xml
	mkdir -p output
	xsltproc --stringparam base.dir output/ --stringparam chunk.fast yes --stringparam chunker.output.encoding UTF-8 --stringparam chunker.output.indent yes --stringparam use.id.as.filename yes --stringparam html.stylesheet ../style.css /sw/share/xml/xsl/docbook-xsl/xhtml/chunk.xsl documentation.xml

pdf: documentation.pdf documentation-a4.pdf

documentation.pdf: documentation.fo
	fop -fo documentation.fo -pdf documentation.pdf

documentation-a4.pdf: documentation-a4.fo
	fop -fo documentation-a4.fo -pdf documentation-a4.pdf

documentation.fo: documentation.xml
	xsltproc --output documentation.fo --stringparam fop.extensions 1 /sw/share/xml/xsl/docbook-xsl/fo/docbook.xsl documentation.xml

documentation-a4.fo: documentation.xml
	xsltproc --output documentation-a4.fo --stringparam fop.extensions 1 --stringparam paper.type A4 /sw/share/xml/xsl/docbook-xsl/fo/docbook.xsl documentation.xml

clean:
	rm -rf output
	rm -f documentation.fo documentation-a4.fo documentation.pdf documentation-a4.pdf

