#! /bin/sh

if test ! -d "config" ; then
mkdir config
fi

libtoolize --copy --force
aclocal
autoheader
automake --gnu --add-missing --copy
autoconf
