%define     name     libmusicbrainz
%define     version  2.0.2
%define     release  1
%define     prefix   /usr

Name:       %{name}
Version:    %{version}
Release:    %{release}
Summary:    A software library for accessing MusicBrainz servers
Source:     http://www.musicbrainz.org/download/%{name}-%{version}.tar.gz
URL:        http://www.musicbrainz.org
Group:      System Environment/Libraries
BuildRoot:  %{_tmppath}/%{name}-buildroot
Copyright:  LGPL
Prefix:     %{_prefix}
Docdir:     %{prefix}/doc

%description
The MusicBrainz client library allows applications to make metadata
lookup to a MusicBrainz server, generate signatures from WAV data and
create CD Index Disk ids from audio CD roms.

%package devel
Summary: Headers for developing programs that will use libmusicbrainz
Group:      Development/Libraries
Requires:   %{name}

%description   devel
This package contains the headers that programmers will need to develop
applications which will use libmusicbrainz.

%prep
%setup -q

%build
./configure --prefix=%{prefix}
make 

%install
rm -rf $RPM_BUILD_ROOT
make prefix=$RPM_BUILD_ROOT%{prefix} install
strip $RPM_BUILD_ROOT%{prefix}/lib/*.so.*
strip $RPM_BUILD_ROOT%{prefix}/lib/*.a
strip $RPM_BUILD_ROOT%{prefix}/lib/*.so

%clean
rm -rf $RPM_BUILD_ROOT

%post -p /sbin/ldconfig
%postun -p /sbin/ldconfig

%files
%defattr(-, root, root)
%doc AUTHORS COPYING ChangeLog README TODO INSTALL
%{prefix}/lib/*.so.*

%files devel
%defattr(-, root, root)
%{prefix}/include/musicbrainz
%{prefix}/lib/*.la
%{prefix}/lib/*.a
%{prefix}/lib/*.so

%changelog
* Fri Sep 22 2000 Robert Kaye <rob@emusic.com> 1.0.0pre1
- First attempt to create a spec file for this library
