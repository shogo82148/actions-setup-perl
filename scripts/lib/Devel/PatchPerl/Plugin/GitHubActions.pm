package Devel::PatchPerl::Plugin::GitHubActions;

use utf8;
use strict;
use warnings;
use 5.026001;
use File::pushd qw[pushd];
use File::Basename;
use File::Slurp qw/read_file/;
use File::Spec;
use JSON qw/encode_json decode_json/;
use Devel::PatchPerl;
use Try::Tiny;

use Devel::PatchPerl::Plugin::MinGWGNUmakefile;
use Devel::PatchPerl::Plugin::MinGW;

# copy utility functions from Devel::PatchPerl
*_is = *Devel::PatchPerl::_is;
*_patch = *Devel::PatchPerl::_patch;

my @patch = (
    {
        perl => [
            qr/^5\.8\.[012]$/,
            qr/^5\.6\./,
        ],
        subs => [
            [ \&_patch_unixish ],
        ],
    },
    {
        perl => [
            qr/^5\.8\.[01]$/,
            qr/^5\.6\./,
        ],
        subs => [
            [ \&_patch_configure ],
        ],
    },
);

sub patchperl {
    my ($class, %args) = @_;
    my $vers = $args{version};
    my $source = $args{source};
    my $dir = pushd( $source );

    if ($^O eq 'MSWin32') {
        Devel::PatchPerl::Plugin::MinGWGNUmakefile->patchperl(%args);
        Devel::PatchPerl::Plugin::MinGW->patchperl(%args);
    }

    # copy from https://github.com/bingos/devel-patchperl/blob/acdcf1d67ae426367f42ca763b9ba6b92dd90925/lib/Devel/PatchPerl.pm#L301-L307
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

    _patch_patchlevel();
}

# adapted from patchlevel.h for use with perls that predate it
sub _patch_patchlevel {
    my $package_json = File::Spec->catfile(dirname(__FILE__), ("..") x 5, "package.json");
    my $package = decode_json(read_file($package_json));
    my $dpv = $package->{version};
    open my $plin, "patchlevel.h" or die "Couldn't open patchlevel.h : $!";
    open my $plout, ">patchlevel.new" or die "Couldn't write on patchlevel.new : $!";
    my $seen=0;
    while (<$plin>) {
        if (/\t,NULL/ and $seen) {
            print {$plout} qq{\t,"shogo82148/actions-setup-perl $dpv"\n};
        }
        $seen++ if /local_patches\[\]/;
        print {$plout} $_;
    }
    close $plout or die "Couldn't close filehandle writing to patchlevel.new : $!";
    close $plin or die "Couldn't close filehandle reading from patchlevel.h : $!";
    unlink "patchlevel.bak" or warn "Couldn't unlink patchlevel.bak : $!"
        if -e "patchlevel.bak";
    rename "patchlevel.h", "patchlevel.bak" or
        die "Couldn't rename patchlevel.h to patchlevel.bak : $!";
    rename "patchlevel.new", "patchlevel.h" or
        die "Couldn't rename patchlevel.new to patchlevel.h : $!";
}

# it is same as ge operator of strings but it assumes the strings are versions
sub _ge {
    my ($v1, $v2) = @_;
    return version->parse("v$v1") >= version->parse("v$v2");
}

sub _patch_unixish {
    my $version = shift;
    if (_ge($version, "5.8.0")) {
        _patch(<<'PATCH');
--- unixish.h
+++ unixish.h
@@ -103,9 +103,7 @@
  */
 /* #define ALTERNATE_SHEBANG "#!" / **/
 
-#if !defined(NSIG) || defined(M_UNIX) || defined(M_XENIX) || defined(__NetBSD__) || defined(__FreeBSD__) || defined(__OpenBSD__)
 # include <signal.h>
-#endif
 
 #ifndef SIGABRT
 #    define SIGABRT SIGILL
PATCH
        return;
    }

    _patch(<<'PATCH');
--- unixish.h
+++ unixish.h
@@ -89,9 +89,7 @@
  */
 /* #define ALTERNATE_SHEBANG "#!" / **/
 
-#if !defined(NSIG) || defined(M_UNIX) || defined(M_XENIX) || defined(__NetBSD__)
 # include <signal.h>
-#endif
 
 #ifndef SIGABRT
 #    define SIGABRT SIGILL
PATCH
}

sub _patch_configure {
    my $version = shift;
    if (_ge($version, "5.8.1")) {
        _patch(<<'PATCH');
    _patch(<<'PATCH');
--- Configure
+++ Configure
@@ -3791,7 +3856,7 @@ int main() {
        printf("%s\n", "1");
 #endif
 #endif
-       exit(0);
+       return(0);
 }
 EOM
 if $cc -o try $ccflags $ldflags try.c; then
PATCH
        return;
    }
    _patch(<<'PATCH');
--- Configure
+++ Configure
@@ -3791,7 +3791,7 @@ int main() {
 	printf("%s\n", "1");
 #endif
 #endif
-	exit(0);
+	return(0);
 }
 EOM
 if $cc -o try $ccflags $ldflags try.c; then
@@ -3852,14 +3852,17 @@ case "$ccname" in
 '') ccname="$cc" ;;
 esac
 
-# gcc 3.1 complains about adding -Idirectories that it already knows about,
+# gcc 3.* complain about adding -Idirectories that they already know about,
 # so we will take those off from locincpth.
 case "$gccversion" in
 3*)
     echo "main(){}">try.c
-    for incdir in `$cc -v -c try.c 2>&1 | \
-       sed '1,/^#include <\.\.\.>/d;/^End of search list/,$d;s/^ //'` ; do
-       locincpth=`echo $locincpth | sed s!$incdir!!`
+    for incdir in $locincpth; do
+       warn=`$cc $ccflags -I$incdir -c try.c 2>&1 | \
+	     grep '^c[cp]p*[01]: warning: changing search order '`
+       if test "X$warn" != X; then
+	   locincpth=`echo " $locincpth " | sed "s! $incdir ! !"`
+       fi
     done
     $rm -f try try.*
 esac
@@ -4797,7 +4800,7 @@ echo " "
 echo "Checking your choice of C compiler and flags for coherency..." >&4
 $cat > try.c <<'EOF'
 #include <stdio.h>
-int main() { printf("Ok\n"); exit(0); }
+int main() { printf("Ok\n"); return(0); }
 EOF
 set X $cc -o try $optimize $ccflags $ldflags try.c $libs
 shift
@@ -5362,2052 +5365,1859 @@ case "$use64bitall" in
 	;;
 esac
 
+case "$d_quad:$use64bitint" in
+$undef:$define)
+	cat >&4 <<EOF
+
+*** You have chosen to use 64-bit integers,
+*** but none cannot be found.
+*** Please rerun Configure without -Duse64bitint and/or -Dusemorebits.
+*** Cannot continue, aborting.
+
+EOF
+	exit 1
+	;;
+esac
+
+: check for length of double
 echo " "
-echo "Checking for GNU C Library..." >&4
-cat >try.c <<'EOCP'
-/* Find out version of GNU C library.  __GLIBC__ and __GLIBC_MINOR__
-   alone are insufficient to distinguish different versions, such as
-   2.0.6 and 2.0.7.  The function gnu_get_libc_version() appeared in
-   libc version 2.1.0.      A. Dougherty,  June 3, 2002.
-*/
+case "$doublesize" in
+'')
+	echo "Checking to see how big your double precision numbers are..." >&4
+	$cat >try.c <<EOCP
 #include <stdio.h>
-int main(void)
-{
-#ifdef __GLIBC__
-#   ifdef __GLIBC_MINOR__
-#       if __GLIBC__ >= 2 && __GLIBC_MINOR__ >= 1
-#           include <gnu/libc-version.h>
-	    printf("%s\n",  gnu_get_libc_version());
-#       else
-	    printf("%d.%d\n",  __GLIBC__, __GLIBC_MINOR__);
-#       endif
-#   else
-	printf("%d\n",  __GLIBC__);
-#   endif
-    return 0;
-#else
-    return 1;
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
 #endif
+int main()
+{
+    printf("%d\n", (int)sizeof(double));
+    exit(0);
 }
 EOCP
+	set try
+	if eval $compile_ok; then
+		doublesize=`$run ./try`
+		echo "Your double is $doublesize bytes long."
+	else
+		dflt='8'
+		echo "(I can't seem to compile the test program.  Guessing...)"
+		rp="What is the size of a double precision number (in bytes)?"
+		. ./myread
+		doublesize="$ans"
+	fi
+	;;
+esac
+$rm -f try.c try
+
+: check for long doubles
+echo " "
+echo "Checking to see if you have long double..." >&4
+echo 'int main() { long double x = 7.0; }' > try.c
 set try
-if eval $compile_ok && $run ./try > glibc.ver; then
+if eval $compile; then
 	val="$define"
-	gnulibc_version=`$cat glibc.ver`
-	echo "You are using the GNU C Library version $gnulibc_version"
+	echo "You have long double."
 else
 	val="$undef"
-	gnulibc_version=''
-	echo "You are not using the GNU C Library"
+	echo "You do not have long double."
 fi
-$rm -f try try.* glibc.ver
-set d_gnulibc
+$rm try.*
+set d_longdbl
 eval $setvar
 
-: see if nm is to be used to determine whether a symbol is defined or not
-case "$usenm" in
-'')
-	dflt=''
-	case "$d_gnulibc" in
-	"$define")
+: check for length of long double
+case "${d_longdbl}${longdblsize}" in
+$define)
+	echo " "
+	echo "Checking to see how big your long doubles are..." >&4
+	$cat >try.c <<'EOCP'
+#include <stdio.h>
+int main()
+{
+	printf("%d\n", sizeof(long double));
+}
+EOCP
+	set try
+	set try
+	if eval $compile; then
+		longdblsize=`$run ./try`
+		echo "Your long doubles are $longdblsize bytes long."
+	else
+		dflt='8'
 		echo " "
-		echo "nm probably won't work on the GNU C Library." >&4
-		dflt=n
-		;;
-	esac
-	case "$dflt" in
-	'') 
-		if $test "$osname" = aix -a ! -f /lib/syscalls.exp; then
-			echo " "
-			echo "Whoops!  This is an AIX system without /lib/syscalls.exp!" >&4
-			echo "'nm' won't be sufficient on this sytem." >&4
-			dflt=n
-		fi
-		;;
-	esac
-	case "$dflt" in
-	'') dflt=`$egrep 'inlibc|csym' $rsrc/Configure | wc -l 2>/dev/null`
-		if $test $dflt -gt 20; then
-			dflt=y
-		else
-			dflt=n
-		fi
-		;;
-	esac
-	;;
-*)
-	case "$usenm" in
-	true|$define) dflt=y;;
-	*) dflt=n;;
-	esac
+		echo "(I can't seem to compile the test program.  Guessing...)" >&4
+		rp="What is the size of a long double (in bytes)?"
+		. ./myread
+		longdblsize="$ans"
+	fi
+	if $test "X$doublesize" = "X$longdblsize"; then
+		echo "That isn't any different from an ordinary double."
+		echo "I'll keep your setting anyway, but you may see some"
+		echo "harmless compilation warnings."
+	fi	
 	;;
 esac
-$cat <<EOM
-
-I can use $nm to extract the symbols from your C libraries. This
-is a time consuming task which may generate huge output on the disk (up
-to 3 megabytes) but that should make the symbols extraction faster. The
-alternative is to skip the 'nm' extraction part and to compile a small
-test program instead to determine whether each symbol is present. If
-you have a fast C compiler and/or if your 'nm' output cannot be parsed,
-this may be the best solution.
-
-You probably shouldn't let me use 'nm' if you are using the GNU C Library.
+$rm -f try.* try
 
-EOM
-rp="Shall I use $nm to extract C symbols from the libraries?"
-. ./myread
-case "$ans" in
-[Nn]*) usenm=false;;
-*) usenm=true;;
+: determine the architecture name
+echo " "
+if xxx=`./loc arch blurfl $pth`; $test -f "$xxx"; then
+	tarch=`arch`"-$osname"
+elif xxx=`./loc uname blurfl $pth`; $test -f "$xxx" ; then
+	if uname -m > tmparch 2>&1 ; then
+		tarch=`$sed -e 's/ *$//' -e 's/ /_/g' \
+			-e 's/$/'"-$osname/" tmparch`
+	else
+		tarch="$osname"
+	fi
+	$rm -f tmparch
+else
+	tarch="$osname"
+fi
+case "$myarchname" in
+''|"$tarch") ;;
+*)
+	echo "(Your architecture name used to be $myarchname.)"
+	archname=''
+	;;
 esac
-
-runnm=$usenm
-case "$reuseval" in
-true) runnm=false;;
+case "$targetarch" in
+'') ;;
+*)  archname=`echo $targetarch|sed 's,^[^-]*-,,'` ;;
 esac
-
-: nm options which may be necessary
-case "$nm_opt" in
-'') if $test -f /mach_boot; then
-		nm_opt=''	# Mach
-	elif $test -d /usr/ccs/lib; then
-		nm_opt='-p'	# Solaris (and SunOS?)
-	elif $test -f /dgux; then
-		nm_opt='-p'	# DG-UX
-	elif $test -f /lib64/rld; then
-		nm_opt='-p'	# 64-bit Irix
-	else
-		nm_opt=''
-	fi;;
+myarchname="$tarch"
+case "$archname" in
+'') dflt="$tarch";;
+*) dflt="$archname";;
 esac
-
-: nm options which may be necessary for shared libraries but illegal
-: for archive libraries.  Thank you, Linux.
-case "$nm_so_opt" in
-'')	case "$myuname" in
-	*linux*)
-		if $nm --help | $grep 'dynamic' > /dev/null 2>&1; then
-			nm_so_opt='--dynamic'
-		fi
-		;;
-	esac
+rp='What is your architecture name'
+. ./myread
+archname="$ans"
+case "$usethreads" in
+$define)
+	echo "Threads selected." >&4
+	case "$archname" in
+        *-thread*) echo "...and architecture name already has -thread." >&4
+                ;;
+        *)      archname="$archname-thread"
+                echo "...setting architecture name to $archname." >&4
+                ;;
+        esac
 	;;
 esac
-
-case "$runnm" in
-true)
-: get list of predefined functions in a handy place
-echo " "
-case "$libc" in
-'') libc=unknown
-	case "$libs" in
-	*-lc_s*) libc=`./loc libc_s$_a $libc $libpth`
-	esac
+case "$usemultiplicity" in
+$define)
+	echo "Multiplicity selected." >&4
+	case "$archname" in
+        *-multi*) echo "...and architecture name already has -multi." >&4
+                ;;
+        *)      archname="$archname-multi"
+                echo "...setting architecture name to $archname." >&4
+                ;;
+        esac
 	;;
 esac
-case "$libs" in
-'') ;;
-*)  for thislib in $libs; do
-	case "$thislib" in
-	-lc|-lc_s)
-		: Handle C library specially below.
+case "$use64bitint$use64bitall" in
+*"$define"*)
+	case "$archname64" in
+	'')
+		echo "This architecture is naturally 64-bit, not changing architecture name." >&4
 		;;
-	-l*)
-		thislib=`echo $thislib | $sed -e 's/^-l//'`
-		if try=`./loc lib$thislib.$so.'*' X $libpth`; $test -f "$try"; then
-			:
-		elif try=`./loc lib$thislib.$so X $libpth`; $test -f "$try"; then
-			:
-		elif try=`./loc lib$thislib$_a X $libpth`; $test -f "$try"; then
-			:
-		elif try=`./loc $thislib$_a X $libpth`; $test -f "$try"; then
-			:
-		elif try=`./loc lib$thislib X $libpth`; $test -f "$try"; then
-			:
-		elif try=`./loc $thislib X $libpth`; $test -f "$try"; then
-			:
-		elif try=`./loc Slib$thislib$_a X $xlibpth`; $test -f "$try"; then
-			:
-		else
-			try=''
-		fi
-		libnames="$libnames $try"
+	*)
+		case "$use64bitint" in
+		"$define") echo "64 bit integers selected." >&4 ;;
+		esac
+		case "$use64bitall" in
+		"$define") echo "Maximal 64 bitness selected." >&4 ;;
+		esac
+		case "$archname" in
+	        *-$archname64*) echo "...and architecture name already has $archname64." >&4
+	                ;;
+	        *)      archname="$archname-$archname64"
+	                echo "...setting architecture name to $archname." >&4
+	                ;;
+	        esac
+		;;
+	esac
+esac
+case "$uselongdouble" in
+$define)
+	echo "Long doubles selected." >&4
+	case "$longdblsize" in
+	$doublesize)
+		echo "...but long doubles are equal to doubles, not changing architecture name." >&4
+		;;
+	*)
+		case "$archname" in
+	        *-ld*) echo "...and architecture name already has -ld." >&4
+	                ;;
+	        *)      archname="$archname-ld"
+	                echo "...setting architecture name to $archname." >&4
+        	        ;;
+	        esac
 		;;
-	*) libnames="$libnames $thislib" ;;
 	esac
-	done
 	;;
 esac
-xxx=normal
-case "$libc" in
-unknown)
-	set /lib/libc.$so
-	for xxx in $libpth; do
-		$test -r $1 || set $xxx/libc.$so
-		: The messy sed command sorts on library version numbers.
-		$test -r $1 || \
-			set `echo blurfl; echo $xxx/libc.$so.[0-9]* | \
-			tr ' ' $trnl | egrep -v '\.[A-Za-z]*$' | $sed -e '
-				h
-				s/[0-9][0-9]*/0000&/g
-				s/0*\([0-9][0-9][0-9][0-9][0-9]\)/\1/g
-				G
-				s/\n/ /' | \
-			 $sort | $sed -e 's/^.* //'`
-		eval set \$$#
-	done
-	$test -r $1 || set /usr/ccs/lib/libc.$so
-	$test -r $1 || set /lib/libsys_s$_a
+case "$useperlio" in
+$define)
+	echo "Perlio selected." >&4
 	;;
 *)
-	set blurfl
+	echo "Perlio not selected, using stdio." >&4
+	case "$archname" in
+        *-stdio*) echo "...and architecture name already has -stdio." >&4
+                ;;
+        *)      archname="$archname-stdio"
+                echo "...setting architecture name to $archname." >&4
+                ;;
+        esac
 	;;
 esac
