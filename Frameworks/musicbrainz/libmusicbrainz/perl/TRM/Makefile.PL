
use 5.006001;
use ExtUtils::MakeMaker;

# $Id: Makefile.PL 777 2005-11-20 03:57:01Z sander $
  
sub MY::postamble {
                                     
  return <<'EOT';
ck_version :
	@perl -MExtUtils::MakeMaker -le 'print "Version: " . MM->parse_version(shift)' $(VERSION_FROM)

cvs_export :
	cvs export -rcpan_$(NAME_SYM)_$(VERSION_SYM) -d$(DISTVNAME) $(CVS_PACKAGE)
  
cvs_tag :
	cvs tag cpan_$(NAME_SYM)_$(VERSION_SYM) .
	@echo tagged all files with $(NAME_SYM)_$(VERSION_SYM)
    
EOT
}


# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'MusicBrainz::TRM',
    'VERSION_FROM'	=> 'TRM.pm', # finds $VERSION
    'PREREQ_PM'		=> {'Test::More'  =>  0}, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM => 'TRM.pm', # retrieve abstract from module
       AUTHOR     => 'Sander van Zoest <svanzoest@cpan.org>') : ()),
    'LIBS'		=> ['-L/usr/local/lib -lstdc++ -lm -lmusicbrainz'], 
    'DEFINE'		=> '', # e.g., '-DHAVE_SOMETHING'
    'CCFLAGS'           => '',
	# Insert -I. if you add *.h files later:
    'INC'		=> '-I/usr/local/include -I.',
    'dist'              => {
        COMPRESS        => 'gzip -9f',
        SUFFIX          => 'gz',
        CI              => 'cvs commit'
                           },
     'realclean'        => {
        FILES           => 'MANIFEST.bak'
                           },
     macro              => {
        CVS_PACKAGE     => ''
                           },
	# Un-comment this if you add C files to link with later:
    # 'OBJECT'		=> '$(O_FILES)', # link all the C files too
);
