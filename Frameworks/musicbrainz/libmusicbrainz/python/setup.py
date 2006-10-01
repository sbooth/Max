#!/usr/bin/env python

__revision__ = "$Id: setup.py 7523 2006-05-11 19:24:23Z luks $"

from distutils.core import setup, Extension, Command
import distutils.command.build_ext

import sys, os, string

cmdclass = {}

setup_args = { 
    'name': 'python-musicbrainz',
    'description': 'A wrapper for the MusicBrainz libraries',
    'long_description': """\
The MusicBrainz client library is a development library geared towards
developers who wish to add MusicBrainz lookup capabilities to their
applications.

The client library includes the following features:

    * Lookup Audio CD metadata using CD Index Discids
    * Calculate Relatable TRM acoustic fingerprints
    * Search for artist/album/track titles
    * Lookup metadata by name, TRM ids or MusicBrainz Ids 
""",

    'license': 'LGPL',
    'author': 'Myers W. Carpenter',
    'author_email': 'icepick@icepick.info',
    'url': 'http://icepick.info/projects/python-musicbrainz/',
    'download_url': 'http://icepick.info/projects/python-musicbrainz/',
    'classifiers': [
        'Development Status :: 5 - Production/Stable',
        'Environment :: Plugins',
        'Intended Audience :: Developers',
        'License :: OSI Approved :: GNU Library or Lesser General Public License (LGPL)',
        'Programming Language :: Python',
        'Topic :: Utilities',
        'Topic :: Communications :: File Sharing',
        'Topic :: Multimedia :: Sound/Audio :: Analysis',
    ],
    'cmdclass': cmdclass,

    'py_modules': ['musicbrainz',],
}

try:
    import musicbrainz
    setup_args['version'] = musicbrainz.__version__
except:
    pass

# patch distutils if it can't cope with the 'classifiers' or
# 'download_url' keywords
if sys.version < '2.2.3':
    from distutils.dist import DistributionMetadata
    DistributionMetadata.classifiers = None
    DistributionMetadata.download_url = None

if hasattr(distutils.dist.DistributionMetadata, 'get_platforms'):
    setup_args['platforms'] = 'win32 posix'


class build_queries(distutils.command.build_ext.build_ext):
    def run(self):
        raise Exception("broken now")
        build = self.get_finalized_command('build')
        self.build_platlib = build.build_platlib
        
        queries_h = os.path.join('src', 'queries.h')

        output = []
        includes = ''
        for ii in self.include_dirs:
            includes = includes + "-I%s " % ii
        cmd = "gcc -E -dM %s %s" % (includes, queries_h)
        print cmd
        file = os.popen(cmd, "r")
        output = file.readlines()

        queries = {}

        output.sort()

        for ii in output:
            name = ''
            query = ''
            # Remove "#define " from the beginning of each line
            ii = ii[8:-1] 
            if ii[:2] == "MB":
                name = ii[:ii.find(" ")]
                query = ii[ii.find(" ")+1:]
                # Remove all quotes
                query = query.replace("\"", "")
                # Escape out the newlines
                query = query.replace("\\n", "\\\n")
                query = query.replace("\\", "")
                # Get rid of trail/leading spaces
                query = query.strip()
                if query.endswith('\\'):
                    query = query[:-1]
                queries[name] = query

        # 80's just a rough guess
        if len(queries) < 80:
            raise SystemExit, "Bug! for some reason I can't read the header file that came with libmusicbrainz"
        
        filename = os.path.join('musicbrainz', 'queries.py')
        ff = open(filename, "w")
        ff.write("# auto generated.  run ./setup.py build_queries to update\n")

        keys = queries.keys()
        keys.sort()
        for key in keys:
            ff.write("%s = \"\"\"\\\n%s\"\"\"\n\n" % (key, queries[key]))
        ff.close()

        print "Wrote %i queries into '%s'." % (len(queries), filename)

cmdclass['build_queries'] = build_queries

class test(Command):
    """
    
    Based off of http://mail.python.org/pipermail/distutils-sig/2002-January/002714.html
    """
    description  = "test the distribution prior to install"
    
    user_options = [
        ('test-dir=', None,
         "directory that contains the test definitions"),]
                 
    def initialize_options(self):
        self.test_dir = 'test'    
        
    def finalize_options(self):
        build = self.get_finalized_command('build')
        self.build_purelib = build.build_purelib
        self.build_platlib = build.build_platlib
                                                                                           
    def run(self):
        import unittest
        self.run_command('build')
        self.run_command('build_ext')

        old_path = sys.path[:]
        sys.path.insert(0, self.build_purelib)
        sys.path.insert(0, self.build_platlib)
        sys.path.insert(0, os.path.join(os.getcwd(), self.test_dir))
        
        runner = unittest.TextTestRunner()
        for ff in os.listdir(self.test_dir):
            if ff == '__init__.py':
                continue
            if os.path.splitext(ff)[1] != ".py":
                continue
            print "Running tests found in '%s'..." % ff
            TEST = __import__(ff[:-3], globals(), locals(), [''])
            runner.run(TEST.suite())
        
        sys.path = old_path[:]
                
            
cmdclass['test'] = test

if __name__ == '__main__':
    distutils.core.setup(**setup_args)