-if $test -r "$1"; then
-	echo "Your (shared) C library seems to be in $1."
-	libc="$1"
-elif $test -r /lib/libc && $test -r /lib/clib; then
-	echo "Your C library seems to be in both /lib/clib and /lib/libc."
-	xxx=apollo
-	libc='/lib/clib /lib/libc'
-	if $test -r /lib/syslib; then
-		echo "(Your math library is in /lib/syslib.)"
-		libc="$libc /lib/syslib"
-	fi
-elif $test -r "$libc" || (test -h "$libc") >/dev/null 2>&1; then
-	echo "Your C library seems to be in $libc, as you said before."
-elif $test -r $incpath/usr/lib/libc$_a; then
-	libc=$incpath/usr/lib/libc$_a;
-	echo "Your C library seems to be in $libc.  That's fine."
-elif $test -r /lib/libc$_a; then
-	libc=/lib/libc$_a;
-	echo "Your C library seems to be in $libc.  You're normal."
-else
-	if tans=`./loc libc$_a blurfl/dyick $libpth`; $test -r "$tans"; then
-		:
-	elif tans=`./loc libc blurfl/dyick $libpth`; $test -r "$tans"; then
-		libnames="$libnames "`./loc clib blurfl/dyick $libpth`
-	elif tans=`./loc clib blurfl/dyick $libpth`; $test -r "$tans"; then
-		:
-	elif tans=`./loc Slibc$_a blurfl/dyick $xlibpth`; $test -r "$tans"; then
-		:
-	elif tans=`./loc Mlibc$_a blurfl/dyick $xlibpth`; $test -r "$tans"; then
-		:
-	else
-		tans=`./loc Llibc$_a blurfl/dyick $xlibpth`
-	fi
-	if $test -r "$tans"; then
-		echo "Your C library seems to be in $tans, of all places."
-		libc=$tans
+
+: determine root of directory hierarchy where package will be installed.
+case "$prefix" in
+'')
+	dflt=`./loc . /usr/local /usr/local /local /opt /usr`
+	;;
+*)
+	dflt="$prefix"
+	;;
+esac
+$cat <<EOM
+
+By default, $package will be installed in $dflt/bin, manual pages
+under $dflt/man, etc..., i.e. with $dflt as prefix for all
+installation directories. Typically this is something like /usr/local.
+If you wish to have binaries under /usr/bin but other parts of the
+installation under /usr/local, that's ok: you will be prompted
+separately for each of the installation directories, the prefix being
+only used to set the defaults.
+
+EOM
+fn=d~
+rp='Installation prefix to use?'
+. ./getfile
+oldprefix=''
+case "$prefix" in
+'') ;;
+*)
+	case "$ans" in
+	"$prefix") ;;
+	*) oldprefix="$prefix";;
+	esac
+	;;
+esac
+prefix="$ans"
+prefixexp="$ansexp"
+
+case "$afsroot" in
+'')	afsroot=/afs ;;
+*)	afsroot=$afsroot ;;
+esac
+
+: is AFS running?
+echo " "
+case "$afs" in
+$define|true)	afs=true ;;
+$undef|false)	afs=false ;;
+*)	if test -d $afsroot; then
+		afs=true
 	else
-		libc='blurfl'
+		afs=false
 	fi
+	;;
+esac
+if $afs; then
+	echo "AFS may be running... I'll be extra cautious then..." >&4
+else
+	echo "AFS does not seem to be running..." >&4
 fi
-if $test $xxx = apollo -o -r "$libc" || (test -h "$libc") >/dev/null 2>&1; then
-	dflt="$libc"
-	cat <<EOM
 
-If the guess above is wrong (which it might be if you're using a strange
-compiler, or your machine supports multiple models), you can override it here.
+: determine installation prefix for where package is to be installed.
+if $afs; then 
+$cat <<EOM
 
-EOM
-else
-	dflt=''
-	echo $libpth | $tr ' ' $trnl | $sort | $uniq > libpath
-	cat >&4 <<EOM
-I can't seem to find your C library.  I've looked in the following places:
+Since you are running AFS, I need to distinguish the directory in which
+files will reside from the directory in which they are installed (and from
+which they are presumably copied to the former directory by occult means).
 
 EOM
-	$sed 's/^/	/' libpath
-	cat <<EOM
+	case "$installprefix" in
+	'') dflt=`echo $prefix | sed 's#^/afs/#/afs/.#'`;;
+	*) dflt="$installprefix";;
+	esac
+else
+$cat <<EOM
 
-None of these seems to contain your C library. I need to get its name...
+In some special cases, particularly when building $package for distribution,
+it is convenient to distinguish between the directory in which files should 
+be installed from the directory ($prefix) in which they 
+will eventually reside.  For most users, these two directories are the same.
 
 EOM
+	case "$installprefix" in
+	'') dflt=$prefix ;;
+	*) dflt=$installprefix;;
+	esac
 fi
-fn=f
-rp='Where is your C library?'
+fn=d~
+rp='What installation prefix should I use for installing files?'
 . ./getfile
-libc="$ans"
+installprefix="$ans"
+installprefixexp="$ansexp"
 
-echo " "
-echo $libc $libnames | $tr ' ' $trnl | $sort | $uniq > libnames
-set X `cat libnames`
-shift
-xxx=files
-case $# in 1) xxx=file; esac
-echo "Extracting names from the following $xxx for later perusal:" >&4
-echo " "
-$sed 's/^/	/' libnames >&4
-echo " "
-$echo $n "This may take a while...$c" >&4
+: set the prefixit variable, to compute a suitable default value
+prefixit='case "$3" in
+""|none)
+	case "$oldprefix" in
+	"") eval "$1=\"\$$2\"";;
+	*)
+		case "$3" in
+		"") eval "$1=";;
+		none)
+			eval "tp=\"\$$2\"";
+			case "$tp" in
+			""|" ") eval "$1=\"\$$2\"";;
+			*) eval "$1=";;
+			esac;;
+		esac;;
+	esac;;
+*)
+	eval "tp=\"$oldprefix-\$$2-\""; eval "tp=\"$tp\"";
+	case "$tp" in
+	--|/*--|\~*--) eval "$1=\"$prefix/$3\"";;
+	/*-$oldprefix/*|\~*-$oldprefix/*)
+		eval "$1=\`echo \$$2 | sed \"s,^$oldprefix,$prefix,\"\`";;
+	*) eval "$1=\"\$$2\"";;
+	esac;;
+esac'
 
-for file in $*; do
-	case $file in
-	*$so*) $nm $nm_so_opt $nm_opt $file 2>/dev/null;;
-	*) $nm $nm_opt $file 2>/dev/null;;
-	esac
-done >libc.tmp
-
-$echo $n ".$c"
-$grep fprintf libc.tmp > libc.ptf
-xscan='eval "<libc.ptf $com >libc.list"; $echo $n ".$c" >&4'
-xrun='eval "<libc.tmp $com >libc.list"; echo "done." >&4'
-xxx='[ADTSIW]'
-if com="$sed -n -e 's/__IO//' -e 's/^.* $xxx  *_[_.]*//p' -e 's/^.* $xxx  *//p'";\
-	eval $xscan;\
-	$contains '^fprintf$' libc.list >/dev/null 2>&1; then
-		eval $xrun
-elif com="$sed -n -e 's/^__*//' -e 's/^\([a-zA-Z_0-9$]*\).*xtern.*/\1/p'";\
-	eval $xscan;\
-	$contains '^fprintf$' libc.list >/dev/null 2>&1; then
-		eval $xrun
-elif com="$sed -n -e '/|UNDEF/d' -e '/FUNC..GL/s/^.*|__*//p'";\
-	eval $xscan;\
-	$contains '^fprintf$' libc.list >/dev/null 2>&1; then
-		eval $xrun
-elif com="$sed -n -e 's/^.* D __*//p' -e 's/^.* D //p'";\
-	eval $xscan;\
-	$contains '^fprintf$' libc.list >/dev/null 2>&1; then
-		eval $xrun
-elif com="$sed -n -e 's/^_//' -e 's/^\([a-zA-Z_0-9]*\).*xtern.*text.*/\1/p'";\
-	eval $xscan;\
-	$contains '^fprintf$' libc.list >/dev/null 2>&1; then
-		eval $xrun
-elif com="$sed -n -e 's/^.*|FUNC |GLOB .*|//p'";\
-	eval $xscan;\
-	$contains '^fprintf$' libc.list >/dev/null 2>&1; then
-		eval $xrun
-elif com="$grep '|' | $sed -n -e '/|COMMON/d' -e '/|DATA/d' \
-				-e '/ file/d' -e 's/^\([^ 	]*\).*/\1/p'";\
-	eval $xscan;\
-	$contains '^fprintf$' libc.list >/dev/null 2>&1; then
-		eval $xrun
-elif com="$sed -n -e 's/^.*|FUNC |GLOB .*|//p' -e 's/^.*|FUNC |WEAK .*|//p'";\
-	eval $xscan;\
-	$contains '^fprintf$' libc.list >/dev/null 2>&1; then
-		eval $xrun
-elif com="$sed -n -e 's/^__//' -e '/|Undef/d' -e '/|Proc/s/ .*//p'";\
-	eval $xscan;\
-	$contains '^fprintf$' libc.list >/dev/null 2>&1; then
-		eval $xrun
-elif com="$sed -n -e 's/^.*|Proc .*|Text *| *//p'";\
-	eval $xscan;\
-	$contains '^fprintf$' libc.list >/dev/null 2>&1; then
-		eval $xrun
-elif com="$sed -n -e '/Def. Text/s/.* \([^ ]*\)\$/\1/p'";\
-	eval $xscan;\
-	$contains '^fprintf$' libc.list >/dev/null 2>&1; then
-		eval $xrun
-elif com="$sed -n -e 's/^[-0-9a-f ]*_\(.*\)=.*/\1/p'";\
-	eval $xscan;\
-	$contains '^fprintf$' libc.list >/dev/null 2>&1; then
-		eval $xrun
-elif com="$sed -n -e 's/.*\.text n\ \ \ \.//p'";\
-	eval $xscan;\
-	$contains '^fprintf$' libc.list >/dev/null 2>&1; then
-		eval $xrun
-elif com="sed -n -e 's/^__.*//' -e 's/[       ]*D[    ]*[0-9]*.*//p'";\
-	eval $xscan;\
-	$contains '^fprintf$' libc.list >/dev/null 2>&1; then
-		eval $xrun
+: get the patchlevel
+echo " "
+echo "Getting the current patchlevel..." >&4
+if $test -r $rsrc/patchlevel.h;then
+	revision=`awk '/define[ 	]+PERL_REVISION/ {print $3}' $rsrc/patchlevel.h`
+	patchlevel=`awk '/define[ 	]+PERL_VERSION/ {print $3}' $rsrc/patchlevel.h`
+	subversion=`awk '/define[ 	]+PERL_SUBVERSION/ {print $3}' $rsrc/patchlevel.h`
+	api_revision=`awk '/define[ 	]+PERL_API_REVISION/ {print $3}' $rsrc/patchlevel.h`
+	api_version=`awk '/define[ 	]+PERL_API_VERSION/ {print $3}' $rsrc/patchlevel.h`
+	api_subversion=`awk '/define[ 	]+PERL_API_SUBVERSION/ {print $3}' $rsrc/patchlevel.h`
+       perl_patchlevel=`grep ',"DEVEL[0-9][0-9]*"' $rsrc/patchlevel.h|sed 's/[^0-9]//g'`
 else
-	$nm -p $* 2>/dev/null >libc.tmp
-	$grep fprintf libc.tmp > libc.ptf
-	if com="$sed -n -e 's/^.* [ADTSIW]  *_[_.]*//p' -e 's/^.* [ADTSIW] //p'";\
-		eval $xscan; $contains '^fprintf$' libc.list >/dev/null 2>&1
-	then
-		nm_opt='-p'
-		eval $xrun
-	else
-		echo " "
-		echo "$nm didn't seem to work right. Trying $ar instead..." >&4
-		com=''
-		if $ar t $libc > libc.tmp && $contains '^fprintf$' libc.tmp >/dev/null 2>&1; then
-			for thisname in $libnames $libc; do
-				$ar t $thisname >>libc.tmp
-			done
-			$sed -e "s/\\$_o\$//" < libc.tmp > libc.list
-			echo "Ok." >&4
-		elif test "X$osname" = "Xos2" && $ar tv $libc > libc.tmp; then
-			# Repeat libc to extract forwarders to DLL entries too
-			for thisname in $libnames $libc; do
-				$ar tv $thisname >>libc.tmp
-				# Revision 50 of EMX has bug in $ar.
-				# it will not extract forwarders to DLL entries
-				# Use emximp which will extract exactly them.
-				emximp -o tmp.imp $thisname \
-				    2>/dev/null && \
-				    $sed -e 's/^\([_a-zA-Z0-9]*\) .*$/\1/p' \
-				    < tmp.imp >>libc.tmp
-				$rm tmp.imp
-			done
-			$sed -e "s/\\$_o\$//" -e 's/^ \+//' < libc.tmp > libc.list
-			echo "Ok." >&4
-		else
-			echo "$ar didn't seem to work right." >&4
-			echo "Maybe this is a Cray...trying bld instead..." >&4
-			if bld t $libc | $sed -e 's/.*\///' -e "s/\\$_o:.*\$//" > libc.list
-			then
-				for thisname in $libnames; do
-					bld t $libnames | \
-					$sed -e 's/.*\///' -e "s/\\$_o:.*\$//" >>libc.list
-					$ar t $thisname >>libc.tmp
-				done
-				echo "Ok." >&4
-			else
-				echo "That didn't work either.  Giving up." >&4
-				exit 1
-			fi
-		fi
-	fi
+	revision=0
+	patchlevel=0
+	subversion=0
+	api_revision=0
+	api_version=0
+	api_subversion=0
+	perl_patchlevel=0
+	$echo "(You do not have patchlevel.h.  Eek.)"
 fi
-nm_extract="$com"
-if $test -f /lib/syscalls.exp; then
-	echo " "
-	echo "Also extracting names from /lib/syscalls.exp for good ole AIX..." >&4
-	$sed -n 's/^\([^ 	]*\)[ 	]*syscall[0-9]*[ 	]*$/\1/p' /lib/syscalls.exp >>libc.list
+if $test -r $rsrc/.patch ; then  
+	if $test "`cat $rsrc/.patch`" -gt "$perl_patchlevel" ; then
+		perl_patchlevel=`cat $rsrc/.patch`
+	fi
 fi
-;;
+: Define a handy string here to avoid duplication in myconfig.SH and configpm.
+version_patchlevel_string="version $patchlevel subversion $subversion"
+case "$perl_patchlevel" in
+0|'') ;;
+*) version_patchlevel_string="$version_patchlevel_string patch $perl_patchlevel" ;;
 esac
-$rm -f libnames libpath
 
-: is a C symbol defined?
-csym='tlook=$1;
-case "$3" in
--v) tf=libc.tmp; tc=""; tdc="";;
--a) tf=libc.tmp; tc="[0]"; tdc="[]";;
-*) tlook="^$1\$"; tf=libc.list; tc="()"; tdc="()";;
-esac;
-tx=yes;
-case "$reuseval-$4" in
-true-) ;;
-true-*) tx=no; eval "tval=\$$4"; case "$tval" in "") tx=yes;; esac;;
-esac;
-case "$tx" in
-yes)
-	case "$runnm" in
-	true)
-		if $contains $tlook $tf >/dev/null 2>&1;
-		then tval=true;
-		else tval=false;
-		fi;;
-	*)
-		echo "int main() { extern short $1$tdc; printf(\"%hd\", $1$tc); }" > t.c;
-		if $cc -o t $optimize $ccflags $ldflags t.c $libs >/dev/null 2>&1;
-		then tval=true;
-		else tval=false;
-		fi;
-		$rm -f t t.c;;
-	esac;;
-*)
-	case "$tval" in
-	$define) tval=true;;
-	*) tval=false;;
-	esac;;
-esac;
-eval "$2=$tval"'
+$echo "(You have $package $version_patchlevel_string.)"
 
-: define an is-in-libc? function
-inlibc='echo " "; td=$define; tu=$undef;
-sym=$1; var=$2; eval "was=\$$2";
-tx=yes;
-case "$reuseval$was" in
-true) ;;
-true*) tx=no;;
-esac;
-case "$tx" in
-yes)
-	set $sym tres -f;
-	eval $csym;
-	case "$tres" in
-	true)
-		echo "$sym() found." >&4;
-		case "$was" in $undef) . ./whoa; esac; eval "$var=\$td";;
-	*)
-		echo "$sym() NOT found." >&4;
-		case "$was" in $define) . ./whoa; esac; eval "$var=\$tu";;
-	esac;;
+case "$osname" in
+dos|vms)
+	: XXX Should be a Configure test for double-dots in filenames.
+	version=`echo $revision $patchlevel $subversion | \
+		 $awk '{ printf "%d_%d_%d\n", $1, $2, $3 }'`
+	api_versionstring=`echo $api_revision $api_version $api_subversion | \
+		 $awk '{ printf "%d_%d_%d\n", $1, $2, $3 }'`
+	;;
 *)
-	case "$was" in
-	$define) echo "$sym() found." >&4;;
-	*) echo "$sym() NOT found." >&4;;
-	esac;;
-esac'
-
-: see if sqrtl exists
-set sqrtl d_sqrtl
-eval $inlibc
-
-: check for length of double
-echo " "
-case "$doublesize" in
-'')
-	echo "Checking to see how big your double precision numbers are..." >&4
-	$cat >try.c <<'EOCP'
-#include <stdio.h>
-int main()
-{
-    printf("%d\n", (int)sizeof(double));
-    exit(0);
-}
-EOCP
-	set try
-	if eval $compile_ok; then
-		doublesize=`$run ./try`
-		echo "Your double is $doublesize bytes long."
-	else
-		dflt='8'
-		echo "(I can't seem to compile the test program.  Guessing...)"
-		rp="What is the size of a double precision number (in bytes)?"
-		. ./myread
-		doublesize="$ans"
-	fi
+	version=`echo $revision $patchlevel $subversion | \
+		 $awk '{ printf "%d.%d.%d\n", $1, $2, $3 }'`
+	api_versionstring=`echo $api_revision $api_version $api_subversion | \
+		 $awk '{ printf "%d.%d.%d\n", $1, $2, $3 }'`
 	;;
 esac
-$rm -f try.c try
-
-: check for long doubles
-echo " "
-echo "Checking to see if you have long double..." >&4
-echo 'int main() { long double x = 7.0; }' > try.c
-set try
-if eval $compile; then
-	val="$define"
-	echo "You have long double."
-else
-	val="$undef"
-	echo "You do not have long double."
+: Special case the 5.005_xx maintenance series, which used 5.005
+: without any subversion label as a subdirectory in $sitelib
+if test "${api_revision}${api_version}${api_subversion}" = "550"; then
+	api_versionstring='5.005'
 fi
-$rm try.*
-set d_longdbl
-eval $setvar
 
-: check for length of long double
-case "${d_longdbl}${longdblsize}" in
-$define)
-	echo " "
-	echo "Checking to see how big your long doubles are..." >&4
-	$cat >try.c <<'EOCP'
-#include <stdio.h>
-int main()
-{
-	printf("%d\n", sizeof(long double));
-}
-EOCP
-	set try
-	set try
-	if eval $compile; then
-		longdblsize=`$run ./try`
-		echo "Your long doubles are $longdblsize bytes long."
-	else
-		dflt='8'
-		echo " "
-		echo "(I can't seem to compile the test program.  Guessing...)" >&4
-		rp="What is the size of a long double (in bytes)?"
-		. ./myread
-		longdblsize="$ans"
-	fi
-	if $test "X$doublesize" = "X$longdblsize"; then
-		echo "(That isn't any different from an ordinary double.)"
-	fi	
+: determine installation style
+: For now, try to deduce it from prefix unless it is already set.
+: Reproduce behavior of 5.005 and earlier, maybe drop that in 5.7.
+case "$installstyle" in
+'')	case "$prefix" in
+		*perl*) dflt='lib';;
+		*) dflt='lib/perl5' ;;
+	esac
 	;;
