package Devel::PatchPerl::Plugin::MinGWGNUmakefile;

use utf8;
use strict;
use warnings;
use 5.026001;
use version;
use Devel::PatchPerl;
use File::pushd qw[pushd];
use File::Spec;
use Try::Tiny;

# copy utility functions from Devel::PatchPerl
*_is = *Devel::PatchPerl::_is;
*_patch = *Devel::PatchPerl::_patch;

my @patch = (
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
            qr/^5\.2[01]\./,
        ],
        subs => [
            [ \&_patch_gnumakefile_520 ],
        ],
    },
    {
        perl => [
            qr/^5\.1[89]\./,
        ],
        subs => [
            [ \&_patch_gnumakefile_518 ],
        ],
    },
    {
        perl => [
            qr/^5\.1[67]\./,
        ],
        subs => [
            [ \&_patch_gnumakefile_516 ],
        ],
    },
    {
        perl => [
            qr/^5\.1[45]\./,
        ],
        subs => [
            [ \&_patch_gnumakefile_514 ],
        ],
    },
    {
        perl => [
            qr/^5\.1[23]\./,
        ],
        subs => [
            [ \&_patch_gnumakefile_512 ],
        ],
    },
    {
        perl => [
            qr/^5\.1[01]\./,
        ],
        subs => [
            [ \&_patch_gnumakefile_510 ],
        ],
    },
    {
        perl => [
            qr/^5\.9\./,
        ],
        subs => [
            [ \&_patch_gnumakefile_509 ],
        ],
    },
    {
        perl => [
            qr/^5\.8\./,
        ],
        subs => [
            [ \&_patch_gnumakefile_508 ],
        ],
    },
    {
        perl => [
            qr/^5\.7\./,
        ],
        subs => [
            [ \&_patch_gnumakefile_507 ],
        ],
    },
    {
        perl => [
            qr/^5\.6\./,
        ],
        subs => [
            [ \&_patch_gnumakefile_506 ],
        ],
    },
);

sub patchperl {
    my ($class, %args) = @_;
    my $vers = $args{version};
    my $source = $args{source};

    my $dir = pushd( $source );

    # based on https://github.com/bingos/devel-patchperl/blob/acdcf1d67ae426367f42ca763b9ba6b92dd90925/lib/Devel/PatchPerl.pm#L301-L307
    for my $p ( grep { _is( $_->{perl}, $vers ) } @patch ) {
        for my $s (@{$p->{subs}}) {
            my($sub, @args) = @$s;
            push @args, $vers unless scalar @args;
            try {
                $sub->(@args);
            } catch {
                warn "caught error: $_";
            };
        }
    }
}

# it is same as ge operator of strings but it assumes the strings are versions
sub _ge {
    my ($v1, $v2) = @_;
    return version->parse("v$v1") >= version->parse("v$v2");
}

sub _write_or_die {
    my($file, $data) = @_;
    my $fh = IO::File->new(">$file") or die "$file: $!\n";
    $fh->print($data);
}

sub _write_gnumakefile {
    my ($version, $makefile) = @_;
    my @v = split /[.]/, $version;
    $makefile =~ s/__INST_VER__/$version/g;
    $makefile =~ s/__PERL_MINOR_VERSION__/$v[0]$v[1]/g;
    $makefile =~ s/__PERL_VERSION__/$v[0]$v[1]$v[2]/g;

    _write_or_die(File::Spec->catfile("win32", "GNUmakefile"), $makefile);
}

sub _patch_gnumakefile {
    my ($version, $makefile) = @_;
    my @v = split /[.]/, $version;
    $makefile =~ s/__INST_VER__/$version/g;
    $makefile =~ s/__PERL_MINOR_VERSION__/$v[0]$v[1]/g;
    $makefile =~ s/__PERL_VERSION__/$v[0]$v[1]$v[2]/g;
    _patch($makefile);
}

sub _patch_gnumakefile_522 {
    my $version = shift;
    _write_gnumakefile($version, <<'MAKEFILE');
SHELL := cmd.exe
GCCBIN := gcc
INST_DRV := c:
INST_TOP := $(INST_DRV)\perl
#INST_VER	:= \__INST_VER__
#INST_ARCH	:= \$(ARCHNAME)
#USE_SITECUST	:= define
USE_MULTI	:= define
USE_ITHREADS	:= define
USE_IMP_SYS	:= define
USE_PERLIO	:= define
USE_LARGE_FILES	:= define
#USE_64_BIT_INT	:= define
#USE_LONG_DOUBLE :=define
#USE_NO_REGISTRY := define
CCTYPE		:= GCC
#__ICC		:= define
#CFG		:= Debug
#USE_SETARGV	:= define
#PERL_MALLOC	:= define
#DEBUG_MSTATS	:= define
CCHOME		:= C:\MinGW

CCINCDIR := $(CCHOME)\include
CCLIBDIR := $(CCHOME)\lib
CCDLLDIR := $(CCHOME)\bin
ARCHPREFIX :=

BUILDOPT	:= $(BUILDOPTEXTRA)

BUILDOPT	+= -DPERL_TEXTMODE_SCRIPTS

EXTRALIBDIRS	:=


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
DEFINES		= -DWIN32 -DWIN64 -DCONSERVATIVE -DNO_STRICT
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
}

sub _patch_gnumakefile_520 {
    my $version = shift;
    _write_gnumakefile($version, <<'MAKEFILE');
SHELL := cmd.exe
GCCBIN := gcc
INST_DRV := c:
INST_TOP := $(INST_DRV)\perl
#INST_VER	:= \__INST_VER__
#INST_ARCH	:= \$(ARCHNAME)
#USE_SITECUST	:= define
USE_MULTI	:= define
USE_ITHREADS	:= define
USE_IMP_SYS	:= define
USE_PERLIO	:= define
USE_LARGE_FILES	:= define
#USE_64_BIT_INT	:= define
#USE_LONG_DOUBLE :=define
#USE_NO_REGISTRY := define
CCTYPE		:= GCC
#__ICC		:= define
#CFG		:= Debug
#USE_SETARGV	:= define
#PERL_MALLOC	:= define
#DEBUG_MSTATS	:= define
CCHOME		:= C:\MinGW

CCINCDIR := $(CCHOME)\include
CCLIBDIR := $(CCHOME)\lib
CCDLLDIR := $(CCHOME)\bin
ARCHPREFIX :=

BUILDOPT	:= $(BUILDOPTEXTRA)

BUILDOPT	+= -DPERL_TEXTMODE_SCRIPTS

EXTRALIBDIRS	:=


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
DEFINES		= -DWIN32 -DWIN64 -DCONSERVATIVE -DNO_STRICT
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
    if (_ge($version, "5.21.1")) {
        _patch_gnumakefile($version, <<'PATCH');
--- win32/GNUmakefile
+++ win32/GNUmakefile
@@ -279,7 +279,6 @@
 		..\utils\libnetcfg	\
 		..\utils\enc2xs		\
 		..\utils\piconv		\
-		..\utils\config_data	\
 		..\utils\corelist	\
 		..\utils\cpan		\
 		..\utils\xsubpp		\
@@ -292,9 +291,6 @@
 		..\utils\instmodsh	\
 		..\utils\json_pp	\
 		..\utils\pod2html	\
-		..\x2p\find2perl	\
-		..\x2p\psed		\
-		..\x2p\s2p		\
 		bin\exetype.pl		\
 		bin\runperl.pl		\
 		bin\pl2bat.pl		\
@@ -372,13 +368,6 @@
 		.\win32thread.c	\
 		.\fcrypt.c
 
-X2P_SRC		=		\
-		..\x2p\a2p.c	\
-		..\x2p\hash.c	\
-		..\x2p\str.c	\
-		..\x2p\util.c	\
-		..\x2p\walk.c
-
 CORE_NOCFG_H	=		\
 		..\av.h		\
 		..\cop.h	\
@@ -440,7 +429,6 @@
 MINIWIN32_OBJ	= $(subst .\,mini\,$(WIN32_OBJ))
 MINI_OBJ	= $(MINICORE_OBJ) $(MINIWIN32_OBJ)
 DLL_OBJ		= $(DYNALOADER)
-X2P_OBJ		= $(X2P_SRC:.c=$(o))
 PERLDLL_OBJ	= $(CORE_OBJ)
 PERLEXE_OBJ	= perlmain$(o)
 PERLEXEST_OBJ	= perlmainst$(o)
@@ -510,7 +498,7 @@
 .PHONY: all
 
 all : .\config.h ..\git_version.h $(GLOBEXE) $(CONFIGPM) \
-		$(UNIDATAFILES) MakePPPort $(PERLEXE) $(X2P) Extensions_nonxs Extensions $(PERLSTATIC)
+		$(UNIDATAFILES) MakePPPort $(PERLEXE) Extensions_nonxs Extensions $(PERLSTATIC)
 		@echo Everything is up to date. '$(MAKE_BARE) test' to run test suite.
 
 ..\regcomp$(o) : ..\regnodes.h ..\regcharclass.h
@@ -740,8 +728,6 @@
 
 $(DLL_OBJ)	: $(CORE_H)
 
-$(X2P_OBJ)	: $(CORE_H)
-
 perllibst.h : $(HAVEMINIPERL) $(CONFIGPM) create_perllibst_h.pl
 	$(MINIPERL) -I..\lib create_perllibst_h.pl
 
@@ -770,26 +756,6 @@
 
 $(PERLEXE_RES): perlexe.rc $(PERLEXE_MANIFEST) $(PERLEXE_ICO)
 
-..\x2p\a2p$(o) : ..\x2p\a2p.c
-	$(CC) -I..\x2p $(CFLAGS) $(OBJOUT_FLAG)$@ -c ..\x2p\a2p.c
-
-..\x2p\hash$(o) : ..\x2p\hash.c
-	$(CC) -I..\x2p $(CFLAGS) $(OBJOUT_FLAG)$@ -c ..\x2p\hash.c
-
-..\x2p\str$(o) : ..\x2p\str.c
-	$(CC) -I..\x2p $(CFLAGS) $(OBJOUT_FLAG)$@ -c ..\x2p\str.c
-
-..\x2p\util$(o) : ..\x2p\util.c
-	$(CC) -I..\x2p $(CFLAGS) $(OBJOUT_FLAG)$@ -c ..\x2p\util.c
-
-..\x2p\walk$(o) : ..\x2p\walk.c
-	$(CC) -I..\x2p $(CFLAGS) $(OBJOUT_FLAG)$@ -c ..\x2p\walk.c
-
-$(X2P) : $(HAVEMINIPERL) $(X2P_OBJ) Extensions
-	$(MINIPERL) -I..\lib ..\x2p\find2perl.PL
-	$(MINIPERL) -I..\lib ..\x2p\s2p.PL
-	$(LINK32) -mconsole -o $@ $(BLINK_FLAGS) $(LIBFILES) $(X2P_OBJ)
-
 $(MINIDIR)\globals$(o) : $(GENERATED_HEADERS)
 
 $(UUDMAP_H) $(MG_DATA_H) : $(BITCOUNT_H)
@@ -919,7 +885,6 @@
 	if exist $(PERLEXESTATIC) $(XCOPY) $(PERLEXESTATIC) $(INST_BIN)\$(NULL)
 	$(XCOPY) $(GLOBEXE) $(INST_BIN)\$(NULL)
 	if exist ..\perl*.pdb $(XCOPY) ..\perl*.pdb $(INST_BIN)\$(NULL)
-	if exist ..\x2p\a2p.pdb $(XCOPY) ..\x2p\a2p.pdb $(INST_BIN)\$(NULL)
 	$(XCOPY) "bin\*.bat" $(INST_SCRIPT)\$(NULL)
 
 installhtml : doc
PATCH
    }
}

sub _patch_gnumakefile_518 {
    my $version = shift;
    _write_gnumakefile($version, <<'MAKEFILE');
SHELL := cmd.exe
GCCBIN := gcc
INST_DRV := c:
INST_TOP := $(INST_DRV)\perl
#INST_VER	:= \__INST_VER__
#INST_ARCH	:= \$(ARCHNAME)
#USE_SITECUST	:= define
USE_MULTI	:= define
USE_ITHREADS	:= define
USE_IMP_SYS	:= define
USE_PERLIO	:= define
USE_LARGE_FILES	:= define
#USE_64_BIT_INT	:= define
#USE_LONG_DOUBLE :=define
#USE_NO_REGISTRY := define

CCTYPE		:= GCC

#CFG		:= Debug
#USE_SETARGV	:= define
#PERL_MALLOC	:= define
#DEBUG_MSTATS	:= define
CCHOME		:= C:\MinGW

CCINCDIR := $(CCHOME)\include
CCLIBDIR := $(CCHOME)\lib
CCDLLDIR := $(CCHOME)\bin
ARCHPREFIX :=

BUILDOPT	:= $(BUILDOPTEXTRA)

BUILDOPT	+= -DPERL_TEXTMODE_SCRIPTS

EXTRALIBDIRS	:=


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
DEFINES		= -DWIN32 -DWIN64 -DCONSERVATIVE -DNO_STRICT
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
}

sub _patch_gnumakefile_516 {
    my $version = shift;
    _write_gnumakefile($version, <<'MAKEFILE');
SHELL := cmd.exe
GCCBIN := gcc
INST_DRV := c:
INST_TOP := $(INST_DRV)\perl
#INST_VER	:= \__INST_VER__
#INST_ARCH	:= \$(ARCHNAME)
#USE_SITECUST	:= define
USE_MULTI	:= define
USE_ITHREADS	:= define
USE_IMP_SYS	:= define
USE_PERLIO	:= define
USE_LARGE_FILES	:= define
#USE_64_BIT_INT	:= define
#USE_LONG_DOUBLE :=define
#USE_NO_REGISTRY := define
CCTYPE		:= GCC
#CFG		:= Debug
#USE_SETARGV	:= define
#PERL_MALLOC	:= define
#DEBUG_MSTATS	:= define
CCHOME		:= C:\MinGW

CCINCDIR := $(CCHOME)\include
CCLIBDIR := $(CCHOME)\lib
CCDLLDIR := $(CCHOME)\bin
ARCHPREFIX :=

BUILDOPT	:= $(BUILDOPTEXTRA)

BUILDOPT	+= -DPERL_TEXTMODE_SCRIPTS

EXTRALIBDIRS	:=


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
DEFINES		= -DWIN32 -DWIN64 -DCONSERVATIVE -DNO_STRICT
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
	    --podpath=pod:lib:ext:utils --htmlroot="file://$(subst :,|,$(INST_HTML))" \
	    --recurse

# Note that this next section is parsed (and regenerated) by pod/buildtoc
# so please check that script before making structural changes here
utils: $(PERLEXE) $(X2P)
	cd ..\utils && $(PLMAKE) PERL=$(MINIPERL)
	copy ..\README.aix      ..\pod\perlaix.pod
	copy ..\README.amiga    ..\pod\perlamiga.pod
	copy ..\README.beos     ..\pod\perlbeos.pod
	copy ..\README.bs2000   ..\pod\perlbs2000.pod
	copy ..\README.ce       ..\pod\perlce.pod
	copy ..\README.cn       ..\pod\perlcn.pod
	copy ..\README.cygwin   ..\pod\perlcygwin.pod
	copy ..\README.dgux     ..\pod\perldgux.pod
	copy ..\README.dos      ..\pod\perldos.pod
	copy ..\README.epoc     ..\pod\perlepoc.pod
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
	copy ..\README.mpeix    ..\pod\perlmpeix.pod
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
	copy ..\README.uts      ..\pod\perluts.pod
	copy ..\README.vmesa    ..\pod\perlvmesa.pod
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
    if (_ge($version, "5.17.1")) {
        _patch_gnumakefile($version, <<'PATCH');
--- win32/GNUmakefile
+++ win32/GNUmakefile
@@ -857,7 +857,7 @@
 
 doc: $(PERLEXE) ..\pod\perltoc.pod
 	$(PERLEXE) -I..\lib ..\installhtml --podroot=.. --htmldir=$(HTMLDIR) \
-	    --podpath=pod:lib:ext:utils --htmlroot="file://$(subst :,|,$(INST_HTML))" \
+	    --podpath=pod:lib:utils --htmlroot="file://$(subst :,|,$(INST_HTML))"\
 	    --recurse
 
 # Note that this next section is parsed (and regenerated) by pod/buildtoc
PATCH
    }
    if (! -e 'README.uts') { # _ge($version, "5.17.3")
        _patch_gnumakefile($version, <<'PATCH');
--- win32/GNUmakefile
+++ win32/GNUmakefile
@@ -897,7 +897,6 @@
 	copy ..\README.symbian  ..\pod\perlsymbian.pod
 	copy ..\README.tru64    ..\pod\perltru64.pod
 	copy ..\README.tw       ..\pod\perltw.pod
-	copy ..\README.uts      ..\pod\perluts.pod
 	copy ..\README.vmesa    ..\pod\perlvmesa.pod
 	copy ..\README.vos      ..\pod\perlvos.pod
 	copy ..\README.win32    ..\pod\perlwin32.pod
PATCH
    }
    if (! -e 'README.vmesa') { # _ge($version, "5.17.4")
        _patch_gnumakefile($version, <<'PATCH');
--- win32/GNUmakefile
+++ win32/GNUmakefile
@@ -897,7 +897,6 @@
 	copy ..\README.symbian  ..\pod\perlsymbian.pod
 	copy ..\README.tru64    ..\pod\perltru64.pod
 	copy ..\README.tw       ..\pod\perltw.pod
-	copy ..\README.vmesa    ..\pod\perlvmesa.pod
 	copy ..\README.vos      ..\pod\perlvos.pod
 	copy ..\README.win32    ..\pod\perlwin32.pod
 	copy ..\pod\perldelta.pod ..\pod\perl__PERL_VERSION__delta.pod
PATCH
    }
    if (! -e 'README.mpeix') { # _ge($version, "5.17.5")
        _patch_gnumakefile($version, <<'PATCH');
--- win32/GNUmakefile
+++ win32/GNUmakefile
@@ -884,7 +884,6 @@
 	copy ..\README.linux    ..\pod\perllinux.pod
 	copy ..\README.macos    ..\pod\perlmacos.pod
 	copy ..\README.macosx   ..\pod\perlmacosx.pod
-	copy ..\README.mpeix    ..\pod\perlmpeix.pod
 	copy ..\README.netware  ..\pod\perlnetware.pod
 	copy ..\README.openbsd  ..\pod\perlopenbsd.pod
 	copy ..\README.os2      ..\pod\perlos2.pod
PATCH
    }
    if (! -e 'README.epoc') { # _ge($version, "5.17.6")
        _patch_gnumakefile($version, <<'PATCH');
--- win32/GNUmakefile
+++ win32/GNUmakefile
@@ -873,7 +873,6 @@
 	copy ..\README.cygwin   ..\pod\perlcygwin.pod
 	copy ..\README.dgux     ..\pod\perldgux.pod
 	copy ..\README.dos      ..\pod\perldos.pod
-	copy ..\README.epoc     ..\pod\perlepoc.pod
 	copy ..\README.freebsd  ..\pod\perlfreebsd.pod
 	copy ..\README.haiku    ..\pod\perlhaiku.pod
 	copy ..\README.hpux     ..\pod\perlhpux.pod
PATCH
    }
    if (! -e 'README.beos') { # _ge($version, "5.17.7")
        _patch_gnumakefile($version, <<'PATCH');
--- win32/GNUmakefile
+++ win32/GNUmakefile
@@ -866,7 +866,6 @@
 	cd ..\utils && $(PLMAKE) PERL=$(MINIPERL)
 	copy ..\README.aix      ..\pod\perlaix.pod
 	copy ..\README.amiga    ..\pod\perlamiga.pod
-	copy ..\README.beos     ..\pod\perlbeos.pod
 	copy ..\README.bs2000   ..\pod\perlbs2000.pod
 	copy ..\README.ce       ..\pod\perlce.pod
 	copy ..\README.cn       ..\pod\perlcn.pod
PATCH
    }
    if (-e 'hv_func.h') { # ge($version, "5.17.10")
        _patch_gnumakefile($version, <<'PATCH');
--- win32/GNUmakefile
+++ win32/GNUmakefile
@@ -393,6 +393,7 @@
 		..\gv.h		\
 		..\handy.h	\
 		..\hv.h		\
+		..\hv_func.h	\
 		..\iperlsys.h	\
 		..\mg.h		\
 		..\nostdio.h	\
PATCH
    }
}

sub _patch_gnumakefile_514 {
    my $version = shift;
    _write_gnumakefile($version, <<'MAKEFILE');
SHELL := cmd.exe
GCCBIN := gcc
INST_DRV := c:
INST_TOP := $(INST_DRV)\perl
#INST_VER	:= \__INST_VER__
#INST_ARCH	:= \$(ARCHNAME)
#USE_SITECUST	:= define
USE_MULTI	:= define
USE_ITHREADS	:= define
USE_IMP_SYS	:= define
USE_PERLIO	:= define
USE_LARGE_FILES	:= define
#USE_64_BIT_INT	:= define
#USE_LONG_DOUBLE :=define
#USE_NO_REGISTRY := define
CCTYPE		:= GCC
#CFG		:= Debug
#USE_SETARGV	:= define
#PERL_MALLOC	:= define
#DEBUG_MSTATS	:= define
CCHOME		:= C:\MinGW

CCINCDIR := $(CCHOME)\include
CCLIBDIR := $(CCHOME)\lib
CCDLLDIR := $(CCHOME)\bin
ARCHPREFIX :=

BUILDOPT	:= $(BUILDOPTEXTRA)

BUILDOPT	+= -DPERL_TEXTMODE_SCRIPTS

EXTRALIBDIRS	:=


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
DEFINES		= -DWIN32 -DWIN64 -DCONSERVATIVE -DNO_STRICT
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
		..\utils\dprofpp	\
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
		..\utils\cpanp-run-perl	\
		..\utils\cpanp	\
		..\utils\cpan2dist	\
		..\utils\shasum		\
		..\utils\instmodsh	\
		..\utils\json_pp	\
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
GENUUDMAP_OBJ	= $(GENUUDMAP:.exe=$(o))
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

$(GENUUDMAP) : $(GENUUDMAP_OBJ)
	$(LINK32) $(CFLAGS_O) -o $@ $(GENUUDMAP_OBJ) \
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
	    --podpath=pod:lib:ext:utils --htmlroot="file://$(subst :,|,$(INST_HTML))" \
	    --libpods=perlfunc:perlguts:perlvar:perlrun:perlop --recurse

# Note that this next section is parsed (and regenerated) by pod/buildtoc
# so please check that script before making structural changes here
utils: $(PERLEXE) $(X2P)
	cd ..\utils && $(PLMAKE) PERL=$(MINIPERL)
	copy ..\README.aix      ..\pod\perlaix.pod
	copy ..\README.amiga    ..\pod\perlamiga.pod
	copy ..\README.beos     ..\pod\perlbeos.pod
	copy ..\README.bs2000   ..\pod\perlbs2000.pod
	copy ..\README.ce       ..\pod\perlce.pod
	copy ..\README.cn       ..\pod\perlcn.pod
	copy ..\README.cygwin   ..\pod\perlcygwin.pod
	copy ..\README.dgux     ..\pod\perldgux.pod
	copy ..\README.dos      ..\pod\perldos.pod
	copy ..\README.epoc     ..\pod\perlepoc.pod
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
	copy ..\README.mpeix    ..\pod\perlmpeix.pod
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
	copy ..\README.uts      ..\pod\perluts.pod
	copy ..\README.vmesa    ..\pod\perlvmesa.pod
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
    if (! -e 'utils\dprofpp') { # _ge($version, "5.15.0")
        _patch_gnumakefile($version, <<'PATCH');
--- win32/GNUmakefile
+++ win32/GNUmakefile
@@ -271,7 +271,6 @@
 UTILS		=			\
 		..\utils\h2ph		\
 		..\utils\splain		\
-		..\utils\dprofpp	\
 		..\utils\perlbug	\
 		..\utils\pl2pm 		\
 		..\utils\c2ph		\
PATCH
    }
}

