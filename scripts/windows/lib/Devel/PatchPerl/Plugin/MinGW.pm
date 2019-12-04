package Devel::PatchPerl::Plugin::MinGW;

use utf8;
use strict;
use warnings;
use 5.026002;
use version;
use Devel::PatchPerl;
use File::pushd qw[pushd];
use File::Spec;

# copy utility functions from Devel::PatchPerl
*_is = *Devel::PatchPerl::_is;
*_patch = *Devel::PatchPerl::_patch;

my @patch = (
    {
        perl => [
            qr/^5\.2[0-2]\./,
            qr/^5\.1[0-9]\./,
            qr/^5\.[0-9]\./,
        ],
        subs => [
            [ \&_patch_make_maker ],
        ],
    },
    {
        perl => [
            qr/^5\.22\./,
        ],
        subs => [
            [ \&_patch_gnumakefile_522 ],
        ],
    },
    {
        perl => [
            qr/^5\.21\.8$/,
        ],
        subs => [
            [ \&_patch_sdbm ],
        ],
    },
    {
        perl => [
            qr/^5\.21\.[0-9]+$/,
            qr/^5\.20\.[012]$/,
            qr/^5\.20\.[012][-_]/,
            qr/^5\.1[0-9]\./,
            qr/^5\.[0-9]\./,
        ],
        subs => [
            [ \&_patch_win32_mkstemp ],
        ],
    },
    {
        perl => [
            qr/^5\.21\.[0-6]$/,
            qr/^5\.20\.[01]$/,
            qr/^5\.18\./,
        ],
        subs => [
            [ \&_patch_installperl ],
        ],
    },
    {
        perl => [
            qr/^5\.21\.[0-5]$/,
            qr/^5\.20\./,
            qr/^5\.19\.1[0-9]+$/,
            qr/^5\.19\.[3-9]$/,
        ],
        subs => [
            [ \&_patch_make_maker_dirfilesep ],
        ],
    },
    {
        perl => [
            qr/^5\.19.[0-2]$/,
            qr/^5\.1[78]\./,
        ],
        subs => [
            [ \&_patch_make_maker_dirfilesep_518 ],
        ],
    },
    {
        perl => [
            qr/^5\.21\.[1-9][0-9]*$/,
        ],
        subs => [
            [ \&_patch_gnumakefile_521_1 ],
        ],
    },
    {
        perl => [
            qr/^5\.21\.0$/,
            qr/^5\.20\./,
        ],
        subs => [
            [ \&_patch_gnumakefile_520 ],
        ],
    },
    {
        perl => [
            qr/^5\.19\.[4-9]$/,
            qr/^5\.19\.1[0-9]+$/,
        ],
        subs => [
            [ \&_patch_convert_errno_to_wsa_error ],
        ],
    },
    {
        perl => [
            qr/^5\.1[789]\./,
        ],
        subs => [
            [ \&_patch_gnumakefile_518 ],
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
#INST_VER	:= \__INST_VER__

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

..\utils\Makefile: $(HAVEMINIPERL) $(CONFIGPM) ..\utils\Makefile.PL
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
    $makefile =~ s/__INST_VER__/$version/g;
    $makefile =~ s/__PERL_MINOR_VERSION__/$v[0]$v[1]/g;
    $makefile =~ s/__PERL_VERSION__/$v[0]$v[1]$v[2]/g;
    _write_or_die(File::Spec->catfile("win32", "GNUMakefile"), $makefile);
}

sub _patch_sdbm {
    _patch(<<'PATCH');
--- ext/SDBM_File/sdbm.h
+++ ext/SDBM_File/sdbm.h
@@ -51,7 +51,7 @@ typedef struct {
        int dsize;
 } datum;

-EXTCONST datum nullitem
+extern const datum nullitem
 #ifdef DOINIT
                         = {0, 0}
 #endif
PATCH
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

sub _patch_installperl {
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
PATCH
}

sub _patch_make_maker_dirfilesep {
    _patch(<<'PATCH');
--- cpan/ExtUtils-MakeMaker/lib/ExtUtils/MM_Win32.pm
+++ cpan/ExtUtils-MakeMaker/lib/ExtUtils/MM_Win32.pm
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
PATCH
}

sub _patch_make_maker_dirfilesep_518 {
    # _patch_make_maker_dirfilesep_518 is same as _patch_make_maker_dirfilesep
    # except ' ' after `"\$(PERLRUN) $self->{PERL_SRC}/win32/bin/pl2bat.pl" :`
    _patch(<<'PATCH');
--- cpan/ExtUtils-MakeMaker/lib/ExtUtils/MM_Win32.pm
+++ cpan/ExtUtils-MakeMaker/lib/ExtUtils/MM_Win32.pm
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
PATCH
}

sub _patch_gnumakefile_521_1 {
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
#INST_VER	:= \__INST_VER__

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
		..\utils\piconv		\
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

..\utils\Makefile: $(HAVEMINIPERL) $(CONFIGPM) ..\utils\Makefile.PL
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
    $makefile =~ s/__INST_VER__/$version/g;
    $makefile =~ s/__PERL_MINOR_VERSION__/$v[0]$v[1]/g;
    $makefile =~ s/__PERL_VERSION__/$v[0]$v[1]$v[2]/g;
    if ($v[2] >= 10) {
        $makefile =~ s/\\mro\./\\mro_core./g;
    }
    _write_or_die(File::Spec->catfile("win32", "GNUMakefile"), $makefile);
}

sub _patch_gnumakefile_520 {
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
#INST_VER	:= \__INST_VER__

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

..\utils\Makefile: $(HAVEMINIPERL) $(CONFIGPM) ..\utils\Makefile.PL
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
    $makefile =~ s/__INST_VER__/$version/g;
    $makefile =~ s/__PERL_MINOR_VERSION__/$v[0]$v[1]/g;
    $makefile =~ s/__PERL_VERSION__/$v[0]$v[1]$v[2]/g;
    if ($version =~ /^5\.21\./) {
        $makefile =~ s/\s+\.\.\\utils\\config_data\s*\\//;
    }
    _write_or_die(File::Spec->catfile("win32", "GNUMakefile"), $makefile);
}

sub _patch_convert_errno_to_wsa_error {
    _patch(<<'PATCH');
--- win32/win32sck.c
+++ win32/win32sck.c
@@ -54,6 +54,10 @@ static struct servent* win32_savecopyservent(struct servent*d,
 
 static int wsock_started = 0;
 
+#ifdef WIN32_DYN_IOINFO_SIZE
+EXTERN_C Size_t w32_ioinfo_size;
+#endif
+
 EXTERN_C void
 EndSockets(void)
 {
@@ -208,8 +216,10 @@ convert_errno_to_wsa_error(int err)
 	return WSAEAFNOSUPPORT;
     case EALREADY:
 	return WSAEALREADY;
-    case EBADMSG:
+#ifdef EBADMSG
+    case EBADMSG:			/* Not defined in gcc-4.8.0 */
 	return ERROR_INVALID_FUNCTION;
+#endif
     case ECANCELED:
 #ifdef WSAECANCELLED
 	return WSAECANCELLED;		/* New in WinSock2 */
@@ -226,8 +236,10 @@ convert_errno_to_wsa_error(int err)
 	return WSAEDESTADDRREQ;
     case EHOSTUNREACH:
 	return WSAEHOSTUNREACH;
-    case EIDRM:
+#ifdef EIDRM
+    case EIDRM:				/* Not defined in gcc-4.8.0 */
 	return ERROR_INVALID_FUNCTION;
+#endif
     case EINPROGRESS:
 	return WSAEINPROGRESS;
     case EISCONN:
@@ -244,30 +256,44 @@ convert_errno_to_wsa_error(int err)
 	return WSAENETUNREACH;
     case ENOBUFS:
 	return WSAENOBUFS;
-    case ENODATA:
+#ifdef ENODATA
+    case ENODATA:			/* Not defined in gcc-4.8.0 */
 	return ERROR_INVALID_FUNCTION;
-    case ENOLINK:
+#endif
+#ifdef ENOLINK
+    case ENOLINK:			/* Not defined in gcc-4.8.0 */
 	return ERROR_INVALID_FUNCTION;
-    case ENOMSG:
+#endif
+#ifdef ENOMSG
+    case ENOMSG:			/* Not defined in gcc-4.8.0 */
 	return ERROR_INVALID_FUNCTION;
+#endif
     case ENOPROTOOPT:
 	return WSAENOPROTOOPT;
-    case ENOSR:
+#ifdef ENOSR
+    case ENOSR:				/* Not defined in gcc-4.8.0 */
 	return ERROR_INVALID_FUNCTION;
-    case ENOSTR:
+#endif
+#ifdef ENOSTR
+    case ENOSTR:			/* Not defined in gcc-4.8.0 */
 	return ERROR_INVALID_FUNCTION;
+#endif
     case ENOTCONN:
 	return WSAENOTCONN;
-    case ENOTRECOVERABLE:
+#ifdef ENOTRECOVERABLE
+    case ENOTRECOVERABLE:		/* Not defined in gcc-4.8.0 */
 	return ERROR_INVALID_FUNCTION;
+#endif
     case ENOTSOCK:
 	return WSAENOTSOCK;
     case ENOTSUP:
 	return ERROR_INVALID_FUNCTION;
     case EOPNOTSUPP:
 	return WSAEOPNOTSUPP;
-    case EOTHER:
+#ifdef EOTHER
+    case EOTHER:			/* Not defined in gcc-4.8.0 */
 	return ERROR_INVALID_FUNCTION;
+#endif
     case EOVERFLOW:
 	return ERROR_INVALID_FUNCTION;
     case EOWNERDEAD:
@@ -278,12 +304,16 @@ convert_errno_to_wsa_error(int err)
 	return WSAEPROTONOSUPPORT;
     case EPROTOTYPE:
 	return WSAEPROTOTYPE;
-    case ETIME:
+#ifdef ETIME
+    case ETIME:				/* Not defined in gcc-4.8.0 */
 	return ERROR_INVALID_FUNCTION;
+#endif
     case ETIMEDOUT:
 	return WSAETIMEDOUT;
-    case ETXTBSY:
+#ifdef ETXTBSY
+    case ETXTBSY:			/* Not defined in gcc-4.8.0 */
 	return ERROR_INVALID_FUNCTION;
+#endif
     case EWOULDBLOCK:
 	return WSAEWOULDBLOCK;
     }
@@ -663,8 +693,10 @@ int my_close(int fd)
 	int err;
 	err = closesocket(osf);
 	if (err == 0) {
-	    (void)close(fd);	/* handle already closed, ignore error */
-	    return 0;
+	    assert(_osfhnd(fd) == osf); /* catch a bad ioinfo struct def */
+	    /* don't close freed handle */
+	    _set_osfhnd(fd, INVALID_HANDLE_VALUE);
+	    return close(fd);
 	}
 	else if (err == SOCKET_ERROR) {
 	    err = get_last_socket_error();
@@ -691,8 +723,10 @@ my_fclose (FILE *pf)
 	win32_fflush(pf);
 	err = closesocket(osf);
 	if (err == 0) {
-	    (void)fclose(pf);	/* handle already closed, ignore error */
-	    return 0;
+	    assert(_osfhnd(win32_fileno(pf)) == osf); /* catch a bad ioinfo struct def */
+	    /* don't close freed handle */
+	    _set_osfhnd(win32_fileno(pf), INVALID_HANDLE_VALUE);
+	    return fclose(pf);
 	}
 	else if (err == SOCKET_ERROR) {
 	    err = get_last_socket_error();
PATCH
}

sub _patch_gnumakefile_518 {
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
#INST_VER	:= \__INST_VER__

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
MINIMOD	= ..\lib\ExtUtils\Miniperl.pm
X2P		= ..\x2p\a2p.exe
GENUUDMAP	= ..\generate_uudmap.exe
PERLSTATIC	=

# Unicode data files generated by mktables
FIRSTUNIFILE     = ..\lib\unicore\Decomposition.pl
UNIDATAFILES	 = ..\lib\unicore\Decomposition.pl \
		   ..\lib\unicore\CombiningClass.pl ..\lib\unicore\Name.pl \
		   ..\lib\unicore\Heavy.pl ..\lib\unicore\mktables.lst     \
		   ..\lib\unicore\UCD.pl ..\lib\unicore\Name.pm            \
		   ..\lib\unicore\TestProp.pl

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
		..\utils\cpanp-run-perl	\
		..\utils\cpanp	\
		..\utils\cpan2dist	\
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
		..\perlsfio.h	\
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
#  - Win32 extension contains overlapped symbols with win32.c (BUG!)
#  - MakeMaker isn't capable enough for SDBM_File (smaller bug)
#  - Encode (encoding search algorithm relies on shared library?)
STATIC_EXT	= * !Win32 !SDBM_File !Encode
else
# specify static extensions here, for example:
#STATIC_EXT	= Cwd Compress/Raw/Zlib
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

ICWD = -I..\dist\Cwd -I..\dist\Cwd\lib

#
# Top targets
#

.PHONY: all

all : .\config.h ..\git_version.h $(GLOBEXE) $(MINIMOD) $(CONFIGPM) \
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
	-$(MINIPERL) -I..\lib $(ICWD) config_h.PL "ARCHPREFIX=$(ARCHPREFIX)"

# See the comment in Makefile.SH explaining this seemingly cranky ordering
..\lib\buildcustomize.pl : $(MINI_OBJ) ..\write_buildcustomize.pl
	$(LINK32) -mconsole -o $(MINIPERL) $(BLINK_FLAGS) $(MINI_OBJ) $(LIBFILES)
	$(MINIPERL) -I..\lib -f ..\write_buildcustomize.pl .. >..\lib\buildcustomize.pl

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

$(MINIMOD) : $(HAVEMINIPERL) ..\minimod.pl
	cd .. && miniperl minimod.pl > lib\ExtUtils\Miniperl.pm && cd win32

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
	$(MINIPERL) -I..\lib $(ICWD) ..\mkppport


#most of deps of this target are in DYNALOADER and therefore omitted here
Extensions : ..\make_ext.pl ..\lib\buildcustomize.pl $(PERLDEP) $(CONFIGPM) $(DYNALOADER)
	$(XCOPY) ..\\*.h $(COREDIR)\\*.*
	$(MINIPERL) -I..\lib $(ICWD) ..\make_ext.pl "MAKE=$(PLMAKE)" --dir=$(CPANDIR) --dir=$(DISTDIR) --dir=$(EXTDIR) --dynamic

Extensions_static : ..\make_ext.pl ..\lib\buildcustomize.pl list_static_libs.pl $(CONFIGPM) Extensions_nonxs
	$(XCOPY) ..\\*.h $(COREDIR)\\*.*
	$(MINIPERL) -I..\lib $(ICWD) ..\make_ext.pl "MAKE=$(PLMAKE)" --dir=$(CPANDIR) --dir=$(DISTDIR) --dir=$(EXTDIR) --static
	$(MINIPERL) -I..\lib $(ICWD) list_static_libs.pl > Extensions_static

Extensions_nonxs : ..\make_ext.pl ..\lib\buildcustomize.pl $(PERLDEP) $(CONFIGPM) ..\pod\perlfunc.pod
	$(XCOPY) ..\\*.h $(COREDIR)\\*.*
	$(MINIPERL) -I..\lib $(ICWD) ..\make_ext.pl "MAKE=$(PLMAKE)" --dir=$(CPANDIR) --dir=$(DISTDIR) --dir=$(EXTDIR) --nonxs

#lib must be built, it can't be buildcustomize.pl-ed, and is required for XS building
$(DYNALOADER) : ..\make_ext.pl ..\lib\buildcustomize.pl $(PERLDEP) $(CONFIGPM) Extensions_nonxs
	$(XCOPY) ..\\*.h $(COREDIR)\\*.*
	$(MINIPERL) -I..\lib $(ICWD) ..\make_ext.pl "MAKE=$(PLMAKE)" --dir=$(EXTDIR) --dynaloader

#-------------------------------------------------------------------------------

doc: $(PERLEXE) ..\pod\perltoc.pod
	$(PERLEXE) -I..\lib ..\installhtml --podroot=.. --htmldir=$(HTMLDIR) \
	    --podpath=pod:lib:utils --htmlroot="file://$(subst :,|,$(INST_HTML))"\
	    --recurse

# perl 5.18.x do not need this, it is for perl 5.19.2
..\utils\Makefile: $(HAVEMINIPERL) $(CONFIGPM) ..\utils\Makefile.PL
	$(MINIPERL) -I..\lib ..\utils\Makefile.PL ..

# Note that this next section is parsed (and regenerated) by pod/buildtoc
# so please check that script before making structural changes here
utils: $(PERLEXE) $(X2P)
	cd ..\utils && $(PLMAKE) PERL=$(MINIPERL)
	copy ..\README.aix      ..\pod\perlaix.pod
	copy ..\README.amiga    ..\pod\perlamiga.pod
	copy ..\README.bs2000   ..\pod\perlbs2000.pod
	copy ..\README.ce       ..\pod\perlce.pod
	copy ..\README.cn       ..\pod\perlcn.pod
	copy ..\README.cygwin   ..\pod\perlcygwin.pod
	copy ..\README.dgux     ..\pod\perldgux.pod
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
	copy ..\README.tru64    ..\pod\perltru64.pod
	copy ..\README.tw       ..\pod\perltw.pod
	copy ..\README.vos      ..\pod\perlvos.pod
	copy ..\README.win32    ..\pod\perlwin32.pod
	copy ..\pod\perldelta.pod ..\pod\perl__PERL_VERSION__delta.pod
	$(PERLEXE) -I..\lib $(PL2BAT) $(UTILS)
	$(PERLEXE) $(ICWD) ..\autodoc.pl ..
	$(PERLEXE) $(ICWD) ..\pod\perlmodlib.PL -q ..

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
	$(MINIPERL) -I..\lib $(ICWD) ..\lib\unicore\mktables -C ..\lib\unicore -P ..\pod -maketest -makelist -p
MAKEFILE
    my @v = split /[.]/, $version;
    $makefile =~ s/__INST_VER__/$version/g;
    $makefile =~ s/__PERL_MINOR_VERSION__/$v[0]$v[1]/g;
    $makefile =~ s/__PERL_VERSION__/$v[0]$v[1]$v[2]/g;
    if ($version =~ /^5\.19\./) {
        $makefile =~ s/\s+\.\.\\utils\\cpanp-run-perl\s*\\//;
        $makefile =~ s/\s+\.\.\\utils\\cpanp\s*\\//;
        $makefile =~ s/\s+\.\.\\utils\\cpan2dist\s*\\//;
    }
    if (version->parse($version) >= version->parse("v5.19.8")) {
        $makefile =~ s/\s+\.\.\\perlsfio\.h\s*\\//;
    }
    if (version->parse($version) >= version->parse("v5.19.2")) {
        $makefile =~ s/^MINIMOD\s*=.*$//;
        $makefile =~ s/\$\(MINIMOD\)//g;
        $makefile =~ s/^.*minimod.pl.*$//g;
        $makefile =~ s/^ICWD\s*=.*$//;
        $makefile =~ s/\$\(ICWD\)//g;
        $makefile =~ s/^\s*utils\s*:.*$/\$(PERLEXE) $(X2P) ..\\utils\\Makefile/;
    }
    if (version->parse($version) >= version->parse("v5.19.1")) {
        $makefile =~ s/\$\(MINIPERL\)\s+-I\.\.\\lib\s+-f\s+\.\.\\write_buildcustomize\.pl\s+.*/\$(MINIPERL) -I..\\lib -f ..\\write_buildcustomize.pl ../;
        $makefile =~ s/copy\s+\.\.\\README\.dgux\s+\.\.\\pod\\perldgux\.pod//;
    }
    _write_or_die(File::Spec->catfile("win32", "GNUMakefile"), $makefile);
}

1;