+*)	dflt="$installstyle" ;;
 esac
-$rm -f try.* try
-
-echo " "
+: Probably not worth prompting for this since we prompt for all
+: the directories individually, and the prompt would be too long and
+: confusing anyway.
+installstyle=$dflt
 
-if $test X"$d_longdbl" = X"$define"; then
+: determine where private library files go
+: Usual default is /usr/local/lib/perl5/$version.
+: Also allow things like /opt/perl/lib/$version, since 
+: /opt/perl/lib/perl5... would be redundant.
+: The default "style" setting is made in installstyle.U
+case "$installstyle" in
+*lib/perl5*) set dflt privlib lib/$package/$version ;;
+*)	 set dflt privlib lib/$version ;;
+esac
+eval $prefixit
+$cat <<EOM
 
-echo "Checking how to print long doubles..." >&4
+There are some auxiliary files for $package that need to be put into a
+private library directory that is accessible by everyone.
 
-if $test X"$sPRIfldbl" = X -a X"$doublesize" = X"$longdblsize"; then
-	$cat >try.c <<'EOCP'
-#include <sys/types.h>
-#include <stdio.h>
-int main() {
-  double d = 123.456;
-  printf("%.3f\n", d);
-}
-EOCP
-	set try
-	if eval $compile; then
-		yyy=`$run ./try`
-		case "$yyy" in
-		123.456)
-			sPRIfldbl='"f"'; sPRIgldbl='"g"'; sPRIeldbl='"e"';
-                	sPRIFUldbl='"F"'; sPRIGUldbl='"G"'; sPRIEUldbl='"E"';
-			echo "We will use %f."
-			;;
-		esac
-	fi
+EOM
+fn=d~+
+rp='Pathname where the private library files will reside?'
+. ./getfile
+privlib="$ans"
+privlibexp="$ansexp"
+: Change installation prefix, if necessary.
+if $test X"$prefix" != X"$installprefix"; then
+	installprivlib=`echo $privlibexp | sed "s#^$prefix#$installprefix#"`
+else
+	installprivlib="$privlibexp"
 fi
 
-if $test X"$sPRIfldbl" = X; then
-	$cat >try.c <<'EOCP'
-#include <sys/types.h>
-#include <stdio.h>
-int main() {
-  long double d = 123.456;
-  printf("%.3Lf\n", d);
-}
-EOCP
-	set try
-	if eval $compile; then
-		yyy=`$run ./try`
-		case "$yyy" in
-		123.456)
-			sPRIfldbl='"Lf"'; sPRIgldbl='"Lg"'; sPRIeldbl='"Le"';
-                	sPRIFUldbl='"LF"'; sPRIGUldbl='"LG"'; sPRIEUldbl='"LE"';
-			echo "We will use %Lf."
-			;;
-		esac
-	fi
-fi
+: set the prefixup variable, to restore leading tilda escape
+prefixup='case "$prefixexp" in
+"$prefix") ;;
+*) eval "$1=\`echo \$$1 | sed \"s,^$prefixexp,$prefix,\"\`";;
+esac'
 
-if $test X"$sPRIfldbl" = X; then
-	$cat >try.c <<'EOCP'
-#include <sys/types.h>
-#include <stdio.h>
-int main() {
-  long double d = 123.456;
-  printf("%.3llf\n", d);
-}
-EOCP
-	set try
-	if eval $compile; then
-		yyy=`$run ./try`
-		case "$yyy" in
-		123.456)
-			sPRIfldbl='"llf"'; sPRIgldbl='"llg"'; sPRIeldbl='"lle"';
-                	sPRIFUldbl='"llF"'; sPRIGUldbl='"llG"'; sPRIEUldbl='"llE"';
-			echo "We will use %llf."
-			;;
-		esac
-	fi
-fi
+: determine where public architecture dependent libraries go
+set archlib archlib
+eval $prefixit
+: privlib default is /usr/local/lib/$package/$version
+: archlib default is /usr/local/lib/$package/$version/$archname
+: privlib may have an optional trailing /share.
+tdflt=`echo $privlib | $sed 's,/share$,,'`
+tdflt=$tdflt/$archname
+case "$archlib" in
+'')	dflt=$tdflt
+	;;
+*)	dflt="$archlib"
+    ;;
+esac
+$cat <<EOM
 
-if $test X"$sPRIfldbl" = X; then
-	$cat >try.c <<'EOCP'
-#include <sys/types.h>
-#include <stdio.h>
-int main() {
-  long double d = 123.456;
-  printf("%.3lf\n", d);
-}
-EOCP
-	set try
-	if eval $compile; then
-		yyy=`$run ./try`
-		case "$yyy" in
-		123.456)
-			sPRIfldbl='"lf"'; sPRIgldbl='"lg"'; sPRIeldbl='"le"';
-                	sPRIFUldbl='"lF"'; sPRIGUldbl='"lG"'; sPRIEUldbl='"lE"';
-			echo "We will use %lf."
-			;;
-		esac
-	fi
-fi
+$spackage contains architecture-dependent library files.  If you are
+sharing libraries in a heterogeneous environment, you might store
+these files in a separate location.  Otherwise, you can just include
+them with the rest of the public library files.
 
-if $test X"$sPRIfldbl" = X; then
-	echo "Cannot figure out how to print long doubles." >&4
+EOM
+fn=d+~
+rp='Where do you want to put the public architecture-dependent libraries?'
+. ./getfile
+archlib="$ans"
+archlibexp="$ansexp"
+if $test X"$archlib" = X"$privlib"; then
+	d_archlib="$undef"
+else
+	d_archlib="$define"
+fi
+: Change installation prefix, if necessary.
+if $test X"$prefix" != X"$installprefix"; then
+	installarchlib=`echo $archlibexp | sed "s#^$prefix#$installprefix#"`
 else
-	sSCNfldbl=$sPRIfldbl	# expect consistency
+	installarchlib="$archlibexp"
 fi
 
-$rm -f try try.*
+: see if setuid scripts can be secure
+$cat <<EOM
 
-fi # d_longdbl
+Some kernels have a bug that prevents setuid #! scripts from being
+secure.  Some sites have disabled setuid #! scripts because of this.
 
-case "$sPRIfldbl" in
-'')	d_PRIfldbl="$undef"; d_PRIgldbl="$undef"; d_PRIeldbl="$undef"; 
-	d_PRIFUldbl="$undef"; d_PRIGUldbl="$undef"; d_PRIEUldbl="$undef"; 
-	d_SCNfldbl="$undef";
-	;;
-*)	d_PRIfldbl="$define"; d_PRIgldbl="$define"; d_PRIeldbl="$define"; 
-	d_PRIFUldbl="$define"; d_PRIGUldbl="$define"; d_PRIEUldbl="$define"; 
-	d_SCNfldbl="$define";
-	;;
-esac
+First let's decide if your kernel supports secure setuid #! scripts.
+(If setuid #! scripts would be secure but have been disabled anyway,
+don't say that they are secure if asked.)
 
-: see if modfl exists
-set modfl d_modfl
-eval $inlibc
+EOM
 
-d_modfl_pow32_bug="$undef"
+val="$undef"
+if $test -d /dev/fd; then
+	echo "#!$ls" >reflect
+	chmod +x,u+s reflect
+	./reflect >flect 2>&1
+	if $contains "/dev/fd" flect >/dev/null; then
+		echo "Congratulations, your kernel has secure setuid scripts!" >&4
+		val="$define"
+	else
+		$cat <<EOM
+If you are not sure if they are secure, I can check but I'll need a
+username and password different from the one you are using right now.
+If you don't have such a username or don't want me to test, simply
+enter 'none'.
 
-case "$d_longdbl$d_modfl" in
-$define$define)
-	$cat <<EOM
-Checking to see whether your modfl() is okay for large values...
 EOM
-$cat >try.c <<EOCP
-#include <math.h> 
-#include <stdio.h>
-int main() {
-    long double nv = 4294967303.15;
-    long double v, w;
-    v = modfl(nv, &w);         
-#ifdef __GLIBC__
-    printf("glibc");
-#endif
-    printf(" %"$sPRIfldbl" %"$sPRIfldbl" %"$sPRIfldbl"\n", nv, v, w);
-    return 0;
-}
-EOCP
-	case "$osname:$gccversion" in
-	aix:)	saveccflags="$ccflags"
-		ccflags="$ccflags -qlongdouble" ;; # to avoid core dump
-	esac
-	set try
-	if eval $compile; then
-		foo=`$run ./try`
-		case "$foo" in
-		*" 4294967303.150000 1.150000 4294967302.000000")
-			echo >&4 "Your modfl() is broken for large values."
-			d_modfl_pow32_bug="$define"
-			case "$foo" in
-			glibc)	echo >&4 "You should upgrade your glibc to at least 2.2.2 to get a fixed modfl()."
-			;;
+		rp='Other username to test security of setuid scripts with?'
+		dflt='none'
+		. ./myread
+		case "$ans" in
+		n|none)
+			case "$d_suidsafe" in
+			'')	echo "I'll assume setuid scripts are *not* secure." >&4
+				dflt=n;;
+			"$undef")
+				echo "Well, the $hint value is *not* secure." >&4
+				dflt=n;;
+			*)	echo "Well, the $hint value *is* secure." >&4
+				dflt=y;;
 			esac
 			;;
-		*" 4294967303.150000 0.150000 4294967303.000000")
-			echo >&4 "Your modfl() seems okay for large values."
-			;;
-		*)	echo >&4 "I don't understand your modfl() at all."
-			d_modfl="$undef"
+		*)
+			$rm -f reflect flect
+			echo "#!$ls" >reflect
+			chmod +x,u+s reflect
+			echo >flect
+			chmod a+w flect
+			echo '"su" will (probably) prompt you for '"$ans's password."
+			su $ans -c './reflect >flect'
+			if $contains "/dev/fd" flect >/dev/null; then
+				echo "Okay, it looks like setuid scripts are secure." >&4
+				dflt=y
+			else
+				echo "I don't think setuid scripts are secure." >&4
+				dflt=n
+			fi
 			;;
 		esac
-		$rm -f try.* try core core.try.*
-	else
-		echo "I cannot figure out whether your modfl() is okay, assuming it isn't."
-		d_modfl="$undef"
+		rp='Does your kernel have *secure* setuid scripts?'
+		. ./myread
+		case "$ans" in
+		[yY]*)	val="$define";;
+		*)	val="$undef";;
+		esac
 	fi
-	case "$osname:$gccversion" in
-	aix:)	ccflags="$saveccflags" ;; # restore
-	esac
-	;;
-esac
+else
+	echo "I don't think setuid scripts are secure (no /dev/fd directory)." >&4
+	echo "(That's for file descriptors, not floppy disks.)"
+	val="$undef"
+fi
+set d_suidsafe
+eval $setvar
 
-case "$ccflags" in
-*-DUSE_LONG_DOUBLE*|*-DUSE_MORE_BITS*) uselongdouble="$define" ;;
-esac
+$rm -f reflect flect
 
-case "$uselongdouble" in
-$define|true|[yY]*)	dflt='y';;
-*) dflt='n';;
-esac
-cat <<EOM
-
-Perl can be built to take advantage of long doubles which
-(if available) may give more accuracy and range for floating point numbers.
+: now see if they want to do setuid emulation
+echo " "
+val="$undef"
+case "$d_suidsafe" in
+"$define")
+	val="$undef"
+	echo "No need to emulate SUID scripts since they are secure here." >&4
+	;;
+*)
+	$cat <<EOM
+Some systems have disabled setuid scripts, especially systems where
+setuid scripts cannot be secure.  On systems where setuid scripts have
+been disabled, the setuid/setgid bits on scripts are currently
+useless.  It is possible for $package to detect those bits and emulate
+setuid/setgid in a secure fashion.  This emulation will only work if
+setuid scripts have been disabled in your kernel.
 
-If this doesn't make any sense to you, just accept the default '$dflt'.
 EOM
-rp='Try to use long doubles if available?'
-. ./myread
-case "$ans" in
-y|Y) 	val="$define"	;;
-*)      val="$undef"	;;
+	case "$d_dosuid" in
+	"$define") dflt=y ;;
+	*) dflt=n ;;
+	esac
+	rp="Do you want to do setuid/setgid emulation?"
+	. ./myread
+	case "$ans" in
+	[yY]*)	val="$define";;
+	*)	val="$undef";;
+	esac
+	;;
 esac
-set uselongdouble
+set d_dosuid
 eval $setvar
 
-case "$uselongdouble" in
-true|[yY]*) uselongdouble="$define" ;;
-esac
+: see if this is a malloc.h system
+: we want a real compile instead of Inhdr because some systems have a
+: malloc.h that just gives a compile error saying to use stdlib.h instead
+echo " "
+$cat >try.c <<EOCP
+#include <stdlib.h>
+#include <malloc.h>
+int main () { return 0; }
+EOCP
+set try
+if eval $compile; then
+    echo "<malloc.h> found." >&4
+    val="$define"
+else
+    echo "<malloc.h> NOT found." >&4
+    val="$undef"
+fi
+$rm -f try.c try
+set i_malloc
+eval $setvar
 
-case "$uselongdouble" in
-$define)
-: Look for a hint-file generated 'call-back-unit'.  If the
-: user has specified that long doubles should be used,
-: we may need to set or change some other defaults.
-	if $test -f uselongdouble.cbu; then
-		echo "Your platform has some specific hints for long doubles, using them..."
-		. ./uselongdouble.cbu
+: check for void type
+echo " "
+echo "Checking to see how well your C compiler groks the void type..." >&4
+case "$voidflags" in
+'')
+	$cat >try.c <<EOCP
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
+#if TRY & 1
+void sub() {
+#else
+sub() {
+#endif
+	extern void moo();	/* function returning void */
+	void (*goo)();		/* ptr to func returning void */
+#if TRY & 8
+	void *hue;		/* generic ptr */
+#endif
+#if TRY & 2
+	void (*foo[10])();
+#endif
+
+#if TRY & 4
+	if(goo == moo) {
+		exit(0);
+	}
+#endif
+	exit(0);
+}
+int main() { sub(); }
+EOCP
+	if $cc $ccflags -c -DTRY=$defvoidused try.c >.out 2>&1 ; then
+		voidflags=$defvoidused
+	echo "Good.  It appears to support void to the level $package wants.">&4
+		if $contains warning .out >/dev/null 2>&1; then
+			echo "However, you might get some warnings that look like this:"
+			$cat .out
+		fi
 	else
-		$cat <<EOM
-(Your platform doesn't have any specific hints for long doubles.)
-EOM
+echo "Hmm, your compiler has some difficulty with void. Checking further..." >&4
+		if $cc $ccflags -c -DTRY=1 try.c >/dev/null 2>&1; then
+			echo "It supports 1..."
+			if $cc $ccflags -c -DTRY=3 try.c >/dev/null 2>&1; then
+				echo "It also supports 2..."
+				if $cc $ccflags -c -DTRY=7 try.c >/dev/null 2>&1; then
+					voidflags=7
+					echo "And it supports 4 but not 8 definitely."
+				else
+					echo "It doesn't support 4..."
+					if $cc $ccflags -c -DTRY=11 try.c >/dev/null 2>&1; then
+						voidflags=11
+						echo "But it supports 8."
+					else
+						voidflags=3
+						echo "Neither does it support 8."
+					fi
+				fi
+			else
+				echo "It does not support 2..."
+				if $cc $ccflags -c -DTRY=13 try.c >/dev/null 2>&1; then
+					voidflags=13
+					echo "But it supports 4 and 8."
+				else
+					if $cc $ccflags -c -DTRY=5 try.c >/dev/null 2>&1; then
+						voidflags=5
+						echo "And it supports 4 but has not heard about 8."
+					else
+						echo "However it supports 8 but not 4."
+					fi
+				fi
+			fi
+		else
+			echo "There is no support at all for void."
+			voidflags=0
+		fi
 	fi
+esac
+case "$voidflags" in
+"$defvoidused") ;;
+*)	$cat >&4 <<'EOM'
+  Support flag bits are:
+    1: basic void declarations.
+    2: arrays of pointers to functions returning void.
+    4: operations between pointers to and addresses of void functions.
+    8: generic void pointers.
+EOM
+	dflt="$voidflags";
+	rp="Your void support flags add up to what?"
+	. ./myread
+	voidflags="$ans"
 	;;
 esac
+$rm -f try.* .out
 
-message=X
-case "$uselongdouble:$d_sqrtl:$d_modfl" in
-$define:$define:$define)
-	: You have both
-	;;
-$define:$define:$undef)
-	message="I could not find modfl"
-	;;
-$define:$undef:$define)
-	message="I could not find sqrtl"
-	;;
-$define:$undef:$undef)
-	message="I found neither sqrtl nor modfl"
+: check for length of pointer
+echo " "
+case "$ptrsize" in
+'')
+	echo "Checking to see how big your pointers are..." >&4
+	if test "$voidflags" -gt 7; then
+		echo '#define VOID_PTR char *' > try.c
+	else
+		echo '#define VOID_PTR void *' > try.c
+	fi
+	$cat >>try.c <<EOCP
+#include <stdio.h>
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
+int main()
+{
+    printf("%d\n", (int)sizeof(VOID_PTR));
+    exit(0);
+}
+EOCP
+	set try
+	if eval $compile_ok; then
+		ptrsize=`$run ./try`
+		echo "Your pointers are $ptrsize bytes long."
+	else
+		dflt='4'
+		echo "(I can't seem to compile the test program.  Guessing...)" >&4
+		rp="What is the size of a pointer (in bytes)?"
+		. ./myread
+		ptrsize="$ans"
+	fi
 	;;
 esac
+$rm -f try.c try
+case "$use64bitall" in
+"$define"|true|[yY]*)
+	case "$ptrsize" in
+	4)	cat <<EOM >&4
 
-if $test "$message" != X; then
-	$cat <<EOM >&4
-
-*** You requested the use of long doubles but you do not seem to have
-*** the mathematic functions for long doubles.
-*** ($message)
-*** I'm disabling the use of long doubles.
+*** You have chosen a maximally 64-bit build,
+*** but your pointers are only 4 bytes wide.
+*** Please rerun Configure without -Duse64bitall.
+EOM
+		case "$d_quad" in
+		define)
+			cat <<EOM >&4
+*** Since you have quads, you could possibly try with -Duse64bitint.
+EOM
+			;;
+		esac
+		cat <<EOM >&4
+*** Cannot continue, aborting.
 
 EOM
 