sub _patch_gnumakefile_512 {
    my $version = shift;
    _write_gnumakefile($version, <<'MAKEFILE');
SHELL := cmd.exe
GCCBIN := gcc
INST_DRV := c:
INST_TOP := $(INST_DRV)\perl
#INST_VER	:= \__INST_VER__
#INST_ARCH	:= \$(ARCHNAME)
#USE_SITECUST	:= define
USE_MULTI	:= define
USE_ITHREADS	:= define
USE_IMP_SYS	:= define
USE_PERLIO	:= define
USE_LARGE_FILES	:= define
#USE_64_BIT_INT	:= define
#USE_LONG_DOUBLE :=define
CCTYPE		:= GCC
#CFG		:= Debug
#USE_PERLCRT	= define
#USE_SETARGV	:= define
CRYPT_SRC      = fcrypt.c
#CRYPT_LIB     = -lfcrypt
#PERL_MALLOC	:= define
#DEBUG_MSTATS	:= define
CCHOME		:= C:\MinGW

CCINCDIR := $(CCHOME)\include
CCLIBDIR := $(CCHOME)\lib
CCDLLDIR := $(CCHOME)\bin
ARCHPREFIX :=
BUILDOPT	:= $(BUILDOPTEXTRA)
BUILDOPT	+= -DPERL_TEXTMODE_SCRIPTS

EXTRALIBDIRS	:=


PERL_MALLOC	?= undef
DEBUG_MSTATS	?= undef
USE_PERLCRT	?= undef

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

ifeq ("$(CRYPT_SRC)$(CRYPT_LIB)","")
D_CRYPT		= undef
else
D_CRYPT		= define
CRYPT_FLAG	= -DHAVE_DES_FCRYPT
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
DEFINES		= -DWIN32 -DWIN64 -DCONSERVATIVE -DNO_STRICT $(CRYPT_FLAG)
LOCDEFS		= -DPERLDLL -DPERL_CORE
CXX_FLAG	= -xc++
LIBC		=
LIBFILES	= $(LIBC) $(CRYPT_LIB) -lmoldname -lkernel32 -luser32 -lgdi32 -lwinspool \
	-lcomdlg32 -ladvapi32 -lshell32 -lole32 -loleaut32 -lnetapi32 \
	-luuid -lws2_32 -lmpr -lwinmm -lversion -lodbc32 -lodbccp32 -lcomctl32

ifeq ($(CFG),Debug)
OPTIMIZE	= -g -O2 -DDEBUGGING
LINK_DBG	= -g
else
# It seems that there are some Undefined Behavior.
# diable optimization to cause unexpected hebavior.
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
HAVEMINIPERL	= .have_miniperl
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
		..\utils\dprofpp	\
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
		..\utils\cpanp-run-perl	\
		..\utils\cpanp	\
		..\utils\cpan2dist	\
		..\utils\shasum		\
		..\utils\instmodsh	\
		..\pod\pod2html		\
		..\pod\pod2latex	\
		..\pod\pod2man		\
		..\pod\pod2text		\
		..\pod\pod2usage	\
		..\pod\podchecker	\
		..\pod\podselect	\
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
		..\mathoms.c	\
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
		.\win32sck.c	\
		.\win32thread.c	\
		.\win32io.c

ifneq ("$(CRYPT_SRC)", "")
WIN32_SRC	+= .\$(CRYPT_SRC)
endif

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
GENUUDMAP_OBJ	= $(GENUUDMAP:.exe=$(o))
PERLDLL_OBJ	= $(CORE_OBJ)
PERLEXE_OBJ	= perlmain$(o)
PERLEXEST_OBJ	= perlmainst$(o)

PERLDLL_OBJ	+= $(WIN32_OBJ) $(DLL_OBJ)

ifneq ($(USE_SETARGV),)
SETARGV_OBJ	= setargv$(o)
endif

STATIC_EXT	= Win32CORE

DYNALOADER	= ..\DynaLoader$(o)

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

ICWD = -I..\cpan\Cwd -I..\cpan\Cwd\lib

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

$(CONFIGPM) : $(HAVEMINIPERL) ..\config.sh config_h.PL ..\minimod.pl
	$(MINIPERL) -I..\lib ..\configpm --chdir=..
	$(XCOPY) *.h $(COREDIR)\\*.*
	$(XCOPY) ..\\ext\\re\\re.pm $(LIBDIR)\\*.*
	$(RCOPY) include $(COREDIR)\\*.*
	$(XCOPY) ..\\*.h $(COREDIR)\\*.*
	-$(MINIPERL) -I..\lib $(ICWD) config_h.PL "ARCHPREFIX=$(ARCHPREFIX)"

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

perllib$(o)	: perllib.c perllibst.h .\perlhost.h .\vdir.h .\vmem.h
ifeq ($(USE_IMP_SYS),define)
	$(CC) -c -I. $(CFLAGS_O) $(CXX_FLAG) $(OBJOUT_FLAG)$@ $(PDBOUT) perllib.c
else
	$(CC) -c -I. $(CFLAGS_O) $(OBJOUT_FLAG)$@ $(PDBOUT) perllib.c
endif

$(MINI_OBJ)	: $(MINIDIR)\.exists $(CORE_NOCFG_H)

$(WIN32_OBJ)	: $(CORE_H)

$(CORE_OBJ)	: $(CORE_H)

$(DLL_OBJ)	: $(CORE_H)

$(X2P_OBJ)	: $(CORE_H)

perllibst.h : $(HAVEMINIPERL) $(CONFIGPM) create_perllibst_h.pl
	$(MINIPERL) -I..\lib create_perllibst_h.pl

perldll.def : $(HAVEMINIPERL) $(CONFIGPM) ..\global.sym ..\pp.sym ..\makedef.pl create_perllibst_h.pl
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

$(MINIDIR)\globals$(o) : $(UUDMAP_H) $(BITCOUNT_H)

$(UUDMAP_H) $(BITCOUNT_H) : $(GENUUDMAP)
	$(GENUUDMAP) $(UUDMAP_H) $(BITCOUNT_H)

$(GENUUDMAP) : $(GENUUDMAP_OBJ)
	$(LINK32) $(CFLAGS_O) -o $@ $(GENUUDMAP_OBJ) \
	$(BLINK_FLAGS) $(LIBFILES)

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

MakePPPort: $(HAVEMINIPERL) $(CONFIGPM) Extensions_nonxs
	$(MINIPERL) -I..\lib $(ICWD) ..\mkppport

$(HAVEMINIPERL): $(MINI_OBJ)
	$(LINK32) -mconsole -o $(MINIPERL) $(BLINK_FLAGS) $(MINI_OBJ) $(LIBFILES)
	rem . > $@

Extensions : ..\make_ext.pl $(HAVEMINIPERL) $(PERLDEP) $(CONFIGPM) $(DYNALOADER)
	$(XCOPY) ..\\*.h $(COREDIR)\\*.*
	$(MINIPERL) -I..\lib $(ICWD) ..\make_ext.pl "MAKE=$(PLMAKE)" --dir=$(CPANDIR) --dir=$(DISTDIR) --dir=$(EXTDIR) --dynamic

Extensions_reonly : ..\make_ext.pl $(HAVEMINIPERL) $(PERLDEP) $(CONFIGPM) $(DYNALOADER)
	$(XCOPY) ..\\*.h $(COREDIR)\\*.*
	$(MINIPERL) -I..\lib $(ICWD) ..\make_ext.pl "MAKE=$(PLMAKE)" --dir=$(CPANDIR) --dir=$(DISTDIR) --dir=$(EXTDIR) --dynamic +re

Extensions_static : ..\make_ext.pl $(HAVEMINIPERL) list_static_libs.pl $(CONFIGPM) Extensions_nonxs
	$(XCOPY) ..\\*.h $(COREDIR)\\*.*
	$(MINIPERL) -I..\lib $(ICWD) ..\make_ext.pl "MAKE=$(PLMAKE)" --dir=$(CPANDIR) --dir=$(DISTDIR) --dir=$(EXTDIR) --static
	$(MINIPERL) -I..\lib $(ICWD) list_static_libs.pl > Extensions_static

Extensions_nonxs : ..\make_ext.pl $(HAVEMINIPERL) $(PERLDEP) $(CONFIGPM) ..\pod\perlfunc.pod
	$(XCOPY) ..\\*.h $(COREDIR)\\*.*
	$(MINIPERL) -I..\lib $(ICWD) ..\make_ext.pl "MAKE=$(PLMAKE)" --dir=$(CPANDIR) --dir=$(DISTDIR) --dir=$(EXTDIR) --nonxs

$(DYNALOADER) : ..\make_ext.pl $(HAVEMINIPERL) $(PERLDEP) $(CONFIGPM) Extensions_nonxs
	$(XCOPY) ..\\*.h $(COREDIR)\\*.*
	$(MINIPERL) -I..\lib $(ICWD) ..\make_ext.pl "MAKE=$(PLMAKE)" --dir=$(EXTDIR) --dynaloader

#-------------------------------------------------------------------------------

doc: $(PERLEXE) ..\pod\perltoc.pod
	$(PERLEXE) -I..\lib ..\installhtml --podroot=.. --htmldir=$(HTMLDIR) \
	    --podpath=pod:lib:ext:utils --htmlroot="file://$(subst :,|,$(INST_HTML))" \
	    --libpod=perlfunc:perlguts:perlvar:perlrun:perlop --recurse

utils: $(PERLEXE) $(X2P)
	cd ..\utils && $(PLMAKE) PERL=$(MINIPERL)
	copy ..\README.aix      ..\pod\perlaix.pod
	copy ..\README.amiga    ..\pod\perlamiga.pod
	copy ..\README.apollo   ..\pod\perlapollo.pod
	copy ..\README.beos     ..\pod\perlbeos.pod
	copy ..\README.bs2000   ..\pod\perlbs2000.pod
	copy ..\README.ce       ..\pod\perlce.pod
	copy ..\README.cn       ..\pod\perlcn.pod
	copy ..\README.cygwin   ..\pod\perlcygwin.pod
	copy ..\README.dgux     ..\pod\perldgux.pod
	copy ..\README.dos      ..\pod\perldos.pod
	copy ..\README.epoc     ..\pod\perlepoc.pod
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
	copy ..\README.mpeix    ..\pod\perlmpeix.pod
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
	copy ..\README.uts      ..\pod\perluts.pod
	copy ..\README.vmesa    ..\pod\perlvmesa.pod
	copy ..\README.vos      ..\pod\perlvos.pod
	copy ..\README.win32    ..\pod\perlwin32.pod
	copy ..\pod\perl__PERL_VERSION__delta.pod ..\pod\perldelta.pod
	cd ..\pod && $(PLMAKE) -f ..\win32\pod.mak converters
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
    if (_ge($version, "5.13.4")) {
        _patch_gnumakefile($version, <<'PATCH');
--- win32/GNUmakefile
+++ win32/GNUmakefile
@@ -14,7 +14,6 @@
 #USE_LONG_DOUBLE :=define
 CCTYPE		:= GCC
 #CFG		:= Debug
-#USE_PERLCRT	= define
 #USE_SETARGV	:= define
 CRYPT_SRC      = fcrypt.c
 #CRYPT_LIB     = -lfcrypt
@@ -34,7 +33,6 @@
 
 PERL_MALLOC	?= undef
 DEBUG_MSTATS	?= undef
-USE_PERLCRT	?= undef
 
 USE_SITECUST	?= undef
 USE_MULTI	?= undef
@@ -503,7 +501,7 @@
 		"ARCHPREFIX=$(ARCHPREFIX)"		\
 		"WIN64=$(WIN64)"
 
-ICWD = -I..\cpan\Cwd -I..\cpan\Cwd\lib
+ICWD = -I..\dist\Cwd -I..\dist\Cwd\lib
 
 #
 # Top targets
PATCH
    }
    if (_ge($version, "5.13.5")) {
        _patch_gnumakefile($version, <<'PATCH');
--- win32/GNUmakefile
+++ win32/GNUmakefile
@@ -869,7 +869,7 @@
 	copy ..\README.vmesa    ..\pod\perlvmesa.pod
 	copy ..\README.vos      ..\pod\perlvos.pod
 	copy ..\README.win32    ..\pod\perlwin32.pod
-	copy ..\pod\perl__PERL_VERSION__delta.pod ..\pod\perldelta.pod
+	copy ..\pod\perldelta.pod ..\pod\perl__PERL_VERSION__delta.pod
 	cd ..\pod && $(PLMAKE) -f ..\win32\pod.mak converters
 	$(PERLEXE) -I..\lib $(PL2BAT) $(UTILS)
 	$(PERLEXE) $(ICWD) ..\autodoc.pl ..
PATCH
    }
    if (_ge($version, "5.13.6")) {
        _patch_gnumakefile($version, <<'PATCH');
--- win32/GNUmakefile
+++ win32/GNUmakefile
@@ -300,13 +300,6 @@
 		..\utils\cpan2dist	\
 		..\utils\shasum		\
 		..\utils\instmodsh	\
-		..\pod\pod2html		\
-		..\pod\pod2latex	\
-		..\pod\pod2man		\
-		..\pod\pod2text		\
-		..\pod\pod2usage	\
-		..\pod\podchecker	\
-		..\pod\podselect	\
 		..\x2p\find2perl	\
 		..\x2p\psed		\
 		..\x2p\s2p		\
@@ -870,7 +863,6 @@
 	copy ..\README.vos      ..\pod\perlvos.pod
 	copy ..\README.win32    ..\pod\perlwin32.pod
 	copy ..\pod\perldelta.pod ..\pod\perl__PERL_VERSION__delta.pod
-	cd ..\pod && $(PLMAKE) -f ..\win32\pod.mak converters
 	$(PERLEXE) -I..\lib $(PL2BAT) $(UTILS)
 	$(PERLEXE) $(ICWD) ..\autodoc.pl ..
 	$(PERLEXE) $(ICWD) ..\pod\perlmodlib.PL -q ..
PATCH
    }
    if (_ge($version, "5.13.7")) {
        _patch_gnumakefile($version, <<'PATCH');
--- win32/GNUmakefile
+++ win32/GNUmakefile
@@ -295,6 +295,7 @@
 		..\utils\prove		\
 		..\utils\ptar		\
 		..\utils\ptardiff	\
+		..\utils\ptargrep	\
 		..\utils\cpanp-run-perl	\
 		..\utils\cpanp	\
 		..\utils\cpan2dist	\
PATCH
    }
    if (_ge($version, "5.13.8")) {
        _patch_gnumakefile($version, <<'PATCH');
--- win32/GNUmakefile
+++ win32/GNUmakefile
@@ -15,8 +15,6 @@
 CCTYPE		:= GCC
 #CFG		:= Debug
 #USE_SETARGV	:= define
-CRYPT_SRC      = fcrypt.c
-#CRYPT_LIB     = -lfcrypt
 #PERL_MALLOC	:= define
 #DEBUG_MSTATS	:= define
 CCHOME		:= C:\MinGW
@@ -72,13 +70,6 @@
 BUILDOPT	+= -DPERL_IMPLICIT_CONTEXT
 endif
 
-ifeq ("$(CRYPT_SRC)$(CRYPT_LIB)","")
-D_CRYPT		= undef
-else
-D_CRYPT		= define
-CRYPT_FLAG	= -DHAVE_DES_FCRYPT
-endif
-
 ifneq ($(USE_IMP_SYS),undef)
 BUILDOPT	+= -DPERL_IMPLICIT_SYS
 endif
@@ -167,11 +158,11 @@
 #
 
 INCLUDES	= -I.\include -I. -I..
-DEFINES		= -DWIN32 -DWIN64 -DCONSERVATIVE -DNO_STRICT $(CRYPT_FLAG)
+DEFINES		= -DWIN32 -DWIN64 -DCONSERVATIVE -DNO_STRICT
 LOCDEFS		= -DPERLDLL -DPERL_CORE
 CXX_FLAG	= -xc++
 LIBC		=
-LIBFILES	= $(LIBC) $(CRYPT_LIB) -lmoldname -lkernel32 -luser32 -lgdi32 -lwinspool \
+LIBFILES	= $(LIBC) -lmoldname -lkernel32 -luser32 -lgdi32 -lwinspool \
 	-lcomdlg32 -ladvapi32 -lshell32 -lole32 -loleaut32 -lnetapi32 \
 	-luuid -lws2_32 -lmpr -lwinmm -lversion -lodbc32 -lodbccp32 -lcomctl32
 
@@ -375,12 +366,9 @@
 		.\win32.c	\
 		.\win32sck.c	\
 		.\win32thread.c	\
+		.\fcrypt.c	\
 		.\win32io.c
 
-ifneq ("$(CRYPT_SRC)", "")
-WIN32_SRC	+= .\$(CRYPT_SRC)
-endif
-
 X2P_SRC		=		\
 		..\x2p\a2p.c	\
 		..\x2p\hash.c	\
PATCH
    }
    if (_ge($version, "5.13.9")) {
        _patch_gnumakefile($version, <<'PATCH');
--- win32/GNUmakefile
+++ win32/GNUmakefile
@@ -694,7 +694,7 @@
 perllibst.h : $(HAVEMINIPERL) $(CONFIGPM) create_perllibst_h.pl
 	$(MINIPERL) -I..\lib create_perllibst_h.pl
 
-perldll.def : $(HAVEMINIPERL) $(CONFIGPM) ..\global.sym ..\pp.sym ..\makedef.pl create_perllibst_h.pl
+perldll.def : $(HAVEMINIPERL) $(CONFIGPM) ..\global.sym ..\makedef.pl create_perllibst_h.pl
 	$(MINIPERL) -I..\lib -w ..\makedef.pl PLATFORM=win32 $(OPTIMIZE) $(DEFINES) \
 	$(BUILDOPT) CCTYPE=$(CCTYPE) TARG_DIR=..\ > perldll.def
 
@@ -815,7 +815,6 @@
 	cd ..\utils && $(PLMAKE) PERL=$(MINIPERL)
 	copy ..\README.aix      ..\pod\perlaix.pod
 	copy ..\README.amiga    ..\pod\perlamiga.pod
-	copy ..\README.apollo   ..\pod\perlapollo.pod
 	copy ..\README.beos     ..\pod\perlbeos.pod
 	copy ..\README.bs2000   ..\pod\perlbs2000.pod
 	copy ..\README.ce       ..\pod\perlce.pod
PATCH
    }
    if (_ge($version, "5.13.10")) {
        _patch_gnumakefile($version, <<'PATCH');
--- win32/GNUmakefile
+++ win32/GNUmakefile
@@ -328,6 +328,7 @@
 		..\mro.c	\
 		..\hv.c		\
 		..\locale.c	\
+		..\keywords.c	\
 		..\mathoms.c	\
 		..\mg.c		\
 		..\numeric.c	\
@@ -516,11 +517,13 @@
 $(CONFIGPM) : $(HAVEMINIPERL) ..\config.sh config_h.PL ..\minimod.pl
 	$(MINIPERL) -I..\lib ..\configpm --chdir=..
 	$(XCOPY) *.h $(COREDIR)\\*.*
-	$(XCOPY) ..\\ext\\re\\re.pm $(LIBDIR)\\*.*
 	$(RCOPY) include $(COREDIR)\\*.*
 	$(XCOPY) ..\\*.h $(COREDIR)\\*.*
 	-$(MINIPERL) -I..\lib $(ICWD) config_h.PL "ARCHPREFIX=$(ARCHPREFIX)"
 
+..\lib\buildcustomize.pl: $(HAVEMINIPERL) ..\write_buildcustomize.pl
+	$(MINIPERL) -I..\lib ..\write_buildcustomize.pl .. > ..\lib\buildcustomize.pl
+
 .\config.h : $(CONFIGPM)
 $(MINIDIR)\.exists : $(CFGH_TMPL)
 	if not exist "$(MINIDIR)" mkdir "$(MINIDIR)"
@@ -783,24 +786,24 @@
 	$(LINK32) -mconsole -o $(MINIPERL) $(BLINK_FLAGS) $(MINI_OBJ) $(LIBFILES)
 	rem . > $@
 
-Extensions : ..\make_ext.pl $(HAVEMINIPERL) $(PERLDEP) $(CONFIGPM) $(DYNALOADER)
+Extensions : ..\make_ext.pl $(HAVEMINIPERL) ..\lib\buildcustomize.pl $(PERLDEP) $(CONFIGPM) $(DYNALOADER)
 	$(XCOPY) ..\\*.h $(COREDIR)\\*.*
 	$(MINIPERL) -I..\lib $(ICWD) ..\make_ext.pl "MAKE=$(PLMAKE)" --dir=$(CPANDIR) --dir=$(DISTDIR) --dir=$(EXTDIR) --dynamic
 
-Extensions_reonly : ..\make_ext.pl $(HAVEMINIPERL) $(PERLDEP) $(CONFIGPM) $(DYNALOADER)
+Extensions_reonly : ..\make_ext.pl $(HAVEMINIPERL) ..\lib\buildcustomize.pl $(PERLDEP) $(CONFIGPM) $(DYNALOADER)
 	$(XCOPY) ..\\*.h $(COREDIR)\\*.*
 	$(MINIPERL) -I..\lib $(ICWD) ..\make_ext.pl "MAKE=$(PLMAKE)" --dir=$(CPANDIR) --dir=$(DISTDIR) --dir=$(EXTDIR) --dynamic +re
 
-Extensions_static : ..\make_ext.pl $(HAVEMINIPERL) list_static_libs.pl $(CONFIGPM) Extensions_nonxs
+Extensions_static : ..\make_ext.pl $(HAVEMINIPERL) ..\lib\buildcustomize.pl list_static_libs.pl $(CONFIGPM) Extensions_nonxs
 	$(XCOPY) ..\\*.h $(COREDIR)\\*.*
 	$(MINIPERL) -I..\lib $(ICWD) ..\make_ext.pl "MAKE=$(PLMAKE)" --dir=$(CPANDIR) --dir=$(DISTDIR) --dir=$(EXTDIR) --static
 	$(MINIPERL) -I..\lib $(ICWD) list_static_libs.pl > Extensions_static
 
-Extensions_nonxs : ..\make_ext.pl $(HAVEMINIPERL) $(PERLDEP) $(CONFIGPM) ..\pod\perlfunc.pod
+Extensions_nonxs : ..\make_ext.pl $(HAVEMINIPERL) ..\lib\buildcustomize.pl $(PERLDEP) $(CONFIGPM) ..\pod\perlfunc.pod
 	$(XCOPY) ..\\*.h $(COREDIR)\\*.*
 	$(MINIPERL) -I..\lib $(ICWD) ..\make_ext.pl "MAKE=$(PLMAKE)" --dir=$(CPANDIR) --dir=$(DISTDIR) --dir=$(EXTDIR) --nonxs
 
-$(DYNALOADER) : ..\make_ext.pl $(HAVEMINIPERL) $(PERLDEP) $(CONFIGPM) Extensions_nonxs
+$(DYNALOADER) : ..\make_ext.pl $(HAVEMINIPERL) ..\lib\buildcustomize.pl $(PERLDEP) $(CONFIGPM) Extensions_nonxs
 	$(XCOPY) ..\\*.h $(COREDIR)\\*.*
 	$(MINIPERL) -I..\lib $(ICWD) ..\make_ext.pl "MAKE=$(PLMAKE)" --dir=$(EXTDIR) --dynaloader
 
PATCH
    }
    if (_ge($version, "5.13.11")) {
        _patch_gnumakefile($version, <<'PATCH');
--- win32/GNUmakefile
+++ win32/GNUmakefile
@@ -292,6 +292,7 @@
 		..\utils\cpan2dist	\
 		..\utils\shasum		\
 		..\utils\instmodsh	\
+		..\utils\json_pp	\
 		..\x2p\find2perl	\
 		..\x2p\psed		\
 		..\x2p\s2p		\
PATCH
    }
}

