package Devel::PatchPerl::Plugin::MinGW;

use utf8;
use strict;
use warnings;
use 5.026002;
use Devel::PatchPerl;
use File::pushd qw[pushd];
use File::Spec;

# copy utility functions from Devel::PatchPerl
*_is = *Devel::PatchPerl::_is;
*_patch = *Devel::PatchPerl::_patch;

my @patch = (
    {
        perl => [
            qr/^5\.2[0-2]\.[0-9]+$/,
            qr/^5\.1[0-9]\.[0-9]+$/,
            qr/^5\.[0-9]\.[0-9]+$/,
        ],
        subs => [
            [ \&_patch_make_maker ],
        ],
    },
    {
        perl => [
            qr/^5\.22\.[0-9]+$/,
        ],
        subs => [
            [ \&_patch_gnumakefile_522 ],
        ],
    },
    {
        perl => [
            qr/^5\.2[01]\.[012]$/,
        ],
        subs => [
            [ \&_patch_win32_mkstemp ],
        ],
    },
	{
        perl => [
            qr/^5\.2[01]\.[0-9]+$/,
        ],
        subs => [
            [ \&_patch_make_maker_dirfilesep ],
            [ \&_patch_gnumakefile_520 ],
        ],
    },
);

sub patchperl {
    my ($class, %args) = @_;
    my $vers = $args{version};
    my $source = $args{source};

    my $dir = pushd( $source );

    # copy from https://github.com/bingos/devel-patchperl/blob/acdcf1d67ae426367f42ca763b9ba6b92dd90925/lib/Devel/PatchPerl.pm#L301-L307
    for my $p ( grep { _is( $_->{perl}, $vers ) } @patch ) {
       for my $s (@{$p->{subs}}) {
         my($sub, @args) = @$s;
         push @args, $vers unless scalar @args;
         $sub->(@args);
       }
    }
}

sub _write_or_die {
    my($file, $data) = @_;
    my $fh = IO::File->new(">$file") or die "$file: $!\n";
    $fh->print($data);
}