-	uselongdouble=$undef
-fi
+		exit 1
+		;;
+	esac
+	;;
+esac
 
-: determine the architecture name
+
+: determine which malloc to compile in
 echo " "
-if xxx=`./loc arch blurfl $pth`; $test -f "$xxx"; then
-	tarch=`arch`"-$osname"
-elif xxx=`./loc uname blurfl $pth`; $test -f "$xxx" ; then
-	if uname -m > tmparch 2>&1 ; then
-		tarch=`$sed -e 's/ *$//' -e 's/ /_/g' \
-			-e 's/$/'"-$osname/" tmparch`
-	else
-		tarch="$osname"
-	fi
-	$rm -f tmparch
-else
-	tarch="$osname"
-fi
-case "$myarchname" in
-''|"$tarch") ;;
-*)
-	echo "(Your architecture name used to be $myarchname.)"
-	archname=''
+case "$usemymalloc" in
+[yY]*|true|$define)	dflt='y' ;;
+[nN]*|false|$undef)	dflt='n' ;;
+*)	case "$ptrsize" in
+	4) dflt='y' ;;
+	*) dflt='n' ;;
+	esac
 	;;
 esac
-case "$targetarch" in
-'') ;;
-*)  archname=`echo $targetarch|sed 's,^[^-]*-,,'` ;;
-esac
-myarchname="$tarch"
-case "$archname" in
-'') dflt="$tarch";;
-*) dflt="$archname";;
-esac
-rp='What is your architecture name'
+rp="Do you wish to attempt to use the malloc that comes with $package?"
 . ./myread
-archname="$ans"
-case "$usethreads" in
-$define)
-	echo "Threads selected." >&4
-	case "$archname" in
-        *-thread*) echo "...and architecture name already has -thread." >&4
-                ;;
-        *)      archname="$archname-thread"
-                echo "...setting architecture name to $archname." >&4
-                ;;
-        esac
-	;;
-esac
-case "$usemultiplicity" in
-$define)
-	echo "Multiplicity selected." >&4
-	case "$archname" in
-        *-multi*) echo "...and architecture name already has -multi." >&4
-                ;;
-        *)      archname="$archname-multi"
-                echo "...setting architecture name to $archname." >&4
-                ;;
-        esac
-	;;
-esac
-case "$use64bitint$use64bitall" in
-*"$define"*)
-	case "$archname64" in
-	'')
-		echo "This architecture is naturally 64-bit, not changing architecture name." >&4
-		;;
-	*)
-		case "$use64bitint" in
-		"$define") echo "64 bit integers selected." >&4 ;;
-		esac
-		case "$use64bitall" in
-		"$define") echo "Maximal 64 bitness selected." >&4 ;;
-		esac
-		case "$archname" in
-	        *-$archname64*) echo "...and architecture name already has $archname64." >&4
-	                ;;
-	        *)      archname="$archname-$archname64"
-	                echo "...setting architecture name to $archname." >&4
-	                ;;
-	        esac
-		;;
-	esac
-esac
-case "$uselongdouble" in
-$define)
-	echo "Long doubles selected." >&4
-	case "$longdblsize" in
-	$doublesize)
-		echo "...but long doubles are equal to doubles, not changing architecture name." >&4
-		;;
-	*)
-		case "$archname" in
-	        *-ld*) echo "...and architecture name already has -ld." >&4
-	                ;;
-	        *)      archname="$archname-ld"
-	                echo "...setting architecture name to $archname." >&4
-        	        ;;
-	        esac
+usemymalloc="$ans"
+case "$ans" in
+y*|true)
+	usemymalloc='y'
+	mallocsrc='malloc.c'
+	mallocobj="malloc$_o"
+	d_mymalloc="$define"
+	case "$libs" in
+	*-lmalloc*)
+		: Remove malloc from list of libraries to use
+		echo "Removing unneeded -lmalloc from library list" >&4
+		set `echo X $libs | $sed -e 's/-lmalloc / /' -e 's/-lmalloc$//'`
+		shift
+		libs="$*"
+		echo "libs = $libs" >&4
 		;;
 	esac
 	;;
-esac
-case "$useperlio" in
-$define)
-	echo "Perlio selected." >&4
-	;;
 *)
-	echo "Perlio not selected, using stdio." >&4
-	case "$archname" in
-        *-stdio*) echo "...and architecture name already has -stdio." >&4
-                ;;
-        *)      archname="$archname-stdio"
-                echo "...setting architecture name to $archname." >&4
-                ;;
-        esac
+	usemymalloc='n'
+	mallocsrc=''
+	mallocobj=''
+	d_mymalloc="$undef"
 	;;
 esac
 
-: determine root of directory hierarchy where package will be installed.
-case "$prefix" in
+: compute the return types of malloc and free
+echo " "
+$cat >malloc.c <<END
+#$i_malloc I_MALLOC
+#$i_stdlib I_STDLIB
+#include <stdio.h>
+#include <sys/types.h>
+#ifdef I_MALLOC
+#include <malloc.h>
+#endif
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
+#ifdef TRY_MALLOC
+void *malloc();
+#endif
+#ifdef TRY_FREE
+void free();
+#endif
+END
+case "$malloctype" in
 '')
-	dflt=`./loc . /usr/local /usr/local /local /opt /usr`
+	if $cc $ccflags -c -DTRY_MALLOC malloc.c >/dev/null 2>&1; then
+		malloctype='void *'
+	else
+		malloctype='char *'
+	fi
 	;;
-*)
-	dflt="$prefix"
+esac
+echo "Your system wants malloc to return '$malloctype', it would seem." >&4
+
+case "$freetype" in
+'')
+	if $cc $ccflags -c -DTRY_FREE malloc.c >/dev/null 2>&1; then
+		freetype='void'
+	else
+		freetype='int'
+	fi
 	;;
 esac
+echo "Your system uses $freetype free(), it would seem." >&4
+$rm -f malloc.[co]
 $cat <<EOM
 
-By default, $package will be installed in $dflt/bin, manual pages
-under $dflt/man, etc..., i.e. with $dflt as prefix for all
-installation directories. Typically this is something like /usr/local.
-If you wish to have binaries under /usr/bin but other parts of the
-installation under /usr/local, that's ok: you will be prompted
-separately for each of the installation directories, the prefix being
-only used to set the defaults.
+After $package is installed, you may wish to install various
+add-on modules and utilities.  Typically, these add-ons will
+be installed under $prefix with the rest
+of this package.  However, you may wish to install such add-ons
+elsewhere under a different prefix.
+
+If you do not wish to put everything under a single prefix, that's
+ok.  You will be prompted for the individual locations; this siteprefix
+is only used to suggest the defaults.
+
+The default should be fine for most people.
 
 EOM
-fn=d~
-rp='Installation prefix to use?'
+fn=d~+
+rp='Installation prefix to use for add-on modules and utilities?'
+: XXX Here might be another good place for an installstyle setting.
+case "$siteprefix" in
+'') dflt=$prefix ;;
+*)  dflt=$siteprefix ;;
+esac
 . ./getfile
-oldprefix=''
-case "$prefix" in
+: XXX Prefixit unit does not yet support siteprefix and vendorprefix
+oldsiteprefix=''
+case "$siteprefix" in
 '') ;;
-*)
-	case "$ans" in
+*)	case "$ans" in
 	"$prefix") ;;
-	*) oldprefix="$prefix";;
+	*) oldsiteprefix="$prefix";;
 	esac
 	;;
 esac
-prefix="$ans"
-prefixexp="$ansexp"
-
-case "$afsroot" in
-'')	afsroot=/afs ;;
-*)	afsroot=$afsroot ;;
-esac
+siteprefix="$ans"
+siteprefixexp="$ansexp"
 
-: is AFS running?
-echo " "
-case "$afs" in
-$define|true)	afs=true ;;
-$undef|false)	afs=false ;;
-*)	if test -d $afsroot; then
-		afs=true
-	else
-		afs=false
-	fi
+: determine where site specific libraries go.
+: Usual default is /usr/local/lib/perl5/site_perl/$version
+: The default "style" setting is made in installstyle.U
+: XXX No longer works with Prefixit stuff.
+prog=`echo $package | $sed 's/-*[0-9.]*$//'`
+case "$sitelib" in
+'') case "$installstyle" in
+	*lib/perl5*) dflt=$siteprefix/lib/$package/site_$prog/$version ;;
+	*)	 dflt=$siteprefix/lib/site_$prog/$version ;;
+	esac
+	;;
+*)	dflt="$sitelib"
 	;;
 esac
-if $afs; then
-	echo "AFS may be running... I'll be extra cautious then..." >&4
+$cat <<EOM
+
+The installation process will create a directory for
+site-specific extensions and modules.  Most users find it convenient
+to place all site-specific files in this directory rather than in the
+main distribution directory.
+
+EOM
+fn=d~+
+rp='Pathname for the site-specific library files?'
+. ./getfile
+sitelib="$ans"
+sitelibexp="$ansexp"
+sitelib_stem=`echo "$sitelibexp" | sed "s,/$version$,,"`
+: Change installation prefix, if necessary.
+if $test X"$prefix" != X"$installprefix"; then
+	installsitelib=`echo $sitelibexp | $sed "s#^$prefix#$installprefix#"`
 else
-	echo "AFS does not seem to be running..." >&4
+	installsitelib="$sitelibexp"
 fi
 
-: determine installation prefix for where package is to be installed.
-if $afs; then 
+: determine where site specific architecture-dependent libraries go.
+: sitelib  default is /usr/local/lib/perl5/site_perl/$version
+: sitearch default is /usr/local/lib/perl5/site_perl/$version/$archname
+: sitelib may have an optional trailing /share.
+case "$sitearch" in
+'')	dflt=`echo $sitelib | $sed 's,/share$,,'`
+	dflt="$dflt/$archname"
+	;;
+*)	dflt="$sitearch"
+	;;
+esac
+set sitearch sitearch none
+eval $prefixit
 $cat <<EOM
 
-Since you are running AFS, I need to distinguish the directory in which
-files will reside from the directory in which they are installed (and from
-which they are presumably copied to the former directory by occult means).
+The installation process will also create a directory for
+architecture-dependent site-specific extensions and modules.
 
 EOM
-	case "$installprefix" in
-	'') dflt=`echo $prefix | sed 's#^/afs/#/afs/.#'`;;
-	*) dflt="$installprefix";;
-	esac
+fn=d~+
+rp='Pathname for the site-specific architecture-dependent library files?'
+. ./getfile
+sitearch="$ans"
+sitearchexp="$ansexp"
+: Change installation prefix, if necessary.
+if $test X"$prefix" != X"$installprefix"; then
+	installsitearch=`echo $sitearchexp | sed "s#^$prefix#$installprefix#"`
 else
+	installsitearch="$sitearchexp"
+fi
+
 $cat <<EOM
 
-In some special cases, particularly when building $package for distribution,
-it is convenient to distinguish between the directory in which files should 
-be installed from the directory ($prefix) in which they 
-will eventually reside.  For most users, these two directories are the same.
+The installation process will also create a directory for
+vendor-supplied add-ons.  Vendors who supply perl with their system
+may find it convenient to place all vendor-supplied files in this
+directory rather than in the main distribution directory.  This will
+ease upgrades between binary-compatible maintenance versions of perl.
 
-EOM
-	case "$installprefix" in
-	'') dflt=$prefix ;;
-	*) dflt=$installprefix;;
-	esac
-fi
-fn=d~
-rp='What installation prefix should I use for installing files?'
-. ./getfile
-installprefix="$ans"
-installprefixexp="$ansexp"
+Of course you may also use these directories in whatever way you see
+fit.  For example, you might use them to access modules shared over a
+company-wide network.
 
