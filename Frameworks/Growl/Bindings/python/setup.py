#!/usr/bin/python
from distutils.core import setup, Extension
import sys

_growl = Extension('_growl',
                    extra_link_args = ["-framework","Foundation"],
                    sources = ['libgrowl.m'])
_growlImage = Extension('_growlImage',
                        extra_link_args = ["-framework","Cocoa"],
                        sources = ['growlImage.m'])

if sys.platform.startswith("darwin"):
    modules = [_growl, _growlImage]
else:
    modules = []

setup(name="py-Growl",
      version="0.0.6",
      description="Python bindings for posting notifications to the Growl daemon",
      author="Mark Rowe",
      author_email="bdash@users.sourceforge.net",
      url="http://Growl.info",
      py_modules=["Growl"],
      ext_modules = modules )