sub _patch_make_maker {
    # from https://github.com/Perl/perl5/commit/9cc600a92e7d683d4b053eb5e84ca8654ce82ac4
    # Win32 gmake needs SHELL to be specified
    _patch(<<'PATCH');
--- cpan/ExtUtils-MakeMaker/lib/ExtUtils/MM_Unix.pm
+++ cpan/ExtUtils-MakeMaker/lib/ExtUtils/MM_Unix.pm
@@ -317,8 +317,8 @@ sub const_cccmd {
 
 =item const_config (o)
 
-Defines a couple of constants in the Makefile that are imported from
-%Config.
+Sets SHELL if needed, then defines a couple of constants in the Makefile
+that are imported from %Config.
 
 =cut
 
@@ -326,7 +326,8 @@ sub const_config {
 # --- Constants Sections ---
 
     my($self) = shift;
-    my @m = <<"END";
+    my @m = $self->specify_shell(); # Usually returns empty string
+    push @m, <<"END";
 
 # These definitions are from config.sh (via $INC{'Config.pm'}).
 # They may have been overridden via Makefile.PL or on the command line.
@@ -3176,6 +3177,16 @@ MAKE_FRAG
     return $m;
 }
 
+=item specify_shell
+
+Specify SHELL if needed - not done on Unix.
+
+=cut
+
+sub specify_shell {
+  return '';
+}
+
 =item quote_paren
 
 Backslashes parentheses C<()> in command line arguments.
--- cpan/ExtUtils-MakeMaker/lib/ExtUtils/MM_Win32.pm
+++ cpan/ExtUtils-MakeMaker/lib/ExtUtils/MM_Win32.pm
@@ -232,6 +232,17 @@ sub platform_constants {
     return $make_frag;
 }
 
+=item specify_shell
+
+Set SHELL to $ENV{COMSPEC} only if make is type 'gmake'.
+
+=cut
+
+sub specify_shell {
+    my $self = shift;
+    return '' unless $self->is_make_type('gmake');
+    "\nSHELL = $ENV{COMSPEC}\n";
+}
 
 =item constants
PATCH
}

sub _patch_gnumakefile_522 {
    my $version = shift;
    my $makefile = <<'MAKEFILE';
#
# Makefile to build perl on Windows using GMAKE.
# Supported compilers:
#	MinGW with gcc-8.3.0 or later

##
## Make sure you read README.win32 *before* you mess with anything here!
##

#
# We set this to point to cmd.exe in case GNU Make finds sh.exe in the path.
# Comment this line out if necessary
#
SHELL := cmd.exe

# define whether you want to use native gcc compiler or cross-compiler
# possible values: gcc
#                  i686-w64-mingw32-gcc
#                  x86_64-w64-mingw32-gcc
GCCBIN := gcc

##
## Build configuration.  Edit the values below to suit your needs.
##

#
# Set these to wherever you want "gmake install" to put your
# newly built perl.
#
INST_DRV := c:
INST_TOP := $(INST_DRV)\perl

#
# Comment this out if you DON'T want your perl installation to be versioned.
# This means that the new installation will overwrite any files from the
# old installation at the same INST_TOP location.  Leaving it enabled is
# the safest route, as perl adds the extra version directory to all the
# locations it installs files to.  If you disable it, an alternative
# versioned installation can be obtained by setting INST_TOP above to a
# path that includes an arbitrary version string.
#
#INST_VER	:= \5.22.0

#
# Comment this out if you DON'T want your perl installation to have
# architecture specific components.  This means that architecture-
# specific files will be installed along with the architecture-neutral
# files.  Leaving it enabled is safer and more flexible, in case you
# want to build multiple flavors of perl and install them together in
# the same location.  Commenting it out gives you a simpler
# installation that is easier to understand for beginners.
#
#INST_ARCH	:= \$(ARCHNAME)

#
# Uncomment this if you want perl to run
# 	$Config{sitelibexp}\sitecustomize.pl
# before anything else.  This script can then be set up, for example,
# to add additional entries to @INC.
#
#USE_SITECUST	:= define

#
# uncomment to enable multiple interpreters.  This is needed for fork()
# emulation and for thread support, and is auto-enabled by USE_IMP_SYS
# and USE_ITHREADS below.
#
USE_MULTI	:= define

#
# Interpreter cloning/threads; now reasonably complete.
# This should be enabled to get the fork() emulation.  This needs (and
# will auto-enable) USE_MULTI above.
#
USE_ITHREADS	:= define

#
# uncomment to enable the implicit "host" layer for all system calls
# made by perl.  This is also needed to get fork().  This needs (and
# will auto-enable) USE_MULTI above.
#
USE_IMP_SYS	:= define

#
# Comment out next assign to disable perl's I/O subsystem and use compiler's
# stdio for IO - depending on your compiler vendor and run time library you may
# then get a number of fails from make test i.e. bugs - complain to them not us ;-).
# You will also be unable to take full advantage of perl5.8's support for multiple
# encodings and may see lower IO performance. You have been warned.
#
USE_PERLIO	:= define

#
# Comment this out if you don't want to enable large file support for
# some reason.  Should normally only be changed to maintain compatibility
# with an older release of perl.
#
USE_LARGE_FILES	:= define

#
# Uncomment this if you're building a 32-bit perl and want 64-bit integers.
# (If you're building a 64-bit perl then you will have 64-bit integers whether
# or not this is uncommented.)
# Note: This option is not supported in 32-bit MSVC60 builds.
#
#USE_64_BIT_INT	:= define

#
# Uncomment this if you want to support the use of long doubles in GCC builds.
# This option is not supported for MSVC builds.
#
#USE_LONG_DOUBLE :=define

#
# Uncomment this if you want to disable looking up values from
# HKEY_CURRENT_USER\Software\Perl and HKEY_LOCAL_MACHINE\Software\Perl in
# the Registry.
#
#USE_NO_REGISTRY := define

# MinGW or mingw-w64 with gcc-8.3.0 or later
CCTYPE		:= GCC

#
# If you are using Intel C++ Compiler uncomment this
#
#__ICC		:= define

#
# uncomment next line if you want debug version of perl (big/slow)
# If not enabled, we automatically try to use maximum optimization
# with all compilers that are known to have a working optimizer.
#
#CFG		:= Debug

#
# uncomment to enable linking with setargv.obj under the Visual C
# compiler. Setting this options enables perl to expand wildcards in
# arguments, but it may be harder to use alternate methods like
# File::DosGlob that are more powerful.  This option is supported only with
# Visual C.
#
#USE_SETARGV	:= define

#
# set this if you wish to use perl's malloc
# WARNING: Turning this on/off WILL break binary compatibility with extensions
# you may have compiled with/without it.  Be prepared to recompile all
# extensions if you change the default.  Currently, this cannot be enabled
# if you ask for USE_IMP_SYS above.
#
#PERL_MALLOC	:= define

#
# set this to enable debugging mstats
# This must be enabled to use the Devel::Peek::mstat() function.  This cannot
# be enabled without PERL_MALLOC as well.
#
#DEBUG_MSTATS	:= define

#
# set the install locations of the compiler include/libraries
#
CCHOME		:= C:\Strawberry\c

#
# Following sets $Config{incpath} and $Config{libpth}
#

CCINCDIR := $(CCHOME)\include
CCLIBDIR := $(CCHOME)\lib
CCDLLDIR := $(CCHOME)\bin
ARCHPREFIX :=

#
# Additional compiler flags can be specified here.
#
BUILDOPT	:= $(BUILDOPTEXTRA)

#
# Perl needs to read scripts in text mode so that the DATA filehandle
# works correctly with seek() and tell(), or around auto-flushes of
# all filehandles (e.g. by system(), backticks, fork(), etc).
#
# The current version on the ByteLoader module on CPAN however only
# works if scripts are read in binary mode.  But before you disable text
# mode script reading (and break some DATA filehandle functionality)
# please check first if an updated ByteLoader isn't available on CPAN.
#
BUILDOPT	+= -DPERL_TEXTMODE_SCRIPTS

#
# specify semicolon-separated list of extra directories that modules will
# look for libraries (spaces in path names need not be quoted)
#
EXTRALIBDIRS	:=


##
## Build configuration ends.
##

##################### CHANGE THESE ONLY IF YOU MUST #####################

PERL_MALLOC	?= undef
DEBUG_MSTATS	?= undef

USE_SITECUST	?= undef
USE_MULTI	?= undef
USE_ITHREADS	?= undef
USE_IMP_SYS	?= undef
USE_PERLIO	?= undef
USE_LARGE_FILES	?= undef
USE_64_BIT_INT	?= undef
USE_LONG_DOUBLE	?= undef
USE_NO_REGISTRY	?= undef

ifeq ($(USE_IMP_SYS),define)
PERL_MALLOC	= undef
endif

ifeq ($(PERL_MALLOC),undef)
DEBUG_MSTATS	= undef
endif

ifeq ($(DEBUG_MSTATS),define)
BUILDOPT	+= -DPERL_DEBUGGING_MSTATS
endif

ifeq ("$(USE_IMP_SYS) $(USE_MULTI)","define undef")
USE_MULTI	= define
endif

ifeq ("$(USE_ITHREADS) $(USE_MULTI)","define undef")
USE_MULTI	= define
endif

ifeq ($(USE_SITECUST),define)
BUILDOPT	+= -DUSE_SITECUSTOMIZE
endif

ifneq ($(USE_MULTI),undef)
BUILDOPT	+= -DPERL_IMPLICIT_CONTEXT
endif

ifneq ($(USE_IMP_SYS),undef)
BUILDOPT	+= -DPERL_IMPLICIT_SYS
endif

ifeq ($(USE_NO_REGISTRY),define)
BUILDOPT	+= -DWIN32_NO_REGISTRY
endif

WIN64 := define
PROCESSOR_ARCHITECTURE := x64
USE_64_BIT_INT = define
ARCHITECTURE = x64

ifeq ($(USE_MULTI),define)
ARCHNAME	= MSWin32-$(ARCHITECTURE)-multi
else
ifeq ($(USE_PERLIO),define)
ARCHNAME	= MSWin32-$(ARCHITECTURE)-perlio
else
ARCHNAME	= MSWin32-$(ARCHITECTURE)
endif
endif

ifeq ($(USE_PERLIO),define)
BUILDOPT	+= -DUSE_PERLIO
endif

ifeq ($(USE_ITHREADS),define)
ARCHNAME	:= $(ARCHNAME)-thread
endif

ifneq ($(WIN64),define)
ifeq ($(USE_64_BIT_INT),define)
ARCHNAME	:= $(ARCHNAME)-64int
endif
endif

ifeq ($(USE_LONG_DOUBLE),define)
ARCHNAME	:= $(ARCHNAME)-ld
endif

ARCHDIR		= ..\lib\$(ARCHNAME)
COREDIR		= ..\lib\CORE
AUTODIR		= ..\lib\auto
LIBDIR		= ..\lib
EXTDIR		= ..\ext
DISTDIR		= ..\dist
CPANDIR		= ..\cpan
PODDIR		= ..\pod
HTMLDIR		= .\html

#
INST_SCRIPT	= $(INST_TOP)$(INST_VER)\bin
INST_BIN	= $(INST_SCRIPT)$(INST_ARCH)
INST_LIB	= $(INST_TOP)$(INST_VER)\lib
INST_ARCHLIB	= $(INST_LIB)$(INST_ARCH)
INST_COREDIR	= $(INST_ARCHLIB)\CORE
INST_HTML	= $(INST_TOP)$(INST_VER)\html

#
# Programs to compile, build .lib files and link
#

MINIBUILDOPT    :=

CC		= $(ARCHPREFIX)gcc
LINK32		= $(ARCHPREFIX)g++
LIB32		= $(ARCHPREFIX)ar rc
IMPLIB		= $(ARCHPREFIX)dlltool
RSC		= $(ARCHPREFIX)windres

ifeq ($(USE_LONG_DOUBLE),define)
BUILDOPT        += -D__USE_MINGW_ANSI_STDIO
MINIBUILDOPT    += -D__USE_MINGW_ANSI_STDIO
endif

BUILDOPT        += -fwrapv
MINIBUILDOPT    += -fwrapv

i = .i
o = .o
a = .a

#
# Options
#

INCLUDES	= -I.\include -I. -I..
DEFINES		= -DWIN32 -DWIN64 -DCONSERVATIVE
LOCDEFS		= -DPERLDLL -DPERL_CORE
CXX_FLAG	= -xc++
LIBC		=
LIBFILES	= $(LIBC) -lmoldname -lkernel32 -luser32 -lgdi32 -lwinspool \
	-lcomdlg32 -ladvapi32 -lshell32 -lole32 -loleaut32 -lnetapi32 \
	-luuid -lws2_32 -lmpr -lwinmm -lversion -lodbc32 -lodbccp32 -lcomctl32

ifeq ($(CFG),Debug)
OPTIMIZE	= -g -O2 -DDEBUGGING
LINK_DBG	= -g
else
OPTIMIZE	= -s -O2
LINK_DBG	= -s
endif

EXTRACFLAGS	=
CFLAGS		= $(EXTRACFLAGS) $(INCLUDES) $(DEFINES) $(LOCDEFS) $(OPTIMIZE)
LINK_FLAGS	= $(LINK_DBG) -L"$(INST_COREDIR)" -L"$(CCLIBDIR)"
OBJOUT_FLAG	= -o
EXEOUT_FLAG	= -o
LIBOUT_FLAG	=
PDBOUT		=

BUILDOPT	+= -fno-strict-aliasing -mms-bitfields
MINIBUILDOPT	+= -fno-strict-aliasing

TESTPREPGCC	= test-prep-gcc

CFLAGS_O	= $(CFLAGS) $(BUILDOPT)
BLINK_FLAGS	= $(PRIV_LINK_FLAGS) $(LINK_FLAGS)

#################### do not edit below this line #######################
############# NO USER-SERVICEABLE PARTS BEYOND THIS POINT ##############

#prevent -j from reaching EUMM/make_ext.pl/"sub makes", Win32 EUMM not parallel
#compatible yet
unexport MAKEFLAGS

a ?= .lib

.SUFFIXES : .c .i $(o) .dll $(a) .exe .rc .res

%$(o): %.c
	$(CC) -c -I$(<D) $(CFLAGS_O) $(OBJOUT_FLAG)$@ $(PDBOUT) $<

%.i: %.c
	$(CC) -c -I$(<D) $(CFLAGS_O) -E $< >$@

%.c: %.y
	$(NOOP)

%.dll: %$(o)
	$(LINK32) -o $@ $(BLINK_FLAGS) $< $(LIBFILES)
	$(IMPLIB) --input-def $(*F).def --output-lib $(*F).a $@

%.res: %.rc
	$(RSC) --use-temp-file --include-dir=. --include-dir=.. -O COFF -D INCLUDE_MANIFEST -i $< -o $@

#
# various targets

#do not put $(MINIPERL) as a dep/prereq in a rule, instead put $(HAVEMINIPERL)
#$(MINIPERL) is not a buildable target, use "gmake mp" if you want to just build
#miniperl alone
MINIPERL	= ..\miniperl.exe
HAVEMINIPERL	= ..\lib\buildcustomize.pl
MINIDIR		= mini
PERLEXE		= ..\perl.exe
WPERLEXE	= ..\wperl.exe
PERLEXESTATIC	= ..\perl-static.exe
STATICDIR	= .\static.tmp
GLOBEXE		= ..\perlglob.exe
CONFIGPM	= ..\lib\Config.pm
GENUUDMAP	= ..\generate_uudmap.exe
PERLSTATIC	=

# Unicode data files generated by mktables
UNIDATAFILES	 = ..\lib\unicore\Decomposition.pl ..\lib\unicore\TestProp.pl \
		   ..\lib\unicore\CombiningClass.pl ..\lib\unicore\Name.pl \
		   ..\lib\unicore\UCD.pl ..\lib\unicore\Name.pm            \
		   ..\lib\unicore\Heavy.pl ..\lib\unicore\mktables.lst

# Directories of Unicode data files generated by mktables
UNIDATADIR1	= ..\lib\unicore\To
UNIDATADIR2	= ..\lib\unicore\lib

PERLEXE_MANIFEST= .\perlexe.manifest
PERLEXE_ICO	= .\perlexe.ico
PERLEXE_RES	= .\perlexe.res
PERLDLL_RES	=

# Nominate a target which causes extensions to be re-built
# This used to be $(PERLEXE), but at worst it is the .dll that they depend
# on and really only the interface - i.e. the .def file used to export symbols
# from the .dll
PERLDEP = $(PERLIMPLIB)


PL2BAT		= bin\pl2bat.pl

UTILS		=			\
		..\utils\h2ph		\
		..\utils\splain		\
		..\utils\perlbug	\
		..\utils\pl2pm 		\
		..\utils\c2ph		\
		..\utils\pstruct	\
		..\utils\h2xs		\
		..\utils\perldoc	\
		..\utils\perlivp	\
		..\utils\libnetcfg	\
		..\utils\enc2xs		\
		..\utils\encguess	\
		..\utils\piconv		\
		..\utils\corelist	\
		..\utils\cpan		\
		..\utils\xsubpp		\
		..\utils\pod2html	\
		..\utils\prove		\
		..\utils\ptar		\
		..\utils\ptardiff	\
		..\utils\ptargrep	\
		..\utils\zipdetails	\
		..\utils\shasum		\
		..\utils\instmodsh	\
		..\utils\json_pp	\
		bin\exetype.pl		\
		bin\runperl.pl		\
		bin\pl2bat.pl		\
		bin\perlglob.pl		\
		bin\search.pl

CFGSH_TMPL	= config.gc
CFGH_TMPL	= config_H.gc
PERLIMPLIB	= $(COREDIR)\libperl__PERL_MINOR_VERSION__$(a)
PERLIMPLIBBASE	= libperl__PERL_MINOR_VERSION__$(a)
PERLSTATICLIB	= ..\libperl__PERL_MINOR_VERSION__s$(a)
INT64		= long long
PERLEXPLIB	= $(COREDIR)\perl__PERL_MINOR_VERSION__.exp
PERLDLL		= ..\perl__PERL_MINOR_VERSION__.dll

# don't let "gmake -n all" try to run "miniperl.exe make_ext.pl"
PLMAKE		= gmake

XCOPY		= xcopy /f /r /i /d /y
RCOPY		= xcopy /f /r /i /e /d /y
NOOP		= @rem

#first ones are arrange in compile time order for faster parallel building
MICROCORE_SRC	=		\
		..\av.c		\
		..\caretx.c	\
		..\deb.c	\
		..\doio.c	\
		..\doop.c	\
		..\dump.c	\
		..\globals.c	\
		..\gv.c		\
		..\mro_core.c	\
		..\hv.c		\
		..\locale.c	\
		..\keywords.c	\
		..\mathoms.c    \
		..\mg.c		\
		..\numeric.c	\
		..\op.c		\
		..\pad.c	\
		..\perl.c	\
		..\perlapi.c	\
		..\perly.c	\
		..\pp.c		\
		..\pp_ctl.c	\
		..\pp_hot.c	\
		..\pp_pack.c	\
		..\pp_sort.c	\
		..\pp_sys.c	\
		..\reentr.c	\
		..\regcomp.c	\
		..\regexec.c	\
		..\run.c	\
		..\scope.c	\
		..\sv.c		\
		..\taint.c	\
		..\toke.c	\
		..\universal.c	\
		..\utf8.c	\
		..\util.c

EXTRACORE_SRC	+= perllib.c

ifeq ($(PERL_MALLOC),define)
EXTRACORE_SRC	+= ..\malloc.c
endif

EXTRACORE_SRC	+= ..\perlio.c

WIN32_SRC	=		\
		.\win32.c	\
		.\win32io.c	\
		.\win32sck.c	\
		.\win32thread.c	\
		.\fcrypt.c

CORE_NOCFG_H	=		\
		..\av.h		\
		..\cop.h	\
		..\cv.h		\
		..\dosish.h	\
		..\embed.h	\
		..\form.h	\
		..\gv.h		\
		..\handy.h	\
		..\hv.h		\
		..\hv_func.h	\
		..\iperlsys.h	\
		..\mg.h		\
		..\nostdio.h	\
		..\op.h		\
		..\opcode.h	\
		..\perl.h	\
		..\perlapi.h	\
		..\perlsdio.h	\
		..\perly.h	\
		..\pp.h		\
		..\proto.h	\
		..\regcomp.h	\
		..\regexp.h	\
		..\scope.h	\
		..\sv.h		\
		..\thread.h	\
		..\unixish.h	\
		..\utf8.h	\
		..\util.h	\
		..\warnings.h	\
		..\XSUB.h	\
		..\EXTERN.h	\
		..\perlvars.h	\
		..\intrpvar.h	\
		.\include\dirent.h	\
		.\include\netdb.h	\
		.\include\sys\errno2.h	\
		.\include\sys\socket.h	\
		.\win32.h

CORE_H		= $(CORE_NOCFG_H) .\config.h ..\git_version.h

UUDMAP_H	= ..\uudmap.h
BITCOUNT_H	= ..\bitcount.h
MG_DATA_H	= ..\mg_data.h
GENERATED_HEADERS = $(UUDMAP_H) $(BITCOUNT_H) $(MG_DATA_H)
#a stub ppport.h must be generated so building XS modules, .c->.obj wise, will
#work, so this target also represents creating the COREDIR and filling it
HAVE_COREDIR	= $(COREDIR)\ppport.h

MICROCORE_OBJ	= $(MICROCORE_SRC:.c=$(o))
CORE_OBJ	= $(MICROCORE_OBJ) $(EXTRACORE_SRC:.c=$(o))
WIN32_OBJ	= $(WIN32_SRC:.c=$(o))

MINICORE_OBJ	= $(subst ..\,mini\,$(MICROCORE_OBJ))	\
		  $(MINIDIR)\miniperlmain$(o)	\
		  $(MINIDIR)\perlio$(o)
MINIWIN32_OBJ	= $(subst .\,mini\,$(WIN32_OBJ))
MINI_OBJ	= $(MINICORE_OBJ) $(MINIWIN32_OBJ)
DLL_OBJ		= $(DYNALOADER)

PERLDLL_OBJ	= $(CORE_OBJ)
PERLEXE_OBJ	= perlmain$(o)
PERLEXEST_OBJ	= perlmainst$(o)

PERLDLL_OBJ	+= $(WIN32_OBJ) $(DLL_OBJ)

ifneq ($(USE_SETARGV),)
SETARGV_OBJ	= setargv$(o)
endif

ifeq ($(ALL_STATIC),define)
# some exclusions, unfortunately, until fixed:
#  - MakeMaker isn't capable enough for SDBM_File (small bug)
STATIC_EXT	= * !SDBM_File
else
# specify static extensions here, for example:
# (be sure to include Win32CORE to load Win32 on demand)
#STATIC_EXT	= Win32CORE Cwd Compress/Raw/Zlib
STATIC_EXT	= Win32CORE
endif

DYNALOADER	= ..\DynaLoader$(o)

# vars must be separated by "\t+~\t+", since we're using the tempfile
# version of config_sh.pl (we were overflowing someone's buffer by
# trying to fit them all on the command line)
#	-- BKS 10-17-1999
CFG_VARS	=					\
		"INST_TOP=$(INST_TOP)"			\
		"INST_VER=$(INST_VER)"			\
		"INST_ARCH=$(INST_ARCH)"		\
		"archname=$(ARCHNAME)"			\
		"cc=$(CC)"				\
		"ld=$(LINK32)"				\
		"ccflags=$(subst ",\",$(EXTRACFLAGS) $(OPTIMIZE) $(DEFINES) $(BUILDOPT))" \
		"usecplusplus=$(USE_CPLUSPLUS)"		\
		"cf_email=$(EMAIL)"			\
		"d_mymalloc=$(PERL_MALLOC)"		\
		"libs=$(LIBFILES)"			\
		"incpath=$(subst ",\",$(CCINCDIR))"			\
		"libperl=$(subst ",\",$(PERLIMPLIBBASE))"		\
		"libpth=$(subst ",\",$(CCLIBDIR);$(EXTRALIBDIRS))"	\
		"libc=$(LIBC)"				\
		"make=$(PLMAKE)"				\
		"_o=$(o)"				\
		"obj_ext=$(o)"				\
		"_a=$(a)"				\
		"lib_ext=$(a)"				\
		"static_ext=$(STATIC_EXT)"		\
		"usethreads=$(USE_ITHREADS)"		\
		"useithreads=$(USE_ITHREADS)"		\
		"usemultiplicity=$(USE_MULTI)"		\
		"useperlio=$(USE_PERLIO)"		\
		"use64bitint=$(USE_64_BIT_INT)"		\
		"uselongdouble=$(USE_LONG_DOUBLE)"	\
		"uselargefiles=$(USE_LARGE_FILES)"	\
		"usesitecustomize=$(USE_SITECUST)"	\
		"LINK_FLAGS=$(subst ",\",$(LINK_FLAGS))"\
		"optimize=$(subst ",\",$(OPTIMIZE))"	\
		"ARCHPREFIX=$(ARCHPREFIX)"		\
		"WIN64=$(WIN64)"

#
# Top targets
#

.PHONY: all

all : .\config.h ..\git_version.h $(GLOBEXE) $(CONFIGPM) \
		$(UNIDATAFILES) MakePPPort $(PERLEXE) Extensions_nonxs Extensions $(PERLSTATIC)
		@echo Everything is up to date. '$(MAKE_BARE) test' to run test suite.

..\regcomp$(o) : ..\regnodes.h ..\regcharclass.h

..\regexec$(o) : ..\regnodes.h ..\regcharclass.h

#----------------------------------------------------------------

$(GLOBEXE) : perlglob.c
	$(LINK32) $(OPTIMIZE) $(BLINK_FLAGS) -mconsole -o $@ perlglob.c $(LIBFILES)

..\git_version.h : $(HAVEMINIPERL) ..\make_patchnum.pl
	$(MINIPERL) -I..\lib ..\make_patchnum.pl

# make sure that we recompile perl.c if the git version changes
..\perl$(o) : ..\git_version.h

..\config.sh : $(CFGSH_TMPL) $(HAVEMINIPERL) config_sh.PL FindExt.pm
	$(MINIPERL) -I..\lib config_sh.PL $(CFG_VARS) $(CFGSH_TMPL) > ..\config.sh

$(CONFIGPM) : $(HAVEMINIPERL) ..\config.sh config_h.PL
	$(MINIPERL) -I..\lib ..\configpm --chdir=..
	$(XCOPY) *.h $(COREDIR)\\*.*
	$(RCOPY) include $(COREDIR)\\*.*
	$(XCOPY) ..\\*.h $(COREDIR)\\*.*
	-$(MINIPERL) -I..\lib config_h.PL "ARCHPREFIX=$(ARCHPREFIX)"

# See the comment in Makefile.SH explaining this seemingly cranky ordering
..\lib\buildcustomize.pl : $(MINI_OBJ) ..\write_buildcustomize.pl
	$(LINK32) -mconsole -o $(MINIPERL) $(BLINK_FLAGS) $(MINI_OBJ) $(LIBFILES)
	$(MINIPERL) -I..\lib -f ..\write_buildcustomize.pl ..

#
# Copy the template config.h and set configurables at the end of it
# as per the options chosen and compiler used.
# Note: This config.h is only used to build miniperl.exe anyway, but
# it's as well to have its options correct to be sure that it builds
# and so that it's "-V" options are correct for use by makedef.pl. The
# real config.h used to build perl.exe is generated from the top-level
# config_h.SH by config_h.PL (run by miniperl.exe).
#
.\config.h : $(CONFIGPM)
$(MINIDIR)\.exists : $(CFGH_TMPL)
	if not exist "$(MINIDIR)" mkdir "$(MINIDIR)"
	copy $(CFGH_TMPL) config.h
	@(echo.&& \
	echo #ifndef _config_h_footer_&& \
	echo #define _config_h_footer_&& \
	echo #undef Off_t&& \
	echo #undef LSEEKSIZE&& \
	echo #undef Off_t_size&& \
	echo #undef PTRSIZE&& \
	echo #undef SSize_t&& \
	echo #undef HAS_ATOLL&& \
	echo #undef HAS_STRTOLL&& \
	echo #undef HAS_STRTOULL&& \
	echo #undef Size_t_size&& \
	echo #undef IVTYPE&& \
	echo #undef UVTYPE&& \
	echo #undef IVSIZE&& \
	echo #undef UVSIZE&& \
	echo #undef NV_PRESERVES_UV&& \
	echo #undef NV_PRESERVES_UV_BITS&& \
	echo #undef IVdf&& \
	echo #undef UVuf&& \
	echo #undef UVof&& \
	echo #undef UVxf&& \
	echo #undef UVXf&& \
	echo #undef USE_64_BIT_INT&& \
	echo #undef Gconvert&& \
	echo #undef HAS_FREXPL&& \
	echo #undef HAS_ISNANL&& \
	echo #undef HAS_MODFL&& \
	echo #undef HAS_MODFL_PROTO&& \
	echo #undef HAS_SQRTL&& \
	echo #undef HAS_STRTOLD&& \
	echo #undef PERL_PRIfldbl&& \
	echo #undef PERL_PRIgldbl&& \
	echo #undef PERL_PRIeldbl&& \
	echo #undef PERL_SCNfldbl&& \
	echo #undef NVTYPE&& \
	echo #undef NVSIZE&& \
	echo #undef LONG_DOUBLESIZE&& \
	echo #undef NV_OVERFLOWS_INTEGERS_AT&& \
	echo #undef NVef&& \
	echo #undef NVff&& \
	echo #undef NVgf&& \
	echo #undef USE_LONG_DOUBLE)>> config.h
ifeq ($(USE_LARGE_FILES),define)
	@(echo #define Off_t $(INT64)&& \
	echo #define LSEEKSIZE ^8&& \
	echo #define Off_t_size ^8)>> config.h
else
	@(echo #define Off_t long&& \
	echo #define LSEEKSIZE ^4&& \
	echo #define Off_t_size ^4)>> config.h
endif
ifeq ($(WIN64),define)
	@(echo #define PTRSIZE ^8&& \
	echo #define SSize_t $(INT64)&& \
	echo #define HAS_ATOLL&& \
	echo #define HAS_STRTOLL&& \
	echo #define HAS_STRTOULL&& \
	echo #define Size_t_size ^8)>> config.h
else
	@(echo #define PTRSIZE ^4&& \
	echo #define SSize_t int&& \
	echo #undef HAS_ATOLL&& \
	echo #undef HAS_STRTOLL&& \
	echo #undef HAS_STRTOULL&& \
	echo #define Size_t_size ^4)>> config.h
endif
ifeq ($(USE_64_BIT_INT),define)
	@(echo #define IVTYPE $(INT64)&& \
	echo #define UVTYPE unsigned $(INT64)&& \
	echo #define IVSIZE ^8&& \
	echo #define UVSIZE ^8)>> config.h
ifeq ($(USE_LONG_DOUBLE),define)
	@(echo #define NV_PRESERVES_UV&& \
	echo #define NV_PRESERVES_UV_BITS 64)>> config.h
else
	@(echo #undef NV_PRESERVES_UV&& \
	echo #define NV_PRESERVES_UV_BITS 53)>> config.h
endif
	@(echo #define IVdf "I64d"&& \
	echo #define UVuf "I64u"&& \
	echo #define UVof "I64o"&& \
	echo #define UVxf "I64x"&& \
	echo #define UVXf "I64X"&& \
	echo #define USE_64_BIT_INT)>> config.h
else
	@(echo #define IVTYPE long&& \
	echo #define UVTYPE unsigned long&& \
	echo #define IVSIZE ^4&& \
	echo #define UVSIZE ^4&& \
	echo #define NV_PRESERVES_UV&& \
	echo #define NV_PRESERVES_UV_BITS 32&& \
	echo #define IVdf "ld"&& \
	echo #define UVuf "lu"&& \
	echo #define UVof "lo"&& \
	echo #define UVxf "lx"&& \
	echo #define UVXf "lX"&& \
	echo #undef USE_64_BIT_INT)>> config.h
endif
ifeq ($(USE_LONG_DOUBLE),define)
	@(echo #define Gconvert^(x,n,t,b^) sprintf^(^(b^),"%%.*""Lg",^(n^),^(x^)^)&& \
	echo #define HAS_FREXPL&& \
	echo #define HAS_ISNANL&& \
	echo #define HAS_MODFL&& \
	echo #define HAS_MODFL_PROTO&& \
	echo #define HAS_SQRTL&& \
	echo #define HAS_STRTOLD&& \
	echo #define PERL_PRIfldbl "Lf"&& \
	echo #define PERL_PRIgldbl "Lg"&& \
	echo #define PERL_PRIeldbl "Le"&& \
	echo #define PERL_SCNfldbl "Lf"&& \
	echo #define NVTYPE long double)>> config.h
ifeq ($(WIN64),define)
	@(echo #define NVSIZE ^16&& \
	echo #define LONG_DOUBLESIZE ^16)>> config.h
else
	@(echo #define NVSIZE ^12&& \
	echo #define LONG_DOUBLESIZE ^12)>> config.h
endif
	@(echo #define NV_OVERFLOWS_INTEGERS_AT 256.0*256.0*256.0*256.0*256.0*256.0*256.0*2.0*2.0*2.0*2.0*2.0*2.0*2.0*2.0&& \
	echo #define NVef "Le"&& \
	echo #define NVff "Lf"&& \
	echo #define NVgf "Lg"&& \
	echo #define USE_LONG_DOUBLE)>> config.h
else
	@(echo #define Gconvert^(x,n,t,b^) sprintf^(^(b^),"%%.*g",^(n^),^(x^)^)&& \
	echo #undef HAS_FREXPL&& \
	echo #undef HAS_ISNANL&& \
	echo #undef HAS_MODFL&& \
	echo #undef HAS_MODFL_PROTO&& \
	echo #undef HAS_SQRTL&& \
	echo #undef HAS_STRTOLD&& \
	echo #undef PERL_PRIfldbl&& \
	echo #undef PERL_PRIgldbl&& \
	echo #undef PERL_PRIeldbl&& \
	echo #undef PERL_SCNfldbl&& \
	echo #define NVTYPE double&& \
	echo #define NVSIZE ^8&& \
	echo #define LONG_DOUBLESIZE ^8&& \
	echo #define NV_OVERFLOWS_INTEGERS_AT 256.0*256.0*256.0*256.0*256.0*256.0*2.0*2.0*2.0*2.0*2.0&& \
	echo #define NVef "e"&& \
	echo #define NVff "f"&& \
	echo #define NVgf "g"&& \
	echo #undef USE_LONG_DOUBLE)>> config.h
endif
ifeq ($(USE_CPLUSPLUS),define)
	@(echo #define USE_CPLUSPLUS&& \
	echo #endif)>> config.h
else
	@(echo #undef USE_CPLUSPLUS&& \
	echo #endif)>> config.h
endif
#separate line since this is sentinal that this target is done
	rem. > $(MINIDIR)\.exists

$(MINICORE_OBJ) : $(CORE_NOCFG_H)
	$(CC) -c $(CFLAGS) $(MINIBUILDOPT) -DPERL_EXTERNAL_GLOB -DPERL_IS_MINIPERL $(OBJOUT_FLAG)$@ $(PDBOUT) ..\$(*F).c

$(MINIWIN32_OBJ) : $(CORE_NOCFG_H)
	$(CC) -c $(CFLAGS) $(MINIBUILDOPT) -DPERL_IS_MINIPERL $(OBJOUT_FLAG)$@ $(PDBOUT) $(*F).c

# -DPERL_IMPLICIT_SYS needs C++ for perllib.c
# rules wrapped in .IFs break Win9X build (we end up with unbalanced []s unless
# unless the .IF is true), so instead we use a .ELSE with the default.
# This is the only file that depends on perlhost.h, vmem.h, and vdir.h

perllib$(o)	: perllib.c perllibst.h .\perlhost.h .\vdir.h .\vmem.h
ifeq ($(USE_IMP_SYS),define)
	$(CC) -c -I. $(CFLAGS_O) $(CXX_FLAG) $(OBJOUT_FLAG)$@ $(PDBOUT) perllib.c
else
	$(CC) -c -I. $(CFLAGS_O) $(OBJOUT_FLAG)$@ $(PDBOUT) perllib.c
endif

# 1. we don't want to rebuild miniperl.exe when config.h changes
# 2. we don't want to rebuild miniperl.exe with non-default config.h
# 3. we can't have miniperl.exe depend on git_version.h, as miniperl creates it
$(MINI_OBJ)	: $(MINIDIR)\.exists $(CORE_NOCFG_H)

$(WIN32_OBJ)	: $(CORE_H)

$(CORE_OBJ)	: $(CORE_H)

$(DLL_OBJ)	: $(CORE_H)


perllibst.h : $(HAVEMINIPERL) $(CONFIGPM) create_perllibst_h.pl
	$(MINIPERL) -I..\lib create_perllibst_h.pl

perldll.def : $(HAVEMINIPERL) $(CONFIGPM) ..\embed.fnc ..\makedef.pl
	$(MINIPERL) -I..\lib -w ..\makedef.pl PLATFORM=win32 $(OPTIMIZE) $(DEFINES) \
	$(BUILDOPT) CCTYPE=$(CCTYPE) TARG_DIR=..\ > perldll.def

$(PERLEXPLIB) : $(PERLIMPLIB)

$(PERLIMPLIB) : perldll.def
	$(IMPLIB) -k -d perldll.def -l $(PERLIMPLIB) -e $(PERLEXPLIB)

$(PERLDLL): perldll.def $(PERLEXPLIB) $(PERLDLL_OBJ) Extensions_static
	$(LINK32) -mdll -o $@ $(BLINK_FLAGS) \
	   $(PERLDLL_OBJ) $(shell type Extensions_static) $(LIBFILES) $(PERLEXPLIB)

$(PERLSTATICLIB): $(PERLDLL_OBJ) Extensions_static
	$(LIB32) $(LIB_FLAGS) $@ $(PERLDLL_OBJ)
	if exist $(STATICDIR) rmdir /s /q $(STATICDIR)
	for %%i in ($(shell type Extensions_static)) do \
		@mkdir $(STATICDIR) && cd $(STATICDIR) && \
		$(ARCHPREFIX)ar x ..\%%i && \
		$(ARCHPREFIX)ar q ..\$@ *$(o) && \
		cd .. && rmdir /s /q $(STATICDIR)
	$(XCOPY) $(PERLSTATICLIB) $(COREDIR)

$(PERLEXE_RES): perlexe.rc $(PERLEXE_MANIFEST) $(PERLEXE_ICO)

$(MINIDIR)\globals$(o) : $(GENERATED_HEADERS)

$(UUDMAP_H) $(MG_DATA_H) : $(BITCOUNT_H)

$(BITCOUNT_H) : $(GENUUDMAP)
	$(GENUUDMAP) $(GENERATED_HEADERS)

$(GENUUDMAP) : ..\mg_raw.h
	$(LINK32) $(CFLAGS_O) -o..\generate_uudmap.exe ..\generate_uudmap.c \
	$(BLINK_FLAGS) $(LIBFILES)

#This generates a stub ppport.h & creates & fills /lib/CORE to allow for XS
#building .c->.obj wise (linking is a different thing). This target is AKA
#$(HAVE_COREDIR).
$(COREDIR)\ppport.h : $(CORE_H)
	$(XCOPY) *.h $(COREDIR)\\*.*
	$(RCOPY) include $(COREDIR)\\*.*
	$(XCOPY) ..\\*.h $(COREDIR)\\*.*
	rem. > $@

perlmain$(o) : runperl.c $(CONFIGPM)
	$(CC) $(subst -DPERLDLL,-UPERLDLL,$(CFLAGS_O)) $(OBJOUT_FLAG)$@ $(PDBOUT) -c runperl.c

perlmainst$(o) : runperl.c $(CONFIGPM)
	$(CC) $(CFLAGS_O) $(OBJOUT_FLAG)$@ $(PDBOUT) -c runperl.c

$(PERLEXE): $(PERLDLL) $(CONFIGPM) $(PERLEXE_OBJ) $(PERLEXE_RES) $(PERLIMPLIB)
	$(LINK32) -mconsole -o $@ $(BLINK_FLAGS)  \
	    $(PERLEXE_OBJ) $(PERLEXE_RES) $(PERLIMPLIB) $(LIBFILES)
	copy $(PERLEXE) $(WPERLEXE)
	$(MINIPERL) -I..\lib bin\exetype.pl $(WPERLEXE) WINDOWS

$(PERLEXESTATIC): $(PERLSTATICLIB) $(CONFIGPM) $(PERLEXEST_OBJ) $(PERLEXE_RES)
	$(LINK32) -mconsole -o $@ $(BLINK_FLAGS) \
	    $(PERLEXEST_OBJ) $(PERLEXE_RES) $(PERLSTATICLIB) $(LIBFILES)

#-------------------------------------------------------------------------------
# There's no direct way to mark a dependency on
# DynaLoader.pm, so this will have to do

MakePPPort: $(HAVEMINIPERL) $(CONFIGPM) Extensions_nonxs
	$(MINIPERL) -I..\lib ..\mkppport


#most of deps of this target are in DYNALOADER and therefore omitted here
Extensions : ..\make_ext.pl ..\lib\buildcustomize.pl $(PERLDEP) $(CONFIGPM) $(DYNALOADER)
	$(XCOPY) ..\\*.h $(COREDIR)\\*.*
	$(MINIPERL) -I..\lib ..\make_ext.pl "MAKE=$(PLMAKE)" --dir=$(CPANDIR) --dir=$(DISTDIR) --dir=$(EXTDIR) --dynamic --verbose

Extensions_static : ..\make_ext.pl ..\lib\buildcustomize.pl list_static_libs.pl $(CONFIGPM) Extensions_nonxs
	$(XCOPY) ..\\*.h $(COREDIR)\\*.*
	$(MINIPERL) -I..\lib ..\make_ext.pl "MAKE=$(PLMAKE)" --dir=$(CPANDIR) --dir=$(DISTDIR) --dir=$(EXTDIR) --static --verbose
	$(MINIPERL) -I..\lib list_static_libs.pl > Extensions_static

Extensions_nonxs : ..\make_ext.pl ..\lib\buildcustomize.pl $(PERLDEP) $(CONFIGPM) ..\pod\perlfunc.pod
	$(XCOPY) ..\\*.h $(COREDIR)\\*.*
	$(MINIPERL) -I..\lib ..\make_ext.pl "MAKE=$(PLMAKE)" --dir=$(CPANDIR) --dir=$(DISTDIR) --dir=$(EXTDIR) --nonxs --verbose

#lib must be built, it can't be buildcustomize.pl-ed, and is required for XS building
$(DYNALOADER) : ..\make_ext.pl ..\lib\buildcustomize.pl $(PERLDEP) $(CONFIGPM) Extensions_nonxs
	$(XCOPY) ..\\*.h $(COREDIR)\\*.*
	$(MINIPERL) -I..\lib ..\make_ext.pl "MAKE=$(PLMAKE)" --dir=$(EXTDIR) --dynaloader --verbose

#-------------------------------------------------------------------------------

doc: $(PERLEXE) ..\pod\perltoc.pod
	$(PERLEXE) -I..\lib ..\installhtml --podroot=.. --htmldir=$(HTMLDIR) \
	    --podpath=pod:lib:utils --htmlroot="file://$(subst :,|,$(INST_HTML))"\
	    --recurse

..\utils\Makefile: $(CONFIGPM) ..\utils\Makefile.PL
	$(MINIPERL) -I..\lib ..\utils\Makefile.PL ..

# Note that this next section is parsed (and regenerated) by pod/buildtoc
# so please check that script before making structural changes here
utils: $(HAVEMINIPERL) ..\utils\Makefile
	cd ..\utils && $(PLMAKE) PERL=$(MINIPERL)
	copy ..\README.aix      ..\pod\perlaix.pod
	copy ..\README.amiga    ..\pod\perlamiga.pod
	copy ..\README.android  ..\pod\perlandroid.pod
	copy ..\README.bs2000   ..\pod\perlbs2000.pod
	copy ..\README.ce       ..\pod\perlce.pod
	copy ..\README.cn       ..\pod\perlcn.pod
	copy ..\README.cygwin   ..\pod\perlcygwin.pod
	copy ..\README.dos      ..\pod\perldos.pod
	copy ..\README.freebsd  ..\pod\perlfreebsd.pod
	copy ..\README.haiku    ..\pod\perlhaiku.pod
	copy ..\README.hpux     ..\pod\perlhpux.pod
	copy ..\README.hurd     ..\pod\perlhurd.pod
	copy ..\README.irix     ..\pod\perlirix.pod
	copy ..\README.jp       ..\pod\perljp.pod
	copy ..\README.ko       ..\pod\perlko.pod
	copy ..\README.linux    ..\pod\perllinux.pod
	copy ..\README.macos    ..\pod\perlmacos.pod
	copy ..\README.macosx   ..\pod\perlmacosx.pod
	copy ..\README.netware  ..\pod\perlnetware.pod
	copy ..\README.openbsd  ..\pod\perlopenbsd.pod
	copy ..\README.os2      ..\pod\perlos2.pod
	copy ..\README.os390    ..\pod\perlos390.pod
	copy ..\README.os400    ..\pod\perlos400.pod
	copy ..\README.plan9    ..\pod\perlplan9.pod
	copy ..\README.qnx      ..\pod\perlqnx.pod
	copy ..\README.riscos   ..\pod\perlriscos.pod
	copy ..\README.solaris  ..\pod\perlsolaris.pod
	copy ..\README.symbian  ..\pod\perlsymbian.pod
	copy ..\README.synology ..\pod\perlsynology.pod
	copy ..\README.tru64    ..\pod\perltru64.pod
	copy ..\README.tw       ..\pod\perltw.pod
	copy ..\README.vos      ..\pod\perlvos.pod
	copy ..\README.win32    ..\pod\perlwin32.pod
	copy ..\pod\perldelta.pod ..\pod\perl__PERL_VERSION__delta.pod
	$(MINIPERL) -I..\lib $(PL2BAT) $(UTILS)
	$(MINIPERL) -I..\lib ..\autodoc.pl ..
	$(MINIPERL) -I..\lib ..\pod\perlmodlib.PL -q ..

..\pod\perltoc.pod: $(PERLEXE) Extensions Extensions_nonxs
	$(PERLEXE) -f ..\pod\buildtoc -q

install : all installbare installhtml

installbare : utils ..\pod\perltoc.pod
	$(PERLEXE) ..\installperl
	if exist $(WPERLEXE) $(XCOPY) $(WPERLEXE) $(INST_BIN)\$(NULL)
	if exist $(PERLEXESTATIC) $(XCOPY) $(PERLEXESTATIC) $(INST_BIN)\$(NULL)
	$(XCOPY) $(GLOBEXE) $(INST_BIN)\$(NULL)
	if exist ..\perl*.pdb $(XCOPY) ..\perl*.pdb $(INST_BIN)\$(NULL)
	$(XCOPY) "bin\*.bat" $(INST_SCRIPT)\$(NULL)

installhtml : doc
	$(RCOPY) $(HTMLDIR)\*.* $(INST_HTML)\$(NULL)

inst_lib : $(CONFIGPM)
	$(RCOPY) ..\lib $(INST_LIB)\$(NULL)

$(UNIDATAFILES) : ..\pod\perluniprops.pod

..\pod\perluniprops.pod: ..\lib\unicore\mktables $(CONFIGPM) $(HAVEMINIPERL) ..\lib\unicore\mktables Extensions_nonxs
	$(MINIPERL) -I..\lib ..\lib\unicore\mktables -C ..\lib\unicore -P ..\pod -maketest -makelist -p
MAKEFILE
    my @v = split /[.]/, $version;
    $makefile =~ s/__PERL_MINOR_VERSION__/$v[0]$v[1]/g;
    $makefile =~ s/__PERL_VERSION__/$v[0]$v[1]$v[2]/g;
    _write_or_die(File::Spec->catfile("win32", "GNUMakefile"), $makefile);
}

sub _patch_win32_mkstemp {
    _patch(<<'PATCH');
--- win32/win32.h
+++ win32/win32.h
@@ -331,8 +352,10 @@
 #endif
 extern	char *	getlogin(void);
 extern	int	chown(const char *p, uid_t o, gid_t g);
+#if !defined(__MINGW64_VERSION_MAJOR) || __MINGW64_VERSION_MAJOR < 4
 extern  int	mkstemp(const char *path);
 #endif
+#endif
 
 #undef	 Stat
 #define  Stat		win32_stat
--- win32/win32.c
+++ win32/win32.c
@@ -1122,6 +1124,7 @@
  * XXX this needs strengthening  (for PerlIO)
  *   -- BKS, 11-11-200
 */
+#if !defined(__MINGW64_VERSION_MAJOR) || __MINGW64_VERSION_MAJOR < 4
 int mkstemp(const char *path)
 {
     dTHX;
@@ -1142,6 +1145,7 @@
 	goto retry;
     return fd;
 }
+#endif
 
 static long
 find_pid(pTHX_ int pid)
--- win32/config_H.gc
+++ win32/config_H.gc
@@ -1973,7 +1970,9 @@
  *	available to exclusively create and open a uniquely named
  *	temporary file.
  */
-/*#define HAS_MKSTEMP		/ **/
+#if __MINGW64_VERSION_MAJOR >= 4
+#define HAS_MKSTEMP
+#endif
 
 /* HAS_MMAP:
  *	This symbol, if defined, indicates that the mmap system call is
PATCH
}

sub _patch_make_maker_dirfilesep {
    _patch(<<'PATCH');
--- installperl
+++ installperl
@@ -260,7 +259,7 @@ if (($Is_W32 and ! $Is_NetWare) or $Is_Cygwin) {
     if ($Is_Cygwin) {
 	$perldll = $libperl;
     } else {
-	$perldll = 'perl5'.$Config{patchlevel}.'.'.$dlext;
+	$perldll = 'perl5'.$Config{patchlevel}.'.'.$so;
     }
 
     if ($dlsrc ne "dl_none.xs") {
--- make_ext.pl
+++ make_ext.pl
@@ -2,11 +2,11 @@
 use strict;
 use warnings;
 use Config;
-use constant IS_CROSS => defined $Config::Config{usecrosscompile} ? 1 : 0;
-
-my $is_Win32 = $^O eq 'MSWin32';
-my $is_VMS = $^O eq 'VMS';
-my $is_Unix = !$is_Win32 && !$is_VMS;
+use constant{IS_CROSS => defined $Config::Config{usecrosscompile} ? 1 : 0,
+             IS_WIN32 => $^O eq 'MSWin32',
+             IS_VMS   => $^O eq 'VMS',
+             IS_UNIX  => $^O ne 'MSWin32' && $^O ne 'VMS',
+};
 
 my @ext_dirs = qw(cpan dist ext);
 my $ext_dirs_re = '(?:' . join('|', @ext_dirs) . ')';
@@ -51,13 +51,15 @@ my $ext_dirs_re = '(?:' . join('|', @ext_dirs) . ')';
 # It may be deleted in a later release of perl so try to
 # avoid using it for other purposes.
 
-my (%excl, %incl, %opts, @extspec, @pass_through);
+my (%excl, %incl, %opts, @extspec, @pass_through, $verbose);
 
 foreach (@ARGV) {
     if (/^!(.*)$/) {
 	$excl{$1} = 1;
     } elsif (/^\+(.*)$/) {
 	$incl{$1} = 1;
+    } elsif (/^--verbose$/ or /^-v$/) {
+	$verbose = 1;
     } elsif (/^--([\w\-]+)$/) {
 	$opts{$1} = 1;
     } elsif (/^--([\w\-]+)=(.*)$/) {
@@ -137,7 +139,7 @@ if (!@extspec and !$static and !$dynamic and !$nonxs and !$dynaloader)  {
 my $perl;
 my %extra_passthrough;
 
-if ($is_Win32) {
+if (IS_WIN32) {
     require Cwd;
     require FindExt;
     my $build = Cwd::getcwd();
@@ -153,11 +155,11 @@ if ($is_Win32) {
     my $pl2bat = "$topdir\\win32\\bin\\pl2bat";
     unless (-f "$pl2bat.bat") {
 	my @args = ($perl, "-I$topdir\\lib", ("$pl2bat.pl") x 2);
-	print "@args\n";
+	print "@args\n" if $verbose;
 	system(@args) unless IS_CROSS;
     }
 
-    print "In $build";
+    print "In $build" if $verbose;
     foreach my $dir (@dirs) {
 	chdir($dir) or die "Cannot cd to $dir: $!\n";
 	(my $ext = Cwd::getcwd()) =~ s{/}{\\}g;
@@ -183,10 +185,7 @@ if ($is_Win32) {
 	    next;
 	}
 	push @extspec, $_;
-	if($_ eq 'DynaLoader' and $target !~ /clean$/) {
-	    # No, we don't know why nmake can't work out the dependency chain
-	    push @{$extra_passthrough{$_}}, 'DynaLoader.c';
-	} elsif(FindExt::is_static($_)) {
+	if($_ ne 'DynaLoader' && FindExt::is_static($_)) {
 	    push @{$extra_passthrough{$_}}, 'LINKTYPE=static';
 	}
     }
@@ -194,7 +193,7 @@ if ($is_Win32) {
     chdir '..'
 	or die "Couldn't chdir to build directory: $!"; # now in the Perl build
 }
-elsif ($is_VMS) {
+elsif (IS_VMS) {
     $perl = $^X;
     push @extspec, (split ' ', $Config{static_ext}) if $static;
     push @extspec, (split ' ', $Config{dynamic_ext}) if $dynamic;
@@ -252,7 +251,7 @@ foreach my $spec (@extspec)  {
 	}
     }
 
-    print "\tMaking $mname ($target)\n";
+    print "\tMaking $mname ($target)\n" if $verbose;
 
     build_extension($ext_pathname, $perl, $mname, $target,
 		    [@pass_through, @{$extra_passthrough{$spec} || []}]);
@@ -274,8 +273,8 @@ sub build_extension {
     my $lib_dir = "$up/lib";
     $ENV{PERL_CORE} = 1;
 
-    my $makefile;
-    if ($is_VMS) {
+    my ($makefile, $makefile_no_minus_f);
+    if (IS_VMS) {
 	$makefile = 'descrip.mms';
 	if ($target =~ /clean$/
 	    && !-f $makefile
@@ -287,6 +286,7 @@ sub build_extension {
     }
     
     if (-f $makefile) {
+	$makefile_no_minus_f = 0;
 	open my $mfh, $makefile or die "Cannot open $makefile: $!";
 	while (<$mfh>) {
 	    # Plagiarised from CPAN::Distribution
@@ -337,9 +337,11 @@ sub build_extension {
                 _unlink($makefile);
             }
         }
+    } else {
+	$makefile_no_minus_f = 1;
     }
 
-    if (!-f $makefile) {
+    if ($makefile_no_minus_f || !-f $makefile) {
 	NO_MAKEFILE:
 	if (!-f 'Makefile.PL') {
             unless (just_pm_to_blib($target, $ext_dir, $mname, $return_dir)) {
@@ -348,7 +350,7 @@ sub build_extension {
                 return;
             }
 
-	    print "\nCreating Makefile.PL in $ext_dir for $mname\n";
+	    print "\nCreating Makefile.PL in $ext_dir for $mname\n" if $verbose;
 	    my ($fromname, $key, $value);
 	    if ($mname eq 'podlators') {
 		# We need to special case this somewhere, and this is fewer
@@ -375,11 +376,22 @@ sub build_extension {
 		}
 
 		unless ($fromname) {
-		    die "For $mname tried @locations in in $ext_dir but can't find source";
+		    die "For $mname tried @locations in $ext_dir but can't find source";
 		}
 		($value = $fromname) =~ s/\.pm\z/.pod/;
 		$value = $fromname unless -e $value;
 	    }
+
+            if ($mname eq 'Pod::Checker') {
+                # the abstract in the .pm file is unparseable by MM,
+                # so special-case it. We can't use the package's own
+                # Makefile.PL, as it doesn't handle the executable scripts
+                # right.
+                $key = 'ABSTRACT';
+                # this is copied from the CPAN Makefile.PL v 1.171
+                $value = 'Pod::Checker verifies POD documentation contents for compliance with the POD format specifications';
+            }
+
 	    open my $fh, '>', 'Makefile.PL'
 		or die "Can't open Makefile.PL for writing: $!";
 	    printf $fh <<'EOM', $0, $mname, $fromname, $key, $value;
@@ -443,8 +455,8 @@ EOM
 	    # the Makefile.PL. Altering the atime and mtime backwards by 4
 	    # seconds seems to resolve the issue.
 	    eval {
-		my $ftime = time - 4;
-		utime $ftime, $ftime, 'Makefile.PL';
+        my $ftime = (stat('Makefile.PL'))[9] - 4;
+        utime $ftime, $ftime, 'Makefile.PL';
 	    };
         } elsif ($mname =~ /\A(?:Carp
                             |ExtUtils::CBuilder
@@ -491,10 +503,10 @@ EOM
 	}
 
         # We are going to have to use Makefile.PL:
-	print "\nRunning Makefile.PL in $ext_dir\n";
+	print "\nRunning Makefile.PL in $ext_dir\n" if $verbose;
 
 	my @args = ("-I$lib_dir", 'Makefile.PL');
-	if ($is_VMS) {
+	if (IS_VMS) {
 	    my $libd = VMS::Filespec::vmspath($lib_dir);
 	    push @args, "INST_LIB=$libd", "INST_ARCHLIB=$libd";
 	} else {
@@ -502,9 +514,12 @@ EOM
 		'INSTALLMAN3DIR=none';
 	}
 	push @args, @$pass_through;
-	_quote_args(\@args) if $is_VMS;
-	print join(' ', $perl, @args), "\n";
-	my $code = system $perl, @args;
+	_quote_args(\@args) if IS_VMS;
+	print join(' ', $perl, @args), "\n" if $verbose;
+	my $code = do {
+	   local $ENV{PERL_MM_USE_DEFAULT} = 1;
+	    system $perl, @args;
+	};
 	warn "$code from $ext_dir\'s Makefile.PL" if $code;
 
 	# Right. The reason for this little hack is that we're sitting inside
@@ -518,7 +533,7 @@ EOM
 	# some of them rely on a $(PERL) for their own distclean targets.
 	# But this always used to be a problem with the old /bin/sh version of
 	# this.
-	if ($is_Unix) {
+	if (IS_UNIX) {
 	    foreach my $clean_target ('realclean', 'veryclean') {
                 fallback_cleanup($return_dir, $clean_target, <<"EOS");
 cd $ext_dir
@@ -529,7 +544,7 @@ else
     if test ! -f Makefile ; then
 	echo "Warning: No Makefile!"
     fi
-    make $clean_target MAKE='@make' @pass_through
+    @make $clean_target MAKE='@make' @pass_through
 fi
 cd $return_dir
 EOS
@@ -541,7 +556,7 @@ EOS
 	print "Warning: No Makefile!\n";
     }
 
-    if ($is_VMS) {
+    if (IS_VMS) {
 	_quote_args($pass_through);
 	@$pass_through = (
 			  "/DESCRIPTION=$makefile",
@@ -549,15 +564,13 @@ EOS
 			 );
     }
 
-    if (!$target or $target !~ /clean$/) {
-	# Give makefile an opportunity to rewrite itself.
-	# reassure users that life goes on...
-	my @args = ('config', @$pass_through);
-	system(@make, @args) and print "@make @args failed, continuing anyway...\n";
-    }
     my @targ = ($target, @$pass_through);
-    print "Making $target in $ext_dir\n@make @targ\n";
+    print "Making $target in $ext_dir\n@make @targ\n" if $verbose;
+    local $ENV{PERL_INSTALL_QUIET} = 1;
     my $code = system(@make, @targ);
+    if($code >> 8 != 0){ # probably cleaned itself, try again once more time
+        $code = system(@make, @targ);
+    }
     die "Unsuccessful make($ext_dir): code=$code" if $code != 0;
 
     chdir $return_dir || die "Cannot cd to $return_dir: $!";
@@ -598,12 +611,12 @@ sub just_pm_to_blib {
     my ($last) = $mname =~ /([^:]+)$/;
     my ($first) = $mname =~ /^([^:]+)/;
 
-    my $pm_to_blib = $is_VMS ? 'pm_to_blib.ts' : 'pm_to_blib';
+    my $pm_to_blib = IS_VMS ? 'pm_to_blib.ts' : 'pm_to_blib';
 
     foreach my $leaf (<*>) {
         if (-d $leaf) {
             $leaf =~ s/\.DIR\z//i
-                if $is_VMS;
+                if IS_VMS;
             next if $leaf =~ /\A(?:\.|\.\.|t|demo)\z/;
             if ($leaf eq 'lib') {
                 ++$has_lib;
@@ -617,7 +630,7 @@ sub just_pm_to_blib {
         return $leaf
             unless -f _;
         $leaf =~ s/\.\z//
-            if $is_VMS;
+            if IS_VMS;
         # Makefile.PL is "safe" to ignore because we will only be called for
         # directories that hold a Makefile.PL if they are in the exception list.
         next
@@ -689,6 +702,7 @@ sub just_pm_to_blib {
     }
     # This is running under miniperl, so no autodie
     if ($target eq 'all') {
+        local $ENV{PERL_INSTALL_QUIET} = 1;
         require ExtUtils::Install;
         ExtUtils::Install::pm_to_blib(\%pm, '../../lib/auto');
         open my $fh, '>', $pm_to_blib
@@ -696,7 +710,7 @@ sub just_pm_to_blib {
         print $fh "$0 has handled pm_to_blib directly\n";
         close $fh
             or die "Can't close '$pm_to_blib': $!";
-	if ($is_Unix) {
+	if (IS_UNIX) {
             # Fake the fallback cleanup
             my $fallback
                 = join '', map {s!^\.\./\.\./!!; "rm -f $_\n"} sort values %pm;
@@ -715,7 +729,7 @@ sub just_pm_to_blib {
             # (which it has to deal with, as cpan/foo/bar creates
             # lib/auto/foo/bar, but the EU::MM rule will only
             # rmdir lib/auto/foo/bar, leaving lib/auto/foo
-            _unlink("../../$_")
+            _unlink($_)
                 foreach sort values %pm;
         }
     }
--- cpan/ExtUtils-MakeMaker/lib/ExtUtils/Command/MM.pm
+++ cpan/ExtUtils-MakeMaker/lib/ExtUtils/Command/MM.pm
@@ -10,7 +10,7 @@ our @ISA = qw(Exporter);
 
 our @EXPORT  = qw(test_harness pod2man perllocal_install uninstall
                   warn_if_old_packlist test_s cp_nonempty);
-our $VERSION = '6.98';
+our $VERSION = '7.04_01';
 
 my $Is_VMS = $^O eq 'VMS';
 
@@ -116,8 +116,9 @@ sub pod2man {
                 'section|s=s', 'release|r=s', 'center|c=s',
                 'date|d=s', 'fixed=s', 'fixedbold=s', 'fixeditalic=s',
                 'fixedbolditalic=s', 'official|o', 'quotes|q=s', 'lax|l',
-                'name|n=s', 'perm_rw=i'
+                'name|n=s', 'perm_rw=i', 'utf8|u'
     );
+    delete $options{utf8} unless $Pod::Man::VERSION >= 2.17;
 
     # If there's no files, don't bother going further.
     return 0 unless @ARGV;
@@ -130,6 +131,9 @@ sub pod2man {
     # This isn't a valid Pod::Man option and is only accepted for backwards
     # compatibility.
     delete $options{lax};
+    my $count = scalar @ARGV / 2;
+    my $plural = $count == 1 ? 'document' : 'documents';
+    print "Manifying $count pod $plural\n";
 
     do {{  # so 'next' works
         my ($pod, $man) = splice(@ARGV, 0, 2);
@@ -138,8 +142,6 @@ sub pod2man {
                  (mtime($man) > mtime($pod)) &&
                  (mtime($man) > mtime("Makefile")));
 
-        print "Manifying $man\n";
-
         my $parser = Pod::Man->new(%options);
         $parser->parse_from_file($pod, $man)
           or do { warn("Could not install $man\n");  next };
--- cpan/ExtUtils-MakeMaker/lib/ExtUtils/Liblist.pm
+++ cpan/ExtUtils-MakeMaker/lib/ExtUtils/Liblist.pm
@@ -2,7 +2,7 @@ package ExtUtils::Liblist;
 
 use strict;
 
-our $VERSION = '6.98';
+our $VERSION = '7.04_01';
 
 use File::Spec;
 require ExtUtils::Liblist::Kid;
--- cpan/ExtUtils-MakeMaker/lib/ExtUtils/Liblist/Kid.pm
+++ cpan/ExtUtils-MakeMaker/lib/ExtUtils/Liblist/Kid.pm
@@ -11,7 +11,7 @@ use 5.006;
 
 use strict;
 use warnings;
-our $VERSION = '6.98';
+our $VERSION = '7.04_01';
 
 use ExtUtils::MakeMaker::Config;
 use Cwd 'cwd';
@@ -49,7 +49,7 @@ sub _unix_os2_ext {
     # this is a rewrite of Andy Dougherty's extliblist in perl
 
     my ( @searchpath );    # from "-L/path" entries in $potential_libs
-    my ( @libpath ) = split " ", $Config{'libpth'};
+    my ( @libpath ) = split " ", $Config{'libpth'} || '';
     my ( @ldloadlibs, @bsloadlibs, @extralibs, @ld_run_path, %ld_run_path_seen );
     my ( @libs,       %libs_seen );
     my ( $fullname,   @fullname );
@@ -57,6 +57,7 @@ sub _unix_os2_ext {
     my ( $found ) = 0;
 
     foreach my $thislib ( split ' ', $potential_libs ) {
+        my ( $custom_name ) = '';
 
         # Handle possible linker path arguments.
         if ( $thislib =~ s/^(-[LR]|-Wl,-R|-Wl,-rpath,)// ) {    # save path flag type
@@ -92,7 +93,14 @@ sub _unix_os2_ext {
         }
 
         # Handle possible library arguments.
-        unless ( $thislib =~ s/^-l// ) {
+        if ( $thislib =~ s/^-l(:)?// ) {
+            # Handle -l:foo.so, which means that the library will
+            # actually be called foo.so, not libfoo.so.  This
+            # is used in Android by ExtUtils::Depends to allow one XS
+            # module to link to another.
+            $custom_name = $1 || '';
+        }
+        else {
             warn "Unrecognized argument in LIBS ignored: '$thislib'\n";
             next;
         }
@@ -106,8 +114,10 @@ sub _unix_os2_ext {
             # For gcc-2.6.2 on linux (March 1995), DLD can not load
             # .sa libraries, with the exception of libm.sa, so we
             # deliberately skip them.
-            if ( @fullname = $self->lsdir( $thispth, "^\Qlib$thislib.$so.\E[0-9]+" ) ) {
-
+            if ((@fullname =
+                 $self->lsdir($thispth, "^\Qlib$thislib.$so.\E[0-9]+")) ||
+                (@fullname =
+                 $self->lsdir($thispth, "^\Qlib$thislib.\E[0-9]+\Q\.$so"))) {
                 # Take care that libfoo.so.10 wins against libfoo.so.9.
                 # Compare two libraries to find the most recent version
                 # number.  E.g.  if you have libfoo.so.9.0.7 and
@@ -176,6 +186,8 @@ sub _unix_os2_ext {
                 #
                 # , the compilation tools expand the environment variables.)
             }
+            elsif ( $custom_name && -f ( $fullname = "$thispth/$thislib" ) ) {
+            }
             else {
                 warn "$thislib not found in $thispth\n" if $verbose;
                 next;
@@ -189,7 +201,7 @@ sub _unix_os2_ext {
 
             # what do we know about this library...
             my $is_dyna = ( $fullname !~ /\Q$Config_libext\E\z/ );
-            my $in_perl = ( $libs =~ /\B-l\Q${thislib}\E\b/s );
+            my $in_perl = ( $libs =~ /\B-l:?\Q${thislib}\E\b/s );
 
             # include the path to the lib once in the dynamic linker path
             # but only if it is a dynamic lib and not in Perl itself
@@ -209,7 +221,7 @@ sub _unix_os2_ext {
                     && ( $thislib eq 'm' || $thislib eq 'ndbm' ) )
               )
             {
-                push( @extralibs, "-l$thislib" );
+                push( @extralibs, "-l$custom_name$thislib" );
             }
 
             # We might be able to load this archive file dynamically
@@ -231,11 +243,11 @@ sub _unix_os2_ext {
 
                     # For SunOS4, do not add in this shared library if
                     # it is already linked in the main perl executable
-                    push( @ldloadlibs, "-l$thislib" )
+                    push( @ldloadlibs, "-l$custom_name$thislib" )
                       unless ( $in_perl and $^O eq 'sunos' );
                 }
                 else {
-                    push( @ldloadlibs, "-l$thislib" );
+                    push( @ldloadlibs, "-l$custom_name$thislib" );
                 }
             }
             last;    # found one here so don't bother looking further
@@ -330,8 +342,8 @@ sub _win32_ext {
     return ( '', '', '', '', ( $give_libs ? \@libs : () ) ) unless @extralibs;
 
     # make sure paths with spaces are properly quoted
-    @extralibs = map { /\s/ ? qq["$_"] : $_ } @extralibs;
-    @libs      = map { /\s/ ? qq["$_"] : $_ } @libs;
+    @extralibs = map { qq["$_"] } @extralibs;
+    @libs      = map { qq["$_"] } @libs;
 
     my $lib = join( ' ', @extralibs );
 
@@ -499,7 +511,6 @@ sub _vms_ext {
         'Xm'     => 'DECW$XMLIBSHR',
         'Xmu'    => 'DECW$XMULIBSHR'
     );
-    if ( $Config{'vms_cc_type'} ne 'decc' ) { $libmap{'curses'} = 'VAXCCURSE'; }
 
     warn "Potential libraries are '$potential_libs'\n" if $verbose;
 
@@ -525,7 +536,7 @@ sub _vms_ext {
         }
         warn "Resolving directory $dir\n" if $verbose;
         if ( File::Spec->file_name_is_absolute( $dir ) ) {
-            $dir = $self->fixpath( $dir, 1 );
+            $dir = VMS::Filespec::vmspath( $dir );
         }
         else {
             $dir = $self->catdir( $cwd, $dir );
@@ -609,9 +620,7 @@ sub _vms_ext {
             }
             if ( $ctype ) {
 
-                # This has to precede any other CRTLs, so just make it first
-                if ( $cand eq 'VAXCCURSE' ) { unshift @{ $found{$ctype} }, $cand; }
-                else                        { push @{ $found{$ctype} }, $cand; }
+                push @{ $found{$ctype} }, $cand;
                 warn "\tFound as $cand (really $fullname), type $ctype\n"
                   if $verbose > 1;
                 push @flibs, $name unless $libs_seen{$fullname}++;
@@ -627,6 +636,7 @@ sub _vms_ext {
     my $lib = join( ' ', @fndlibs );
 
     $ldlib = $crtlstr ? "$lib $crtlstr" : $lib;
+    $ldlib =~ s/^\s+|\s+$//g;
     warn "Result:\n\tEXTRALIBS: $lib\n\tLDLOADLIBS: $ldlib\n" if $verbose;
     wantarray ? ( $lib, '', $ldlib, '', ( $give_libs ? \@flibs : () ) ) : $lib;
 }
--- cpan/ExtUtils-MakeMaker/lib/ExtUtils/MM.pm
+++ cpan/ExtUtils-MakeMaker/lib/ExtUtils/MM.pm
@@ -3,7 +3,7 @@ package ExtUtils::MM;
 use strict;
 use ExtUtils::MakeMaker::Config;
 
-our $VERSION = '6.98';
+our $VERSION = '7.04_01';
 
 require ExtUtils::Liblist;
 require ExtUtils::MakeMaker;
--- cpan/ExtUtils-MakeMaker/lib/ExtUtils/MM_AIX.pm
+++ cpan/ExtUtils-MakeMaker/lib/ExtUtils/MM_AIX.pm
@@ -1,7 +1,7 @@
 package ExtUtils::MM_AIX;
 
 use strict;
-our $VERSION = '6.98';
+our $VERSION = '7.04_01';
 
 require ExtUtils::MM_Unix;
 our @ISA = qw(ExtUtils::MM_Unix);
--- cpan/ExtUtils-MakeMaker/lib/ExtUtils/MM_Any.pm
+++ cpan/ExtUtils-MakeMaker/lib/ExtUtils/MM_Any.pm
@@ -1,7 +1,7 @@
 package ExtUtils::MM_Any;
 
 use strict;
-our $VERSION = '6.98';
+our $VERSION = '7.04_01';
 
 use Carp;
 use File::Spec;
@@ -125,6 +125,143 @@ sub can_load_xs {
 }
 
 
+=head3 can_run
+
+  use ExtUtils::MM;
+  my $runnable = MM->can_run($Config{make});
+
+If called in a scalar context it will return the full path to the binary
+you asked for if it was found, or C<undef> if it was not.
+
+If called in a list context, it will return a list of the full paths to instances
+of the binary where found in C<PATH>, or an empty list if it was not found.
+
+Copied from L<IPC::Cmd|IPC::Cmd/"$path = can_run( PROGRAM );">, but modified into
+a method (and removed C<$INSTANCES> capability).
+
+=cut
+
+sub can_run {
+    my ($self, $command) = @_;
+
+    # a lot of VMS executables have a symbol defined
+    # check those first
+    if ( $^O eq 'VMS' ) {
+        require VMS::DCLsym;
+        my $syms = VMS::DCLsym->new;
+        return $command if scalar $syms->getsym( uc $command );
+    }
+
+    my @possibles;
+
+    if( File::Spec->file_name_is_absolute($command) ) {
+        return $self->maybe_command($command);
+
+    } else {
+        for my $dir (
+            File::Spec->path,
+            File::Spec->curdir
+        ) {
+            next if ! $dir || ! -d $dir;
+            my $abs = File::Spec->catfile($self->os_flavor_is('Win32') ? Win32::GetShortPathName( $dir ) : $dir, $command);
+            push @possibles, $abs if $abs = $self->maybe_command($abs);
+        }
+    }
+    return @possibles if wantarray;
+    return shift @possibles;
+}
+
+
+=head3 can_redirect_error
+
+  $useredirect = MM->can_redirect_error;
+
+True if on an OS where qx operator (or backticks) can redirect C<STDERR>
+onto C<STDOUT>.
+
+=cut
+
+sub can_redirect_error {
+  my $self = shift;
+  $self->os_flavor_is('Unix')
+      or ($self->os_flavor_is('Win32') and !$self->os_flavor_is('Win9x'))
+      or $self->os_flavor_is('OS/2')
+}
+
+
+=head3 is_make_type
+
+    my $is_dmake = $self->is_make_type('dmake');
+
+Returns true if C<<$self->make>> is the given type; possibilities are:
+
+  gmake    GNU make
+  dmake
+  nmake
+  bsdmake  BSD pmake-derived
+
+=cut
+
+sub is_make_type {
+    my($self, $type) = @_;
+    (undef, undef, my $make_basename) = $self->splitpath($self->make);
+    return 1 if $make_basename =~ /\b$type\b/i; # executable's filename
+    return 0 if $make_basename =~ /\b(dmake|nmake)\b/i; # Never fall through for dmake/nmake
+    # now have to run with "-v" and guess
+    my $redirect = $self->can_redirect_error ? '2>&1' : '';
+    my $make = $self->make || $self->{MAKE};
+    my $minus_v = `"$make" -v $redirect`;
+    return 1 if $type eq 'gmake' and $minus_v =~ /GNU make/i;
+    return 1 if $type eq 'bsdmake'
+      and $minus_v =~ /^usage: make \[-BeikNnqrstWwX\]/im;
+    0; # it wasn't whatever you asked
+}
+
+
+=head3 can_dep_space
+
+    my $can_dep_space = $self->can_dep_space;
+
+Returns true if C<make> can handle (probably by quoting)
+dependencies that contain a space. Currently known true for GNU make,
+false for BSD pmake derivative.
+
+=cut
+
+my $cached_dep_space;
+sub can_dep_space {
+    my $self = shift;
+    return $cached_dep_space if defined $cached_dep_space;
+    return $cached_dep_space = 1 if $self->is_make_type('gmake');
+    return $cached_dep_space = 0 if $self->is_make_type('dmake'); # only on W32
+    return $cached_dep_space = 0 if $self->is_make_type('bsdmake');
+    return $cached_dep_space = 0; # assume no
+}
+
+
+=head3 quote_dep
+
+  $text = $mm->quote_dep($text);
+
+Method that protects Makefile single-value constants (mainly filenames),
+so that make will still treat them as single values even if they
+inconveniently have spaces in. If the make program being used cannot
+achieve such protection and the given text would need it, throws an
+exception.
+
+=cut
+
+sub quote_dep {
+    my ($self, $arg) = @_;
+    die <<EOF if $arg =~ / / and not $self->can_dep_space;
+Tried to use make dependency with space for make that can't:
+  '$arg'
+EOF
+    $arg =~ s/( )/\\$1/g; # how GNU make does it
+    return $arg;
+}
+
+
 =head3 split_command
 
     my @cmds = $MM->split_command($cmd, @args);
@@ -781,9 +918,10 @@ END
     my @man_cmds;
     foreach my $section (qw(1 3)) {
         my $pods = $self->{"MAN${section}PODS"};
-        push @man_cmds, $self->split_command(<<CMD, map {($_,$pods->{$_})} sort keys %$pods);
-	\$(NOECHO) \$(POD2MAN) --section=$section --perm_rw=\$(PERM_RW)
+        my $p2m = sprintf <<CMD, $] > 5.008 ? " -u" : "";
+	\$(NOECHO) \$(POD2MAN) --section=$section --perm_rw=\$(PERM_RW)%s
 CMD
+        push @man_cmds, $self->split_command($p2m, map {($_,$pods->{$_})} sort keys %$pods);
     }
 
     $manify .= "\t\$(NOECHO) \$(NOOP)\n" unless @man_cmds;
@@ -1037,8 +1175,7 @@ sub _add_requirements_to_meta_v1_4 {
     # Check the original args so we can tell between the user setting it
     # to an empty hash and it just being initialized.
     if( $self->{ARGS}{CONFIGURE_REQUIRES} ) {
-        $meta{configure_requires}
-            = _normalize_prereqs($self->{CONFIGURE_REQUIRES});
+        $meta{configure_requires} = $self->{CONFIGURE_REQUIRES};
     } else {
         $meta{configure_requires} = {
             'ExtUtils::MakeMaker'       => 0,
@@ -1046,7 +1183,7 @@ sub _add_requirements_to_meta_v1_4 {
     }
 
     if( $self->{ARGS}{BUILD_REQUIRES} ) {
-        $meta{build_requires} = _normalize_prereqs($self->{BUILD_REQUIRES});
+        $meta{build_requires} = $self->{BUILD_REQUIRES};
     } else {
         $meta{build_requires} = {
             'ExtUtils::MakeMaker'       => 0,
@@ -1056,11 +1193,11 @@ sub _add_requirements_to_meta_v1_4 {
     if( $self->{ARGS}{TEST_REQUIRES} ) {
         $meta{build_requires} = {
           %{ $meta{build_requires} },
-          %{ _normalize_prereqs($self->{TEST_REQUIRES}) },
+          %{ $self->{TEST_REQUIRES} },
         };
     }
 
-    $meta{requires} = _normalize_prereqs($self->{PREREQ_PM})
+    $meta{requires} = $self->{PREREQ_PM}
         if defined $self->{PREREQ_PM};
     $meta{requires}{perl} = _normalize_version($self->{MIN_PERL_VERSION})
         if $self->{MIN_PERL_VERSION};
@@ -1074,8 +1211,7 @@ sub _add_requirements_to_meta_v2 {
     # Check the original args so we can tell between the user setting it
     # to an empty hash and it just being initialized.
     if( $self->{ARGS}{CONFIGURE_REQUIRES} ) {
-        $meta{prereqs}{configure}{requires}
-            = _normalize_prereqs($self->{CONFIGURE_REQUIRES});
+        $meta{prereqs}{configure}{requires} = $self->{CONFIGURE_REQUIRES};
     } else {
         $meta{prereqs}{configure}{requires} = {
             'ExtUtils::MakeMaker'       => 0,
@@ -1083,7 +1219,7 @@ sub _add_requirements_to_meta_v2 {
     }
 
     if( $self->{ARGS}{BUILD_REQUIRES} ) {
-        $meta{prereqs}{build}{requires} = _normalize_prereqs($self->{BUILD_REQUIRES});
+        $meta{prereqs}{build}{requires} = $self->{BUILD_REQUIRES};
     } else {
         $meta{prereqs}{build}{requires} = {
             'ExtUtils::MakeMaker'       => 0,
@@ -1091,10 +1227,10 @@ sub _add_requirements_to_meta_v2 {
     }
 
     if( $self->{ARGS}{TEST_REQUIRES} ) {
-        $meta{prereqs}{test}{requires} = _normalize_prereqs($self->{TEST_REQUIRES});
+        $meta{prereqs}{test}{requires} = $self->{TEST_REQUIRES};
     }
 
-    $meta{prereqs}{runtime}{requires} = _normalize_prereqs($self->{PREREQ_PM})
+    $meta{prereqs}{runtime}{requires} = $self->{PREREQ_PM}
         if $self->{ARGS}{PREREQ_PM};
     $meta{prereqs}{runtime}{requires}{perl} = _normalize_version($self->{MIN_PERL_VERSION})
         if $self->{MIN_PERL_VERSION};
@@ -1102,15 +1238,6 @@ sub _add_requirements_to_meta_v2 {
     return %meta;
 }
 
-sub _normalize_prereqs {
-  my ($hash) = @_;
-  my %prereqs;
-  while ( my ($k,$v) = each %$hash ) {
-    $prereqs{$k} = _normalize_version($v);
-  }
-  return \%prereqs;
-}
-
 # Adapted from Module::Build::Base
 sub _normalize_version {
   my ($version) = @_;
@@ -1993,7 +2120,7 @@ sub init_VERSION {
     if (defined $self->{VERSION}) {
         if ( $self->{VERSION} !~ /^\s*v?[\d_\.]+\s*$/ ) {
           require version;
-          my $normal = eval { version->parse( $self->{VERSION} ) };
+          my $normal = eval { version->new( $self->{VERSION} ) };
           $self->{VERSION} = $normal if defined $normal;
         }
         $self->{VERSION} =~ s/^\s+//;
@@ -2060,7 +2187,7 @@ Defines at least these macros.
 sub init_tools {
     my $self = shift;
 
-    $self->{ECHO}     ||= $self->oneliner('print qq{@ARGV}', ['-l']);
+    $self->{ECHO}     ||= $self->oneliner('binmode STDOUT, qq{:raw}; print qq{@ARGV}', ['-l']);
     $self->{ECHO_N}   ||= $self->oneliner('print qq{@ARGV}');
 
     $self->{TOUCH}    ||= $self->oneliner('touch', ["-MExtUtils::Command"]);
@@ -2722,7 +2849,7 @@ Used by perldepend() in MM_Unix and MM_VMS via _perl_header_files_fragment()
 sub _perl_header_files {
     my $self = shift;
 
-    my $header_dir = $self->{PERL_SRC} || $self->catdir($Config{archlibexp}, 'CORE');
+    my $header_dir = $self->{PERL_SRC} || $ENV{PERL_SRC} || $self->catdir($Config{archlibexp}, 'CORE');
     opendir my $dh, $header_dir
         or die "Failed to opendir '$header_dir' to find header files: $!";
 
@@ -2759,7 +2886,7 @@ sub _perl_header_files_fragment {
     return join("\\\n",
                 "PERL_HDRS = ",
                 map {
-                    sprintf( "        \$(PERL_INC)%s%s            ", $separator, $_ )
+                    sprintf( "        \$(PERL_INCDEP)%s%s            ", $separator, $_ )
                 } $self->_perl_header_files()
            ) . "\n\n"
            . "\$(OBJECT) : \$(PERL_HDRS)\n";
--- cpan/ExtUtils-MakeMaker/lib/ExtUtils/MM_BeOS.pm
+++ cpan/ExtUtils-MakeMaker/lib/ExtUtils/MM_BeOS.pm
@@ -26,7 +26,7 @@ require ExtUtils::MM_Any;
 require ExtUtils::MM_Unix;
 
 our @ISA = qw( ExtUtils::MM_Any ExtUtils::MM_Unix );
-our $VERSION = '6.98';
+our $VERSION = '7.04_01';
 
 
 =item os_flavor
@@ -50,6 +50,7 @@ sub init_linker {
 
     $self->{PERL_ARCHIVE} ||=
       File::Spec->catdir('$(PERL_INC)',$Config{libperl});
+    $self->{PERL_ARCHIVEDEP} ||= '';
     $self->{PERL_ARCHIVE_AFTER} ||= '';
     $self->{EXPORT_LIST}  ||= '';
 }
--- cpan/ExtUtils-MakeMaker/lib/ExtUtils/MM_Cygwin.pm
+++ cpan/ExtUtils-MakeMaker/lib/ExtUtils/MM_Cygwin.pm
@@ -9,7 +9,7 @@ require ExtUtils::MM_Unix;
 require ExtUtils::MM_Win32;
 our @ISA = qw( ExtUtils::MM_Unix );
 
-our $VERSION = '6.98';
+our $VERSION = '7.04_01';
 
 
 =head1 NAME
@@ -94,6 +94,7 @@ sub init_linker {
           '$(PERL_INC)' .'/'. ("$Config{libperl}" or "libperl.a");
     }
 
+    $self->{PERL_ARCHIVEDEP} ||= '';
     $self->{PERL_ARCHIVE_AFTER} ||= '';
     $self->{EXPORT_LIST}  ||= '';
 }
--- cpan/ExtUtils-MakeMaker/lib/ExtUtils/MM_DOS.pm
+++ cpan/ExtUtils-MakeMaker/lib/ExtUtils/MM_DOS.pm
@@ -2,7 +2,7 @@ package ExtUtils::MM_DOS;
 
 use strict;
 
-our $VERSION = '6.98';
+our $VERSION = '7.04_01';
 
 require ExtUtils::MM_Any;
 require ExtUtils::MM_Unix;
--- cpan/ExtUtils-MakeMaker/lib/ExtUtils/MM_Darwin.pm
+++ cpan/ExtUtils-MakeMaker/lib/ExtUtils/MM_Darwin.pm
@@ -7,7 +7,7 @@ BEGIN {
     our @ISA = qw( ExtUtils::MM_Unix );
 }
 
-our $VERSION = '6.98';
+our $VERSION = '7.04_01';
 
 
 =head1 NAME
--- cpan/ExtUtils-MakeMaker/lib/ExtUtils/MM_MacOS.pm
+++ cpan/ExtUtils-MakeMaker/lib/ExtUtils/MM_MacOS.pm
@@ -2,13 +2,10 @@ package ExtUtils::MM_MacOS;
 
 use strict;
 
-our $VERSION = '6.98';
+our $VERSION = '7.04_01';
 
 sub new {
-    die <<'UNSUPPORTED';
-MacOS Classic (MacPerl) is no longer supported by MakeMaker.
-Please use Module::Build instead.
-UNSUPPORTED
+    die 'MacOS Classic (MacPerl) is no longer supported by MakeMaker';
 }
 
 =head1 NAME
@@ -28,12 +25,8 @@ Since there's little chance of it being repaired, MacOS Classic is fading
 away, and the code was icky to begin with, the code has been deleted to
 make maintenance easier.
 
-Those interested in writing modules for MacPerl should use Module::Build
-which works better than MakeMaker ever did.
-
 Anyone interested in resurrecting this file should pull the old version
-from the MakeMaker CVS repository and contact makemaker@perl.org, but we
-really encourage you to work on Module::Build instead.
+from the MakeMaker CVS repository and contact makemaker@perl.org.
 
 =cut
 
--- cpan/ExtUtils-MakeMaker/lib/ExtUtils/MM_NW5.pm
+++ cpan/ExtUtils-MakeMaker/lib/ExtUtils/MM_NW5.pm
@@ -22,7 +22,7 @@ use strict;
 use ExtUtils::MakeMaker::Config;
 use File::Basename;
 
-our $VERSION = '6.98';
+our $VERSION = '7.04_01';
 
 require ExtUtils::MM_Win32;
 our @ISA = qw(ExtUtils::MM_Win32);
--- cpan/ExtUtils-MakeMaker/lib/ExtUtils/MM_OS2.pm
+++ cpan/ExtUtils-MakeMaker/lib/ExtUtils/MM_OS2.pm
@@ -5,7 +5,7 @@ use strict;
 use ExtUtils::MakeMaker qw(neatvalue);
 use File::Spec;
 
-our $VERSION = '6.98';
+our $VERSION = '7.04_01';
 
 require ExtUtils::MM_Any;
 require ExtUtils::MM_Unix;
@@ -129,6 +129,7 @@ sub init_linker {
 
     $self->{PERL_ARCHIVE} = "\$(PERL_INC)/libperl\$(LIB_EXT)";
 
+    $self->{PERL_ARCHIVEDEP} ||= '';
     $self->{PERL_ARCHIVE_AFTER} = $OS2::is_aout
       ? ''
       : '$(PERL_INC)/libperl_override$(LIB_EXT)';
--- cpan/ExtUtils-MakeMaker/lib/ExtUtils/MM_QNX.pm
+++ cpan/ExtUtils-MakeMaker/lib/ExtUtils/MM_QNX.pm
@@ -1,7 +1,7 @@
 package ExtUtils::MM_QNX;
 
 use strict;
-our $VERSION = '6.98';
+our $VERSION = '7.04_01';
 
 require ExtUtils::MM_Unix;
 our @ISA = qw(ExtUtils::MM_Unix);
--- cpan/ExtUtils-MakeMaker/lib/ExtUtils/MM_UWIN.pm
+++ cpan/ExtUtils-MakeMaker/lib/ExtUtils/MM_UWIN.pm
@@ -1,7 +1,7 @@
 package ExtUtils::MM_UWIN;
 
 use strict;
-our $VERSION = '6.98';
+our $VERSION = '7.04_01';
 
 require ExtUtils::MM_Unix;
 our @ISA = qw(ExtUtils::MM_Unix);
--- cpan/ExtUtils-MakeMaker/lib/ExtUtils/MM_Unix.pm
+++ cpan/ExtUtils-MakeMaker/lib/ExtUtils/MM_Unix.pm
@@ -15,7 +15,7 @@ use ExtUtils::MakeMaker qw($Verbose neatvalue);
 
 # If we make $VERSION an our variable parse_version() breaks
 use vars qw($VERSION);
-$VERSION = '6.98';
+$VERSION = '7.04_01';
 $VERSION = eval $VERSION;  ## no critic [BuiltinFunctions::ProhibitStringyEval]
 
 require ExtUtils::MM_Any;
@@ -190,6 +190,20 @@ sub cflags {
 
     @cflags{qw(cc ccflags optimize shellflags)}
 	= @Config{qw(cc ccflags optimize shellflags)};
+
+    # Perl 5.21.4 adds the (gcc) warning (-Wall ...) and std (-std=c89)
+    # flags to the %Config, and the modules in the core should be built
+    # with the warning flags, but NOT the -std=c89 flags (the latter
+    # would break using any system header files that are strict C99).
+    my @ccextraflags = qw(ccwarnflags);
+    if ($ENV{PERL_CORE}) {
+      for my $x (@ccextraflags) {
+        if (exists $Config{$x}) {
+          $cflags{$x} = $Config{$x};
+        }
+      }
+    }
+
     my($optdebug) = "";
 
     $cflags{shellflags} ||= '';
@@ -258,6 +272,11 @@ sub cflags {
 	$self->{CCFLAGS} .= ' -DPERL_POLLUTE ';
     }
 
+    for my $x (@ccextraflags) {
+      next unless exists $cflags{$x};
+      $self->{CCFLAGS} .= $cflags{$x} =~ m!^\s! ? $cflags{$x} : ' ' . $cflags{$x};
+    }
+
     my $pollute = '';
     if ($Config{usemymalloc} and not $Config{bincompat5005}
 	and not $Config{ccflags} =~ /-DPERL_POLLUTE_MALLOC\b/
@@ -387,10 +406,10 @@ sub constants {
                         } $self->installvars),
                    qw(
               PERL_LIB
-              PERL_ARCHLIB
+              PERL_ARCHLIB PERL_ARCHLIBDEP
               LIBPERL_A MYEXTLIB
               FIRST_MAKEFILE MAKEFILE_OLD MAKE_APERL_FILE
-              PERLMAINCC PERL_SRC PERL_INC
+              PERLMAINCC PERL_SRC PERL_INC PERL_INCDEP
               PERL            FULLPERL          ABSPERL
               PERLRUN         FULLPERLRUN       ABSPERLRUN
               PERLRUNINST     FULLPERLRUNINST   ABSPERLRUNINST
@@ -404,6 +423,8 @@ sub constants {
         # pathnames can have sharp signs in them; escape them so
         # make doesn't think it is a comment-start character.
         $self->{$macro} =~ s/#/\\#/g;
+	$self->{$macro} = $self->quote_dep($self->{$macro})
+	  if $ExtUtils::MakeMaker::macro_dep{$macro};
 	push @m, "$macro = $self->{$macro}\n";
     }
 
@@ -443,7 +464,7 @@ MAN3PODS = ".$self->wraplist(sort keys %{$self->{MAN3PODS}})."
 
     push @m, q{
 # Where is the Config information that we are using/depend on
-CONFIGDEP = $(PERL_ARCHLIB)$(DFSEP)Config.pm $(PERL_INC)$(DFSEP)config.h
+CONFIGDEP = $(PERL_ARCHLIBDEP)$(DFSEP)Config.pm $(PERL_INCDEP)$(DFSEP)config.h
 } if -e File::Spec->catfile( $self->{PERL_INC}, 'config.h' );
 
 
@@ -460,11 +481,11 @@ INST_DYNAMIC     = $self->{INST_DYNAMIC}
 INST_BOOT        = $self->{INST_BOOT}
 };
 
-
     push @m, qq{
 # Extra linker info
 EXPORT_LIST        = $self->{EXPORT_LIST}
 PERL_ARCHIVE       = $self->{PERL_ARCHIVE}
+PERL_ARCHIVEDEP    = $self->{PERL_ARCHIVEDEP}
 PERL_ARCHIVE_AFTER = $self->{PERL_ARCHIVE_AFTER}
 };
 
@@ -878,8 +899,8 @@ $(BOOTSTRAP) : $(FIRST_MAKEFILE) $(BOOTDEP) $(INST_ARCHAUTODIR)$(DFSEP).exists
 	$(NOECHO) $(PERLRUN) \
 		"-MExtUtils::Mkbootstrap" \
 		-e "Mkbootstrap('$(BASEEXT)','$(BSLOADLIBS)');"
-	$(NOECHO) $(TOUCH) %s
-	$(CHMOD) $(PERM_RW) %s
+	$(NOECHO) $(TOUCH) "%s"
+	$(CHMOD) $(PERM_RW) "%s"
 MAKE_FRAG
 }
 
@@ -911,7 +932,7 @@ OTHERLDFLAGS = '.$ld_opt.$otherldflags.'
 INST_DYNAMIC_DEP = '.$inst_dynamic_dep.'
 INST_DYNAMIC_FIX = '.$ld_fix.'
 
-$(INST_DYNAMIC): $(OBJECT) $(MYEXTLIB) $(INST_ARCHAUTODIR)$(DFSEP).exists $(EXPORT_LIST) $(PERL_ARCHIVE) $(PERL_ARCHIVE_AFTER) $(INST_DYNAMIC_DEP)
+$(INST_DYNAMIC): $(OBJECT) $(MYEXTLIB) $(INST_ARCHAUTODIR)$(DFSEP).exists $(EXPORT_LIST) $(PERL_ARCHIVEDEP) $(PERL_ARCHIVE_AFTER) $(INST_DYNAMIC_DEP)
 ');
     if ($armaybe ne ':'){
 	$ldfrom = 'tmp$(LIB_EXT)';
@@ -940,13 +961,13 @@ $(INST_DYNAMIC): $(OBJECT) $(MYEXTLIB) $(INST_ARCHAUTODIR)$(DFSEP).exists $(EXPO
 	# platforms.  We peek at lddlflags to see if we need -Wl,-R
 	# or -R to add paths to the run-time library search path.
         if ($Config{'lddlflags'} =~ /-Wl,-R/) {
-            $libs .= ' -L$(PERL_INC) -Wl,-R$(INSTALLARCHLIB)/CORE -Wl,-R$(PERL_ARCHLIB)/CORE -lperl';
+            $libs .= ' "-L$(PERL_INC)" "-Wl,-R$(INSTALLARCHLIB)/CORE" "-Wl,-R$(PERL_ARCHLIB)/CORE" -lperl';
         } elsif ($Config{'lddlflags'} =~ /-R/) {
-            $libs .= ' -L$(PERL_INC) -R$(INSTALLARCHLIB)/CORE -R$(PERL_ARCHLIB)/CORE -lperl';
+            $libs .= ' "-L$(PERL_INC)" "-R$(INSTALLARCHLIB)/CORE" "-R$(PERL_ARCHLIB)/CORE" -lperl';
         } elsif ( $Is{Android} ) {
             # The Android linker will not recognize symbols from
             # libperl unless the module explicitly depends on it.
-            $libs .= ' -L$(PERL_INC) -lperl';
+            $libs .= ' "-L$(PERL_INC)" -lperl';
         }
     }
 
@@ -1043,7 +1064,7 @@ WARNING
             next unless $self->maybe_command($abs);
             print "Executing $abs\n" if ($trace >= 2);
 
-            my $version_check = qq{$abs -le "require $ver; print qq{VER_OK}"};
+            my $version_check = qq{"$abs" -le "require $ver; print qq{VER_OK}"};
 
             # To avoid using the unportable 2>&1 to suppress STDERR,
             # we close it before running the command.
@@ -1191,10 +1212,6 @@ sub _fixin_replace_shebang {
             $shb .= ' ' . $arg if defined $arg;
             $shb .= "\n";
         }
-        $shb .= qq{
-eval 'exec $interpreter $arg -S \$0 \${1+"\$\@"}'
-    if 0; # not running under some shell
-} unless $Is{Win32};    # this won't work on win32, so don't
     }
     else {
         warn "Can't find $cmd in PATH, $file unchanged"
@@ -1712,6 +1729,8 @@ EOP
     	$self->{PERL_LIB} = File::Spec->rel2abs($self->{PERL_LIB});
     	$self->{PERL_ARCHLIB} = File::Spec->rel2abs($self->{PERL_ARCHLIB});
     }
+    $self->{PERL_INCDEP} = $self->{PERL_INC};
+    $self->{PERL_ARCHLIBDEP} = $self->{PERL_ARCHLIB};
 
     # We get SITELIBEXP and SITEARCHEXP directly via
     # Get_from_Config. When we are running standard modules, these
@@ -1805,6 +1824,7 @@ Unix has no need of special linker flags.
 sub init_linker {
     my($self) = shift;
     $self->{PERL_ARCHIVE} ||= '';
+    $self->{PERL_ARCHIVEDEP} ||= '';
     $self->{PERL_ARCHIVE_AFTER} ||= '';
     $self->{EXPORT_LIST}  ||= '';
 }
@@ -1909,8 +1929,20 @@ sub init_PERL {
 
     $self->{PERL} ||=
         $self->find_perl(5.0, \@perls, \@defpath, $Verbose );
-    # don't check if perl is executable, maybe they have decided to
-    # supply switches with perl
+
+    my $perl = $self->{PERL};
+    $perl =~ s/^"//;
+    my $has_mcr = $perl =~ s/^MCR\s*//;
+    my $perlflags = '';
+    my $stripped_perl;
+    while ($perl) {
+	($stripped_perl = $perl) =~ s/"$//;
+	last if -x $stripped_perl;
+	last unless $perl =~ s/(\s+\S+)$//;
+	$perlflags = $1.$perlflags;
+    }
+    $self->{PERL} = $stripped_perl;
+    $self->{PERL} = 'MCR '.$self->{PERL} if $has_mcr || $Is{VMS};
 
     # When built for debugging, VMS doesn't create perl.exe but ndbgperl.exe.
     my $perl_name = 'perl';
@@ -1920,13 +1952,18 @@ sub init_PERL {
     # XXX This logic is flawed.  If "miniperl" is anywhere in the path
     # it will get confused.  It should be fixed to work only on the filename.
     # Define 'FULLPERL' to be a non-miniperl (used in test: target)
-    ($self->{FULLPERL} = $self->{PERL}) =~ s/\Q$miniperl\E$/$perl_name$Config{exe_ext}/i
-	unless $self->{FULLPERL};
+    unless ($self->{FULLPERL}) {
+      ($self->{FULLPERL} = $self->{PERL}) =~ s/\Q$miniperl\E$/$perl_name$Config{exe_ext}/i;
+      $self->{FULLPERL} = qq{"$self->{FULLPERL}"}.$perlflags;
+    }
+    # Can't have an image name with quotes, and findperl will have
+    # already escaped spaces.
+    $self->{FULLPERL} =~ tr/"//d if $Is{VMS};
 
     # Little hack to get around VMS's find_perl putting "MCR" in front
     # sometimes.
     $self->{ABSPERL} = $self->{PERL};
-    my $has_mcr = $self->{ABSPERL} =~ s/^MCR\s*//;
+    $has_mcr = $self->{ABSPERL} =~ s/^MCR\s*//;
     if( $self->file_name_is_absolute($self->{ABSPERL}) ) {
         $self->{ABSPERL} = '$(PERL)';
     }
@@ -1939,6 +1976,11 @@ sub init_PERL {
 
         $self->{ABSPERL} = 'MCR '.$self->{ABSPERL} if $has_mcr;
     }
+    $self->{PERL} = qq{"$self->{PERL}"}.$perlflags;
+
+    # Can't have an image name with quotes, and findperl will have
+    # already escaped spaces.
+    $self->{PERL} =~ tr/"//d if $Is{VMS};
 
     # Are we building the core?
     $self->{PERL_CORE} = $ENV{PERL_CORE} unless exists $self->{PERL_CORE};
@@ -1948,14 +1990,15 @@ sub init_PERL {
     foreach my $perl (qw(PERL FULLPERL ABSPERL)) {
         my $run  = $perl.'RUN';
 
-        $self->{$run}  = "\$($perl)";
+        $self->{$run}  = qq{\$($perl)};
 
         # Make sure perl can find itself before it's installed.
         $self->{$run} .= q{ "-I$(PERL_LIB)" "-I$(PERL_ARCHLIB)"}
           if $self->{UNINSTALLED_PERL} || $self->{PERL_CORE};
 
         $self->{$perl.'RUNINST'} =
-          sprintf q{$(%sRUN) "-I$(INST_ARCHLIB)" "-I$(INST_LIB)"}, $perl;
+          sprintf q{$(%sRUN)%s "-I$(INST_ARCHLIB)" "-I$(INST_LIB)"},
+	    $perl, $perlflags;
     }
 
     return 1;
@@ -2079,54 +2122,54 @@ pure_perl_install :: all
 };
 
     push @m,
-q{		read }.$self->catfile('$(PERL_ARCHLIB)','auto','$(FULLEXT)','.packlist').q{ \
-		write }.$self->catfile('$(DESTINSTALLARCHLIB)','auto','$(FULLEXT)','.packlist').q{ \
+q{		read "}.$self->catfile('$(PERL_ARCHLIB)','auto','$(FULLEXT)','.packlist').q{" \
+		write "}.$self->catfile('$(DESTINSTALLARCHLIB)','auto','$(FULLEXT)','.packlist').q{" \
 } unless $self->{NO_PACKLIST};
 
     push @m,
-q{		$(INST_LIB) $(DESTINSTALLPRIVLIB) \
-		$(INST_ARCHLIB) $(DESTINSTALLARCHLIB) \
-		$(INST_BIN) $(DESTINSTALLBIN) \
-		$(INST_SCRIPT) $(DESTINSTALLSCRIPT) \
-		$(INST_MAN1DIR) $(DESTINSTALLMAN1DIR) \
-		$(INST_MAN3DIR) $(DESTINSTALLMAN3DIR)
+q{		"$(INST_LIB)" "$(DESTINSTALLPRIVLIB)" \
+		"$(INST_ARCHLIB)" "$(DESTINSTALLARCHLIB)" \
+		"$(INST_BIN)" "$(DESTINSTALLBIN)" \
+		"$(INST_SCRIPT)" "$(DESTINSTALLSCRIPT)" \
+		"$(INST_MAN1DIR)" "$(DESTINSTALLMAN1DIR)" \
+		"$(INST_MAN3DIR)" "$(DESTINSTALLMAN3DIR)"
 	$(NOECHO) $(WARN_IF_OLD_PACKLIST) \
-		}.$self->catdir('$(SITEARCHEXP)','auto','$(FULLEXT)').q{
+		"}.$self->catdir('$(SITEARCHEXP)','auto','$(FULLEXT)').q{"
 
 
 pure_site_install :: all
 	$(NOECHO) $(MOD_INSTALL) \
 };
     push @m,
-q{		read }.$self->catfile('$(SITEARCHEXP)','auto','$(FULLEXT)','.packlist').q{ \
-		write }.$self->catfile('$(DESTINSTALLSITEARCH)','auto','$(FULLEXT)','.packlist').q{ \
+q{		read "}.$self->catfile('$(SITEARCHEXP)','auto','$(FULLEXT)','.packlist').q{" \
+		write "}.$self->catfile('$(DESTINSTALLSITEARCH)','auto','$(FULLEXT)','.packlist').q{" \
 } unless $self->{NO_PACKLIST};
 
     push @m,
-q{		$(INST_LIB) $(DESTINSTALLSITELIB) \
-		$(INST_ARCHLIB) $(DESTINSTALLSITEARCH) \
-		$(INST_BIN) $(DESTINSTALLSITEBIN) \
-		$(INST_SCRIPT) $(DESTINSTALLSITESCRIPT) \
-		$(INST_MAN1DIR) $(DESTINSTALLSITEMAN1DIR) \
-		$(INST_MAN3DIR) $(DESTINSTALLSITEMAN3DIR)
+q{		"$(INST_LIB)" "$(DESTINSTALLSITELIB)" \
+		"$(INST_ARCHLIB)" "$(DESTINSTALLSITEARCH)" \
+		"$(INST_BIN)" "$(DESTINSTALLSITEBIN)" \
+		"$(INST_SCRIPT)" "$(DESTINSTALLSITESCRIPT)" \
+		"$(INST_MAN1DIR)" "$(DESTINSTALLSITEMAN1DIR)" \
+		"$(INST_MAN3DIR)" "$(DESTINSTALLSITEMAN3DIR)"
 	$(NOECHO) $(WARN_IF_OLD_PACKLIST) \
-		}.$self->catdir('$(PERL_ARCHLIB)','auto','$(FULLEXT)').q{
+		"}.$self->catdir('$(PERL_ARCHLIB)','auto','$(FULLEXT)').q{"
 
 pure_vendor_install :: all
 	$(NOECHO) $(MOD_INSTALL) \
 };
     push @m,
-q{		read }.$self->catfile('$(VENDORARCHEXP)','auto','$(FULLEXT)','.packlist').q{ \
-		write }.$self->catfile('$(DESTINSTALLVENDORARCH)','auto','$(FULLEXT)','.packlist').q{ \
+q{		read "}.$self->catfile('$(VENDORARCHEXP)','auto','$(FULLEXT)','.packlist').q{" \
+		write "}.$self->catfile('$(DESTINSTALLVENDORARCH)','auto','$(FULLEXT)','.packlist').q{" \
 } unless $self->{NO_PACKLIST};
 
     push @m,
-q{		$(INST_LIB) $(DESTINSTALLVENDORLIB) \
-		$(INST_ARCHLIB) $(DESTINSTALLVENDORARCH) \
-		$(INST_BIN) $(DESTINSTALLVENDORBIN) \
-		$(INST_SCRIPT) $(DESTINSTALLVENDORSCRIPT) \
-		$(INST_MAN1DIR) $(DESTINSTALLVENDORMAN1DIR) \
-		$(INST_MAN3DIR) $(DESTINSTALLVENDORMAN3DIR)
+q{		"$(INST_LIB)" "$(DESTINSTALLVENDORLIB)" \
+		"$(INST_ARCHLIB)" "$(DESTINSTALLVENDORARCH)" \
+		"$(INST_BIN)" "$(DESTINSTALLVENDORBIN)" \
+		"$(INST_SCRIPT)" "$(DESTINSTALLVENDORSCRIPT)" \
+		"$(INST_MAN1DIR)" "$(DESTINSTALLVENDORMAN1DIR)" \
+		"$(INST_MAN3DIR)" "$(DESTINSTALLVENDORMAN3DIR)"
 
 };
 
@@ -2144,37 +2187,37 @@ doc_vendor_install :: all
 
     push @m, q{
 doc_perl_install :: all
-	$(NOECHO) $(ECHO) Appending installation info to $(DESTINSTALLARCHLIB)/perllocal.pod
-	-$(NOECHO) $(MKPATH) $(DESTINSTALLARCHLIB)
+	$(NOECHO) $(ECHO) Appending installation info to "$(DESTINSTALLARCHLIB)/perllocal.pod"
+	-$(NOECHO) $(MKPATH) "$(DESTINSTALLARCHLIB)"
 	-$(NOECHO) $(DOC_INSTALL) \
 		"Module" "$(NAME)" \
-		"installed into" "$(INSTALLPRIVLIB)" \
+		"installed into" $(INSTALLPRIVLIB) \
 		LINKTYPE "$(LINKTYPE)" \
 		VERSION "$(VERSION)" \
 		EXE_FILES "$(EXE_FILES)" \
-		>> }.$self->catfile('$(DESTINSTALLARCHLIB)','perllocal.pod').q{
+		>> "}.$self->catfile('$(DESTINSTALLARCHLIB)','perllocal.pod').q{"
 
 doc_site_install :: all
-	$(NOECHO) $(ECHO) Appending installation info to $(DESTINSTALLARCHLIB)/perllocal.pod
-	-$(NOECHO) $(MKPATH) $(DESTINSTALLARCHLIB)
+	$(NOECHO) $(ECHO) Appending installation info to "$(DESTINSTALLARCHLIB)/perllocal.pod"
+	-$(NOECHO) $(MKPATH) "$(DESTINSTALLARCHLIB)"
 	-$(NOECHO) $(DOC_INSTALL) \
 		"Module" "$(NAME)" \
-		"installed into" "$(INSTALLSITELIB)" \
+		"installed into" $(INSTALLSITELIB) \
 		LINKTYPE "$(LINKTYPE)" \
 		VERSION "$(VERSION)" \
 		EXE_FILES "$(EXE_FILES)" \
-		>> }.$self->catfile('$(DESTINSTALLARCHLIB)','perllocal.pod').q{
+		>> "}.$self->catfile('$(DESTINSTALLARCHLIB)','perllocal.pod').q{"
 
 doc_vendor_install :: all
-	$(NOECHO) $(ECHO) Appending installation info to $(DESTINSTALLARCHLIB)/perllocal.pod
-	-$(NOECHO) $(MKPATH) $(DESTINSTALLARCHLIB)
+	$(NOECHO) $(ECHO) Appending installation info to "$(DESTINSTALLARCHLIB)/perllocal.pod"
+	-$(NOECHO) $(MKPATH) "$(DESTINSTALLARCHLIB)"
 	-$(NOECHO) $(DOC_INSTALL) \
 		"Module" "$(NAME)" \
-		"installed into" "$(INSTALLVENDORLIB)" \
+		"installed into" $(INSTALLVENDORLIB) \
 		LINKTYPE "$(LINKTYPE)" \
 		VERSION "$(VERSION)" \
 		EXE_FILES "$(EXE_FILES)" \
-		>> }.$self->catfile('$(DESTINSTALLARCHLIB)','perllocal.pod').q{
+		>> "}.$self->catfile('$(DESTINSTALLARCHLIB)','perllocal.pod').q{"
 
 } unless $self->{NO_PERLLOCAL};
 
@@ -2183,13 +2226,13 @@ uninstall :: uninstall_from_$(INSTALLDIRS)dirs
 	$(NOECHO) $(NOOP)
 
 uninstall_from_perldirs ::
-	$(NOECHO) $(UNINSTALL) }.$self->catfile('$(PERL_ARCHLIB)','auto','$(FULLEXT)','.packlist').q{
+	$(NOECHO) $(UNINSTALL) "}.$self->catfile('$(PERL_ARCHLIB)','auto','$(FULLEXT)','.packlist').q{"
 
 uninstall_from_sitedirs ::
-	$(NOECHO) $(UNINSTALL) }.$self->catfile('$(SITEARCHEXP)','auto','$(FULLEXT)','.packlist').q{
+	$(NOECHO) $(UNINSTALL) "}.$self->catfile('$(SITEARCHEXP)','auto','$(FULLEXT)','.packlist').q{"
 
 uninstall_from_vendordirs ::
-	$(NOECHO) $(UNINSTALL) }.$self->catfile('$(VENDORARCHEXP)','auto','$(FULLEXT)','.packlist').q{
+	$(NOECHO) $(UNINSTALL) "}.$self->catfile('$(VENDORARCHEXP)','auto','$(FULLEXT)','.packlist').q{"
 };
 
     join("",@m);
@@ -2343,7 +2386,7 @@ $(MAP_TARGET) :: static $(MAKE_APERL_FILE)
 $(MAKE_APERL_FILE) : $(FIRST_MAKEFILE) pm_to_blib
 	$(NOECHO) $(ECHO) Writing \"$(MAKE_APERL_FILE)\" for this $(MAP_TARGET)
 	$(NOECHO) $(PERLRUNINST) \
-		Makefile.PL DIR=}, $dir, q{ \
+		Makefile.PL DIR="}, $dir, q{" \
 		MAKEFILE=$(MAKE_APERL_FILE) LINKTYPE=static \
 		MAKEAPERL=1 NORECURS=1 CCCDLFLAGS=};
 
@@ -2521,20 +2564,20 @@ $tmp/perlmain.c: $makefilename}, q{
 		-e "writemain(grep s#.*/auto/##s, split(q| |, q|$(MAP_STATIC)|))" > $@t && $(MV) $@t $@
 
 };
-    push @m, "\t", q{$(NOECHO) $(PERL) $(INSTALLSCRIPT)/fixpmain
+    push @m, "\t", q{$(NOECHO) $(PERL) "$(INSTALLSCRIPT)/fixpmain"
 } if (defined (&Dos::UseLFN) && Dos::UseLFN()==0);
 
 
     push @m, q{
 doc_inst_perl :
-	$(NOECHO) $(ECHO) Appending installation info to $(DESTINSTALLARCHLIB)/perllocal.pod
-	-$(NOECHO) $(MKPATH) $(DESTINSTALLARCHLIB)
+	$(NOECHO) $(ECHO) Appending installation info to "$(DESTINSTALLARCHLIB)/perllocal.pod"
+	-$(NOECHO) $(MKPATH) "$(DESTINSTALLARCHLIB)"
 	-$(NOECHO) $(DOC_INSTALL) \
 		"Perl binary" "$(MAP_TARGET)" \
 		MAP_STATIC "$(MAP_STATIC)" \
 		MAP_EXTRA "`cat $(INST_ARCHAUTODIR)/extralibs.all`" \
 		MAP_LIBPERL "$(MAP_LIBPERL)" \
-		>> }.$self->catfile('$(DESTINSTALLARCHLIB)','perllocal.pod').q{
+		>> "}.$self->catfile('$(DESTINSTALLARCHLIB)','perllocal.pod').q{"
 
 };
 
@@ -2542,7 +2585,7 @@ doc_inst_perl :
 inst_perl : pure_inst_perl doc_inst_perl
 
 pure_inst_perl : $(MAP_TARGET)
-	}.$self->{CP}.q{ $(MAP_TARGET) }.$self->catfile('$(DESTINSTALLBIN)','$(MAP_TARGET)').q{
+	}.$self->{CP}.q{ $(MAP_TARGET) "}.$self->catfile('$(DESTINSTALLBIN)','$(MAP_TARGET)').q{"
 
 clean :: map_clean
 
@@ -2651,17 +2694,24 @@ sub parse_abstract {
     local $/ = "\n";
     open(my $fh, '<', $parsefile) or die "Could not open '$parsefile': $!";
     my $inpod = 0;
+    my $pod_encoding;
     my $package = $self->{DISTNAME};
     $package =~ s/-/::/g;
     while (<$fh>) {
         $inpod = /^=(?!cut)/ ? 1 : /^=cut/ ? 0 : $inpod;
         next if !$inpod;
         chop;
+
+        if ( /^=encoding\s*(.*)$/i ) {
+            $pod_encoding = $1;
+        }
+
         if ( /^($package(?:\.pm)? \s+ -+ \s+)(.*)/x ) {
           $result = $2;
           next;
         }
         next unless $result;
+
         if ( $result && ( /^\s*$/ || /^\=/ ) ) {
           last;
         }
@@ -2669,6 +2719,16 @@ sub parse_abstract {
     }
     close $fh;
 
+    if ( $pod_encoding and !( $] < 5.008 or !$Config{useperlio} ) ) {
+        # Have to wrap in an eval{} for when running under PERL_CORE
+        # Encode isn't available during build phase and parsing
+        # ABSTRACT isn't important there
+        eval {
+          require Encode;
+          $result = Encode::decode($pod_encoding, $result);
+        }
+    }
+
     return $result;
 }
 
@@ -2721,43 +2781,32 @@ sub parse_version {
 
     if ( defined $result && $result !~ /^v?[\d_\.]+$/ ) {
       require version;
-      my $normal = eval { version->parse( $result ) };
+      my $normal = eval { version->new( $result ) };
       $result = $normal if defined $normal;
     }
     $result = "undef" unless defined $result;
     return $result;
 }
 
-sub get_version
-{
-	my ($self, $parsefile, $sigil, $name) = @_;
-	my $eval = qq{
-		package ExtUtils::MakeMaker::_version;
-		no strict;
-		BEGIN { eval {
-			# Ensure any version() routine which might have leaked
-			# into this package has been deleted.  Interferes with
-			# version->import()
-			undef *version;
-			require version;
-			"version"->import;
-		} }
-
-		local $sigil$name;
-		\$$name=undef;
-		do {
-			$_
-		};
-		\$$name;
-	};
-  $eval = $1 if $eval =~ m{^(.+)}s;
-	local $^W = 0;
-	my $result = eval($eval);  ## no critic
-	warn "Could not eval '$eval' in $parsefile: $@" if $@;
-	$result;
+sub get_version {
+    my ($self, $parsefile, $sigil, $name) = @_;
+    my $line = $_; # from the while() loop in parse_version
+    {
+        package ExtUtils::MakeMaker::_version;
+        undef *version; # in case of unexpected version() sub
+        eval {
+            require version;
+            version::->import;
+        };
+        no strict;
+        local *{$name};
+        local $^W = 0;
+        $line = $1 if $line =~ m{^(.+)}s;
+        eval($line); ## no critic
+        return ${$name};
+    }
 }
 
-
 =item pasthru (o)
 
 Defines the string that is passed to recursive make calls in
@@ -2821,7 +2870,7 @@ sub perldepend {
 # Check for unpropogated config.sh changes. Should never happen.
 # We do NOT just update config.h because that is not sufficient.
 # An out of date config.h is not fatal but complains loudly!
-$(PERL_INC)/config.h: $(PERL_SRC)/config.sh
+$(PERL_INCDEP)/config.h: $(PERL_SRC)/config.sh
 	-$(NOECHO) $(ECHO) "Warning: $(PERL_INC)/config.h out of date with $(PERL_SRC)/config.sh"; $(FALSE)
 
 $(PERL_ARCHLIB)/Config.pm: $(PERL_SRC)/config.sh
@@ -2837,7 +2886,7 @@ MAKE_FRAG
         push @m, $self->_perl_header_files_fragment("/"); # Directory separator between $(PERL_INC)/header.h
     }
 
-    push @m, join(" ", values %{$self->{XS}})." : \$(XSUBPPDEPS)\n"  if %{$self->{XS}};
+    push @m, join(" ", sort values %{$self->{XS}})." : \$(XSUBPPDEPS)\n"  if %{$self->{XS}};
 
     return join "\n", @m;
 }
@@ -2960,11 +3009,11 @@ PPD_PERLVERS
     foreach my $prereq (sort keys %prereqs) {
         my $name = $prereq;
         $name .= '::' unless $name =~ /::/;
-        my $version = $prereqs{$prereq}+0;  # force numification
+        my $version = $prereqs{$prereq};
 
         my %attrs = ( NAME => $name );
         $attrs{VERSION} = $version if $version;
-        my $attrs = join " ", map { qq[$_="$attrs{$_}"] } keys %attrs;
+        my $attrs = join " ", map { qq[$_="$attrs{$_}"] } sort keys %attrs;
         $ppd_xml .= qq(        <REQUIRE $attrs />\n);
     }
 
@@ -3198,6 +3247,17 @@ sub oneliner {
 
 =item quote_literal
 
+Quotes macro literal value suitable for being used on a command line so
+that when expanded by make, will be received by command as given to
+this method:
+
+  my $quoted = $mm->quote_literal(q{it isn't});
+  # returns:
+  #   'it isn'\''t'
+  print MAKEFILE "target:\n\techo $quoted\n";
+  # when run "make target", will output:
+  #   it isn't
+
 =cut
 
 sub quote_literal {
@@ -3287,7 +3347,7 @@ END
     # If this extension has its own library (eg SDBM_File)
     # then copy that to $(INST_STATIC) and add $(OBJECT) into it.
     push(@m, <<'MAKE_FRAG') if $self->{MYEXTLIB};
-	$(CP) $(MYEXTLIB) $@
+	$(CP) $(MYEXTLIB) "$@"
 MAKE_FRAG
 
     my $ar;
@@ -3301,12 +3361,12 @@ MAKE_FRAG
     push @m, sprintf <<'MAKE_FRAG', $ar;
 	$(%s) $(AR_STATIC_ARGS) $@ $(OBJECT) && $(RANLIB) $@
 	$(CHMOD) $(PERM_RWX) $@
-	$(NOECHO) $(ECHO) "$(EXTRALIBS)" > $(INST_ARCHAUTODIR)/extralibs.ld
+	$(NOECHO) $(ECHO) "$(EXTRALIBS)" > "$(INST_ARCHAUTODIR)/extralibs.ld"
 MAKE_FRAG
 
     # Old mechanism - still available:
     push @m, <<'MAKE_FRAG' if $self->{PERL_SRC} && $self->{EXTRALIBS};
-	$(NOECHO) $(ECHO) "$(EXTRALIBS)" >> $(PERL_SRC)/ext.libs
+	$(NOECHO) $(ECHO) "$(EXTRALIBS)" >> "$(PERL_SRC)/ext.libs"
 MAKE_FRAG
 
     join('', @m);
@@ -3420,6 +3480,8 @@ sub test {
     elsif (!$tests && -d 't') {
         $tests = $self->find_tests;
     }
+    # have to do this because nmake is broken
+    $tests =~ s!/!\\!g if $self->is_make_type('nmake');
     # note: 'test.pl' name is also hardcoded in init_dirscan()
     my(@m);
     push(@m,"
@@ -3545,7 +3607,8 @@ sub tool_xsubpp {
         }
     }
     push(@tmdeps, "typemap") if -f "typemap";
-    my(@tmargs) = map("-typemap $_", @tmdeps);
+    my @tmargs = map(qq{-typemap "$_"}, @tmdeps);
+    $_ = $self->quote_dep($_) for @tmdeps;
     if( exists $self->{XSOPT} ){
         unshift( @tmargs, $self->{XSOPT} );
     }
@@ -3561,17 +3624,19 @@ sub tool_xsubpp {
 
 
     $self->{XSPROTOARG} = "" unless defined $self->{XSPROTOARG};
+    my $xsdirdep = $self->quote_dep($xsdir);
+    # -dep for use when dependency not command
 
     return qq{
 XSUBPPDIR = $xsdir
-XSUBPP = \$(XSUBPPDIR)\$(DFSEP)xsubpp
+XSUBPP = "\$(XSUBPPDIR)\$(DFSEP)xsubpp"
 XSUBPPRUN = \$(PERLRUN) \$(XSUBPP)
 XSPROTOARG = $self->{XSPROTOARG}
-XSUBPPDEPS = @tmdeps \$(XSUBPP)
+XSUBPPDEPS = @tmdeps $xsdirdep\$(DFSEP)xsubpp
 XSUBPPARGS = @tmargs
 XSUBPP_EXTRA_ARGS =
 };
-};
+}
 
 
 =item all_target
--- cpan/ExtUtils-MakeMaker/lib/ExtUtils/MM_VMS.pm
+++ cpan/ExtUtils-MakeMaker/lib/ExtUtils/MM_VMS.pm
@@ -15,7 +15,7 @@ BEGIN {
 
 use File::Basename;
 
-our $VERSION = '6.98';
+our $VERSION = '7.04_01';
 
 require ExtUtils::MM_Any;
 require ExtUtils::MM_Unix;
@@ -489,7 +489,7 @@ sub init_tools {
 
     $self->{MOD_INSTALL} ||=
       $self->oneliner(<<'CODE', ['-MExtUtils::Install']);
-install([ from_to => {split(' ', <STDIN>)}, verbose => '$(VERBINST)', uninstall_shadows => '$(UNINST)', dir_mode => '$(PERM_DIR)' ]);
+install([ from_to => {split('\|', <STDIN>)}, verbose => '$(VERBINST)', uninstall_shadows => '$(UNINST)', dir_mode => '$(PERM_DIR)' ]);
 CODE
 
     $self->{UMASK_NULL} = '! ';
@@ -1176,6 +1176,9 @@ install_perl :: all pure_perl_install doc_perl_install
 install_site :: all pure_site_install doc_site_install
 	$(NOECHO) $(NOOP)
 
+install_vendor :: all pure_vendor_install doc_vendor_install
+	$(NOECHO) $(NOOP)
+
 pure_install :: pure_$(INSTALLDIRS)_install
 	$(NOECHO) $(NOOP)
 
@@ -1192,54 +1195,54 @@ doc__install : doc_site_install
 pure_perl_install ::
 ];
     push @m,
-q[	$(NOECHO) $(PERLRUN) "-MFile::Spec" -e "print 'read '.File::Spec->catfile('$(PERL_ARCHLIB)','auto','$(FULLEXT)','.packlist').' '" >.MM_tmp
-	$(NOECHO) $(PERLRUN) "-MFile::Spec" -e "print 'write '.File::Spec->catfile('$(DESTINSTALLARCHLIB)','auto','$(FULLEXT)','.packlist').' '" >>.MM_tmp
+q[	$(NOECHO) $(PERLRUN) "-MFile::Spec" -e "print 'read|'.File::Spec->catfile('$(PERL_ARCHLIB)','auto','$(FULLEXT)','.packlist').'|'" >.MM_tmp
+	$(NOECHO) $(PERLRUN) "-MFile::Spec" -e "print 'write|'.File::Spec->catfile('$(DESTINSTALLARCHLIB)','auto','$(FULLEXT)','.packlist').'|'" >>.MM_tmp
 ] unless $self->{NO_PACKLIST};
 
     push @m,
-q[	$(NOECHO) $(ECHO_N) "$(INST_LIB) $(DESTINSTALLPRIVLIB) " >>.MM_tmp
-	$(NOECHO) $(ECHO_N) "$(INST_ARCHLIB) $(DESTINSTALLARCHLIB) " >>.MM_tmp
-	$(NOECHO) $(ECHO_N) "$(INST_BIN) $(DESTINSTALLBIN) " >>.MM_tmp
-	$(NOECHO) $(ECHO_N) "$(INST_SCRIPT) $(DESTINSTALLSCRIPT) " >>.MM_tmp
+q[	$(NOECHO) $(ECHO_N) "$(INST_LIB)|$(DESTINSTALLPRIVLIB)|" >>.MM_tmp
+	$(NOECHO) $(ECHO_N) "$(INST_ARCHLIB)|$(DESTINSTALLARCHLIB)|" >>.MM_tmp
+	$(NOECHO) $(ECHO_N) "$(INST_BIN)|$(DESTINSTALLBIN)|" >>.MM_tmp
+	$(NOECHO) $(ECHO_N) "$(INST_SCRIPT)|$(DESTINSTALLSCRIPT)|" >>.MM_tmp
 	$(NOECHO) $(ECHO_N) "$(INST_MAN1DIR) $(DESTINSTALLMAN1DIR) " >>.MM_tmp
-	$(NOECHO) $(ECHO_N) "$(INST_MAN3DIR) $(DESTINSTALLMAN3DIR) " >>.MM_tmp
+	$(NOECHO) $(ECHO_N) "$(INST_MAN3DIR)|$(DESTINSTALLMAN3DIR)" >>.MM_tmp
 	$(NOECHO) $(MOD_INSTALL) <.MM_tmp
 	$(NOECHO) $(RM_F) .MM_tmp
-	$(NOECHO) $(WARN_IF_OLD_PACKLIST) ].$self->catfile($self->{SITEARCHEXP},'auto',$self->{FULLEXT},'.packlist').q[
+	$(NOECHO) $(WARN_IF_OLD_PACKLIST) "].$self->catfile($self->{SITEARCHEXP},'auto',$self->{FULLEXT},'.packlist').q["
 
 # Likewise
 pure_site_install ::
 ];
     push @m,
-q[	$(NOECHO) $(PERLRUN) "-MFile::Spec" -e "print 'read '.File::Spec->catfile('$(SITEARCHEXP)','auto','$(FULLEXT)','.packlist').' '" >.MM_tmp
-	$(NOECHO) $(PERLRUN) "-MFile::Spec" -e "print 'write '.File::Spec->catfile('$(DESTINSTALLSITEARCH)','auto','$(FULLEXT)','.packlist').' '" >>.MM_tmp
+q[	$(NOECHO) $(PERLRUN) "-MFile::Spec" -e "print 'read|'.File::Spec->catfile('$(SITEARCHEXP)','auto','$(FULLEXT)','.packlist').'|'" >.MM_tmp
+	$(NOECHO) $(PERLRUN) "-MFile::Spec" -e "print 'write|'.File::Spec->catfile('$(DESTINSTALLSITEARCH)','auto','$(FULLEXT)','.packlist').'|'" >>.MM_tmp
 ] unless $self->{NO_PACKLIST};
 
     push @m,
-q[	$(NOECHO) $(ECHO_N) "$(INST_LIB) $(DESTINSTALLSITELIB) " >>.MM_tmp
-	$(NOECHO) $(ECHO_N) "$(INST_ARCHLIB) $(DESTINSTALLSITEARCH) " >>.MM_tmp
-	$(NOECHO) $(ECHO_N) "$(INST_BIN) $(DESTINSTALLSITEBIN) " >>.MM_tmp
-	$(NOECHO) $(ECHO_N) "$(INST_SCRIPT) $(DESTINSTALLSCRIPT) " >>.MM_tmp
-	$(NOECHO) $(ECHO_N) "$(INST_MAN1DIR) $(DESTINSTALLSITEMAN1DIR) " >>.MM_tmp
-	$(NOECHO) $(ECHO_N) "$(INST_MAN3DIR) $(DESTINSTALLSITEMAN3DIR) " >>.MM_tmp
+q[	$(NOECHO) $(ECHO_N) "$(INST_LIB)|$(DESTINSTALLSITELIB)|" >>.MM_tmp
+	$(NOECHO) $(ECHO_N) "$(INST_ARCHLIB)|$(DESTINSTALLSITEARCH)|" >>.MM_tmp
+	$(NOECHO) $(ECHO_N) "$(INST_BIN)|$(DESTINSTALLSITEBIN)|" >>.MM_tmp
+	$(NOECHO) $(ECHO_N) "$(INST_SCRIPT)|$(DESTINSTALLSCRIPT)|" >>.MM_tmp
+	$(NOECHO) $(ECHO_N) "$(INST_MAN1DIR)|$(DESTINSTALLSITEMAN1DIR)|" >>.MM_tmp
+	$(NOECHO) $(ECHO_N) "$(INST_MAN3DIR)|$(DESTINSTALLSITEMAN3DIR)" >>.MM_tmp
 	$(NOECHO) $(MOD_INSTALL) <.MM_tmp
 	$(NOECHO) $(RM_F) .MM_tmp
-	$(NOECHO) $(WARN_IF_OLD_PACKLIST) ].$self->catfile($self->{PERL_ARCHLIB},'auto',$self->{FULLEXT},'.packlist').q[
+	$(NOECHO) $(WARN_IF_OLD_PACKLIST) "].$self->catfile($self->{PERL_ARCHLIB},'auto',$self->{FULLEXT},'.packlist').q["
 
 pure_vendor_install ::
 ];
     push @m,
-q[	$(NOECHO) $(PERLRUN) "-MFile::Spec" -e "print 'read '.File::Spec->catfile('$(VENDORARCHEXP)','auto','$(FULLEXT)','.packlist').' '" >.MM_tmp
-	$(NOECHO) $(PERLRUN) "-MFile::Spec" -e "print 'write '.File::Spec->catfile('$(DESTINSTALLVENDORARCH)','auto','$(FULLEXT)','.packlist').' '" >>.MM_tmp
+q[	$(NOECHO) $(PERLRUN) "-MFile::Spec" -e "print 'read|'.File::Spec->catfile('$(VENDORARCHEXP)','auto','$(FULLEXT)','.packlist').'|'" >.MM_tmp
+	$(NOECHO) $(PERLRUN) "-MFile::Spec" -e "print 'write|'.File::Spec->catfile('$(DESTINSTALLVENDORARCH)','auto','$(FULLEXT)','.packlist').'|'" >>.MM_tmp
 ] unless $self->{NO_PACKLIST};
 
     push @m,
-q[	$(NOECHO) $(ECHO_N) "$(INST_LIB) $(DESTINSTALLVENDORLIB) " >>.MM_tmp
-	$(NOECHO) $(ECHO_N) "$(INST_ARCHLIB) $(DESTINSTALLVENDORARCH) " >>.MM_tmp
-	$(NOECHO) $(ECHO_N) "$(INST_BIN) $(DESTINSTALLVENDORBIN) " >>.MM_tmp
-	$(NOECHO) $(ECHO_N) "$(INST_SCRIPT) $(DESTINSTALLSCRIPT) " >>.MM_tmp
-	$(NOECHO) $(ECHO_N) "$(INST_MAN1DIR) $(DESTINSTALLVENDORMAN1DIR) " >>.MM_tmp
-	$(NOECHO) $(ECHO_N) "$(INST_MAN3DIR) $(DESTINSTALLVENDORMAN3DIR) " >>.MM_tmp
+q[	$(NOECHO) $(ECHO_N) "$(INST_LIB)|$(DESTINSTALLVENDORLIB)|" >>.MM_tmp
+	$(NOECHO) $(ECHO_N) "$(INST_ARCHLIB)|$(DESTINSTALLVENDORARCH)|" >>.MM_tmp
+	$(NOECHO) $(ECHO_N) "$(INST_BIN)|$(DESTINSTALLVENDORBIN)|" >>.MM_tmp
+	$(NOECHO) $(ECHO_N) "$(INST_SCRIPT)|$(DESTINSTALLSCRIPT)|" >>.MM_tmp
+	$(NOECHO) $(ECHO_N) "$(INST_MAN1DIR)|$(DESTINSTALLVENDORMAN1DIR)|" >>.MM_tmp
+	$(NOECHO) $(ECHO_N) "$(INST_MAN3DIR)|$(DESTINSTALLVENDORMAN3DIR)" >>.MM_tmp
 	$(NOECHO) $(MOD_INSTALL) <.MM_tmp
 	$(NOECHO) $(RM_F) .MM_tmp
 
@@ -1294,15 +1297,12 @@ uninstall :: uninstall_from_$(INSTALLDIRS)dirs
 
 uninstall_from_perldirs ::
 	$(NOECHO) $(UNINSTALL) ].$self->catfile($self->{PERL_ARCHLIB},'auto',$self->{FULLEXT},'.packlist').q[
-	$(NOECHO) $(ECHO) "Uninstall is now deprecated and makes no actual changes."
-	$(NOECHO) $(ECHO) "Please check the list above carefully for errors, and manually remove"
-	$(NOECHO) $(ECHO) "the appropriate files.  Sorry for the inconvenience."
 
 uninstall_from_sitedirs ::
 	$(NOECHO) $(UNINSTALL) ].$self->catfile($self->{SITEARCHEXP},'auto',$self->{FULLEXT},'.packlist').q[
-	$(NOECHO) $(ECHO) "Uninstall is now deprecated and makes no actual changes."
-	$(NOECHO) $(ECHO) "Please check the list above carefully for errors, and manually remove"
-	$(NOECHO) $(ECHO) "the appropriate files.  Sorry for the inconvenience."
+
+uninstall_from_vendordirs ::
+	$(NOECHO) $(UNINSTALL) ].$self->catfile($self->{VENDORARCHEXP},'auto',$self->{FULLEXT},'.packlist').q[
 ];
 
     join('',@m);
@@ -1893,6 +1893,7 @@ sub init_linker {
           $ENV{$shr} ? $ENV{$shr} : "Sys\$Share:$shr.$Config{'dlext'}";
     }
 
+    $self->{PERL_ARCHIVEDEP} ||= '';
     $self->{PERL_ARCHIVE_AFTER} ||= '';
 }
 
@@ -1951,10 +1952,6 @@ sub eliminate_macros {
     return '' unless $path;
     $self = {} unless ref $self;
 
-    if ($path =~ /\s/) {
-      return join ' ', map { $self->eliminate_macros($_) } split /\s+/, $path;
-    }
-
     my($npath) = unixify($path);
     # sometimes unixify will return a string with an off-by-one trailing null
     $npath =~ s{\0$}{};
@@ -2013,12 +2010,6 @@ sub fixpath {
     $self = bless {}, $self unless ref $self;
     my($fixedpath,$prefix,$name);
 
-    if ($path =~ /[ \t]/) {
-      return join ' ',
-             map { $self->fixpath($_,$force_path) }
-	     split /[ \t]+/, $path;
-    }
-
     if ($path =~ m#^\$\([^\)]+\)\Z(?!\n)#s || $path =~ m#[/:>\]]#) {
         if ($force_path or $path =~ /(?:DIR\)|\])\Z(?!\n)/) {
             $fixedpath = vmspath($self->eliminate_macros($path));
@@ -2065,6 +2056,21 @@ sub os_flavor {
     return('VMS');
 }
 
+
+=item is_make_type (override)
+
+None of the make types being checked for is viable on VMS,
+plus our $self->{MAKE} is an unexpanded (and unexpandable)
+macro whose value is known only to the make utility itself.
+
+=cut
+
+sub is_make_type {
+    my($self, $type) = @_;
+    return 0;
+}
+
+
 =back
 
 
--- cpan/ExtUtils-MakeMaker/lib/ExtUtils/MM_VOS.pm
+++ cpan/ExtUtils-MakeMaker/lib/ExtUtils/MM_VOS.pm
@@ -1,7 +1,7 @@
 package ExtUtils::MM_VOS;
 
 use strict;
-our $VERSION = '6.98';
+our $VERSION = '7.04_01';
 
 require ExtUtils::MM_Unix;
 our @ISA = qw(ExtUtils::MM_Unix);
--- cpan/ExtUtils-MakeMaker/lib/ExtUtils/MM_Win32.pm
+++ cpan/ExtUtils-MakeMaker/lib/ExtUtils/MM_Win32.pm
@@ -27,7 +27,7 @@ use ExtUtils::MakeMaker qw( neatvalue );
 require ExtUtils::MM_Any;
 require ExtUtils::MM_Unix;
 our @ISA = qw( ExtUtils::MM_Any ExtUtils::MM_Unix );
-our $VERSION = '6.98';
+our $VERSION = '7.04_01';
 
 $ENV{EMXSHELL} = 'sh'; # to run `commands`
 
@@ -128,7 +128,7 @@ sub maybe_command {
 
 =item B<init_DIRFILESEP>
 
-Using \ for Windows.
+Using \ for Windows, except for "gmake" where it is /.
 
 =cut
 
@@ -137,7 +137,8 @@ sub init_DIRFILESEP {
 
     # The ^ makes sure its not interpreted as an escape in nmake
     $self->{DIRFILESEP} = $self->is_make_type('nmake') ? '^\\' :
-                          $self->is_make_type('dmake') ? '\\\\'
+                          $self->is_make_type('dmake') ? '\\\\' :
+                          $self->is_make_type('gmake') ? '/'
                                                        : '\\';
 }
 
@@ -154,7 +155,7 @@ sub init_tools {
     $self->{DEV_NULL} ||= '> NUL';
 
     $self->{FIXIN}    ||= $self->{PERL_CORE} ?
-      "\$(PERLRUN) $self->{PERL_SRC}/win32/bin/pl2bat.pl" :
+      "\$(PERLRUN) $self->{PERL_SRC}\\win32\\bin\\pl2bat.pl" :
       'pl2bat.bat';
 
     $self->SUPER::init_tools;
@@ -346,27 +347,27 @@ sub dynamic_lib {
 OTHERLDFLAGS = '.$otherldflags.'
 INST_DYNAMIC_DEP = '.$inst_dynamic_dep.'
 
-$(INST_DYNAMIC): $(OBJECT) $(MYEXTLIB) $(BOOTSTRAP) $(INST_ARCHAUTODIR)$(DFSEP).exists $(EXPORT_LIST) $(PERL_ARCHIVE) $(INST_DYNAMIC_DEP)
+$(INST_DYNAMIC): $(OBJECT) $(MYEXTLIB) $(BOOTSTRAP) $(INST_ARCHAUTODIR)$(DFSEP).exists $(EXPORT_LIST) $(PERL_ARCHIVEDEP) $(INST_DYNAMIC_DEP)
 ');
     if ($GCC) {
       push(@m,
        q{	}.$DLLTOOL.q{ --def $(EXPORT_LIST) --output-exp dll.exp
-	$(LD) -o $@ -Wl,--base-file -Wl,dll.base $(LDDLFLAGS) }.$ldfrom.q{ $(OTHERLDFLAGS) $(MYEXTLIB) $(PERL_ARCHIVE) $(LDLOADLIBS) dll.exp
+	$(LD) -o $@ -Wl,--base-file -Wl,dll.base $(LDDLFLAGS) }.$ldfrom.q{ $(OTHERLDFLAGS) $(MYEXTLIB) "$(PERL_ARCHIVE)" $(LDLOADLIBS) dll.exp
 	}.$DLLTOOL.q{ --def $(EXPORT_LIST) --base-file dll.base --output-exp dll.exp
-	$(LD) -o $@ $(LDDLFLAGS) }.$ldfrom.q{ $(OTHERLDFLAGS) $(MYEXTLIB) $(PERL_ARCHIVE) $(LDLOADLIBS) dll.exp });
+	$(LD) -o $@ $(LDDLFLAGS) }.$ldfrom.q{ $(OTHERLDFLAGS) $(MYEXTLIB) "$(PERL_ARCHIVE)" $(LDLOADLIBS) dll.exp });
     } elsif ($BORLAND) {
       push(@m,
        q{	$(LD) $(LDDLFLAGS) $(OTHERLDFLAGS) }.$ldfrom.q{,$@,,}
        .($self->is_make_type('dmake')
-                ? q{$(PERL_ARCHIVE:s,/,\,) $(LDLOADLIBS:s,/,\,) }
+                ? q{"$(PERL_ARCHIVE:s,/,\,)" $(LDLOADLIBS:s,/,\,) }
 		 .q{$(MYEXTLIB:s,/,\,),$(EXPORT_LIST:s,/,\,)}
-		: q{$(subst /,\,$(PERL_ARCHIVE)) $(subst /,\,$(LDLOADLIBS)) }
+		: q{"$(subst /,\,$(PERL_ARCHIVE))" $(subst /,\,$(LDLOADLIBS)) }
 		 .q{$(subst /,\,$(MYEXTLIB)),$(subst /,\,$(EXPORT_LIST))})
        .q{,$(RESFILES)});
     } else {	# VC
       push(@m,
        q{	$(LD) -out:$@ $(LDDLFLAGS) }.$ldfrom.q{ $(OTHERLDFLAGS) }
-      .q{$(MYEXTLIB) $(PERL_ARCHIVE) $(LDLOADLIBS) -def:$(EXPORT_LIST)});
+      .q{$(MYEXTLIB) "$(PERL_ARCHIVE)" $(LDLOADLIBS) -def:$(EXPORT_LIST)});
 
       # Embed the manifest file if it exists
       push(@m, q{
@@ -401,6 +402,7 @@ sub init_linker {
     my $self = shift;
 
     $self->{PERL_ARCHIVE}       = "\$(PERL_INC)\\$Config{libperl}";
+    $self->{PERL_ARCHIVEDEP}    = "\$(PERL_INCDEP)\\$Config{libperl}";
     $self->{PERL_ARCHIVE_AFTER} = '';
     $self->{EXPORT_LIST}        = '$(BASEEXT).def';
 }
@@ -421,6 +423,29 @@ sub perl_script {
     return;
 }
 
+sub can_dep_space {
+    my $self = shift;
+    1; # with Win32::GetShortPathName
+}
+
+=item quote_dep
+
+=cut
+
+sub quote_dep {
+    my ($self, $arg) = @_;
+    if ($arg =~ / / and not $self->is_make_type('gmake')) {
+        require Win32;
+        $arg = Win32::GetShortPathName($arg);
+        die <<EOF if not defined $arg or $arg =~ / /;
+Tried to use make dependency with space for non-GNU make:
+  '$arg'
+Fallback to short pathname failed.
+EOF
+        return $arg;
+    }
+    return $self->SUPER::quote_dep($arg);
+}
 
 =item xs_o
 
@@ -622,16 +647,7 @@ PERLTYPE = $self->{PERLTYPE}
 
 }
 
-sub is_make_type {
-    my($self, $type) = @_;
-    return !! ($self->make =~ /\b$type(?:\.exe)?$/);
-}
-
 1;
 __END__
 
 =back
-
-=cut
-
-
--- cpan/ExtUtils-MakeMaker/lib/ExtUtils/MM_Win95.pm
+++ cpan/ExtUtils-MakeMaker/lib/ExtUtils/MM_Win95.pm
@@ -2,7 +2,7 @@ package ExtUtils::MM_Win95;
 
 use strict;
 
-our $VERSION = '6.98';
+our $VERSION = '7.04_01';
 
 require ExtUtils::MM_Win32;
 our @ISA = qw(ExtUtils::MM_Win32);
--- cpan/ExtUtils-MakeMaker/lib/ExtUtils/MY.pm
+++ cpan/ExtUtils-MakeMaker/lib/ExtUtils/MY.pm
@@ -3,7 +3,7 @@ package ExtUtils::MY;
 use strict;
 require ExtUtils::MM;
 
-our $VERSION = '6.98';
+our $VERSION = '7.04_01';
 our @ISA = qw(ExtUtils::MM);
 
 {
--- cpan/ExtUtils-MakeMaker/lib/ExtUtils/MakeMaker.pm
+++ cpan/ExtUtils-MakeMaker/lib/ExtUtils/MakeMaker.pm
@@ -7,8 +7,12 @@ BEGIN {require 5.006;}
 
 require Exporter;
 use ExtUtils::MakeMaker::Config;
+use ExtUtils::MakeMaker::version; # ensure we always have our fake version.pm
 use Carp;
 use File::Path;
+my $CAN_DECODE = eval { require ExtUtils::MakeMaker::Locale; }; # 2 birds, 1 stone
+eval { ExtUtils::MakeMaker::Locale::reinit('UTF-8') }
+  if $CAN_DECODE and $ExtUtils::MakeMaker::Locale::ENCODING_LOCALE eq 'US-ASCII';
 
 our $Verbose = 0;       # exported
 our @Parent;            # needs to be localized
@@ -17,8 +21,10 @@ our @MM_Sections;
 our @Overridable;
 my @Prepend_parent;
 my %Recognized_Att_Keys;
+our %macro_fsentity; # whether a macro is a filesystem name
+our %macro_dep; # whether a macro is a dependency
 
-our $VERSION = '6.98';
+our $VERSION = '7.04_01';
 $VERSION = eval $VERSION;  ## no critic [BuiltinFunctions::ProhibitStringyEval]
 
 # Emulate something resembling CVS $Revision$
@@ -28,7 +34,7 @@ $Revision = int $Revision * 10000;
 our $Filename = __FILE__;   # referenced outside MakeMaker
 
 our @ISA = qw(Exporter);
-our @EXPORT    = qw(&WriteMakefile &writeMakefile $Verbose &prompt);
+our @EXPORT    = qw(&WriteMakefile $Verbose &prompt);
 our @EXPORT_OK = qw($VERSION &neatvalue &mkbootstrap &mksymlists
                     &WriteEmptyMakefile);
 
@@ -36,6 +42,7 @@ our @EXPORT_OK = qw($VERSION &neatvalue &mkbootstrap &mksymlists
 # purged.
 my $Is_VMS     = $^O eq 'VMS';
 my $Is_Win32   = $^O eq 'MSWin32';
+my $UNDER_CORE = $ENV{PERL_CORE};
 
 full_setup();
 
@@ -250,14 +257,12 @@ my $PACKNAME = 'PACK000';
 sub full_setup {
     $Verbose ||= 0;
 
-    my @attrib_help = qw/
+    my @dep_macros = qw/
+    PERL_INCDEP        PERL_ARCHLIBDEP     PERL_ARCHIVEDEP
+    /;
 
-    AUTHOR ABSTRACT ABSTRACT_FROM BINARY_LOCATION
-    C CAPI CCFLAGS CONFIG CONFIGURE DEFINE DIR DISTNAME DISTVNAME
-    DL_FUNCS DL_VARS
-    EXCLUDE_EXT EXE_FILES FIRST_MAKEFILE
-    FULLPERL FULLPERLRUN FULLPERLRUNINST
-    FUNCLIST H IMPORTS
+    my @fs_macros = qw/
+    FULLPERL XSUBPPDIR
 
     INST_ARCHLIB INST_SCRIPT INST_BIN INST_LIB INST_MAN1DIR INST_MAN3DIR
     INSTALLDIRS
@@ -273,22 +278,41 @@ sub full_setup {
     PERL_LIB        PERL_ARCHLIB
     SITELIBEXP      SITEARCHEXP
 
-    INC INCLUDE_EXT LDFROM LIB LIBPERL_A LIBS LICENSE
-    LINKTYPE MAKE MAKEAPERL MAKEFILE MAKEFILE_OLD MAN1PODS MAN3PODS MAP_TARGET
+    MAKE LIBPERL_A LIB PERL_SRC PERL_INC
+    PPM_INSTALL_EXEC PPM_UNINSTALL_EXEC
+    PPM_INSTALL_SCRIPT PPM_UNINSTALL_SCRIPT
+    /;
+
+    my @attrib_help = qw/
+
+    AUTHOR ABSTRACT ABSTRACT_FROM BINARY_LOCATION
+    C CAPI CCFLAGS CONFIG CONFIGURE DEFINE DIR DISTNAME DISTVNAME
+    DL_FUNCS DL_VARS
+    EXCLUDE_EXT EXE_FILES FIRST_MAKEFILE
+    FULLPERLRUN FULLPERLRUNINST
+    FUNCLIST H IMPORTS
+
+    INC INCLUDE_EXT LDFROM LIBS LICENSE
+    LINKTYPE MAKEAPERL MAKEFILE MAKEFILE_OLD MAN1PODS MAN3PODS MAP_TARGET
     META_ADD META_MERGE MIN_PERL_VERSION BUILD_REQUIRES CONFIGURE_REQUIRES
     MYEXTLIB NAME NEEDS_LINKING NOECHO NO_META NO_MYMETA NO_PACKLIST NO_PERLLOCAL
     NORECURS NO_VC OBJECT OPTIMIZE PERL_MALLOC_OK PERL PERLMAINCC PERLRUN
     PERLRUNINST PERL_CORE
-    PERL_SRC PERM_DIR PERM_RW PERM_RWX MAGICXS
-    PL_FILES PM PM_FILTER PMLIBDIRS PMLIBPARENTDIRS POLLUTE PPM_INSTALL_EXEC PPM_UNINSTALL_EXEC
-    PPM_INSTALL_SCRIPT PPM_UNINSTALL_SCRIPT PREREQ_FATAL PREREQ_PM PREREQ_PRINT PRINT_PREREQ
+    PERM_DIR PERM_RW PERM_RWX MAGICXS
+    PL_FILES PM PM_FILTER PMLIBDIRS PMLIBPARENTDIRS POLLUTE
+    PREREQ_FATAL PREREQ_PM PREREQ_PRINT PRINT_PREREQ
     SIGN SKIP TEST_REQUIRES TYPEMAPS UNINST VERSION VERSION_FROM XS XSOPT XSPROTOARG
     XS_VERSION clean depend dist dynamic_lib linkext macro realclean
     tool_autosplit
 
+    MAN1EXT MAN3EXT
+
     MACPERL_SRC MACPERL_LIB MACLIBS_68K MACLIBS_PPC MACLIBS_SC MACLIBS_MRC
     MACLIBS_ALL_68K MACLIBS_ALL_PPC MACLIBS_SHARED
         /;
+    push @attrib_help, @fs_macros;
+    @macro_fsentity{@fs_macros, @dep_macros} = (1) x (@fs_macros+@dep_macros);
+    @macro_dep{@dep_macros} = (1) x @dep_macros;
 
     # IMPORTS is used under OS/2 and Win32
 
@@ -381,26 +405,6 @@ sub full_setup {
     );
 }
 
-sub writeMakefile {
-    die <<END;
-
-The extension you are trying to build apparently is rather old and
-most probably outdated. We detect that from the fact, that a
-subroutine "writeMakefile" is called, and this subroutine is not
-supported anymore since about October 1994.
-
-Please contact the author or look into CPAN (details about CPAN can be
-found in the FAQ and at http:/www.perl.com) for a more recent version
-of the extension. If you're really desperate, you can try to change
-the subroutine name from writeMakefile to WriteMakefile and rerun
-'perl Makefile.PL', but you're most probably left alone, when you do
-so.
-
-The MakeMaker team
-
-END
-}
-
 sub new {
     my($class,$self) = @_;
     my($key);
@@ -449,7 +453,7 @@ sub new {
             # simulate "use warnings FATAL => 'all'" for vintage perls
             die @_;
         };
-        version->parse( $self->{MIN_PERL_VERSION} )
+        version->new( $self->{MIN_PERL_VERSION} )
       };
       $self->{MIN_PERL_VERSION} = $normal if defined $normal && !$@;
     }
@@ -502,7 +506,7 @@ END
           if ( defined $required_version && $required_version =~ /^v?[\d_\.]+$/
                || $required_version !~ /^v?[\d_\.]+$/ ) {
             require version;
-            my $normal = eval { version->parse( $required_version ) };
+            my $normal = eval { version->new( $required_version ) };
             $required_version = $normal if defined $normal;
           }
           $installed_file = $prereq;
@@ -585,10 +589,7 @@ END
 
             $self->{$key} = $self->{PARENT}{$key};
 
-            unless ($Is_VMS && $key =~ /PERL$/) {
-                $self->{$key} = $self->catdir("..",$self->{$key})
-                  unless $self->file_name_is_absolute($self->{$key});
-            } else {
+            if ($Is_VMS && $key =~ /PERL$/) {
                 # PERL or FULLPERL will be a command verb or even a
                 # command with an argument instead of a full file
                 # specification under VMS.  So, don't turn the command
@@ -598,6 +599,14 @@ END
                 $cmd[1] = $self->catfile('[-]',$cmd[1])
                   unless (@cmd < 2) || $self->file_name_is_absolute($cmd[1]);
                 $self->{$key} = join(' ', @cmd);
+            } else {
+                my $value = $self->{$key};
+                # not going to test in FS so only stripping start
+                $value =~ s/^"// if $key =~ /PERL$/;
+                $value = $self->catdir("..", $value)
+                  unless $self->file_name_is_absolute($value);
+                $value = qq{"$value} if $key =~ /PERL$/;
+                $self->{$key} = $value;
             }
         }
         if ($self->{PARENT}) {
@@ -821,7 +830,7 @@ END
 
     foreach my $key (sort keys %$att){
         next if $key eq 'ARGS';
-        my ($v) = neatvalue($att->{$key});
+        my $v;
         if ($key eq 'PREREQ_PM') {
             # CPAN.pm takes prereqs from this field in 'Makefile'
             # and does not know about BUILD_REQUIRES
@@ -938,6 +947,7 @@ sub check_manifest {
 
 sub parse_args{
     my($self, @args) = @_;
+    @args = map { Encode::decode(locale => $_) } @args if $CAN_DECODE;
     foreach (@args) {
         unless (m/(.*?)=(.*)/) {
             ++$Verbose if m/^verb/;
@@ -1162,8 +1172,13 @@ sub flush {
     unlink($finalname, "MakeMaker.tmp", $Is_VMS ? 'Descrip.MMS' : ());
     open(my $fh,">", "MakeMaker.tmp")
         or die "Unable to open MakeMaker.tmp: $!";
+    binmode $fh, ':encoding(locale)' if $CAN_DECODE;
 
     for my $chunk (@{$self->{RESULT}}) {
+        my $to_write = "$chunk\n";
+        if (!$CAN_DECODE && $] > 5.008) {
+            utf8::encode $to_write;
+        }
         print $fh "$chunk\n"
             or die "Can't write to MakeMaker.tmp: $!";
     }
@@ -1242,28 +1257,62 @@ sub neatvalue {
         push @m, "]";
         return join "", @m;
     }
-    return "$v" unless $t eq 'HASH';
+    return $v unless $t eq 'HASH';
     my(@m, $key, $val);
-    while (($key,$val) = each %$v){
+    for my $key (sort keys %$v) {
         last unless defined $key; # cautious programming in case (undef,undef) is true
-        push(@m,"$key=>".neatvalue($val)) ;
+        push @m,"$key=>".neatvalue($v->{$key});
     }
     return "{ ".join(', ',@m)." }";
 }
 
+sub _find_magic_vstring {
+    my $value = shift;
+    return $value if $UNDER_CORE;
+    my $tvalue = '';
+    require B;
+    my $sv = B::svref_2object(\$value);
+    my $magic = ref($sv) eq 'B::PVMG' ? $sv->MAGIC : undef;
+    while ( $magic ) {
+        if ( $magic->TYPE eq 'V' ) {
+            $tvalue = $magic->PTR;
+            $tvalue =~ s/^v?(.+)$/v$1/;
+            last;
+        }
+        else {
+            $magic = $magic->MOREMAGIC;
+        }
+    }
+    return $tvalue;
+}
+
+
 # Look for weird version numbers, warn about them and set them to 0
 # before CPAN::Meta chokes.
 sub clean_versions {
     my($self, $key) = @_;
-
     my $reqs = $self->{$key};
     for my $module (keys %$reqs) {
-        my $version = $reqs->{$module};
-
-        if( !defined $version or $version !~ /^v?[\d_\.]+$/ ) {
-            carp "Unparsable version '$version' for prerequisite $module";
+        my $v = $reqs->{$module};
+        my $printable = _find_magic_vstring($v);
+        $v = $printable if length $printable;
+        my $version = eval {
+            local $SIG{__WARN__} = sub {
+              # simulate "use warnings FATAL => 'all'" for vintage perls
+              die @_;
+            };
+            version->new($v)->stringify;
+        };
+        if( $@ || $reqs->{$module} eq '' ) {
+            if ( $] < 5.008 && $v !~ /^v?[\d_\.]+$/ ) {
+               $v = sprintf "v%vd", $v unless $v eq '';
+            }
+            carp "Unparsable version '$v' for prerequisite $module";
             $reqs->{$module} = 0;
         }
+        else {
+            $reqs->{$module} = $version;
+        }
     }
 }
 
@@ -1318,15 +1367,19 @@ won't have to face the possibly bewildering errors resulting from
 using the wrong one.
 
 On POSIX systems, that program will likely be GNU Make; on Microsoft
-Windows, it will be either Microsoft NMake or DMake. Note that this
-module does not support generating Makefiles for GNU Make on Windows.
+Windows, it will be either Microsoft NMake, DMake or GNU Make.
 See the section on the L</"MAKE"> parameter for details.
 
-MakeMaker is object oriented. Each directory below the current
+ExtUtils::MakeMaker (EUMM) is object oriented. Each directory below the current
 directory that contains a Makefile.PL is treated as a separate
 object. This makes it possible to write an unlimited number of
 Makefiles with a single invocation of WriteMakefile().
 
+All inputs to WriteMakefile are Unicode characters, not just octets. EUMM
+seeks to handle all of these correctly. It is currently still not possible
+to portably use Unicode characters in module names, because this requires
+Perl to handle Unicode filenames, which is not yet the case on Windows.
+
 =head2 How To Write A Makefile.PL
 
 See L<ExtUtils::MakeMaker::Tutorial>.
@@ -1375,6 +1428,11 @@ It is possible to use globbing with this mechanism.
 
   make test TEST_FILES='t/foobar.t t/dagobah*.t'
 
+Windows users who are using C<nmake> should note that due to a bug in C<nmake>,
+when specifying C<TEST_FILES> you must use back-slashes instead of forward-slashes.
+
+  nmake test TEST_FILES='t\foobar.t t\dagobah*.t'
+
 =head2 make testdb
 
 A useful variation of the above is the target C<testdb>. It runs the
@@ -2111,7 +2169,8 @@ linkext below).
 
 =item MAGICXS
 
-When this is set to C<1>, C<OBJECT> will be automagically derived from C<XS>.
+When this is set to C<1>, C<OBJECT> will be automagically derived from
+C<O_FILES>.
 
 =item MAKE
 
@@ -2195,6 +2254,20 @@ own.  META_MERGE will merge its value with the default.
 Unless you want to override the defaults, prefer META_MERGE so as to
 get the advantage of any future defaults.
 
+Where prereqs are concerned, if META_MERGE is used, prerequisites are merged
+with their counterpart C<WriteMakefile()> argument
+(PREREQ_PM is merged into {prereqs}{runtime}{requires},
+BUILD_REQUIRES into C<{prereqs}{build}{requires}>,
+CONFIGURE_REQUIRES into C<{prereqs}{configure}{requires}>,
+and TEST_REQUIRES into C<{prereqs}{test}{requires})>.
+When prereqs are specified with META_ADD, the only prerequisites added to the
+file come from the metadata, not C<WriteMakefile()> arguments.
+
+Note that these configuration options are only used for generating F<META.yml>
+and F<META.json> -- they are NOT used for F<MYMETA.yml> and F<MYMETA.json>.
+Therefore data in these fields should NOT be used for dynamic (user-side)
+configuration.
+
 By default CPAN Meta specification C<1.4> is used. In order to use
 CPAN Meta specification C<2.0>, indicate with C<meta-spec> the version
 you want to use.
@@ -2232,9 +2305,9 @@ name of the library (see SDBM_File)
 
 The package representing the distribution. For example, C<Test::More>
 or C<ExtUtils::MakeMaker>. It will be used to derive information about
-the distribution such as the L<DISTNAME>, installation locations
+the distribution such as the L</DISTNAME>, installation locations
 within the Perl library and where XS files will be looked for by
-default (see L<XS>).
+default (see L</XS>).
 
 C<NAME> I<must> be a valid Perl package name and it I<must> have an
 associated C<.pm> file. For example, C<Foo::Bar> is a valid C<NAME>
@@ -3092,6 +3165,12 @@ If no $default is provided an empty string will be used instead.
 
 =back
 
+=head2 Supported versions of Perl
+
+Please note that while this module works on Perl 5.6, it is no longer
+being routinely tested on 5.6 - the earliest Perl version being routinely
+tested, and expressly supported, is 5.8.1. However, patches to repair
+any breakage on 5.6 are still being accepted.
 
 =head1 ENVIRONMENT
 
@@ -3130,6 +3209,13 @@ help you setup your distribution.
 
 L<CPAN::Meta> and L<CPAN::Meta::Spec> explain CPAN Meta files in detail.
 
+L<File::ShareDir::Install> makes it easy to install static, sometimes
+also referred to as 'shared' files. L<File::ShareDir> helps accessing
+the shared files after installation.
+
+L<Dist::Zilla> makes it easy for the module author to create MakeMaker-based
+distributions with lots of bells and whistles.
+
 =head1 AUTHORS
 
 Andy Dougherty C<doughera@lafayette.edu>, Andreas KE<ouml>nig
--- cpan/ExtUtils-MakeMaker/lib/ExtUtils/MakeMaker/Config.pm
+++ cpan/ExtUtils-MakeMaker/lib/ExtUtils/MakeMaker/Config.pm
@@ -2,7 +2,7 @@ package ExtUtils::MakeMaker::Config;
 
 use strict;
 
-our $VERSION = '6.98';
+our $VERSION = '7.04_01';
 
 use Config ();
 
--- /dev/null
+++ cpan/ExtUtils-MakeMaker/lib/ExtUtils/MakeMaker/Locale.pm
@@ -0,0 +1,376 @@
+package ExtUtils::MakeMaker::Locale;
+
+use strict;
+our $VERSION = "7.04_01";
+
+use base 'Exporter';
+our @EXPORT_OK = qw(
+    decode_argv env
+    $ENCODING_LOCALE $ENCODING_LOCALE_FS
+    $ENCODING_CONSOLE_IN $ENCODING_CONSOLE_OUT
+);
+
+use Encode ();
+use Encode::Alias ();
+
+our $ENCODING_LOCALE;
+our $ENCODING_LOCALE_FS;
+our $ENCODING_CONSOLE_IN;
+our $ENCODING_CONSOLE_OUT;
+
+sub DEBUG () { 0 }
+
+sub _init {
+    if ($^O eq "MSWin32") {
+	unless ($ENCODING_LOCALE) {
+	    # Try to obtain what the Windows ANSI code page is
+	    eval {
+		unless (defined &GetConsoleCP) {
+		    require Win32;
+                    # no point falling back to Win32::GetConsoleCP from this
+                    # as added same time, 0.45
+                    eval { Win32::GetConsoleCP() };
+                    # manually "import" it since Win32->import refuses
+		    *GetConsoleCP = sub { &Win32::GetConsoleCP } unless $@;
+		}
+		unless (defined &GetConsoleCP) {
+		    require Win32::API;
+		    Win32::API->Import('kernel32', 'int GetConsoleCP()');
+		}
+		if (defined &GetConsoleCP) {
+		    my $cp = GetConsoleCP();
+		    $ENCODING_LOCALE = "cp$cp" if $cp;
+		}
+	    };
+	}
+
+	unless ($ENCODING_CONSOLE_IN) {
+            # only test one since set together
+            unless (defined &GetInputCP) {
+                eval {
+                    require Win32;
+                    eval { Win32::GetConsoleCP() };
+                    # manually "import" it since Win32->import refuses
+                    *GetInputCP = sub { &Win32::GetConsoleCP } unless $@;
+                    *GetOutputCP = sub { &Win32::GetConsoleOutputCP } unless $@;
+                };
+                unless (defined &GetInputCP) {
+                    eval {
+                        # try Win32::Console module for codepage to use
+                        require Win32::Console;
+                        eval { Win32::Console::InputCP() };
+                        *GetInputCP = sub { &Win32::Console::InputCP }
+                            unless $@;
+                        *GetOutputCP = sub { &Win32::Console::OutputCP }
+                            unless $@;
+                    };
+                }
+                unless (defined &GetInputCP) {
+                    # final fallback
+                    *GetInputCP = *GetOutputCP = sub {
+                        # another fallback that could work is:
+                        # reg query HKLM\System\CurrentControlSet\Control\Nls\CodePage /v ACP
+                        ((qx(chcp) || '') =~ /^Active code page: (\d+)/)
+                            ? $1 : ();
+                    };
+                }
+	    }
+            my $cp = GetInputCP();
+            $ENCODING_CONSOLE_IN = "cp$cp" if $cp;
+            $cp = GetOutputCP();
+            $ENCODING_CONSOLE_OUT = "cp$cp" if $cp;
+	}
+    }
+
+    unless ($ENCODING_LOCALE) {
+	eval {
+	    require I18N::Langinfo;
+	    $ENCODING_LOCALE = I18N::Langinfo::langinfo(I18N::Langinfo::CODESET());
+
+	    # Workaround of Encode < v2.25.  The "646" encoding  alias was
+	    # introduced in Encode-2.25, but we don't want to require that version
+	    # quite yet.  Should avoid the CPAN testers failure reported from
+	    # openbsd-4.7/perl-5.10.0 combo.
+	    $ENCODING_LOCALE = "ascii" if $ENCODING_LOCALE eq "646";
+
+	    # https://rt.cpan.org/Ticket/Display.html?id=66373
+	    $ENCODING_LOCALE = "hp-roman8" if $^O eq "hpux" && $ENCODING_LOCALE eq "roman8";
+	};
+	$ENCODING_LOCALE ||= $ENCODING_CONSOLE_IN;
+    }
+
+    if ($^O eq "darwin") {
+	$ENCODING_LOCALE_FS ||= "UTF-8";
+    }
+
+    # final fallback
+    $ENCODING_LOCALE ||= $^O eq "MSWin32" ? "cp1252" : "UTF-8";
+    $ENCODING_LOCALE_FS ||= $ENCODING_LOCALE;
+    $ENCODING_CONSOLE_IN ||= $ENCODING_LOCALE;
+    $ENCODING_CONSOLE_OUT ||= $ENCODING_CONSOLE_IN;
+
+    unless (Encode::find_encoding($ENCODING_LOCALE)) {
+	my $foundit;
+	if (lc($ENCODING_LOCALE) eq "gb18030") {
+	    eval {
+		require Encode::HanExtra;
+	    };
+	    if ($@) {
+		die "Need Encode::HanExtra to be installed to support locale codeset ($ENCODING_LOCALE), stopped";
+	    }
+	    $foundit++ if Encode::find_encoding($ENCODING_LOCALE);
+	}
+	die "The locale codeset ($ENCODING_LOCALE) isn't one that perl can decode, stopped"
+	    unless $foundit;
+
+    }
+
+    # use Data::Dump; ddx $ENCODING_LOCALE, $ENCODING_LOCALE_FS, $ENCODING_CONSOLE_IN, $ENCODING_CONSOLE_OUT;
+}
+
+_init();
+Encode::Alias::define_alias(sub {
+    no strict 'refs';
+    no warnings 'once';
+    return ${"ENCODING_" . uc(shift)};
+}, "locale");
+
+sub _flush_aliases {
+    no strict 'refs';
+    for my $a (keys %Encode::Alias::Alias) {
+	if (defined ${"ENCODING_" . uc($a)}) {
+	    delete $Encode::Alias::Alias{$a};
+	    warn "Flushed alias cache for $a" if DEBUG;
+	}
+    }
+}
+
+sub reinit {
+    $ENCODING_LOCALE = shift;
+    $ENCODING_LOCALE_FS = shift;
+    $ENCODING_CONSOLE_IN = $ENCODING_LOCALE;
+    $ENCODING_CONSOLE_OUT = $ENCODING_LOCALE;
+    _init();
+    _flush_aliases();
+}
+
+sub decode_argv {
+    die if defined wantarray;
+    for (@ARGV) {
+	$_ = Encode::decode(locale => $_, @_);
+    }
+}
+
+sub env {
+    my $k = Encode::encode(locale => shift);
+    my $old = $ENV{$k};
+    if (@_) {
+	my $v = shift;
+	if (defined $v) {
+	    $ENV{$k} = Encode::encode(locale => $v);
+	}
+	else {
+	    delete $ENV{$k};
+	}
+    }
+    return Encode::decode(locale => $old) if defined wantarray;
+}
+
+1;
+
+__END__
+
+=head1 NAME
+
+ExtUtils::MakeMaker::Locale - bundled Encode::Locale
+
+=head1 SYNOPSIS
+
+  use Encode::Locale;
+  use Encode;
+
+  $string = decode(locale => $bytes);
+  $bytes = encode(locale => $string);
+
+  if (-t) {
+      binmode(STDIN, ":encoding(console_in)");
+      binmode(STDOUT, ":encoding(console_out)");
+      binmode(STDERR, ":encoding(console_out)");
+  }
+
+  # Processing file names passed in as arguments
+  my $uni_filename = decode(locale => $ARGV[0]);
+  open(my $fh, "<", encode(locale_fs => $uni_filename))
+     || die "Can't open '$uni_filename': $!";
+  binmode($fh, ":encoding(locale)");
+  ...
+
+=head1 DESCRIPTION
+
+In many applications it's wise to let Perl use Unicode for the strings it
+processes.  Most of the interfaces Perl has to the outside world are still byte
+based.  Programs therefore need to decode byte strings that enter the program
+from the outside and encode them again on the way out.
+
+The POSIX locale system is used to specify both the language conventions
+requested by the user and the preferred character set to consume and
+output.  The C<Encode::Locale> module looks up the charset and encoding (called
+a CODESET in the locale jargon) and arranges for the L<Encode> module to know
+this encoding under the name "locale".  It means bytes obtained from the
+environment can be converted to Unicode strings by calling C<<
+Encode::encode(locale => $bytes) >> and converted back again with C<<
+Encode::decode(locale => $string) >>.
+
+Where file systems interfaces pass file names in and out of the program we also
+need care.  The trend is for operating systems to use a fixed file encoding
+that don't actually depend on the locale; and this module determines the most
+appropriate encoding for file names. The L<Encode> module will know this
+encoding under the name "locale_fs".  For traditional Unix systems this will
+be an alias to the same encoding as "locale".
+
+For programs running in a terminal window (called a "Console" on some systems)
+the "locale" encoding is usually a good choice for what to expect as input and
+output.  Some systems allows us to query the encoding set for the terminal and
+C<Encode::Locale> will do that if available and make these encodings known
+under the C<Encode> aliases "console_in" and "console_out".  For systems where
+we can't determine the terminal encoding these will be aliased as the same
+encoding as "locale".  The advice is to use "console_in" for input known to
+come from the terminal and "console_out" for output to the terminal.
+
+In addition to arranging for various Encode aliases the following functions and
+variables are provided:
+
+=over
+
+=item decode_argv( )
+
+=item decode_argv( Encode::FB_CROAK )
+
+This will decode the command line arguments to perl (the C<@ARGV> array) in-place.
+
+The function will by default replace characters that can't be decoded by
+"\x{FFFD}", the Unicode replacement character.
+
+Any argument provided is passed as CHECK to underlying Encode::decode() call.
+Pass the value C<Encode::FB_CROAK> to have the decoding croak if not all the
+command line arguments can be decoded.  See L<Encode/"Handling Malformed Data">
+for details on other options for CHECK.
+
+=item env( $uni_key )
+
+=item env( $uni_key => $uni_value )
+
+Interface to get/set environment variables.  Returns the current value as a
+Unicode string. The $uni_key and $uni_value arguments are expected to be
+Unicode strings as well.  Passing C<undef> as $uni_value deletes the
+environment variable named $uni_key.
+
+The returned value will have the characters that can't be decoded replaced by
+"\x{FFFD}", the Unicode replacement character.
+
+There is no interface to request alternative CHECK behavior as for
+decode_argv().  If you need that you need to call encode/decode yourself.
+For example:
+
+    my $key = Encode::encode(locale => $uni_key, Encode::FB_CROAK);
+    my $uni_value = Encode::decode(locale => $ENV{$key}, Encode::FB_CROAK);
+
+=item reinit( )
+
+=item reinit( $encoding )
+
+Reinitialize the encodings from the locale.  You want to call this function if
+you changed anything in the environment that might influence the locale.
+
+This function will croak if the determined encoding isn't recognized by
+the Encode module.
+
+With argument force $ENCODING_... variables to set to the given value.
+
+=item $ENCODING_LOCALE
+
+The encoding name determined to be suitable for the current locale.
+L<Encode> know this encoding as "locale".
+
+=item $ENCODING_LOCALE_FS
+
+The encoding name determined to be suitable for file system interfaces
+involving file names.
+L<Encode> know this encoding as "locale_fs".
+
+=item $ENCODING_CONSOLE_IN
+
+=item $ENCODING_CONSOLE_OUT
+
+The encodings to be used for reading and writing output to the a console.
+L<Encode> know these encodings as "console_in" and "console_out".
+
+=back
+
+=head1 NOTES
+
+This table summarizes the mapping of the encodings set up
+by the C<Encode::Locale> module:
+
+  Encode      |         |              |
+  Alias       | Windows | Mac OS X     | POSIX
+  ------------+---------+--------------+------------
+  locale      | ANSI    | nl_langinfo  | nl_langinfo
+  locale_fs   | ANSI    | UTF-8        | nl_langinfo
+  console_in  | OEM     | nl_langinfo  | nl_langinfo
+  console_out | OEM     | nl_langinfo  | nl_langinfo
+
+=head2 Windows
+
+Windows has basically 2 sets of APIs.  A wide API (based on passing UTF-16
+strings) and a byte based API based a character set called ANSI.  The
+regular Perl interfaces to the OS currently only uses the ANSI APIs.
+Unfortunately ANSI is not a single character set.
+
+The encoding that corresponds to ANSI varies between different editions of
+Windows.  For many western editions of Windows ANSI corresponds to CP-1252
+which is a character set similar to ISO-8859-1.  Conceptually the ANSI
+character set is a similar concept to the POSIX locale CODESET so this module
+figures out what the ANSI code page is and make this available as
+$ENCODING_LOCALE and the "locale" Encoding alias.
+
+Windows systems also operate with another byte based character set.
+It's called the OEM code page.  This is the encoding that the Console
+takes as input and output.  It's common for the OEM code page to
+differ from the ANSI code page.
+
+=head2 Mac OS X
+
+On Mac OS X the file system encoding is always UTF-8 while the locale
+can otherwise be set up as normal for POSIX systems.
+
+File names on Mac OS X will at the OS-level be converted to
+NFD-form.  A file created by passing a NFC-filename will come
+in NFD-form from readdir().  See L<Unicode::Normalize> for details
+of NFD/NFC.
+
+Actually, Apple does not follow the Unicode NFD standard since not all
+character ranges are decomposed.  The claim is that this avoids problems with
+round trip conversions from old Mac text encodings.  See L<Encode::UTF8Mac> for
+details.
+
+=head2 POSIX (Linux and other Unixes)
+
+File systems might vary in what encoding is to be used for
+filenames.  Since this module has no way to actually figure out
+what the is correct it goes with the best guess which is to
+assume filenames are encoding according to the current locale.
+Users are advised to always specify UTF-8 as the locale charset.
+
+=head1 SEE ALSO
+
+L<I18N::Langinfo>, L<Encode>, L<Term::Encoding>
+
+=head1 AUTHOR
+
+Copyright 2010 Gisle Aas <gisle@aas.no>.
+
+This library is free software; you can redistribute it and/or
+modify it under the same terms as Perl itself.
+
+=cut
--- /dev/null
+++ cpan/ExtUtils-MakeMaker/lib/ExtUtils/MakeMaker/version.pm
@@ -0,0 +1,55 @@
+#--------------------------------------------------------------------------#
+# This is a modified copy of version.pm 0.9909, bundled exclusively for
+# use by ExtUtils::Makemaker and its dependencies to bootstrap when
+# version.pm is not available.  It should not be used by ordinary modules.
+#
+# When loaded, it will try to load version.pm.  If that fails, it will load
+# ExtUtils::MakeMaker::version::vpp and alias various *version functions
+# to functions in that module.  It will also override UNIVERSAL::VERSION.
+#--------------------------------------------------------------------------#
+
+package ExtUtils::MakeMaker::version;
+
+use 5.006002;
+use strict;
+
+use vars qw(@ISA $VERSION $CLASS $STRICT $LAX *declare *qv);
+
+$VERSION = '7.04_01';
+$CLASS = 'version';
+
+{
+    local $SIG{'__DIE__'};
+    eval "use version";
+    if ( $@ ) { # don't have any version.pm installed
+        eval "use ExtUtils::MakeMaker::version::vpp";
+        die "$@" if ( $@ );
+        local $^W;
+        delete $INC{'version.pm'};
+        $INC{'version.pm'} = $INC{'ExtUtils/MakeMaker/version.pm'};
+        push @version::ISA, "ExtUtils::MakeMaker::version::vpp";
+        $version::VERSION = $VERSION;
+        *version::qv = \&ExtUtils::MakeMaker::version::vpp::qv;
+        *version::declare = \&ExtUtils::MakeMaker::version::vpp::declare;
+        *version::_VERSION = \&ExtUtils::MakeMaker::version::vpp::_VERSION;
+        *version::vcmp = \&ExtUtils::MakeMaker::version::vpp::vcmp;
+        *version::new = \&ExtUtils::MakeMaker::version::vpp::new;
+        if ($] >= 5.009000) {
+            no strict 'refs';
+            *version::stringify = \&ExtUtils::MakeMaker::version::vpp::stringify;
+            *{'version::(""'} = \&ExtUtils::MakeMaker::version::vpp::stringify;
+            *{'version::(<=>'} = \&ExtUtils::MakeMaker::version::vpp::vcmp;
+            *version::parse = \&ExtUtils::MakeMaker::version::vpp::parse;
+        }
+        require ExtUtils::MakeMaker::version::regex;
+        *version::is_lax = \&ExtUtils::MakeMaker::version::regex::is_lax;
+        *version::is_strict = \&ExtUtils::MakeMaker::version::regex::is_strict;
+        *LAX = \$ExtUtils::MakeMaker::version::regex::LAX;
+        *STRICT = \$ExtUtils::MakeMaker::version::regex::STRICT;
+    }
+    elsif ( ! version->can('is_qv') ) {
+        *version::is_qv = sub { exists $_[0]->{qv} };
+    }
+}
+
+1;
--- /dev/null
+++ cpan/ExtUtils-MakeMaker/lib/ExtUtils/MakeMaker/version/regex.pm
@@ -0,0 +1,123 @@
+#--------------------------------------------------------------------------#
+# This is a modified copy of version.pm 0.9909, bundled exclusively for
+# use by ExtUtils::Makemaker and its dependencies to bootstrap when
+# version.pm is not available.  It should not be used by ordinary modules.
+#--------------------------------------------------------------------------#
+
+package ExtUtils::MakeMaker::version::regex;
+
+use strict;
+
+use vars qw($VERSION $CLASS $STRICT $LAX);
+
+$VERSION = '7.04_01';
+
+#--------------------------------------------------------------------------#
+# Version regexp components
+#--------------------------------------------------------------------------#
+
+# Fraction part of a decimal version number.  This is a common part of
+# both strict and lax decimal versions
+
+my $FRACTION_PART = qr/\.[0-9]+/;
+
+# First part of either decimal or dotted-decimal strict version number.
+# Unsigned integer with no leading zeroes (except for zero itself) to
+# avoid confusion with octal.
+
+my $STRICT_INTEGER_PART = qr/0|[1-9][0-9]*/;
+
+# First part of either decimal or dotted-decimal lax version number.
+# Unsigned integer, but allowing leading zeros.  Always interpreted
+# as decimal.  However, some forms of the resulting syntax give odd
+# results if used as ordinary Perl expressions, due to how perl treats
+# octals.  E.g.
+#   version->new("010" ) == 10
+#   version->new( 010  ) == 8
+#   version->new( 010.2) == 82  # "8" . "2"
+
+my $LAX_INTEGER_PART = qr/[0-9]+/;
+
+# Second and subsequent part of a strict dotted-decimal version number.
+# Leading zeroes are permitted, and the number is always decimal.
+# Limited to three digits to avoid overflow when converting to decimal
+# form and also avoid problematic style with excessive leading zeroes.
+
+my $STRICT_DOTTED_DECIMAL_PART = qr/\.[0-9]{1,3}/;
+
+# Second and subsequent part of a lax dotted-decimal version number.
+# Leading zeroes are permitted, and the number is always decimal.  No
+# limit on the numerical value or number of digits, so there is the
+# possibility of overflow when converting to decimal form.
+
+my $LAX_DOTTED_DECIMAL_PART = qr/\.[0-9]+/;
+
+# Alpha suffix part of lax version number syntax.  Acts like a
+# dotted-decimal part.
+
+my $LAX_ALPHA_PART = qr/_[0-9]+/;
+
+#--------------------------------------------------------------------------#
+# Strict version regexp definitions
+#--------------------------------------------------------------------------#
+
+# Strict decimal version number.
+
+my $STRICT_DECIMAL_VERSION =
+    qr/ $STRICT_INTEGER_PART $FRACTION_PART? /x;
+
+# Strict dotted-decimal version number.  Must have both leading "v" and
+# at least three parts, to avoid confusion with decimal syntax.
+
+my $STRICT_DOTTED_DECIMAL_VERSION =
+    qr/ v $STRICT_INTEGER_PART $STRICT_DOTTED_DECIMAL_PART{2,} /x;
+
+# Complete strict version number syntax -- should generally be used
+# anchored: qr/ \A $STRICT \z /x
+
+$STRICT =
+    qr/ $STRICT_DECIMAL_VERSION | $STRICT_DOTTED_DECIMAL_VERSION /x;
+
+#--------------------------------------------------------------------------#
+# Lax version regexp definitions
+#--------------------------------------------------------------------------#
+
+# Lax decimal version number.  Just like the strict one except for
+# allowing an alpha suffix or allowing a leading or trailing
+# decimal-point
+
+my $LAX_DECIMAL_VERSION =
+    qr/ $LAX_INTEGER_PART (?: \. | $FRACTION_PART $LAX_ALPHA_PART? )?
+	|
+	$FRACTION_PART $LAX_ALPHA_PART?
+    /x;
+
+# Lax dotted-decimal version number.  Distinguished by having either
+# leading "v" or at least three non-alpha parts.  Alpha part is only
+# permitted if there are at least two non-alpha parts. Strangely
+# enough, without the leading "v", Perl takes .1.2 to mean v0.1.2,
+# so when there is no "v", the leading part is optional
+
+my $LAX_DOTTED_DECIMAL_VERSION =
+    qr/
+	v $LAX_INTEGER_PART (?: $LAX_DOTTED_DECIMAL_PART+ $LAX_ALPHA_PART? )?
+	|
+	$LAX_INTEGER_PART? $LAX_DOTTED_DECIMAL_PART{2,} $LAX_ALPHA_PART?
+    /x;
+
+# Complete lax version number syntax -- should generally be used
+# anchored: qr/ \A $LAX \z /x
+#
+# The string 'undef' is a special case to make for easier handling
+# of return values from ExtUtils::MM->parse_version
+
+$LAX =
+    qr/ undef | $LAX_DECIMAL_VERSION | $LAX_DOTTED_DECIMAL_VERSION /x;
+
+#--------------------------------------------------------------------------#
+
+# Preloaded methods go here.
+sub is_strict	{ defined $_[0] && $_[0] =~ qr/ \A $STRICT \z /x }
+sub is_lax	{ defined $_[0] && $_[0] =~ qr/ \A $LAX \z /x }
+
+1;
--- /dev/null
+++ cpan/ExtUtils-MakeMaker/lib/ExtUtils/MakeMaker/version/vpp.pm
@@ -0,0 +1,1028 @@
+#--------------------------------------------------------------------------#
+# This is a modified copy of version.pm 0.9909, bundled exclusively for
+# use by ExtUtils::Makemaker and its dependencies to bootstrap when
+# version.pm is not available.  It should not be used by ordinary modules.
+#--------------------------------------------------------------------------#
+
+package ExtUtils::MakeMaker::charstar;
+# a little helper class to emulate C char* semantics in Perl
+# so that prescan_version can use the same code as in C
+
+use overload (
+    '""'	=> \&thischar,
+    '0+'	=> \&thischar,
+    '++'	=> \&increment,
+    '--'	=> \&decrement,
+    '+'		=> \&plus,
+    '-'		=> \&minus,
+    '*'		=> \&multiply,
+    'cmp'	=> \&cmp,
+    '<=>'	=> \&spaceship,
+    'bool'	=> \&thischar,
+    '='		=> \&clone,
+);
+
+sub new {
+    my ($self, $string) = @_;
+    my $class = ref($self) || $self;
+
+    my $obj = {
+	string  => [split(//,$string)],
+	current => 0,
+    };
+    return bless $obj, $class;
+}
+
+sub thischar {
+    my ($self) = @_;
+    my $last = $#{$self->{string}};
+    my $curr = $self->{current};
+    if ($curr >= 0 && $curr <= $last) {
+	return $self->{string}->[$curr];
+    }
+    else {
+	return '';
+    }
+}
+
+sub increment {
+    my ($self) = @_;
+    $self->{current}++;
+}
+
+sub decrement {
+    my ($self) = @_;
+    $self->{current}--;
+}
+
+sub plus {
+    my ($self, $offset) = @_;
+    my $rself = $self->clone;
+    $rself->{current} += $offset;
+    return $rself;
+}
+
+sub minus {
+    my ($self, $offset) = @_;
+    my $rself = $self->clone;
+    $rself->{current} -= $offset;
+    return $rself;
+}
+
+sub multiply {
+    my ($left, $right, $swapped) = @_;
+    my $char = $left->thischar();
+    return $char * $right;
+}
+
+sub spaceship {
+    my ($left, $right, $swapped) = @_;
+    unless (ref($right)) { # not an object already
+	$right = $left->new($right);
+    }
+    return $left->{current} <=> $right->{current};
+}
+
+sub cmp {
+    my ($left, $right, $swapped) = @_;
+    unless (ref($right)) { # not an object already
+	if (length($right) == 1) { # comparing single character only
+	    return $left->thischar cmp $right;
+	}
+	$right = $left->new($right);
+    }
+    return $left->currstr cmp $right->currstr;
+}
+
+sub bool {
+    my ($self) = @_;
+    my $char = $self->thischar;
+    return ($char ne '');
+}
+
+sub clone {
+    my ($left, $right, $swapped) = @_;
+    $right = {
+	string  => [@{$left->{string}}],
+	current => $left->{current},
+    };
+    return bless $right, ref($left);
+}
+
+sub currstr {
+    my ($self, $s) = @_;
+    my $curr = $self->{current};
+    my $last = $#{$self->{string}};
+    if (defined($s) && $s->{current} < $last) {
+	$last = $s->{current};
+    }
+
+    my $string = join('', @{$self->{string}}[$curr..$last]);
+    return $string;
+}
+
+package ExtUtils::MakeMaker::version::vpp;
+
+use 5.006002;
+use strict;
+
+use Config;
+use vars qw($VERSION $CLASS @ISA $LAX $STRICT);
+$VERSION = '7.04_01';
+$CLASS = 'ExtUtils::MakeMaker::version::vpp';
+
+require ExtUtils::MakeMaker::version::regex;
+*ExtUtils::MakeMaker::version::vpp::is_strict = \&ExtUtils::MakeMaker::version::regex::is_strict;
+*ExtUtils::MakeMaker::version::vpp::is_lax = \&ExtUtils::MakeMaker::version::regex::is_lax;
+*LAX = \$ExtUtils::MakeMaker::version::regex::LAX;
+*STRICT = \$ExtUtils::MakeMaker::version::regex::STRICT;
+
+use overload (
+    '""'       => \&stringify,
+    '0+'       => \&numify,
+    'cmp'      => \&vcmp,
+    '<=>'      => \&vcmp,
+    'bool'     => \&vbool,
+    '+'        => \&vnoop,
+    '-'        => \&vnoop,
+    '*'        => \&vnoop,
+    '/'        => \&vnoop,
+    '+='        => \&vnoop,
+    '-='        => \&vnoop,
+    '*='        => \&vnoop,
+    '/='        => \&vnoop,
+    'abs'      => \&vnoop,
+);
+
+eval "use warnings";
+if ($@) {
+    eval '
+	package
+	warnings;
+	sub enabled {return $^W;}
+	1;
+    ';
+}
+
+sub import {
+    no strict 'refs';
+    my ($class) = shift;
+
+    # Set up any derived class
+    unless ($class eq $CLASS) {
+	local $^W;
+	*{$class.'::declare'} =  \&{$CLASS.'::declare'};
+	*{$class.'::qv'} = \&{$CLASS.'::qv'};
+    }
+
+    my %args;
+    if (@_) { # any remaining terms are arguments
+	map { $args{$_} = 1 } @_
+    }
+    else { # no parameters at all on use line
+	%args =
+	(
+	    qv => 1,
+	    'UNIVERSAL::VERSION' => 1,
+	);
+    }
+
+    my $callpkg = caller();
+
+    if (exists($args{declare})) {
+	*{$callpkg.'::declare'} =
+	    sub {return $class->declare(shift) }
+	  unless defined(&{$callpkg.'::declare'});
+    }
+
+    if (exists($args{qv})) {
+	*{$callpkg.'::qv'} =
+	    sub {return $class->qv(shift) }
+	  unless defined(&{$callpkg.'::qv'});
+    }
+
+    if (exists($args{'UNIVERSAL::VERSION'})) {
+	local $^W;
+	*UNIVERSAL::VERSION
+		= \&{$CLASS.'::_VERSION'};
+    }
+
+    if (exists($args{'VERSION'})) {
+	*{$callpkg.'::VERSION'} = \&{$CLASS.'::_VERSION'};
+    }
+
+    if (exists($args{'is_strict'})) {
+	*{$callpkg.'::is_strict'} = \&{$CLASS.'::is_strict'}
+	  unless defined(&{$callpkg.'::is_strict'});
+    }
+
+    if (exists($args{'is_lax'})) {
+	*{$callpkg.'::is_lax'} = \&{$CLASS.'::is_lax'}
+	  unless defined(&{$callpkg.'::is_lax'});
+    }
+}
+
+my $VERSION_MAX = 0x7FFFFFFF;
+
+# implement prescan_version as closely to the C version as possible
+use constant TRUE  => 1;
+use constant FALSE => 0;
+
+sub isDIGIT {
+    my ($char) = shift->thischar();
+    return ($char =~ /\d/);
+}
+
+sub isALPHA {
+    my ($char) = shift->thischar();
+    return ($char =~ /[a-zA-Z]/);
+}
+
+sub isSPACE {
+    my ($char) = shift->thischar();
+    return ($char =~ /\s/);
+}
+
+sub BADVERSION {
+    my ($s, $errstr, $error) = @_;
+    if ($errstr) {
+	$$errstr = $error;
+    }
+    return $s;
+}
+
+sub prescan_version {
+    my ($s, $strict, $errstr, $sqv, $ssaw_decimal, $swidth, $salpha) = @_;
+    my $qv          = defined $sqv          ? $$sqv          : FALSE;
+    my $saw_decimal = defined $ssaw_decimal ? $$ssaw_decimal : 0;
+    my $width       = defined $swidth       ? $$swidth       : 3;
+    my $alpha       = defined $salpha       ? $$salpha       : FALSE;
+
+    my $d = $s;
+
+    if ($qv && isDIGIT($d)) {
+	goto dotted_decimal_version;
+    }
+
+    if ($d eq 'v') { # explicit v-string
+	$d++;
+	if (isDIGIT($d)) {
+	    $qv = TRUE;
+	}
+	else { # degenerate v-string
+	    # requires v1.2.3
+	    return BADVERSION($s,$errstr,"Invalid version format (dotted-decimal versions require at least three parts)");
+	}
+
+dotted_decimal_version:
+	if ($strict && $d eq '0' && isDIGIT($d+1)) {
+	    # no leading zeros allowed
+	    return BADVERSION($s,$errstr,"Invalid version format (no leading zeros)");
+	}
+
+	while (isDIGIT($d)) { 	# integer part
+	    $d++;
+	}
+
+	if ($d eq '.')
+	{
+	    $saw_decimal++;
+	    $d++; 		# decimal point
+	}
+	else
+	{
+	    if ($strict) {
+		# require v1.2.3
+		return BADVERSION($s,$errstr,"Invalid version format (dotted-decimal versions require at least three parts)");
+	    }
+	    else {
+		goto version_prescan_finish;
+	    }
+	}
+
+	{
+	    my $i = 0;
+	    my $j = 0;
+	    while (isDIGIT($d)) {	# just keep reading
+		$i++;
+		while (isDIGIT($d)) {
+		    $d++; $j++;
+		    # maximum 3 digits between decimal
+		    if ($strict && $j > 3) {
+			return BADVERSION($s,$errstr,"Invalid version format (maximum 3 digits between decimals)");
+		    }
+		}
+		if ($d eq '_') {
+		    if ($strict) {
+			return BADVERSION($s,$errstr,"Invalid version format (no underscores)");
+		    }
+		    if ( $alpha ) {
+			return BADVERSION($s,$errstr,"Invalid version format (multiple underscores)");
+		    }
+		    $d++;
+		    $alpha = TRUE;
+		}
+		elsif ($d eq '.') {
+		    if ($alpha) {
+			return BADVERSION($s,$errstr,"Invalid version format (underscores before decimal)");
+		    }
+		    $saw_decimal++;
+		    $d++;
+		}
+		elsif (!isDIGIT($d)) {
+		    last;
+		}
+		$j = 0;
+	    }
+
+	    if ($strict && $i < 2) {
+		# requires v1.2.3
+		return BADVERSION($s,$errstr,"Invalid version format (dotted-decimal versions require at least three parts)");
+	    }
+	}
+    } 					# end if dotted-decimal
+    else
+    {					# decimal versions
+	my $j = 0;
+	# special $strict case for leading '.' or '0'
+	if ($strict) {
+	    if ($d eq '.') {
+		return BADVERSION($s,$errstr,"Invalid version format (0 before decimal required)");
+	    }
+	    if ($d eq '0' && isDIGIT($d+1)) {
+		return BADVERSION($s,$errstr,"Invalid version format (no leading zeros)");
+	    }
+	}
+
+	# and we never support negative version numbers
+	if ($d eq '-') {
+	    return BADVERSION($s,$errstr,"Invalid version format (negative version number)");
+	}
+
+	# consume all of the integer part
+	while (isDIGIT($d)) {
+	    $d++;
+	}
+
+	# look for a fractional part
+	if ($d eq '.') {
+	    # we found it, so consume it
+	    $saw_decimal++;
+	    $d++;
+	}
+	elsif (!$d || $d eq ';' || isSPACE($d) || $d eq '}') {
+	    if ( $d == $s ) {
+		# found nothing
+		return BADVERSION($s,$errstr,"Invalid version format (version required)");
+	    }
+	    # found just an integer
+	    goto version_prescan_finish;
+	}
+	elsif ( $d == $s ) {
+	    # didn't find either integer or period
+	    return BADVERSION($s,$errstr,"Invalid version format (non-numeric data)");
+	}
+	elsif ($d eq '_') {
+	    # underscore can't come after integer part
+	    if ($strict) {
+		return BADVERSION($s,$errstr,"Invalid version format (no underscores)");
+	    }
+	    elsif (isDIGIT($d+1)) {
+		return BADVERSION($s,$errstr,"Invalid version format (alpha without decimal)");
+	    }
+	    else {
+		return BADVERSION($s,$errstr,"Invalid version format (misplaced underscore)");
+	    }
+	}
+	elsif ($d) {
+	    # anything else after integer part is just invalid data
+	    return BADVERSION($s,$errstr,"Invalid version format (non-numeric data)");
+	}
+
+	# scan the fractional part after the decimal point
+	if ($d && !isDIGIT($d) && ($strict || ! ($d eq ';' || isSPACE($d) || $d eq '}') )) {
+		# $strict or lax-but-not-the-end
+		return BADVERSION($s,$errstr,"Invalid version format (fractional part required)");
+	}
+
+	while (isDIGIT($d)) {
+	    $d++; $j++;
+	    if ($d eq '.' && isDIGIT($d-1)) {
+		if ($alpha) {
+		    return BADVERSION($s,$errstr,"Invalid version format (underscores before decimal)");
+		}
+		if ($strict) {
+		    return BADVERSION($s,$errstr,"Invalid version format (dotted-decimal versions must begin with 'v')");
+		}
+		$d = $s; # start all over again
+		$qv = TRUE;
+		goto dotted_decimal_version;
+	    }
+	    if ($d eq '_') {
+		if ($strict) {
+		    return BADVERSION($s,$errstr,"Invalid version format (no underscores)");
+		}
+		if ( $alpha ) {
+		    return BADVERSION($s,$errstr,"Invalid version format (multiple underscores)");
+		}
+		if ( ! isDIGIT($d+1) ) {
+		    return BADVERSION($s,$errstr,"Invalid version format (misplaced underscore)");
+		}
+		$width = $j;
+		$d++;
+		$alpha = TRUE;
+	    }
+	}
+    }
+
+version_prescan_finish:
+    while (isSPACE($d)) {
+	$d++;
+    }
+
+    if ($d && !isDIGIT($d) && (! ($d eq ';' || $d eq '}') )) {
+	# trailing non-numeric data
+	return BADVERSION($s,$errstr,"Invalid version format (non-numeric data)");
+    }
+
+    if (defined $sqv) {
+	$$sqv = $qv;
+    }
+    if (defined $swidth) {
+	$$swidth = $width;
+    }
+    if (defined $ssaw_decimal) {
+	$$ssaw_decimal = $saw_decimal;
+    }
+    if (defined $salpha) {
+	$$salpha = $alpha;
+    }
+    return $d;
+}
+
+sub scan_version {
+    my ($s, $rv, $qv) = @_;
+    my $start;
+    my $pos;
+    my $last;
+    my $errstr;
+    my $saw_decimal = 0;
+    my $width = 3;
+    my $alpha = FALSE;
+    my $vinf = FALSE;
+    my @av;
+
+    $s = new ExtUtils::MakeMaker::charstar $s;
+
+    while (isSPACE($s)) { # leading whitespace is OK
+	$s++;
+    }
+
+    $last = prescan_version($s, FALSE, \$errstr, \$qv, \$saw_decimal,
+	\$width, \$alpha);
+
+    if ($errstr) {
+	# 'undef' is a special case and not an error
+	if ( $s ne 'undef') {
+	    require Carp;
+	    Carp::croak($errstr);
+	}
+    }
+
+    $start = $s;
+    if ($s eq 'v') {
+	$s++;
+    }
+    $pos = $s;
+
+    if ( $qv ) {
+	$$rv->{qv} = $qv;
+    }
+    if ( $alpha ) {
+	$$rv->{alpha} = $alpha;
+    }
+    if ( !$qv && $width < 3 ) {
+	$$rv->{width} = $width;
+    }
+
+    while (isDIGIT($pos)) {
+	$pos++;
+    }
+    if (!isALPHA($pos)) {
+	my $rev;
+
+	for (;;) {
+	    $rev = 0;
+	    {
+  		# this is atoi() that delimits on underscores
+  		my $end = $pos;
+  		my $mult = 1;
+		my $orev;
+
+		#  the following if() will only be true after the decimal
+		#  point of a version originally created with a bare
+		#  floating point number, i.e. not quoted in any way
+		#
+ 		if ( !$qv && $s > $start && $saw_decimal == 1 ) {
+		    $mult *= 100;
+ 		    while ( $s < $end ) {
+			$orev = $rev;
+ 			$rev += $s * $mult;
+ 			$mult /= 10;
+			if (   (abs($orev) > abs($rev))
+			    || (abs($rev) > $VERSION_MAX )) {
+			    warn("Integer overflow in version %d",
+					   $VERSION_MAX);
+			    $s = $end - 1;
+			    $rev = $VERSION_MAX;
+			    $vinf = 1;
+			}
+ 			$s++;
+			if ( $s eq '_' ) {
+			    $s++;
+			}
+ 		    }
+  		}
+ 		else {
+ 		    while (--$end >= $s) {
+			$orev = $rev;
+ 			$rev += $end * $mult;
+ 			$mult *= 10;
+			if (   (abs($orev) > abs($rev))
+			    || (abs($rev) > $VERSION_MAX )) {
+			    warn("Integer overflow in version");
+			    $end = $s - 1;
+			    $rev = $VERSION_MAX;
+			    $vinf = 1;
+			}
+ 		    }
+ 		}
+  	    }
+
+  	    # Append revision
+	    push @av, $rev;
+	    if ( $vinf ) {
+		$s = $last;
+		last;
+	    }
+	    elsif ( $pos eq '.' ) {
+		$s = ++$pos;
+	    }
+	    elsif ( $pos eq '_' && isDIGIT($pos+1) ) {
+		$s = ++$pos;
+	    }
+	    elsif ( $pos eq ',' && isDIGIT($pos+1) ) {
+		$s = ++$pos;
+	    }
+	    elsif ( isDIGIT($pos) ) {
+		$s = $pos;
+	    }
+	    else {
+		$s = $pos;
+		last;
+	    }
+	    if ( $qv ) {
+		while ( isDIGIT($pos) ) {
+		    $pos++;
+		}
+	    }
+	    else {
+		my $digits = 0;
+		while ( ( isDIGIT($pos) || $pos eq '_' ) && $digits < 3 ) {
+		    if ( $pos ne '_' ) {
+			$digits++;
+		    }
+		    $pos++;
+		}
+	    }
+	}
+    }
+    if ( $qv ) { # quoted versions always get at least three terms
+	my $len = $#av;
+	#  This for loop appears to trigger a compiler bug on OS X, as it
+	#  loops infinitely. Yes, len is negative. No, it makes no sense.
+	#  Compiler in question is:
+	#  gcc version 3.3 20030304 (Apple Computer, Inc. build 1640)
+	#  for ( len = 2 - len; len > 0; len-- )
+	#  av_push(MUTABLE_AV(sv), newSViv(0));
+	#
+	$len = 2 - $len;
+	while ($len-- > 0) {
+	    push @av, 0;
+	}
+    }
+
+    # need to save off the current version string for later
+    if ( $vinf ) {
+	$$rv->{original} = "v.Inf";
+	$$rv->{vinf} = 1;
+    }
+    elsif ( $s > $start ) {
+	$$rv->{original} = $start->currstr($s);
+	if ( $qv && $saw_decimal == 1 && $start ne 'v' ) {
+	    # need to insert a v to be consistent
+	    $$rv->{original} = 'v' . $$rv->{original};
+	}
+    }
+    else {
+	$$rv->{original} = '0';
+	push(@av, 0);
+    }
+
+    # And finally, store the AV in the hash
+    $$rv->{version} = \@av;
+
+    # fix RT#19517 - special case 'undef' as string
+    if ($s eq 'undef') {
+	$s += 5;
+    }
+
+    return $s;
+}
+
+sub new {
+    my $class = shift;
+    unless (defined $class or $#_ > 1) {
+	require Carp;
+	Carp::croak('Usage: version::new(class, version)');
+    }
+
+    my $self = bless ({}, ref ($class) || $class);
+    my $qv = FALSE;
+
+    if ( $#_ == 1 ) { # must be CVS-style
+	$qv = TRUE;
+    }
+    my $value = pop; # always going to be the last element
+
+    if ( ref($value) && eval('$value->isa("version")') ) {
+	# Can copy the elements directly
+	$self->{version} = [ @{$value->{version} } ];
+	$self->{qv} = 1 if $value->{qv};
+	$self->{alpha} = 1 if $value->{alpha};
+	$self->{original} = ''.$value->{original};
+	return $self;
+    }
+
+    if ( not defined $value or $value =~ /^undef$/ ) {
+	# RT #19517 - special case for undef comparison
+	# or someone forgot to pass a value
+	push @{$self->{version}}, 0;
+	$self->{original} = "0";
+	return ($self);
+    }
+
+
+    if (ref($value) =~ m/ARRAY|HASH/) {
+	require Carp;
+	Carp::croak("Invalid version format (non-numeric data)");
+    }
+
+    $value = _un_vstring($value);
+
+    if ($Config{d_setlocale} && eval { require POSIX } ) {
+      require locale;
+	my $currlocale = POSIX::setlocale(&POSIX::LC_ALL);
+
+	# if the current locale uses commas for decimal points, we
+	# just replace commas with decimal places, rather than changing
+	# locales
+	if ( POSIX::localeconv()->{decimal_point} eq ',' ) {
+	    $value =~ tr/,/./;
+	}
+    }
+
+    # exponential notation
+    if ( $value =~ /\d+.?\d*e[-+]?\d+/ ) {
+	$value = sprintf("%.9f",$value);
+	$value =~ s/(0+)$//; # trim trailing zeros
+    }
+
+    my $s = scan_version($value, \$self, $qv);
+
+    if ($s) { # must be something left over
+	warn("Version string '%s' contains invalid data; "
+		   ."ignoring: '%s'", $value, $s);
+    }
+
+    return ($self);
+}
+
+*parse = \&new;
+
+sub numify {
+    my ($self) = @_;
+    unless (_verify($self)) {
+	require Carp;
+	Carp::croak("Invalid version object");
+    }
+    my $width = $self->{width} || 3;
+    my $alpha = $self->{alpha} || "";
+    my $len = $#{$self->{version}};
+    my $digit = $self->{version}[0];
+    my $string = sprintf("%d.", $digit );
+
+    for ( my $i = 1 ; $i < $len ; $i++ ) {
+	$digit = $self->{version}[$i];
+	if ( $width < 3 ) {
+	    my $denom = 10**(3-$width);
+	    my $quot = int($digit/$denom);
+	    my $rem = $digit - ($quot * $denom);
+	    $string .= sprintf("%0".$width."d_%d", $quot, $rem);
+	}
+	else {
+	    $string .= sprintf("%03d", $digit);
+	}
+    }
+
+    if ( $len > 0 ) {
+	$digit = $self->{version}[$len];
+	if ( $alpha && $width == 3 ) {
+	    $string .= "_";
+	}
+	$string .= sprintf("%0".$width."d", $digit);
+    }
+    else # $len = 0
+    {
+	$string .= sprintf("000");
+    }
+
+    return $string;
+}
+
+sub normal {
+    my ($self) = @_;
+    unless (_verify($self)) {
+	require Carp;
+	Carp::croak("Invalid version object");
+    }
+    my $alpha = $self->{alpha} || "";
+    my $len = $#{$self->{version}};
+    my $digit = $self->{version}[0];
+    my $string = sprintf("v%d", $digit );
+
+    for ( my $i = 1 ; $i < $len ; $i++ ) {
+	$digit = $self->{version}[$i];
+	$string .= sprintf(".%d", $digit);
+    }
+
+    if ( $len > 0 ) {
+	$digit = $self->{version}[$len];
+	if ( $alpha ) {
+	    $string .= sprintf("_%0d", $digit);
+	}
+	else {
+	    $string .= sprintf(".%0d", $digit);
+	}
+    }
+
+    if ( $len <= 2 ) {
+	for ( $len = 2 - $len; $len != 0; $len-- ) {
+	    $string .= sprintf(".%0d", 0);
+	}
+    }
+
+    return $string;
+}
+
+sub stringify {
+    my ($self) = @_;
+    unless (_verify($self)) {
+	require Carp;
+	Carp::croak("Invalid version object");
+    }
+    return exists $self->{original}
+    	? $self->{original}
+	: exists $self->{qv}
+	    ? $self->normal
+	    : $self->numify;
+}
+
+sub vcmp {
+    require UNIVERSAL;
+    my ($left,$right,$swap) = @_;
+    my $class = ref($left);
+    unless ( UNIVERSAL::isa($right, $class) ) {
+	$right = $class->new($right);
+    }
+
+    if ( $swap ) {
+	($left, $right) = ($right, $left);
+    }
+    unless (_verify($left)) {
+	require Carp;
+	Carp::croak("Invalid version object");
+    }
+    unless (_verify($right)) {
+	require Carp;
+	Carp::croak("Invalid version format");
+    }
+    my $l = $#{$left->{version}};
+    my $r = $#{$right->{version}};
+    my $m = $l < $r ? $l : $r;
+    my $lalpha = $left->is_alpha;
+    my $ralpha = $right->is_alpha;
+    my $retval = 0;
+    my $i = 0;
+    while ( $i <= $m && $retval == 0 ) {
+	$retval = $left->{version}[$i] <=> $right->{version}[$i];
+	$i++;
+    }
+
+    # tiebreaker for alpha with identical terms
+    if ( $retval == 0
+	&& $l == $r
+	&& $left->{version}[$m] == $right->{version}[$m]
+	&& ( $lalpha || $ralpha ) ) {
+
+	if ( $lalpha && !$ralpha ) {
+	    $retval = -1;
+	}
+	elsif ( $ralpha && !$lalpha) {
+	    $retval = +1;
+	}
+    }
+
+    # possible match except for trailing 0's
+    if ( $retval == 0 && $l != $r ) {
+	if ( $l < $r ) {
+	    while ( $i <= $r && $retval == 0 ) {
+		if ( $right->{version}[$i] != 0 ) {
+		    $retval = -1; # not a match after all
+		}
+		$i++;
+	    }
+	}
+	else {
+	    while ( $i <= $l && $retval == 0 ) {
+		if ( $left->{version}[$i] != 0 ) {
+		    $retval = +1; # not a match after all
+		}
+		$i++;
+	    }
+	}
+    }
+
+    return $retval;
+}
+
+sub vbool {
+    my ($self) = @_;
+    return vcmp($self,$self->new("0"),1);
+}
+
+sub vnoop {
+    require Carp;
+    Carp::croak("operation not supported with version object");
+}
+
+sub is_alpha {
+    my ($self) = @_;
+    return (exists $self->{alpha});
+}
+
+sub qv {
+    my $value = shift;
+    my $class = $CLASS;
+    if (@_) {
+	$class = ref($value) || $value;
+	$value = shift;
+    }
+
+    $value = _un_vstring($value);
+    $value = 'v'.$value unless $value =~ /(^v|\d+\.\d+\.\d)/;
+    my $obj = $CLASS->new($value);
+    return bless $obj, $class;
+}
+
+*declare = \&qv;
+
+sub is_qv {
+    my ($self) = @_;
+    return (exists $self->{qv});
+}
+
+
+sub _verify {
+    my ($self) = @_;
+    if ( ref($self)
+	&& eval { exists $self->{version} }
+	&& ref($self->{version}) eq 'ARRAY'
+	) {
+	return 1;
+    }
+    else {
+	return 0;
+    }
+}
+
+sub _is_non_alphanumeric {
+    my $s = shift;
+    $s = new ExtUtils::MakeMaker::charstar $s;
+    while ($s) {
+	return 0 if isSPACE($s); # early out
+	return 1 unless (isALPHA($s) || isDIGIT($s) || $s =~ /[.-]/);
+	$s++;
+    }
+    return 0;
+}
+
+sub _un_vstring {
+    my $value = shift;
+    # may be a v-string
+    if ( length($value) >= 3 && $value !~ /[._]/
+	&& _is_non_alphanumeric($value)) {
+	my $tvalue;
+	if ( $] ge 5.008_001 ) {
+	    $tvalue = _find_magic_vstring($value);
+	    $value = $tvalue if length $tvalue;
+	}
+	elsif ( $] ge 5.006_000 ) {
+	    $tvalue = sprintf("v%vd",$value);
+	    if ( $tvalue =~ /^v\d+(\.\d+){2,}$/ ) {
+		# must be a v-string
+		$value = $tvalue;
+	    }
+	}
+    }
+    return $value;
+}
+
+sub _find_magic_vstring {
+    my $value = shift;
+    my $tvalue = '';
+    require B;
+    my $sv = B::svref_2object(\$value);
+    my $magic = ref($sv) eq 'B::PVMG' ? $sv->MAGIC : undef;
+    while ( $magic ) {
+	if ( $magic->TYPE eq 'V' ) {
+	    $tvalue = $magic->PTR;
+	    $tvalue =~ s/^v?(.+)$/v$1/;
+	    last;
+	}
+	else {
+	    $magic = $magic->MOREMAGIC;
+	}
+    }
+    return $tvalue;
+}
+
+sub _VERSION {
+    my ($obj, $req) = @_;
+    my $class = ref($obj) || $obj;
+
+    no strict 'refs';
+    if ( exists $INC{"$class.pm"} and not %{"$class\::"} and $] >= 5.008) {
+	 # file but no package
+	require Carp;
+	Carp::croak( "$class defines neither package nor VERSION"
+	    ."--version check failed");
+    }
+
+    my $version = eval "\$$class\::VERSION";
+    if ( defined $version ) {
+	local $^W if $] <= 5.008;
+	$version = ExtUtils::MakeMaker::version::vpp->new($version);
+    }
+
+    if ( defined $req ) {
+	unless ( defined $version ) {
+	    require Carp;
+	    my $msg =  $] < 5.006
+	    ? "$class version $req required--this is only version "
+	    : "$class does not define \$$class\::VERSION"
+	      ."--version check failed";
+
+	    if ( $ENV{VERSION_DEBUG} ) {
+		Carp::confess($msg);
+	    }
+	    else {
+		Carp::croak($msg);
+	    }
+	}
+
+	$req = ExtUtils::MakeMaker::version::vpp->new($req);
+
+	if ( $req > $version ) {
+	    require Carp;
+	    if ( $req->is_qv ) {
+		Carp::croak(
+		    sprintf ("%s version %s required--".
+			"this is only version %s", $class,
+			$req->normal, $version->normal)
+		);
+	    }
+	    else {
+		Carp::croak(
+		    sprintf ("%s version %s required--".
+			"this is only version %s", $class,
+			$req->stringify, $version->stringify)
+		);
+	    }
+	}
+    }
+
+    return defined $version ? $version->stringify : undef;
+}
+
+1; #this line is important and will help the module return a true value
--- cpan/ExtUtils-MakeMaker/lib/ExtUtils/Mkbootstrap.pm
+++ cpan/ExtUtils-MakeMaker/lib/ExtUtils/Mkbootstrap.pm
@@ -3,7 +3,7 @@ package ExtUtils::Mkbootstrap;
 # There's just too much Dynaloader incest here to turn on strict vars.
 use strict 'refs';
 
-our $VERSION = '6.98';
+our $VERSION = '7.04_01';
 
 require Exporter;
 our @ISA = ('Exporter');
--- cpan/ExtUtils-MakeMaker/lib/ExtUtils/Mksymlists.pm
+++ cpan/ExtUtils-MakeMaker/lib/ExtUtils/Mksymlists.pm
@@ -10,7 +10,7 @@ use Config;
 
 our @ISA = qw(Exporter);
 our @EXPORT = qw(&Mksymlists);
-our $VERSION = '6.98';
+our $VERSION = '7.04_01';
 
 sub Mksymlists {
     my(%spec) = @_;
@@ -141,19 +141,24 @@ sub _write_win32 {
     print $def "EXPORTS\n  ";
     my @syms;
     # Export public symbols both with and without underscores to
-    # ensure compatibility between DLLs from different compilers
+    # ensure compatibility between DLLs from Borland C and Visual C
     # NOTE: DynaLoader itself only uses the names without underscores,
     # so this is only to cover the case when the extension DLL may be
     # linked to directly from C. GSAR 97-07-10
-    if ($Config::Config{'cc'} =~ /^bcc/i) {
-        for (@{$data->{DL_VARS}}, @{$data->{FUNCLIST}}) {
-            push @syms, "_$_", "$_ = _$_";
+
+    #bcc dropped in 5.16, so dont create useless extra symbols for export table
+    unless($] >= 5.016) {
+        if ($Config::Config{'cc'} =~ /^bcc/i) {
+            push @syms, "_$_", "$_ = _$_"
+                for (@{$data->{DL_VARS}}, @{$data->{FUNCLIST}});
         }
-    }
-    else {
-        for (@{$data->{DL_VARS}}, @{$data->{FUNCLIST}}) {
-            push @syms, "$_", "_$_ = $_";
+        else {
+            push @syms, "$_", "_$_ = $_"
+                for (@{$data->{DL_VARS}}, @{$data->{FUNCLIST}});
         }
+    } else {
+        push @syms, "$_"
+            for (@{$data->{DL_VARS}}, @{$data->{FUNCLIST}});
     }
     print $def join("\n  ",@syms, "\n") if @syms;
     _print_imports($def, $data);
--- cpan/ExtUtils-MakeMaker/lib/ExtUtils/testlib.pm
+++ cpan/ExtUtils-MakeMaker/lib/ExtUtils/testlib.pm
@@ -3,7 +3,7 @@ package ExtUtils::testlib;
 use strict;
 use warnings;
 
-our $VERSION = '6.98';
+our $VERSION = '7.04_01';
 
 use Cwd;
 use File::Spec;
--- /dev/null
+++ cpan/ExtUtils-MakeMaker/t/lib/MakeMaker/Test/Setup/Unicode.pm
@@ -0,0 +1,90 @@
+package MakeMaker::Test::Setup::Unicode;
+
+@ISA = qw(Exporter);
+require Exporter;
+@EXPORT = qw(setup_recurs teardown_recurs);
+
+use strict;
+use File::Path;
+use File::Basename;
+use MakeMaker::Test::Utils;
+use utf8;
+use Config;
+
+my %Files = (
+             'Problem-Module/Makefile.PL'   => <<'PL_END',
+use ExtUtils::MakeMaker;
+use utf8;
+
+WriteMakefile(
+    NAME          => 'Problem::Module',
+    ABSTRACT_FROM => 'lib/Problem/Module.pm',
+    AUTHOR        => q{Danijel Tašov},
+    EXE_FILES     => [ qw(bin/probscript) ],
+    INSTALLMAN1DIR => "some", # even if disabled in $Config{man1dir}
+    MAN1EXT       => 1, # set to 0 if man pages disabled
+);
+PL_END
+
+            'Problem-Module/lib/Problem/Module.pm'  => <<'pm_END',
+use utf8;
+
+=pod
+
+=encoding utf8
+
+=head1 NAME
+
+Problem::Module - Danijel Tašov's great new module
+
+=cut
+
+1;
+pm_END
+
+            'Problem-Module/bin/probscript'  => <<'pl_END',
+#!/usr/bin/perl
+use utf8;
+
+=encoding utf8
+
+=head1 NAME
+
+文档 - Problem script
+pl_END
+);
+
+
+sub setup_recurs {
+    while(my($file, $text) = each %Files) {
+        # Convert to a relative, native file path.
+        $file = File::Spec->catfile(File::Spec->curdir, split m{\/}, $file);
+
+        my $dir = dirname($file);
+        mkpath $dir;
+        my $utf8 = ($] < 5.008 or !$Config{useperlio}) ? "" : ":utf8";
+        open(FILE, ">$utf8", $file) || die "Can't create $file: $!";
+        print FILE $text;
+        close FILE;
+
+        # ensure file at least 1 second old for makes that assume
+        # files with the same time are out of date.
+        my $time = calibrate_mtime();
+        utime $time, $time - 1, $file;
+    }
+
+    return 1;
+}
+
+sub teardown_recurs {
+    foreach my $file (keys %Files) {
+        my $dir = dirname($file);
+        if( -e $dir ) {
+            rmtree($dir) || return;
+        }
+    }
+    return 1;
+}
+
+
+1;
--- cpan/ExtUtils-MakeMaker/t/lib/MakeMaker/Test/Setup/XS.pm
+++ cpan/ExtUtils-MakeMaker/t/lib/MakeMaker/Test/Setup/XS.pm
@@ -8,8 +8,11 @@ use strict;
 use File::Path;
 use File::Basename;
 use MakeMaker::Test::Utils;
+use Config;
 
-my $Is_VMS = $^O eq 'VMS';
+use ExtUtils::MM;
+my $typemap = 'type map';
+$typemap =~ s/ //g unless MM->new({NAME=>'name'})->can_dep_space;
 
 my %Files = (
              'XS-Test/lib/XS/Test.pm'     => <<'END',
@@ -27,15 +30,19 @@ bootstrap XS::Test $VERSION;
 1;
 END
 
-             'XS-Test/Makefile.PL'          => <<'END',
+             'XS-Test/Makefile.PL'          => <<END,
 use ExtUtils::MakeMaker;
 
 WriteMakefile(
     NAME          => 'XS::Test',
     VERSION_FROM  => 'lib/XS/Test.pm',
+    TYPEMAPS      => [ '$typemap' ],
+    PERL          => "\$^X -w",
 );
 END
 
+             "XS-Test/$typemap"             => '',
+
              'XS-Test/Test.xs'              => <<'END',
 #include "EXTERN.h"
 #include "perl.h"
--- cpan/ExtUtils-MakeMaker/t/lib/MakeMaker/Test/Utils.pm
+++ cpan/ExtUtils-MakeMaker/t/lib/MakeMaker/Test/Utils.pm
@@ -30,6 +30,7 @@ our @EXPORT = qw(which_perl perl_lib makefile_name makefile_backup
         HARNESS_VERBOSE
         PREFIX
         MAKEFLAGS
+        PERL_INSTALL_QUIET
     );
 
     my %default_env_keys;
@@ -97,7 +98,7 @@ MakeMaker::Test::Utils - Utility routines for testing MakeMaker
 
 =head1 DESCRIPTION
 
-A consolidation of little utility functions used through out the
+A consolidation of little utility functions used throughout the
 MakeMaker test suite.
 
 =head2 Functions
@@ -138,6 +139,7 @@ sub which_perl {
             last if -x $perlpath;
         }
     }
+    $perlpath = qq{"$perlpath"}; # "safe... in a command line" even with spaces
 
     return $perlpath;
 }
@@ -213,7 +215,7 @@ sub make {
     my $make = $Config{make};
     $make = $ENV{MAKE} if exists $ENV{MAKE};
 
-    return $make;
+    return $Is_VMS ? $make : qq{"$make"};
 }
 
 =item B<make_run>
@@ -304,10 +306,7 @@ sub run {
 
     # Unix, modern Windows and OS/2 from 5.005_54 up can handle 2>&1
     # This makes our failure diagnostics nicer to read.
-    if( MM->os_flavor_is('Unix')                                   or
-        (MM->os_flavor_is('Win32') and !MM->os_flavor_is('Win9x')) or
-        ($] > 5.00554 and MM->os_flavor_is('OS/2'))
-      ) {
+    if (MM->can_redirect_error) {
         return `$cmd 2>&1`;
     }
     else {
--- ext/DynaLoader/DynaLoader_pm.PL
+++ ext/DynaLoader/DynaLoader_pm.PL
@@ -85,7 +85,7 @@ package DynaLoader;
 # Tim.Bunce@ig.co.uk, August 1994
 
 BEGIN {
-    $VERSION = '1.25';
+    $VERSION = '1.32';
 }
 
 use Config;
@@ -578,7 +578,7 @@ anyone wishing to use the DynaLoader directly in an application.
 
 The DynaLoader is designed to be a very simple high-level
 interface that is sufficiently general to cover the requirements
-of SunOS, HP-UX, NeXT, Linux, VMS and other platforms.
+of SunOS, HP-UX, Linux, VMS and other platforms.
 
 It is also hoped that the interface will cover the needs of OS/2, NT
 etc and also allow pseudo-dynamic linking (using C<ld -A> at runtime).
@@ -796,7 +796,6 @@ current values of @dl_require_symbols and @dl_resolve_using if required.
     SunOS: dlopen($filename)
     HP-UX: shl_load($filename)
     Linux: dld_create_reference(@dl_require_symbols); dld_link($filename)
-    NeXT:  rld_load($filename, @dl_resolve_using)
     VMS:   lib$find_image_symbol($filename,$dl_require_symbols[0])
 
 (The dlopen() function is also used by Solaris and some versions of
@@ -833,7 +832,6 @@ Apache and mod_perl built with the APXS mechanism.
     SunOS: dlclose($libref)
     HP-UX: ???
     Linux: ???
-    NeXT:  ???
     VMS:   ???
 
 (The dlclose() function is also used by Solaris and some versions of
@@ -869,7 +867,6 @@ be passed to, and understood by, dl_install_xsub().
     SunOS: dlsym($libref, $symbol)
     HP-UX: shl_findsym($libref, $symbol)
     Linux: dld_get_func($symbol) and/or dld_get_symbol($symbol)
-    NeXT:  rld_lookup("_$symbol")
     VMS:   lib$find_image_symbol($libref,$symbol)
 
 
--- ext/DynaLoader/Makefile.PL
+++ ext/DynaLoader/Makefile.PL
@@ -14,7 +14,8 @@ WriteMakefile(
     VERSION_FROM => 'DynaLoader_pm.PL',
     PL_FILES	=> {'DynaLoader_pm.PL'=>'DynaLoader.pm'},
     PM		=> {'DynaLoader.pm' => '$(INST_LIBDIR)/DynaLoader.pm'},
-    depend      => {'DynaLoader$(OBJ_EXT)' => 'dlutils.c'},
+    depend      => {	'DynaLoader$(OBJ_EXT)' => 'dlutils.c',
+			'DynaLoader.c' => 'DynaLoader.xs'},
     clean	=> {FILES => 'DynaLoader.c DynaLoader.xs DynaLoader.pm'},
 );
 
--- ext/DynaLoader/dl_aix.xs
+++ ext/DynaLoader/dl_aix.xs
@@ -12,6 +12,7 @@
  */
 
 #define PERLIO_NOT_STDIO 0
+#define PERL_EXT
 
 /*
  * On AIX 4.3 and above the emulation layer is not needed any more, and
@@ -759,11 +760,11 @@ dl_install_xsub(perl_name, symref, filename="$Package")
 					      XS_DYNAMIC_FILENAME)));
 
 
-char *
+SV *
 dl_error()
     CODE:
     dMY_CXT;
-    RETVAL = dl_last_error ;
+    RETVAL = newSVsv(MY_CXT.x_dl_last_error);
     OUTPUT:
     RETVAL
 
@@ -780,7 +781,7 @@ CLONE(...)
      * using Perl variables that belong to another thread, we create our 
      * own for this thread.
      */
-    MY_CXT.x_dl_last_error = newSVpvn("", 0);
+    MY_CXT.x_dl_last_error = newSVpvs("");
 
 #endif
 
--- ext/DynaLoader/dl_dllload.xs
+++ ext/DynaLoader/dl_dllload.xs
@@ -84,6 +84,7 @@
    Other comments within the dl_dlopen.xs file may be helpful as well.
 */
 
+#define PERL_EXT
 #include "EXTERN.h"
 #include "perl.h"
 #include "XSUB.h"
@@ -184,11 +185,11 @@ dl_install_xsub(perl_name, symref, filename="$Package")
     XSRETURN(1);
 
 
-char *
+SV *
 dl_error()
     CODE:
     dMY_CXT;
-    RETVAL = dl_last_error ;
+    RETVAL = newSVsv(MY_CXT.x_dl_last_error);
     OUTPUT:
     RETVAL
 
@@ -205,7 +206,7 @@ CLONE(...)
      * using Perl variables that belong to another thread, we create our 
      * own for this thread.
      */
-    MY_CXT.x_dl_last_error = newSVpvn("", 0);
+    MY_CXT.x_dl_last_error = newSVpvs("");
 
 #endif
 
--- ext/DynaLoader/dl_dlopen.xs
+++ ext/DynaLoader/dl_dlopen.xs
@@ -117,8 +117,10 @@
 */
 
 #define PERL_NO_GET_CONTEXT
+#define PERL_EXT
 
 #include "EXTERN.h"
+#define PERL_IN_DL_DLOPEN_XS
 #include "perl.h"
 #include "XSUB.h"
 
@@ -258,11 +260,11 @@ dl_install_xsub(perl_name, symref, filename="$Package")
 					      XS_DYNAMIC_FILENAME)));
 
 
-char *
+SV *
 dl_error()
     CODE:
     dMY_CXT;
-    RETVAL = dl_last_error ;
+    RETVAL = newSVsv(MY_CXT.x_dl_last_error);
     OUTPUT:
     RETVAL
 
@@ -279,7 +281,7 @@ CLONE(...)
      * using Perl variables that belong to another thread, we create our 
      * own for this thread.
      */
-    MY_CXT.x_dl_last_error = newSVpvn("", 0);
+    MY_CXT.x_dl_last_error = newSVpvs("");
 
 #endif
 
--- ext/DynaLoader/dl_dyld.xs
+++ ext/DynaLoader/dl_dyld.xs
@@ -39,6 +39,7 @@ been tested on NeXT platforms.
 
 */
 
+#define PERL_EXT
 #include "EXTERN.h"
 #include "perl.h"
 #include "XSUB.h"
@@ -213,11 +214,11 @@ dl_install_xsub(perl_name, symref, filename="$Package")
 					      XS_DYNAMIC_FILENAME)));
 
 
-char *
+SV *
 dl_error()
     CODE:
     dMY_CXT;
-    RETVAL = dl_last_error ;
+    RETVAL = newSVsv(MY_CXT.x_dl_last_error);
     OUTPUT:
     RETVAL
 
@@ -234,7 +235,7 @@ CLONE(...)
      * using Perl variables that belong to another thread, we create our 
      * own for this thread.
      */
-    MY_CXT.x_dl_last_error = newSVpvn("", 0);
+    MY_CXT.x_dl_last_error = newSVpvs("");
 
 #endif
 
--- ext/DynaLoader/dl_freemint.xs
+++ ext/DynaLoader/dl_freemint.xs
@@ -37,6 +37,7 @@
  *
  */
 
+#define PERL_EXT
 #include "EXTERN.h"
 #include "perl.h"
 #include "XSUB.h"
@@ -191,12 +192,11 @@ dl_install_xsub(perl_name, symref, filename="$Package")
 					      XS_DYNAMIC_FILENAME)));
     XSRETURN(1);
 
-char *
+SV *
 dl_error()
-    PREINIT:
-    dMY_CXT;
     CODE:
-    RETVAL = dl_last_error ;
+    dMY_CXT;
+    RETVAL = newSVsv(MY_CXT.x_dl_last_error);
     OUTPUT:
     RETVAL
 
@@ -211,7 +211,7 @@ CLONE(...)
      * using Perl variables that belong to another thread, we create our
      * own for this thread.
      */
-    MY_CXT.x_dl_last_error = newSVpvn("", 0);
+    MY_CXT.x_dl_last_error = newSVpvs("");
     dl_resolve_using   = get_av("DynaLoader::dl_resolve_using", GV_ADDMULTI);
     dl_require_symbols = get_av("DynaLoader::dl_require_symbols", GV_ADDMULTI);
 
--- ext/DynaLoader/dl_hpux.xs
+++ ext/DynaLoader/dl_hpux.xs
@@ -22,7 +22,9 @@
 #undef MAGIC
 #endif
 
+#define PERL_EXT
 #include "EXTERN.h"
+#define PERL_IN_DL_HPUX_XS
 #include "perl.h"
 #include "XSUB.h"
 
@@ -93,7 +95,7 @@ dl_load_file(filename, flags=0)
     DLDEBUG(1,PerlIO_printf(Perl_debug_log, "dl_load_file(%s): ", filename));
     obj = shl_load(filename, bind_type, 0L);
 
-    DLDEBUG(2,PerlIO_printf(Perl_debug_log, " libref=%x\n", obj));
+    DLDEBUG(2,PerlIO_printf(Perl_debug_log, " libref=%p\n", (void*)obj));
 end:
     ST(0) = sv_newmortal() ;
     if (obj == NULL)
@@ -107,7 +109,7 @@ dl_unload_file(libref)
     void *	libref
   CODE:
     DLDEBUG(1,PerlIO_printf(Perl_debug_log, "dl_unload_file(%lx):\n", PTR2ul(libref)));
-    RETVAL = (shl_unload(libref) == 0 ? 1 : 0);
+    RETVAL = (shl_unload((shl_t)libref) == 0 ? 1 : 0);
     if (!RETVAL)
 	SaveError(aTHX_ "%s", Strerror(errno));
     DLDEBUG(2,PerlIO_printf(Perl_debug_log, " retval = %d\n", RETVAL));
@@ -135,11 +137,11 @@ dl_find_symbol(libhandle, symbolname)
     errno = 0;
 
     status = shl_findsym(&obj, symbolname, TYPE_PROCEDURE, &symaddr);
-    DLDEBUG(2,PerlIO_printf(Perl_debug_log, "  symbolref(PROCEDURE) = %x\n", symaddr));
+    DLDEBUG(2,PerlIO_printf(Perl_debug_log, "  symbolref(PROCEDURE) = %p\n", (void*)symaddr));
 
     if (status == -1 && errno == 0) {	/* try TYPE_DATA instead */
 	status = shl_findsym(&obj, symbolname, TYPE_DATA, &symaddr);
-	DLDEBUG(2,PerlIO_printf(Perl_debug_log, "  symbolref(DATA) = %x\n", symaddr));
+	DLDEBUG(2,PerlIO_printf(Perl_debug_log, "  symbolref(DATA) = %p\n", (void*)symaddr));
     }
 
     if (status == -1) {
@@ -163,18 +165,18 @@ dl_install_xsub(perl_name, symref, filename="$Package")
     void *	symref 
     const char *	filename
     CODE:
-    DLDEBUG(2,PerlIO_printf(Perl_debug_log, "dl_install_xsub(name=%s, symref=%x)\n",
-	    perl_name, symref));
+    DLDEBUG(2,PerlIO_printf(Perl_debug_log, "dl_install_xsub(name=%s, symref=%p)\n",
+                            perl_name, (void*)symref));
     ST(0) = sv_2mortal(newRV((SV*)newXS_flags(perl_name,
 					      (void(*)(pTHX_ CV *))symref,
 					      filename, NULL,
 					      XS_DYNAMIC_FILENAME)));
 
-char *
+SV *
 dl_error()
     CODE:
     dMY_CXT;
-    RETVAL = dl_last_error ;
+    RETVAL = newSVsv(MY_CXT.x_dl_last_error);
     OUTPUT:
     RETVAL
 
@@ -191,7 +193,7 @@ CLONE(...)
      * using Perl variables that belong to another thread, we create our 
      * own for this thread.
      */
-    MY_CXT.x_dl_last_error = newSVpvn("", 0);
+    MY_CXT.x_dl_last_error = newSVpvs("");
     dl_resolve_using = get_av("DynaLoader::dl_resolve_using", GV_ADDMULTI);
 
 #endif
--- ext/DynaLoader/dl_none.xs
+++ ext/DynaLoader/dl_none.xs
@@ -3,6 +3,7 @@
  * Stubs for platforms that do not support dynamic linking
  */
 
+#define PERL_EXT
 #include "EXTERN.h"
 #include "perl.h"
 #include "XSUB.h"
--- ext/DynaLoader/dl_symbian.xs
+++ ext/DynaLoader/dl_symbian.xs
@@ -26,6 +26,7 @@
  * trouble because of Symbian's New(), Copy(), etc definitions. */
 
 #define DL_SYMBIAN_XS
+#define PERL_EXT
 
 #include "EXTERN.h"
 #include "perl.h"
@@ -213,11 +214,11 @@ dl_install_xsub(perl_name, symref, filename="$Package")
 					      XS_DYNAMIC_FILENAME)));
 
 
-char *
+SV *
 dl_error()
     CODE:
     dMY_CXT;
-    RETVAL = dl_last_error;
+    RETVAL = newSVsv(MY_CXT.x_dl_last_error);
     OUTPUT:
     RETVAL
 
@@ -234,7 +235,7 @@ CLONE(...)
      * using Perl variables that belong to another thread, we create our 
      * own for this thread.
      */
-    MY_CXT.x_dl_last_error = newSVpvn("", 0);
+    MY_CXT.x_dl_last_error = newSVpvs("");
 
 #endif
 
--- ext/DynaLoader/dl_vms.xs
+++ ext/DynaLoader/dl_vms.xs
@@ -45,6 +45,7 @@
  *
  */
 
+#define PERL_EXT
 #include "EXTERN.h"
 #include "perl.h"
 #include "XSUB.h"
@@ -347,13 +348,13 @@ dl_install_xsub(perl_name, symref, filename="$Package")
 					      XS_DYNAMIC_FILENAME)));
 
 
-char *
+SV *
 dl_error()
     CODE:
     dMY_CXT;
-    RETVAL = dl_last_error ;
+    RETVAL = newSVsv(MY_CXT.x_dl_last_error);
     OUTPUT:
-      RETVAL
+    RETVAL
 
 #if defined(USE_ITHREADS)
 
@@ -368,9 +369,18 @@ CLONE(...)
      * using Perl variables that belong to another thread, we create our 
      * own for this thread.
      */
-    MY_CXT.x_dl_last_error = newSVpvn("", 0);
+    MY_CXT.x_dl_last_error = newSVpvs("");
     dl_require_symbols = get_av("DynaLoader::dl_require_symbols", GV_ADDMULTI);
 
+    /* Set up the "static" control blocks for dl_expand_filespec() */
+    dl_fab = cc$rms_fab;
+    dl_nam = cc$rms_nam;
+    dl_fab.fab$l_nam = &dl_nam;
+    dl_nam.nam$l_esa = dl_esa;
+    dl_nam.nam$b_ess = sizeof dl_esa;
+    dl_nam.nam$l_rsa = dl_rsa;
+    dl_nam.nam$b_rss = sizeof dl_rsa;
+
 #endif
 
 # end.
--- ext/DynaLoader/dl_win32.xs
+++ ext/DynaLoader/dl_win32.xs
@@ -25,6 +25,7 @@ calls.
 #include <string.h>
 
 #define PERL_NO_GET_CONTEXT
+#define PERL_EXT
 
 #include "EXTERN.h"
 #include "perl.h"
@@ -47,10 +48,13 @@ OS_Error_String(pTHX)
     dMY_CXT;
     DWORD err = GetLastError();
     STRLEN len;
-    if (!dl_error_sv)
-	dl_error_sv = newSVpvn("",0);
-    PerlProc_GetOSError(dl_error_sv,err);
-    return SvPV(dl_error_sv,len);
+    SV ** l_dl_error_svp = &dl_error_sv;
+    SV * l_dl_error_sv;
+    if (!*l_dl_error_svp)
+	*l_dl_error_svp = newSVpvs("");
+    l_dl_error_sv = *l_dl_error_svp;
+    PerlProc_GetOSError(l_dl_error_sv,err);
+    return SvPV(l_dl_error_sv,len);
 }
 
 static void
@@ -114,11 +118,14 @@ BOOT:
 void
 dl_load_file(filename,flags=0)
     char *		filename
-    int			flags
+#flags is unused
+    SV *		flags = NO_INIT
     PREINIT:
     void *retv;
+    SV * retsv;
     CODE:
   {
+    PERL_UNUSED_VAR(flags);
     DLDEBUG(1,PerlIO_printf(Perl_debug_log,"dl_load_file(%s):\n", filename));
     if (dl_static_linked(filename) == 0) {
 	retv = PerlProc_DynaLoad(filename);
@@ -126,12 +133,15 @@ dl_load_file(filename,flags=0)
     else
 	retv = (void*) Win_GetModuleHandle(NULL);
     DLDEBUG(2,PerlIO_printf(Perl_debug_log," libref=%x\n", retv));
-    ST(0) = sv_newmortal() ;
-    if (retv == NULL)
+
+    if (retv == NULL) {
 	SaveError(aTHX_ "load_file:%s",
 		  OS_Error_String(aTHX)) ;
+	retsv = &PL_sv_undef;
+    }
     else
-	sv_setiv( ST(0), (IV)retv);
+	retsv = sv_2mortal(newSViv((IV)retv));
+    ST(0) = retsv;
   }
 
 int
@@ -139,7 +149,7 @@ dl_unload_file(libref)
     void *	libref
   CODE:
     DLDEBUG(1,PerlIO_printf(Perl_debug_log, "dl_unload_file(%lx):\n", PTR2ul(libref)));
-    RETVAL = FreeLibrary(libref);
+    RETVAL = FreeLibrary((HMODULE)libref);
     if (!RETVAL)
         SaveError(aTHX_ "unload_file:%s", OS_Error_String(aTHX)) ;
     DLDEBUG(2,PerlIO_printf(Perl_debug_log, " retval = %d\n", RETVAL));
@@ -186,11 +196,11 @@ dl_install_xsub(perl_name, symref, filename="$Package")
 					filename)));
 
 
-char *
+SV *
 dl_error()
     CODE:
     dMY_CXT;
-    RETVAL = dl_last_error;
+    RETVAL = newSVsv(MY_CXT.x_dl_last_error);
     OUTPUT:
     RETVAL
 
@@ -207,7 +217,7 @@ CLONE(...)
      * using Perl variables that belong to another thread, we create our 
      * own for this thread.
      */
-    MY_CXT.x_dl_last_error = newSVpvn("", 0);
+    MY_CXT.x_dl_last_error = newSVpvs("");
 
 #endif
 
--- ext/DynaLoader/dlutils.c
+++ ext/DynaLoader/dlutils.c
@@ -10,6 +10,7 @@
 
 #define PERL_EUPXS_ALWAYS_EXPORT
 #ifndef START_MY_CXT /* Some IDEs try compiling this standalone. */
+#   define PERL_EXT
 #   include "EXTERN.h"
 #   include "perl.h"
 #   include "XSUB.h"
@@ -20,11 +21,17 @@
 #endif
 #define MY_CXT_KEY "DynaLoader::_guts" XS_VERSION
 
+/* disable version checking since DynaLoader can't be DynaLoaded */
+#undef dXSBOOTARGSXSAPIVERCHK
+#define dXSBOOTARGSXSAPIVERCHK dXSBOOTARGSNOVERCHK
+
 typedef struct {
     SV*		x_dl_last_error;	/* pointer to allocated memory for
 					   last error message */
+#if defined(PERL_IN_DL_HPUX_XS) || defined(PERL_IN_DL_DLOPEN_XS)
     int		x_dl_nonlazy;		/* flag for immediate rather than lazy
 					   linking (spots unresolved symbol) */
+#endif
 #ifdef DL_LOADONCEONLY
     HV *	x_dl_loaded_files;	/* only needed on a few systems */
 #endif
@@ -39,7 +46,9 @@ typedef struct {
 START_MY_CXT
 
 #define dl_last_error	(SvPVX(MY_CXT.x_dl_last_error))
+#if defined(PERL_IN_DL_HPUX_XS) || defined(PERL_IN_DL_DLOPEN_XS)
 #define dl_nonlazy	(MY_CXT.x_dl_nonlazy)
+#endif
 #ifdef DL_LOADONCEONLY
 #define dl_loaded_files	(MY_CXT.x_dl_loaded_files)
 #endif
@@ -71,12 +80,13 @@ dl_unload_all_files(pTHX_ void *unused)
 
     if ((sub = get_cvs("DynaLoader::dl_unload_file", 0)) != NULL) {
         dl_librefs = get_av("DynaLoader::dl_librefs", 0);
+        EXTEND(SP,1);
         while ((dl_libref = av_pop(dl_librefs)) != &PL_sv_undef) {
            dSP;
            ENTER;
            SAVETMPS;
            PUSHMARK(SP);
-           XPUSHs(sv_2mortal(dl_libref));
+           PUSHs(sv_2mortal(dl_libref));
            PUTBACK;
            call_sv((SV*)sub, G_DISCARD | G_NODEBUG);
            FREETMPS;
@@ -89,11 +99,13 @@ dl_unload_all_files(pTHX_ void *unused)
 static void
 dl_generic_private_init(pTHX)	/* called by dl_*.xs dl_private_init() */
 {
+#if defined(PERL_IN_DL_HPUX_XS) || defined(PERL_IN_DL_DLOPEN_XS)
     char *perl_dl_nonlazy;
+    UV uv;
+#endif
     MY_CXT_INIT;
 
-    MY_CXT.x_dl_last_error = newSVpvn("", 0);
-    dl_nonlazy = 0;
+    MY_CXT.x_dl_last_error = newSVpvs("");
 #ifdef DL_LOADONCEONLY
     dl_loaded_files = NULL;
 #endif
@@ -103,10 +115,18 @@ dl_generic_private_init(pTHX)	/* called by dl_*.xs dl_private_init() */
 	dl_debug = sv ? SvIV(sv) : 0;
     }
 #endif
-    if ( (perl_dl_nonlazy = getenv("PERL_DL_NONLAZY")) != NULL )
-	dl_nonlazy = atoi(perl_dl_nonlazy);
+
+#if defined(PERL_IN_DL_HPUX_XS) || defined(PERL_IN_DL_DLOPEN_XS)
+    if ( (perl_dl_nonlazy = getenv("PERL_DL_NONLAZY")) != NULL
+	&& grok_atoUV(perl_dl_nonlazy, &uv, NULL)
+	&& uv <= INT_MAX
+    ) {
+	dl_nonlazy = (int)uv;
+    } else
+	dl_nonlazy = 0;
     if (dl_nonlazy)
 	DLDEBUG(1,PerlIO_printf(Perl_debug_log, "DynaLoader bind mode is 'non-lazy'\n"));
+#endif
 #ifdef DL_LOADONCEONLY
     if (!dl_loaded_files)
 	dl_loaded_files = newHV(); /* provide cache for dl_*.xs if needed */
@@ -122,7 +142,6 @@ dl_generic_private_init(pTHX)	/* called by dl_*.xs dl_private_init() */
 static void
 SaveError(pTHX_ const char* pat, ...)
 {
-    dMY_CXT;
     va_list args;
     SV *msv;
     const char *message;
@@ -137,9 +156,12 @@ SaveError(pTHX_ const char* pat, ...)
     message = SvPV(msv,len);
     len++;		/* include terminating null char */
 
+    {
+	dMY_CXT;
     /* Copy message into dl_last_error (including terminating null char) */
-    sv_setpvn(MY_CXT.x_dl_last_error, message, len) ;
-    DLDEBUG(2,PerlIO_printf(Perl_debug_log, "DynaLoader: stored error msg '%s'\n",dl_last_error));
+	sv_setpvn(MY_CXT.x_dl_last_error, message, len) ;
+	DLDEBUG(2,PerlIO_printf(Perl_debug_log, "DynaLoader: stored error msg '%s'\n",dl_last_error));
+    }
 }
 #endif
 
--- dist/XSLoader/XSLoader_pm.PL
+++ dist/XSLoader/XSLoader_pm.PL
@@ -10,7 +10,7 @@ print OUT <<'EOT';
 
 package XSLoader;
 
-$VERSION = "0.17";
+$VERSION = "0.20";
 
 #use strict;
 
@@ -48,7 +48,8 @@ package XSLoader;
 sub load {
     package DynaLoader;
 
-    my ($module, $modlibname) = caller();
+    my ($caller, $modlibname) = caller();
+    my $module = $caller;
 
     if (@_) {
         $module = $_[0];
@@ -67,11 +68,14 @@ sub load {
 
 EOT
 
-print OUT <<'EOT' if defined &DynaLoader::mod2fname;
+# defined &DynaLoader::mod2fname catches most cases, except when
+# cross-compiling to a system that defines mod2fname. Using 
+# $Config{d_libname_unique} is a best attempt at catching those cases.
+print OUT <<'EOT' if defined &DynaLoader::mod2fname || $Config{d_libname_unique};
     # Some systems have restrictions on files names for DLL's etc.
     # mod2fname returns appropriate file base name (typically truncated)
     # It may also edit @modparts if required.
-    $modfname = &mod2fname(\@modparts) if defined &mod2fname;
+    $modfname = &DynaLoader::mod2fname(\@modparts) if defined &DynaLoader::mod2fname;
 
 EOT
 
@@ -84,7 +88,7 @@ EOT
 
 print OUT <<'EOT';
     my $modpname = join('/',@modparts);
-    my $c = @modparts;
+    my $c = () = split(/::/,$caller,-1);
     $modlibname =~ s,[\\/][^\\/]+$,, while $c--;    # Q&D basename
 EOT
 
@@ -105,9 +109,10 @@ print OUT <<'EOT';
 #       print STDERR "BS: $bs ($^O, $dlsrc)\n" if $dl_debug;
         eval { do $bs; };
         warn "$bs: $@\n" if $@;
+	goto \&XSLoader::bootstrap_inherit;
     }
 
-    goto \&XSLoader::bootstrap_inherit if not -f $file or -s $bs;
+    goto \&XSLoader::bootstrap_inherit if not -f $file;
 
     my $bootname = "boot_$module";
     $bootname =~ s/\W/_/g;
--- dist/IO/IO.pm
+++ dist/IO/IO.pm
@@ -7,7 +7,7 @@ use Carp;
 use strict;
 use warnings;
 
-our $VERSION = "1.31";
+our $VERSION = "1.35";
 XSLoader::load 'IO', $VERSION;
 
 sub import {
--- dist/IO/IO.xs
+++ dist/IO/IO.xs
@@ -61,6 +61,10 @@ typedef FILE * OutputStream;
 #  define dVAR dNOOP
 #endif
 
+#ifndef OpSIBLING
+#  define OpSIBLING(o) (o)->op_sibling
+#endif
+
 static int not_here(const char *s) __attribute__noreturn__;
 static int
 not_here(const char *s)
@@ -102,13 +106,19 @@ not_here(const char *s)
 static int
 io_blocking(pTHX_ InputStream f, int block)
 {
+    int fd = -1;
 #if defined(HAS_FCNTL)
     int RETVAL;
-    if(!f) {
+    if (!f) {
 	errno = EBADF;
 	return -1;
     }
-    RETVAL = fcntl(PerlIO_fileno(f), F_GETFL, 0);
+    fd = PerlIO_fileno(f);
+    if (fd < 0) {
+      errno = EBADF;
+      return -1;
+    }
+    RETVAL = fcntl(fd, F_GETFL, 0);
     if (RETVAL >= 0) {
 	int mode = RETVAL;
 	int newmode = mode;
@@ -143,7 +153,7 @@ io_blocking(pTHX_ InputStream f, int block)
 	}
 #endif
 	if (newmode != mode) {
-	    const int ret = fcntl(PerlIO_fileno(f),F_SETFL,newmode);
+            const int ret = fcntl(fd, F_SETFL, newmode);
 	    if (ret < 0)
 		RETVAL = ret;
 	}
@@ -154,7 +164,7 @@ io_blocking(pTHX_ InputStream f, int block)
     if (block >= 0) {
 	unsigned long flags = !block;
 	/* ioctl claims to take char* but really needs a u_long sized buffer */
-	const int ret = ioctl(PerlIO_fileno(f), FIONBIO, (char*)&flags);
+	const int ret = ioctl(fd, FIONBIO, (char*)&flags);
 	if (ret != 0)
 	    return -1;
 	/* Win32 has no way to get the current blocking status of a socket.
@@ -185,7 +195,7 @@ static OP *
 io_ck_lineseq(pTHX_ OP *o)
 {
     OP *kid = cBINOPo->op_first;
-    for (; kid; kid = kid->op_sibling)
+    for (; kid; kid = OpSIBLING(kid))
 	if (kid->op_type == OP_NEXTSTATE || kid->op_type == OP_DBSTATE)
 	    kid->op_ppaddr = io_pp_nextstate;
     return o;
@@ -524,9 +534,15 @@ fsync(arg)
 	handle = IoOFP(sv_2io(arg));
 	if (!handle)
 	    handle = IoIFP(sv_2io(arg));
-	if(handle)
-	    RETVAL = fsync(PerlIO_fileno(handle));
-	else {
+	if (handle) {
+	    int fd = PerlIO_fileno(handle);
+	    if (fd >= 0) {
+		RETVAL = fsync(fd);
+	    } else {
+		RETVAL = -1;
+		errno = EBADF;
+	    }
+	} else {
 	    RETVAL = -1;
 	    errno = EINVAL;
 	}
@@ -556,12 +572,17 @@ sockatmark (sock)
    PREINIT:
      int fd;
    CODE:
-   {
      fd = PerlIO_fileno(sock);
+     if (fd < 0) {
+       errno = EBADF;
+       RETVAL = -1;
+     }
 #ifdef HAS_SOCKATMARK
-     RETVAL = sockatmark(fd);
+     else {
+       RETVAL = sockatmark(fd);
+     }
 #else
-     {
+     else {
        int flag = 0;
 #   ifdef SIOCATMARK
 #     if defined(NETWARE) || defined(WIN32)
@@ -576,7 +597,6 @@ sockatmark (sock)
        RETVAL = flag;
      }
 #endif
-   }
    OUTPUT:
      RETVAL
 
--- dist/IO/lib/IO/Socket.pm
+++ dist/IO/lib/IO/Socket.pm
@@ -24,7 +24,7 @@ require IO::Socket::UNIX if ($^O ne 'epoc' && $^O ne 'symbian');
 
 @ISA = qw(IO::Handle);
 
-$VERSION = "1.37";
+$VERSION = "1.38";
 
 @EXPORT_OK = qw(sockatmark);
 
@@ -499,8 +499,23 @@ C<use> declaration will fail at compile time.
 
 =item connected
 
-If the socket is in a connected state the peer address is returned.
-If the socket is not in a connected state then undef will be returned.
+If the socket is in a connected state, the peer address is returned. If the
+socket is not in a connected state, undef is returned.
+
+Note that connected() considers a half-open TCP socket to be "in a connected
+state".  Specifically, connected() does not distinguish between the
+B<ESTABLISHED> and B<CLOSE-WAIT> TCP states; it returns the peer address,
+rather than undef, in either case.  Thus, in general, connected() cannot
+be used to reliably learn whether the peer has initiated a graceful shutdown
+because in most cases (see below) the local TCP state machine remains in
+B<CLOSE-WAIT> until the local application calls shutdown() or close();
+only at that point does connected() return undef.
+
+The "in most cases" hedge is because local TCP state machine behavior may
+depend on the peer's socket options. In particular, if the peer socket has
+SO_LINGER enabled with a zero timeout, then the peer's close() will generate
+a RST segment, upon receipt of which the local TCP transitions immediately to
+B<CLOSED>, and in that state, connected() I<will> return undef.
 
 =item protocol
 
--- dist/IO/poll.c
+++ dist/IO/poll.c
@@ -54,7 +54,9 @@ poll(struct pollfd *fds, unsigned long nfds, int timeout)
 
     FD_ZERO(&ifd);
 
+#ifdef HAS_FSTAT
 again:
+#endif
 
     FD_ZERO(&rfd);
     FD_ZERO(&wfd);
PATCH
}

sub _patch_gnumakefile_520 {
    my $version = shift;
    $version =~ s/[.]//g;
    my $makefile = <<'MAKEFILE';
#
# Makefile to build perl on Windows using GMAKE.
# Supported compilers:
#	MinGW with gcc-8.3.0 or later

##
## Make sure you read README.win32 *before* you mess with anything here!
##

#
# We set this to point to cmd.exe in case GNU Make finds sh.exe in the path.
# Comment this line out if necessary
#
SHELL := cmd.exe

# define whether you want to use native gcc compiler or cross-compiler
# possible values: gcc
#                  i686-w64-mingw32-gcc
#                  x86_64-w64-mingw32-gcc
GCCBIN := gcc

##
## Build configuration.  Edit the values below to suit your needs.
##

#
# Set these to wherever you want "gmake install" to put your
# newly built perl.
#
INST_DRV := c:
INST_TOP := $(INST_DRV)\perl

#
# Comment this out if you DON'T want your perl installation to be versioned.
# This means that the new installation will overwrite any files from the
# old installation at the same INST_TOP location.  Leaving it enabled is
# the safest route, as perl adds the extra version directory to all the
# locations it installs files to.  If you disable it, an alternative
# versioned installation can be obtained by setting INST_TOP above to a
# path that includes an arbitrary version string.
#
#INST_VER	:= \5.20.0

#
# Comment this out if you DON'T want your perl installation to have
# architecture specific components.  This means that architecture-
# specific files will be installed along with the architecture-neutral
# files.  Leaving it enabled is safer and more flexible, in case you
# want to build multiple flavors of perl and install them together in
# the same location.  Commenting it out gives you a simpler
# installation that is easier to understand for beginners.
#
#INST_ARCH	:= \$(ARCHNAME)

#
# Uncomment this if you want perl to run
# 	$Config{sitelibexp}\sitecustomize.pl
# before anything else.  This script can then be set up, for example,
# to add additional entries to @INC.
#
#USE_SITECUST	:= define

#
# uncomment to enable multiple interpreters.  This is needed for fork()
# emulation and for thread support, and is auto-enabled by USE_IMP_SYS
# and USE_ITHREADS below.
#
USE_MULTI	:= define

#
# Interpreter cloning/threads; now reasonably complete.
# This should be enabled to get the fork() emulation.  This needs (and
# will auto-enable) USE_MULTI above.
#
USE_ITHREADS	:= define

#
# uncomment to enable the implicit "host" layer for all system calls
# made by perl.  This is also needed to get fork().  This needs (and
# will auto-enable) USE_MULTI above.
#
USE_IMP_SYS	:= define

#
# Comment out next assign to disable perl's I/O subsystem and use compiler's
# stdio for IO - depending on your compiler vendor and run time library you may
# then get a number of fails from make test i.e. bugs - complain to them not us ;-).
# You will also be unable to take full advantage of perl5.8's support for multiple
# encodings and may see lower IO performance. You have been warned.
#
USE_PERLIO	:= define

#
# Comment this out if you don't want to enable large file support for
# some reason.  Should normally only be changed to maintain compatibility
# with an older release of perl.
#
USE_LARGE_FILES	:= define

#
# Uncomment this if you're building a 32-bit perl and want 64-bit integers.
# (If you're building a 64-bit perl then you will have 64-bit integers whether
# or not this is uncommented.)
# Note: This option is not supported in 32-bit MSVC60 builds.
#
#USE_64_BIT_INT	:= define

#
# Uncomment this if you want to support the use of long doubles in GCC builds.
# This option is not supported for MSVC builds.
#
#USE_LONG_DOUBLE :=define

#
# Uncomment this if you want to disable looking up values from
# HKEY_CURRENT_USER\Software\Perl and HKEY_LOCAL_MACHINE\Software\Perl in
# the Registry.
#
#USE_NO_REGISTRY := define

# MinGW or mingw-w64 with gcc-8.3.0 or later
CCTYPE		:= GCC

#
# If you are using Intel C++ Compiler uncomment this
#
#__ICC		:= define

#
# uncomment next line if you want debug version of perl (big/slow)
# If not enabled, we automatically try to use maximum optimization
# with all compilers that are known to have a working optimizer.
#
CFG		:= Debug

#
# uncomment to enable linking with setargv.obj under the Visual C
# compiler. Setting this options enables perl to expand wildcards in
# arguments, but it may be harder to use alternate methods like
# File::DosGlob that are more powerful.  This option is supported only with
# Visual C.
#
#USE_SETARGV	:= define

#
# set this if you wish to use perl's malloc
# WARNING: Turning this on/off WILL break binary compatibility with extensions
# you may have compiled with/without it.  Be prepared to recompile all
# extensions if you change the default.  Currently, this cannot be enabled
# if you ask for USE_IMP_SYS above.
#
#PERL_MALLOC	:= define

#
# set this to enable debugging mstats
# This must be enabled to use the Devel::Peek::mstat() function.  This cannot
# be enabled without PERL_MALLOC as well.
#
#DEBUG_MSTATS	:= define

#
# set the install locations of the compiler include/libraries
#
CCHOME		:= C:\Strawberry\c

#
# Following sets $Config{incpath} and $Config{libpth}
#

CCINCDIR := $(CCHOME)\include
CCLIBDIR := $(CCHOME)\lib
CCDLLDIR := $(CCHOME)\bin
ARCHPREFIX :=

#
# Additional compiler flags can be specified here.
#
BUILDOPT	:= $(BUILDOPTEXTRA)

#
# Perl needs to read scripts in text mode so that the DATA filehandle
# works correctly with seek() and tell(), or around auto-flushes of
# all filehandles (e.g. by system(), backticks, fork(), etc).
#
# The current version on the ByteLoader module on CPAN however only
# works if scripts are read in binary mode.  But before you disable text
# mode script reading (and break some DATA filehandle functionality)
# please check first if an updated ByteLoader isn't available on CPAN.
#
BUILDOPT	+= -DPERL_TEXTMODE_SCRIPTS

#
# specify semicolon-separated list of extra directories that modules will
# look for libraries (spaces in path names need not be quoted)
#
EXTRALIBDIRS	:=


##
## Build configuration ends.
##

##################### CHANGE THESE ONLY IF YOU MUST #####################

PERL_MALLOC	?= undef
DEBUG_MSTATS	?= undef

USE_SITECUST	?= undef
USE_MULTI	?= undef
USE_ITHREADS	?= undef
USE_IMP_SYS	?= undef
USE_PERLIO	?= undef
USE_LARGE_FILES	?= undef
USE_64_BIT_INT	?= undef
USE_LONG_DOUBLE	?= undef
USE_NO_REGISTRY	?= undef

ifeq ($(USE_IMP_SYS),define)
PERL_MALLOC	= undef
endif

ifeq ($(PERL_MALLOC),undef)
DEBUG_MSTATS	= undef
endif

ifeq ($(DEBUG_MSTATS),define)
BUILDOPT	+= -DPERL_DEBUGGING_MSTATS
endif

ifeq ("$(USE_IMP_SYS) $(USE_MULTI)","define undef")
USE_MULTI	= define
endif

ifeq ("$(USE_ITHREADS) $(USE_MULTI)","define undef")
USE_MULTI	= define
endif

ifeq ($(USE_SITECUST),define)
BUILDOPT	+= -DUSE_SITECUSTOMIZE
endif

ifneq ($(USE_MULTI),undef)
BUILDOPT	+= -DPERL_IMPLICIT_CONTEXT
endif

ifneq ($(USE_IMP_SYS),undef)
BUILDOPT	+= -DPERL_IMPLICIT_SYS
endif

ifeq ($(USE_NO_REGISTRY),define)
BUILDOPT	+= -DWIN32_NO_REGISTRY
endif

WIN64 := define
PROCESSOR_ARCHITECTURE := x64
USE_64_BIT_INT = define
ARCHITECTURE = x64

ifeq ($(USE_MULTI),define)
ARCHNAME	= MSWin32-$(ARCHITECTURE)-multi
else
ifeq ($(USE_PERLIO),define)
ARCHNAME	= MSWin32-$(ARCHITECTURE)-perlio
else
ARCHNAME	= MSWin32-$(ARCHITECTURE)
endif
endif

ifeq ($(USE_PERLIO),define)
BUILDOPT	+= -DUSE_PERLIO
endif

ifeq ($(USE_ITHREADS),define)
ARCHNAME	:= $(ARCHNAME)-thread
endif

ifneq ($(WIN64),define)
ifeq ($(USE_64_BIT_INT),define)
ARCHNAME	:= $(ARCHNAME)-64int
endif
endif

ifeq ($(USE_LONG_DOUBLE),define)
ARCHNAME	:= $(ARCHNAME)-ld
endif

ARCHDIR		= ..\lib\$(ARCHNAME)
COREDIR		= ..\lib\CORE
AUTODIR		= ..\lib\auto
LIBDIR		= ..\lib
EXTDIR		= ..\ext
DISTDIR		= ..\dist
CPANDIR		= ..\cpan
PODDIR		= ..\pod
HTMLDIR		= .\html

#
INST_SCRIPT	= $(INST_TOP)$(INST_VER)\bin
INST_BIN	= $(INST_SCRIPT)$(INST_ARCH)
INST_LIB	= $(INST_TOP)$(INST_VER)\lib
INST_ARCHLIB	= $(INST_LIB)$(INST_ARCH)
INST_COREDIR	= $(INST_ARCHLIB)\CORE
INST_HTML	= $(INST_TOP)$(INST_VER)\html

#
# Programs to compile, build .lib files and link
#

MINIBUILDOPT    :=

CC		= $(ARCHPREFIX)gcc
LINK32		= $(ARCHPREFIX)g++
LIB32		= $(ARCHPREFIX)ar rc
IMPLIB		= $(ARCHPREFIX)dlltool
RSC		= $(ARCHPREFIX)windres

ifeq ($(USE_LONG_DOUBLE),define)
BUILDOPT        += -D__USE_MINGW_ANSI_STDIO
MINIBUILDOPT    += -D__USE_MINGW_ANSI_STDIO
endif

BUILDOPT        += -fwrapv
MINIBUILDOPT    += -fwrapv

i = .i
o = .o
a = .a

#
# Options
#

INCLUDES	= -I.\include -I. -I..
DEFINES		= -DWIN32 -DWIN64 -DCONSERVATIVE
LOCDEFS		= -DPERLDLL -DPERL_CORE
CXX_FLAG	= -xc++
LIBC		=
LIBFILES	= $(LIBC) -lmoldname -lkernel32 -luser32 -lgdi32 -lwinspool \
	-lcomdlg32 -ladvapi32 -lshell32 -lole32 -loleaut32 -lnetapi32 \
	-luuid -lws2_32 -lmpr -lwinmm -lversion -lodbc32 -lodbccp32 -lcomctl32

ifeq ($(CFG),Debug)
OPTIMIZE	= -g -O2 -DDEBUGGING
LINK_DBG	= -g
else
OPTIMIZE	= -s -O2
LINK_DBG	= -s
endif

EXTRACFLAGS	=
CFLAGS		= $(EXTRACFLAGS) $(INCLUDES) $(DEFINES) $(LOCDEFS) $(OPTIMIZE)
LINK_FLAGS	= $(LINK_DBG) -L"$(INST_COREDIR)" -L"$(CCLIBDIR)"
OBJOUT_FLAG	= -o
EXEOUT_FLAG	= -o
LIBOUT_FLAG	=
PDBOUT		=

BUILDOPT	+= -fno-strict-aliasing -mms-bitfields
MINIBUILDOPT	+= -fno-strict-aliasing

TESTPREPGCC	= test-prep-gcc

CFLAGS_O	= $(CFLAGS) $(BUILDOPT)
BLINK_FLAGS	= $(PRIV_LINK_FLAGS) $(LINK_FLAGS)

#################### do not edit below this line #######################
############# NO USER-SERVICEABLE PARTS BEYOND THIS POINT ##############

#prevent -j from reaching EUMM/make_ext.pl/"sub makes", Win32 EUMM not parallel
#compatible yet
unexport MAKEFLAGS

a ?= .lib

.SUFFIXES : .c .i $(o) .dll $(a) .exe .rc .res

%$(o): %.c
	$(CC) -c -I$(<D) $(CFLAGS_O) $(OBJOUT_FLAG)$@ $(PDBOUT) $<

%.i: %.c
	$(CC) -c -I$(<D) $(CFLAGS_O) -E $< >$@

%.c: %.y
	$(NOOP)

%.dll: %$(o)
	$(LINK32) -o $@ $(BLINK_FLAGS) $< $(LIBFILES)
	$(IMPLIB) --input-def $(*F).def --output-lib $(*F).a $@

%.res: %.rc
	$(RSC) --use-temp-file --include-dir=. --include-dir=.. -O COFF -D INCLUDE_MANIFEST -i $< -o $@

#
# various targets

#do not put $(MINIPERL) as a dep/prereq in a rule, instead put $(HAVEMINIPERL)
#$(MINIPERL) is not a buildable target, use "gmake mp" if you want to just build
#miniperl alone
MINIPERL	= ..\miniperl.exe
HAVEMINIPERL	= ..\lib\buildcustomize.pl
MINIDIR		= mini
PERLEXE		= ..\perl.exe
WPERLEXE	= ..\wperl.exe
PERLEXESTATIC	= ..\perl-static.exe
STATICDIR	= .\static.tmp
GLOBEXE		= ..\perlglob.exe
CONFIGPM	= ..\lib\Config.pm
X2P		= ..\x2p\a2p.exe
GENUUDMAP	= ..\generate_uudmap.exe
PERLSTATIC	=

# Unicode data files generated by mktables
UNIDATAFILES	 = ..\lib\unicore\Decomposition.pl ..\lib\unicore\TestProp.pl \
		   ..\lib\unicore\CombiningClass.pl ..\lib\unicore\Name.pl \
		   ..\lib\unicore\UCD.pl ..\lib\unicore\Name.pm            \
		   ..\lib\unicore\Heavy.pl ..\lib\unicore\mktables.lst

# Directories of Unicode data files generated by mktables
UNIDATADIR1	= ..\lib\unicore\To
UNIDATADIR2	= ..\lib\unicore\lib

PERLEXE_MANIFEST= .\perlexe.manifest
PERLEXE_ICO	= .\perlexe.ico
PERLEXE_RES	= .\perlexe.res
PERLDLL_RES	=

# Nominate a target which causes extensions to be re-built
# This used to be $(PERLEXE), but at worst it is the .dll that they depend
# on and really only the interface - i.e. the .def file used to export symbols
# from the .dll
PERLDEP = $(PERLIMPLIB)


PL2BAT		= bin\pl2bat.pl

UTILS		=			\
		..\utils\h2ph		\
		..\utils\splain		\
		..\utils\perlbug	\
		..\utils\pl2pm 		\
		..\utils\c2ph		\
		..\utils\pstruct	\
		..\utils\h2xs		\
		..\utils\perldoc	\
		..\utils\perlivp	\
		..\utils\libnetcfg	\
		..\utils\enc2xs		\
		..\utils\piconv		\
		..\utils\config_data	\
		..\utils\corelist	\
		..\utils\cpan		\
		..\utils\xsubpp		\
		..\utils\prove		\
		..\utils\ptar		\
		..\utils\ptardiff	\
		..\utils\ptargrep	\
		..\utils\zipdetails	\
		..\utils\shasum		\
		..\utils\instmodsh	\
		..\utils\json_pp	\
		..\utils\pod2html	\
		..\x2p\find2perl	\
		..\x2p\psed		\
		..\x2p\s2p		\
		bin\exetype.pl		\
		bin\runperl.pl		\
		bin\pl2bat.pl		\
		bin\perlglob.pl		\
		bin\search.pl

CFGSH_TMPL	= config.gc
CFGH_TMPL	= config_H.gc
PERLIMPLIB	= $(COREDIR)\libperl__PERL_MINOR_VERSION__$(a)
PERLIMPLIBBASE	= libperl__PERL_MINOR_VERSION__$(a)
PERLSTATICLIB	= ..\libperl__PERL_MINOR_VERSION__s$(a)
INT64		= long long
PERLEXPLIB	= $(COREDIR)\perl__PERL_MINOR_VERSION__.exp
PERLDLL		= ..\perl__PERL_MINOR_VERSION__.dll

# don't let "gmake -n all" try to run "miniperl.exe make_ext.pl"
PLMAKE		= gmake

XCOPY		= xcopy /f /r /i /d /y
RCOPY		= xcopy /f /r /i /e /d /y
NOOP		= @rem

#first ones are arrange in compile time order for faster parallel building
MICROCORE_SRC	=		\
		..\av.c		\
		..\caretx.c	\
		..\deb.c	\
		..\doio.c	\
		..\doop.c	\
		..\dump.c	\
		..\globals.c	\
		..\gv.c		\
		..\mro.c	\
		..\hv.c		\
		..\locale.c	\
		..\keywords.c	\
		..\mathoms.c    \
		..\mg.c		\
		..\numeric.c	\
		..\op.c		\
		..\pad.c	\
		..\perl.c	\
		..\perlapi.c	\
		..\perly.c	\
		..\pp.c		\
		..\pp_ctl.c	\
		..\pp_hot.c	\
		..\pp_pack.c	\
		..\pp_sort.c	\
		..\pp_sys.c	\
		..\reentr.c	\
		..\regcomp.c	\
		..\regexec.c	\
		..\run.c	\
		..\scope.c	\
		..\sv.c		\
		..\taint.c	\
		..\toke.c	\
		..\universal.c	\
		..\utf8.c	\
		..\util.c

EXTRACORE_SRC	+= perllib.c

ifeq ($(PERL_MALLOC),define)
EXTRACORE_SRC	+= ..\malloc.c
endif

EXTRACORE_SRC	+= ..\perlio.c

WIN32_SRC	=		\
		.\win32.c	\
		.\win32io.c	\
		.\win32sck.c	\
		.\win32thread.c	\
		.\fcrypt.c

X2P_SRC		=		\
		..\x2p\a2p.c	\
		..\x2p\hash.c	\
		..\x2p\str.c	\
		..\x2p\util.c	\
		..\x2p\walk.c

CORE_NOCFG_H	=		\
		..\av.h		\
		..\cop.h	\
		..\cv.h		\
		..\dosish.h	\
		..\embed.h	\
		..\form.h	\
		..\gv.h		\
		..\handy.h	\
		..\hv.h		\
		..\hv_func.h	\
		..\iperlsys.h	\
		..\mg.h		\
		..\nostdio.h	\
		..\op.h		\
		..\opcode.h	\
		..\perl.h	\
		..\perlapi.h	\
		..\perlsdio.h	\
		..\perly.h	\
		..\pp.h		\
		..\proto.h	\
		..\regcomp.h	\
		..\regexp.h	\
		..\scope.h	\
		..\sv.h		\
		..\thread.h	\
		..\unixish.h	\
		..\utf8.h	\
		..\util.h	\
		..\warnings.h	\
		..\XSUB.h	\
		..\EXTERN.h	\
		..\perlvars.h	\
		..\intrpvar.h	\
		.\include\dirent.h	\
		.\include\netdb.h	\
		.\include\sys\errno2.h	\
		.\include\sys\socket.h	\
		.\win32.h

CORE_H		= $(CORE_NOCFG_H) .\config.h ..\git_version.h

UUDMAP_H	= ..\uudmap.h
BITCOUNT_H	= ..\bitcount.h
MG_DATA_H	= ..\mg_data.h
GENERATED_HEADERS = $(UUDMAP_H) $(BITCOUNT_H) $(MG_DATA_H)
#a stub ppport.h must be generated so building XS modules, .c->.obj wise, will
#work, so this target also represents creating the COREDIR and filling it
HAVE_COREDIR	= $(COREDIR)\ppport.h

MICROCORE_OBJ	= $(MICROCORE_SRC:.c=$(o))
CORE_OBJ	= $(MICROCORE_OBJ) $(EXTRACORE_SRC:.c=$(o))
WIN32_OBJ	= $(WIN32_SRC:.c=$(o))

MINICORE_OBJ	= $(subst ..\,mini\,$(MICROCORE_OBJ))	\
		  $(MINIDIR)\miniperlmain$(o)	\
		  $(MINIDIR)\perlio$(o)
MINIWIN32_OBJ	= $(subst .\,mini\,$(WIN32_OBJ))
MINI_OBJ	= $(MINICORE_OBJ) $(MINIWIN32_OBJ)
DLL_OBJ		= $(DYNALOADER)
X2P_OBJ		= $(X2P_SRC:.c=$(o))
PERLDLL_OBJ	= $(CORE_OBJ)
PERLEXE_OBJ	= perlmain$(o)
PERLEXEST_OBJ	= perlmainst$(o)

PERLDLL_OBJ	+= $(WIN32_OBJ) $(DLL_OBJ)

ifneq ($(USE_SETARGV),)
SETARGV_OBJ	= setargv$(o)
endif

ifeq ($(ALL_STATIC),define)
# some exclusions, unfortunately, until fixed:
#  - MakeMaker isn't capable enough for SDBM_File (small bug)
STATIC_EXT	= * !SDBM_File
else
# specify static extensions here, for example:
# (be sure to include Win32CORE to load Win32 on demand)
#STATIC_EXT	= Win32CORE Cwd Compress/Raw/Zlib
STATIC_EXT	= Win32CORE
endif

DYNALOADER	= ..\DynaLoader$(o)

# vars must be separated by "\t+~\t+", since we're using the tempfile
# version of config_sh.pl (we were overflowing someone's buffer by
# trying to fit them all on the command line)
#	-- BKS 10-17-1999
CFG_VARS	=					\
		"INST_TOP=$(INST_TOP)"			\
		"INST_VER=$(INST_VER)"			\
		"INST_ARCH=$(INST_ARCH)"		\
		"archname=$(ARCHNAME)"			\
		"cc=$(CC)"				\
		"ld=$(LINK32)"				\
		"ccflags=$(subst ",\",$(EXTRACFLAGS) $(OPTIMIZE) $(DEFINES) $(BUILDOPT))" \
		"usecplusplus=$(USE_CPLUSPLUS)"		\
		"cf_email=$(EMAIL)"			\
		"d_mymalloc=$(PERL_MALLOC)"		\
		"libs=$(LIBFILES)"			\
		"incpath=$(subst ",\",$(CCINCDIR))"			\
		"libperl=$(subst ",\",$(PERLIMPLIBBASE))"		\
		"libpth=$(subst ",\",$(CCLIBDIR);$(EXTRALIBDIRS))"	\
		"libc=$(LIBC)"				\
		"make=$(PLMAKE)"				\
		"_o=$(o)"				\
		"obj_ext=$(o)"				\
		"_a=$(a)"				\
		"lib_ext=$(a)"				\
		"static_ext=$(STATIC_EXT)"		\
		"usethreads=$(USE_ITHREADS)"		\
		"useithreads=$(USE_ITHREADS)"		\
		"usemultiplicity=$(USE_MULTI)"		\
		"useperlio=$(USE_PERLIO)"		\
		"use64bitint=$(USE_64_BIT_INT)"		\
		"uselongdouble=$(USE_LONG_DOUBLE)"	\
		"uselargefiles=$(USE_LARGE_FILES)"	\
		"usesitecustomize=$(USE_SITECUST)"	\
		"LINK_FLAGS=$(subst ",\",$(LINK_FLAGS))"\
		"optimize=$(subst ",\",$(OPTIMIZE))"	\
		"ARCHPREFIX=$(ARCHPREFIX)"		\
		"WIN64=$(WIN64)"

#
# Top targets
#

.PHONY: all

all : .\config.h ..\git_version.h $(GLOBEXE) $(CONFIGPM) \
		$(UNIDATAFILES) MakePPPort $(PERLEXE) $(X2P) Extensions_nonxs Extensions $(PERLSTATIC)
		@echo Everything is up to date. '$(MAKE_BARE) test' to run test suite.

..\regcomp$(o) : ..\regnodes.h ..\regcharclass.h

..\regexec$(o) : ..\regnodes.h ..\regcharclass.h

#----------------------------------------------------------------

$(GLOBEXE) : perlglob.c
	$(LINK32) $(OPTIMIZE) $(BLINK_FLAGS) -mconsole -o $@ perlglob.c $(LIBFILES)

..\git_version.h : $(HAVEMINIPERL) ..\make_patchnum.pl
	$(MINIPERL) -I..\lib ..\make_patchnum.pl

# make sure that we recompile perl.c if the git version changes
..\perl$(o) : ..\git_version.h

..\config.sh : $(CFGSH_TMPL) $(HAVEMINIPERL) config_sh.PL FindExt.pm
	$(MINIPERL) -I..\lib config_sh.PL $(CFG_VARS) $(CFGSH_TMPL) > ..\config.sh

$(CONFIGPM) : $(HAVEMINIPERL) ..\config.sh config_h.PL
	$(MINIPERL) -I..\lib ..\configpm --chdir=..
	$(XCOPY) *.h $(COREDIR)\\*.*
	$(RCOPY) include $(COREDIR)\\*.*
	$(XCOPY) ..\\*.h $(COREDIR)\\*.*
	-$(MINIPERL) -I..\lib config_h.PL "ARCHPREFIX=$(ARCHPREFIX)"

# See the comment in Makefile.SH explaining this seemingly cranky ordering
..\lib\buildcustomize.pl : $(MINI_OBJ) ..\write_buildcustomize.pl
	$(LINK32) -mconsole -o $(MINIPERL) $(BLINK_FLAGS) $(MINI_OBJ) $(LIBFILES)
	$(MINIPERL) -I..\lib -f ..\write_buildcustomize.pl ..

#
# Copy the template config.h and set configurables at the end of it
# as per the options chosen and compiler used.
# Note: This config.h is only used to build miniperl.exe anyway, but
# it's as well to have its options correct to be sure that it builds
# and so that it's "-V" options are correct for use by makedef.pl. The
# real config.h used to build perl.exe is generated from the top-level
# config_h.SH by config_h.PL (run by miniperl.exe).
#
.\config.h : $(CONFIGPM)
$(MINIDIR)\.exists : $(CFGH_TMPL)
	if not exist "$(MINIDIR)" mkdir "$(MINIDIR)"
	copy $(CFGH_TMPL) config.h
	@(echo.&& \
	echo #ifndef _config_h_footer_&& \
	echo #define _config_h_footer_&& \
	echo #undef Off_t&& \
	echo #undef LSEEKSIZE&& \
	echo #undef Off_t_size&& \
	echo #undef PTRSIZE&& \
	echo #undef SSize_t&& \
	echo #undef HAS_ATOLL&& \
	echo #undef HAS_STRTOLL&& \
	echo #undef HAS_STRTOULL&& \
	echo #undef Size_t_size&& \
	echo #undef IVTYPE&& \
	echo #undef UVTYPE&& \
	echo #undef IVSIZE&& \
	echo #undef UVSIZE&& \
	echo #undef NV_PRESERVES_UV&& \
	echo #undef NV_PRESERVES_UV_BITS&& \
	echo #undef IVdf&& \
	echo #undef UVuf&& \
	echo #undef UVof&& \
	echo #undef UVxf&& \
	echo #undef UVXf&& \
	echo #undef USE_64_BIT_INT&& \
	echo #undef Gconvert&& \
	echo #undef HAS_FREXPL&& \
	echo #undef HAS_ISNANL&& \
	echo #undef HAS_MODFL&& \
	echo #undef HAS_MODFL_PROTO&& \
	echo #undef HAS_SQRTL&& \
	echo #undef HAS_STRTOLD&& \
	echo #undef PERL_PRIfldbl&& \
	echo #undef PERL_PRIgldbl&& \
	echo #undef PERL_PRIeldbl&& \
	echo #undef PERL_SCNfldbl&& \
	echo #undef NVTYPE&& \
	echo #undef NVSIZE&& \
	echo #undef LONG_DOUBLESIZE&& \
	echo #undef NV_OVERFLOWS_INTEGERS_AT&& \
	echo #undef NVef&& \
	echo #undef NVff&& \
	echo #undef NVgf&& \
	echo #undef USE_LONG_DOUBLE)>> config.h
ifeq ($(USE_LARGE_FILES),define)
	@(echo #define Off_t $(INT64)&& \
	echo #define LSEEKSIZE ^8&& \
	echo #define Off_t_size ^8)>> config.h
else
	@(echo #define Off_t long&& \
	echo #define LSEEKSIZE ^4&& \
	echo #define Off_t_size ^4)>> config.h
endif
ifeq ($(WIN64),define)
	@(echo #define PTRSIZE ^8&& \
	echo #define SSize_t $(INT64)&& \
	echo #define HAS_ATOLL&& \
	echo #define HAS_STRTOLL&& \
	echo #define HAS_STRTOULL&& \
	echo #define Size_t_size ^8)>> config.h
else
	@(echo #define PTRSIZE ^4&& \
	echo #define SSize_t int&& \
	echo #undef HAS_ATOLL&& \
	echo #undef HAS_STRTOLL&& \
	echo #undef HAS_STRTOULL&& \
	echo #define Size_t_size ^4)>> config.h
endif
ifeq ($(USE_64_BIT_INT),define)
	@(echo #define IVTYPE $(INT64)&& \
	echo #define UVTYPE unsigned $(INT64)&& \
	echo #define IVSIZE ^8&& \
	echo #define UVSIZE ^8)>> config.h
ifeq ($(USE_LONG_DOUBLE),define)
	@(echo #define NV_PRESERVES_UV&& \
	echo #define NV_PRESERVES_UV_BITS 64)>> config.h
else
	@(echo #undef NV_PRESERVES_UV&& \
	echo #define NV_PRESERVES_UV_BITS 53)>> config.h
endif
	@(echo #define IVdf "I64d"&& \
	echo #define UVuf "I64u"&& \
	echo #define UVof "I64o"&& \
	echo #define UVxf "I64x"&& \
	echo #define UVXf "I64X"&& \
	echo #define USE_64_BIT_INT)>> config.h
else
	@(echo #define IVTYPE long&& \
	echo #define UVTYPE unsigned long&& \
	echo #define IVSIZE ^4&& \
	echo #define UVSIZE ^4&& \
	echo #define NV_PRESERVES_UV&& \
	echo #define NV_PRESERVES_UV_BITS 32&& \
	echo #define IVdf "ld"&& \
	echo #define UVuf "lu"&& \
	echo #define UVof "lo"&& \
	echo #define UVxf "lx"&& \
	echo #define UVXf "lX"&& \
	echo #undef USE_64_BIT_INT)>> config.h
endif
ifeq ($(USE_LONG_DOUBLE),define)
	@(echo #define Gconvert^(x,n,t,b^) sprintf^(^(b^),"%%.*""Lg",^(n^),^(x^)^)&& \
	echo #define HAS_FREXPL&& \
	echo #define HAS_ISNANL&& \
	echo #define HAS_MODFL&& \
	echo #define HAS_MODFL_PROTO&& \
	echo #define HAS_SQRTL&& \
	echo #define HAS_STRTOLD&& \
	echo #define PERL_PRIfldbl "Lf"&& \
	echo #define PERL_PRIgldbl "Lg"&& \
	echo #define PERL_PRIeldbl "Le"&& \
	echo #define PERL_SCNfldbl "Lf"&& \
	echo #define NVTYPE long double)>> config.h
ifeq ($(WIN64),define)
	@(echo #define NVSIZE ^16&& \
	echo #define LONG_DOUBLESIZE ^16)>> config.h
else
	@(echo #define NVSIZE ^12&& \
	echo #define LONG_DOUBLESIZE ^12)>> config.h
endif
	@(echo #define NV_OVERFLOWS_INTEGERS_AT 256.0*256.0*256.0*256.0*256.0*256.0*256.0*2.0*2.0*2.0*2.0*2.0*2.0*2.0*2.0&& \
	echo #define NVef "Le"&& \
	echo #define NVff "Lf"&& \
	echo #define NVgf "Lg"&& \
	echo #define USE_LONG_DOUBLE)>> config.h
else
	@(echo #define Gconvert^(x,n,t,b^) sprintf^(^(b^),"%%.*g",^(n^),^(x^)^)&& \
	echo #undef HAS_FREXPL&& \
	echo #undef HAS_ISNANL&& \
	echo #undef HAS_MODFL&& \
	echo #undef HAS_MODFL_PROTO&& \
	echo #undef HAS_SQRTL&& \
	echo #undef HAS_STRTOLD&& \
	echo #undef PERL_PRIfldbl&& \
	echo #undef PERL_PRIgldbl&& \
	echo #undef PERL_PRIeldbl&& \
	echo #undef PERL_SCNfldbl&& \
	echo #define NVTYPE double&& \
	echo #define NVSIZE ^8&& \
	echo #define LONG_DOUBLESIZE ^8&& \
	echo #define NV_OVERFLOWS_INTEGERS_AT 256.0*256.0*256.0*256.0*256.0*256.0*2.0*2.0*2.0*2.0*2.0&& \
	echo #define NVef "e"&& \
	echo #define NVff "f"&& \
	echo #define NVgf "g"&& \
	echo #undef USE_LONG_DOUBLE)>> config.h
endif
ifeq ($(USE_CPLUSPLUS),define)
	@(echo #define USE_CPLUSPLUS&& \
	echo #endif)>> config.h
else
	@(echo #undef USE_CPLUSPLUS&& \
	echo #endif)>> config.h
endif
#separate line since this is sentinal that this target is done
	rem. > $(MINIDIR)\.exists

$(MINICORE_OBJ) : $(CORE_NOCFG_H)
	$(CC) -c $(CFLAGS) $(MINIBUILDOPT) -DPERL_EXTERNAL_GLOB -DPERL_IS_MINIPERL $(OBJOUT_FLAG)$@ $(PDBOUT) ..\$(*F).c

$(MINIWIN32_OBJ) : $(CORE_NOCFG_H)
	$(CC) -c $(CFLAGS) $(MINIBUILDOPT) -DPERL_IS_MINIPERL $(OBJOUT_FLAG)$@ $(PDBOUT) $(*F).c

# -DPERL_IMPLICIT_SYS needs C++ for perllib.c
# rules wrapped in .IFs break Win9X build (we end up with unbalanced []s unless
# unless the .IF is true), so instead we use a .ELSE with the default.
# This is the only file that depends on perlhost.h, vmem.h, and vdir.h

perllib$(o)	: perllib.c perllibst.h .\perlhost.h .\vdir.h .\vmem.h
ifeq ($(USE_IMP_SYS),define)
	$(CC) -c -I. $(CFLAGS_O) $(CXX_FLAG) $(OBJOUT_FLAG)$@ $(PDBOUT) perllib.c
else
	$(CC) -c -I. $(CFLAGS_O) $(OBJOUT_FLAG)$@ $(PDBOUT) perllib.c
endif

# 1. we don't want to rebuild miniperl.exe when config.h changes
# 2. we don't want to rebuild miniperl.exe with non-default config.h
# 3. we can't have miniperl.exe depend on git_version.h, as miniperl creates it
$(MINI_OBJ)	: $(MINIDIR)\.exists $(CORE_NOCFG_H)

$(WIN32_OBJ)	: $(CORE_H)

$(CORE_OBJ)	: $(CORE_H)

$(DLL_OBJ)	: $(CORE_H)

$(X2P_OBJ)	: $(CORE_H)

perllibst.h : $(HAVEMINIPERL) $(CONFIGPM) create_perllibst_h.pl
	$(MINIPERL) -I..\lib create_perllibst_h.pl

perldll.def : $(HAVEMINIPERL) $(CONFIGPM) ..\embed.fnc ..\makedef.pl
	$(MINIPERL) -I..\lib -w ..\makedef.pl PLATFORM=win32 $(OPTIMIZE) $(DEFINES) \
	$(BUILDOPT) CCTYPE=$(CCTYPE) TARG_DIR=..\ > perldll.def

$(PERLEXPLIB) : $(PERLIMPLIB)

$(PERLIMPLIB) : perldll.def
	$(IMPLIB) -k -d perldll.def -l $(PERLIMPLIB) -e $(PERLEXPLIB)

$(PERLDLL): perldll.def $(PERLEXPLIB) $(PERLDLL_OBJ) Extensions_static
	$(LINK32) -mdll -o $@ $(BLINK_FLAGS) \
	   $(PERLDLL_OBJ) $(shell type Extensions_static) $(LIBFILES) $(PERLEXPLIB)

$(PERLSTATICLIB): $(PERLDLL_OBJ) Extensions_static
	$(LIB32) $(LIB_FLAGS) $@ $(PERLDLL_OBJ)
	if exist $(STATICDIR) rmdir /s /q $(STATICDIR)
	for %%i in ($(shell type Extensions_static)) do \
		@mkdir $(STATICDIR) && cd $(STATICDIR) && \
		$(ARCHPREFIX)ar x ..\%%i && \
		$(ARCHPREFIX)ar q ..\$@ *$(o) && \
		cd .. && rmdir /s /q $(STATICDIR)
	$(XCOPY) $(PERLSTATICLIB) $(COREDIR)

$(PERLEXE_RES): perlexe.rc $(PERLEXE_MANIFEST) $(PERLEXE_ICO)

..\x2p\a2p$(o) : ..\x2p\a2p.c
	$(CC) -I..\x2p $(CFLAGS) $(OBJOUT_FLAG)$@ -c ..\x2p\a2p.c

..\x2p\hash$(o) : ..\x2p\hash.c
	$(CC) -I..\x2p $(CFLAGS) $(OBJOUT_FLAG)$@ -c ..\x2p\hash.c

..\x2p\str$(o) : ..\x2p\str.c
	$(CC) -I..\x2p $(CFLAGS) $(OBJOUT_FLAG)$@ -c ..\x2p\str.c

..\x2p\util$(o) : ..\x2p\util.c
	$(CC) -I..\x2p $(CFLAGS) $(OBJOUT_FLAG)$@ -c ..\x2p\util.c

..\x2p\walk$(o) : ..\x2p\walk.c
	$(CC) -I..\x2p $(CFLAGS) $(OBJOUT_FLAG)$@ -c ..\x2p\walk.c

$(X2P) : $(HAVEMINIPERL) $(X2P_OBJ) Extensions
	$(MINIPERL) -I..\lib ..\x2p\find2perl.PL
	$(MINIPERL) -I..\lib ..\x2p\s2p.PL
	$(LINK32) -mconsole -o $@ $(BLINK_FLAGS) $(LIBFILES) $(X2P_OBJ)

$(MINIDIR)\globals$(o) : $(GENERATED_HEADERS)

$(UUDMAP_H) $(MG_DATA_H) : $(BITCOUNT_H)

$(BITCOUNT_H) : $(GENUUDMAP)
	$(GENUUDMAP) $(GENERATED_HEADERS)

$(GENUUDMAP) : ..\mg_raw.h
	$(LINK32) $(CFLAGS_O) -o..\generate_uudmap.exe ..\generate_uudmap.c \
	$(BLINK_FLAGS) $(LIBFILES)

#This generates a stub ppport.h & creates & fills /lib/CORE to allow for XS
#building .c->.obj wise (linking is a different thing). This target is AKA
#$(HAVE_COREDIR).
$(COREDIR)\ppport.h : $(CORE_H)
	$(XCOPY) *.h $(COREDIR)\\*.*
	$(RCOPY) include $(COREDIR)\\*.*
	$(XCOPY) ..\\*.h $(COREDIR)\\*.*
	rem. > $@

perlmain.c : runperl.c
	copy runperl.c perlmain.c

perlmain$(o) : runperl.c $(CONFIGPM)
	$(CC) $(subst -DPERLDLL,-UPERLDLL,$(CFLAGS_O)) $(OBJOUT_FLAG)$@ $(PDBOUT) -c runperl.c

perlmainst$(o) : runperl.c $(CONFIGPM)
	$(CC) $(CFLAGS_O) $(OBJOUT_FLAG)$@ $(PDBOUT) -c runperl.c

$(PERLEXE): $(PERLDLL) $(CONFIGPM) $(PERLEXE_OBJ) $(PERLEXE_RES) $(PERLIMPLIB)
	$(LINK32) -mconsole -o $@ $(BLINK_FLAGS)  \
	    $(PERLEXE_OBJ) $(PERLEXE_RES) $(PERLIMPLIB) $(LIBFILES)
	copy $(PERLEXE) $(WPERLEXE)
	$(MINIPERL) -I..\lib bin\exetype.pl $(WPERLEXE) WINDOWS

$(PERLEXESTATIC): $(PERLSTATICLIB) $(CONFIGPM) $(PERLEXEST_OBJ) $(PERLEXE_RES)
	$(LINK32) -mconsole -o $@ $(BLINK_FLAGS) \
	    $(PERLEXEST_OBJ) $(PERLEXE_RES) $(PERLSTATICLIB) $(LIBFILES)

#-------------------------------------------------------------------------------
# There's no direct way to mark a dependency on
# DynaLoader.pm, so this will have to do

MakePPPort: $(HAVEMINIPERL) $(CONFIGPM) Extensions_nonxs
	$(MINIPERL) -I..\lib ..\mkppport


#most of deps of this target are in DYNALOADER and therefore omitted here
Extensions : ..\make_ext.pl ..\lib\buildcustomize.pl $(PERLDEP) $(CONFIGPM) $(DYNALOADER)
	$(XCOPY) ..\\*.h $(COREDIR)\\*.*
	$(MINIPERL) -I..\lib ..\make_ext.pl "MAKE=$(PLMAKE)" --dir=$(CPANDIR) --dir=$(DISTDIR) --dir=$(EXTDIR) --dynamic

Extensions_static : ..\make_ext.pl ..\lib\buildcustomize.pl list_static_libs.pl $(CONFIGPM) Extensions_nonxs
	$(XCOPY) ..\\*.h $(COREDIR)\\*.*
	$(MINIPERL) -I..\lib ..\make_ext.pl "MAKE=$(PLMAKE)" --dir=$(CPANDIR) --dir=$(DISTDIR) --dir=$(EXTDIR) --static
	$(MINIPERL) -I..\lib list_static_libs.pl > Extensions_static

Extensions_nonxs : ..\make_ext.pl ..\lib\buildcustomize.pl $(PERLDEP) $(CONFIGPM) ..\pod\perlfunc.pod
	$(XCOPY) ..\\*.h $(COREDIR)\\*.*
	$(MINIPERL) -I..\lib ..\make_ext.pl "MAKE=$(PLMAKE)" --dir=$(CPANDIR) --dir=$(DISTDIR) --dir=$(EXTDIR) --nonxs

#lib must be built, it can't be buildcustomize.pl-ed, and is required for XS building
$(DYNALOADER) : ..\make_ext.pl ..\lib\buildcustomize.pl $(PERLDEP) $(CONFIGPM) Extensions_nonxs
	$(XCOPY) ..\\*.h $(COREDIR)\\*.*
	$(MINIPERL) -I..\lib ..\make_ext.pl "MAKE=$(PLMAKE)" --dir=$(EXTDIR) --dynaloader

#-------------------------------------------------------------------------------

doc: $(PERLEXE) ..\pod\perltoc.pod
	$(PERLEXE) -I..\lib ..\installhtml --podroot=.. --htmldir=$(HTMLDIR) \
	    --podpath=pod:lib:utils --htmlroot="file://$(subst :,|,$(INST_HTML))"\
	    --recurse

..\utils\Makefile: $(CONFIGPM) ..\utils\Makefile.PL
	$(MINIPERL) -I..\lib ..\utils\Makefile.PL ..

# Note that this next section is parsed (and regenerated) by pod/buildtoc
# so please check that script before making structural changes here
utils: $(HAVEMINIPERL) $(X2P) ..\utils\Makefile
	cd ..\utils && $(PLMAKE) PERL=$(MINIPERL)
	copy ..\README.aix      ..\pod\perlaix.pod
	copy ..\README.amiga    ..\pod\perlamiga.pod
	copy ..\README.android  ..\pod\perlandroid.pod
	copy ..\README.bs2000   ..\pod\perlbs2000.pod
	copy ..\README.ce       ..\pod\perlce.pod
	copy ..\README.cn       ..\pod\perlcn.pod
	copy ..\README.cygwin   ..\pod\perlcygwin.pod
	copy ..\README.dos      ..\pod\perldos.pod
	copy ..\README.freebsd  ..\pod\perlfreebsd.pod
	copy ..\README.haiku    ..\pod\perlhaiku.pod
	copy ..\README.hpux     ..\pod\perlhpux.pod
	copy ..\README.hurd     ..\pod\perlhurd.pod
	copy ..\README.irix     ..\pod\perlirix.pod
	copy ..\README.jp       ..\pod\perljp.pod
	copy ..\README.ko       ..\pod\perlko.pod
	copy ..\README.linux    ..\pod\perllinux.pod
	copy ..\README.macos    ..\pod\perlmacos.pod
	copy ..\README.macosx   ..\pod\perlmacosx.pod
	copy ..\README.netware  ..\pod\perlnetware.pod
	copy ..\README.openbsd  ..\pod\perlopenbsd.pod
	copy ..\README.os2      ..\pod\perlos2.pod
	copy ..\README.os390    ..\pod\perlos390.pod
	copy ..\README.os400    ..\pod\perlos400.pod
	copy ..\README.plan9    ..\pod\perlplan9.pod
	copy ..\README.qnx      ..\pod\perlqnx.pod
	copy ..\README.riscos   ..\pod\perlriscos.pod
	copy ..\README.solaris  ..\pod\perlsolaris.pod
	copy ..\README.symbian  ..\pod\perlsymbian.pod
	copy ..\README.synology ..\pod\perlsynology.pod
	copy ..\README.tru64    ..\pod\perltru64.pod
	copy ..\README.tw       ..\pod\perltw.pod
	copy ..\README.vos      ..\pod\perlvos.pod
	copy ..\README.win32    ..\pod\perlwin32.pod
	copy ..\pod\perldelta.pod ..\pod\perl__PERL_VERSION__delta.pod
	$(MINIPERL) -I..\lib $(PL2BAT) $(UTILS)
	$(MINIPERL) -I..\lib ..\autodoc.pl ..
	$(MINIPERL) -I..\lib ..\pod\perlmodlib.PL -q ..

..\pod\perltoc.pod: $(PERLEXE) Extensions Extensions_nonxs
	$(PERLEXE) -f ..\pod\buildtoc -q

install : all installbare installhtml

installbare : utils ..\pod\perltoc.pod
	$(PERLEXE) ..\installperl
	if exist $(WPERLEXE) $(XCOPY) $(WPERLEXE) $(INST_BIN)\$(NULL)
	if exist $(PERLEXESTATIC) $(XCOPY) $(PERLEXESTATIC) $(INST_BIN)\$(NULL)
	$(XCOPY) $(GLOBEXE) $(INST_BIN)\$(NULL)
	if exist ..\perl*.pdb $(XCOPY) ..\perl*.pdb $(INST_BIN)\$(NULL)
	if exist ..\x2p\a2p.pdb $(XCOPY) ..\x2p\a2p.pdb $(INST_BIN)\$(NULL)
	$(XCOPY) "bin\*.bat" $(INST_SCRIPT)\$(NULL)

installhtml : doc
	$(RCOPY) $(HTMLDIR)\*.* $(INST_HTML)\$(NULL)

inst_lib : $(CONFIGPM)
	$(RCOPY) ..\lib $(INST_LIB)\$(NULL)

$(UNIDATAFILES) : ..\pod\perluniprops.pod

..\pod\perluniprops.pod: ..\lib\unicore\mktables $(CONFIGPM) $(HAVEMINIPERL) ..\lib\unicore\mktables Extensions_nonxs
	$(MINIPERL) -I..\lib ..\lib\unicore\mktables -C ..\lib\unicore -P ..\pod -maketest -makelist -p
MAKEFILE
    my @v = split /[.]/, $version;
    $makefile =~ s/__PERL_MINOR_VERSION__/$v[0]$v[1]/g;
    $makefile =~ s/__PERL_VERSION__/$v[0]$v[1]$v[2]/g;
}

1;