-: set the prefixit variable, to compute a suitable default value
-prefixit='case "$3" in
-""|none)
-	case "$oldprefix" in
-	"") eval "$1=\"\$$2\"";;
-	*)
-		case "$3" in
-		"") eval "$1=";;
-		none)
-			eval "tp=\"\$$2\"";
-			case "$tp" in
-			""|" ") eval "$1=\"\$$2\"";;
-			*) eval "$1=";;
-			esac;;
-		esac;;
-	esac;;
-*)
-	eval "tp=\"$oldprefix-\$$2-\""; eval "tp=\"$tp\"";
-	case "$tp" in
-	--|/*--|\~*--) eval "$1=\"$prefix/$3\"";;
-	/*-$oldprefix/*|\~*-$oldprefix/*)
-		eval "$1=\`echo \$$2 | sed \"s,^$oldprefix,$prefix,\"\`";;
-	*) eval "$1=\"\$$2\"";;
-	esac;;
-esac'
+The default answer should be fine for most people.
+This causes further questions about vendor add-ons to be skipped
+and no vendor-specific directories will be configured for perl.
 
-: get the patchlevel
-echo " "
-echo "Getting the current patchlevel..." >&4
-if $test -r $rsrc/patchlevel.h;then
-	revision=`awk '/define[ 	]+PERL_REVISION/ {print $3}' $rsrc/patchlevel.h`
-	patchlevel=`awk '/define[ 	]+PERL_VERSION/ {print $3}' $rsrc/patchlevel.h`
-	subversion=`awk '/define[ 	]+PERL_SUBVERSION/ {print $3}' $rsrc/patchlevel.h`
-	api_revision=`awk '/define[ 	]+PERL_API_REVISION/ {print $3}' $rsrc/patchlevel.h`
-	api_version=`awk '/define[ 	]+PERL_API_VERSION/ {print $3}' $rsrc/patchlevel.h`
-	api_subversion=`awk '/define[ 	]+PERL_API_SUBVERSION/ {print $3}' $rsrc/patchlevel.h`
-       perl_patchlevel=`grep ',"DEVEL[0-9][0-9]*"' $rsrc/patchlevel.h|sed 's/[^0-9]//g'`
-else
-	revision=0
-	patchlevel=0
-	subversion=0
-	api_revision=0
-	api_version=0
-	api_subversion=0
-	perl_patchlevel=0
-	$echo "(You do not have patchlevel.h.  Eek.)"
-fi
-if $test -r $rsrc/.patch ; then  
-	if $test "`cat $rsrc/.patch`" -gt "$perl_patchlevel" ; then
-		perl_patchlevel=`cat $rsrc/.patch`
-	fi
-fi
-: Define a handy string here to avoid duplication in myconfig.SH and configpm.
-version_patchlevel_string="version $patchlevel subversion $subversion"
-case "$perl_patchlevel" in
-0|'') ;;
-*) version_patchlevel_string="$version_patchlevel_string patch $perl_patchlevel" ;;
+EOM
+rp='Do you want to configure vendor-specific add-on directories?'
+case "$usevendorprefix" in
+define|true|[yY]*) dflt=y ;;
+*)	: User may have set vendorprefix directly on Configure command line.
+	case "$vendorprefix" in
+	''|' ') dflt=n ;;
+	*)	dflt=y ;;
+	esac
+	;;
 esac
-
-$echo "(You have $package $version_patchlevel_string.)"
-
-case "$osname" in
-dos|vms)
-	: XXX Should be a Configure test for double-dots in filenames.
-	version=`echo $revision $patchlevel $subversion | \
-		 $awk '{ printf "%d_%d_%d\n", $1, $2, $3 }'`
-	api_versionstring=`echo $api_revision $api_version $api_subversion | \
-		 $awk '{ printf "%d_%d_%d\n", $1, $2, $3 }'`
+. ./myread
+case "$ans" in
+[yY]*)	fn=d~+
+	rp='Installation prefix to use for vendor-supplied add-ons?'
+	case "$vendorprefix" in
+	'') dflt='' ;;
+	*)  dflt=$vendorprefix ;;
+	esac
+	. ./getfile
+	: XXX Prefixit unit does not yet support siteprefix and vendorprefix
+	oldvendorprefix=''
+	case "$vendorprefix" in
+	'') ;;
+	*)	case "$ans" in
+		"$prefix") ;;
+		*) oldvendorprefix="$prefix";;
+		esac
+		;;
+	esac
+	usevendorprefix="$define"
+	vendorprefix="$ans"
+	vendorprefixexp="$ansexp"
 	;;
-*)
-	version=`echo $revision $patchlevel $subversion | \
-		 $awk '{ printf "%d.%d.%d\n", $1, $2, $3 }'`
-	api_versionstring=`echo $api_revision $api_version $api_subversion | \
-		 $awk '{ printf "%d.%d.%d\n", $1, $2, $3 }'`
+*)	usevendorprefix="$undef"
+	vendorprefix=''
+	vendorprefixexp=''
 	;;
 esac
-: Special case the 5.005_xx maintenance series, which used 5.005
-: without any subversion label as a subdirectory in $sitelib
-if test "${api_revision}${api_version}${api_subversion}" = "550"; then
-	api_versionstring='5.005'
-fi
 
-: determine installation style
-: For now, try to deduce it from prefix unless it is already set.
-: Reproduce behavior of 5.005 and earlier, maybe drop that in 5.7.
-case "$installstyle" in
-'')	case "$prefix" in
-		*perl*) dflt='lib';;
-		*) dflt='lib/perl5' ;;
+case "$vendorprefix" in
+'')	d_vendorlib="$undef"
+	vendorlib=''
+	vendorlibexp=''
+	;;
+*)	d_vendorlib="$define"
+	: determine where vendor-supplied modules go.
+	: Usual default is /usr/local/lib/perl5/vendor_perl/$version
+	case "$vendorlib" in
+	'')
+		prog=`echo $package | $sed 's/-*[0-9.]*$//'`
+		case "$installstyle" in
+		*lib/perl5*) dflt=$vendorprefix/lib/$package/vendor_$prog/$version ;;
+		*)	     dflt=$vendorprefix/lib/vendor_$prog/$version ;;
+		esac
+		;;
+	*)	dflt="$vendorlib"
+		;;
 	esac
+	fn=d~+
+	rp='Pathname for the vendor-supplied library files?'
+	. ./getfile
+	vendorlib="$ans"
+	vendorlibexp="$ansexp"
 	;;
-*)	dflt="$installstyle" ;;
-esac
-: Probably not worth prompting for this since we prompt for all
-: the directories individually, and the prompt would be too long and
-: confusing anyway.
-installstyle=$dflt
-
-: determine where private library files go
-: Usual default is /usr/local/lib/perl5/$version.
-: Also allow things like /opt/perl/lib/$version, since 
-: /opt/perl/lib/perl5... would be redundant.
-: The default "style" setting is made in installstyle.U
-case "$installstyle" in
-*lib/perl5*) set dflt privlib lib/$package/$version ;;
-*)	 set dflt privlib lib/$version ;;
 esac
-eval $prefixit
-$cat <<EOM
-
-There are some auxiliary files for $package that need to be put into a
-private library directory that is accessible by everyone.
-
-EOM
-fn=d~+
-rp='Pathname where the private library files will reside?'
-. ./getfile
-privlib="$ans"
-privlibexp="$ansexp"
+vendorlib_stem=`echo "$vendorlibexp" | sed "s,/$version$,,"`
 : Change installation prefix, if necessary.
 if $test X"$prefix" != X"$installprefix"; then
-	installprivlib=`echo $privlibexp | sed "s#^$prefix#$installprefix#"`
+	installvendorlib=`echo $vendorlibexp | $sed "s#^$prefix#$installprefix#"`
 else
-	installprivlib="$privlibexp"
+	installvendorlib="$vendorlibexp"
 fi
 
-: set the prefixup variable, to restore leading tilda escape
-prefixup='case "$prefixexp" in
-"$prefix") ;;
-*) eval "$1=\`echo \$$1 | sed \"s,^$prefixexp,$prefix,\"\`";;
-esac'
-
-: determine where public architecture dependent libraries go
-set archlib archlib
-eval $prefixit
-: privlib default is /usr/local/lib/$package/$version
-: archlib default is /usr/local/lib/$package/$version/$archname
-: privlib may have an optional trailing /share.
-tdflt=`echo $privlib | $sed 's,/share$,,'`
-tdflt=$tdflt/$archname
-case "$archlib" in
-'')	dflt=$tdflt
+case "$vendorprefix" in
+'')	d_vendorarch="$undef"
+	vendorarch=''
+	vendorarchexp=''
+	;;
+*)	d_vendorarch="$define"
+	: determine where vendor-supplied architecture-dependent libraries go.
+	: vendorlib  default is /usr/local/lib/perl5/vendor_perl/$version
+	: vendorarch default is /usr/local/lib/perl5/vendor_perl/$version/$archname
+	: vendorlib may have an optional trailing /share.
+	case "$vendorarch" in
+	'')	dflt=`echo $vendorlib | $sed 's,/share$,,'`
+		dflt="$dflt/$archname"
+		;;
+	*)	dflt="$vendorarch" ;;
+	esac
+	fn=d~+
+	rp='Pathname for vendor-supplied architecture-dependent files?'
+	. ./getfile
+	vendorarch="$ans"
+	vendorarchexp="$ansexp"
 	;;
-*)	dflt="$archlib"
-    ;;
 esac
-$cat <<EOM
-
-$spackage contains architecture-dependent library files.  If you are
-sharing libraries in a heterogeneous environment, you might store
-these files in a separate location.  Otherwise, you can just include
-them with the rest of the public library files.
-
-EOM
-fn=d+~
-rp='Where do you want to put the public architecture-dependent libraries?'
-. ./getfile
-archlib="$ans"
-archlibexp="$ansexp"
-if $test X"$archlib" = X"$privlib"; then
-	d_archlib="$undef"
-else
-	d_archlib="$define"
-fi
 : Change installation prefix, if necessary.
 if $test X"$prefix" != X"$installprefix"; then
-	installarchlib=`echo $archlibexp | sed "s#^$prefix#$installprefix#"`
+	installvendorarch=`echo $vendorarchexp | sed "s#^$prefix#$installprefix#"`
 else
-	installarchlib="$archlibexp"
+	installvendorarch="$vendorarchexp"
 fi
 
-: see if setuid scripts can be secure
+: Final catch-all directories to search
 $cat <<EOM
 
-Some kernels have a bug that prevents setuid #! scripts from being
-secure.  Some sites have disabled setuid #! scripts because of this.
-
-First let's decide if your kernel supports secure setuid #! scripts.
-(If setuid #! scripts would be secure but have been disabled anyway,
-don't say that they are secure if asked.)
+Lastly, you can have perl look in other directories for extensions and
+modules in addition to those already specified.
+These directories will be searched after 
+	$sitearch 
+	$sitelib 
+EOM
+test X"$vendorlib" != "X" && echo '	' $vendorlib
+test X"$vendorarch" != "X" && echo '	' $vendorarch
+echo ' '
+case "$otherlibdirs" in
+''|' ') dflt='none' ;;
+*)	dflt="$otherlibdirs" ;;
+esac
+$cat <<EOM
+Enter a colon-separated set of extra paths to include in perl's @INC
+search path, or enter 'none' for no extra paths.
 
 EOM
 
-val="$undef"
-if $test -d /dev/fd; then
-	echo "#!$ls" >reflect
-	chmod +x,u+s reflect
-	./reflect >flect 2>&1
-	if $contains "/dev/fd" flect >/dev/null; then
-		echo "Congratulations, your kernel has secure setuid scripts!" >&4
-		val="$define"
-	else
-		$cat <<EOM
-If you are not sure if they are secure, I can check but I'll need a
-username and password different from the one you are using right now.
-If you don't have such a username or don't want me to test, simply
-enter 'none'.
+rp='Colon-separated list of additional directories for perl to search?'
+. ./myread
+case "$ans" in
+' '|''|none)	otherlibdirs=' ' ;;     
+*)	otherlibdirs="$ans" ;;
+esac
+case "$otherlibdirs" in
+' ') val=$undef ;;
+*)	val=$define ;;
+esac
+set d_perl_otherlibdirs
+eval $setvar
 
-EOM
-		rp='Other username to test security of setuid scripts with?'
-		dflt='none'
-		. ./myread
-		case "$ans" in
-		n|none)
-			case "$d_suidsafe" in
-			'')	echo "I'll assume setuid scripts are *not* secure." >&4
-				dflt=n;;
-			"$undef")
-				echo "Well, the $hint value is *not* secure." >&4
-				dflt=n;;
-			*)	echo "Well, the $hint value *is* secure." >&4
-				dflt=y;;
-			esac
-			;;
-		*)
-			$rm -f reflect flect
-			echo "#!$ls" >reflect
-			chmod +x,u+s reflect
-			echo >flect
-			chmod a+w flect
-			echo '"su" will (probably) prompt you for '"$ans's password."
-			su $ans -c './reflect >flect'
-			if $contains "/dev/fd" flect >/dev/null; then
-				echo "Okay, it looks like setuid scripts are secure." >&4
-				dflt=y
-			else
-				echo "I don't think setuid scripts are secure." >&4
-				dflt=n
-			fi
-			;;
-		esac
-		rp='Does your kernel have *secure* setuid scripts?'
-		. ./myread
-		case "$ans" in
-		[yY]*)	val="$define";;
-		*)	val="$undef";;
-		esac
-	fi
+: Cruising for prototypes
+echo " "
+echo "Checking out function prototypes..." >&4
+$cat >prototype.c <<EOCP
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
+int main(int argc, char *argv[]) {
+	exit(0);}
+EOCP
+if $cc $ccflags -c prototype.c >prototype.out 2>&1 ; then
+	echo "Your C compiler appears to support function prototypes."
+	val="$define"
 else
-	echo "I don't think setuid scripts are secure (no /dev/fd directory)." >&4
-	echo "(That's for file descriptors, not floppy disks.)"
+	echo "Your C compiler doesn't seem to understand function prototypes."
 	val="$undef"
 fi
-set d_suidsafe
+set prototype
 eval $setvar
+$rm -f prototype*
 
-$rm -f reflect flect
+case "$prototype" in
+"$define") ;;
+*)	ansi2knr='ansi2knr'
+	echo " "
+	cat <<EOM >&4
 
-: now see if they want to do setuid emulation
-echo " "
-val="$undef"
-case "$d_suidsafe" in
-"$define")
-	val="$undef"
-	echo "No need to emulate SUID scripts since they are secure here." >&4
-	;;
-*)
-	$cat <<EOM
-Some systems have disabled setuid scripts, especially systems where
-setuid scripts cannot be secure.  On systems where setuid scripts have
-been disabled, the setuid/setgid bits on scripts are currently
-useless.  It is possible for $package to detect those bits and emulate
-setuid/setgid in a secure fashion.  This emulation will only work if
-setuid scripts have been disabled in your kernel.
+$me:  FATAL ERROR:
+This version of $package can only be compiled by a compiler that 
+understands function prototypes.  Unfortunately, your C compiler 
+	$cc $ccflags
+doesn't seem to understand them.  Sorry about that.
+
+If GNU cc is available for your system, perhaps you could try that instead.  
 
+Eventually, we hope to support building Perl with pre-ANSI compilers.
+If you would like to help in that effort, please contact <perlbug@perl.org>.
+
+Aborting Configure now.
 EOM
-	case "$d_dosuid" in
-	"$define") dflt=y ;;
-	*) dflt=n ;;
-	esac
-	rp="Do you want to do setuid/setgid emulation?"
-	. ./myread
-	case "$ans" in
-	[yY]*)	val="$define";;
-	*)	val="$undef";;
-	esac
+	exit 2
 	;;
 esac
-set d_dosuid
-eval $setvar
 
-: see if this is a malloc.h system
-set malloc.h i_malloc
-eval $inhdr
+: determine where public executables go
+echo " "
+set dflt bin bin
+eval $prefixit
+fn=d~
+rp='Pathname where the public executables will reside?'
+. ./getfile
+if $test "X$ansexp" != "X$binexp"; then
+	installbin=''
+fi
+bin="$ans"
+binexp="$ansexp"
+: Change installation prefix, if necessary.
+: XXX Bug? -- ignores Configure -Dinstallprefix setting.
+if $test X"$prefix" != X"$installprefix"; then
+	installbin=`echo $binexp | sed "s#^$prefix#$installprefix#"`
+else
+	installbin="$binexp"
+fi
 
-: see if stdlib is available
-set stdlib.h i_stdlib
-eval $inhdr
+echo " "
+case "$extras" in
+'') dflt='n';;
+*) dflt='y';;
+esac
+cat <<EOM
+Perl can be built with extra modules or bundles of modules which
+will be fetched from the CPAN and installed alongside Perl.
 
-: check for void type
+Notice that you will need access to the CPAN; either via the Internet,
+or a local copy, for example a CD-ROM or a local CPAN mirror.  (You will
+be asked later to configure the CPAN.pm module which will in turn do
+the installation of the rest of the extra modules or bundles.)
+
+Notice also that if the modules require any external software such as
+libraries and headers (the libz library and the zlib.h header for the
+Compress::Zlib module, for example) you MUST have any such software
+already installed, this configuration process will NOT install such
+things for you.
+
+If this doesn't make any sense to you, just accept the default '$dflt'.
+EOM
+rp='Install any extra modules (y or n)?'
+. ./myread
+case "$ans" in
+y|Y)
+	cat <<EOM
+
+Please list any extra modules or bundles to be installed from CPAN,
+with spaces between the names.  The names can be in any format the
+'install' command of CPAN.pm will understand.  (Answer 'none',
+without the quotes, to install no extra modules or bundles.)
+EOM
+	rp='Extras?'
+	dflt="$extras"
+	. ./myread
+	extras="$ans"
+esac
+case "$extras" in
+''|'none')
+	val=''
+	$rm -f ../extras.lst
+	;;
+*)	echo "(Saving the list of extras for later...)"
+	echo "$extras" > ../extras.lst
+	val="'$extras'"
+	;;
+esac
+set extras
+eval $setvar
 echo " "
-echo "Checking to see how well your C compiler groks the void type..." >&4
-case "$voidflags" in
-'')
-	$cat >try.c <<'EOCP'
-#if TRY & 1
-void sub() {
-#else
-sub() {
-#endif
-	extern void moo();	/* function returning void */
-	void (*goo)();		/* ptr to func returning void */
-#if TRY & 8
-	void *hue;		/* generic ptr */
-#endif
-#if TRY & 2
-	void (*foo[10])();
-#endif
 
-#if TRY & 4
-	if(goo == moo) {
-		exit(0);
-	}
-#endif
-	exit(0);
-}
-int main() { sub(); }
-EOCP
-	if $cc $ccflags -c -DTRY=$defvoidused try.c >.out 2>&1 ; then
-		voidflags=$defvoidused
-	echo "Good.  It appears to support void to the level $package wants.">&4
-		if $contains warning .out >/dev/null 2>&1; then
-			echo "However, you might get some warnings that look like this:"
-			$cat .out
-		fi
-	else
-echo "Hmm, your compiler has some difficulty with void. Checking further..." >&4
-		if $cc $ccflags -c -DTRY=1 try.c >/dev/null 2>&1; then
-			echo "It supports 1..."
-			if $cc $ccflags -c -DTRY=3 try.c >/dev/null 2>&1; then
-				echo "It also supports 2..."
-				if $cc $ccflags -c -DTRY=7 try.c >/dev/null 2>&1; then
-					voidflags=7
-					echo "And it supports 4 but not 8 definitely."
-				else
-					echo "It doesn't support 4..."
-					if $cc $ccflags -c -DTRY=11 try.c >/dev/null 2>&1; then
-						voidflags=11
-						echo "But it supports 8."
-					else
-						voidflags=3
-						echo "Neither does it support 8."
-					fi
-				fi
-			else
-				echo "It does not support 2..."
-				if $cc $ccflags -c -DTRY=13 try.c >/dev/null 2>&1; then
-					voidflags=13
-					echo "But it supports 4 and 8."
-				else
-					if $cc $ccflags -c -DTRY=5 try.c >/dev/null 2>&1; then
-						voidflags=5
-						echo "And it supports 4 but has not heard about 8."
-					else
-						echo "However it supports 8 but not 4."
-					fi
-				fi
-			fi
-		else
-			echo "There is no support at all for void."
-			voidflags=0
+: Find perl5.005 or later.
+echo "Looking for a previously installed perl5.005 or later... "
+case "$perl5" in
+'')	for tdir in `echo "$binexp$path_sep$PATH" | $sed "s/$path_sep/ /g"`; do
+		: Check if this perl is recent and can load a simple module
+		if $test -x $tdir/perl$exe_ext && $tdir/perl -Mless -e 'use 5.005;' >/dev/null 2>&1; then
+			perl5=$tdir/perl
+			break;
+		elif $test -x $tdir/perl5$exe_ext && $tdir/perl5 -Mless -e 'use 5.005;' >/dev/null 2>&1; then
+			perl5=$tdir/perl5
+			break;
 		fi
-	fi
-esac
-case "$voidflags" in
-"$defvoidused") ;;
-*)	$cat >&4 <<'EOM'
-  Support flag bits are:
-    1: basic void declarations.
-    2: arrays of pointers to functions returning void.
-    4: operations between pointers to and addresses of void functions.
-    8: generic void pointers.
-EOM
-	dflt="$voidflags";
-	rp="Your void support flags add up to what?"
-	. ./myread
-	voidflags="$ans"
+	done
+	;;
+*)	perl5="$perl5"
 	;;
 esac
-$rm -f try.* .out
+case "$perl5" in
+'')	echo "None found.  That's ok.";;
+*)	echo "Using $perl5." ;;
+esac
 
-: check for length of pointer
-echo " "
-case "$ptrsize" in
-'')
-	echo "Checking to see how big your pointers are..." >&4
-	if test "$voidflags" -gt 7; then
-		echo '#define VOID_PTR char *' > try.c
-	else
-		echo '#define VOID_PTR void *' > try.c
-	fi
-	$cat >>try.c <<'EOCP'
-#include <stdio.h>
-int main()
-{
-    printf("%d\n", (int)sizeof(VOID_PTR));
-    exit(0);
+: Determine list of previous versions to include in @INC
+$cat > getverlist <<EOPL
+#!$perl5 -w
+use File::Basename;
+\$api_versionstring = "$api_versionstring";
+\$version = "$version";
+\$stem = "$sitelib_stem";
+\$archname = "$archname";
+EOPL
+	$cat >> getverlist <<'EOPL'
+# Can't have leading @ because metaconfig interprets it as a command!
+;@inc_version_list=();
+# XXX Redo to do opendir/readdir? 
+if (-d $stem) {
+    chdir($stem);
+    ;@candidates = glob("5.*");
 }
-EOCP
-	set try
-	if eval $compile_ok; then
-		ptrsize=`$run ./try`
-		echo "Your pointers are $ptrsize bytes long."
+else {
+    ;@candidates = ();
+}
+
+# XXX ToDo:  These comparisons must be reworked when two-digit
+# subversions come along, so that 5.7.10 compares as greater than
+# 5.7.3!  By that time, hope that 5.6.x is sufficiently
+# widespread that we can use the built-in version vectors rather
+# than reinventing them here.  For 5.6.0, however, we must
+# assume this script will likely be run by 5.005_0x.  --AD 1/2000.
+foreach $d (@candidates) {
+    if ($d lt $version) {
+	if ($d ge $api_versionstring) {
+	    unshift(@inc_version_list, grep { -d } "$d/$archname", $d);
+	}
+	elsif ($d ge "5.005") {
+	    unshift(@inc_version_list, grep { -d } $d);
+	}
+    }
+    else {
+	# Skip newer version.  I.e. don't look in
+	# 5.7.0 if we're installing 5.6.1.
+    }
+}
+
+if (@inc_version_list) {
+    print join(' ', @inc_version_list);
+}
+else {
+    # Blank space to preserve value for next Configure run.
+    print " ";
+}
+EOPL
+chmod +x getverlist
+case "$inc_version_list" in
+'')	if test -x "$perl5$exe_ext"; then
+		dflt=`$perl5 getverlist`
 	else
-		dflt='4'
-		echo "(I can't seem to compile the test program.  Guessing...)" >&4
-		rp="What is the size of a pointer (in bytes)?"
-		. ./myread
-		ptrsize="$ans"
+		dflt='none'
 	fi
 	;;
+$undef) dflt='none' ;;
+*)  eval dflt=\"$inc_version_list\" ;;
 esac
-$rm -f try.c try
-case "$use64bitall" in
-"$define"|true|[yY]*)
-	case "$ptrsize" in
-	4)	cat <<EOM >&4
+case "$dflt" in
+''|' ') dflt=none ;;
+esac
+case "$dflt" in
+5.005) dflt=none ;;
+esac
+$cat <<EOM
 
-*** You have chosen a maximally 64-bit build, but your pointers
-*** are only 4 bytes wide, disabling maximal 64-bitness.
+In order to ease the process of upgrading, this version of perl 
+can be configured to use modules built and installed with earlier 
+versions of perl that were installed under $prefix.  Specify here
+the list of earlier versions that this version of perl should check.
+If Configure detected no earlier versions of perl installed under
+$prefix, then the list will be empty.  Answer 'none' to tell perl
+to not search earlier versions.
 
+The default should almost always be sensible, so if you're not sure,
+just accept the default.
 EOM
-		use64bitall="$undef"
-		case "$use64bitint" in
-		"$define"|true|[yY]*) ;;
-		*)	cat <<EOM >&4
 
-*** Downgrading from maximal 64-bitness to using 64-bit integers.
-
-EOM
-			use64bitint="$define"
-			;;
-		esac
-		;;
-	esac
+rp='List of earlier versions to include in @INC?'
+. ./myread
+case "$ans" in
+[Nn]one|''|' ') inc_version_list=' ' ;;
+*) inc_version_list="$ans" ;;
+esac
+case "$inc_version_list" in
+''|' ') 
+	inc_version_list_init='0';;
+*)	inc_version_list_init=`echo $inc_version_list |
+		$sed -e 's/^/"/' -e 's/ /","/g' -e 's/$/",0/'`
 	;;
 esac
+$rm -f getverlist
 
+: determine whether to install perl also as /usr/bin/perl
 
