from distutils.core import setup
from distutils.command.install_scripts import install_scripts
import sys

try:
	import Growl
except ImportError:
	sys.exit("Required module Growl not installed. Install it from ../../Bindings/python first.")
else:
	del Growl

class appleLocalInstallWorkAround(install_scripts):
    # BAD BAD But this works :)
    def run (self):
        hold_dir = self.install_dir
        self.install_dir = "/usr/local/bin"
        r = install_scripts.run(self)
        self.install_dir = hold_dir
        return r
if sys.platform.startswith("darwin"):
    myCmdClass={'install_scripts':appleLocalInstallWorkAround}
else:
    myCmdClass=None
setup(name="Growl-tools",
      version="0.0.2",
      description="A command-line interface to Growl written in Python",
      author="Jeremy Rossi",
      author_email="jeremy@jeremyrossi.com",
      url="http://Growl.info",
      scripts=["gnotify", "gtime"],
      cmdclass=myCmdClass)