sub _patch_gnumakefile_510 {
    my $version = shift;
    _write_gnumakefile($version, <<'MAKEFILE');
SHELL := cmd.exe
GCCBIN := gcc
INST_DRV := c:
INST_TOP := $(INST_DRV)\perl
#INST_VER	:= \__INST_VER__
#INST_ARCH	:= \$(ARCHNAME)
#USE_SITECUST	:= define
USE_MULTI	:= define
USE_ITHREADS	:= define
USE_IMP_SYS	:= define
USE_PERLIO	:= define
USE_LARGE_FILES	:= define
#USE_64_BIT_INT	:= define
#USE_LONG_DOUBLE :=define
#USE_NO_REGISTRY := define
CCTYPE		:= GCC
#CFG		:= Debug
#USE_PERLCRT	= define
#USE_SETARGV	:= define
CRYPT_SRC	= .\fcrypt.c
#CRYPT_LIB	= fcrypt.lib
#PERL_MALLOC	:= define
#DEBUG_MSTATS	:= define
CCHOME		:= C:\MinGW

CCINCDIR := $(CCHOME)\include
CCLIBDIR := $(CCHOME)\lib
CCDLLDIR := $(CCHOME)\bin
ARCHPREFIX :=
BUILDOPT	:= $(BUILDOPTEXTRA)
BUILDOPT	+= -DPERL_TEXTMODE_SCRIPTS

EXTRALIBDIRS	:=


D_CRYPT		?= undef
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

ifeq ("$(CRYPT_SRC)$(CRYPT_LIB)","")
D_CRYPT		= undef
else
D_CRYPT		= define
CRYPT_FLAG	= -DHAVE_DES_FCRYPT
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
EXTUTILSDIR	= $(LIBDIR)\ExtUtils
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
DEFINES		= -DWIN32 -DWIN64 -DCONSERVATIVE -DNO_STRICT $(CRYPT_FLAG)
LOCDEFS		= -DPERLDLL -DPERL_CORE
CXX_FLAG	= -xc++
LIBC		=
LIBFILES	= $(LIBC) $(CRYPT_LIB) -lmoldname -lkernel32 -luser32 -lgdi32 -lwinspool \
	-lcomdlg32 -ladvapi32 -lshell32 -lole32 -loleaut32 -lnetapi32 \
	-luuid -lws2_32 -lmpr -lwinmm -lversion -lodbc32 -lodbccp32

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
HAVEMINIPERL	= .have_miniperl
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
FIRSTUNIFILE	= ..\lib\unicore\Canonical.pl
UNIDATAFILES	= ..\lib\unicore\Canonical.pl ..\lib\unicore\Exact.pl \
		   ..\lib\unicore\Properties ..\lib\unicore\Decomposition.pl \
		   ..\lib\unicore\CombiningClass.pl ..\lib\unicore\Name.pl \
		   ..\lib\unicore\PVA.pl

# Directories of Unicode data files generated by mktables
UNIDATADIR1	= ..\lib\unicore\To
UNIDATADIR2	= ..\lib\unicore\lib

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
		..\utils\dprofpp	\
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
		..\utils\cpanp-run-perl	\
		..\utils\cpanp	\
		..\utils\cpan2dist	\
		..\utils\shasum		\
		..\utils\instmodsh	\
		..\pod\checkpods	\
		..\pod\pod2html		\
		..\pod\pod2latex	\
		..\pod\pod2man		\
		..\pod\pod2text		\
		..\pod\pod2usage	\
		..\pod\podchecker	\
		..\pod\podselect	\
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

XSUBPP		= ..\$(MINIPERL) -I..\..\lib ..\$(EXTUTILSDIR)\xsubpp \
		-C++ -prototypes

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
		..\mathoms.c	\
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
		..\util.c	\
		..\xsutils.c

EXTRACORE_SRC	+= perllib.c

ifeq ($(PERL_MALLOC),define)
EXTRACORE_SRC	+= ..\malloc.c
endif

EXTRACORE_SRC	+= ..\perlio.c

WIN32_SRC	=		\
		.\win32.c	\
		.\win32sck.c	\
		.\win32thread.c	\
		.\win32io.c

ifneq ($(CRYPT_SRC), "")
WIN32_SRC	+= $(CRYPT_SRC)
endif

DLL_SRC		= $(DYNALOADER).c

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

CORE_H		= $(CORE_NOCFG_H) .\config.h

UUDMAP_H	= ..\uudmap.h
HAVE_COREDIR	= $(COREDIR)\ppport.h

MICROCORE_OBJ	= $(MICROCORE_SRC:.c=$(o))
CORE_OBJ	= $(MICROCORE_OBJ) $(EXTRACORE_SRC:.c=$(o))
WIN32_OBJ	= $(WIN32_SRC:.c=$(o))

MINICORE_OBJ	= $(subst ..\,mini\,$(MICROCORE_OBJ))	\
		  $(MINIDIR)\miniperlmain$(o)	\
		  $(MINIDIR)\perlio$(o)
MINIWIN32_OBJ	= $(subst .\,mini\,$(WIN32_OBJ))
MINI_OBJ	= $(MINICORE_OBJ) $(MINIWIN32_OBJ)
DLL_OBJ		= $(DLL_SRC:.c=$(o))
X2P_OBJ		= $(X2P_SRC:.c=$(o))
GENUUDMAP_OBJ	= $(GENUUDMAP:.exe=$(o))
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

DYNALOADER	= $(EXTDIR)\DynaLoader\DynaLoader

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

ICWD = -I..\cpan\Cwd -I..\cpan\Cwd\lib

#
# Top targets
#

.PHONY: all

all : .\config.h $(GLOBEXE) $(MINIMOD) $(CONFIGPM) \
		$(UNIDATAFILES) MakePPPort $(PERLEXE) $(X2P) Extensions $(PERLSTATIC)
		@echo Everything is up to date. '$(MAKE_BARE) test' to run test suite.

..\regcomp$(o) : ..\regnodes.h ..\regcharclass.h

..\regexec$(o) : ..\regnodes.h ..\regcharclass.h

$(DYNALOADER)$(o) : $(DYNALOADER).c $(CORE_H) $(EXTDIR)\DynaLoader\dlutils.c

#----------------------------------------------------------------

$(GLOBEXE) : perlglob.c
	$(LINK32) $(OPTIMIZE) $(BLINK_FLAGS) -mconsole -o $@ perlglob.c $(LIBFILES)

..\config.sh : $(CFGSH_TMPL) $(HAVEMINIPERL) config_sh.PL
	$(MINIPERL) -I..\lib config_sh.PL $(CFG_VARS) $(CFGSH_TMPL) > ..\config.sh

$(CONFIGPM) : $(HAVEMINIPERL) ..\config.sh config_h.PL ..\minimod.pl
	cd .. && miniperl.exe -Ilib configpm
	$(XCOPY) *.h $(COREDIR)\\*.*
	$(XCOPY) ..\\ext\\re\\re.pm $(LIBDIR)\\*.*
	$(RCOPY) include $(COREDIR)\\*.*
	$(XCOPY) ..\\*.h $(COREDIR)\\*.*
	-$(MINIPERL) -I..\lib $(ICWD) config_h.PL "ARCHPREFIX=$(ARCHPREFIX)"

# See the comment in Makefile.SH explaining this seemingly cranky ordering

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
$(MINI_OBJ)	: $(MINIDIR)\.exists $(CORE_NOCFG_H)

$(WIN32_OBJ)	: $(CORE_H)

$(CORE_OBJ)	: $(CORE_H)

$(DLL_OBJ)	: $(CORE_H)

$(X2P_OBJ)	: $(CORE_H)

perllibst.h : $(HAVEMINIPERL) $(CONFIGPM)
	$(MINIPERL) -I..\lib buildext.pl --create-perllibst-h

perldll.def : $(HAVEMINIPERL) $(CONFIGPM) ..\global.sym ..\pp.sym ..\makedef.pl
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

$(PERLEXE_ICO): $(HAVEMINIPERL) ..\uupacktool.pl $(PERLEXE_ICO).packd
	$(MINIPERL) -I..\lib ..\uupacktool.pl -u $(PERLEXE_ICO).packd $(PERLEXE_ICO)

$(PERLEXE_RES): perlexe.rc $(PERLEXE_ICO)

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

$(MINIDIR)\globals$(o) : $(UUDMAP_H)

$(UUDMAP_H) : $(GENUUDMAP)
	$(GENUUDMAP) > $(UUDMAP_H)

$(GENUUDMAP) : $(GENUUDMAP_OBJ)
	$(LINK32) $(CFLAGS_O) -o $@ $(GENUUDMAP_OBJ) \
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
	copy splittree.pl ..
	$(MINIPERL) -I..\lib ..\splittree.pl "../LIB" $(AUTODIR)

$(PERLEXESTATIC): $(PERLSTATICLIB) $(CONFIGPM) $(PERLEXEST_OBJ) $(PERLEXE_RES)
	$(LINK32) -mconsole -o $@ $(BLINK_FLAGS) \
	    $(PERLEXEST_OBJ) $(PERLEXE_RES) $(PERLSTATICLIB) $(LIBFILES)

$(DYNALOADER).c: $(HAVEMINIPERL) $(EXTDIR)\DynaLoader\dl_win32.xs $(CONFIGPM)
	if not exist $(AUTODIR) mkdir $(AUTODIR)
	cd $(EXTDIR)\DynaLoader \
		&& ..\$(MINIPERL) -I..\..\lib DynaLoader_pm.PL \
		&& ..\$(MINIPERL) -I..\..\lib XSLoader_pm.PL
	$(XCOPY) $(EXTDIR)\DynaLoader\DynaLoader.pm $(LIBDIR)\$(NULL)
	$(XCOPY) $(EXTDIR)\DynaLoader\XSLoader.pm $(LIBDIR)\$(NULL)
	cd $(EXTDIR)\DynaLoader \
		&& $(XSUBPP) dl_win32.xs > ..\$(DYNALOADER).c

$(EXTDIR)\DynaLoader\dl_win32.xs: dl_win32.xs
	copy dl_win32.xs $(EXTDIR)\DynaLoader\dl_win32.xs

#-------------------------------------------------------------------------------
# There's no direct way to mark a dependency on
# DynaLoader.pm, so this will have to do

MakePPPort: $(HAVEMINIPERL) $(CONFIGPM)
	$(MINIPERL) -I..\lib ..\mkppport

$(HAVEMINIPERL): $(MINI_OBJ)
	$(LINK32) -mconsole -o $(MINIPERL) $(BLINK_FLAGS) $(MINI_OBJ) $(LIBFILES)
	rem . > $@

#most of deps of this target are in DYNALOADER and therefore omitted here
Extensions : buildext.pl $(HAVEMINIPERL) $(PERLDEP) $(CONFIGPM)
	$(XCOPY) ..\\*.h $(COREDIR)\\*.*
	$(MINIPERL) -I..\lib $(ICWD) buildext.pl "$(PLMAKE)" $(PERLDEP) $(EXTDIR) --dynamic
	-if exist ext $(MINIPERL) -I..\lib $(ICWD) buildext.pl "$(PLMAKE)" $(PERLDEP) ext --dynamic

Extensions_static : buildext.pl $(HAVEMINIPERL) $(CONFIGPM)
	$(XCOPY) ..\\*.h $(COREDIR)\\*.*
	$(MINIPERL) -I..\lib $(ICWD) buildext.pl "$(PLMAKE)" $(PERLDEP) $(EXTDIR) --static
	-if exist ext $(MINIPERL) -I..\lib $(ICWD) buildext.pl "$(PLMAKE)" $(PERLDEP) ext --static
	$(MINIPERL) -I..\lib buildext.pl --list-static-libs > Extensions_static

#-------------------------------------------------------------------------------

doc: $(PERLEXE)
	$(PERLEXE) -I..\lib ..\installhtml --podroot=.. --htmldir=$(HTMLDIR) \
	    --podpath=pod:lib:ext:utils --htmlroot="file://$(subst :,|,$(INST_HTML))" \
	    --libpod=perlfunc:perlguts:perlvar:perlrun:perlop --recurse

# Note that this next section is parsed (and regenerated) by pod/buildtoc
# so please check that script before making structural changes here
utils: $(PERLEXE) $(X2P)
	cd ..\utils && $(PLMAKE) PERL=$(MINIPERL)
	copy ..\README.aix      ..\pod\perlaix.pod
	copy ..\README.amiga    ..\pod\perlamiga.pod
	copy ..\README.apollo   ..\pod\perlapollo.pod
	copy ..\README.beos     ..\pod\perlbeos.pod
	copy ..\README.bs2000   ..\pod\perlbs2000.pod
	copy ..\README.ce       ..\pod\perlce.pod
	copy ..\README.cn       ..\pod\perlcn.pod
	copy ..\README.cygwin   ..\pod\perlcygwin.pod
	copy ..\README.dgux     ..\pod\perldgux.pod
	copy ..\README.dos      ..\pod\perldos.pod
	copy ..\README.epoc     ..\pod\perlepoc.pod
	copy ..\README.freebsd  ..\pod\perlfreebsd.pod
	copy ..\README.hpux     ..\pod\perlhpux.pod
	copy ..\README.hurd     ..\pod\perlhurd.pod
	copy ..\README.irix     ..\pod\perlirix.pod
	copy ..\README.jp       ..\pod\perljp.pod
	copy ..\README.ko       ..\pod\perlko.pod
	copy ..\README.linux    ..\pod\perllinux.pod
	copy ..\README.machten  ..\pod\perlmachten.pod
	copy ..\README.macos    ..\pod\perlmacos.pod
	copy ..\README.macosx   ..\pod\perlmacosx.pod
	copy ..\README.mint     ..\pod\perlmint.pod
	copy ..\README.mpeix    ..\pod\perlmpeix.pod
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
	copy ..\README.uts      ..\pod\perluts.pod
	copy ..\README.vmesa    ..\pod\perlvmesa.pod
	copy ..\README.vms      ..\pod\perlvms.pod
	copy ..\README.vos      ..\pod\perlvos.pod
	copy ..\README.win32    ..\pod\perlwin32.pod
	copy ..\pod\perl__PERL_VERSION__delta.pod ..\pod\perldelta.pod
	cd ..\lib && $(PERLEXE) lib_pm.PL
	cd ..\pod && $(PLMAKE) -f ..\win32\pod.mak converters
	$(PERLEXE) -I..\lib $(PL2BAT) $(UTILS)

install : all installbare installhtml

installbare : utils
	$(PERLEXE) ..\installperl
	if exist $(WPERLEXE) $(XCOPY) $(WPERLEXE) $(INST_BIN)\$(NULL)
	if exist $(PERLEXESTATIC) $(XCOPY) $(PERLEXESTATIC) $(INST_BIN)\$(NULL)
	$(XCOPY) $(GLOBEXE) $(INST_BIN)\$(NULL)
	if exist ..\perl*.pdb $(XCOPY) ..\perl*.pdb $(INST_BIN)\$(NULL)
	if exist ..\x2p\a2p.pdb $(XCOPY) ..\x2p\a2p.pdb $(INST_BIN)\$(NULL)
	$(XCOPY) "bin\*.bat" $(INST_SCRIPT)\$(NULL)

installhtml : doc
	$(RCOPY) $(HTMLDIR)\*.* $(INST_HTML)\$(NULL)

$(UNIDATAFILES) : $(HAVEMINIPERL) $(CONFIGPM) ..\lib\unicore\mktables
	cd ..\lib\unicore && ..\$(MINIPERL) -I.. mktables -check $@ $(FIRSTUNIFILE)
MAKEFILE
    if (_ge($version, "5.10.1")) {
        _patch_gnumakefile($version, <<'PATCH');
--- win32/GNUmakefile
+++ win32/GNUmakefile
@@ -300,7 +300,6 @@
 		..\utils\cpan2dist	\
 		..\utils\shasum		\
 		..\utils\instmodsh	\
-		..\pod\checkpods	\
 		..\pod\pod2html		\
 		..\pod\pod2latex	\
 		..\pod\pod2man		\
@@ -441,7 +440,7 @@
 		.\include\sys\socket.h	\
 		.\win32.h
 
-CORE_H		= $(CORE_NOCFG_H) .\config.h
+CORE_H		= $(CORE_NOCFG_H) .\config.h ..\git_version.h
 
 UUDMAP_H	= ..\uudmap.h
 HAVE_COREDIR	= $(COREDIR)\ppport.h
@@ -529,7 +528,7 @@
 
 .PHONY: all
 
-all : .\config.h $(GLOBEXE) $(MINIMOD) $(CONFIGPM) \
+all : .\config.h ..\git_version.h $(GLOBEXE) $(MINIMOD) $(CONFIGPM) \
 		$(UNIDATAFILES) MakePPPort $(PERLEXE) $(X2P) Extensions $(PERLSTATIC)
 		@echo Everything is up to date. '$(MAKE_BARE) test' to run test suite.
 
@@ -544,6 +543,12 @@
 $(GLOBEXE) : perlglob.c
 	$(LINK32) $(OPTIMIZE) $(BLINK_FLAGS) -mconsole -o $@ perlglob.c $(LIBFILES)
 
+..\git_version.h : $(HAVEMINIPERL) ..\make_patchnum.pl
+	cd .. && miniperl.exe -Ilib make_patchnum.pl
+
+# make sure that we recompile perl.c if the git version changes
+..\perl$(o) : ..\git_version.h
+
 ..\config.sh : $(CFGSH_TMPL) $(HAVEMINIPERL) config_sh.PL
 	$(MINIPERL) -I..\lib config_sh.PL $(CFG_VARS) $(CFGSH_TMPL) > ..\config.sh
 
@@ -743,8 +748,8 @@
 
 $(X2P_OBJ)	: $(CORE_H)
 
-perllibst.h : $(HAVEMINIPERL) $(CONFIGPM)
-	$(MINIPERL) -I..\lib buildext.pl --create-perllibst-h
+perllibst.h : $(HAVEMINIPERL) $(CONFIGPM) create_perllibst_h.pl
+	$(MINIPERL) -I..\lib create_perllibst_h.pl
 
 perldll.def : $(HAVEMINIPERL) $(CONFIGPM) ..\global.sym ..\pp.sym ..\makedef.pl
 	$(MINIPERL) -I..\lib -w ..\makedef.pl PLATFORM=win32 $(OPTIMIZE) $(DEFINES) \
@@ -861,16 +866,14 @@
 	rem . > $@
 
 #most of deps of this target are in DYNALOADER and therefore omitted here
-Extensions : buildext.pl $(HAVEMINIPERL) $(PERLDEP) $(CONFIGPM)
+Extensions : ..\make_ext.pl $(HAVEMINIPERL) $(PERLDEP) $(CONFIGPM)
 	$(XCOPY) ..\\*.h $(COREDIR)\\*.*
-	$(MINIPERL) -I..\lib $(ICWD) buildext.pl "$(PLMAKE)" $(PERLDEP) $(EXTDIR) --dynamic
-	-if exist ext $(MINIPERL) -I..\lib $(ICWD) buildext.pl "$(PLMAKE)" $(PERLDEP) ext --dynamic
+	$(MINIPERL) -I..\lib $(ICWD) ..\make_ext.pl "MAKE=$(PLMAKE)" --dir=$(EXTDIR) --dynamic
 
-Extensions_static : buildext.pl $(HAVEMINIPERL) $(CONFIGPM)
+Extensions_static : ..\make_ext.pl $(HAVEMINIPERL) list_static_libs.pl $(CONFIGPM)
 	$(XCOPY) ..\\*.h $(COREDIR)\\*.*
-	$(MINIPERL) -I..\lib $(ICWD) buildext.pl "$(PLMAKE)" $(PERLDEP) $(EXTDIR) --static
-	-if exist ext $(MINIPERL) -I..\lib $(ICWD) buildext.pl "$(PLMAKE)" $(PERLDEP) ext --static
-	$(MINIPERL) -I..\lib buildext.pl --list-static-libs > Extensions_static
+	$(MINIPERL) -I..\lib $(ICWD) ..\make_ext.pl "MAKE=$(PLMAKE)" --dir=$(EXTDIR) --static
+	$(MINIPERL) -I..\lib $(ICWD) list_static_libs.pl > Extensions_static
 
 #-------------------------------------------------------------------------------
 
@@ -895,6 +898,7 @@
 	copy ..\README.dos      ..\pod\perldos.pod
 	copy ..\README.epoc     ..\pod\perlepoc.pod
 	copy ..\README.freebsd  ..\pod\perlfreebsd.pod
+	copy ..\README.haiku    ..\pod\perlhaiku.pod
 	copy ..\README.hpux     ..\pod\perlhpux.pod
 	copy ..\README.hurd     ..\pod\perlhurd.pod
 	copy ..\README.irix     ..\pod\perlirix.pod
@@ -920,7 +924,6 @@
 	copy ..\README.tw       ..\pod\perltw.pod
 	copy ..\README.uts      ..\pod\perluts.pod
 	copy ..\README.vmesa    ..\pod\perlvmesa.pod
-	copy ..\README.vms      ..\pod\perlvms.pod
 	copy ..\README.vos      ..\pod\perlvos.pod
 	copy ..\README.win32    ..\pod\perlwin32.pod
 	copy ..\pod\perl__PERL_VERSION__delta.pod ..\pod\perldelta.pod
PATCH
    }
    if (_ge($version, "5.11.0")) {
        _patch_gnumakefile($version, <<'PATCH');
--- win32/GNUmakefile
+++ win32/GNUmakefile
@@ -2,6 +2,7 @@
 GCCBIN := gcc
 INST_DRV := c:
 INST_TOP := $(INST_DRV)\perl
+#WIN64		:= undef
 #INST_VER	:= \__INST_VER__
 #INST_ARCH	:= \$(ARCHNAME)
 #USE_SITECUST	:= define
@@ -10,17 +11,16 @@
 USE_IMP_SYS	:= define
 USE_PERLIO	:= define
 USE_LARGE_FILES	:= define
-#USE_64_BIT_INT	:= define
-#USE_LONG_DOUBLE :=define
-#USE_NO_REGISTRY := define
 CCTYPE		:= GCC
 #CFG		:= Debug
 #USE_PERLCRT	= define
 #USE_SETARGV	:= define
-CRYPT_SRC	= .\fcrypt.c
-#CRYPT_LIB	= fcrypt.lib
+CRYPT_SRC      = fcrypt.c
+#CRYPT_LIB     = -lfcrypt
 #PERL_MALLOC	:= define
 #DEBUG_MSTATS	:= define
+#BUILD_STATIC	:= define
+#ALL_STATIC	:= define
 CCHOME		:= C:\MinGW
 
 CCINCDIR := $(CCHOME)\include
@@ -33,9 +33,9 @@
 EXTRALIBDIRS	:=
 
 
-D_CRYPT		?= undef
 PERL_MALLOC	?= undef
 DEBUG_MSTATS	?= undef
+USE_PERLCRT	?= undef
 
 USE_SITECUST	?= undef
 USE_MULTI	?= undef
@@ -43,9 +43,6 @@
 USE_IMP_SYS	?= undef
 USE_PERLIO	?= undef
 USE_LARGE_FILES	?= undef
-USE_64_BIT_INT	?= undef
-USE_LONG_DOUBLE	?= undef
-USE_NO_REGISTRY	?= undef
 
 ifeq ($(USE_IMP_SYS),define)
 PERL_MALLOC	= undef
@@ -86,10 +83,6 @@
 BUILDOPT	+= -DPERL_IMPLICIT_SYS
 endif
 
-ifeq ($(USE_NO_REGISTRY),define)
-BUILDOPT	+= -DWIN32_NO_REGISTRY
-endif
-
 WIN64 := define
 PROCESSOR_ARCHITECTURE := x64
 USE_64_BIT_INT = define
@@ -105,24 +98,10 @@
 endif
 endif
 
-ifeq ($(USE_PERLIO),define)
-BUILDOPT	+= -DUSE_PERLIO
-endif
-
 ifeq ($(USE_ITHREADS),define)
 ARCHNAME	:= $(ARCHNAME)-thread
 endif
 
-ifneq ($(WIN64),define)
-ifeq ($(USE_64_BIT_INT),define)
-ARCHNAME	:= $(ARCHNAME)-64int
-endif
-endif
-
-ifeq ($(USE_LONG_DOUBLE),define)
-ARCHNAME	:= $(ARCHNAME)-ld
-endif
-
 ARCHDIR		= ..\lib\$(ARCHNAME)
 COREDIR		= ..\lib\CORE
 AUTODIR		= ..\lib\auto
@@ -131,7 +110,6 @@
 DISTDIR		= ..\dist
 CPANDIR		= ..\cpan
 PODDIR		= ..\pod
-EXTUTILSDIR	= $(LIBDIR)\ExtUtils
 HTMLDIR		= .\html
 
 #
@@ -154,11 +132,6 @@
 IMPLIB		= $(ARCHPREFIX)dlltool
 RSC		= $(ARCHPREFIX)windres
 
-ifeq ($(USE_LONG_DOUBLE),define)
-BUILDOPT        += -D__USE_MINGW_ANSI_STDIO
-MINIBUILDOPT    += -D__USE_MINGW_ANSI_STDIO
-endif
-
 BUILDOPT        += -fwrapv
 MINIBUILDOPT    += -fwrapv
 
@@ -177,12 +150,14 @@
 LIBC		=
 LIBFILES	= $(LIBC) $(CRYPT_LIB) -lmoldname -lkernel32 -luser32 -lgdi32 -lwinspool \
 	-lcomdlg32 -ladvapi32 -lshell32 -lole32 -loleaut32 -lnetapi32 \
-	-luuid -lws2_32 -lmpr -lwinmm -lversion -lodbc32 -lodbccp32
+	-luuid -lws2_32 -lmpr -lwinmm -lversion -lodbc32 -lodbccp32 -lcomctl32
 
 ifeq ($(CFG),Debug)
 OPTIMIZE	= -g -O2 -DDEBUGGING
 LINK_DBG	= -g
 else
+# It seems that there are some Undefined Behavior.
+# diable optimization to cause unexpected hebavior.
 OPTIMIZE	= -s -O2
 LINK_DBG	= -s
 endif
@@ -253,9 +228,9 @@
 # Unicode data files generated by mktables
 FIRSTUNIFILE	= ..\lib\unicore\Canonical.pl
 UNIDATAFILES	= ..\lib\unicore\Canonical.pl ..\lib\unicore\Exact.pl \
-		   ..\lib\unicore\Properties ..\lib\unicore\Decomposition.pl \
-		   ..\lib\unicore\CombiningClass.pl ..\lib\unicore\Name.pl \
-		   ..\lib\unicore\PVA.pl
+		  ..\lib\unicore\Properties ..\lib\unicore\Decomposition.pl \
+		  ..\lib\unicore\CombiningClass.pl ..\lib\unicore\Name.pl \
+		  ..\lib\unicore\PVA.pl
 
 # Directories of Unicode data files generated by mktables
 UNIDATADIR1	= ..\lib\unicore\To
@@ -273,6 +248,7 @@
 
 
 PL2BAT		= bin\pl2bat.pl
+GLOBBAT		= bin\perlglob.bat
 
 UTILS		=			\
 		..\utils\h2ph		\
@@ -332,9 +308,6 @@
 RCOPY		= xcopy /f /r /i /e /d /y
 NOOP		= @rem
 
-XSUBPP		= ..\$(MINIPERL) -I..\..\lib ..\$(EXTUTILSDIR)\xsubpp \
-		-C++ -prototypes
-
 MICROCORE_SRC	=		\
 		..\av.c		\
 		..\deb.c	\
@@ -346,7 +319,7 @@
 		..\mro.c	\
 		..\hv.c		\
 		..\locale.c	\
-		..\mathoms.c	\
+		..\mathoms.c    \
 		..\mg.c		\
 		..\numeric.c	\
 		..\op.c		\
@@ -370,8 +343,7 @@
 		..\toke.c	\
 		..\universal.c	\
 		..\utf8.c	\
-		..\util.c	\
-		..\xsutils.c
+		..\util.c
 
 EXTRACORE_SRC	+= perllib.c
 
@@ -387,12 +359,10 @@
 		.\win32thread.c	\
 		.\win32io.c
 
-ifneq ($(CRYPT_SRC), "")
-WIN32_SRC	+= $(CRYPT_SRC)
+ifneq ("$(CRYPT_SRC)", "")
+WIN32_SRC	+= .\$(CRYPT_SRC)
 endif
 
-DLL_SRC		= $(DYNALOADER).c
-
 X2P_SRC		=		\
 		..\x2p\a2p.c	\
 		..\x2p\hash.c	\
@@ -443,6 +413,7 @@
 CORE_H		= $(CORE_NOCFG_H) .\config.h ..\git_version.h
 
 UUDMAP_H	= ..\uudmap.h
+BITCOUNT_H	= ..\bitcount.h
 HAVE_COREDIR	= $(COREDIR)\ppport.h
 
 MICROCORE_OBJ	= $(MICROCORE_SRC:.c=$(o))
@@ -454,7 +425,7 @@
 		  $(MINIDIR)\perlio$(o)
 MINIWIN32_OBJ	= $(subst .\,mini\,$(WIN32_OBJ))
 MINI_OBJ	= $(MINICORE_OBJ) $(MINIWIN32_OBJ)
-DLL_OBJ		= $(DLL_SRC:.c=$(o))
+DLL_OBJ		= $(DYNALOADER)
 X2P_OBJ		= $(X2P_SRC:.c=$(o))
 GENUUDMAP_OBJ	= $(GENUUDMAP:.exe=$(o))
 PERLDLL_OBJ	= $(CORE_OBJ)
@@ -467,25 +438,12 @@
 SETARGV_OBJ	= setargv$(o)
 endif
 
-ifeq ($(ALL_STATIC),define)
-# some exclusions, unfortunately, until fixed:
-#  - Win32 extension contains overlapped symbols with win32.c (BUG!)
-#  - MakeMaker isn't capable enough for SDBM_File (smaller bug)
-#  - Encode (encoding search algorithm relies on shared library?)
-STATIC_EXT	= * !Win32 !SDBM_File !Encode
-else
-# specify static extensions here, for example:
-#STATIC_EXT	= Cwd Compress/Raw/Zlib
 STATIC_EXT	= Win32CORE
-endif
 
-DYNALOADER	= $(EXTDIR)\DynaLoader\DynaLoader
+DYNALOADER	= ..\DynaLoader$(o)
 
-# vars must be separated by "\t+~\t+", since we're using the tempfile
-# version of config_sh.pl (we were overflowing someone's buffer by
-# trying to fit them all on the command line)
-#	-- BKS 10-17-1999
 CFG_VARS	=					\
+		"INST_DRV=$(INST_DRV)"			\
 		"INST_TOP=$(INST_TOP)"			\
 		"INST_VER=$(INST_VER)"			\
 		"INST_ARCH=$(INST_ARCH)"		\
@@ -493,7 +451,6 @@
 		"cc=$(CC)"				\
 		"ld=$(LINK32)"				\
 		"ccflags=$(subst ",\",$(EXTRACFLAGS) $(OPTIMIZE) $(DEFINES) $(BUILDOPT))" \
-		"usecplusplus=$(USE_CPLUSPLUS)"		\
 		"cf_email=$(EMAIL)"			\
 		"d_mymalloc=$(PERL_MALLOC)"		\
 		"libs=$(LIBFILES)"			\
@@ -511,14 +468,10 @@
 		"useithreads=$(USE_ITHREADS)"		\
 		"usemultiplicity=$(USE_MULTI)"		\
 		"useperlio=$(USE_PERLIO)"		\
-		"use64bitint=$(USE_64_BIT_INT)"		\
-		"uselongdouble=$(USE_LONG_DOUBLE)"	\
 		"uselargefiles=$(USE_LARGE_FILES)"	\
 		"usesitecustomize=$(USE_SITECUST)"	\
 		"LINK_FLAGS=$(subst ",\",$(LINK_FLAGS))"\
-		"optimize=$(subst ",\",$(OPTIMIZE))"	\
-		"ARCHPREFIX=$(ARCHPREFIX)"		\
-		"WIN64=$(WIN64)"
+		"optimize=$(subst ",\",$(OPTIMIZE))"
 
 ICWD = -I..\cpan\Cwd -I..\cpan\Cwd\lib
 
@@ -529,48 +482,35 @@
 .PHONY: all
 
 all : .\config.h ..\git_version.h $(GLOBEXE) $(MINIMOD) $(CONFIGPM) \
-		$(UNIDATAFILES) MakePPPort $(PERLEXE) $(X2P) Extensions $(PERLSTATIC)
+		$(UNIDATAFILES) MakePPPort $(PERLEXE) $(X2P) Extensions_nonxs Extensions $(PERLSTATIC)
 		@echo Everything is up to date. '$(MAKE_BARE) test' to run test suite.
 
 ..\regcomp$(o) : ..\regnodes.h ..\regcharclass.h
 
 ..\regexec$(o) : ..\regnodes.h ..\regcharclass.h
 
-$(DYNALOADER)$(o) : $(DYNALOADER).c $(CORE_H) $(EXTDIR)\DynaLoader\dlutils.c
-
 #----------------------------------------------------------------
 
 $(GLOBEXE) : perlglob.c
 	$(LINK32) $(OPTIMIZE) $(BLINK_FLAGS) -mconsole -o $@ perlglob.c $(LIBFILES)
 
 ..\git_version.h : $(HAVEMINIPERL) ..\make_patchnum.pl
-	cd .. && miniperl.exe -Ilib make_patchnum.pl
+	$(MINIPERL) -I..\lib ..\make_patchnum.pl
 
 # make sure that we recompile perl.c if the git version changes
 ..\perl$(o) : ..\git_version.h
 
-..\config.sh : $(CFGSH_TMPL) $(HAVEMINIPERL) config_sh.PL
+..\config.sh : $(CFGSH_TMPL) $(HAVEMINIPERL) config_sh.PL FindExt.pm
 	$(MINIPERL) -I..\lib config_sh.PL $(CFG_VARS) $(CFGSH_TMPL) > ..\config.sh
 
 $(CONFIGPM) : $(HAVEMINIPERL) ..\config.sh config_h.PL ..\minimod.pl
-	cd .. && miniperl.exe -Ilib configpm
+	$(MINIPERL) -I..\lib ..\configpm --chdir=..
 	$(XCOPY) *.h $(COREDIR)\\*.*
 	$(XCOPY) ..\\ext\\re\\re.pm $(LIBDIR)\\*.*
 	$(RCOPY) include $(COREDIR)\\*.*
 	$(XCOPY) ..\\*.h $(COREDIR)\\*.*
 	-$(MINIPERL) -I..\lib $(ICWD) config_h.PL "ARCHPREFIX=$(ARCHPREFIX)"
 
-# See the comment in Makefile.SH explaining this seemingly cranky ordering
-
-#
-# Copy the template config.h and set configurables at the end of it
-# as per the options chosen and compiler used.
-# Note: This config.h is only used to build miniperl.exe anyway, but
-# it's as well to have its options correct to be sure that it builds
-# and so that it's "-V" options are correct for use by makedef.pl. The
-# real config.h used to build perl.exe is generated from the top-level
-# config_h.SH by config_h.PL (run by miniperl.exe).
-#
 .\config.h : $(CONFIGPM)
 $(MINIDIR)\.exists : $(CFGH_TMPL)
 	if not exist "$(MINIDIR)" mkdir "$(MINIDIR)"
@@ -630,64 +570,18 @@
 	echo #undef HAS_STRTOULL&& \
 	echo #define Size_t_size ^4)>> config.h
 endif
-ifeq ($(USE_64_BIT_INT),define)
 	@(echo #define IVTYPE $(INT64)&& \
 	echo #define UVTYPE unsigned $(INT64)&& \
 	echo #define IVSIZE ^8&& \
 	echo #define UVSIZE ^8)>> config.h
-ifeq ($(USE_LONG_DOUBLE),define)
-	@(echo #define NV_PRESERVES_UV&& \
-	echo #define NV_PRESERVES_UV_BITS 64)>> config.h
-else
 	@(echo #undef NV_PRESERVES_UV&& \
 	echo #define NV_PRESERVES_UV_BITS 53)>> config.h
-endif
 	@(echo #define IVdf "I64d"&& \
 	echo #define UVuf "I64u"&& \
 	echo #define UVof "I64o"&& \
 	echo #define UVxf "I64x"&& \
 	echo #define UVXf "I64X"&& \
 	echo #define USE_64_BIT_INT)>> config.h
-else
-	@(echo #define IVTYPE long&& \
-	echo #define UVTYPE unsigned long&& \
-	echo #define IVSIZE ^4&& \
-	echo #define UVSIZE ^4&& \
-	echo #define NV_PRESERVES_UV&& \
-	echo #define NV_PRESERVES_UV_BITS 32&& \
-	echo #define IVdf "ld"&& \
-	echo #define UVuf "lu"&& \
-	echo #define UVof "lo"&& \
-	echo #define UVxf "lx"&& \
-	echo #define UVXf "lX"&& \
-	echo #undef USE_64_BIT_INT)>> config.h
-endif
-ifeq ($(USE_LONG_DOUBLE),define)
-	@(echo #define Gconvert^(x,n,t,b^) sprintf^(^(b^),"%%.*""Lg",^(n^),^(x^)^)&& \
-	echo #define HAS_FREXPL&& \
-	echo #define HAS_ISNANL&& \
-	echo #define HAS_MODFL&& \
-	echo #define HAS_MODFL_PROTO&& \
-	echo #define HAS_SQRTL&& \
-	echo #define HAS_STRTOLD&& \
-	echo #define PERL_PRIfldbl "Lf"&& \
-	echo #define PERL_PRIgldbl "Lg"&& \
-	echo #define PERL_PRIeldbl "Le"&& \
-	echo #define PERL_SCNfldbl "Lf"&& \
-	echo #define NVTYPE long double)>> config.h
-ifeq ($(WIN64),define)
-	@(echo #define NVSIZE ^16&& \
-	echo #define LONG_DOUBLESIZE ^16)>> config.h
-else
-	@(echo #define NVSIZE ^12&& \
-	echo #define LONG_DOUBLESIZE ^12)>> config.h
-endif
-	@(echo #define NV_OVERFLOWS_INTEGERS_AT 256.0*256.0*256.0*256.0*256.0*256.0*256.0*2.0*2.0*2.0*2.0*2.0*2.0*2.0*2.0&& \
-	echo #define NVef "Le"&& \
-	echo #define NVff "Lf"&& \
-	echo #define NVgf "Lg"&& \
-	echo #define USE_LONG_DOUBLE)>> config.h
-else
 	@(echo #define Gconvert^(x,n,t,b^) sprintf^(^(b^),"%%.*g",^(n^),^(x^)^)&& \
 	echo #undef HAS_FREXPL&& \
 	echo #undef HAS_ISNANL&& \
@@ -706,15 +600,7 @@
 	echo #define NVef "e"&& \
 	echo #define NVff "f"&& \
 	echo #define NVgf "g"&& \
-	echo #undef USE_LONG_DOUBLE)>> config.h
-endif
-ifeq ($(USE_CPLUSPLUS),define)
-	@(echo #define USE_CPLUSPLUS&& \
-	echo #endif)>> config.h
-else
-	@(echo #undef USE_CPLUSPLUS&& \
 	echo #endif)>> config.h
-endif
 #separate line since this is sentinal that this target is done
 	rem. > $(MINIDIR)\.exists
 
@@ -724,11 +610,6 @@
 $(MINIWIN32_OBJ) : $(CORE_NOCFG_H)
 	$(CC) -c $(CFLAGS) $(MINIBUILDOPT) -DPERL_IS_MINIPERL $(OBJOUT_FLAG)$@ $(PDBOUT) $(*F).c
 
-# -DPERL_IMPLICIT_SYS needs C++ for perllib.c
-# rules wrapped in .IFs break Win9X build (we end up with unbalanced []s unless
-# unless the .IF is true), so instead we use a .ELSE with the default.
-# This is the only file that depends on perlhost.h, vmem.h, and vdir.h
-
 perllib$(o)	: perllib.c perllibst.h .\perlhost.h .\vdir.h .\vmem.h
 ifeq ($(USE_IMP_SYS),define)
 	$(CC) -c -I. $(CFLAGS_O) $(CXX_FLAG) $(OBJOUT_FLAG)$@ $(PDBOUT) perllib.c
@@ -736,8 +617,6 @@
 	$(CC) -c -I. $(CFLAGS_O) $(OBJOUT_FLAG)$@ $(PDBOUT) perllib.c
 endif
 
-# 1. we don't want to rebuild miniperl.exe when config.h changes
-# 2. we don't want to rebuild miniperl.exe with non-default config.h
 $(MINI_OBJ)	: $(MINIDIR)\.exists $(CORE_NOCFG_H)
 
 $(WIN32_OBJ)	: $(CORE_H)
@@ -751,7 +630,7 @@
 perllibst.h : $(HAVEMINIPERL) $(CONFIGPM) create_perllibst_h.pl
 	$(MINIPERL) -I..\lib create_perllibst_h.pl
 
-perldll.def : $(HAVEMINIPERL) $(CONFIGPM) ..\global.sym ..\pp.sym ..\makedef.pl
+perldll.def : $(HAVEMINIPERL) $(CONFIGPM) ..\global.sym ..\pp.sym ..\makedef.pl create_perllibst_h.pl
 	$(MINIPERL) -I..\lib -w ..\makedef.pl PLATFORM=win32 $(OPTIMIZE) $(DEFINES) \
 	$(BUILDOPT) CCTYPE=$(CCTYPE) TARG_DIR=..\ > perldll.def
 
@@ -774,9 +653,6 @@
 		cd .. && rmdir /s /q $(STATICDIR)
 	$(XCOPY) $(PERLSTATICLIB) $(COREDIR)
 
-$(PERLEXE_ICO): $(HAVEMINIPERL) ..\uupacktool.pl $(PERLEXE_ICO).packd
-	$(MINIPERL) -I..\lib ..\uupacktool.pl -u $(PERLEXE_ICO).packd $(PERLEXE_ICO)
-
 $(PERLEXE_RES): perlexe.rc $(PERLEXE_ICO)
 
 $(MINIMOD) : $(HAVEMINIPERL) ..\minimod.pl
@@ -802,18 +678,15 @@
 	$(MINIPERL) -I..\lib ..\x2p\s2p.PL
 	$(LINK32) -mconsole -o $@ $(BLINK_FLAGS) $(LIBFILES) $(X2P_OBJ)
 
-$(MINIDIR)\globals$(o) : $(UUDMAP_H)
+$(MINIDIR)\globals$(o) : $(UUDMAP_H) $(BITCOUNT_H)
 
-$(UUDMAP_H) : $(GENUUDMAP)
-	$(GENUUDMAP) > $(UUDMAP_H)
+$(UUDMAP_H) $(BITCOUNT_H) : $(GENUUDMAP)
+	$(GENUUDMAP) $(UUDMAP_H) $(BITCOUNT_H)
 
 $(GENUUDMAP) : $(GENUUDMAP_OBJ)
 	$(LINK32) $(CFLAGS_O) -o $@ $(GENUUDMAP_OBJ) \
 	$(BLINK_FLAGS) $(LIBFILES)
 
-#This generates a stub ppport.h & creates & fills /lib/CORE to allow for XS
-#building .c->.obj wise (linking is a different thing). This target is AKA
-#$(HAVE_COREDIR).
 $(COREDIR)\ppport.h : $(CORE_H)
 	$(XCOPY) *.h $(COREDIR)\\*.*
 	$(RCOPY) include $(COREDIR)\\*.*
@@ -834,56 +707,42 @@
 	    $(PERLEXE_OBJ) $(PERLEXE_RES) $(PERLIMPLIB) $(LIBFILES)
 	copy $(PERLEXE) $(WPERLEXE)
 	$(MINIPERL) -I..\lib bin\exetype.pl $(WPERLEXE) WINDOWS
-	copy splittree.pl ..
-	$(MINIPERL) -I..\lib ..\splittree.pl "../LIB" $(AUTODIR)
 
 $(PERLEXESTATIC): $(PERLSTATICLIB) $(CONFIGPM) $(PERLEXEST_OBJ) $(PERLEXE_RES)
 	$(LINK32) -mconsole -o $@ $(BLINK_FLAGS) \
 	    $(PERLEXEST_OBJ) $(PERLEXE_RES) $(PERLSTATICLIB) $(LIBFILES)
 
-$(DYNALOADER).c: $(HAVEMINIPERL) $(EXTDIR)\DynaLoader\dl_win32.xs $(CONFIGPM)
-	if not exist $(AUTODIR) mkdir $(AUTODIR)
-	cd $(EXTDIR)\DynaLoader \
-		&& ..\$(MINIPERL) -I..\..\lib DynaLoader_pm.PL \
-		&& ..\$(MINIPERL) -I..\..\lib XSLoader_pm.PL
-	$(XCOPY) $(EXTDIR)\DynaLoader\DynaLoader.pm $(LIBDIR)\$(NULL)
-	$(XCOPY) $(EXTDIR)\DynaLoader\XSLoader.pm $(LIBDIR)\$(NULL)
-	cd $(EXTDIR)\DynaLoader \
-		&& $(XSUBPP) dl_win32.xs > ..\$(DYNALOADER).c
-
-$(EXTDIR)\DynaLoader\dl_win32.xs: dl_win32.xs
-	copy dl_win32.xs $(EXTDIR)\DynaLoader\dl_win32.xs
-
-#-------------------------------------------------------------------------------
-# There's no direct way to mark a dependency on
-# DynaLoader.pm, so this will have to do
-
-MakePPPort: $(HAVEMINIPERL) $(CONFIGPM)
-	$(MINIPERL) -I..\lib ..\mkppport
+MakePPPort: $(HAVEMINIPERL) $(CONFIGPM) Extensions_nonxs
+	$(MINIPERL) -I..\lib $(ICWD) ..\mkppport
 
 $(HAVEMINIPERL): $(MINI_OBJ)
 	$(LINK32) -mconsole -o $(MINIPERL) $(BLINK_FLAGS) $(MINI_OBJ) $(LIBFILES)
 	rem . > $@
 
-#most of deps of this target are in DYNALOADER and therefore omitted here
-Extensions : ..\make_ext.pl $(HAVEMINIPERL) $(PERLDEP) $(CONFIGPM)
+Extensions : ..\make_ext.pl $(HAVEMINIPERL) $(PERLDEP) $(CONFIGPM) $(DYNALOADER)
 	$(XCOPY) ..\\*.h $(COREDIR)\\*.*
-	$(MINIPERL) -I..\lib $(ICWD) ..\make_ext.pl "MAKE=$(PLMAKE)" --dir=$(EXTDIR) --dynamic
+	$(MINIPERL) -I..\lib $(ICWD) ..\make_ext.pl "MAKE=$(PLMAKE)" --dir=$(CPANDIR) --dir=$(DISTDIR) --dir=$(EXTDIR) --dynamic
 
-Extensions_static : ..\make_ext.pl $(HAVEMINIPERL) list_static_libs.pl $(CONFIGPM)
+Extensions_static : ..\make_ext.pl $(HAVEMINIPERL) list_static_libs.pl $(CONFIGPM) Extensions_nonxs
 	$(XCOPY) ..\\*.h $(COREDIR)\\*.*
-	$(MINIPERL) -I..\lib $(ICWD) ..\make_ext.pl "MAKE=$(PLMAKE)" --dir=$(EXTDIR) --static
+	$(MINIPERL) -I..\lib $(ICWD) ..\make_ext.pl "MAKE=$(PLMAKE)" --dir=$(CPANDIR) --dir=$(DISTDIR) --dir=$(EXTDIR) --static
 	$(MINIPERL) -I..\lib $(ICWD) list_static_libs.pl > Extensions_static
 
+Extensions_nonxs : ..\make_ext.pl $(HAVEMINIPERL) $(PERLDEP) $(CONFIGPM) ..\pod\perlfunc.pod
+	$(XCOPY) ..\\*.h $(COREDIR)\\*.*
+	$(MINIPERL) -I..\lib $(ICWD) ..\make_ext.pl "MAKE=$(PLMAKE)" --dir=$(CPANDIR) --dir=$(DISTDIR) --dir=$(EXTDIR) --nonxs
+
+$(DYNALOADER) : ..\make_ext.pl $(HAVEMINIPERL) $(PERLDEP) $(CONFIGPM) Extensions_nonxs
+	$(XCOPY) ..\\*.h $(COREDIR)\\*.*
+	$(MINIPERL) -I..\lib $(ICWD) ..\make_ext.pl "MAKE=$(PLMAKE)" --dir=$(EXTDIR) --dynaloader
+
 #-------------------------------------------------------------------------------
 
-doc: $(PERLEXE)
+doc: $(PERLEXE) ..\pod\perltoc.pod
 	$(PERLEXE) -I..\lib ..\installhtml --podroot=.. --htmldir=$(HTMLDIR) \
 	    --podpath=pod:lib:ext:utils --htmlroot="file://$(subst :,|,$(INST_HTML))" \
 	    --libpod=perlfunc:perlguts:perlvar:perlrun:perlop --recurse
 
-# Note that this next section is parsed (and regenerated) by pod/buildtoc
-# so please check that script before making structural changes here
 utils: $(PERLEXE) $(X2P)
 	cd ..\utils && $(PLMAKE) PERL=$(MINIPERL)
 	copy ..\README.aix      ..\pod\perlaix.pod
@@ -905,10 +764,8 @@
 	copy ..\README.jp       ..\pod\perljp.pod
 	copy ..\README.ko       ..\pod\perlko.pod
 	copy ..\README.linux    ..\pod\perllinux.pod
-	copy ..\README.machten  ..\pod\perlmachten.pod
 	copy ..\README.macos    ..\pod\perlmacos.pod
 	copy ..\README.macosx   ..\pod\perlmacosx.pod
-	copy ..\README.mint     ..\pod\perlmint.pod
 	copy ..\README.mpeix    ..\pod\perlmpeix.pod
 	copy ..\README.netware  ..\pod\perlnetware.pod
 	copy ..\README.openbsd  ..\pod\perlopenbsd.pod
@@ -927,13 +784,17 @@
 	copy ..\README.vos      ..\pod\perlvos.pod
 	copy ..\README.win32    ..\pod\perlwin32.pod
 	copy ..\pod\perl__PERL_VERSION__delta.pod ..\pod\perldelta.pod
-	cd ..\lib && $(PERLEXE) lib_pm.PL
 	cd ..\pod && $(PLMAKE) -f ..\win32\pod.mak converters
 	$(PERLEXE) -I..\lib $(PL2BAT) $(UTILS)
+	$(PERLEXE) $(ICWD) ..\autodoc.pl ..
+	$(PERLEXE) $(ICWD) ..\pod\perlmodlib.PL -q ..
+
+..\pod\perltoc.pod: $(PERLEXE) Extensions Extensions_nonxs
+	$(PERLEXE) -f ..\pod\buildtoc -q
 
 install : all installbare installhtml
 
-installbare : utils
+installbare : utils ..\pod\perltoc.pod
 	$(PERLEXE) ..\installperl
 	if exist $(WPERLEXE) $(XCOPY) $(WPERLEXE) $(INST_BIN)\$(NULL)
 	if exist $(PERLEXESTATIC) $(XCOPY) $(PERLEXESTATIC) $(INST_BIN)\$(NULL)
@@ -945,5 +806,7 @@
 installhtml : doc
 	$(RCOPY) $(HTMLDIR)\*.* $(INST_HTML)\$(NULL)
 
-$(UNIDATAFILES) : $(HAVEMINIPERL) $(CONFIGPM) ..\lib\unicore\mktables
-	cd ..\lib\unicore && ..\$(MINIPERL) -I.. mktables -check $@ $(FIRSTUNIFILE)
+$(UNIDATAFILES) : ..\pod\perluniprops.pod
+
+..\pod\perluniprops.pod: ..\lib\unicore\mktables $(CONFIGPM) $(HAVEMINIPERL) ..\lib\unicore\mktables Extensions_nonxs
+	cd ..\lib\unicore && ..\$(MINIPERL) -I.. -I..\..\cpan\Cwd\lib mktables
PATCH
    }
    if (_ge($version, "5.11.3")) {
        _patch_gnumakefile($version, <<'PATCH');
--- win32/GNUmakefile
+++ win32/GNUmakefile
@@ -226,16 +226,17 @@
 PERLSTATIC	=
 
 # Unicode data files generated by mktables
-FIRSTUNIFILE	= ..\lib\unicore\Canonical.pl
-UNIDATAFILES	= ..\lib\unicore\Canonical.pl ..\lib\unicore\Exact.pl \
-		  ..\lib\unicore\Properties ..\lib\unicore\Decomposition.pl \
+FIRSTUNIFILE	= ..\lib\unicore\Decomposition.pl
+UNIDATAFILES	= ..\lib\unicore\Decomposition.pl \
 		  ..\lib\unicore\CombiningClass.pl ..\lib\unicore\Name.pl \
-		  ..\lib\unicore\PVA.pl
+		  ..\lib\unicore\Heavy.pl ..\lib\unicore\mktables.lst     \
+		  ..\lib\unicore\TestProp.pl
 
 # Directories of Unicode data files generated by mktables
 UNIDATADIR1	= ..\lib\unicore\To
 UNIDATADIR2	= ..\lib\unicore\lib
 
+PERLEXE_MANIFEST= .\perlexe.manifest
 PERLEXE_ICO	= .\perlexe.ico
 PERLEXE_RES	= .\perlexe.res
 PERLDLL_RES	=
@@ -653,7 +654,7 @@
 		cd .. && rmdir /s /q $(STATICDIR)
 	$(XCOPY) $(PERLSTATICLIB) $(COREDIR)
 
-$(PERLEXE_RES): perlexe.rc $(PERLEXE_ICO)
+$(PERLEXE_RES): perlexe.rc $(PERLEXE_MANIFEST) $(PERLEXE_ICO)
 
 $(MINIMOD) : $(HAVEMINIPERL) ..\minimod.pl
 	cd .. && miniperl minimod.pl > lib\ExtUtils\Miniperl.pm && cd win32
@@ -809,4 +810,4 @@
 $(UNIDATAFILES) : ..\pod\perluniprops.pod
 
 ..\pod\perluniprops.pod: ..\lib\unicore\mktables $(CONFIGPM) $(HAVEMINIPERL) ..\lib\unicore\mktables Extensions_nonxs
-	cd ..\lib\unicore && ..\$(MINIPERL) -I.. -I..\..\cpan\Cwd\lib mktables
+	$(MINIPERL) -I..\lib $(ICWD) ..\lib\unicore\mktables -C ..\lib\unicore -P ..\pod -maketest -makelist -p
PATCH
    }
}

sub _patch_gnumakefile_509 {
    my $version = shift;
    _write_gnumakefile($version, <<'MAKEFILE');
SHELL := cmd.exe
GCCBIN := gcc
INST_DRV := c:
INST_TOP := $(INST_DRV)\perl
#INST_VER	:= \__INST_VER__
#INST_ARCH	:= \$(ARCHNAME)
#USE_SITECUST	:= define
USE_MULTI	:= define
USE_ITHREADS	:= define
USE_IMP_SYS	:= define
USE_PERLIO	:= define
USE_LARGE_FILES	:= define
#USE_64_BIT_INT	:= define
#USE_LONG_DOUBLE :=define
#USE_NO_REGISTRY := define
CCTYPE		:= GCC
#CFG		:= Debug
#USE_PERLCRT	= define
#USE_SETARGV	:= define
CRYPT_SRC	= .\fcrypt.c
#CRYPT_LIB	= fcrypt.lib
#PERL_MALLOC	:= define
#DEBUG_MSTATS	:= define
CCHOME		:= C:\MinGW

CCINCDIR := $(CCHOME)\include
CCLIBDIR := $(CCHOME)\lib
CCDLLDIR := $(CCHOME)\bin
ARCHPREFIX :=

BUILDOPT	:= $(BUILDOPTEXTRA)

BUILDOPT	+= -DPERL_TEXTMODE_SCRIPTS

EXTRALIBDIRS	:=


D_CRYPT		?= undef
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

ifneq ("$(CRYPT_SRC)$(CRYPT_LIB)", "")
D_CRYPT		= define
CRYPT_FLAG	= -DHAVE_DES_FCRYPT
endif

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
EXTUTILSDIR	= $(LIBDIR)\ExtUtils
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
DEFINES		= -DWIN32 -DWIN64 -DCONSERVATIVE -DNO_STRICT $(CRYPT_FLAG)
LOCDEFS		= -DPERLDLL -DPERL_CORE
CXX_FLAG	= -xc++
LIBC		=
LIBFILES	= $(LIBC) -lmoldname -lkernel32 -luser32 -lgdi32 -lwinspool \
	-lcomdlg32 -ladvapi32 -lshell32 -lole32 -loleaut32 -lnetapi32 \
	-luuid -lws2_32 -lmpr -lwinmm -lversion -lodbc32 -lodbccp32

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

MINIPERL	= ..\miniperl.exe
HAVEMINIPERL	= .have_miniperl
MINIDIR		= mini
PERLEXE		= ..\perl.exe
WPERLEXE	= ..\wperl.exe
STATICDIR	= .\static.tmp
GLOBEXE		= ..\perlglob.exe
CONFIGPM	= ..\lib\Config.pm ..\lib\Config_heavy.pl
MINIMOD	= ..\lib\ExtUtils\Miniperl.pm
X2P		= ..\x2p\a2p.exe
PERLEXE_RES	=
PERLDLL_RES	=


PERLDEP = $(PERLIMPLIB)


PL2BAT		= bin\pl2bat.pl

UTILS		=			\
		..\utils\h2ph		\
		..\utils\splain		\
		..\utils\dprofpp	\
		..\utils\perlbug	\
		..\utils\pl2pm 		\
		..\utils\c2ph		\
		..\utils\pstruct	\
		..\utils\h2xs		\
		..\utils\perldoc	\
		..\utils\perlcc		\
		..\utils\perlivp	\
		..\utils\libnetcfg	\
		..\utils\enc2xs		\
		..\utils\piconv		\
		..\utils\cpan		\
		..\pod\checkpods	\
		..\pod\pod2html		\
		..\pod\pod2latex	\
		..\pod\pod2man		\
		..\pod\pod2text		\
		..\pod\pod2usage	\
		..\pod\podchecker	\
		..\pod\podselect	\
		..\x2p\find2perl	\
		..\x2p\psed		\
		..\x2p\s2p		\
		..\lib\ExtUtils\xsubpp	\
		bin\exetype.pl		\
		bin\runperl.pl		\
		bin\pl2bat.pl		\
		bin\perlglob.pl		\
		bin\search.pl

CFGSH_TMPL	= config.gc
CFGH_TMPL	= config_H.gc
PERLIMPLIB	= $(COREDIR)\libperl__PERL_MINOR_VERSION__$(a)
PERLIMPLIBBASE	= libperl__PERL_MINOR_VERSION__$(a)
INT64		= long long
PERLEXPLIB	= $(COREDIR)\perl__PERL_MINOR_VERSION__.exp
PERLDLL		= ..\perl__PERL_MINOR_VERSION__.dll

# don't let "gmake -n all" try to run "miniperl.exe make_ext.pl"
PLMAKE		= gmake

XCOPY		= xcopy /f /r /i /d /y
RCOPY		= xcopy /f /r /i /e /d /y
NOOP		= @rem

XSUBPP		= ..\$(MINIPERL) -I..\..\lib ..\$(EXTUTILSDIR)\xsubpp \
		-C++ -prototypes

MICROCORE_SRC	=		\
		..\av.c		\
		..\deb.c	\
		..\doio.c	\
		..\doop.c	\
		..\dump.c	\
		..\globals.c	\
		..\gv.c		\
		..\hv.c		\
		..\locale.c	\
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
		..\util.c	\
		..\xsutils.c

EXTRACORE_SRC	+= perllib.c

ifeq ($(PERL_MALLOC),define)
EXTRACORE_SRC	+= ..\malloc.c
endif

EXTRACORE_SRC	+= ..\perlio.c

WIN32_SRC	=		\
		.\win32.c	\
		.\win32sck.c	\
		.\win32thread.c	\
		.\win32io.c

ifneq ($(CRYPT_SRC), "")
WIN32_SRC	+= $(CRYPT_SRC)
endif

DLL_SRC		= $(DYNALOADER).c

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
		..\thrdvar.h	\
		.\include\dirent.h	\
		.\include\netdb.h	\
		.\include\sys\socket.h	\
		.\win32.h

CORE_H		= $(CORE_NOCFG_H) .\config.h

MICROCORE_OBJ	= $(MICROCORE_SRC:.c=$(o))
CORE_OBJ	= $(MICROCORE_OBJ) $(EXTRACORE_SRC:.c=$(o))
WIN32_OBJ	= $(WIN32_SRC:.c=$(o))

MINICORE_OBJ	= $(subst ..\,mini\,$(MICROCORE_OBJ))	\
		  $(MINIDIR)\miniperlmain$(o)	\
		  $(MINIDIR)\perlio$(o)
MINIWIN32_OBJ	= $(subst .\,mini\,$(WIN32_OBJ))
MINI_OBJ	= $(MINICORE_OBJ) $(MINIWIN32_OBJ)
DLL_OBJ		= $(DLL_SRC:.c=$(o))
X2P_OBJ		= $(X2P_SRC:.c=$(o))
PERLDLL_OBJ	= $(CORE_OBJ)
PERLEXE_OBJ	= perlmain$(o)
PERLEXEST_OBJ	= perlmainst$(o)

PERLDLL_OBJ	+= $(WIN32_OBJ) $(DLL_OBJ)

ifneq ($(USE_SETARGV),)
SETARGV_OBJ	= setargv$(o)
endif

ifeq ($(ALL_STATIC),define)
STATIC_EXT	= * !Win32 !SDBM_File !Encode
else
#STATIC_EXT	= Cwd Compress/Raw/Zlib
STATIC_EXT	= Win32CORE
endif

DYNALOADER	= $(EXTDIR)\DynaLoader\DynaLoader

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

ICWD = -I..\cpan\Cwd -I..\cpan\Cwd\lib

#
# Top targets
#

.PHONY: all

all : .\config.h $(GLOBEXE) $(MINIMOD) $(CONFIGPM) $(PERLEXE) $(X2P) Extensions
	@echo Everything is up to date. '$(MAKE_BARE) test' to run test suite.

$(DYNALOADER)$(o) : $(DYNALOADER).c $(CORE_H) $(EXTDIR)\DynaLoader\dlutils.c

#----------------------------------------------------------------

$(GLOBEXE) : perlglob.c
	$(LINK32) $(OPTIMIZE) $(BLINK_FLAGS) -mconsole -o $@ perlglob.c $(LIBFILES)

..\config.sh : $(CFGSH_TMPL) $(HAVEMINIPERL) config_sh.PL
	$(MINIPERL) -I..\lib config_sh.PL $(CFG_VARS) $(CFGSH_TMPL) > ..\config.sh

$(CONFIGPM) : $(HAVEMINIPERL) ..\config.sh config_h.PL ..\minimod.pl
	cd .. && miniperl.exe -Ilib configpm
	$(XCOPY) *.h $(COREDIR)\\*.*
	$(XCOPY) ..\\ext\\re\\re.pm $(LIBDIR)\\*.*
	$(RCOPY) include $(COREDIR)\\*.*
	$(XCOPY) ..\\*.h $(COREDIR)\\*.*
	-$(MINIPERL) -I..\lib $(ICWD) config_h.PL "ARCHPREFIX=$(ARCHPREFIX)"

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

perllib$(o)	: perllib.c .\perlhost.h .\vdir.h .\vmem.h
ifeq ($(USE_IMP_SYS),define)
	$(CC) -c -I. $(CFLAGS_O) $(CXX_FLAG) $(OBJOUT_FLAG)$@ $(PDBOUT) perllib.c
else
	$(CC) -c -I. $(CFLAGS_O) $(OBJOUT_FLAG)$@ $(PDBOUT) perllib.c
endif

$(MINI_OBJ)	: $(MINIDIR)\.exists $(CORE_NOCFG_H)

$(WIN32_OBJ)	: $(CORE_H)
$(CORE_OBJ)	: $(CORE_H)
$(DLL_OBJ)	: $(CORE_H)
$(X2P_OBJ)	: $(CORE_H)

perldll.def : $(HAVEMINIPERL) $(CONFIGPM) ..\global.sym ..\pp.sym ..\makedef.pl
	$(MINIPERL) -w ..\makedef.pl PLATFORM=win32 $(OPTIMIZE) $(DEFINES) $(BUILDOPT) \
	    CCTYPE=$(CCTYPE) > perldll.def

$(PERLEXPLIB) : $(PERLIMPLIB)

$(PERLIMPLIB) : perldll.def
	$(IMPLIB) -k -d perldll.def -l $(PERLIMPLIB) -e $(PERLEXPLIB)

$(PERLDLL): perldll.def $(PERLEXPLIB) $(PERLDLL_OBJ)
	$(LINK32) -mdll -o $@ $(BLINK_FLAGS) \
	   $(PERLDLL_OBJ) $(LIBFILES) $(PERLEXPLIB)

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
	copy splittree.pl ..
	$(MINIPERL) -I..\lib ..\splittree.pl "../LIB" $(AUTODIR)

$(DYNALOADER).c: $(HAVEMINIPERL) $(EXTDIR)\DynaLoader\dl_win32.xs $(CONFIGPM)
	if not exist $(AUTODIR) mkdir $(AUTODIR)
	cd $(EXTDIR)\DynaLoader \
		&& ..\$(MINIPERL) -I..\..\lib DynaLoader_pm.PL \
		&& ..\$(MINIPERL) -I..\..\lib XSLoader_pm.PL
	$(XCOPY) $(EXTDIR)\DynaLoader\DynaLoader.pm $(LIBDIR)\$(NULL)
	$(XCOPY) $(EXTDIR)\DynaLoader\XSLoader.pm $(LIBDIR)\$(NULL)
	cd $(EXTDIR)\DynaLoader \
		&& $(XSUBPP) dl_win32.xs > ..\$(DYNALOADER).c

$(EXTDIR)\DynaLoader\dl_win32.xs: dl_win32.xs
	copy dl_win32.xs $(EXTDIR)\DynaLoader\dl_win32.xs

$(HAVEMINIPERL): $(MINI_OBJ)
	$(LINK32) -mconsole -o $(MINIPERL) $(BLINK_FLAGS) $(MINI_OBJ) $(LIBFILES)
	rem . > $@

#most of deps of this target are in DYNALOADER and therefore omitted here
Extensions : buildext.pl $(HAVEMINIPERL) $(PERLDEP) $(CONFIGPM)
	$(MINIPERL) -I..\lib $(ICWD) buildext.pl "$(PLMAKE)" $(PERLDEP) $(EXTDIR)

#-------------------------------------------------------------------------------

doc: $(PERLEXE)
	$(PERLEXE) -I..\lib ..\installhtml --podroot=.. --htmldir=$(HTMLDIR) \
	    --podpath=pod:lib:utils --htmlroot="file://$(subst :,|,$(INST_HTML))"\
	    --recurse

utils: $(PERLEXE) $(X2P)
	cd ..\utils && $(PLMAKE) PERL=$(MINIPERL)
	copy ..\README.aix      ..\pod\perlaix.pod
	copy ..\README.amiga    ..\pod\perlamiga.pod
	copy ..\README.apollo   ..\pod\perlapollo.pod
	copy ..\README.beos     ..\pod\perlbeos.pod
	copy ..\README.bs2000   ..\pod\perlbs2000.pod
	copy ..\README.ce       ..\pod\perlce.pod
	copy ..\README.cn       ..\pod\perlcn.pod
	copy ..\README.cygwin   ..\pod\perlcygwin.pod
	copy ..\README.dgux     ..\pod\perldgux.pod
	copy ..\README.dos      ..\pod\perldos.pod
	copy ..\README.epoc     ..\pod\perlepoc.pod
	copy ..\README.freebsd  ..\pod\perlfreebsd.pod
	copy ..\README.hpux     ..\pod\perlhpux.pod
	copy ..\README.hurd     ..\pod\perlhurd.pod
	copy ..\README.irix     ..\pod\perlirix.pod
	copy ..\README.jp       ..\pod\perljp.pod
	copy ..\README.ko       ..\pod\perlko.pod
	copy ..\README.machten  ..\pod\perlmachten.pod
	copy ..\README.macos    ..\pod\perlmacos.pod
	copy ..\README.macosx   ..\pod\perlmacosx.pod
	copy ..\README.mint     ..\pod\perlmint.pod
	copy ..\README.mpeix    ..\pod\perlmpeix.pod
	copy ..\README.netware  ..\pod\perlnetware.pod
	copy ..\README.os2      ..\pod\perlos2.pod
	copy ..\README.os390    ..\pod\perlos390.pod
	copy ..\README.os400    ..\pod\perlos400.pod
	copy ..\README.plan9    ..\pod\perlplan9.pod
	copy ..\README.qnx      ..\pod\perlqnx.pod
	copy ..\README.solaris  ..\pod\perlsolaris.pod
	copy ..\README.tru64    ..\pod\perltru64.pod
	copy ..\README.tw       ..\pod\perltw.pod
	copy ..\README.uts      ..\pod\perluts.pod
	copy ..\README.vmesa    ..\pod\perlvmesa.pod
	copy ..\README.vms      ..\pod\perlvms.pod
	copy ..\README.vos      ..\pod\perlvos.pod
	copy ..\README.win32    ..\pod\perlwin32.pod
	cd ..\lib && $(PERLEXE) -Dtls lib_pm.PL
	cd ..\pod && $(PLMAKE) -f ..\win32\pod.mak converters
	$(PERLEXE) -I..\lib $(PL2BAT) $(UTILS)

install : all installbare installhtml

installbare : utils
	$(PERLEXE) ..\installperl
	if exist $(WPERLEXE) $(XCOPY) $(WPERLEXE) $(INST_BIN)\$(NULL)
	$(XCOPY) $(GLOBEXE) $(INST_BIN)\$(NULL)
	$(XCOPY) "bin\*.bat" $(INST_SCRIPT)\$(NULL)

installhtml : doc
	$(RCOPY) $(HTMLDIR)\*.* $(INST_HTML)\$(NULL)
MAKEFILE
    if (_ge($version, "5.9.1")) {
        _patch_gnumakefile($version, <<'PATCH');
--- win32/GNUmakefile
+++ win32/GNUmakefile
@@ -791,6 +791,7 @@
 	copy ..\README.vms      ..\pod\perlvms.pod
 	copy ..\README.vos      ..\pod\perlvos.pod
 	copy ..\README.win32    ..\pod\perlwin32.pod
+	copy ..\pod\perl__PERL_VERSION__delta.pod ..\pod\perldelta.pod
 	cd ..\lib && $(PERLEXE) -Dtls lib_pm.PL
 	cd ..\pod && $(PLMAKE) -f ..\win32\pod.mak converters
 	$(PERLEXE) -I..\lib $(PL2BAT) $(UTILS)
PATCH
    }
    if (_ge($version, "5.9.2")) {
        _patch_gnumakefile($version, <<'PATCH');
--- win32/GNUmakefile
+++ win32/GNUmakefile
@@ -240,7 +240,19 @@
 CONFIGPM	= ..\lib\Config.pm ..\lib\Config_heavy.pl
 MINIMOD	= ..\lib\ExtUtils\Miniperl.pm
 X2P		= ..\x2p\a2p.exe
-PERLEXE_RES	=
+
+# Unicode data files generated by mktables
+UNIDATAFILES	 = ..\lib\unicore\Canonical.pl ..\lib\unicore\Exact.pl \
+		   ..\lib\unicore\Properties ..\lib\unicore\Decomposition.pl \
+		   ..\lib\unicore\CombiningClass.pl ..\lib\unicore\Name.pl \
+		   ..\lib\unicore\PVA.pl
+
+# Directories of Unicode data files generated by mktables
+UNIDATADIR1	= ..\lib\unicore\To
+UNIDATADIR2	= ..\lib\unicore\lib
+
+PERLEXE_ICO	= .\perlexe.ico
+PERLEXE_RES	= .\perlexe.res
 PERLDLL_RES	=
 
 
@@ -479,7 +491,8 @@
 
 .PHONY: all
 
-all : .\config.h $(GLOBEXE) $(MINIMOD) $(CONFIGPM) $(PERLEXE) $(X2P) Extensions
+all : .\config.h $(GLOBEXE) $(MINIMOD) $(CONFIGPM) \
+		$(UNIDATAFILES) $(PERLEXE) $(X2P) Extensions
 	@echo Everything is up to date. '$(MAKE_BARE) test' to run test suite.
 
 $(DYNALOADER)$(o) : $(DYNALOADER).c $(CORE_H) $(EXTDIR)\DynaLoader\dlutils.c
@@ -685,6 +698,11 @@
 	$(LINK32) -mdll -o $@ $(BLINK_FLAGS) \
 	   $(PERLDLL_OBJ) $(LIBFILES) $(PERLEXPLIB)
 
+$(PERLEXE_ICO): $(HAVEMINIPERL) makeico.pl
+	$(MINIPERL) makeico.pl > $@
+
+$(PERLEXE_RES): perlexe.rc $(PERLEXE_ICO)
+
 $(MINIMOD) : $(HAVEMINIPERL) ..\minimod.pl
 	cd .. && miniperl minimod.pl > lib\ExtUtils\Miniperl.pm && cd win32
 
@@ -745,6 +763,7 @@
 #most of deps of this target are in DYNALOADER and therefore omitted here
 Extensions : buildext.pl $(HAVEMINIPERL) $(PERLDEP) $(CONFIGPM)
 	$(MINIPERL) -I..\lib $(ICWD) buildext.pl "$(PLMAKE)" $(PERLDEP) $(EXTDIR)
+	$(MINIPERL) -I..\lib $(ICWD) buildext.pl "$(PLMAKE)" $(PERLDEP) ext
 
 #-------------------------------------------------------------------------------
 
@@ -806,3 +825,6 @@
 
 installhtml : doc
 	$(RCOPY) $(HTMLDIR)\*.* $(INST_HTML)\$(NULL)
+
+$(UNIDATAFILES) : $(HAVEMINIPERL) $(CONFIGPM) ..\lib\unicore\mktables
+	cd ..\lib\unicore && ..\$(MINIPERL) -I.. mktables
PATCH
    }
    if (_ge($version, "5.9.3")) {
        _patch_gnumakefile($version, <<'PATCH');
--- win32/GNUmakefile
+++ win32/GNUmakefile
@@ -255,7 +255,6 @@
 PERLEXE_RES	= .\perlexe.res
 PERLDLL_RES	=
 
-
 PERLDEP = $(PERLIMPLIB)
 
 
@@ -276,7 +275,14 @@
 		..\utils\libnetcfg	\
 		..\utils\enc2xs		\
 		..\utils\piconv		\
+		..\utils\corelist	\
 		..\utils\cpan		\
+		..\utils\xsubpp		\
+		..\utils\prove		\
+		..\utils\ptar		\
+		..\utils\ptardiff	\
+		..\utils\shasum		\
+		..\utils\instmodsh	\
 		..\pod\checkpods	\
 		..\pod\pod2html		\
 		..\pod\pod2latex	\
@@ -288,7 +294,6 @@
 		..\x2p\find2perl	\
 		..\x2p\psed		\
 		..\x2p\s2p		\
-		..\lib\ExtUtils\xsubpp	\
 		bin\exetype.pl		\
 		bin\runperl.pl		\
 		bin\pl2bat.pl		\
@@ -323,6 +328,7 @@
 		..\gv.c		\
 		..\hv.c		\
 		..\locale.c	\
+		..\mathoms.c	\
 		..\mg.c		\
 		..\numeric.c	\
 		..\op.c		\
@@ -398,6 +404,7 @@
 		..\perly.h	\
 		..\pp.h		\
 		..\proto.h	\
+		..\regcomp.h	\
 		..\regexp.h	\
 		..\scope.h	\
 		..\sv.h		\
@@ -686,6 +693,7 @@
 $(X2P_OBJ)	: $(CORE_H)
 
 perldll.def : $(HAVEMINIPERL) $(CONFIGPM) ..\global.sym ..\pp.sym ..\makedef.pl
+	$(MINIPERL) -I..\lib buildext.pl --create-perllibst-h
 	$(MINIPERL) -w ..\makedef.pl PLATFORM=win32 $(OPTIMIZE) $(DEFINES) $(BUILDOPT) \
 	    CCTYPE=$(CCTYPE) > perldll.def
 
@@ -694,9 +702,9 @@
 $(PERLIMPLIB) : perldll.def
 	$(IMPLIB) -k -d perldll.def -l $(PERLIMPLIB) -e $(PERLEXPLIB)
 
-$(PERLDLL): perldll.def $(PERLEXPLIB) $(PERLDLL_OBJ)
+$(PERLDLL): perldll.def $(PERLEXPLIB) $(PERLDLL_OBJ) Extensions_static
 	$(LINK32) -mdll -o $@ $(BLINK_FLAGS) \
-	   $(PERLDLL_OBJ) $(LIBFILES) $(PERLEXPLIB)
+	   $(PERLDLL_OBJ) $(shell type Extensions_static) $(LIBFILES) $(PERLEXPLIB)
 
 $(PERLEXE_ICO): $(HAVEMINIPERL) makeico.pl
 	$(MINIPERL) makeico.pl > $@
@@ -762,8 +770,13 @@
 
 #most of deps of this target are in DYNALOADER and therefore omitted here
 Extensions : buildext.pl $(HAVEMINIPERL) $(PERLDEP) $(CONFIGPM)
-	$(MINIPERL) -I..\lib $(ICWD) buildext.pl "$(PLMAKE)" $(PERLDEP) $(EXTDIR)
-	$(MINIPERL) -I..\lib $(ICWD) buildext.pl "$(PLMAKE)" $(PERLDEP) ext
+	$(MINIPERL) -I..\lib $(ICWD) buildext.pl "$(PLMAKE)" $(PERLDEP) $(EXTDIR) --dynamic
+	$(MINIPERL) -I..\lib $(ICWD) buildext.pl "$(PLMAKE)" $(PERLDEP) ext --dynamic
+
+Extensions_static : buildext.pl $(HAVEMINIPERL) $(CONFIGPM)
+	$(MINIPERL) -I..\lib $(ICWD) buildext.pl "$(PLMAKE)" $(PERLDEP) $(EXTDIR) --static
+	$(MINIPERL) -I..\lib $(ICWD) buildext.pl "$(PLMAKE)" $(PERLDEP) ext --static
+	$(MINIPERL) -I..\lib buildext.pl --list-static-libs > Extensions_static
 
 #-------------------------------------------------------------------------------
 
PATCH
    }
    if (_ge($version, "5.9.4")) {
        _patch_gnumakefile($version, <<'PATCH');
--- win32/GNUmakefile
+++ win32/GNUmakefile
@@ -240,21 +240,10 @@
 CONFIGPM	= ..\lib\Config.pm ..\lib\Config_heavy.pl
 MINIMOD	= ..\lib\ExtUtils\Miniperl.pm
 X2P		= ..\x2p\a2p.exe
-
-# Unicode data files generated by mktables
-UNIDATAFILES	 = ..\lib\unicore\Canonical.pl ..\lib\unicore\Exact.pl \
-		   ..\lib\unicore\Properties ..\lib\unicore\Decomposition.pl \
-		   ..\lib\unicore\CombiningClass.pl ..\lib\unicore\Name.pl \
-		   ..\lib\unicore\PVA.pl
-
-# Directories of Unicode data files generated by mktables
-UNIDATADIR1	= ..\lib\unicore\To
-UNIDATADIR2	= ..\lib\unicore\lib
-
-PERLEXE_ICO	= .\perlexe.ico
-PERLEXE_RES	= .\perlexe.res
+PERLEXE_RES	=
 PERLDLL_RES	=
 
+
 PERLDEP = $(PERLIMPLIB)
 
 
@@ -275,6 +264,7 @@
 		..\utils\libnetcfg	\
 		..\utils\enc2xs		\
 		..\utils\piconv		\
+		..\utils\config_data	\
 		..\utils\corelist	\
 		..\utils\cpan		\
 		..\utils\xsubpp		\
@@ -499,7 +489,7 @@
 .PHONY: all
 
 all : .\config.h $(GLOBEXE) $(MINIMOD) $(CONFIGPM) \
-		$(UNIDATAFILES) $(PERLEXE) $(X2P) Extensions
+		$(UNIDATAFILES) MakePPPort $(PERLEXE) $(X2P) Extensions
 	@echo Everything is up to date. '$(MAKE_BARE) test' to run test suite.
 
 $(DYNALOADER)$(o) : $(DYNALOADER).c $(CORE_H) $(EXTDIR)\DynaLoader\dlutils.c
@@ -706,8 +696,8 @@
 	$(LINK32) -mdll -o $@ $(BLINK_FLAGS) \
 	   $(PERLDLL_OBJ) $(shell type Extensions_static) $(LIBFILES) $(PERLEXPLIB)
 
-$(PERLEXE_ICO): $(HAVEMINIPERL) makeico.pl
-	$(MINIPERL) makeico.pl > $@
+$(PERLEXE_ICO): $(HAVEMINIPERL) ..\uupacktool.pl $(PERLEXE_ICO).packd
+	$(MINIPERL) -I..\lib ..\uupacktool.pl -u $(PERLEXE_ICO).packd $(PERLEXE_ICO)
 
 $(PERLEXE_RES): perlexe.rc $(PERLEXE_ICO)
 
@@ -764,6 +754,10 @@
 $(EXTDIR)\DynaLoader\dl_win32.xs: dl_win32.xs
 	copy dl_win32.xs $(EXTDIR)\DynaLoader\dl_win32.xs
 
+
+MakePPPort: $(HAVEMINIPERL) $(CONFIGPM)
+	$(MINIPERL) -I..\lib ..\mkppport
+
 $(HAVEMINIPERL): $(MINI_OBJ)
 	$(LINK32) -mconsole -o $(MINIPERL) $(BLINK_FLAGS) $(MINI_OBJ) $(LIBFILES)
 	rem . > $@
PATCH
    }
    if (_ge($version, "5.9.5")) {
        _patch_gnumakefile($version, <<'PATCH');
--- win32/GNUmakefile
+++ win32/GNUmakefile
@@ -21,6 +21,7 @@
 #CRYPT_LIB	= fcrypt.lib
 #PERL_MALLOC	:= define
 #DEBUG_MSTATS	:= define
+#BUILD_STATIC	:= define
 CCHOME		:= C:\MinGW
 
 CCINCDIR := $(CCHOME)\include
@@ -235,14 +236,33 @@
 MINIDIR		= mini
 PERLEXE		= ..\perl.exe
 WPERLEXE	= ..\wperl.exe
+PERLEXESTATIC	= ..\perl-static.exe
 STATICDIR	= .\static.tmp
 GLOBEXE		= ..\perlglob.exe
-CONFIGPM	= ..\lib\Config.pm ..\lib\Config_heavy.pl
+CONFIGPM	= ..\lib\Config.pm
 MINIMOD	= ..\lib\ExtUtils\Miniperl.pm
 X2P		= ..\x2p\a2p.exe
-PERLEXE_RES	=
-PERLDLL_RES	=
+GENUUDMAP	= ..\generate_uudmap.exe
+ifeq ($(BUILD_STATIC),define)
+PERLSTATIC	= static
+else
+PERLSTATIC	= 
+endif
+
+# Unicode data files generated by mktables
+FIRSTUNIFILE	= ..\lib\unicore\Canonical.pl
+UNIDATAFILES	= ..\lib\unicore\Canonical.pl ..\lib\unicore\Exact.pl \
+		   ..\lib\unicore\Properties ..\lib\unicore\Decomposition.pl \
+		   ..\lib\unicore\CombiningClass.pl ..\lib\unicore\Name.pl \
+		   ..\lib\unicore\PVA.pl
+
+# Directories of Unicode data files generated by mktables
+UNIDATADIR1	= ..\lib\unicore\To
+UNIDATADIR2	= ..\lib\unicore\lib
 
+PERLEXE_ICO	= .\perlexe.ico
+PERLEXE_RES	= .\perlexe.res
+PERLDLL_RES	=
 
 PERLDEP = $(PERLIMPLIB)
 
@@ -259,7 +279,6 @@
 		..\utils\pstruct	\
 		..\utils\h2xs		\
 		..\utils\perldoc	\
-		..\utils\perlcc		\
 		..\utils\perlivp	\
 		..\utils\libnetcfg	\
 		..\utils\enc2xs		\
@@ -271,6 +290,9 @@
 		..\utils\prove		\
 		..\utils\ptar		\
 		..\utils\ptardiff	\
+		..\utils\cpanp-run-perl	\
+		..\utils\cpanp	\
+		..\utils\cpan2dist	\
 		..\utils\shasum		\
 		..\utils\instmodsh	\
 		..\pod\checkpods	\
@@ -294,6 +316,7 @@
 CFGH_TMPL	= config_H.gc
 PERLIMPLIB	= $(COREDIR)\libperl__PERL_MINOR_VERSION__$(a)
 PERLIMPLIBBASE	= libperl__PERL_MINOR_VERSION__$(a)
+PERLSTATICLIB	= ..\libperl__PERL_MINOR_VERSION__s$(a)
 INT64		= long long
 PERLEXPLIB	= $(COREDIR)\perl__PERL_MINOR_VERSION__.exp
 PERLDLL		= ..\perl__PERL_MINOR_VERSION__.dll
@@ -316,6 +339,7 @@
 		..\dump.c	\
 		..\globals.c	\
 		..\gv.c		\
+		..\mro.c	\
 		..\hv.c		\
 		..\locale.c	\
 		..\mathoms.c	\
@@ -407,7 +431,6 @@
 		..\EXTERN.h	\
 		..\perlvars.h	\
 		..\intrpvar.h	\
-		..\thrdvar.h	\
 		.\include\dirent.h	\
 		.\include\netdb.h	\
 		.\include\sys\socket.h	\
@@ -415,6 +438,8 @@
 
 CORE_H		= $(CORE_NOCFG_H) .\config.h
 
+UUDMAP_H       = ..\uudmap.h
+
 MICROCORE_OBJ	= $(MICROCORE_SRC:.c=$(o))
 CORE_OBJ	= $(MICROCORE_OBJ) $(EXTRACORE_SRC:.c=$(o))
 WIN32_OBJ	= $(WIN32_SRC:.c=$(o))
@@ -426,6 +451,7 @@
 MINI_OBJ	= $(MINICORE_OBJ) $(MINIWIN32_OBJ)
 DLL_OBJ		= $(DLL_SRC:.c=$(o))
 X2P_OBJ		= $(X2P_SRC:.c=$(o))
+GENUUDMAP_OBJ  = $(GENUUDMAP:.exe=$(o))
 PERLDLL_OBJ	= $(CORE_OBJ)
 PERLEXE_OBJ	= perlmain$(o)
 PERLEXEST_OBJ	= perlmainst$(o)
@@ -489,13 +515,19 @@
 .PHONY: all
 
 all : .\config.h $(GLOBEXE) $(MINIMOD) $(CONFIGPM) \
-		$(UNIDATAFILES) MakePPPort $(PERLEXE) $(X2P) Extensions
+		$(UNIDATAFILES) MakePPPort $(PERLEXE) $(X2P) Extensions $(PERLSTATIC)
 	@echo Everything is up to date. '$(MAKE_BARE) test' to run test suite.
 
+..\regcomp$(o) : ..\regnodes.h ..\regcharclass.h
+
+..\regexec$(o) : ..\regnodes.h ..\regcharclass.h
+
 $(DYNALOADER)$(o) : $(DYNALOADER).c $(CORE_H) $(EXTDIR)\DynaLoader\dlutils.c
 
 #----------------------------------------------------------------
 
+static: $(PERLEXESTATIC)
+
 $(GLOBEXE) : perlglob.c
 	$(LINK32) $(OPTIMIZE) $(BLINK_FLAGS) -mconsole -o $@ perlglob.c $(LIBFILES)
 
@@ -696,6 +728,16 @@
 	$(LINK32) -mdll -o $@ $(BLINK_FLAGS) \
 	   $(PERLDLL_OBJ) $(shell type Extensions_static) $(LIBFILES) $(PERLEXPLIB)
 
+$(PERLSTATICLIB): $(PERLDLL_OBJ) Extensions_static
+	$(LIB32) $(LIB_FLAGS) $@ $(PERLDLL_OBJ)
+	if exist $(STATICDIR) rmdir /s /q $(STATICDIR)
+	for %%i in ($(shell type Extensions_static)) do \
+		@mkdir $(STATICDIR) && cd $(STATICDIR) && \
+		$(ARCHPREFIX)ar x ..\%%i && \
+		$(ARCHPREFIX)ar q ..\$@ *$(o) && \
+		cd .. && rmdir /s /q $(STATICDIR)
+	$(XCOPY) $(PERLSTATICLIB) $(COREDIR)
+
 $(PERLEXE_ICO): $(HAVEMINIPERL) ..\uupacktool.pl $(PERLEXE_ICO).packd
 	$(MINIPERL) -I..\lib ..\uupacktool.pl -u $(PERLEXE_ICO).packd $(PERLEXE_ICO)
 
@@ -724,6 +766,15 @@
 	$(MINIPERL) -I..\lib ..\x2p\s2p.PL
 	$(LINK32) -mconsole -o $@ $(BLINK_FLAGS) $(LIBFILES) $(X2P_OBJ)
 
+$(MINIDIR)\globals$(o) : $(UUDMAP_H)
+
+$(UUDMAP_H) : $(GENUUDMAP)
+	$(GENUUDMAP) > $(UUDMAP_H)
+
+$(GENUUDMAP) : $(GENUUDMAP_OBJ)
+	$(LINK32) $(CFLAGS_O) -o $@ $(GENUUDMAP_OBJ) \
+	$(BLINK_FLAGS) $(LIBFILES)
+
 perlmain.c : runperl.c
 	copy runperl.c perlmain.c
 
@@ -741,6 +792,10 @@
 	copy splittree.pl ..
 	$(MINIPERL) -I..\lib ..\splittree.pl "../LIB" $(AUTODIR)
 
+$(PERLEXESTATIC): $(PERLSTATICLIB) $(CONFIGPM) $(PERLEXEST_OBJ) $(PERLEXE_RES)
+	$(LINK32) -mconsole -o $@ $(BLINK_FLAGS) \
+	    $(PERLEXEST_OBJ) $(PERLEXE_RES) $(PERLSTATICLIB) $(LIBFILES)
+
 $(DYNALOADER).c: $(HAVEMINIPERL) $(EXTDIR)\DynaLoader\dl_win32.xs $(CONFIGPM)
 	if not exist $(AUTODIR) mkdir $(AUTODIR)
 	cd $(EXTDIR)\DynaLoader \
@@ -764,12 +819,14 @@
 
 #most of deps of this target are in DYNALOADER and therefore omitted here
 Extensions : buildext.pl $(HAVEMINIPERL) $(PERLDEP) $(CONFIGPM)
+	$(XCOPY) ..\\*.h $(COREDIR)\\*.*
 	$(MINIPERL) -I..\lib $(ICWD) buildext.pl "$(PLMAKE)" $(PERLDEP) $(EXTDIR) --dynamic
-	$(MINIPERL) -I..\lib $(ICWD) buildext.pl "$(PLMAKE)" $(PERLDEP) ext --dynamic
+	-if exist ext $(MINIPERL) -I..\lib $(ICWD) buildext.pl "$(PLMAKE)" $(PERLDEP) ext --dynamic
 
 Extensions_static : buildext.pl $(HAVEMINIPERL) $(CONFIGPM)
+	$(XCOPY) ..\\*.h $(COREDIR)\\*.*
 	$(MINIPERL) -I..\lib $(ICWD) buildext.pl "$(PLMAKE)" $(PERLDEP) $(EXTDIR) --static
-	$(MINIPERL) -I..\lib $(ICWD) buildext.pl "$(PLMAKE)" $(PERLDEP) ext --static
+	-if exist ext $(MINIPERL) -I..\lib $(ICWD) buildext.pl "$(PLMAKE)" $(PERLDEP) ext --static
 	$(MINIPERL) -I..\lib buildext.pl --list-static-libs > Extensions_static
 
 #-------------------------------------------------------------------------------
@@ -827,11 +884,14 @@
 installbare : utils
 	$(PERLEXE) ..\installperl
 	if exist $(WPERLEXE) $(XCOPY) $(WPERLEXE) $(INST_BIN)\$(NULL)
+	if exist $(PERLEXESTATIC) $(XCOPY) $(PERLEXESTATIC) $(INST_BIN)\$(NULL)
 	$(XCOPY) $(GLOBEXE) $(INST_BIN)\$(NULL)
+	if exist ..\perl*.pdb $(XCOPY) ..\perl*.pdb $(INST_BIN)\$(NULL)
+	if exist ..\x2p\a2p.pdb $(XCOPY) ..\x2p\a2p.pdb $(INST_BIN)\$(NULL)
 	$(XCOPY) "bin\*.bat" $(INST_SCRIPT)\$(NULL)
 
 installhtml : doc
 	$(RCOPY) $(HTMLDIR)\*.* $(INST_HTML)\$(NULL)
 
 $(UNIDATAFILES) : $(HAVEMINIPERL) $(CONFIGPM) ..\lib\unicore\mktables
-	cd ..\lib\unicore && ..\$(MINIPERL) -I.. mktables
+	cd ..\lib\unicore && ..\$(MINIPERL) -I.. mktables -check $@ $(FIRSTUNIFILE)
PATCH
    }
}

sub _patch_gnumakefile_508 {
    my $version = shift;
    _write_gnumakefile($version, <<'MAKEFILE');
SHELL := cmd.exe
GCCBIN := gcc
INST_DRV := c:
INST_TOP := $(INST_DRV)\perl
#INST_VER	:= \__INST_VER__
#INST_ARCH	:= \$(ARCHNAME)
#USE_SITECUST	:= define
USE_MULTI	:= define
USE_ITHREADS	:= define
USE_IMP_SYS	:= define
USE_PERLIO	:= define
USE_LARGE_FILES	:= define
#USE_64_BIT_INT	:= define
#USE_LONG_DOUBLE :=define
#USE_NO_REGISTRY := define
CCTYPE		:= GCC
#CFG		:= Debug
#USE_PERLCRT	= define
#USE_SETARGV	:= define
#USE_5005THREADS:= define
#CRYPT_SRC	= .\fcrypt.c
#CRYPT_LIB	= fcrypt.lib
#PERL_MALLOC	:= define
#DEBUG_MSTATS	:= define
CCHOME		:= C:\MinGW

CCINCDIR := $(CCHOME)\include
CCLIBDIR := $(CCHOME)\lib
CCDLLDIR := $(CCHOME)\bin
ARCHPREFIX :=

BUILDOPT	:= $(BUILDOPTEXTRA)

BUILDOPT	+= -DPERL_TEXTMODE_SCRIPTS

EXTRALIBDIRS	:=


D_CRYPT		?= undef
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
USE_5005THREADS ?= undef

ifneq ("$(CRYPT_SRC)$(CRYPT_LIB)", "")
D_CRYPT		= define
CRYPT_FLAG	= -DHAVE_DES_FCRYPT
endif

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

ifeq ($(USE_5005THREADS),define)
ARCHNAME	= MSWin32-$(ARCHITECTURE)-thread
else ifeq ($(USE_MULTI),define)
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
EXTUTILSDIR	= $(LIBDIR)\ExtUtils
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
DEFINES		= -DWIN32 -DWIN64 -DCONSERVATIVE -DNO_STRICT $(CRYPT_FLAG)
LOCDEFS		= -DPERLDLL -DPERL_CORE
CXX_FLAG	= -xc++
LIBC		=
LIBFILES	= $(LIBC) -lmoldname -lkernel32 -luser32 -lgdi32 -lwinspool \
	-lcomdlg32 -ladvapi32 -lshell32 -lole32 -loleaut32 -lnetapi32 \
	-luuid -lws2_32 -lmpr -lwinmm -lversion -lodbc32 -lodbccp32

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

MINIPERL	= ..\miniperl.exe
HAVEMINIPERL	= .have_miniperl
MINIDIR		= mini
PERLEXE		= ..\perl.exe
WPERLEXE	= ..\wperl.exe
STATICDIR	= .\static.tmp
GLOBEXE		= ..\perlglob.exe
CONFIGPM	= ..\lib\Config.pm
MINIMOD	= ..\lib\ExtUtils\Miniperl.pm
X2P		= ..\x2p\a2p.exe

PERLDEP = $(PERLIMPLIB)


PL2BAT		= bin\pl2bat.pl

UTILS		=			\
		..\utils\h2ph		\
		..\utils\splain		\
		..\utils\dprofpp	\
		..\utils\perlbug	\
		..\utils\pl2pm 		\
		..\utils\c2ph		\
		..\utils\pstruct	\
		..\utils\h2xs		\
		..\utils\perldoc	\
		..\utils\perlcc		\
		..\utils\perlivp	\
		..\utils\libnetcfg	\
		..\utils\enc2xs		\
		..\utils\piconv		\
		..\pod\checkpods	\
		..\pod\pod2html		\
		..\pod\pod2latex	\
		..\pod\pod2man		\
		..\pod\pod2text		\
		..\pod\pod2usage	\
		..\pod\podchecker	\
		..\pod\podselect	\
		..\x2p\find2perl	\
		..\x2p\psed		\
		..\x2p\s2p		\
		..\lib\ExtUtils\xsubpp	\
		bin\exetype.pl		\
		bin\runperl.pl		\
		bin\pl2bat.pl		\
		bin\perlglob.pl		\
		bin\search.pl

CFGSH_TMPL	= config.gc
CFGH_TMPL	= config_H.gc
PERLIMPLIB	= $(COREDIR)\libperl__PERL_MINOR_VERSION__$(a)
PERLIMPLIBBASE	= libperl__PERL_MINOR_VERSION__$(a)
INT64		= long long
PERLEXPLIB	= $(COREDIR)\perl__PERL_MINOR_VERSION__.exp
PERLDLL		= ..\perl__PERL_MINOR_VERSION__.dll

# don't let "gmake -n all" try to run "miniperl.exe make_ext.pl"
PLMAKE		= gmake

XCOPY		= xcopy /f /r /i /d /y
RCOPY		= xcopy /f /r /i /e /d /y
NOOP		= @rem

XSUBPP		= ..\$(MINIPERL) -I..\..\lib ..\$(EXTUTILSDIR)\xsubpp \
		-C++ -prototypes

MICROCORE_SRC	=		\
		..\av.c		\
		..\deb.c	\
		..\doio.c	\
		..\doop.c	\
		..\dump.c	\
		..\globals.c	\
		..\gv.c		\
		..\hv.c		\
		..\locale.c	\
		..\mg.c		\
		..\numeric.c	\
		..\op.c		\
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
		..\util.c	\
		..\xsutils.c

EXTRACORE_SRC	+= perllib.c

ifeq ($(PERL_MALLOC),define)
EXTRACORE_SRC	+= ..\malloc.c
endif

EXTRACORE_SRC	+= ..\perlio.c

WIN32_SRC	=		\
		.\win32.c	\
		.\win32sck.c	\
		.\win32thread.c	\
		.\win32io.c

ifneq ($(CRYPT_SRC), "")
WIN32_SRC	+= $(CRYPT_SRC)
endif

DLL_SRC		= $(DYNALOADER).c

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
		..\thrdvar.h	\
		.\include\dirent.h	\
		.\include\netdb.h	\
		.\include\sys\socket.h	\
		.\win32.h

CORE_H		= $(CORE_NOCFG_H) .\config.h

MICROCORE_OBJ	= $(MICROCORE_SRC:.c=$(o))
CORE_OBJ	= $(MICROCORE_OBJ) $(EXTRACORE_SRC:.c=$(o))
WIN32_OBJ	= $(WIN32_SRC:.c=$(o))

MINICORE_OBJ	= $(subst ..\,mini\,$(MICROCORE_OBJ))	\
		  $(MINIDIR)\miniperlmain$(o)	\
		  $(MINIDIR)\perlio$(o)
MINIWIN32_OBJ	= $(subst .\,mini\,$(WIN32_OBJ))
MINI_OBJ	= $(MINICORE_OBJ) $(MINIWIN32_OBJ)
DLL_OBJ		= $(DLL_SRC:.c=$(o))
X2P_OBJ		= $(X2P_SRC:.c=$(o))
PERLDLL_OBJ	= $(CORE_OBJ)
PERLEXE_OBJ	= perlmain$(o)
PERLEXEST_OBJ	= perlmainst$(o)

PERLDLL_OBJ	+= $(WIN32_OBJ) $(DLL_OBJ)

ifneq ($(USE_SETARGV),)
SETARGV_OBJ	= setargv$(o)
endif

ifeq ($(ALL_STATIC),define)
STATIC_EXT	= * !Win32 !SDBM_File !Encode
else
#STATIC_EXT	= Cwd Compress/Raw/Zlib
STATIC_EXT	= Win32CORE
endif

DYNALOADER	= $(EXTDIR)\DynaLoader\DynaLoader

CFG_VARS	=					\
		"INST_DRV=$(INST_DRV)"			\
		"INST_TOP=$(INST_TOP)"			\
		"INST_VER=$(INST_VER)"			\
		"INST_ARCH=$(INST_ARCH)"		\
		"archname=$(ARCHNAME)"			\
		"cc=$(CC)"				\
		"ld=$(LINK32)"				\
		"ccflags=$(subst ",\",$(EXTRACFLAGS) $(OPTIMIZE) $(DEFINES) $(BUILDOPT))" \
		"cf_email=$(EMAIL)"	 		\
		"d_crypt=$(D_CRYPT)"			\
		"d_mymalloc=$(PERL_MALLOC)"		\
		"libs=$(LIBFILES)"			\
		"incpath=$(subst ",\",$(CCINCDIR))"			\
		"libperl=$(subst ",\",$(PERLIMPLIBBASE))"		\
		"libpth=$(subst ",\",$(CCLIBDIR);$(EXTRALIBDIRS))"	\
		"libc=$(LIBC)"				\
		"make=$(PLMAKE)"				\
		"usethreads=$(USE_ITHREADS)"		\
		"use5005threads=$(USE_5005THREADS)"	\
		"useithreads=$(USE_ITHREADS)"		\
		"usethreads=$(USE_5005THREADS)"		\
		"usemultiplicity=$(USE_MULTI)"		\
		"useperlio=$(USE_PERLIO)"		\
		"use64bitint=$(USE_64_BIT_INT)"		\
		"uselargefiles=$(USE_LARGE_FILES)"	\
		"LINK_FLAGS=$(subst ",\",$(LINK_FLAGS))"\
		"optimize=$(subst ",\",$(OPTIMIZE))"

ICWD = -I..\cpan\Cwd -I..\cpan\Cwd\lib

#
# Top targets
#

.PHONY: all

all : .\config.h $(GLOBEXE) $(MINIMOD) $(CONFIGPM) $(PERLEXE) $(X2P) Extensions
	@echo Everything is up to date. '$(MAKE_BARE) test' to run test suite.

$(DYNALOADER)$(o) : $(DYNALOADER).c $(CORE_H) $(EXTDIR)\DynaLoader\dlutils.c

#----------------------------------------------------------------

$(GLOBEXE) : perlglob.c
	$(LINK32) $(OPTIMIZE) $(BLINK_FLAGS) -mconsole -o $@ perlglob.c $(LIBFILES)

..\config.sh : $(CFGSH_TMPL) $(HAVEMINIPERL) config_sh.PL
	$(MINIPERL) -I..\lib config_sh.PL $(CFG_VARS) $(CFGSH_TMPL) > ..\config.sh

$(CONFIGPM) : $(HAVEMINIPERL) ..\config.sh config_h.PL ..\minimod.pl
	cd .. && miniperl.exe -Ilib configpm
	$(XCOPY) *.h $(COREDIR)\\*.*
	$(XCOPY) ..\\ext\\re\\re.pm $(LIBDIR)\\*.*
	$(RCOPY) include $(COREDIR)\\*.*
	$(XCOPY) ..\\*.h $(COREDIR)\\*.*
	-$(MINIPERL) -I..\lib $(ICWD) config_h.PL "ARCHPREFIX=$(ARCHPREFIX)"

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

$(CONFIGPM) : $(HAVEMINIPERL) ..\config.sh config_h.PL ..\minimod.pl
	cd .. && miniperl.exe -Ilib configpm
	$(XCOPY) *.h $(COREDIR)\\*.*
	$(XCOPY) ..\\*.inc $(COREDIR)\\*.*
	$(XCOPY) ..\\ext\\re\\re.pm $(LIBDIR)\\*.*
	$(RCOPY) include $(COREDIR)\\*.*
	$(XCOPY) ..\\*.h $(COREDIR)\\*.*
	-$(MINIPERL) -I..\lib $(ICWD) config_h.PL "INST_VER=$(INST_VER)"

$(MINICORE_OBJ) : $(CORE_NOCFG_H)
	$(CC) -c $(CFLAGS) $(MINIBUILDOPT) -DPERL_EXTERNAL_GLOB -DPERL_IS_MINIPERL $(OBJOUT_FLAG)$@ $(PDBOUT) ..\$(*F).c

$(MINIWIN32_OBJ) : $(CORE_NOCFG_H)
	$(CC) -c $(CFLAGS) $(MINIBUILDOPT) -DPERL_IS_MINIPERL $(OBJOUT_FLAG)$@ $(PDBOUT) $(*F).c

# -DPERL_IMPLICIT_SYS needs C++ for perllib.c
# rules wrapped in .IFs break Win9X build (we end up with unbalanced []s unless
# unless the .IF is true), so instead we use a .ELSE with the default.
# This is the only file that depends on perlhost.h, vmem.h, and vdir.h

perllib$(o)	: perllib.c .\perlhost.h .\vdir.h .\vmem.h
ifeq ($(USE_IMP_SYS),define)
	$(CC) -c -I. $(CFLAGS_O) $(CXX_FLAG) $(OBJOUT_FLAG)$@ $(PDBOUT) perllib.c
else
	$(CC) -c -I. $(CFLAGS_O) $(OBJOUT_FLAG)$@ $(PDBOUT) perllib.c
endif

$(MINI_OBJ)	: $(MINIDIR)\.exists $(CORE_NOCFG_H)

$(WIN32_OBJ)	: $(CORE_H)
$(CORE_OBJ)	: $(CORE_H)
$(DLL_OBJ)	: $(CORE_H)
$(X2P_OBJ)	: $(CORE_H)

perldll.def : $(HAVEMINIPERL) $(CONFIGPM) ..\global.sym ..\pp.sym ..\makedef.pl
	$(MINIPERL) -w ..\makedef.pl PLATFORM=win32 $(OPTIMIZE) $(DEFINES) $(BUILDOPT) \
	    CCTYPE=$(CCTYPE) > perldll.def

$(PERLEXPLIB) : $(PERLIMPLIB)

$(PERLIMPLIB) : perldll.def
	$(IMPLIB) -k -d perldll.def -l $(PERLIMPLIB) -e $(PERLEXPLIB)

$(PERLDLL): perldll.def $(PERLEXPLIB) $(PERLDLL_OBJ)
	$(LINK32) -mdll -o $@ $(BLINK_FLAGS) \
	   $(PERLDLL_OBJ) $(LIBFILES) $(PERLEXPLIB)

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

perlmain.c : runperl.c
	copy runperl.c perlmain.c

perlmain$(o) : runperl.c $(CONFIGPM)
	$(CC) $(subst -DPERLDLL,-UPERLDLL,$(CFLAGS_O)) $(OBJOUT_FLAG)$@ $(PDBOUT) -c runperl.c

perlmainst$(o) : runperl.c $(CONFIGPM)
	$(CC) $(CFLAGS_O) $(OBJOUT_FLAG)$@ $(PDBOUT) -c runperl.c

$(PERLEXE): $(PERLDLL) $(CONFIGPM) $(PERLEXE_OBJ) $(PERLIMPLIB)
	$(LINK32) -mconsole -o $@ $(BLINK_FLAGS)  \
	    $(PERLEXE_OBJ) $(PERLIMPLIB) $(LIBFILES)
	copy $(PERLEXE) $(WPERLEXE)
	$(MINIPERL) -I..\lib bin\exetype.pl $(WPERLEXE) WINDOWS
	copy splittree.pl ..
	$(MINIPERL) -I..\lib ..\splittree.pl "../LIB" $(AUTODIR)

$(DYNALOADER).c: $(HAVEMINIPERL) $(EXTDIR)\DynaLoader\dl_win32.xs $(CONFIGPM)
	if not exist $(AUTODIR) mkdir $(AUTODIR)
	cd $(EXTDIR)\DynaLoader \
		&& ..\$(MINIPERL) -I..\..\lib DynaLoader_pm.PL \
		&& ..\$(MINIPERL) -I..\..\lib XSLoader_pm.PL
	$(XCOPY) $(EXTDIR)\DynaLoader\DynaLoader.pm $(LIBDIR)\$(NULL)
	$(XCOPY) $(EXTDIR)\DynaLoader\XSLoader.pm $(LIBDIR)\$(NULL)
	cd $(EXTDIR)\DynaLoader \
		&& $(XSUBPP) dl_win32.xs > ..\$(DYNALOADER).c

$(EXTDIR)\DynaLoader\dl_win32.xs: dl_win32.xs
	copy dl_win32.xs $(EXTDIR)\DynaLoader\dl_win32.xs

$(HAVEMINIPERL): $(MINI_OBJ)
	$(LINK32) -mconsole -o $(MINIPERL) $(BLINK_FLAGS) $(MINI_OBJ) $(LIBFILES)
	rem . > $@

#most of deps of this target are in DYNALOADER and therefore omitted here
Extensions : buildext.pl $(HAVEMINIPERL) $(PERLDEP) $(CONFIGPM)
	$(MINIPERL) -I..\lib $(ICWD) buildext.pl "$(PLMAKE)" $(PERLDEP) $(EXTDIR)

#-------------------------------------------------------------------------------

doc: $(PERLEXE)
	$(PERLEXE) -I..\lib ..\installhtml --podroot=.. --htmldir=$(HTMLDIR) \
	    --podpath=pod:lib:utils --htmlroot="file://$(subst :,|,$(INST_HTML))"\
	    --recurse

utils: $(PERLEXE) $(X2P)
	cd ..\utils && $(PLMAKE) PERL=$(MINIPERL)
	copy ..\README.aix      ..\pod\perlaix.pod
	copy ..\README.amiga    ..\pod\perlamiga.pod
	copy ..\README.apollo   ..\pod\perlapollo.pod
	copy ..\README.beos     ..\pod\perlbeos.pod
	copy ..\README.bs2000   ..\pod\perlbs2000.pod
	copy ..\README.ce       ..\pod\perlce.pod
	copy ..\README.cygwin   ..\pod\perlcygwin.pod
	copy ..\README.dgux     ..\pod\perldgux.pod
	copy ..\README.dos      ..\pod\perldos.pod
	copy ..\README.epoc     ..\pod\perlepoc.pod
	copy ..\README.freebsd  ..\pod\perlfreebsd.pod
	copy ..\README.hpux     ..\pod\perlhpux.pod
	copy ..\README.hurd     ..\pod\perlhurd.pod
	copy ..\README.irix     ..\pod\perlirix.pod
	copy ..\README.machten  ..\pod\perlmachten.pod
	copy ..\README.macos    ..\pod\perlmacos.pod
	copy ..\README.mint     ..\pod\perlmint.pod
	copy ..\README.mpeix    ..\pod\perlmpeix.pod
	copy ..\README.netware  ..\pod\perlnetware.pod
	copy ..\README.os2      ..\pod\perlos2.pod
	copy ..\README.os390    ..\pod\perlos390.pod
	copy ..\README.plan9    ..\pod\perlplan9.pod
	copy ..\README.qnx      ..\pod\perlqnx.pod
	copy ..\README.solaris  ..\pod\perlsolaris.pod
	copy ..\README.tru64    ..\pod\perltru64.pod
	copy ..\README.uts      ..\pod\perluts.pod
	copy ..\README.vmesa    ..\pod\perlvmesa.pod
	copy ..\vms\perlvms.pod ..\pod\perlvms.pod
	copy ..\README.vos      ..\pod\perlvos.pod
	copy ..\README.win32    ..\pod\perlwin32.pod
	cd ..\lib && $(PERLEXE) -Dtls lib_pm.PL
	cd ..\pod && $(PLMAKE) -f ..\win32\pod.mak converters
	$(PERLEXE) -I..\lib $(PL2BAT) $(UTILS)

install : all installbare installhtml

installbare : utils
	$(PERLEXE) ..\installperl
	if exist $(WPERLEXE) $(XCOPY) $(WPERLEXE) $(INST_BIN)\$(NULL)
	$(XCOPY) $(GLOBEXE) $(INST_BIN)\$(NULL)
	$(XCOPY) "bin\*.bat" $(INST_SCRIPT)\$(NULL)

installhtml : doc
	$(RCOPY) $(HTMLDIR)\*.* $(INST_HTML)\$(NULL)
MAKEFILE
    if (_ge($version, "5.8.1")) {
        _patch_gnumakefile($version, <<'PATCH');
--- win32/GNUmakefile
+++ win32/GNUmakefile
@@ -18,7 +18,7 @@
 #USE_PERLCRT	= define
 #USE_SETARGV	:= define
 #USE_5005THREADS:= define
-#CRYPT_SRC	= .\fcrypt.c
+CRYPT_SRC	= .\fcrypt.c
 #CRYPT_LIB	= fcrypt.lib
 #PERL_MALLOC	:= define
 #DEBUG_MSTATS	:= define
@@ -265,6 +265,7 @@
 		..\utils\libnetcfg	\
 		..\utils\enc2xs		\
 		..\utils\piconv		\
+		..\utils\cpan		\
 		..\pod\checkpods	\
 		..\pod\pod2html		\
 		..\pod\pod2latex	\
@@ -314,6 +315,7 @@
 		..\mg.c		\
 		..\numeric.c	\
 		..\op.c		\
+		..\pad.c	\
 		..\perl.c	\
 		..\perlapi.c	\
 		..\perly.c	\
@@ -763,6 +765,7 @@
 	copy ..\README.beos     ..\pod\perlbeos.pod
 	copy ..\README.bs2000   ..\pod\perlbs2000.pod
 	copy ..\README.ce       ..\pod\perlce.pod
+	copy ..\README.cn       ..\pod\perlcn.pod
 	copy ..\README.cygwin   ..\pod\perlcygwin.pod
 	copy ..\README.dgux     ..\pod\perldgux.pod
 	copy ..\README.dos      ..\pod\perldos.pod
@@ -771,20 +774,25 @@
 	copy ..\README.hpux     ..\pod\perlhpux.pod
 	copy ..\README.hurd     ..\pod\perlhurd.pod
 	copy ..\README.irix     ..\pod\perlirix.pod
+	copy ..\README.jp       ..\pod\perljp.pod
+	copy ..\README.ko       ..\pod\perlko.pod
 	copy ..\README.machten  ..\pod\perlmachten.pod
 	copy ..\README.macos    ..\pod\perlmacos.pod
+	copy ..\README.macosx   ..\pod\perlmacosx.pod
 	copy ..\README.mint     ..\pod\perlmint.pod
 	copy ..\README.mpeix    ..\pod\perlmpeix.pod
 	copy ..\README.netware  ..\pod\perlnetware.pod
 	copy ..\README.os2      ..\pod\perlos2.pod
 	copy ..\README.os390    ..\pod\perlos390.pod
+	copy ..\README.os400    ..\pod\perlos400.pod
 	copy ..\README.plan9    ..\pod\perlplan9.pod
 	copy ..\README.qnx      ..\pod\perlqnx.pod
 	copy ..\README.solaris  ..\pod\perlsolaris.pod
 	copy ..\README.tru64    ..\pod\perltru64.pod
+	copy ..\README.tw       ..\pod\perltw.pod
 	copy ..\README.uts      ..\pod\perluts.pod
 	copy ..\README.vmesa    ..\pod\perlvmesa.pod
-	copy ..\vms\perlvms.pod ..\pod\perlvms.pod
+	copy ..\README.vms      ..\pod\perlvms.pod
 	copy ..\README.vos      ..\pod\perlvos.pod
 	copy ..\README.win32    ..\pod\perlwin32.pod
 	cd ..\lib && $(PERLEXE) -Dtls lib_pm.PL
PATCH
    }
    if (_ge($version, "5.8.3")) {
        _patch_gnumakefile($version, <<'PATCH');
--- win32/GNUmakefile
+++ win32/GNUmakefile
@@ -266,6 +266,9 @@
 		..\utils\enc2xs		\
 		..\utils\piconv		\
 		..\utils\cpan		\
+		..\utils\xsubpp		\
+		..\utils\prove		\
+		..\utils\instmodsh	\
 		..\pod\checkpods	\
 		..\pod\pod2html		\
 		..\pod\pod2latex	\
@@ -277,7 +280,6 @@
 		..\x2p\find2perl	\
 		..\x2p\psed		\
 		..\x2p\s2p		\
-		..\lib\ExtUtils\xsubpp	\
 		bin\exetype.pl		\
 		bin\runperl.pl		\
 		bin\pl2bat.pl		\
@@ -759,6 +761,7 @@
 
 utils: $(PERLEXE) $(X2P)
 	cd ..\utils && $(PLMAKE) PERL=$(MINIPERL)
+	copy ..\vms\perlvms.pod .\perlvms.pod
 	copy ..\README.aix      ..\pod\perlaix.pod
 	copy ..\README.amiga    ..\pod\perlamiga.pod
 	copy ..\README.apollo   ..\pod\perlapollo.pod
@@ -795,6 +798,7 @@
 	copy ..\README.vms      ..\pod\perlvms.pod
 	copy ..\README.vos      ..\pod\perlvos.pod
 	copy ..\README.win32    ..\pod\perlwin32.pod
+	copy ..\pod\perl__PERL_VERSION__delta.pod ..\pod\perldelta.pod
 	cd ..\lib && $(PERLEXE) -Dtls lib_pm.PL
 	cd ..\pod && $(PLMAKE) -f ..\win32\pod.mak converters
 	$(PERLEXE) -I..\lib $(PL2BAT) $(UTILS)
PATCH
    }
    if (_ge($version, "5.8.4")) {
        _patch_gnumakefile($version, <<'PATCH');
--- win32/GNUmakefile
+++ win32/GNUmakefile
@@ -751,6 +751,7 @@
 #most of deps of this target are in DYNALOADER and therefore omitted here
 Extensions : buildext.pl $(HAVEMINIPERL) $(PERLDEP) $(CONFIGPM)
 	$(MINIPERL) -I..\lib $(ICWD) buildext.pl "$(PLMAKE)" $(PERLDEP) $(EXTDIR)
+	$(MINIPERL) -I..\lib $(ICWD) buildext.pl "$(PLMAKE)" $(PERLDEP) ext
 
 #-------------------------------------------------------------------------------
 
PATCH
    }
    if (_ge($version, "5.8.5")) {
        _patch_gnumakefile($version, <<'PATCH');
--- win32/GNUmakefile
+++ win32/GNUmakefile
@@ -245,6 +245,21 @@
 MINIMOD	= ..\lib\ExtUtils\Miniperl.pm
 X2P		= ..\x2p\a2p.exe
 
+# Unicode data files generated by mktables
+FIRSTUNIFILE     = ..\lib\unicore\Canonical.pl
+UNIDATAFILES	 = ..\lib\unicore\Canonical.pl ..\lib\unicore\Exact.pl \
+		   ..\lib\unicore\Properties ..\lib\unicore\Decomposition.pl \
+		   ..\lib\unicore\CombiningClass.pl ..\lib\unicore\Name.pl \
+		   ..\lib\unicore\PVA.pl
+
+UNIDATADIR1	= ..\lib\unicore\To
+UNIDATADIR2	= ..\lib\unicore\lib
+
+PERLEXE_ICO	= .\perlexe.ico
+PERLEXE_RES	= .\perlexe.res
+PERLDLL_RES	=
+
+
 PERLDEP = $(PERLIMPLIB)
 
 
@@ -476,7 +491,7 @@
 
 .PHONY: all
 
-all : .\config.h $(GLOBEXE) $(MINIMOD) $(CONFIGPM) $(PERLEXE) $(X2P) Extensions
+all : .\config.h $(GLOBEXE) $(MINIMOD) $(CONFIGPM) $(UNIDATAFILES) $(PERLEXE) $(X2P) Extensions
 	@echo Everything is up to date. '$(MAKE_BARE) test' to run test suite.
 
 $(DYNALOADER)$(o) : $(DYNALOADER).c $(CORE_H) $(EXTDIR)\DynaLoader\dlutils.c
@@ -723,14 +738,19 @@
 perlmainst$(o) : runperl.c $(CONFIGPM)
 	$(CC) $(CFLAGS_O) $(OBJOUT_FLAG)$@ $(PDBOUT) -c runperl.c
 
-$(PERLEXE): $(PERLDLL) $(CONFIGPM) $(PERLEXE_OBJ) $(PERLIMPLIB)
+$(PERLEXE): $(PERLDLL) $(CONFIGPM) $(PERLEXE_OBJ) $(PERLEXE_RES) $(PERLIMPLIB)
 	$(LINK32) -mconsole -o $@ $(BLINK_FLAGS)  \
-	    $(PERLEXE_OBJ) $(PERLIMPLIB) $(LIBFILES)
+	    $(PERLEXE_OBJ) $(PERLEXE_RES) $(PERLIMPLIB) $(LIBFILES)
 	copy $(PERLEXE) $(WPERLEXE)
 	$(MINIPERL) -I..\lib bin\exetype.pl $(WPERLEXE) WINDOWS
 	copy splittree.pl ..
 	$(MINIPERL) -I..\lib ..\splittree.pl "../LIB" $(AUTODIR)
 
+$(PERLEXE_ICO): $(HAVEMINIPERL) makeico.pl
+	$(MINIPERL) makeico.pl > $@
+
+$(PERLEXE_RES): perlexe.rc $(PERLEXE_ICO)
+
 $(DYNALOADER).c: $(HAVEMINIPERL) $(EXTDIR)\DynaLoader\dl_win32.xs $(CONFIGPM)
 	if not exist $(AUTODIR) mkdir $(AUTODIR)
 	cd $(EXTDIR)\DynaLoader \
@@ -762,7 +782,6 @@
 
 utils: $(PERLEXE) $(X2P)
 	cd ..\utils && $(PLMAKE) PERL=$(MINIPERL)
-	copy ..\vms\perlvms.pod .\perlvms.pod
 	copy ..\README.aix      ..\pod\perlaix.pod
 	copy ..\README.amiga    ..\pod\perlamiga.pod
 	copy ..\README.apollo   ..\pod\perlapollo.pod
@@ -814,3 +833,6 @@
 
 installhtml : doc
 	$(RCOPY) $(HTMLDIR)\*.* $(INST_HTML)\$(NULL)
+
+$(UNIDATAFILES) : $(HAVEMINIPERL) $(CONFIGPM) ..\lib\unicore\mktables
+	cd ..\lib\unicore && ..\$(MINIPERL) -I..\lib mktables
PATCH
    }
    if (_ge($version, "5.8.6")) {
        _patch_gnumakefile($version, <<'PATCH');
--- win32/GNUmakefile
+++ win32/GNUmakefile
@@ -17,8 +17,7 @@
 #CFG		:= Debug
 #USE_PERLCRT	= define
 #USE_SETARGV	:= define
-#USE_5005THREADS:= define
-CRYPT_SRC	= .\fcrypt.c
+CRYPT_SRC	= fcrypt.c
 #CRYPT_LIB	= fcrypt.lib
 #PERL_MALLOC	:= define
 #DEBUG_MSTATS	:= define
@@ -36,6 +35,8 @@
 EXTRALIBDIRS	:=
 
 
+##################### CHANGE THESE ONLY IF YOU MUST #####################
+
 D_CRYPT		?= undef
 PERL_MALLOC	?= undef
 DEBUG_MSTATS	?= undef
@@ -49,7 +50,6 @@
 USE_64_BIT_INT	?= undef
 USE_LONG_DOUBLE	?= undef
 USE_NO_REGISTRY	?= undef
-USE_5005THREADS ?= undef
 
 ifneq ("$(CRYPT_SRC)$(CRYPT_LIB)", "")
 D_CRYPT		= define
@@ -97,9 +97,7 @@
 USE_64_BIT_INT = define
 ARCHITECTURE = x64
 
-ifeq ($(USE_5005THREADS),define)
-ARCHNAME	= MSWin32-$(ARCHITECTURE)-thread
-else ifeq ($(USE_MULTI),define)
+ifeq ($(USE_MULTI),define)
 ARCHNAME	= MSWin32-$(ARCHITECTURE)-multi
 else
 ifeq ($(USE_PERLIO),define)
@@ -234,16 +232,24 @@
 %.res: %.rc
 	$(RSC) --use-temp-file --include-dir=. --include-dir=.. -O COFF -D INCLUDE_MANIFEST -i $< -o $@
 
+#
+# various targets
+
+#do not put $(MINIPERL) as a dep/prereq in a rule, instead put $(HAVEMINIPERL)
+#$(MINIPERL) is not a buildable target, use "gmake mp" if you want to just build
+#miniperl alone
 MINIPERL	= ..\miniperl.exe
 HAVEMINIPERL	= .have_miniperl
 MINIDIR		= mini
 PERLEXE		= ..\perl.exe
 WPERLEXE	= ..\wperl.exe
+PERLEXESTATIC	= ..\perl-static.exe
 STATICDIR	= .\static.tmp
 GLOBEXE		= ..\perlglob.exe
 CONFIGPM	= ..\lib\Config.pm
 MINIMOD	= ..\lib\ExtUtils\Miniperl.pm
 X2P		= ..\x2p\a2p.exe
+PERLSTATIC	=
 
 # Unicode data files generated by mktables
 FIRSTUNIFILE     = ..\lib\unicore\Canonical.pl
@@ -259,7 +265,6 @@
 PERLEXE_RES	= .\perlexe.res
 PERLDLL_RES	=
 
-
 PERLDEP = $(PERLIMPLIB)
 
 
@@ -305,6 +310,7 @@
 CFGH_TMPL	= config_H.gc
 PERLIMPLIB	= $(COREDIR)\libperl__PERL_MINOR_VERSION__$(a)
 PERLIMPLIBBASE	= libperl__PERL_MINOR_VERSION__$(a)
+PERLSTATICLIB	= ..\libperl__PERL_MINOR_VERSION__s$(a)
 INT64		= long long
 PERLEXPLIB	= $(COREDIR)\perl__PERL_MINOR_VERSION__.exp
 PERLDLL		= ..\perl__PERL_MINOR_VERSION__.dll
@@ -404,6 +410,7 @@
 		..\perly.h	\
 		..\pp.h		\
 		..\proto.h	\
+		..\regcomp.h	\
 		..\regexp.h	\
 		..\scope.h	\
 		..\sv.h		\
@@ -424,6 +431,11 @@
 
 CORE_H		= $(CORE_NOCFG_H) .\config.h
 
+MG_DATA_H	= ..\mg_data.h
+#a stub ppport.h must be generated so building XS modules, .c->.obj wise, will
+#work, so this target also represents creating the COREDIR and filling it
+HAVE_COREDIR	= $(COREDIR)\ppport.h
+
 MICROCORE_OBJ	= $(MICROCORE_SRC:.c=$(o))
 CORE_OBJ	= $(MICROCORE_OBJ) $(EXTRACORE_SRC:.c=$(o))
 WIN32_OBJ	= $(WIN32_SRC:.c=$(o))
@@ -449,13 +461,12 @@
 STATIC_EXT	= * !Win32 !SDBM_File !Encode
 else
 #STATIC_EXT	= Cwd Compress/Raw/Zlib
-STATIC_EXT	= Win32CORE
+STATIC_EXT	=
 endif
 
 DYNALOADER	= $(EXTDIR)\DynaLoader\DynaLoader
 
 CFG_VARS	=					\
-		"INST_DRV=$(INST_DRV)"			\
 		"INST_TOP=$(INST_TOP)"			\
 		"INST_VER=$(INST_VER)"			\
 		"INST_ARCH=$(INST_ARCH)"		\
@@ -463,8 +474,8 @@
 		"cc=$(CC)"				\
 		"ld=$(LINK32)"				\
 		"ccflags=$(subst ",\",$(EXTRACFLAGS) $(OPTIMIZE) $(DEFINES) $(BUILDOPT))" \
-		"cf_email=$(EMAIL)"	 		\
-		"d_crypt=$(D_CRYPT)"			\
+		"usecplusplus=$(USE_CPLUSPLUS)"		\
+		"cf_email=$(EMAIL)"			\
 		"d_mymalloc=$(PERL_MALLOC)"		\
 		"libs=$(LIBFILES)"			\
 		"incpath=$(subst ",\",$(CCINCDIR))"			\
@@ -472,16 +483,23 @@
 		"libpth=$(subst ",\",$(CCLIBDIR);$(EXTRALIBDIRS))"	\
 		"libc=$(LIBC)"				\
 		"make=$(PLMAKE)"				\
+		"_o=$(o)"				\
+		"obj_ext=$(o)"				\
+		"_a=$(a)"				\
+		"lib_ext=$(a)"				\
+		"static_ext=$(STATIC_EXT)"		\
 		"usethreads=$(USE_ITHREADS)"		\
-		"use5005threads=$(USE_5005THREADS)"	\
 		"useithreads=$(USE_ITHREADS)"		\
-		"usethreads=$(USE_5005THREADS)"		\
 		"usemultiplicity=$(USE_MULTI)"		\
 		"useperlio=$(USE_PERLIO)"		\
 		"use64bitint=$(USE_64_BIT_INT)"		\
+		"uselongdouble=$(USE_LONG_DOUBLE)"	\
 		"uselargefiles=$(USE_LARGE_FILES)"	\
+		"usesitecustomize=$(USE_SITECUST)"	\
 		"LINK_FLAGS=$(subst ",\",$(LINK_FLAGS))"\
-		"optimize=$(subst ",\",$(OPTIMIZE))"
+		"optimize=$(subst ",\",$(OPTIMIZE))"	\
+		"ARCHPREFIX=$(ARCHPREFIX)"		\
+		"WIN64=$(WIN64)"
 
 ICWD = -I..\cpan\Cwd -I..\cpan\Cwd\lib
 
@@ -498,22 +516,19 @@
 
 #----------------------------------------------------------------
 
-$(GLOBEXE) : perlglob.c
-	$(LINK32) $(OPTIMIZE) $(BLINK_FLAGS) -mconsole -o $@ perlglob.c $(LIBFILES)
+$(GLOBEXE) : perlglob$(o)
+	$(LINK32) $(OPTIMIZE) $(BLINK_FLAGS) -mconsole -o $@ perlglob$(o) $(LIBFILES)
 
-..\config.sh : $(CFGSH_TMPL) $(HAVEMINIPERL) config_sh.PL
-	$(MINIPERL) -I..\lib config_sh.PL $(CFG_VARS) $(CFGSH_TMPL) > ..\config.sh
+perlglob$(o)  : perlglob.c
 
-$(CONFIGPM) : $(HAVEMINIPERL) ..\config.sh config_h.PL ..\minimod.pl
-	cd .. && miniperl.exe -Ilib configpm
-	$(XCOPY) *.h $(COREDIR)\\*.*
-	$(XCOPY) ..\\ext\\re\\re.pm $(LIBDIR)\\*.*
-	$(RCOPY) include $(COREDIR)\\*.*
-	$(XCOPY) ..\\*.h $(COREDIR)\\*.*
-	-$(MINIPERL) -I..\lib $(ICWD) config_h.PL "ARCHPREFIX=$(ARCHPREFIX)"
+config.w32 : $(CFGSH_TMPL)
+	copy $(CFGSH_TMPL) config.w32
+
+..\config.sh : $(HAVEMINIPERL) config.w32 config_sh.PL
+	$(MINIPERL) -I..\lib config_sh.PL $(CFG_VARS) config.w32 > ..\config.sh
 
 .\config.h : $(CONFIGPM)
-$(MINIDIR)\.exists : $(CFGH_TMPL)
+$(MINIDIR)\.exists :
 	if not exist "$(MINIDIR)" mkdir "$(MINIDIR)"
 	copy $(CFGH_TMPL) config.h
 	@(echo.&& \
@@ -674,16 +689,9 @@
 $(MINIWIN32_OBJ) : $(CORE_NOCFG_H)
 	$(CC) -c $(CFLAGS) $(MINIBUILDOPT) -DPERL_IS_MINIPERL $(OBJOUT_FLAG)$@ $(PDBOUT) $(*F).c
 
-# -DPERL_IMPLICIT_SYS needs C++ for perllib.c
-# rules wrapped in .IFs break Win9X build (we end up with unbalanced []s unless
-# unless the .IF is true), so instead we use a .ELSE with the default.
-# This is the only file that depends on perlhost.h, vmem.h, and vdir.h
-
-perllib$(o)	: perllib.c .\perlhost.h .\vdir.h .\vmem.h
 ifeq ($(USE_IMP_SYS),define)
-	$(CC) -c -I. $(CFLAGS_O) $(CXX_FLAG) $(OBJOUT_FLAG)$@ $(PDBOUT) perllib.c
-else
-	$(CC) -c -I. $(CFLAGS_O) $(OBJOUT_FLAG)$@ $(PDBOUT) perllib.c
+perllib$(o)	: perllib.c .\perlhost.h .\vdir.h .\vmem.h
+	$(CC) -c -I. $(CFLAGS_O) $(CXX_FLAG) $(OBJOUT_FLAG)$@ perllib.c
 endif
 
 $(MINI_OBJ)	: $(MINIDIR)\.exists $(CORE_NOCFG_H)
@@ -694,20 +702,30 @@
 $(X2P_OBJ)	: $(CORE_H)
 
 perldll.def : $(HAVEMINIPERL) $(CONFIGPM) ..\global.sym ..\pp.sym ..\makedef.pl
-	$(MINIPERL) -w ..\makedef.pl PLATFORM=win32 $(OPTIMIZE) $(DEFINES) $(BUILDOPT) \
-	    CCTYPE=$(CCTYPE) > perldll.def
+	$(MINIPERL) -I..\lib buildext.pl --create-perllibst-h
+	$(MINIPERL) -I..\lib -w ..\makedef.pl PLATFORM=win32 $(OPTIMIZE) $(DEFINES) $(BUILDOPT) CCTYPE=$(CCTYPE) > perldll.def
 
 $(PERLEXPLIB) : $(PERLIMPLIB)
 
 $(PERLIMPLIB) : perldll.def
 	$(IMPLIB) -k -d perldll.def -l $(PERLIMPLIB) -e $(PERLEXPLIB)
 
-$(PERLDLL): perldll.def $(PERLEXPLIB) $(PERLDLL_OBJ)
+$(PERLDLL): perldll.def $(PERLEXPLIB) $(PERLDLL_OBJ) Extensions_static
 	$(LINK32) -mdll -o $@ $(BLINK_FLAGS) \
-	   $(PERLDLL_OBJ) $(LIBFILES) $(PERLEXPLIB)
+	   $(PERLDLL_OBJ) $(shell type Extensions_static) $(LIBFILES) $(PERLEXPLIB)
+
+$(PERLSTATICLIB): $(PERLDLL_OBJ) Extensions_static
+	$(LIB32) $(LIB_FLAGS) $@ $(PERLDLL_OBJ)
+	if exist $(STATICDIR) rmdir /s /q $(STATICDIR)
+	for %%i in ($(shell type Extensions_static)) do \
+		@mkdir $(STATICDIR) && cd $(STATICDIR) && \
+		$(ARCHPREFIX)ar x ..\%%i && \
+		$(ARCHPREFIX)ar q ..\$@ *$(o) && \
+		cd .. && rmdir /s /q $(STATICDIR)
+	$(XCOPY) $(PERLSTATICLIB) $(COREDIR)
 
 $(MINIMOD) : $(HAVEMINIPERL) ..\minimod.pl
-	cd .. && miniperl minimod.pl > lib\ExtUtils\Miniperl.pm && cd win32
+	cd .. && miniperl.exe minimod.pl > lib\ExtUtils\Miniperl.pm && cd win32
 
 ..\x2p\a2p$(o) : ..\x2p\a2p.c
 	$(CC) -I..\x2p $(CFLAGS) $(OBJOUT_FLAG)$@ -c ..\x2p\a2p.c
@@ -738,9 +756,9 @@
 perlmainst$(o) : runperl.c $(CONFIGPM)
 	$(CC) $(CFLAGS_O) $(OBJOUT_FLAG)$@ $(PDBOUT) -c runperl.c
 
-$(PERLEXE): $(PERLDLL) $(CONFIGPM) $(PERLEXE_OBJ) $(PERLEXE_RES) $(PERLIMPLIB)
+$(PERLEXE): $(PERLDLL) $(CONFIGPM) $(PERLEXE_OBJ) $(PERLEXE_RES)
 	$(LINK32) -mconsole -o $@ $(BLINK_FLAGS)  \
-	    $(PERLEXE_OBJ) $(PERLEXE_RES) $(PERLIMPLIB) $(LIBFILES)
+	    $(LIBFILES) $(PERLEXE_OBJ) $(SETARGV_OBJ) $(PERLIMPLIB) $(PERLEXE_RES)
 	copy $(PERLEXE) $(WPERLEXE)
 	$(MINIPERL) -I..\lib bin\exetype.pl $(WPERLEXE) WINDOWS
 	copy splittree.pl ..
@@ -770,8 +788,15 @@
 
 #most of deps of this target are in DYNALOADER and therefore omitted here
 Extensions : buildext.pl $(HAVEMINIPERL) $(PERLDEP) $(CONFIGPM)
-	$(MINIPERL) -I..\lib $(ICWD) buildext.pl "$(PLMAKE)" $(PERLDEP) $(EXTDIR)
-	$(MINIPERL) -I..\lib $(ICWD) buildext.pl "$(PLMAKE)" $(PERLDEP) ext
+	$(XCOPY) ..\\*.h $(COREDIR)\\*.*
+	$(MINIPERL) -I..\lib $(ICWD) buildext.pl "$(PLMAKE)" $(PERLDEP) $(EXTDIR) --dynamic
+	-if exist ext $(MINIPERL) -I..\lib $(ICWD) buildext.pl "$(PLMAKE)" $(PERLDEP) ext --dynamic
+
+Extensions_static : buildext.pl $(HAVEMINIPERL) $(CONFIGPM)
+	$(XCOPY) ..\\*.h $(COREDIR)\\*.*
+	$(MINIPERL) -I..\lib $(ICWD) buildext.pl "$(PLMAKE)" $(PERLDEP) $(EXTDIR) --static
+	-if exist ext $(MINIPERL) -I..\lib $(ICWD) buildext.pl "$(PLMAKE)" $(PERLDEP) ext --static
+	$(MINIPERL) -I..\lib buildext.pl --list-static-libs > Extensions_static
 
 #-------------------------------------------------------------------------------
 
@@ -788,31 +813,24 @@
 	copy ..\README.beos     ..\pod\perlbeos.pod
 	copy ..\README.bs2000   ..\pod\perlbs2000.pod
 	copy ..\README.ce       ..\pod\perlce.pod
-	copy ..\README.cn       ..\pod\perlcn.pod
 	copy ..\README.cygwin   ..\pod\perlcygwin.pod
 	copy ..\README.dgux     ..\pod\perldgux.pod
 	copy ..\README.dos      ..\pod\perldos.pod
 	copy ..\README.epoc     ..\pod\perlepoc.pod
 	copy ..\README.freebsd  ..\pod\perlfreebsd.pod
-	copy ..\README.hpux     ..\pod\perlhpux.pod
 	copy ..\README.hurd     ..\pod\perlhurd.pod
 	copy ..\README.irix     ..\pod\perlirix.pod
-	copy ..\README.jp       ..\pod\perljp.pod
-	copy ..\README.ko       ..\pod\perlko.pod
 	copy ..\README.machten  ..\pod\perlmachten.pod
 	copy ..\README.macos    ..\pod\perlmacos.pod
-	copy ..\README.macosx   ..\pod\perlmacosx.pod
 	copy ..\README.mint     ..\pod\perlmint.pod
 	copy ..\README.mpeix    ..\pod\perlmpeix.pod
 	copy ..\README.netware  ..\pod\perlnetware.pod
 	copy ..\README.os2      ..\pod\perlos2.pod
 	copy ..\README.os390    ..\pod\perlos390.pod
-	copy ..\README.os400    ..\pod\perlos400.pod
 	copy ..\README.plan9    ..\pod\perlplan9.pod
 	copy ..\README.qnx      ..\pod\perlqnx.pod
 	copy ..\README.solaris  ..\pod\perlsolaris.pod
 	copy ..\README.tru64    ..\pod\perltru64.pod
-	copy ..\README.tw       ..\pod\perltw.pod
 	copy ..\README.uts      ..\pod\perluts.pod
 	copy ..\README.vmesa    ..\pod\perlvmesa.pod
 	copy ..\README.vms      ..\pod\perlvms.pod
@@ -828,11 +846,17 @@
 installbare : utils
 	$(PERLEXE) ..\installperl
 	if exist $(WPERLEXE) $(XCOPY) $(WPERLEXE) $(INST_BIN)\$(NULL)
+	if exist $(PERLEXESTATIC) $(XCOPY) $(PERLEXESTATIC) $(INST_BIN)\$(NULL)
 	$(XCOPY) $(GLOBEXE) $(INST_BIN)\$(NULL)
+	if exist ..\perl*.pdb $(XCOPY) ..\perl*.pdb $(INST_BIN)\$(NULL)
+	if exist ..\x2p\a2p.pdb $(XCOPY) ..\x2p\a2p.pdb $(INST_BIN)\$(NULL)
 	$(XCOPY) "bin\*.bat" $(INST_SCRIPT)\$(NULL)
 
 installhtml : doc
 	$(RCOPY) $(HTMLDIR)\*.* $(INST_HTML)\$(NULL)
 
+inst_lib : $(CONFIGPM)
+	$(RCOPY) ..\lib $(INST_LIB)\$(NULL)
+
 $(UNIDATAFILES) : $(HAVEMINIPERL) $(CONFIGPM) ..\lib\unicore\mktables
 	cd ..\lib\unicore && ..\$(MINIPERL) -I..\lib mktables
PATCH
    }
    if (_ge($version, "5.8.7")) {
        _patch_gnumakefile($version, <<'PATCH');
--- win32/GNUmakefile
+++ win32/GNUmakefile
@@ -410,7 +410,6 @@
 		..\perly.h	\
 		..\pp.h		\
 		..\proto.h	\
-		..\regcomp.h	\
 		..\regexp.h	\
 		..\scope.h	\
 		..\sv.h		\
@@ -710,19 +709,9 @@
 $(PERLIMPLIB) : perldll.def
 	$(IMPLIB) -k -d perldll.def -l $(PERLIMPLIB) -e $(PERLEXPLIB)
 
-$(PERLDLL): perldll.def $(PERLEXPLIB) $(PERLDLL_OBJ) Extensions_static
+$(PERLDLL): perldll.def $(PERLEXPLIB) $(PERLDLL_OBJ)
 	$(LINK32) -mdll -o $@ $(BLINK_FLAGS) \
-	   $(PERLDLL_OBJ) $(shell type Extensions_static) $(LIBFILES) $(PERLEXPLIB)
-
-$(PERLSTATICLIB): $(PERLDLL_OBJ) Extensions_static
-	$(LIB32) $(LIB_FLAGS) $@ $(PERLDLL_OBJ)
-	if exist $(STATICDIR) rmdir /s /q $(STATICDIR)
-	for %%i in ($(shell type Extensions_static)) do \
-		@mkdir $(STATICDIR) && cd $(STATICDIR) && \
-		$(ARCHPREFIX)ar x ..\%%i && \
-		$(ARCHPREFIX)ar q ..\$@ *$(o) && \
-		cd .. && rmdir /s /q $(STATICDIR)
-	$(XCOPY) $(PERLSTATICLIB) $(COREDIR)
+	   $(PERLDLL_OBJ) $(LIBFILES) $(PERLEXPLIB)
 
 $(MINIMOD) : $(HAVEMINIPERL) ..\minimod.pl
 	cd .. && miniperl.exe minimod.pl > lib\ExtUtils\Miniperl.pm && cd win32
@@ -788,15 +777,8 @@
 
 #most of deps of this target are in DYNALOADER and therefore omitted here
 Extensions : buildext.pl $(HAVEMINIPERL) $(PERLDEP) $(CONFIGPM)
-	$(XCOPY) ..\\*.h $(COREDIR)\\*.*
-	$(MINIPERL) -I..\lib $(ICWD) buildext.pl "$(PLMAKE)" $(PERLDEP) $(EXTDIR) --dynamic
-	-if exist ext $(MINIPERL) -I..\lib $(ICWD) buildext.pl "$(PLMAKE)" $(PERLDEP) ext --dynamic
-
-Extensions_static : buildext.pl $(HAVEMINIPERL) $(CONFIGPM)
-	$(XCOPY) ..\\*.h $(COREDIR)\\*.*
-	$(MINIPERL) -I..\lib $(ICWD) buildext.pl "$(PLMAKE)" $(PERLDEP) $(EXTDIR) --static
-	-if exist ext $(MINIPERL) -I..\lib $(ICWD) buildext.pl "$(PLMAKE)" $(PERLDEP) ext --static
-	$(MINIPERL) -I..\lib buildext.pl --list-static-libs > Extensions_static
+	$(MINIPERL) -I..\lib $(ICWD) buildext.pl "$(PLMAKE)" $(PERLDEP) $(EXTDIR)
+	$(MINIPERL) -I..\lib $(ICWD) buildext.pl "$(PLMAKE)" $(PERLDEP) ext
 
 #-------------------------------------------------------------------------------
 
@@ -813,24 +795,31 @@
 	copy ..\README.beos     ..\pod\perlbeos.pod
 	copy ..\README.bs2000   ..\pod\perlbs2000.pod
 	copy ..\README.ce       ..\pod\perlce.pod
+	copy ..\README.cn       ..\pod\perlcn.pod
 	copy ..\README.cygwin   ..\pod\perlcygwin.pod
 	copy ..\README.dgux     ..\pod\perldgux.pod
 	copy ..\README.dos      ..\pod\perldos.pod
 	copy ..\README.epoc     ..\pod\perlepoc.pod
 	copy ..\README.freebsd  ..\pod\perlfreebsd.pod
+	copy ..\README.hpux     ..\pod\perlhpux.pod
 	copy ..\README.hurd     ..\pod\perlhurd.pod
 	copy ..\README.irix     ..\pod\perlirix.pod
+	copy ..\README.jp       ..\pod\perljp.pod
+	copy ..\README.ko       ..\pod\perlko.pod
 	copy ..\README.machten  ..\pod\perlmachten.pod
 	copy ..\README.macos    ..\pod\perlmacos.pod
+	copy ..\README.macosx   ..\pod\perlmacosx.pod
 	copy ..\README.mint     ..\pod\perlmint.pod
 	copy ..\README.mpeix    ..\pod\perlmpeix.pod
 	copy ..\README.netware  ..\pod\perlnetware.pod
 	copy ..\README.os2      ..\pod\perlos2.pod
 	copy ..\README.os390    ..\pod\perlos390.pod
+	copy ..\README.os400    ..\pod\perlos400.pod
 	copy ..\README.plan9    ..\pod\perlplan9.pod
 	copy ..\README.qnx      ..\pod\perlqnx.pod
 	copy ..\README.solaris  ..\pod\perlsolaris.pod
 	copy ..\README.tru64    ..\pod\perltru64.pod
+	copy ..\README.tw       ..\pod\perltw.pod
 	copy ..\README.uts      ..\pod\perluts.pod
 	copy ..\README.vmesa    ..\pod\perlvmesa.pod
 	copy ..\README.vms      ..\pod\perlvms.pod
PATCH
    }
    if (_ge($version, "5.8.9")) {
        _patch_gnumakefile($version, <<'PATCH');
--- win32/GNUmakefile
+++ win32/GNUmakefile
@@ -285,10 +285,6 @@
 		..\utils\libnetcfg	\
 		..\utils\enc2xs		\
 		..\utils\piconv		\
-		..\utils\cpan		\
-		..\utils\xsubpp		\
-		..\utils\prove		\
-		..\utils\instmodsh	\
 		..\pod\checkpods	\
 		..\pod\pod2html		\
 		..\pod\pod2latex	\
@@ -300,6 +296,7 @@
 		..\x2p\find2perl	\
 		..\x2p\psed		\
 		..\x2p\s2p		\
+		..\lib\ExtUtils\xsubpp	\
 		bin\exetype.pl		\
 		bin\runperl.pl		\
 		bin\pl2bat.pl		\
@@ -335,6 +332,7 @@
 		..\gv.c		\
 		..\hv.c		\
 		..\locale.c	\
+		..\mathoms.c	\
 		..\mg.c		\
 		..\numeric.c	\
 		..\op.c		\
@@ -410,6 +408,7 @@
 		..\perly.h	\
 		..\pp.h		\
 		..\proto.h	\
+		..\regcomp.h	\
 		..\regexp.h	\
 		..\scope.h	\
 		..\sv.h		\
@@ -460,7 +459,7 @@
 STATIC_EXT	= * !Win32 !SDBM_File !Encode
 else
 #STATIC_EXT	= Cwd Compress/Raw/Zlib
-STATIC_EXT	=
+STATIC_EXT	= Win32CORE
 endif
 
 DYNALOADER	= $(EXTDIR)\DynaLoader\DynaLoader
@@ -508,7 +507,7 @@
 
 .PHONY: all
 
-all : .\config.h $(GLOBEXE) $(MINIMOD) $(CONFIGPM) $(UNIDATAFILES) $(PERLEXE) $(X2P) Extensions
+all : .\config.h $(GLOBEXE) $(MINIMOD) $(CONFIGPM) $(UNIDATAFILES) MakePPPort $(PERLEXE) $(X2P) Extensions
 	@echo Everything is up to date. '$(MAKE_BARE) test' to run test suite.
 
 $(DYNALOADER)$(o) : $(DYNALOADER).c $(CORE_H) $(EXTDIR)\DynaLoader\dlutils.c
@@ -709,9 +708,19 @@
 $(PERLIMPLIB) : perldll.def
 	$(IMPLIB) -k -d perldll.def -l $(PERLIMPLIB) -e $(PERLEXPLIB)
 
-$(PERLDLL): perldll.def $(PERLEXPLIB) $(PERLDLL_OBJ)
+$(PERLDLL): perldll.def $(PERLEXPLIB) $(PERLDLL_OBJ) Extensions_static
 	$(LINK32) -mdll -o $@ $(BLINK_FLAGS) \
-	   $(PERLDLL_OBJ) $(LIBFILES) $(PERLEXPLIB)
+	   $(PERLDLL_OBJ) $(shell type Extensions_static) $(LIBFILES) $(PERLEXPLIB)
+
+$(PERLSTATICLIB): $(PERLDLL_OBJ) Extensions_static
+	$(LIB32) $(LIB_FLAGS) $@ $(PERLDLL_OBJ)
+	if exist $(STATICDIR) rmdir /s /q $(STATICDIR)
+	for %%i in ($(shell type Extensions_static)) do \
+		@mkdir $(STATICDIR) && cd $(STATICDIR) && \
+		$(ARCHPREFIX)ar x ..\%%i && \
+		$(ARCHPREFIX)ar q ..\$@ *$(o) && \
+		cd .. && rmdir /s /q $(STATICDIR)
+	$(XCOPY) $(PERLSTATICLIB) $(COREDIR)
 
 $(MINIMOD) : $(HAVEMINIPERL) ..\minimod.pl
 	cd .. && miniperl.exe minimod.pl > lib\ExtUtils\Miniperl.pm && cd win32
@@ -753,8 +762,8 @@
 	copy splittree.pl ..
 	$(MINIPERL) -I..\lib ..\splittree.pl "../LIB" $(AUTODIR)
 
-$(PERLEXE_ICO): $(HAVEMINIPERL) makeico.pl
-	$(MINIPERL) makeico.pl > $@
+$(PERLEXE_ICO): $(HAVEMINIPERL) ..\uupacktool.pl $(PERLEXE_ICO).packd
+	$(MINIPERL) -I..\lib ..\uupacktool.pl -u $(PERLEXE_ICO).packd $(PERLEXE_ICO)
 
 $(PERLEXE_RES): perlexe.rc $(PERLEXE_ICO)
 
@@ -771,14 +780,24 @@
 $(EXTDIR)\DynaLoader\dl_win32.xs: dl_win32.xs
 	copy dl_win32.xs $(EXTDIR)\DynaLoader\dl_win32.xs
 
+MakePPPort: $(HAVEMINIPERL) $(CONFIGPM)
+	$(MINIPERL) -I..\lib ..\mkppport
+
 $(HAVEMINIPERL): $(MINI_OBJ)
 	$(LINK32) -mconsole -o $(MINIPERL) $(BLINK_FLAGS) $(MINI_OBJ) $(LIBFILES)
 	rem . > $@
 
 #most of deps of this target are in DYNALOADER and therefore omitted here
 Extensions : buildext.pl $(HAVEMINIPERL) $(PERLDEP) $(CONFIGPM)
-	$(MINIPERL) -I..\lib $(ICWD) buildext.pl "$(PLMAKE)" $(PERLDEP) $(EXTDIR)
-	$(MINIPERL) -I..\lib $(ICWD) buildext.pl "$(PLMAKE)" $(PERLDEP) ext
+	$(XCOPY) ..\\*.h $(COREDIR)\\*.*
+	$(MINIPERL) -I..\lib $(ICWD) buildext.pl "$(PLMAKE)" $(PERLDEP) $(EXTDIR) --dynamic
+	-if exist ext $(MINIPERL) -I..\lib $(ICWD) buildext.pl "$(PLMAKE)" $(PERLDEP) ext --dynamic
+
+Extensions_static : buildext.pl $(HAVEMINIPERL) $(CONFIGPM)
+	$(XCOPY) ..\\*.h $(COREDIR)\\*.*
+	$(MINIPERL) -I..\lib $(ICWD) buildext.pl "$(PLMAKE)" $(PERLDEP) $(EXTDIR) --static
+	-if exist ext $(MINIPERL) -I..\lib $(ICWD) buildext.pl "$(PLMAKE)" $(PERLDEP) ext --static
+	$(MINIPERL) -I..\lib buildext.pl --list-static-libs > Extensions_static
 
 #-------------------------------------------------------------------------------
 
@@ -848,4 +867,4 @@
 	$(RCOPY) ..\lib $(INST_LIB)\$(NULL)
 
 $(UNIDATAFILES) : $(HAVEMINIPERL) $(CONFIGPM) ..\lib\unicore\mktables
-	cd ..\lib\unicore && ..\$(MINIPERL) -I..\lib mktables
+	cd ..\lib\unicore && ..\$(MINIPERL) -I..\lib mktables -check $@ $(FIRSTUNIFILE)
PATCH
    }
}

sub _patch_gnumakefile_507 {
    my $version = shift;
    _write_gnumakefile($version, <<'MAKEFILE');
SHELL := cmd.exe
GCCBIN := gcc
INST_DRV := c:
INST_TOP := $(INST_DRV)\perl
#INST_VER	:= \__INST_VER__
#INST_ARCH	:= \$(ARCHNAME)
#USE_SITECUST	:= define
USE_MULTI	:= define
USE_ITHREADS	:= define
USE_IMP_SYS	:= define
USE_LARGE_FILES	:= define
#USE_64_BIT_INT	:= define
#USE_LONG_DOUBLE :=define
#USE_NO_REGISTRY := define
CCTYPE		:= GCC
#CFG		:= Debug
#USE_PERLCRT	= define
#USE_SETARGV	:= define
#USE_5005THREADS:= define
#CRYPT_SRC	= .\fcrypt.c
#CRYPT_LIB	= fcrypt.lib
#PERL_MALLOC	:= define
#DEBUG_MSTATS	:= define
CCHOME		:= C:\MinGW

CCINCDIR := $(CCHOME)\include
CCLIBDIR := $(CCHOME)\lib
CCDLLDIR := $(CCHOME)\bin
ARCHPREFIX :=

BUILDOPT	:= $(BUILDOPTEXTRA)

BUILDOPT	+= -DPERL_TEXTMODE_SCRIPTS

EXTRALIBDIRS	:=


D_CRYPT		?= undef
PERL_MALLOC	?= undef
DEBUG_MSTATS	?= undef

USE_SITECUST	?= undef
USE_MULTI	?= undef
USE_ITHREADS	?= undef
USE_IMP_SYS	?= undef
USE_LARGE_FILES	?= undef
USE_64_BIT_INT	?= undef
USE_LONG_DOUBLE	?= undef
USE_NO_REGISTRY	?= undef
USE_5005THREADS ?= undef

ifneq ("$(CRYPT_SRC)$(CRYPT_LIB)", "")
D_CRYPT		= define
CRYPT_FLAG	= -DHAVE_DES_FCRYPT
endif

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

ifeq ($(USE_5005THREADS),define)
ARCHNAME	= MSWin32-$(ARCHITECTURE)-thread
else ifeq ($(USE_MULTI),define)
ARCHNAME	= MSWin32-$(ARCHITECTURE)-multi
else
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
EXTUTILSDIR	= $(LIBDIR)\ExtUtils
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
DEFINES		= -DWIN32 -DWIN64 -DCONSERVATIVE -DNO_STRICT $(CRYPT_FLAG)
LOCDEFS		= -DPERLDLL -DPERL_CORE
CXX_FLAG	= -xc++
LIBC		=
LIBFILES	= $(LIBC) -lmoldname -lkernel32 -luser32 -lgdi32 -lwinspool \
	-lcomdlg32 -ladvapi32 -lshell32 -lole32 -loleaut32 -lnetapi32 \
	-luuid -lws2_32 -lmpr -lwinmm -lversion -lodbc32 -lodbccp32

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

MINIPERL	= ..\miniperl.exe
HAVEMINIPERL	= .have_miniperl
MINIDIR		= mini
PERLEXE		= ..\perl.exe
WPERLEXE	= ..\wperl.exe
STATICDIR	= .\static.tmp
GLOBEXE		= ..\perlglob.exe
CONFIGPM	= ..\lib\Config.pm
MINIMOD	= ..\lib\ExtUtils\Miniperl.pm
X2P		= ..\x2p\a2p.exe

PERLDEP = $(PERLIMPLIB)


PL2BAT		= bin\pl2bat.pl

UTILS		=			\
		..\utils\h2ph		\
		..\utils\splain		\
		..\utils\dprofpp	\
		..\utils\perlbug	\
		..\utils\pl2pm 		\
		..\utils\c2ph		\
		..\utils\h2xs		\
		..\utils\perldoc	\
		..\utils\perlcc		\
		..\pod\checkpods	\
		..\pod\pod2html		\
		..\pod\pod2latex	\
		..\pod\pod2man		\
		..\pod\pod2text		\
		..\pod\pod2usage	\
		..\pod\podchecker	\
		..\pod\podselect	\
		..\x2p\find2perl	\
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
INT64		= long long
PERLEXPLIB	= $(COREDIR)\perl__PERL_MINOR_VERSION__.exp
PERLDLL		= ..\perl__PERL_MINOR_VERSION__.dll

# don't let "gmake -n all" try to run "miniperl.exe make_ext.pl"
PLMAKE		= gmake

XCOPY		= xcopy /f /r /i /d /y
RCOPY		= xcopy /f /r /i /e /d /y
NOOP		= @rem

XSUBPP		= ..\$(MINIPERL) -I..\..\lib ..\$(EXTUTILSDIR)\xsubpp \
		-C++ -prototypes

MICROCORE_SRC	=		\
		..\av.c		\
		..\deb.c	\
		..\doio.c	\
		..\doop.c	\
		..\dump.c	\
		..\globals.c	\
		..\gv.c		\
		..\hv.c		\
		..\mg.c		\
		..\op.c		\
		..\perl.c	\
		..\perlapi.c	\
		..\perly.c	\
		..\pp.c		\
		..\pp_ctl.c	\
		..\pp_hot.c	\
		..\pp_sys.c	\
		..\regcomp.c	\
		..\regexec.c	\
		..\run.c	\
		..\scope.c	\
		..\sv.c		\
		..\taint.c	\
		..\toke.c	\
		..\universal.c	\
		..\utf8.c	\
		..\util.c	\
		..\xsutils.c

EXTRACORE_SRC	+= perllib.c

ifeq ($(PERL_MALLOC),define)
EXTRACORE_SRC	+= ..\malloc.c
endif

EXTRACORE_SRC	+= ..\perlio.c

WIN32_SRC	=		\
		.\win32.c	\
		.\win32sck.c	\
		.\win32thread.c 

ifneq ($(CRYPT_SRC), "")
WIN32_SRC	+= $(CRYPT_SRC)
endif

DLL_SRC		= $(DYNALOADER).c

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
		..\thrdvar.h	\
		.\include\dirent.h	\
		.\include\netdb.h	\
		.\include\sys\socket.h	\
		.\win32.h

CORE_H		= $(CORE_NOCFG_H) .\config.h

MICROCORE_OBJ	= $(MICROCORE_SRC:.c=$(o))
CORE_OBJ	= $(MICROCORE_OBJ) $(EXTRACORE_SRC:.c=$(o))
WIN32_OBJ	= $(WIN32_SRC:.c=$(o))

MINICORE_OBJ	= $(subst ..\,mini\,$(MICROCORE_OBJ))	\
		  $(MINIDIR)\miniperlmain$(o)	\
		  $(MINIDIR)\perlio$(o)
MINIWIN32_OBJ	= $(subst .\,mini\,$(WIN32_OBJ))
MINI_OBJ	= $(MINICORE_OBJ) $(MINIWIN32_OBJ)
DLL_OBJ		= $(DLL_SRC:.c=$(o))
X2P_OBJ		= $(X2P_SRC:.c=$(o))
PERLDLL_OBJ	= $(CORE_OBJ)
PERLEXE_OBJ	= perlmain$(o)
PERLEXEST_OBJ	= perlmainst$(o)

PERLDLL_OBJ	+= $(WIN32_OBJ) $(DLL_OBJ)

ifneq ($(USE_SETARGV),)
SETARGV_OBJ	= setargv$(o)
endif

DYNAMIC_EXT	= Socket IO Fcntl Opcode SDBM_File POSIX attrs Thread B re \
		Data/Dumper Devel/Peek ByteLoader Devel/DProf File/Glob \
		Sys/Hostname Storable
STATIC_EXT	= DynaLoader
NONXS_EXT	= Errno

DYNALOADER	= $(EXTDIR)\DynaLoader\DynaLoader
SOCKET		= $(EXTDIR)\Socket\Socket
FCNTL		= $(EXTDIR)\Fcntl\Fcntl
OPCODE		= $(EXTDIR)\Opcode\Opcode
SDBM_FILE	= $(EXTDIR)\SDBM_File\SDBM_File
IO		= $(EXTDIR)\IO\IO
POSIX		= $(EXTDIR)\POSIX\POSIX
ATTRS		= $(EXTDIR)\attrs\attrs
THREAD		= $(EXTDIR)\Thread\Thread
B		= $(EXTDIR)\B\B
RE		= $(EXTDIR)\re\re
DUMPER		= $(EXTDIR)\Data\Dumper\Dumper
ERRNO		= $(EXTDIR)\Errno\Errno
PEEK		= $(EXTDIR)\Devel\Peek\Peek
BYTELOADER	= $(EXTDIR)\ByteLoader\ByteLoader
DPROF		= $(EXTDIR)\Devel\DProf\DProf
GLOB		= $(EXTDIR)\File\Glob\Glob
HOSTNAME	= $(EXTDIR)\Sys\Hostname\Hostname
STORABLE	= $(EXTDIR)\Storable\Storable

SOCKET_DLL	= $(AUTODIR)\Socket\Socket.dll
FCNTL_DLL	= $(AUTODIR)\Fcntl\Fcntl.dll
OPCODE_DLL	= $(AUTODIR)\Opcode\Opcode.dll
SDBM_FILE_DLL	= $(AUTODIR)\SDBM_File\SDBM_File.dll
IO_DLL		= $(AUTODIR)\IO\IO.dll
POSIX_DLL	= $(AUTODIR)\POSIX\POSIX.dll
ATTRS_DLL	= $(AUTODIR)\attrs\attrs.dll
THREAD_DLL	= $(AUTODIR)\Thread\Thread.dll
B_DLL		= $(AUTODIR)\B\B.dll
DUMPER_DLL	= $(AUTODIR)\Data\Dumper\Dumper.dll
PEEK_DLL	= $(AUTODIR)\Devel\Peek\Peek.dll
RE_DLL		= $(AUTODIR)\re\re.dll
BYTELOADER_DLL	= $(AUTODIR)\ByteLoader\ByteLoader.dll
DPROF_DLL	= $(AUTODIR)\Devel\DProf\DProf.dll
GLOB_DLL	= $(AUTODIR)\File\Glob\Glob.dll
HOSTNAME_DLL	= $(AUTODIR)\Sys\Hostname\Hostname.dll
STORABLE_DLL	= $(AUTODIR)\Storable\Storable.dll

ERRNO_PM	= $(LIBDIR)\Errno.pm

EXTENSION_C	= 		\
		$(SOCKET).c	\
		$(FCNTL).c	\
		$(OPCODE).c	\
		$(SDBM_FILE).c	\
		$(IO).c		\
		$(POSIX).c	\
		$(ATTRS).c	\
		$(THREAD).c	\
		$(RE).c		\
		$(DUMPER).c	\
		$(PEEK).c	\
		$(B).c		\
		$(BYTELOADER).c	\
		$(DPROF).c	\
		$(GLOB).c	\
		$(HOSTNAME).c	\
		$(STORABLE).c

EXTENSION_DLL	= 		\
		$(SOCKET_DLL)	\
		$(FCNTL_DLL)	\
		$(OPCODE_DLL)	\
		$(SDBM_FILE_DLL)\
		$(IO_DLL)	\
		$(POSIX_DLL)	\
		$(ATTRS_DLL)	\
		$(DUMPER_DLL)	\
		$(PEEK_DLL)	\
		$(B_DLL)	\
		$(RE_DLL)	\
		$(THREAD_DLL)	\
		$(BYTELOADER_DLL)	\
		$(DPROF_DLL)	\
		$(GLOB_DLL)	\
		$(HOSTNAME_DLL)	\
		$(STORABLE_DLL)

EXTENSION_PM	=		\
		$(ERRNO_PM)

CFG_VARS	=					\
		"INST_DRV=$(INST_DRV)"			\
		"INST_TOP=$(INST_TOP)"			\
		"INST_VER=$(INST_VER)"			\
		"INST_ARCH=$(INST_ARCH)"		\
		"archname=$(ARCHNAME)"			\
		"cc=$(CC)"				\
		"ld=$(LINK32)"				\
		"ccflags=$(subst ",\",$(EXTRACFLAGS) $(OPTIMIZE) $(DEFINES) $(BUILDOPT))" \
		"cf_email=$(EMAIL)"	 		\
		"d_crypt=$(D_CRYPT)"			\
		"d_mymalloc=$(PERL_MALLOC)"		\
		"libs=$(LIBFILES)"			\
		"incpath=$(subst ",\",$(CCINCDIR))"			\
		"libperl=$(subst ",\",$(PERLIMPLIBBASE))"		\
		"libpth=$(subst ",\",$(CCLIBDIR);$(EXTRALIBDIRS))"	\
		"libc=$(LIBC)"				\
		"make=$(PLMAKE)"				\
		"usethreads=$(USE_ITHREADS)"		\
		"use5005threads=$(USE_5005THREADS)"	\
		"useithreads=$(USE_ITHREADS)"		\
		"usethreads=$(USE_5005THREADS)"		\
		"usemultiplicity=$(USE_MULTI)"		\
		"use64bitint=$(USE_64_BIT_INT)"		\
		"uselargefiles=$(USE_LARGE_FILES)"	\
		"LINK_FLAGS=$(subst ",\",$(LINK_FLAGS))"\
		"optimize=$(subst ",\",$(OPTIMIZE))"

ICWD = -I..\cpan\Cwd -I..\cpan\Cwd\lib

#
# Top targets
#

.PHONY: all

all : .\config.h $(GLOBEXE) $(MINIMOD) $(CONFIGPM) $(PERLEXE) $(X2P) $(EXTENSION_DLL) $(EXTENSION_PM)
	@echo Everything is up to date. '$(MAKE_BARE) test' to run test suite.

$(DYNALOADER)$(o) : $(DYNALOADER).c $(CORE_H) $(EXTDIR)\DynaLoader\dlutils.c

#----------------------------------------------------------------

$(GLOBEXE) : perlglob.c
	$(LINK32) $(OPTIMIZE) $(BLINK_FLAGS) -mconsole -o $@ perlglob.c $(LIBFILES)

..\config.sh : $(CFGSH_TMPL) $(HAVEMINIPERL) config_sh.PL
	$(MINIPERL) -I..\lib config_sh.PL $(CFG_VARS) $(CFGSH_TMPL) > ..\config.sh

$(CONFIGPM) : $(HAVEMINIPERL) ..\config.sh config_h.PL ..\minimod.pl
	cd .. && miniperl.exe -Ilib configpm
	$(XCOPY) *.h $(COREDIR)\\*.*
	$(XCOPY) ..\\ext\\re\\re.pm $(LIBDIR)\\*.*
	$(RCOPY) include $(COREDIR)\\*.*
	$(XCOPY) ..\\*.h $(COREDIR)\\*.*
	-$(MINIPERL) -I..\lib $(ICWD) config_h.PL "ARCHPREFIX=$(ARCHPREFIX)"

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
	@(echo #define IVdf "ld"&& \
	echo #define UVuf "lu"&& \
	echo #define UVof "lo"&& \
	echo #define UVxf "lx"&& \
	echo #define UVXf "lX"&& \
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

$(CONFIGPM) : $(HAVEMINIPERL) ..\config.sh config_h.PL ..\minimod.pl
	cd .. && miniperl.exe -Ilib configpm
	$(XCOPY) *.h $(COREDIR)\\*.*
	$(XCOPY) ..\\*.inc $(COREDIR)\\*.*
	$(XCOPY) ..\\ext\\re\\re.pm $(LIBDIR)\\*.*
	$(RCOPY) include $(COREDIR)\\*.*
	$(XCOPY) ..\\*.h $(COREDIR)\\*.*
	-$(MINIPERL) -I..\lib $(ICWD) config_h.PL "INST_VER=$(INST_VER)"

$(MINICORE_OBJ) : $(CORE_NOCFG_H)
	$(CC) -c $(CFLAGS) $(MINIBUILDOPT) -DPERL_EXTERNAL_GLOB -DPERL_IS_MINIPERL $(OBJOUT_FLAG)$@ $(PDBOUT) ..\$(*F).c

$(MINIWIN32_OBJ) : $(CORE_NOCFG_H)
	$(CC) -c $(CFLAGS) $(MINIBUILDOPT) -DPERL_IS_MINIPERL $(OBJOUT_FLAG)$@ $(PDBOUT) $(*F).c

# -DPERL_IMPLICIT_SYS needs C++ for perllib.c
# rules wrapped in .IFs break Win9X build (we end up with unbalanced []s unless
# unless the .IF is true), so instead we use a .ELSE with the default.
# This is the only file that depends on perlhost.h, vmem.h, and vdir.h

perllib$(o)	: perllib.c .\perlhost.h .\vdir.h .\vmem.h
ifeq ($(USE_IMP_SYS),define)
	$(CC) -c -I. $(CFLAGS_O) $(CXX_FLAG) $(OBJOUT_FLAG)$@ $(PDBOUT) perllib.c
else
	$(CC) -c -I. $(CFLAGS_O) $(OBJOUT_FLAG)$@ $(PDBOUT) perllib.c
endif

$(MINI_OBJ)	: $(MINIDIR)\.exists $(CORE_NOCFG_H)

$(WIN32_OBJ)	: $(CORE_H)
$(CORE_OBJ)	: $(CORE_H)
$(DLL_OBJ)	: $(CORE_H)
$(X2P_OBJ)	: $(CORE_H)

perldll.def : $(HAVEMINIPERL) $(CONFIGPM) ..\global.sym ..\pp.sym ..\makedef.pl
	$(MINIPERL) -w ..\makedef.pl PLATFORM=win32 $(OPTIMIZE) $(DEFINES) $(BUILDOPT) \
	    CCTYPE=$(CCTYPE) > perldll.def

$(PERLEXPLIB) : $(PERLIMPLIB)

$(PERLIMPLIB) : perldll.def
	$(IMPLIB) -k -d perldll.def -l $(PERLIMPLIB) -e $(PERLEXPLIB)

$(PERLDLL): perldll.def $(PERLEXPLIB) $(PERLDLL_OBJ)
	$(LINK32) -mdll -o $@ $(BLINK_FLAGS) \
	   $(PERLDLL_OBJ) $(LIBFILES) $(PERLEXPLIB)

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

$(X2P) : $(HAVEMINIPERL) $(X2P_OBJ)
	$(MINIPERL) -I..\lib ..\x2p\find2perl.PL
	$(MINIPERL) -I..\lib ..\x2p\s2p.PL
	$(LINK32) -mconsole -o $@ $(BLINK_FLAGS) $(LIBFILES) $(X2P_OBJ)

perlmain.c : runperl.c
	copy runperl.c perlmain.c

perlmain$(o) : runperl.c $(CONFIGPM)
	$(CC) $(subst -DPERLDLL,-UPERLDLL,$(CFLAGS_O)) $(OBJOUT_FLAG)$@ $(PDBOUT) -c runperl.c

perlmainst$(o) : runperl.c $(CONFIGPM)
	$(CC) $(CFLAGS_O) $(OBJOUT_FLAG)$@ $(PDBOUT) -c runperl.c

$(PERLEXE): $(PERLDLL) $(CONFIGPM) $(PERLEXE_OBJ) $(PERLIMPLIB)
	$(LINK32) -mconsole -o $@ $(BLINK_FLAGS)  \
	    $(PERLEXE_OBJ) $(PERLIMPLIB) $(LIBFILES)
	copy $(PERLEXE) $(WPERLEXE)
	$(MINIPERL) -I..\lib bin\exetype.pl $(WPERLEXE) WINDOWS
	copy splittree.pl ..
	$(MINIPERL) -I..\lib ..\splittree.pl "../LIB" $(AUTODIR)

$(DYNALOADER).c: $(HAVEMINIPERL) $(EXTDIR)\DynaLoader\dl_win32.xs $(CONFIGPM)
	if not exist $(AUTODIR) mkdir $(AUTODIR)
	cd $(EXTDIR)\DynaLoader \
		&& ..\$(MINIPERL) -I..\..\lib DynaLoader_pm.PL \
		&& ..\$(MINIPERL) -I..\..\lib XSLoader_pm.PL
	$(XCOPY) $(EXTDIR)\DynaLoader\DynaLoader.pm $(LIBDIR)\$(NULL)
	$(XCOPY) $(EXTDIR)\DynaLoader\XSLoader.pm $(LIBDIR)\$(NULL)
	cd $(EXTDIR)\DynaLoader \
		&& $(XSUBPP) dl_win32.xs > ..\$(DYNALOADER).c

$(EXTDIR)\DynaLoader\dl_win32.xs: dl_win32.xs
	copy dl_win32.xs $(EXTDIR)\DynaLoader\dl_win32.xs

$(HAVEMINIPERL): $(MINI_OBJ)
	$(LINK32) -mconsole -o $(MINIPERL) $(BLINK_FLAGS) $(MINI_OBJ) $(LIBFILES)
	rem . > $@

$(DUMPER_DLL): $(HAVEMINIPERL) $(DUMPER).xs
	cd $(EXTDIR)\Data\Dumper && ..\..\..\miniperl -I..\..\..\lib Makefile.PL INSTALLDIRS=perl && $(PLMAKE)

$(DPROF_DLL): $(HAVEMINIPERL) $(DPROF).xs
	cd $(EXTDIR)\Devel\DProf && ..\..\..\miniperl -I..\..\..\lib Makefile.PL INSTALLDIRS=perl && $(PLMAKE)

$(GLOB_DLL): $(HAVEMINIPERL) $(GLOB).xs
	cd $(EXTDIR)\File\Glob && ..\..\..\miniperl -I..\..\..\lib Makefile.PL INSTALLDIRS=perl && $(PLMAKE)

$(PEEK_DLL): $(HAVEMINIPERL) $(PEEK).xs
	cd $(EXTDIR)\Devel\Peek && ..\..\..\miniperl -I..\..\..\lib Makefile.PL INSTALLDIRS=perl && $(PLMAKE)

$(RE_DLL): $(HAVEMINIPERL) $(RE).xs
	cd $(EXTDIR)\re && ..\..\miniperl -I..\..\lib Makefile.PL INSTALLDIRS=perl && $(PLMAKE)

$(B_DLL): $(HAVEMINIPERL) $(B).xs
	cd $(EXTDIR)\B && ..\..\miniperl -I..\..\lib Makefile.PL INSTALLDIRS=perl && $(PLMAKE)

$(THREAD_DLL): $(HAVEMINIPERL) $(THREAD).xs
	cd $(EXTDIR)\Thread && ..\..\miniperl -I..\..\lib Makefile.PL INSTALLDIRS=perl && $(PLMAKE)

$(ATTRS_DLL): $(HAVEMINIPERL) $(ATTRS).xs
	cd $(EXTDIR)\attrs && ..\..\miniperl -I..\..\lib Makefile.PL INSTALLDIRS=perl && $(PLMAKE)

$(POSIX_DLL): $(HAVEMINIPERL) $(POSIX).xs
	cd $(EXTDIR)\POSIX && ..\..\miniperl -I..\..\lib Makefile.PL INSTALLDIRS=perl && $(PLMAKE)

$(IO_DLL): $(HAVEMINIPERL) $(IO).xs
	cd $(EXTDIR)\IO && ..\..\miniperl -I..\..\lib Makefile.PL INSTALLDIRS=perl && $(PLMAKE)

$(SDBM_FILE_DLL) : $(HAVEMINIPERL) $(SDBM_FILE).xs
	cd $(EXTDIR)\SDBM_File && ..\..\miniperl -I..\..\lib Makefile.PL INSTALLDIRS=perl && $(PLMAKE)

$(FCNTL_DLL): $(HAVEMINIPERL) $(FCNTL).xs
	cd $(EXTDIR)\Fcntl && ..\..\miniperl -I..\..\lib Makefile.PL INSTALLDIRS=perl && $(PLMAKE)

$(OPCODE_DLL): $(HAVEMINIPERL) $(OPCODE).xs
	cd $(EXTDIR)\Opcode && ..\..\miniperl -I..\..\lib Makefile.PL INSTALLDIRS=perl && $(PLMAKE)

$(SOCKET_DLL): $(HAVEMINIPERL) $(SOCKET).xs
	cd $(EXTDIR)\Socket && ..\..\miniperl -I..\..\lib Makefile.PL INSTALLDIRS=perl && $(PLMAKE)

$(HOSTNAME_DLL): $(HAVEMINIPERL) $(HOSTNAME).xs
	cd $(EXTDIR)\Sys\Hostname && ..\..\..\miniperl -I..\..\..\lib Makefile.PL INSTALLDIRS=perl && $(PLMAKE)

$(BYTELOADER_DLL): $(HAVEMINIPERL) $(BYTELOADER).xs
	cd $(EXTDIR)\ByteLoader && ..\..\miniperl -I..\..\lib Makefile.PL INSTALLDIRS=perl && $(PLMAKE)

$(STORABLE_DLL): $(HAVEMINIPERL) $(STORABLE).xs
	cd $(EXTDIR)\Storable && ..\..\miniperl -I..\..\lib Makefile.PL INSTALLDIRS=perl && $(PLMAKE)

$(ERRNO_PM): $(HAVEMINIPERL) $(ERRNO)_pm.PL
	cd $(EXTDIR)\Errno && ..\..\miniperl -I..\..\lib Makefile.PL INSTALLDIRS=perl && $(PLMAKE)

#-------------------------------------------------------------------------------

doc: $(PERLEXE)
	$(PERLEXE) -I..\lib ..\installhtml --podroot=.. --htmldir=$(HTMLDIR) \
	    --podpath=pod:lib:utils --htmlroot="file://$(subst :,|,$(INST_HTML))"\
	    --recurse

utils: $(PERLEXE) $(X2P)
	cd ..\utils && $(PLMAKE) PERL=$(MINIPERL)
	copy ..\README.amiga    ..\pod\perlamiga.pod
	copy ..\README.cygwin   ..\pod\perlcygwin.pod
	copy ..\README.dos      ..\pod\perldos.pod
	copy ..\README.hpux     ..\pod\perlhpux.pod
	copy ..\README.machten  ..\pod\perlmachten.pod
	copy ..\README.os2      ..\pod\perlos2.pod
	copy ..\vms\perlvms.pod ..\pod\perlvms.pod
	copy ..\README.win32    ..\pod\perlwin32.pod
	cd ..\pod && $(PLMAKE) -f ..\win32\pod.mak converters
# 	FIXME: it faisl with "gmake: *** [GNUmakefile:872: utils] Error -1073741515"
#	$(PERLEXE) -I..\lib $(PL2BAT) $(UTILS)

install : all installbare installhtml

installbare : utils
	$(PERLEXE) ..\installperl
	if exist $(WPERLEXE) $(XCOPY) $(WPERLEXE) $(INST_BIN)\$(NULL)
	$(XCOPY) $(GLOBEXE) $(INST_BIN)\$(NULL)
	$(XCOPY) "bin\*.bat" $(INST_SCRIPT)\$(NULL)

installhtml : doc
	$(RCOPY) $(HTMLDIR)\*.* $(INST_HTML)\$(NULL)
MAKEFILE
    if (_ge($version, "5.7.1")) {
        _patch_gnumakefile($version, <<'PATCH');
--- win32/GNUmakefile
+++ win32/GNUmakefile
@@ -8,6 +8,7 @@
 USE_MULTI	:= define
 USE_ITHREADS	:= define
 USE_IMP_SYS	:= define
+USE_PERLIO	:= define
 USE_LARGE_FILES	:= define
 #USE_64_BIT_INT	:= define
 #USE_LONG_DOUBLE :=define
@@ -43,6 +44,7 @@
 USE_MULTI	?= undef
 USE_ITHREADS	?= undef
 USE_IMP_SYS	?= undef
+USE_PERLIO	?= undef
 USE_LARGE_FILES	?= undef
 USE_64_BIT_INT	?= undef
 USE_LONG_DOUBLE	?= undef
@@ -100,6 +102,15 @@
 else ifeq ($(USE_MULTI),define)
 ARCHNAME	= MSWin32-$(ARCHITECTURE)-multi
 else
+ifeq ($(USE_PERLIO),define)
+ARCHNAME	= MSWin32-$(ARCHITECTURE)-perlio
+else
+ARCHNAME	= MSWin32-$(ARCHITECTURE)
+endif
+endif
+
+ifeq ($(USE_PERLIO),define)
+BUILDOPT	+= -DUSE_PERLIO
 endif
 
 ifeq ($(USE_ITHREADS),define)
@@ -402,92 +413,14 @@
 SETARGV_OBJ	= setargv$(o)
 endif
 
-DYNAMIC_EXT	= Socket IO Fcntl Opcode SDBM_File POSIX attrs Thread B re \
-		Data/Dumper Devel/Peek ByteLoader Devel/DProf File/Glob \
-		Sys/Hostname Storable
-STATIC_EXT	= DynaLoader
-NONXS_EXT	= Errno
+ifeq ($(ALL_STATIC),define)
+STATIC_EXT	= * !Win32 !SDBM_File !Encode
+else
+#STATIC_EXT	= Cwd Compress/Raw/Zlib
+STATIC_EXT	= Win32CORE
+endif
 
 DYNALOADER	= $(EXTDIR)\DynaLoader\DynaLoader
-SOCKET		= $(EXTDIR)\Socket\Socket
-FCNTL		= $(EXTDIR)\Fcntl\Fcntl
-OPCODE		= $(EXTDIR)\Opcode\Opcode
-SDBM_FILE	= $(EXTDIR)\SDBM_File\SDBM_File
-IO		= $(EXTDIR)\IO\IO
-POSIX		= $(EXTDIR)\POSIX\POSIX
-ATTRS		= $(EXTDIR)\attrs\attrs
-THREAD		= $(EXTDIR)\Thread\Thread
-B		= $(EXTDIR)\B\B
-RE		= $(EXTDIR)\re\re
-DUMPER		= $(EXTDIR)\Data\Dumper\Dumper
-ERRNO		= $(EXTDIR)\Errno\Errno
-PEEK		= $(EXTDIR)\Devel\Peek\Peek
-BYTELOADER	= $(EXTDIR)\ByteLoader\ByteLoader
-DPROF		= $(EXTDIR)\Devel\DProf\DProf
-GLOB		= $(EXTDIR)\File\Glob\Glob
-HOSTNAME	= $(EXTDIR)\Sys\Hostname\Hostname
-STORABLE	= $(EXTDIR)\Storable\Storable
-
-SOCKET_DLL	= $(AUTODIR)\Socket\Socket.dll
-FCNTL_DLL	= $(AUTODIR)\Fcntl\Fcntl.dll
-OPCODE_DLL	= $(AUTODIR)\Opcode\Opcode.dll
-SDBM_FILE_DLL	= $(AUTODIR)\SDBM_File\SDBM_File.dll
-IO_DLL		= $(AUTODIR)\IO\IO.dll
-POSIX_DLL	= $(AUTODIR)\POSIX\POSIX.dll
-ATTRS_DLL	= $(AUTODIR)\attrs\attrs.dll
-THREAD_DLL	= $(AUTODIR)\Thread\Thread.dll
-B_DLL		= $(AUTODIR)\B\B.dll
-DUMPER_DLL	= $(AUTODIR)\Data\Dumper\Dumper.dll
-PEEK_DLL	= $(AUTODIR)\Devel\Peek\Peek.dll
-RE_DLL		= $(AUTODIR)\re\re.dll
-BYTELOADER_DLL	= $(AUTODIR)\ByteLoader\ByteLoader.dll
-DPROF_DLL	= $(AUTODIR)\Devel\DProf\DProf.dll
-GLOB_DLL	= $(AUTODIR)\File\Glob\Glob.dll
-HOSTNAME_DLL	= $(AUTODIR)\Sys\Hostname\Hostname.dll
-STORABLE_DLL	= $(AUTODIR)\Storable\Storable.dll
-
-ERRNO_PM	= $(LIBDIR)\Errno.pm
-
-EXTENSION_C	= 		\
-		$(SOCKET).c	\
-		$(FCNTL).c	\
-		$(OPCODE).c	\
-		$(SDBM_FILE).c	\
-		$(IO).c		\
-		$(POSIX).c	\
-		$(ATTRS).c	\
-		$(THREAD).c	\
-		$(RE).c		\
-		$(DUMPER).c	\
-		$(PEEK).c	\
-		$(B).c		\
-		$(BYTELOADER).c	\
-		$(DPROF).c	\
-		$(GLOB).c	\
-		$(HOSTNAME).c	\
-		$(STORABLE).c
-
-EXTENSION_DLL	= 		\
-		$(SOCKET_DLL)	\
-		$(FCNTL_DLL)	\
-		$(OPCODE_DLL)	\
-		$(SDBM_FILE_DLL)\
-		$(IO_DLL)	\
-		$(POSIX_DLL)	\
-		$(ATTRS_DLL)	\
-		$(DUMPER_DLL)	\
-		$(PEEK_DLL)	\
-		$(B_DLL)	\
-		$(RE_DLL)	\
-		$(THREAD_DLL)	\
-		$(BYTELOADER_DLL)	\
-		$(DPROF_DLL)	\
-		$(GLOB_DLL)	\
-		$(HOSTNAME_DLL)	\
-		$(STORABLE_DLL)
-
-EXTENSION_PM	=		\
-		$(ERRNO_PM)
 
 CFG_VARS	=					\
 		"INST_DRV=$(INST_DRV)"			\
@@ -512,6 +445,7 @@
 		"useithreads=$(USE_ITHREADS)"		\
 		"usethreads=$(USE_5005THREADS)"		\
 		"usemultiplicity=$(USE_MULTI)"		\
+		"useperlio=$(USE_PERLIO)"		\
 		"use64bitint=$(USE_64_BIT_INT)"		\
 		"uselargefiles=$(USE_LARGE_FILES)"	\
 		"LINK_FLAGS=$(subst ",\",$(LINK_FLAGS))"\
@@ -525,7 +459,7 @@
 
 .PHONY: all
 
-all : .\config.h $(GLOBEXE) $(MINIMOD) $(CONFIGPM) $(PERLEXE) $(X2P) $(EXTENSION_DLL) $(EXTENSION_PM)
+all : .\config.h $(GLOBEXE) $(MINIMOD) $(CONFIGPM) $(PERLEXE) $(X2P) Extensions
 	@echo Everything is up to date. '$(MAKE_BARE) test' to run test suite.
 
 $(DYNALOADER)$(o) : $(DYNALOADER).c $(CORE_H) $(EXTDIR)\DynaLoader\dlutils.c
@@ -758,7 +692,7 @@
 ..\x2p\walk$(o) : ..\x2p\walk.c
 	$(CC) -I..\x2p $(CFLAGS) $(OBJOUT_FLAG)$@ -c ..\x2p\walk.c
 
-$(X2P) : $(HAVEMINIPERL) $(X2P_OBJ)
+$(X2P) : $(HAVEMINIPERL) $(X2P_OBJ) Extensions
 	$(MINIPERL) -I..\lib ..\x2p\find2perl.PL
 	$(MINIPERL) -I..\lib ..\x2p\s2p.PL
 	$(LINK32) -mconsole -o $@ $(BLINK_FLAGS) $(LIBFILES) $(X2P_OBJ)
@@ -797,59 +731,9 @@
 	$(LINK32) -mconsole -o $(MINIPERL) $(BLINK_FLAGS) $(MINI_OBJ) $(LIBFILES)
 	rem . > $@
 
-$(DUMPER_DLL): $(HAVEMINIPERL) $(DUMPER).xs
-	cd $(EXTDIR)\Data\Dumper && ..\..\..\miniperl -I..\..\..\lib Makefile.PL INSTALLDIRS=perl && $(PLMAKE)
-
-$(DPROF_DLL): $(HAVEMINIPERL) $(DPROF).xs
-	cd $(EXTDIR)\Devel\DProf && ..\..\..\miniperl -I..\..\..\lib Makefile.PL INSTALLDIRS=perl && $(PLMAKE)
-
-$(GLOB_DLL): $(HAVEMINIPERL) $(GLOB).xs
-	cd $(EXTDIR)\File\Glob && ..\..\..\miniperl -I..\..\..\lib Makefile.PL INSTALLDIRS=perl && $(PLMAKE)
-
-$(PEEK_DLL): $(HAVEMINIPERL) $(PEEK).xs
-	cd $(EXTDIR)\Devel\Peek && ..\..\..\miniperl -I..\..\..\lib Makefile.PL INSTALLDIRS=perl && $(PLMAKE)
-
-$(RE_DLL): $(HAVEMINIPERL) $(RE).xs
-	cd $(EXTDIR)\re && ..\..\miniperl -I..\..\lib Makefile.PL INSTALLDIRS=perl && $(PLMAKE)
-
-$(B_DLL): $(HAVEMINIPERL) $(B).xs
-	cd $(EXTDIR)\B && ..\..\miniperl -I..\..\lib Makefile.PL INSTALLDIRS=perl && $(PLMAKE)
-
-$(THREAD_DLL): $(HAVEMINIPERL) $(THREAD).xs
-	cd $(EXTDIR)\Thread && ..\..\miniperl -I..\..\lib Makefile.PL INSTALLDIRS=perl && $(PLMAKE)
-
-$(ATTRS_DLL): $(HAVEMINIPERL) $(ATTRS).xs
-	cd $(EXTDIR)\attrs && ..\..\miniperl -I..\..\lib Makefile.PL INSTALLDIRS=perl && $(PLMAKE)
-
-$(POSIX_DLL): $(HAVEMINIPERL) $(POSIX).xs
-	cd $(EXTDIR)\POSIX && ..\..\miniperl -I..\..\lib Makefile.PL INSTALLDIRS=perl && $(PLMAKE)
-
-$(IO_DLL): $(HAVEMINIPERL) $(IO).xs
-	cd $(EXTDIR)\IO && ..\..\miniperl -I..\..\lib Makefile.PL INSTALLDIRS=perl && $(PLMAKE)
-
-$(SDBM_FILE_DLL) : $(HAVEMINIPERL) $(SDBM_FILE).xs
-	cd $(EXTDIR)\SDBM_File && ..\..\miniperl -I..\..\lib Makefile.PL INSTALLDIRS=perl && $(PLMAKE)
-
-$(FCNTL_DLL): $(HAVEMINIPERL) $(FCNTL).xs
-	cd $(EXTDIR)\Fcntl && ..\..\miniperl -I..\..\lib Makefile.PL INSTALLDIRS=perl && $(PLMAKE)
-
-$(OPCODE_DLL): $(HAVEMINIPERL) $(OPCODE).xs
-	cd $(EXTDIR)\Opcode && ..\..\miniperl -I..\..\lib Makefile.PL INSTALLDIRS=perl && $(PLMAKE)
-
-$(SOCKET_DLL): $(HAVEMINIPERL) $(SOCKET).xs
-	cd $(EXTDIR)\Socket && ..\..\miniperl -I..\..\lib Makefile.PL INSTALLDIRS=perl && $(PLMAKE)
-
-$(HOSTNAME_DLL): $(HAVEMINIPERL) $(HOSTNAME).xs
-	cd $(EXTDIR)\Sys\Hostname && ..\..\..\miniperl -I..\..\..\lib Makefile.PL INSTALLDIRS=perl && $(PLMAKE)
-
-$(BYTELOADER_DLL): $(HAVEMINIPERL) $(BYTELOADER).xs
-	cd $(EXTDIR)\ByteLoader && ..\..\miniperl -I..\..\lib Makefile.PL INSTALLDIRS=perl && $(PLMAKE)
-
-$(STORABLE_DLL): $(HAVEMINIPERL) $(STORABLE).xs
-	cd $(EXTDIR)\Storable && ..\..\miniperl -I..\..\lib Makefile.PL INSTALLDIRS=perl && $(PLMAKE)
-
-$(ERRNO_PM): $(HAVEMINIPERL) $(ERRNO)_pm.PL
-	cd $(EXTDIR)\Errno && ..\..\miniperl -I..\..\lib Makefile.PL INSTALLDIRS=perl && $(PLMAKE)
+#most of deps of this target are in DYNALOADER and therefore omitted here
+Extensions : buildext.pl $(HAVEMINIPERL) $(PERLDEP) $(CONFIGPM)
+	$(MINIPERL) -I..\lib $(ICWD) buildext.pl "$(PLMAKE)" $(PERLDEP) $(EXTDIR)
 
 #-------------------------------------------------------------------------------
 
@@ -860,17 +744,28 @@
 
 utils: $(PERLEXE) $(X2P)
 	cd ..\utils && $(PLMAKE) PERL=$(MINIPERL)
+	copy ..\README.aix      ..\pod\perlaix.pod
 	copy ..\README.amiga    ..\pod\perlamiga.pod
+	copy ..\README.apollo   ..\pod\perlapollo.pod
+	copy ..\README.beos     ..\pod\perlbeos.pod
+	copy ..\README.bs2000   ..\pod\perlbs2000.pod
 	copy ..\README.cygwin   ..\pod\perlcygwin.pod
 	copy ..\README.dos      ..\pod\perldos.pod
+	copy ..\README.epoc     ..\pod\perlepoc.pod
 	copy ..\README.hpux     ..\pod\perlhpux.pod
 	copy ..\README.machten  ..\pod\perlmachten.pod
+	copy ..\README.macos    ..\pod\perlmacos.pod
+	copy ..\README.mpeix    ..\pod\perlmpeix.pod
 	copy ..\README.os2      ..\pod\perlos2.pod
+	copy ..\README.os390    ..\pod\perlos390.pod
+	copy ..\README.solaris  ..\pod\perlsolaris.pod
+	copy ..\README.vmesa    ..\pod\perlvmesa.pod
 	copy ..\vms\perlvms.pod ..\pod\perlvms.pod
+	copy ..\README.vos      ..\pod\perlvos.pod
 	copy ..\README.win32    ..\pod\perlwin32.pod
+	cd ..\lib && $(PERLEXE) -Dtls lib_pm.PL
 	cd ..\pod && $(PLMAKE) -f ..\win32\pod.mak converters
-# 	FIXME: it faisl with "gmake: *** [GNUmakefile:872: utils] Error -1073741515"
-#	$(PERLEXE) -I..\lib $(PL2BAT) $(UTILS)
+	$(PERLEXE) -I..\lib $(PL2BAT) $(UTILS)
 
 install : all installbare installhtml
 
PATCH
    }
    if (_ge($version, "5.7.2")) {
        _patch_gnumakefile($version, <<'PATCH');
--- win32/GNUmakefile
+++ win32/GNUmakefile
@@ -303,7 +303,9 @@
 		..\globals.c	\
 		..\gv.c		\
 		..\hv.c		\
+		..\locale.c	\
 		..\mg.c		\
+		..\numeric.c	\
 		..\op.c		\
 		..\perl.c	\
 		..\perlapi.c	\
@@ -311,6 +313,7 @@
 		..\pp.c		\
 		..\pp_ctl.c	\
 		..\pp_hot.c	\
+		..\pp_pack.c	\
 		..\pp_sys.c	\
 		..\regcomp.c	\
 		..\regexec.c	\
@@ -337,6 +340,10 @@
 		.\win32sck.c	\
 		.\win32thread.c 
 
+ifeq ($(USE_PERLIO),define)
+WIN32_SRC	+= .\win32io.c
+endif
+
 ifneq ($(CRYPT_SRC), "")
 WIN32_SRC	+= $(CRYPT_SRC)
 endif
@@ -748,10 +755,8 @@
 	copy ..\README.amiga    ..\pod\perlamiga.pod
 	copy ..\README.apollo   ..\pod\perlapollo.pod
 	copy ..\README.beos     ..\pod\perlbeos.pod
-	copy ..\README.bs2000   ..\pod\perlbs2000.pod
 	copy ..\README.cygwin   ..\pod\perlcygwin.pod
 	copy ..\README.dos      ..\pod\perldos.pod
-	copy ..\README.epoc     ..\pod\perlepoc.pod
 	copy ..\README.hpux     ..\pod\perlhpux.pod
 	copy ..\README.machten  ..\pod\perlmachten.pod
 	copy ..\README.macos    ..\pod\perlmacos.pod
PATCH
    }
    if (_ge($version, "5.7.3")) {
        _patch_gnumakefile($version, <<'PATCH');
--- win32/GNUmakefile
+++ win32/GNUmakefile
@@ -260,6 +260,8 @@
 		..\utils\h2xs		\
 		..\utils\perldoc	\
 		..\utils\perlcc		\
+		..\utils\perlivp	\
+		..\utils\libnetcfg	\
 		..\pod\checkpods	\
 		..\pod\pod2html		\
 		..\pod\pod2latex	\
@@ -270,6 +272,7 @@
 		..\pod\podselect	\
 		..\x2p\find2perl	\
 		..\x2p\s2p		\
+		..\lib\ExtUtils\xsubpp	\
 		bin\exetype.pl		\
 		bin\runperl.pl		\
 		bin\pl2bat.pl		\
@@ -314,6 +317,7 @@
 		..\pp_ctl.c	\
 		..\pp_hot.c	\
 		..\pp_pack.c	\
+		..\pp_sort.c	\
 		..\pp_sys.c	\
 		..\regcomp.c	\
 		..\regexec.c	\
@@ -755,15 +759,25 @@
 	copy ..\README.amiga    ..\pod\perlamiga.pod
 	copy ..\README.apollo   ..\pod\perlapollo.pod
 	copy ..\README.beos     ..\pod\perlbeos.pod
+	copy ..\README.bs2000   ..\pod\perlbs2000.pod
+	copy ..\README.ce       ..\pod\perlce.pod
 	copy ..\README.cygwin   ..\pod\perlcygwin.pod
+	copy ..\README.dgux     ..\pod\perldgux.pod
 	copy ..\README.dos      ..\pod\perldos.pod
+	copy ..\README.epoc     ..\pod\perlepoc.pod
 	copy ..\README.hpux     ..\pod\perlhpux.pod
+	copy ..\README.hurd     ..\pod\perlhurd.pod
 	copy ..\README.machten  ..\pod\perlmachten.pod
 	copy ..\README.macos    ..\pod\perlmacos.pod
+	copy ..\README.mint     ..\pod\perlmint.pod
 	copy ..\README.mpeix    ..\pod\perlmpeix.pod
 	copy ..\README.os2      ..\pod\perlos2.pod
 	copy ..\README.os390    ..\pod\perlos390.pod
+	copy ..\README.plan9    ..\pod\perlplan9.pod
+	copy ..\README.qnx      ..\pod\perlqnx.pod
 	copy ..\README.solaris  ..\pod\perlsolaris.pod
+	copy ..\README.tru64    ..\pod\perltru64.pod
+	copy ..\README.uts      ..\pod\perluts.pod
 	copy ..\README.vmesa    ..\pod\perlvmesa.pod
 	copy ..\vms\perlvms.pod ..\pod\perlvms.pod
 	copy ..\README.vos      ..\pod\perlvos.pod
PATCH
    }
}

sub _patch_gnumakefile_506 {
    my $version = shift;
    _write_gnumakefile($version, <<'MAKEFILE');
SHELL := cmd.exe
GCCBIN := gcc
INST_DRV := c:
INST_TOP := $(INST_DRV)\perl
#INST_VER	:= \__INST_VER__
#INST_ARCH	:= \$(ARCHNAME)
#USE_SITECUST	:= define
USE_MULTI	:= define
USE_ITHREADS	:= define
USE_IMP_SYS	:= define
USE_LARGE_FILES	:= define
#USE_64_BIT_INT	:= define
#USE_LONG_DOUBLE :=define
#USE_NO_REGISTRY := define
CCTYPE		:= GCC
#CFG		:= Debug
#USE_PERLCRT	= define
#USE_SETARGV	:= define
#USE_5005THREADS:= define
#CRYPT_SRC	= .\fcrypt.c
#CRYPT_LIB	= fcrypt.lib
#PERL_MALLOC	:= define
#DEBUG_MSTATS	:= define
CCHOME		:= C:\MinGW

CCINCDIR := $(CCHOME)\include
CCLIBDIR := $(CCHOME)\lib
CCDLLDIR := $(CCHOME)\bin
ARCHPREFIX :=

BUILDOPT	:= $(BUILDOPTEXTRA)

BUILDOPT	+= -DPERL_TEXTMODE_SCRIPTS

EXTRALIBDIRS	:=


D_CRYPT		?= undef
PERL_MALLOC	?= undef
DEBUG_MSTATS	?= undef

USE_SITECUST	?= undef
USE_MULTI	?= undef
USE_ITHREADS	?= undef
USE_IMP_SYS	?= undef
USE_LARGE_FILES	?= undef
USE_64_BIT_INT	?= undef
USE_LONG_DOUBLE	?= undef
USE_NO_REGISTRY	?= undef
USE_5005THREADS ?= undef

ifneq ("$(CRYPT_SRC)$(CRYPT_LIB)", "")
D_CRYPT		= define
CRYPT_FLAG	= -DHAVE_DES_FCRYPT
endif

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

ifeq ($(USE_5005THREADS),define)
ARCHNAME	= MSWin32-$(ARCHITECTURE)-thread
else ifeq ($(USE_MULTI),define)
ARCHNAME	= MSWin32-$(ARCHITECTURE)-multi
else
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
EXTUTILSDIR	= $(LIBDIR)\ExtUtils
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
DEFINES		= -DWIN32 -DWIN64 -DCONSERVATIVE -DNO_STRICT $(CRYPT_FLAG)
LOCDEFS		= -DPERLDLL -DPERL_CORE
CXX_FLAG	= -xc++
LIBC		=
LIBFILES	= $(LIBC) -lmoldname -lkernel32 -luser32 -lgdi32 -lwinspool \
	-lcomdlg32 -ladvapi32 -lshell32 -lole32 -loleaut32 -lnetapi32 \
	-luuid -lws2_32 -lmpr -lwinmm -lversion -lodbc32 -lodbccp32

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

MINIPERL	= ..\miniperl.exe
HAVEMINIPERL	= .have_miniperl
MINIDIR		= mini
PERLEXE		= ..\perl.exe
WPERLEXE	= ..\wperl.exe
STATICDIR	= .\static.tmp
GLOBEXE		= ..\perlglob.exe
CONFIGPM	= ..\lib\Config.pm
MINIMOD	= ..\lib\ExtUtils\Miniperl.pm
X2P		= ..\x2p\a2p.exe

PERLDEP = $(PERLIMPLIB)


PL2BAT		= bin\pl2bat.pl

UTILS		=			\
		..\utils\h2ph		\
		..\utils\splain		\
		..\utils\dprofpp	\
		..\utils\perlbug	\
		..\utils\pl2pm 		\
		..\utils\c2ph		\
		..\utils\h2xs		\
		..\utils\perldoc	\
		..\utils\perlcc		\
		..\pod\checkpods	\
		..\pod\pod2html		\
		..\pod\pod2latex	\
		..\pod\pod2man		\
		..\pod\pod2text		\
		..\pod\pod2usage	\
		..\pod\podchecker	\
		..\pod\podselect	\
		..\x2p\find2perl	\
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
INT64		= long long
PERLEXPLIB	= $(COREDIR)\perl__PERL_MINOR_VERSION__.exp
PERLDLL		= ..\perl__PERL_MINOR_VERSION__.dll

# don't let "gmake -n all" try to run "miniperl.exe make_ext.pl"
PLMAKE		= gmake

XCOPY		= xcopy /f /r /i /d /y
RCOPY		= xcopy /f /r /i /e /d /y
NOOP		= @rem

XSUBPP		= ..\$(MINIPERL) -I..\..\lib ..\$(EXTUTILSDIR)\xsubpp \
		-C++ -prototypes

MICROCORE_SRC	=		\
		..\av.c		\
		..\deb.c	\
		..\doio.c	\
		..\doop.c	\
		..\dump.c	\
		..\globals.c	\
		..\gv.c		\
		..\hv.c		\
		..\mg.c		\
		..\op.c		\
		..\perl.c	\
		..\perlapi.c	\
		..\perly.c	\
		..\pp.c		\
		..\pp_ctl.c	\
		..\pp_hot.c	\
		..\pp_sys.c	\
		..\regcomp.c	\
		..\regexec.c	\
		..\run.c	\
		..\scope.c	\
		..\sv.c		\
		..\taint.c	\
		..\toke.c	\
		..\universal.c	\
		..\utf8.c	\
		..\util.c	\
		..\xsutils.c

EXTRACORE_SRC	+= perllib.c

ifeq ($(PERL_MALLOC),define)
EXTRACORE_SRC	+= ..\malloc.c
endif

EXTRACORE_SRC	+= ..\perlio.c

WIN32_SRC	=		\
		.\win32.c	\
		.\win32sck.c	\
		.\win32thread.c 

ifneq ($(CRYPT_SRC), "")
WIN32_SRC	+= $(CRYPT_SRC)
endif

DLL_SRC		= $(DYNALOADER).c

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
		..\thrdvar.h	\
		.\include\dirent.h	\
		.\include\netdb.h	\
		.\include\sys\socket.h	\
		.\win32.h

CORE_H		= $(CORE_NOCFG_H) .\config.h

MICROCORE_OBJ	= $(MICROCORE_SRC:.c=$(o))
CORE_OBJ	= $(MICROCORE_OBJ) $(EXTRACORE_SRC:.c=$(o))
WIN32_OBJ	= $(WIN32_SRC:.c=$(o))

MINICORE_OBJ	= $(subst ..\,mini\,$(MICROCORE_OBJ))	\
		  $(MINIDIR)\miniperlmain$(o)	\
		  $(MINIDIR)\perlio$(o)
MINIWIN32_OBJ	= $(subst .\,mini\,$(WIN32_OBJ))
MINI_OBJ	= $(MINICORE_OBJ) $(MINIWIN32_OBJ)
DLL_OBJ		= $(DLL_SRC:.c=$(o))
X2P_OBJ		= $(X2P_SRC:.c=$(o))
PERLDLL_OBJ	= $(CORE_OBJ)
PERLEXE_OBJ	= perlmain$(o)
PERLEXEST_OBJ	= perlmainst$(o)

PERLDLL_OBJ	+= $(WIN32_OBJ) $(DLL_OBJ)

ifneq ($(USE_SETARGV),)
SETARGV_OBJ	= setargv$(o)
endif

DYNAMIC_EXT	= Socket IO Fcntl Opcode SDBM_File POSIX attrs Thread B re \
		Data/Dumper Devel/Peek ByteLoader Devel/DProf File/Glob \
		Sys/Hostname
STATIC_EXT	= DynaLoader
NONXS_EXT	= Errno

DYNALOADER	= $(EXTDIR)\DynaLoader\DynaLoader
SOCKET		= $(EXTDIR)\Socket\Socket
FCNTL		= $(EXTDIR)\Fcntl\Fcntl
OPCODE		= $(EXTDIR)\Opcode\Opcode
SDBM_FILE	= $(EXTDIR)\SDBM_File\SDBM_File
IO		= $(EXTDIR)\IO\IO
POSIX		= $(EXTDIR)\POSIX\POSIX
ATTRS		= $(EXTDIR)\attrs\attrs
THREAD		= $(EXTDIR)\Thread\Thread
B		= $(EXTDIR)\B\B
RE		= $(EXTDIR)\re\re
DUMPER		= $(EXTDIR)\Data\Dumper\Dumper
ERRNO		= $(EXTDIR)\Errno\Errno
PEEK		= $(EXTDIR)\Devel\Peek\Peek
BYTELOADER	= $(EXTDIR)\ByteLoader\ByteLoader
DPROF		= $(EXTDIR)\Devel\DProf\DProf
GLOB		= $(EXTDIR)\File\Glob\Glob
HOSTNAME	= $(EXTDIR)\Sys\Hostname\Hostname

SOCKET_DLL	= $(AUTODIR)\Socket\Socket.dll
FCNTL_DLL	= $(AUTODIR)\Fcntl\Fcntl.dll
OPCODE_DLL	= $(AUTODIR)\Opcode\Opcode.dll
SDBM_FILE_DLL	= $(AUTODIR)\SDBM_File\SDBM_File.dll
IO_DLL		= $(AUTODIR)\IO\IO.dll
POSIX_DLL	= $(AUTODIR)\POSIX\POSIX.dll
ATTRS_DLL	= $(AUTODIR)\attrs\attrs.dll
THREAD_DLL	= $(AUTODIR)\Thread\Thread.dll
B_DLL		= $(AUTODIR)\B\B.dll
DUMPER_DLL	= $(AUTODIR)\Data\Dumper\Dumper.dll
PEEK_DLL	= $(AUTODIR)\Devel\Peek\Peek.dll
RE_DLL		= $(AUTODIR)\re\re.dll
BYTELOADER_DLL	= $(AUTODIR)\ByteLoader\ByteLoader.dll
DPROF_DLL	= $(AUTODIR)\Devel\DProf\DProf.dll
GLOB_DLL	= $(AUTODIR)\File\Glob\Glob.dll
HOSTNAME_DLL	= $(AUTODIR)\Sys\Hostname\Hostname.dll

ERRNO_PM	= $(LIBDIR)\Errno.pm

EXTENSION_C	= 		\
		$(SOCKET).c	\
		$(FCNTL).c	\
		$(OPCODE).c	\
		$(SDBM_FILE).c	\
		$(IO).c		\
		$(POSIX).c	\
		$(ATTRS).c	\
		$(THREAD).c	\
		$(RE).c		\
		$(DUMPER).c	\
		$(PEEK).c	\
		$(B).c		\
		$(BYTELOADER).c	\
		$(DPROF).c	\
		$(GLOB).c	\
		$(HOSTNAME).c

EXTENSION_DLL	= 		\
		$(SOCKET_DLL)	\
		$(FCNTL_DLL)	\
		$(OPCODE_DLL)	\
		$(SDBM_FILE_DLL)\
		$(IO_DLL)	\
		$(POSIX_DLL)	\
		$(ATTRS_DLL)	\
		$(DUMPER_DLL)	\
		$(PEEK_DLL)	\
		$(B_DLL)	\
		$(RE_DLL)	\
		$(THREAD_DLL)	\
		$(BYTELOADER_DLL)	\
		$(DPROF_DLL)	\
		$(GLOB_DLL)	\
		$(HOSTNAME_DLL)

EXTENSION_PM	=		\
		$(ERRNO_PM)

CFG_VARS	=					\
		"INST_DRV=$(INST_DRV)"			\
		"INST_TOP=$(INST_TOP)"			\
		"INST_VER=$(INST_VER)"			\
		"INST_ARCH=$(INST_ARCH)"		\
		"archname=$(ARCHNAME)"			\
		"cc=$(CC)"				\
		"ld=$(LINK32)"				\
		"ccflags=$(subst ",\",$(EXTRACFLAGS) $(OPTIMIZE) $(DEFINES) $(BUILDOPT))" \
		"cf_email=$(EMAIL)"	 		\
		"d_crypt=$(D_CRYPT)"			\
		"d_mymalloc=$(PERL_MALLOC)"		\
		"libs=$(LIBFILES)"			\
		"incpath=$(subst ",\",$(CCINCDIR))"			\
		"libperl=$(subst ",\",$(PERLIMPLIBBASE))"		\
		"libpth=$(subst ",\",$(CCLIBDIR);$(EXTRALIBDIRS))"	\
		"libc=$(LIBC)"				\
		"make=$(PLMAKE)"				\
		"usethreads=$(USE_ITHREADS)"		\
		"use5005threads=$(USE_5005THREADS)"	\
		"useithreads=$(USE_ITHREADS)"		\
		"usethreads=$(USE_5005THREADS)"		\
		"usemultiplicity=$(USE_MULTI)"		\
		"use64bitint=$(USE_64_BIT_INT)"		\
		"uselargefiles=$(USE_LARGE_FILES)"	\
		"LINK_FLAGS=$(subst ",\",$(LINK_FLAGS))"\
		"optimize=$(subst ",\",$(OPTIMIZE))"

ICWD = -I..\cpan\Cwd -I..\cpan\Cwd\lib

#
# Top targets
#

.PHONY: all

all : .\config.h $(GLOBEXE) $(MINIMOD) $(CONFIGPM) $(PERLEXE) $(X2P) $(EXTENSION_DLL) $(EXTENSION_PM)
	@echo Everything is up to date. '$(MAKE_BARE) test' to run test suite.

$(DYNALOADER)$(o) : $(DYNALOADER).c $(CORE_H) $(EXTDIR)\DynaLoader\dlutils.c

#----------------------------------------------------------------

$(GLOBEXE) : perlglob.c
	$(LINK32) $(OPTIMIZE) $(BLINK_FLAGS) -mconsole -o $@ perlglob.c $(LIBFILES)

..\config.sh : $(CFGSH_TMPL) $(HAVEMINIPERL) config_sh.PL
	$(MINIPERL) -I..\lib config_sh.PL $(CFG_VARS) $(CFGSH_TMPL) > ..\config.sh

$(CONFIGPM) : $(HAVEMINIPERL) ..\config.sh config_h.PL ..\minimod.pl
	cd .. && miniperl.exe -Ilib configpm
	$(XCOPY) *.h $(COREDIR)\\*.*
	$(XCOPY) ..\\ext\\re\\re.pm $(LIBDIR)\\*.*
	$(RCOPY) include $(COREDIR)\\*.*
	$(XCOPY) ..\\*.h $(COREDIR)\\*.*
	-$(MINIPERL) -I..\lib $(ICWD) config_h.PL "ARCHPREFIX=$(ARCHPREFIX)"

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
	@(echo #define IVdf "ld"&& \
	echo #define UVuf "lu"&& \
	echo #define UVof "lo"&& \
	echo #define UVxf "lx"&& \
	echo #define UVXf "lX"&& \
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

$(CONFIGPM) : $(HAVEMINIPERL) ..\config.sh config_h.PL ..\minimod.pl
	cd .. && miniperl.exe -Ilib configpm
	$(XCOPY) *.h $(COREDIR)\\*.*
	$(XCOPY) ..\\*.inc $(COREDIR)\\*.*
	$(XCOPY) ..\\ext\\re\\re.pm $(LIBDIR)\\*.*
	$(RCOPY) include $(COREDIR)\\*.*
	$(XCOPY) ..\\*.h $(COREDIR)\\*.*
	-$(MINIPERL) -I..\lib $(ICWD) config_h.PL "INST_VER=$(INST_VER)"

$(MINICORE_OBJ) : $(CORE_NOCFG_H)
	$(CC) -c $(CFLAGS) $(MINIBUILDOPT) -DPERL_EXTERNAL_GLOB -DPERL_IS_MINIPERL $(OBJOUT_FLAG)$@ $(PDBOUT) ..\$(*F).c

$(MINIWIN32_OBJ) : $(CORE_NOCFG_H)
	$(CC) -c $(CFLAGS) $(MINIBUILDOPT) -DPERL_IS_MINIPERL $(OBJOUT_FLAG)$@ $(PDBOUT) $(*F).c

# -DPERL_IMPLICIT_SYS needs C++ for perllib.c
# rules wrapped in .IFs break Win9X build (we end up with unbalanced []s unless
# unless the .IF is true), so instead we use a .ELSE with the default.
# This is the only file that depends on perlhost.h, vmem.h, and vdir.h

perllib$(o)	: perllib.c .\perlhost.h .\vdir.h .\vmem.h
ifeq ($(USE_IMP_SYS),define)
	$(CC) -c -I. $(CFLAGS_O) $(CXX_FLAG) $(OBJOUT_FLAG)$@ $(PDBOUT) perllib.c
else
	$(CC) -c -I. $(CFLAGS_O) $(OBJOUT_FLAG)$@ $(PDBOUT) perllib.c
endif

$(MINI_OBJ)	: $(MINIDIR)\.exists $(CORE_NOCFG_H)

$(WIN32_OBJ)	: $(CORE_H)
$(CORE_OBJ)	: $(CORE_H)
$(DLL_OBJ)	: $(CORE_H)
$(X2P_OBJ)	: $(CORE_H)

perldll.def : $(HAVEMINIPERL) $(CONFIGPM) ..\global.sym ..\pp.sym ..\makedef.pl
	$(MINIPERL) -w ..\makedef.pl PLATFORM=win32 $(OPTIMIZE) $(DEFINES) $(BUILDOPT) \
	    CCTYPE=$(CCTYPE) > perldll.def

$(PERLEXPLIB) : $(PERLIMPLIB)

$(PERLIMPLIB) : perldll.def
	$(IMPLIB) -k -d perldll.def -l $(PERLIMPLIB) -e $(PERLEXPLIB)

$(PERLDLL): perldll.def $(PERLEXPLIB) $(PERLDLL_OBJ)
	$(LINK32) -mdll -o $@ $(BLINK_FLAGS) \
	   $(PERLDLL_OBJ) $(LIBFILES) $(PERLEXPLIB)

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

$(X2P) : $(HAVEMINIPERL) $(X2P_OBJ)
	$(MINIPERL) -I..\lib ..\x2p\find2perl.PL
	$(MINIPERL) -I..\lib ..\x2p\s2p.PL
	$(LINK32) -mconsole -o $@ $(BLINK_FLAGS) $(LIBFILES) $(X2P_OBJ)

perlmain.c : runperl.c
	copy runperl.c perlmain.c

perlmain$(o) : runperl.c $(CONFIGPM)
	$(CC) $(subst -DPERLDLL,-UPERLDLL,$(CFLAGS_O)) $(OBJOUT_FLAG)$@ $(PDBOUT) -c runperl.c

perlmainst$(o) : runperl.c $(CONFIGPM)
	$(CC) $(CFLAGS_O) $(OBJOUT_FLAG)$@ $(PDBOUT) -c runperl.c

$(PERLEXE): $(PERLDLL) $(CONFIGPM) $(PERLEXE_OBJ) $(PERLIMPLIB)
	$(LINK32) -mconsole -o $@ $(BLINK_FLAGS)  \
	    $(PERLEXE_OBJ) $(PERLIMPLIB) $(LIBFILES)
	copy $(PERLEXE) $(WPERLEXE)
	$(MINIPERL) -I..\lib bin\exetype.pl $(WPERLEXE) WINDOWS
	copy splittree.pl ..
	$(MINIPERL) -I..\lib ..\splittree.pl "../LIB" $(AUTODIR)

$(DYNALOADER).c: $(HAVEMINIPERL) $(EXTDIR)\DynaLoader\dl_win32.xs $(CONFIGPM)
	if not exist $(AUTODIR) mkdir $(AUTODIR)
	cd $(EXTDIR)\DynaLoader \
		&& ..\$(MINIPERL) -I..\..\lib DynaLoader_pm.PL \
		&& ..\$(MINIPERL) -I..\..\lib XSLoader_pm.PL
	$(XCOPY) $(EXTDIR)\DynaLoader\DynaLoader.pm $(LIBDIR)\$(NULL)
	$(XCOPY) $(EXTDIR)\DynaLoader\XSLoader.pm $(LIBDIR)\$(NULL)
	cd $(EXTDIR)\DynaLoader \
		&& $(XSUBPP) dl_win32.xs > ..\$(DYNALOADER).c

$(EXTDIR)\DynaLoader\dl_win32.xs: dl_win32.xs
	copy dl_win32.xs $(EXTDIR)\DynaLoader\dl_win32.xs

$(HAVEMINIPERL): $(MINI_OBJ)
	$(LINK32) -mconsole -o $(MINIPERL) $(BLINK_FLAGS) $(MINI_OBJ) $(LIBFILES)
	rem . > $@

$(DUMPER_DLL): $(HAVEMINIPERL) $(DUMPER).xs
	cd $(EXTDIR)\Data\Dumper && ..\..\..\miniperl -I..\..\..\lib Makefile.PL INSTALLDIRS=perl && $(PLMAKE)

$(DPROF_DLL): $(HAVEMINIPERL) $(DPROF).xs
	cd $(EXTDIR)\Devel\DProf && ..\..\..\miniperl -I..\..\..\lib Makefile.PL INSTALLDIRS=perl && $(PLMAKE)

$(GLOB_DLL): $(HAVEMINIPERL) $(GLOB).xs
	cd $(EXTDIR)\File\Glob && ..\..\..\miniperl -I..\..\..\lib Makefile.PL INSTALLDIRS=perl && $(PLMAKE)

$(PEEK_DLL): $(HAVEMINIPERL) $(PEEK).xs
	cd $(EXTDIR)\Devel\Peek && ..\..\..\miniperl -I..\..\..\lib Makefile.PL INSTALLDIRS=perl && $(PLMAKE)

$(RE_DLL): $(HAVEMINIPERL) $(RE).xs
	cd $(EXTDIR)\re && ..\..\miniperl -I..\..\lib Makefile.PL INSTALLDIRS=perl && $(PLMAKE)

$(B_DLL): $(HAVEMINIPERL) $(B).xs
	cd $(EXTDIR)\B && ..\..\miniperl -I..\..\lib Makefile.PL INSTALLDIRS=perl && $(PLMAKE)

$(THREAD_DLL): $(HAVEMINIPERL) $(THREAD).xs
	cd $(EXTDIR)\Thread && ..\..\miniperl -I..\..\lib Makefile.PL INSTALLDIRS=perl && $(PLMAKE)

$(ATTRS_DLL): $(HAVEMINIPERL) $(ATTRS).xs
	cd $(EXTDIR)\attrs && ..\..\miniperl -I..\..\lib Makefile.PL INSTALLDIRS=perl && $(PLMAKE)

$(POSIX_DLL): $(HAVEMINIPERL) $(POSIX).xs
	cd $(EXTDIR)\POSIX && ..\..\miniperl -I..\..\lib Makefile.PL INSTALLDIRS=perl && $(PLMAKE)

$(IO_DLL): $(HAVEMINIPERL) $(IO).xs
	cd $(EXTDIR)\IO && ..\..\miniperl -I..\..\lib Makefile.PL INSTALLDIRS=perl && $(PLMAKE)

$(SDBM_FILE_DLL) : $(HAVEMINIPERL) $(SDBM_FILE).xs
	cd $(EXTDIR)\SDBM_File && ..\..\miniperl -I..\..\lib Makefile.PL INSTALLDIRS=perl && $(PLMAKE)

$(FCNTL_DLL): $(HAVEMINIPERL) $(FCNTL).xs
	cd $(EXTDIR)\Fcntl && ..\..\miniperl -I..\..\lib Makefile.PL INSTALLDIRS=perl && $(PLMAKE)

$(OPCODE_DLL): $(HAVEMINIPERL) $(OPCODE).xs
	cd $(EXTDIR)\Opcode && ..\..\miniperl -I..\..\lib Makefile.PL INSTALLDIRS=perl && $(PLMAKE)

$(SOCKET_DLL): $(HAVEMINIPERL) $(SOCKET).xs
	cd $(EXTDIR)\Socket && ..\..\miniperl -I..\..\lib Makefile.PL INSTALLDIRS=perl && $(PLMAKE)

$(HOSTNAME_DLL): $(HAVEMINIPERL) $(HOSTNAME).xs
	cd $(EXTDIR)\Sys\Hostname && ..\..\..\miniperl -I..\..\..\lib Makefile.PL INSTALLDIRS=perl && $(PLMAKE)

$(BYTELOADER_DLL): $(HAVEMINIPERL) $(BYTELOADER).xs
	cd $(EXTDIR)\ByteLoader && ..\..\miniperl -I..\..\lib Makefile.PL INSTALLDIRS=perl && $(PLMAKE)

$(ERRNO_PM): $(HAVEMINIPERL) $(ERRNO)_pm.PL
	cd $(EXTDIR)\Errno && ..\..\miniperl -I..\..\lib Makefile.PL INSTALLDIRS=perl && $(PLMAKE)

#-------------------------------------------------------------------------------

doc: $(PERLEXE)
	$(PERLEXE) -I..\lib ..\installhtml --podroot=.. --htmldir=$(HTMLDIR) \
	    --podpath=pod:lib:utils --htmlroot="file://$(subst :,|,$(INST_HTML))"\
	    --recurse

utils: $(PERLEXE) $(X2P)
	cd ..\utils && $(PLMAKE) PERL=$(MINIPERL)
	copy ..\README.amiga    ..\pod\perlamiga.pod
	copy ..\README.cygwin   ..\pod\perlcygwin.pod
	copy ..\README.dos      ..\pod\perldos.pod
	copy ..\README.hpux     ..\pod\perlhpux.pod
	copy ..\README.machten  ..\pod\perlmachten.pod
	copy ..\README.os2      ..\pod\perlos2.pod
	copy ..\vms\perlvms.pod ..\pod\perlvms.pod
	copy ..\README.win32    ..\pod\perlwin32.pod
	cd ..\pod && $(PLMAKE) -f ..\win32\pod.mak converters
	$(PERLEXE) -I..\lib $(PL2BAT) $(UTILS)

install : all installbare installhtml

installbare : utils
	$(PERLEXE) ..\installperl
	if exist $(WPERLEXE) $(XCOPY) $(WPERLEXE) $(INST_BIN)\$(NULL)
	$(XCOPY) $(GLOBEXE) $(INST_BIN)\$(NULL)
	$(XCOPY) "bin\*.bat" $(INST_SCRIPT)\$(NULL)

installhtml : doc
	$(RCOPY) $(HTMLDIR)\*.* $(INST_HTML)\$(NULL)
MAKEFILE
    if (_ge($version, "5.6.2")) {
        _patch_gnumakefile($version, <<'PATCH');
--- win32/GNUmakefile
+++ win32/GNUmakefile
@@ -794,55 +794,55 @@
 	rem . > $@
 
 $(DUMPER_DLL): $(HAVEMINIPERL) $(DUMPER).xs
-	cd $(EXTDIR)\Data\Dumper && ..\..\..\miniperl -I..\..\..\lib Makefile.PL INSTALLDIRS=perl && $(PLMAKE)
+	cd $(EXTDIR)\Data\Dumper && ..\..\..\miniperl -I..\..\..\lib Makefile.PL INSTALLDIRS=perl PERL_CORE=1 && $(PLMAKE)
 
 $(DPROF_DLL): $(HAVEMINIPERL) $(DPROF).xs
-	cd $(EXTDIR)\Devel\DProf && ..\..\..\miniperl -I..\..\..\lib Makefile.PL INSTALLDIRS=perl && $(PLMAKE)
+	cd $(EXTDIR)\Devel\DProf && ..\..\..\miniperl -I..\..\..\lib Makefile.PL INSTALLDIRS=perl PERL_CORE=1 && $(PLMAKE)
 
 $(GLOB_DLL): $(HAVEMINIPERL) $(GLOB).xs
-	cd $(EXTDIR)\File\Glob && ..\..\..\miniperl -I..\..\..\lib Makefile.PL INSTALLDIRS=perl && $(PLMAKE)
+	cd $(EXTDIR)\File\Glob && ..\..\..\miniperl -I..\..\..\lib Makefile.PL INSTALLDIRS=perl PERL_CORE=1 && $(PLMAKE)
 
 $(PEEK_DLL): $(HAVEMINIPERL) $(PEEK).xs
-	cd $(EXTDIR)\Devel\Peek && ..\..\..\miniperl -I..\..\..\lib Makefile.PL INSTALLDIRS=perl && $(PLMAKE)
+	cd $(EXTDIR)\Devel\Peek && ..\..\..\miniperl -I..\..\..\lib Makefile.PL INSTALLDIRS=perl PERL_CORE=1 && $(PLMAKE)
 
 $(RE_DLL): $(HAVEMINIPERL) $(RE).xs
-	cd $(EXTDIR)\re && ..\..\miniperl -I..\..\lib Makefile.PL INSTALLDIRS=perl && $(PLMAKE)
+	cd $(EXTDIR)\re && ..\..\miniperl -I..\..\lib Makefile.PL INSTALLDIRS=perl PERL_CORE=1 && $(PLMAKE)
 
 $(B_DLL): $(HAVEMINIPERL) $(B).xs
-	cd $(EXTDIR)\B && ..\..\miniperl -I..\..\lib Makefile.PL INSTALLDIRS=perl && $(PLMAKE)
+	cd $(EXTDIR)\B && ..\..\miniperl -I..\..\lib Makefile.PL INSTALLDIRS=perl PERL_CORE=1 && $(PLMAKE)
 
 $(THREAD_DLL): $(HAVEMINIPERL) $(THREAD).xs
-	cd $(EXTDIR)\Thread && ..\..\miniperl -I..\..\lib Makefile.PL INSTALLDIRS=perl && $(PLMAKE)
+	cd $(EXTDIR)\Thread && ..\..\miniperl -I..\..\lib Makefile.PL INSTALLDIRS=perl PERL_CORE=1 && $(PLMAKE)
 
 $(ATTRS_DLL): $(HAVEMINIPERL) $(ATTRS).xs
-	cd $(EXTDIR)\attrs && ..\..\miniperl -I..\..\lib Makefile.PL INSTALLDIRS=perl && $(PLMAKE)
+	cd $(EXTDIR)\attrs && ..\..\miniperl -I..\..\lib Makefile.PL INSTALLDIRS=perl PERL_CORE=1 && $(PLMAKE)
 
 $(POSIX_DLL): $(HAVEMINIPERL) $(POSIX).xs
-	cd $(EXTDIR)\POSIX && ..\..\miniperl -I..\..\lib Makefile.PL INSTALLDIRS=perl && $(PLMAKE)
+	cd $(EXTDIR)\POSIX && ..\..\miniperl -I..\..\lib Makefile.PL INSTALLDIRS=perl PERL_CORE=1 && $(PLMAKE)
 
 $(IO_DLL): $(HAVEMINIPERL) $(IO).xs
-	cd $(EXTDIR)\IO && ..\..\miniperl -I..\..\lib Makefile.PL INSTALLDIRS=perl && $(PLMAKE)
+	cd $(EXTDIR)\IO && ..\..\miniperl -I..\..\lib Makefile.PL INSTALLDIRS=perl PERL_CORE=1 && $(PLMAKE)
 
 $(SDBM_FILE_DLL) : $(HAVEMINIPERL) $(SDBM_FILE).xs
-	cd $(EXTDIR)\SDBM_File && ..\..\miniperl -I..\..\lib Makefile.PL INSTALLDIRS=perl && $(PLMAKE)
+	cd $(EXTDIR)\SDBM_File && ..\..\miniperl -I..\..\lib Makefile.PL INSTALLDIRS=perl PERL_CORE=1 && $(PLMAKE)
 
 $(FCNTL_DLL): $(HAVEMINIPERL) $(FCNTL).xs
-	cd $(EXTDIR)\Fcntl && ..\..\miniperl -I..\..\lib Makefile.PL INSTALLDIRS=perl && $(PLMAKE)
+	cd $(EXTDIR)\Fcntl && ..\..\miniperl -I..\..\lib Makefile.PL INSTALLDIRS=perl PERL_CORE=1 && $(PLMAKE)
 
 $(OPCODE_DLL): $(HAVEMINIPERL) $(OPCODE).xs
-	cd $(EXTDIR)\Opcode && ..\..\miniperl -I..\..\lib Makefile.PL INSTALLDIRS=perl && $(PLMAKE)
+	cd $(EXTDIR)\Opcode && ..\..\miniperl -I..\..\lib Makefile.PL INSTALLDIRS=perl PERL_CORE=1 && $(PLMAKE)
 
 $(SOCKET_DLL): $(HAVEMINIPERL) $(SOCKET).xs
-	cd $(EXTDIR)\Socket && ..\..\miniperl -I..\..\lib Makefile.PL INSTALLDIRS=perl && $(PLMAKE)
+	cd $(EXTDIR)\Socket && ..\..\miniperl -I..\..\lib Makefile.PL INSTALLDIRS=perl PERL_CORE=1 && $(PLMAKE)
 
 $(HOSTNAME_DLL): $(HAVEMINIPERL) $(HOSTNAME).xs
-	cd $(EXTDIR)\Sys\Hostname && ..\..\..\miniperl -I..\..\..\lib Makefile.PL INSTALLDIRS=perl && $(PLMAKE)
+	cd $(EXTDIR)\Sys\Hostname && ..\..\..\miniperl -I..\..\..\lib Makefile.PL INSTALLDIRS=perl PERL_CORE=1 && $(PLMAKE)
 
 $(BYTELOADER_DLL): $(HAVEMINIPERL) $(BYTELOADER).xs
-	cd $(EXTDIR)\ByteLoader && ..\..\miniperl -I..\..\lib Makefile.PL INSTALLDIRS=perl && $(PLMAKE)
+	cd $(EXTDIR)\ByteLoader && ..\..\miniperl -I..\..\lib Makefile.PL INSTALLDIRS=perl PERL_CORE=1 && $(PLMAKE)
 
 $(ERRNO_PM): $(HAVEMINIPERL) $(ERRNO)_pm.PL
-	cd $(EXTDIR)\Errno && ..\..\miniperl -I..\..\lib Makefile.PL INSTALLDIRS=perl && $(PLMAKE)
+	cd $(EXTDIR)\Errno && ..\..\miniperl -I..\..\lib Makefile.PL INSTALLDIRS=perl PERL_CORE=1 && $(PLMAKE)
 
 #-------------------------------------------------------------------------------
 
PATCH
    }
}

1;