-: determine which malloc to compile in
 echo " "
-case "$usemymalloc" in
-[yY]*|true|$define)	dflt='y' ;;
-[nN]*|false|$undef)	dflt='n' ;;
-*)	case "$ptrsize" in
-	4) dflt='y' ;;
-	*) dflt='n' ;;
+if $test -d /usr/bin -a "X$installbin" != X/usr/bin; then
+	$cat <<EOM
+Many scripts expect perl to be installed as /usr/bin/perl.
+I can install the perl you are about to compile also as /usr/bin/perl
+(in addition to $installbin/perl).
+EOM
+	case "$installusrbinperl" in
+	"$undef"|[nN]*)	dflt='n';;
+	*)		dflt='y';;
 	esac
-	;;
-esac
-rp="Do you wish to attempt to use the malloc that comes with $package?"
-. ./myread
-usemymalloc="$ans"
-case "$ans" in
-y*|true)
-	usemymalloc='y'
-	mallocsrc='malloc.c'
-	mallocobj="malloc$_o"
-	d_mymalloc="$define"
-	case "$libs" in
-	*-lmalloc*)
-		: Remove malloc from list of libraries to use
-		echo "Removing unneeded -lmalloc from library list" >&4
-		set `echo X $libs | $sed -e 's/-lmalloc / /' -e 's/-lmalloc$//'`
-		shift
-		libs="$*"
-		echo "libs = $libs" >&4
-		;;
+	rp="Do you want to install perl as /usr/bin/perl?"
+	. ./myread
+	case "$ans" in
+	[yY]*)	val="$define";;
+	*)	val="$undef" ;;
 	esac
-	;;
-*)
-	usemymalloc='n'
-	mallocsrc=''
-	mallocobj=''
-	d_mymalloc="$undef"
-	;;
-esac
+else
+	val="$undef"
+fi
+set installusrbinperl
+eval $setvar
 
-: compute the return types of malloc and free
 echo " "
-$cat >malloc.c <<END
-#$i_malloc I_MALLOC
-#$i_stdlib I_STDLIB
+echo "Checking for GNU C Library..." >&4
+cat >try.c <<'EOCP'
+/* Find out version of GNU C library.  __GLIBC__ and __GLIBC_MINOR__
+   alone are insufficient to distinguish different versions, such as
+   2.0.6 and 2.0.7.  The function gnu_get_libc_version() appeared in
+   libc version 2.1.0.      A. Dougherty,  June 3, 2002.
+*/
 #include <stdio.h>
-#include <sys/types.h>
-#ifdef I_MALLOC
-#include <malloc.h>
-#endif
-#ifdef I_STDLIB
-#include <stdlib.h>
-#endif
-#ifdef TRY_MALLOC
-void *malloc();
-#endif
-#ifdef TRY_FREE
-void free();
+int main(void)
+{
+#ifdef __GLIBC__
+#   ifdef __GLIBC_MINOR__
+#       if __GLIBC__ >= 2 && __GLIBC_MINOR__ >= 1
+#           include <gnu/libc-version.h>
+	    printf("%s\n",  gnu_get_libc_version());
+#       else
+	    printf("%d.%d\n",  __GLIBC__, __GLIBC_MINOR__);
+#       endif
+#   else
+	printf("%d\n",  __GLIBC__);
+#   endif
+    return 0;
+#else
+    return 1;
 #endif
-END
-case "$malloctype" in
-'')
-	if $cc $ccflags -c -DTRY_MALLOC malloc.c >/dev/null 2>&1; then
-		malloctype='void *'
-	else
-		malloctype='char *'
-	fi
-	;;
-esac
-echo "Your system wants malloc to return '$malloctype', it would seem." >&4
+}
+EOCP
+set try
+if eval $compile_ok && $run ./try > glibc.ver; then
+	val="$define"
+	gnulibc_version=`$cat glibc.ver`
+	echo "You are using the GNU C Library version $gnulibc_version"
+else
+	val="$undef"
+	gnulibc_version=''
+	echo "You are not using the GNU C Library"
+fi
+$rm -f try try.* glibc.ver
+set d_gnulibc
+eval $setvar
 
-case "$freetype" in
+: see if nm is to be used to determine whether a symbol is defined or not
+case "$usenm" in
 '')
-	if $cc $ccflags -c -DTRY_FREE malloc.c >/dev/null 2>&1; then
-		freetype='void'
-	else
-		freetype='int'
-	fi
+	dflt=''
+	case "$d_gnulibc" in
+	"$define")
+		echo " "
+		echo "nm probably won't work on the GNU C Library." >&4
+		dflt=n
+		;;
+	esac
+	case "$dflt" in
+	'') 
+		if $test "$osname" = aix -a "X$PASE" != "Xdefine" -a ! -f /lib/syscalls.exp; then
+			echo " "
+			echo "Whoops!  This is an AIX system without /lib/syscalls.exp!" >&4
+			echo "'nm' won't be sufficient on this sytem." >&4
+			dflt=n
+		fi
+		;;
+	esac
+	case "$dflt" in
+	'') dflt=`$egrep 'inlibc|csym' $rsrc/Configure | wc -l 2>/dev/null`
+		if $test $dflt -gt 20; then
+			dflt=y
+		else
+			dflt=n
+		fi
+		;;
+	esac
+	;;
+*)
+	case "$usenm" in
+	true|$define) dflt=y;;
+	*) dflt=n;;
+	esac
 	;;
 esac
-echo "Your system uses $freetype free(), it would seem." >&4
-$rm -f malloc.[co]
 $cat <<EOM
 
-After $package is installed, you may wish to install various
-add-on modules and utilities.  Typically, these add-ons will
-be installed under $prefix with the rest
-of this package.  However, you may wish to install such add-ons
-elsewhere under a different prefix.
-
-If you do not wish to put everything under a single prefix, that's
-ok.  You will be prompted for the individual locations; this siteprefix
-is only used to suggest the defaults.
+I can use $nm to extract the symbols from your C libraries. This
+is a time consuming task which may generate huge output on the disk (up
+to 3 megabytes) but that should make the symbols extraction faster. The
+alternative is to skip the 'nm' extraction part and to compile a small
+test program instead to determine whether each symbol is present. If
+you have a fast C compiler and/or if your 'nm' output cannot be parsed,
+this may be the best solution.
 
-The default should be fine for most people.
+You probably shouldn't let me use 'nm' if you are using the GNU C Library.
 
 EOM
-fn=d~+
-rp='Installation prefix to use for add-on modules and utilities?'
-: XXX Here might be another good place for an installstyle setting.
-case "$siteprefix" in
-'') dflt=$prefix ;;
-*)  dflt=$siteprefix ;;
+rp="Shall I use $nm to extract C symbols from the libraries?"
+. ./myread
+case "$ans" in
+[Nn]*) usenm=false;;
+*) usenm=true;;
 esac
-. ./getfile
-: XXX Prefixit unit does not yet support siteprefix and vendorprefix
-oldsiteprefix=''
-case "$siteprefix" in
-'') ;;
-*)	case "$ans" in
-	"$prefix") ;;
-	*) oldsiteprefix="$prefix";;
-	esac
-	;;
+
+runnm=$usenm
+case "$reuseval" in
+true) runnm=false;;
 esac
-siteprefix="$ans"
-siteprefixexp="$ansexp"
 
-: determine where site specific libraries go.
-: Usual default is /usr/local/lib/perl5/site_perl/$version
-: The default "style" setting is made in installstyle.U
-: XXX No longer works with Prefixit stuff.
-prog=`echo $package | $sed 's/-*[0-9.]*$//'`
-case "$sitelib" in
-'') case "$installstyle" in
-	*lib/perl5*) dflt=$siteprefix/lib/$package/site_$prog/$version ;;
-	*)	 dflt=$siteprefix/lib/site_$prog/$version ;;
+: nm options which may be necessary
+case "$nm_opt" in
+'') if $test -f /mach_boot; then
+		nm_opt=''	# Mach
+	elif $test -d /usr/ccs/lib; then
+		nm_opt='-p'	# Solaris (and SunOS?)
+	elif $test -f /dgux; then
+		nm_opt='-p'	# DG-UX
+	elif $test -f /lib64/rld; then
+		nm_opt='-p'	# 64-bit Irix
+	else
+		nm_opt=''
+	fi;;
+esac
+
+: nm options which may be necessary for shared libraries but illegal
+: for archive libraries.  Thank you, Linux.
+case "$nm_so_opt" in
+'')	case "$myuname" in
+	*linux*)
+		if $nm --help | $grep 'dynamic' > /dev/null 2>&1; then
+			nm_so_opt='--dynamic'
+		fi
+		;;
 	esac
 	;;
-*)	dflt="$sitelib"
-	;;
 esac
-$cat <<EOM
-
-The installation process will create a directory for
-site-specific extensions and modules.  Most users find it convenient
-to place all site-specific files in this directory rather than in the
-main distribution directory.
-
-EOM
-fn=d~+
-rp='Pathname for the site-specific library files?'
-. ./getfile
-sitelib="$ans"
-sitelibexp="$ansexp"
-sitelib_stem=`echo "$sitelibexp" | sed "s,/$version$,,"`
-: Change installation prefix, if necessary.
-if $test X"$prefix" != X"$installprefix"; then
-	installsitelib=`echo $sitelibexp | $sed "s#^$prefix#$installprefix#"`
-else
-	installsitelib="$sitelibexp"
-fi
 
-: determine where site specific architecture-dependent libraries go.
-: sitelib  default is /usr/local/lib/perl5/site_perl/$version
-: sitearch default is /usr/local/lib/perl5/site_perl/$version/$archname
-: sitelib may have an optional trailing /share.
-case "$sitearch" in
-'')	dflt=`echo $sitelib | $sed 's,/share$,,'`
-	dflt="$dflt/$archname"
+case "$runnm" in
+true)
+: get list of predefined functions in a handy place
+echo " "
+case "$libc" in
+'') libc=unknown
+	case "$libs" in
+	*-lc_s*) libc=`./loc libc_s$_a $libc $libpth`
+	esac
 	;;
-*)	dflt="$sitearch"
+esac
+case "$libs" in
+'') ;;
+*)  for thislib in $libs; do
+	case "$thislib" in
+	-lc|-lc_s)
+		: Handle C library specially below.
+		;;
+	-l*)
+		thislib=`echo $thislib | $sed -e 's/^-l//'`
+		if try=`./loc lib$thislib.$so.'*' X $libpth`; $test -f "$try"; then
+			:
+		elif try=`./loc lib$thislib.$so X $libpth`; $test -f "$try"; then
+			:
+		elif try=`./loc lib$thislib$_a X $libpth`; $test -f "$try"; then
+			:
+		elif try=`./loc $thislib$_a X $libpth`; $test -f "$try"; then
+			:
+		elif try=`./loc lib$thislib X $libpth`; $test -f "$try"; then
+			:
+		elif try=`./loc $thislib X $libpth`; $test -f "$try"; then
+			:
+		elif try=`./loc Slib$thislib$_a X $xlibpth`; $test -f "$try"; then
+			:
+		else
+			try=''
+		fi
+		libnames="$libnames $try"
+		;;
+	*) libnames="$libnames $thislib" ;;
+	esac
+	done
 	;;
 esac
-set sitearch sitearch none
-eval $prefixit
-$cat <<EOM
-
-The installation process will also create a directory for
-architecture-dependent site-specific extensions and modules.
-
-EOM
-fn=d~+
-rp='Pathname for the site-specific architecture-dependent library files?'
-. ./getfile
-sitearch="$ans"
-sitearchexp="$ansexp"
-: Change installation prefix, if necessary.
-if $test X"$prefix" != X"$installprefix"; then
-	installsitearch=`echo $sitearchexp | sed "s#^$prefix#$installprefix#"`
-else
-	installsitearch="$sitearchexp"
-fi
-
-$cat <<EOM
-
-The installation process will also create a directory for
-vendor-supplied add-ons.  Vendors who supply perl with their system
-may find it convenient to place all vendor-supplied files in this
-directory rather than in the main distribution directory.  This will
-ease upgrades between binary-compatible maintenance versions of perl.
-
-Of course you may also use these directories in whatever way you see
-fit.  For example, you might use them to access modules shared over a
-company-wide network.
-
-The default answer should be fine for most people.
-This causes further questions about vendor add-ons to be skipped
-and no vendor-specific directories will be configured for perl.
-
-EOM
-rp='Do you want to configure vendor-specific add-on directories?'
-case "$usevendorprefix" in
-define|true|[yY]*) dflt=y ;;
-*)	: User may have set vendorprefix directly on Configure command line.
-	case "$vendorprefix" in
-	''|' ') dflt=n ;;
-	*)	dflt=y ;;
-	esac
-	;;
-esac
-. ./myread
-case "$ans" in
-[yY]*)	fn=d~+
-	rp='Installation prefix to use for vendor-supplied add-ons?'
-	case "$vendorprefix" in
-	'') dflt='' ;;
-	*)  dflt=$vendorprefix ;;
-	esac
-	. ./getfile
-	: XXX Prefixit unit does not yet support siteprefix and vendorprefix
-	oldvendorprefix=''
-	case "$vendorprefix" in
-	'') ;;
-	*)	case "$ans" in
-		"$prefix") ;;
-		*) oldvendorprefix="$prefix";;
-		esac
-		;;
-	esac
-	usevendorprefix="$define"
-	vendorprefix="$ans"
-	vendorprefixexp="$ansexp"
-	;;
-*)	usevendorprefix="$undef"
-	vendorprefix=''
-	vendorprefixexp=''
-	;;
-esac
-
-case "$vendorprefix" in
-'')	d_vendorlib="$undef"
-	vendorlib=''
-	vendorlibexp=''
-	;;
-*)	d_vendorlib="$define"
-	: determine where vendor-supplied modules go.
-	: Usual default is /usr/local/lib/perl5/vendor_perl/$version
-	case "$vendorlib" in
-	'')
-		prog=`echo $package | $sed 's/-*[0-9.]*$//'`
-		case "$installstyle" in
-		*lib/perl5*) dflt=$vendorprefix/lib/$package/vendor_$prog/$version ;;
-		*)	     dflt=$vendorprefix/lib/vendor_$prog/$version ;;
-		esac
-		;;
-	*)	dflt="$vendorlib"
-		;;
-	esac
-	fn=d~+
-	rp='Pathname for the vendor-supplied library files?'
-	. ./getfile
-	vendorlib="$ans"
-	vendorlibexp="$ansexp"
-	;;
-esac
-vendorlib_stem=`echo "$vendorlibexp" | sed "s,/$version$,,"`
-: Change installation prefix, if necessary.
-if $test X"$prefix" != X"$installprefix"; then
-	installvendorlib=`echo $vendorlibexp | $sed "s#^$prefix#$installprefix#"`
-else
-	installvendorlib="$vendorlibexp"
-fi
-
-case "$vendorprefix" in
-'')	d_vendorarch="$undef"
-	vendorarch=''
-	vendorarchexp=''
+xxx=normal
+case "$libc" in
+unknown)
+	set /lib/libc.$so
+	for xxx in $libpth; do
+		$test -r $1 || set $xxx/libc.$so
+		: The messy sed command sorts on library version numbers.
+		$test -r $1 || \
+			set `echo blurfl; echo $xxx/libc.$so.[0-9]* | \
+			tr ' ' $trnl | egrep -v '\.[A-Za-z]*$' | $sed -e '
+				h
+				s/[0-9][0-9]*/0000&/g
+				s/0*\([0-9][0-9][0-9][0-9][0-9]\)/\1/g
+				G
+				s/\n/ /' | \
+			 $sort | $sed -e 's/^.* //'`
+		eval set \$$#
+	done
+	$test -r $1 || set /usr/ccs/lib/libc.$so
+	$test -r $1 || set /lib/libsys_s$_a
 	;;
-*)	d_vendorarch="$define"
-	: determine where vendor-supplied architecture-dependent libraries go.
-	: vendorlib  default is /usr/local/lib/perl5/vendor_perl/$version
-	: vendorarch default is /usr/local/lib/perl5/vendor_perl/$version/$archname
-	: vendorlib may have an optional trailing /share.
-	case "$vendorarch" in
-	'')	dflt=`echo $vendorlib | $sed 's,/share$,,'`
-		dflt="$dflt/$archname"
-		;;
-	*)	dflt="$vendorarch" ;;
-	esac
-	fn=d~+
-	rp='Pathname for vendor-supplied architecture-dependent files?'
-	. ./getfile
-	vendorarch="$ans"
-	vendorarchexp="$ansexp"
+*)
+	set blurfl
 	;;
 esac
-: Change installation prefix, if necessary.
-if $test X"$prefix" != X"$installprefix"; then
-	installvendorarch=`echo $vendorarchexp | sed "s#^$prefix#$installprefix#"`
+if $test -r "$1"; then
+	echo "Your (shared) C library seems to be in $1."
+	libc="$1"
+elif $test -r /lib/libc && $test -r /lib/clib; then
+	echo "Your C library seems to be in both /lib/clib and /lib/libc."
+	xxx=apollo
+	libc='/lib/clib /lib/libc'
+	if $test -r /lib/syslib; then
+		echo "(Your math library is in /lib/syslib.)"
+		libc="$libc /lib/syslib"
+	fi
+elif $test -r "$libc" || (test -h "$libc") >/dev/null 2>&1; then
+	echo "Your C library seems to be in $libc, as you said before."
+elif $test -r $incpath/usr/lib/libc$_a; then
+	libc=$incpath/usr/lib/libc$_a;
+	echo "Your C library seems to be in $libc.  That's fine."
+elif $test -r /lib/libc$_a; then
+	libc=/lib/libc$_a;
+	echo "Your C library seems to be in $libc.  You're normal."
 else
-	installvendorarch="$vendorarchexp"
+	if tans=`./loc libc$_a blurfl/dyick $libpth`; $test -r "$tans"; then
+		:
+	elif tans=`./loc libc blurfl/dyick $libpth`; $test -r "$tans"; then
+		libnames="$libnames "`./loc clib blurfl/dyick $libpth`
+	elif tans=`./loc clib blurfl/dyick $libpth`; $test -r "$tans"; then
+		:
+	elif tans=`./loc Slibc$_a blurfl/dyick $xlibpth`; $test -r "$tans"; then
+		:
+	elif tans=`./loc Mlibc$_a blurfl/dyick $xlibpth`; $test -r "$tans"; then
+		:
+	else
+		tans=`./loc Llibc$_a blurfl/dyick $xlibpth`
+	fi
+	if $test -r "$tans"; then
+		echo "Your C library seems to be in $tans, of all places."
+		libc=$tans
+	else
+		libc='blurfl'
+	fi
 fi
+if $test $xxx = apollo -o -r "$libc" || (test -h "$libc") >/dev/null 2>&1; then
+	dflt="$libc"
+	cat <<EOM
 
-: Final catch-all directories to search
-$cat <<EOM
+If the guess above is wrong (which it might be if you're using a strange
+compiler, or your machine supports multiple models), you can override it here.
 
-Lastly, you can have perl look in other directories for extensions and
-modules in addition to those already specified.
-These directories will be searched after 
-	$sitearch 
-	$sitelib 
 EOM
-test X"$vendorlib" != "X" && echo '	' $vendorlib
-test X"$vendorarch" != "X" && echo '	' $vendorarch
-echo ' '
-case "$otherlibdirs" in
-''|' ') dflt='none' ;;
-*)	dflt="$otherlibdirs" ;;
-esac
-$cat <<EOM
-Enter a colon-separated set of extra paths to include in perl's @INC
-search path, or enter 'none' for no extra paths.
+else
+	dflt=''
+	echo $libpth | $tr ' ' $trnl | $sort | $uniq > libpath
+	cat >&4 <<EOM
+I can't seem to find your C library.  I've looked in the following places:
 
 EOM
+	$sed 's/^/	/' libpath
+	cat <<EOM
 
-rp='Colon-separated list of additional directories for perl to search?'
-. ./myread
-case "$ans" in
-' '|''|none)	otherlibdirs=' ' ;;     
-*)	otherlibdirs="$ans" ;;
-esac
-case "$otherlibdirs" in
-' ') val=$undef ;;
-*)	val=$define ;;
-esac
-set d_perl_otherlibdirs
-eval $setvar
+None of these seems to contain your C library. I need to get its name...
 
-: Cruising for prototypes
-echo " "
-echo "Checking out function prototypes..." >&4
-$cat >prototype.c <<'EOCP'
-int main(int argc, char *argv[]) {
-	exit(0);}
-EOCP
-if $cc $ccflags -c prototype.c >prototype.out 2>&1 ; then
-	echo "Your C compiler appears to support function prototypes."
-	val="$define"
-else
-	echo "Your C compiler doesn't seem to understand function prototypes."
-	val="$undef"
+EOM
 fi
-set prototype
-eval $setvar
-$rm -f prototype*
-
-case "$prototype" in
-"$define") ;;
-*)	ansi2knr='ansi2knr'
-	echo " "
-	cat <<EOM >&4
+fn=f
+rp='Where is your C library?'
+. ./getfile
+libc="$ans"
 
-$me:  FATAL ERROR:
-This version of $package can only be compiled by a compiler that 
-understands function prototypes.  Unfortunately, your C compiler 
-	$cc $ccflags
-doesn't seem to understand them.  Sorry about that.
-
-If GNU cc is available for your system, perhaps you could try that instead.  
-
-Eventually, we hope to support building Perl with pre-ANSI compilers.
-If you would like to help in that effort, please contact <perlbug@perl.org>.
-
-Aborting Configure now.
-EOM
-	exit 2
-	;;
-esac
-
-: determine where public executables go
 echo " "
-set dflt bin bin
-eval $prefixit
-fn=d~
-rp='Pathname where the public executables will reside?'
-. ./getfile
-if $test "X$ansexp" != "X$binexp"; then
-	installbin=''
-fi
-bin="$ans"
-binexp="$ansexp"
-: Change installation prefix, if necessary.
-: XXX Bug? -- ignores Configure -Dinstallprefix setting.
-if $test X"$prefix" != X"$installprefix"; then
-	installbin=`echo $binexp | sed "s#^$prefix#$installprefix#"`
-else
-	installbin="$binexp"
-fi
-
+echo $libc $libnames | $tr ' ' $trnl | $sort | $uniq > libnames
+set X `cat libnames`
+shift
+xxx=files
+case $# in 1) xxx=file; esac
+echo "Extracting names from the following $xxx for later perusal:" >&4
 echo " "
-case "$extras" in
-'') dflt='n';;
-*) dflt='y';;
-esac
-cat <<EOM
-Perl can be built with extra modules or bundles of modules which
-will be fetched from the CPAN and installed alongside Perl.
-
-Notice that you will need access to the CPAN; either via the Internet,
-or a local copy, for example a CD-ROM or a local CPAN mirror.  (You will
-be asked later to configure the CPAN.pm module which will in turn do
-the installation of the rest of the extra modules or bundles.)
-
-Notice also that if the modules require any external software such as
-libraries and headers (the libz library and the zlib.h header for the
-Compress::Zlib module, for example) you MUST have any such software
-already installed, this configuration process will NOT install such
-things for you.
-
-If this doesn't make any sense to you, just accept the default '$dflt'.
-EOM
-rp='Install any extra modules (y or n)?'
-. ./myread
-case "$ans" in
-y|Y)
-	cat <<EOM
-
-Please list any extra modules or bundles to be installed from CPAN,
-with spaces between the names.  The names can be in any format the
-'install' command of CPAN.pm will understand.  (Answer 'none',
-without the quotes, to install no extra modules or bundles.)
-EOM
-	rp='Extras?'
-	dflt="$extras"
-	. ./myread
-	extras="$ans"
-esac
-case "$extras" in
-''|'none')
-	val=''
-	$rm -f ../extras.lst
-	;;
-*)	echo "(Saving the list of extras for later...)"
-	echo "$extras" > ../extras.lst
-	val="'$extras'"
-	;;
-esac
-set extras
-eval $setvar
+$sed 's/^/	/' libnames >&4
 echo " "
+$echo $n "This may take a while...$c" >&4
 
-: Find perl5.005 or later.
-echo "Looking for a previously installed perl5.005 or later... "
-case "$perl5" in
-'')	for tdir in `echo "$binexp$path_sep$PATH" | $sed "s/$path_sep/ /g"`; do
-		: Check if this perl is recent and can load a simple module
-		if $test -x $tdir/perl$exe_ext && $tdir/perl -Mless -e 'use 5.005;' >/dev/null 2>&1; then
-			perl5=$tdir/perl
-			break;
-		elif $test -x $tdir/perl5$exe_ext && $tdir/perl5 -Mless -e 'use 5.005;' >/dev/null 2>&1; then
-			perl5=$tdir/perl5
-			break;
-		fi
-	done
-	;;
-*)	perl5="$perl5"
-	;;
-esac
-case "$perl5" in
-'')	echo "None found.  That's ok.";;
-*)	echo "Using $perl5." ;;
-esac
-
-: Determine list of previous versions to include in @INC
-$cat > getverlist <<EOPL
-#!$perl5 -w
-use File::Basename;
-\$api_versionstring = "$api_versionstring";
-\$version = "$version";
-\$stem = "$sitelib_stem";
-\$archname = "$archname";
-EOPL
-	$cat >> getverlist <<'EOPL'
-# Can't have leading @ because metaconfig interprets it as a command!
-;@inc_version_list=();
-# XXX Redo to do opendir/readdir? 
-if (-d $stem) {
-    chdir($stem);
-    ;@candidates = glob("5.*");
-}
-else {
-    ;@candidates = ();
-}
-
-# XXX ToDo:  These comparisons must be reworked when two-digit
-# subversions come along, so that 5.7.10 compares as greater than
-# 5.7.3!  By that time, hope that 5.6.x is sufficiently
-# widespread that we can use the built-in version vectors rather
-# than reinventing them here.  For 5.6.0, however, we must
-# assume this script will likely be run by 5.005_0x.  --AD 1/2000.
-foreach $d (@candidates) {
-    if ($d lt $version) {
-	if ($d ge $api_versionstring) {
-	    unshift(@inc_version_list, grep { -d } "$d/$archname", $d);
-	}
-	elsif ($d ge "5.005") {
-	    unshift(@inc_version_list, grep { -d } $d);
-	}
-    }
-    else {
-	# Skip newer version.  I.e. don't look in
-	# 5.7.0 if we're installing 5.6.1.
-    }
-}
+for file in $*; do
+	case $file in
+	*$so*) $nm $nm_so_opt $nm_opt $file 2>/dev/null;;
+	*) $nm $nm_opt $file 2>/dev/null;;
+	esac
+done >libc.tmp
 
-if (@inc_version_list) {
-    print join(' ', @inc_version_list);
-}
-else {
-    # Blank space to preserve value for next Configure run.
-    print " ";
-}
-EOPL
-chmod +x getverlist
-case "$inc_version_list" in
-'')	if test -x "$perl5$exe_ext"; then
-		dflt=`$perl5 getverlist`
+$echo $n ".$c"
+$grep fprintf libc.tmp > libc.ptf
+xscan='eval "<libc.ptf $com >libc.list"; $echo $n ".$c" >&4'
+xrun='eval "<libc.tmp $com >libc.list"; echo "done." >&4'
+xxx='[ADTSIW]'
+if com="$sed -n -e 's/__IO//' -e 's/^.* $xxx  *//p'";\
+	eval $xscan;\
+	$contains '^fprintf$' libc.list >/dev/null 2>&1; then
+		eval $xrun
+elif com="$sed -n -e 's/^__*//' -e 's/^\([a-zA-Z_0-9$]*\).*xtern.*/\1/p'";\
+	eval $xscan;\
+	$contains '^fprintf$' libc.list >/dev/null 2>&1; then
+		eval $xrun
+elif com="$sed -n -e '/|UNDEF/d' -e '/FUNC..GL/s/^.*|__*//p'";\
+	eval $xscan;\
+	$contains '^fprintf$' libc.list >/dev/null 2>&1; then
+		eval $xrun
+elif com="$sed -n -e 's/^.* D __*//p' -e 's/^.* D //p'";\
+	eval $xscan;\
+	$contains '^fprintf$' libc.list >/dev/null 2>&1; then
+		eval $xrun
+elif com="$sed -n -e 's/^_//' -e 's/^\([a-zA-Z_0-9]*\).*xtern.*text.*/\1/p'";\
+	eval $xscan;\
+	$contains '^fprintf$' libc.list >/dev/null 2>&1; then
+		eval $xrun
+elif com="$sed -n -e 's/^.*|FUNC |GLOB .*|//p'";\
+	eval $xscan;\
+	$contains '^fprintf$' libc.list >/dev/null 2>&1; then
+		eval $xrun
+elif com="$grep '|' | $sed -n -e '/|COMMON/d' -e '/|DATA/d' \
+				-e '/ file/d' -e 's/^\([^ 	]*\).*/\1/p'";\
+	eval $xscan;\
+	$contains '^fprintf$' libc.list >/dev/null 2>&1; then
+		eval $xrun
+elif com="$sed -n -e 's/^.*|FUNC |GLOB .*|//p' -e 's/^.*|FUNC |WEAK .*|//p'";\
+	eval $xscan;\
+	$contains '^fprintf$' libc.list >/dev/null 2>&1; then
+		eval $xrun
+elif com="$sed -n -e 's/^__//' -e '/|Undef/d' -e '/|Proc/s/ .*//p'";\
+	eval $xscan;\
+	$contains '^fprintf$' libc.list >/dev/null 2>&1; then
+		eval $xrun
+elif com="$sed -n -e 's/^.*|Proc .*|Text *| *//p'";\
+	eval $xscan;\
+	$contains '^fprintf$' libc.list >/dev/null 2>&1; then
+		eval $xrun
+elif com="$sed -n -e '/Def. Text/s/.* \([^ ]*\)\$/\1/p'";\
+	eval $xscan;\
+	$contains '^fprintf$' libc.list >/dev/null 2>&1; then
+		eval $xrun
+elif com="$sed -n -e 's/^[-0-9a-f ]*_\(.*\)=.*/\1/p'";\
+	eval $xscan;\
+	$contains '^fprintf$' libc.list >/dev/null 2>&1; then
+		eval $xrun
+elif com="$sed -n -e 's/.*\.text n\ \ \ \.//p'";\
+	eval $xscan;\
+	$contains '^fprintf$' libc.list >/dev/null 2>&1; then
+		eval $xrun
+elif com="sed -n -e 's/^__.*//' -e 's/[       ]*D[    ]*[0-9]*.*//p'";\
+	eval $xscan;\
+	$contains '^fprintf$' libc.list >/dev/null 2>&1; then
+		eval $xrun
+else
+	$nm -p $* 2>/dev/null >libc.tmp
+	$grep fprintf libc.tmp > libc.ptf
+	if com="$sed -n -e 's/^.* [ADTSIW]  *_[_.]*//p' -e 's/^.* [ADTSIW] //p'";\
+		eval $xscan; $contains '^fprintf$' libc.list >/dev/null 2>&1
+	then
+		nm_opt='-p'
+		eval $xrun
 	else
-		dflt='none'
+		echo " "
+		echo "$nm didn't seem to work right. Trying $ar instead..." >&4
+		com=''
+		if $ar t $libc > libc.tmp && $contains '^fprintf$' libc.tmp >/dev/null 2>&1; then
+			for thisname in $libnames $libc; do
+				$ar t $thisname >>libc.tmp
+			done
+			$sed -e "s/\\$_o\$//" < libc.tmp > libc.list
+			echo "Ok." >&4
+		elif test "X$osname" = "Xos2" && $ar tv $libc > libc.tmp; then
+			# Repeat libc to extract forwarders to DLL entries too
+			for thisname in $libnames $libc; do
+				$ar tv $thisname >>libc.tmp
+				# Revision 50 of EMX has bug in $ar.
+				# it will not extract forwarders to DLL entries
+				# Use emximp which will extract exactly them.
+				emximp -o tmp.imp $thisname \
+				    2>/dev/null && \
+				    $sed -e 's/^\([_a-zA-Z0-9]*\) .*$/\1/p' \
+				    < tmp.imp >>libc.tmp
+				$rm tmp.imp
+			done
+			$sed -e "s/\\$_o\$//" -e 's/^ \+//' < libc.tmp > libc.list
+			echo "Ok." >&4
+		else
+			echo "$ar didn't seem to work right." >&4
+			echo "Maybe this is a Cray...trying bld instead..." >&4
+			if bld t $libc | $sed -e 's/.*\///' -e "s/\\$_o:.*\$//" > libc.list
+			then
+				for thisname in $libnames; do
+					bld t $libnames | \
+					$sed -e 's/.*\///' -e "s/\\$_o:.*\$//" >>libc.list
+					$ar t $thisname >>libc.tmp
+				done
+				echo "Ok." >&4
+			else
+				echo "That didn't work either.  Giving up." >&4
+				exit 1
+			fi
+		fi
 	fi
-	;;
-$undef) dflt='none' ;;
-*)  eval dflt=\"$inc_version_list\" ;;
-esac
-case "$dflt" in
-''|' ') dflt=none ;;
-esac
-case "$dflt" in
-5.005) dflt=none ;;
-esac
-$cat <<EOM
-
-In order to ease the process of upgrading, this version of perl 
-can be configured to use modules built and installed with earlier 
-versions of perl that were installed under $prefix.  Specify here
-the list of earlier versions that this version of perl should check.
-If Configure detected no earlier versions of perl installed under
-$prefix, then the list will be empty.  Answer 'none' to tell perl
-to not search earlier versions.
-
-The default should almost always be sensible, so if you're not sure,
-just accept the default.
-EOM
-
-rp='List of earlier versions to include in @INC?'
-. ./myread
-case "$ans" in
-[Nn]one|''|' ') inc_version_list=' ' ;;
-*) inc_version_list="$ans" ;;
+fi
+nm_extract="$com"
+case "$PASE" in
+define)
+    echo " "
+    echo "Since you are compiling for PASE, extracting more symbols from libc.a ...">&4
+    dump -Tv /lib/libc.a | awk '$7 == "/unix" {print $5 " " $8}' | grep "^SV" | awk '{print $2}' >> libc.list
+    ;;
+*)  if $test -f /lib/syscalls.exp; then
+	echo " "
+	echo "Also extracting names from /lib/syscalls.exp for good ole AIX..." >&4
+	$sed -n 's/^\([^ 	]*\)[ 	]*syscall[0-9]*[ 	]*$/\1/p' /lib/syscalls.exp >>libc.list
+    fi
+    ;;
 esac
-case "$inc_version_list" in
-''|' ') 
-	inc_version_list_init='0';;
-*)	inc_version_list_init=`echo $inc_version_list |
-		$sed -e 's/^/"/' -e 's/ /","/g' -e 's/$/",0/'`
-	;;
+;;
 esac
-$rm -f getverlist
-
-: determine whether to install perl also as /usr/bin/perl
-
-echo " "
-if $test -d /usr/bin -a "X$installbin" != X/usr/bin; then
-	$cat <<EOM
-Many scripts expect perl to be installed as /usr/bin/perl.
-I can install the perl you are about to compile also as /usr/bin/perl
-(in addition to $installbin/perl).
-EOM
-	case "$installusrbinperl" in
-	"$undef"|[nN]*)	dflt='n';;
-	*)		dflt='y';;
-	esac
-	rp="Do you want to install perl as /usr/bin/perl?"
-	. ./myread
-	case "$ans" in
-	[yY]*)	val="$define";;
-	*)	val="$undef" ;;
-	esac
-else
-	val="$undef"
-fi
-set installusrbinperl
-eval $setvar
+$rm -f libnames libpath
 
 : see if dld is available
 set dld.h i_dld
 eval $inhdr
 
+: is a C symbol defined?
+csym='tlook=$1;
+case "$3" in
+-v) tf=libc.tmp; tdc="";;
+-a) tf=libc.tmp; tdc="[]";;
+*) tlook="^$1\$"; tf=libc.list; tdc="()";;
+esac;
+tx=yes;
+case "$reuseval-$4" in
+true-) ;;
+true-*) tx=no; eval "tval=\$$4"; case "$tval" in "") tx=yes;; esac;;
+esac;
+case "$tx" in
+yes)
+	tval=false;
+	if $test "$runnm" = true; then
+		if $contains $tlook $tf >/dev/null 2>&1; then
+			tval=true;
+		elif $test "$mistrustnm" = compile -o "$mistrustnm" = run; then
+			echo "void *(*(p()))$tdc { extern void *$1$tdc; return &$1; } int main() { if(p()) return(0); else return(1); }"> try.c;
+			$cc -o try $optimize $ccflags $ldflags try.c >/dev/null 2>&1 $libs && tval=true;
+			$test "$mistrustnm" = run -a -x try && { $run ./try$_exe >/dev/null 2>&1 || tval=false; };
+			$rm -f try$_exe try.c core core.* try.core;
+		fi;
+	else
+		echo "void *(*(p()))$tdc { extern void *$1$tdc; return &$1; } int main() { if(p()) return(0); else return(1); }"> try.c;
+		$cc -o try $optimize $ccflags $ldflags try.c $libs >/dev/null 2>&1 && tval=true;
+		$rm -f try$_exe try.c;
+	fi;
+	;;
+*)
+	case "$tval" in
+	$define) tval=true;;
+	*) tval=false;;
+	esac;
+	;;
+esac;
+eval "$2=$tval"'
+
+: define an is-in-libc? function
+inlibc='echo " "; td=$define; tu=$undef;
+sym=$1; var=$2; eval "was=\$$2";
+tx=yes;
+case "$reuseval$was" in
+true) ;;
+true*) tx=no;;
+esac;
+case "$tx" in
+yes)
+	set $sym tres -f;
+	eval $csym;
+	case "$tres" in
+	true)
+		echo "$sym() found." >&4;
+		case "$was" in $undef) . ./whoa; esac; eval "$var=\$td";;
+	*)
+		echo "$sym() NOT found." >&4;
+		case "$was" in $define) . ./whoa; esac; eval "$var=\$tu";;
+	esac;;
+*)
+	case "$was" in
+	$define) echo "$sym() found." >&4;;
+	*) echo "$sym() NOT found." >&4;;
+	esac;;
+esac'
+
 : see if dlopen exists
 xxx_runnm="$runnm"
 runnm=false
@@ -7511,10 +7321,13 @@ while other systems (such as those using ELF) use $cc.
 
 EOM
 	case "$ld" in
-	'')	$cat >try.c <<'EOM'
+	'')	$cat >try.c <<EOM
 /* Test for whether ELF binaries are produced */
 #include <fcntl.h>
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
 #include <stdlib.h>
+#endif
 int main() {
 	char b[4];
 	int i = open("a.out",O_RDONLY);
@@ -7792,7 +7605,7 @@ if "$useshrplib"; then
 	solaris)
 		xxx="-R $shrpdir"
 		;;
-	freebsd|netbsd)
+	freebsd|netbsd|openbsd)
 		xxx="-Wl,-R$shrpdir"
 		;;
 	bsdos|linux|irix*|dec_osf)
@@ -8639,6 +8452,10 @@ echo "Checking the size of $zzz..." >&4
 cat > try.c <<EOCP
 #include <sys/types.h>
 #include <stdio.h>
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
 int main() {
     printf("%d\n", (int)sizeof($fpostype));
     exit(0);
@@ -8743,9 +8560,13 @@ EOCP
 		$cat > try.c <<EOCP
 #include <sys/types.h>
 #include <stdio.h>
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
 int main() {
     printf("%d\n", (int)sizeof($fpostype));
-    exit(0);
+    return(0);
 }
 EOCP
 		set try
@@ -9055,7 +8876,7 @@ eval $inlibc
 case "$d_access" in
 "$define")
 	echo " "
-	$cat >access.c <<'EOCP'
+	$cat >access.c <<EOCP
 #include <sys/types.h>
 #ifdef I_FCNTL
 #include <fcntl.h>
@@ -9066,6 +8887,10 @@ case "$d_access" in
 #ifdef I_UNISTD
 #include <unistd.h>
 #endif
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
 int main() {
 	exit(R_OK);
 }
@@ -9203,7 +9028,7 @@ echo " "
 if test "X$timeincl" = X; then
 	echo "Testing to see if we should include <time.h>, <sys/time.h> or both." >&4
 	$echo $n "I'm now running the test program...$c"
-	$cat >try.c <<'EOCP'
+	$cat >try.c <<EOCP
 #include <sys/types.h>
 #ifdef I_TIME
 #include <time.h>
@@ -9217,6 +9042,10 @@ if test "X$timeincl" = X; then
 #ifdef I_SYSSELECT
 #include <sys/select.h>
 #endif
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
 int main()
 {
 	struct tm foo;
@@ -9382,7 +9211,7 @@ echo " "
 echo "Checking whether your compiler can handle __attribute__ ..." >&4
 $cat >attrib.c <<'EOCP'
 #include <stdio.h>
-void croak (char* pat,...) __attribute__((format(printf,1,2),noreturn));
+void croak (char* pat,...) __attribute__((__format__(__printf__,1,2),noreturn));
 EOCP
 if $cc $ccflags -c attrib.c >attrib.out 2>&1 ; then
 	if $contains 'warning' attrib.out >/dev/null 2>&1; then
@@ -9426,6 +9255,10 @@ case "$d_getpgrp" in
 #ifdef I_UNISTD
 #  include <unistd.h>
 #endif
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
 int main()
 {
 	if (getuid() == 0) {
@@ -9488,6 +9321,10 @@ case "$d_setpgrp" in
 #ifdef I_UNISTD
 #  include <unistd.h>
 #endif
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
 int main()
 {
 	if (getuid() == 0) {
@@ -9593,6 +9430,10 @@ else
 fi
 $cat >try.c <<EOCP
 #include <stdio.h>
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
 #include <sys/types.h>
 #include <signal.h>
 $signal_t blech(s) int s; { exit(3); }
@@ -9647,6 +9488,10 @@ echo " "
 echo 'Checking whether your C compiler can cast negative float to unsigned.' >&4
 $cat >try.c <<EOCP
 #include <stdio.h>
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
 #include <sys/types.h>
 #include <signal.h>
 $signal_t blech(s) int s; { exit(7); }
@@ -9743,8 +9588,12 @@ echo " "
 if set vprintf val -f d_vprintf; eval $csym; $val; then
 	echo 'vprintf() found.' >&4
 	val="$define"
-	$cat >try.c <<'EOF'
+	$cat >try.c <<EOF
 #include <varargs.h>
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
 
 int main() { xxx("foo"); }
 
@@ -10283,6 +10132,10 @@ eval $inhdr
 echo " "
 $cat >dirfd.c <<EOM
 #include <stdio.h>
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
 #$i_dirent I_DIRENT		/**/
 #$i_sysdir I_SYS_DIR		/**/
 #$i_sysndir I_SYS_NDIR		/**/
@@ -10375,6 +10228,10 @@ EOM
 $cat >fred.c<<EOM
 
 #include <stdio.h>
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
 #$i_dlfcn I_DLFCN
 #ifdef I_DLFCN
 #include <dlfcn.h>      /* the dynamic linker include file for SunOS/Solaris */
@@ -10912,7 +10769,7 @@ esac
 
 : Locate the flags for 'open()'
 echo " "
-$cat >try.c <<'EOCP'
+$cat >try.c <<EOCP
 #include <sys/types.h>
 #ifdef I_FCNTL
 #include <fcntl.h>
@@ -10920,6 +10777,10 @@ $cat >try.c <<'EOCP'
 #ifdef I_SYS_FILE
 #include <sys/file.h>
 #endif
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
 int main() {
 	if(O_RDONLY);
 #ifdef O_TRUNC
@@ -11052,7 +10913,10 @@ case "$o_nonblock" in
 	$cat head.c > try.c
 	$cat >>try.c <<EOCP
 #include <stdio.h>
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
 #include <stdlib.h>
+#endif
 #$i_fcntl I_FCNTL
 #ifdef I_FCNTL
 #include <fcntl.h>
@@ -11098,7 +10962,10 @@ case "$eagain" in
 #include <sys/types.h>
 #include <signal.h>
 #include <stdio.h> 
-#include <stdlib.h> 
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
 #$i_fcntl I_FCNTL
 #ifdef I_FCNTL
 #include <fcntl.h>
@@ -11258,7 +11125,10 @@ eval $inlibc
 echo " "
 : See if fcntl-based locking works.
 $cat >try.c <<EOCP
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
 #include <stdlib.h>
+#endif
 #include <unistd.h>
 #include <fcntl.h>
 #include <signal.h>
@@ -11325,6 +11195,10 @@ $cat <<EOM
 Checking to see how well your C compiler handles fd_set and friends ...
 EOM
 $cat >try.c <<EOCP
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
 #$i_systime I_SYS_TIME
 #$i_sysselct I_SYS_SELECT
 #$d_socket HAS_SOCKET
@@ -11864,6 +11738,10 @@ case "$d_gethostbyaddr_r" in
 	./protochk "extern $try" $hdrs && gethostbyaddr_r_proto=I_CII ;;
 	esac
 	case "$gethostbyaddr_r_proto" in
+	''|0) try='int gethostbyaddr_r(const void*, socklen_t, int, struct hostent*, char*, size_t, struct hostent**, int*);'
+	./protochk "extern $try" $hdrs && gethostbyaddr_r_proto=I_TsISBWRE ;;
+	esac
+	case "$gethostbyaddr_r_proto" in
 	''|0)	d_gethostbyaddr_r=undef
  	        gethostbyaddr_r_proto=0
 		echo "Disabling gethostbyaddr_r, cannot determine prototype." >&4 ;;
@@ -12125,6 +12003,10 @@ case "$d_getnetbyaddr_r" in
 	./protochk "extern $try" $hdrs && getnetbyaddr_r_proto=I_IISD ;;
 	esac
 	case "$getnetbyaddr_r_proto" in
+	''|0) try='int getnetbyaddr_r(uint32_t, int, struct netent*, char*, size_t, struct netent**, int*);'
+	./protochk "extern $try" $hdrs && getnetbyaddr_r_proto=I_uISBWRE ;;
+	esac
+	case "$getnetbyaddr_r_proto" in
 	''|0)	d_getnetbyaddr_r=undef
  	        getnetbyaddr_r_proto=0
 		echo "Disabling getnetbyaddr_r, cannot determine prototype." >&4 ;;
@@ -13005,9 +12887,13 @@ eval $inlibc
 
 : Look for isascii
 echo " "
-$cat >isascii.c <<'EOCP'
+$cat >isascii.c <<EOCP
 #include <stdio.h>
 #include <ctype.h>
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
 int main() {
 	int c = 'A';
 	if (isascii(c))
@@ -13352,8 +13238,12 @@ echo " "
 case "$charsize" in
 '')
 	echo "Checking to see how big your characters are (hey, you never know)..." >&4
-	$cat >try.c <<'EOCP'
+	$cat >try.c <<EOCP
 #include <stdio.h>
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
 int main()
 {
     printf("%d\n", (int)sizeof(char));
@@ -13593,6 +13483,10 @@ if test X"$d_volatile" = X"$define"; then
 fi
 $cat <<EOP >try.c
 #include <stdio.h>
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
 #include <sys/types.h>
 #include <signal.h>
 #ifdef SIGFPE
@@ -13887,7 +13781,15 @@ case "$d_random_r" in
 	define)
 	case "$random_r_proto" in
 	''|0) try='int random_r(int*, struct random_data*);'
-	./protochk "extern $try" $hdrs && random_r_proto=I_TS ;;
+	./protochk "extern $try" $hdrs && random_r_proto=I_iS ;;
+	esac
+	case "$random_r_proto" in
+	''|0) try='int random_r(long*, struct random_data*);'
+	./protochk "extern $try" $hdrs && random_r_proto=I_lS ;;
+	esac
+	case "$random_r_proto" in
+	''|0) try='int random_r(struct random_data*, int32_t*);'
+	./protochk "extern $try" $hdrs && random_r_proto=I_St ;;
 	esac
 	case "$random_r_proto" in
 	''|0)	d_random_r=undef
@@ -14363,7 +14265,7 @@ $define)
 #endif
 END
 
-    $cat > try.c <<END
+      $cat > try.c <<END
 #include <sys/types.h>
 #include <sys/ipc.h>
 #include <sys/sem.h>
@@ -14410,14 +14312,14 @@ int main() {
 }
 END
     val="$undef"
-    set try
-    if eval $compile; then
-	xxx=`$run ./try`
-        case "$xxx" in
-        semun) val="$define" ;;
-        esac
-    fi
-    $rm -f try try.c
+      set try
+      if eval $compile; then
+	  xxx=`$run ./try`
+          case "$xxx" in
+          semun) val="$define" ;;
+          esac
+      fi
+      $rm -f try try.c
     set d_semctl_semun
     eval $setvar
     case "$d_semctl_semun" in
@@ -14431,7 +14333,7 @@ END
     esac
 
     : see whether semctl IPC_STAT can use struct semid_ds pointer
-    $cat > try.c <<'END'
+      $cat > try.c <<'END'
 #include <sys/types.h>
 #include <sys/ipc.h>
 #include <sys/sem.h>
@@ -15065,10 +14967,14 @@ echo " "
 : see if we have sigaction
 if set sigaction val -f d_sigaction; eval $csym; $val; then
 	echo 'sigaction() found.' >&4
-	$cat > try.c <<'EOP'
+	$cat > try.c <<EOP
 #include <stdio.h>
 #include <sys/types.h>
 #include <signal.h>
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
 int main()
 {
     struct sigaction act, oact;
@@ -15100,8 +15006,12 @@ eval $inlibc
 echo " "
 case "$d_sigsetjmp" in
 '')
-	$cat >try.c <<'EOP'
+	$cat >try.c <<EOP
 #include <setjmp.h>
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
 sigjmp_buf env;
 int set = 1;
 int main()
@@ -16182,6 +16092,10 @@ I'm now running the test program...
 EOM
 		$cat >try.c <<EOCP
 #include <stdio.h>
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
 #include <sys/types.h>
 typedef $uvtype UV;
 int main()
@@ -16244,6 +16158,10 @@ EOM
 case "$d_u32align" in
 '')   $cat >try.c <<EOCP
 #include <stdio.h>
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
 #define U32 $u32type
 #define BYTEORDER 0x$byteorder
 #define U8 $u8type
@@ -16595,6 +16513,10 @@ $define)
 #endif
 #include <sys/types.h>
 #include <stdio.h>
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
 #include <db.h>
 int main(int argc, char *argv[])
 {
@@ -16933,6 +16855,10 @@ sunos) $echo '#define PERL_FFLUSH_ALL_FOPEN_MAX 32' > try.c ;;
 esac
 $cat >>try.c <<EOCP
 #include <stdio.h>
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
 #$i_unistd I_UNISTD
 #ifdef I_UNISTD
 # include <unistd.h>
@@ -17249,6 +17175,10 @@ echo "Checking the size of $zzz..." >&4
 cat > try.c <<EOCP
 #include <sys/types.h>
 #include <stdio.h>
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
 int main() {
     printf("%d\n", (int)sizeof($gidtype));
     exit(0);
@@ -17959,7 +17889,11 @@ echo " "
 echo "Checking how to generate random libraries on your machine..." >&4
 echo 'int bar1() { return bar2(); }' > bar1.c
 echo 'int bar2() { return 2; }' > bar2.c
-$cat > foo.c <<'EOP'
+$cat > foo.c <<EOP
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
 int main() { printf("%d\n", bar1()); exit(0); }
 EOP
 $cc $ccflags -c bar1.c >/dev/null 2>&1
@@ -18049,7 +17983,8 @@ esac
 
 : check for the select 'width'
 case "$selectminbits" in
-'') case "$d_select" in
+'') safebits=`expr $ptrsize \* 8`
+    case "$d_select" in
 	$define)
 		$cat <<EOM
 
@@ -18081,25 +18016,31 @@ EOM
 #   include <sys/socket.h> /* Might include <sys/bsdtypes.h> */
 #endif
 #include <stdio.h>
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
 $selecttype b;
 #define S sizeof(*(b))
 #define MINBITS	64
 #define NBYTES (S * 8 > MINBITS ? S : MINBITS/8)
 #define NBITS  (NBYTES * 8)
 int main() {
-    char s[NBYTES];
+    char *s = malloc(NBYTES);
     struct timeval t;
     int i;
     FILE* fp;
     int fd;
 
+    if (!s)
+	exit(1);
     fclose(stdin);
     fp = fopen("try.c", "r");
     if (fp == 0)
-      exit(1);
+      exit(2);
     fd = fileno(fp);
     if (fd < 0)
-      exit(2);
+      exit(3);
     b = ($selecttype)s;
     for (i = 0; i < NBITS; i++)
 	FD_SET(i, b);
@@ -18107,6 +18048,7 @@ int main() {
     t.tv_usec = 0;
     select(fd + 1, b, 0, 0, &t);
     for (i = NBITS - 1; i > fd && FD_ISSET(i, b); i--);
+    free(s);
     printf("%d\n", i + 1);
     return 0;
 }
@@ -18117,10 +18059,10 @@ EOCP
 			case "$selectminbits" in
 			'')	cat >&4 <<EOM
 Cannot figure out on how many bits at a time your select() operates.
-I'll play safe and guess it is 32 bits.
+I'll play safe and guess it is $safebits bits.
 EOM
-				selectminbits=32
-				bits="32 bits"
+				selectminbits=$safebits
+				bits="$safebits bits"
 				;;
 			1)	bits="1 bit" ;;
 			*)	bits="$selectminbits bits" ;;
@@ -18129,7 +18071,8 @@ EOM
 		else
 			rp='What is the minimum number of bits your select() operates on?'
 			case "$byteorder" in
-			1234|12345678)	dflt=32 ;;
+			12345678)	dflt=64 ;;
+			1234)		dflt=32 ;;
 			*)		dflt=1	;;
 			esac
 			. ./myread
@@ -18139,7 +18082,7 @@ EOM
 		$rm -f try.* try
 		;;
 	*)	: no select, so pick a harmless default
-		selectminbits='32'
+		selectminbits=$safebits
 		;;
 	esac
 	;;
@@ -18186,9 +18129,13 @@ xxx="$xxx SYS TERM THAW TRAP TSTP TTIN TTOU URG USR1 USR2"
 xxx="$xxx USR3 USR4 VTALRM WAITING WINCH WIND WINDOW XCPU XFSZ"
 
 : generate a few handy files for later
-$cat > signal.c <<'EOCP'
+$cat > signal.c <<EOCP
 #include <sys/types.h>
 #include <signal.h>
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
 #include <stdio.h>
 int main() {
 
@@ -18263,7 +18210,7 @@ END {
 $cat >signal.awk <<'EOP'
 BEGIN { ndups = 0 }
 $1 ~ /^NSIG$/ { nsig = $2 }
-($1 !~ /^NSIG$/) && (NF == 2) {
+($1 !~ /^NSIG$/) && (NF == 2) && ($2 ~ /^[0-9][0-9]*$/) {
     if ($2 > maxsig) { maxsig = $2 }
     if (sig_name[$2]) {
 	dup_name[ndups] = $1
@@ -18416,6 +18363,10 @@ echo "Checking the size of $zzz..." >&4
 cat > try.c <<EOCP
 #include <sys/types.h>
 #include <stdio.h>
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
 int main() {
     printf("%d\n", (int)sizeof($sizetype));
     exit(0);
@@ -18519,6 +18470,10 @@ eval $typedef
 dflt="$ssizetype"
 $cat > try.c <<EOM
 #include <stdio.h>
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
 #include <sys/types.h>
 #define Size_t $sizetype
 #define SSize_t $dflt
@@ -18601,6 +18556,10 @@ echo "Checking the size of $zzz..." >&4
 cat > try.c <<EOCP
 #include <sys/types.h>
 #include <stdio.h>
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
 int main() {
     printf("%d\n", (int)sizeof($uidtype));
     exit(0);
@@ -19424,7 +19383,19 @@ Note that DynaLoader is always built and need not be mentioned here.
 
 EOM
 	case "$dynamic_ext" in
-	'') dflt="$avail_ext" ;;
+	'')
+		: Exclude those listed in static_ext
+		dflt=''
+		for xxx in $avail_ext; do
+			case " $static_ext " in
+			*" $xxx "*) ;;
+			*) dflt="$dflt $xxx" ;;
+			esac
+		done
+		set X $dflt
+		shift
+		dflt="$*"
+		;;
 	*)	dflt="$dynamic_ext"
 		# Perhaps we are reusing an old out-of-date config.sh.
 		case "$hint" in
PATCH
}

1;
