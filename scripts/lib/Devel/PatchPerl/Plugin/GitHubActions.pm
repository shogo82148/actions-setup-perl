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
            qr/^5\.8\.0$/,
            qr/^5\.6\./,
        ],
        subs => [
            [ \&_patch_configure ],
        ],
    },
    {
        perl => [
            qr/^5\.6\./,
        ],
        subs => [
            [ \&_patch_perl_h ],
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

    system("find . -name '*.rej' -exec cat '{}' ';'");
    system("cp", "Configure.orig", "$ENV{GITHUB_WORKSPACE}");
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

sub _patch_perl_h {
    _patch(<<'PATCH');
--- perl.h
+++ perl.h
@@ -2064,6 +2064,12 @@ struct ptr_tbl {
 #  define htovs(x)	vtohs(x)
 # endif
 	/* otherwise default to functions in util.c */
+#ifndef htovs
+short htovs(short n);
+short vtohs(short n);
+long htovl(long n);
+long vtohl(long n);
+#endif
 #endif
 
 #ifdef CASTNEGFLOAT
PATCH
}

sub _patch_configure {
    my $version = shift;
    if (_ge($version, "5.8.0")) {
        _patch(<<'PATCH');
--- Configure
+++ Configure
@@ -2152,9 +2152,10 @@ for dir in \$*; do
 	elif test -f \$dir/\$thing.exe; then
 		if test -n "$DJGPP"; then
 			echo \$dir/\$thing.exe
-		else
+		elif test "$eunicefix" != ":"; then
 			: on Eunice apparently
 			echo \$dir/\$thing
+			exit 0
 		fi
 		exit 0
 	fi
@@ -3791,7 +3792,7 @@ int main() {
 	printf("%s\n", "1");
 #endif
 #endif
-	exit(0);
+	return(0);
 }
 EOM
 if $cc -o try $ccflags $ldflags try.c; then
@@ -3799,7 +3800,7 @@ if $cc -o try $ccflags $ldflags try.c; then
 	case "$gccversion" in
 	'') echo "You are not using GNU cc." ;;
 	*)  echo "You are using GNU cc $gccversion."
-	    ccname=gcc	
+	    ccname=gcc
 	    ;;
 	esac
 else
@@ -3852,14 +3853,17 @@ case "$ccname" in
 '') ccname="$cc" ;;
 esac
 
-# gcc 3.1 complains about adding -Idirectories that it already knows about,
+# gcc 3.* complain about adding -Idirectories that they already know about,
 # so we will take those off from locincpth.
 case "$gccversion" in
 3.*)
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
@@ -4466,6 +4470,50 @@ case "$firstmakefile" in
 '') firstmakefile='makefile';;
 esac
 
+case "$ccflags" in
+*-DUSE_LONG_DOUBLE*|*-DUSE_MORE_BITS*) uselongdouble="$define" ;;
+esac
+
+case "$uselongdouble" in
+$define|true|[yY]*)	dflt='y';;
+*) dflt='n';;
+esac
+cat <<EOM
+
+Perl can be built to take advantage of long doubles which
+(if available) may give more accuracy and range for floating point numbers.
+
+If this doesn't make any sense to you, just accept the default '$dflt'.
+EOM
+rp='Try to use long doubles if available?'
+. ./myread
+case "$ans" in
+y|Y) 	val="$define"	;;
+*)      val="$undef"	;;
+esac
+set uselongdouble
+eval $setvar
+
+case "$uselongdouble" in
+true|[yY]*) uselongdouble="$define" ;;
+esac
+
+case "$uselongdouble" in
+$define)
+: Look for a hint-file generated 'call-back-unit'.  If the
+: user has specified that long doubles should be used,
+: we may need to set or change some other defaults.
+	if $test -f uselongdouble.cbu; then
+		echo "Your platform has some specific hints for long doubles, using them..."
+		. ./uselongdouble.cbu
+	else
+		$cat <<EOM
+(Your platform doesn't have any specific hints for long doubles.)
+EOM
+	fi
+	;;
+esac
+
 : Looking for optional libraries
 echo " "
 echo "Checking for optional libraries..." >&4
@@ -4813,7 +4861,7 @@ echo " "
 echo "Checking your choice of C compiler and flags for coherency..." >&4
 $cat > try.c <<'EOF'
 #include <stdio.h>
-int main() { printf("Ok\n"); exit(0); }
+int main() { printf("Ok\n"); return(0); }
 EOF
 set X $cc -o try $optimize $ccflags $ldflags try.c $libs
 shift
@@ -4897,100 +4945,6 @@ mc_file=$1;
 shift;
 $cc -o ${mc_file} $optimize $ccflags $ldflags $* ${mc_file}.c $libs;'
 
-: check for lengths of integral types
-echo " "
-case "$intsize" in
-'')
-	echo "Checking to see how big your integers are..." >&4
-	$cat >try.c <<'EOCP'
-#include <stdio.h>
-int main()
-{
-	printf("intsize=%d;\n", (int)sizeof(int));
-	printf("longsize=%d;\n", (int)sizeof(long));
-	printf("shortsize=%d;\n", (int)sizeof(short));
-	exit(0);
-}
-EOCP
-	set try
-	if eval $compile_ok && $run ./try > /dev/null; then
-		eval `$run ./try`
-		echo "Your integers are $intsize bytes long."
-		echo "Your long integers are $longsize bytes long."
-		echo "Your short integers are $shortsize bytes long."
-	else
-		$cat >&4 <<EOM
-!
-Help! I can't compile and run the intsize test program: please enlighten me!
-(This is probably a misconfiguration in your system or libraries, and
-you really ought to fix it.  Still, I'll try anyway.)
-!
-EOM
-		dflt=4
-		rp="What is the size of an integer (in bytes)?"
-		. ./myread
-		intsize="$ans"
-		dflt=$intsize
-		rp="What is the size of a long integer (in bytes)?"
-		. ./myread
-		longsize="$ans"
-		dflt=2
-		rp="What is the size of a short integer (in bytes)?"
-		. ./myread
-		shortsize="$ans"
-	fi
-	;;
-esac
-$rm -f try try.*
-
-: check for long long
-echo " "
-echo "Checking to see if you have long long..." >&4
-echo 'int main() { long long x = 7; return 0; }' > try.c
-set try
-if eval $compile; then
-	val="$define"
-	echo "You have long long."
-else
-	val="$undef"
-	echo "You do not have long long."
-fi
-$rm try.*
-set d_longlong
-eval $setvar
-
-: check for length of long long
-case "${d_longlong}${longlongsize}" in
-$define)
-	echo " "
-	echo "Checking to see how big your long longs are..." >&4
-	$cat >try.c <<'EOCP'
-#include <stdio.h>
-int main()
-{
-    printf("%d\n", (int)sizeof(long long));
-    return(0);
-}
-EOCP
-	set try
-	if eval $compile_ok; then
-		longlongsize=`$run ./try`
-		echo "Your long longs are $longlongsize bytes long."
-	else
-		dflt='8'
-		echo " "
-		echo "(I can't seem to compile the test program.  Guessing...)"
-		rp="What is the size of a long long (in bytes)?"
-		. ./myread
-		longlongsize="$ans"
-	fi
-	if $test "X$longsize" = "X$longlongsize"; then
-		echo "(That isn't any different from an ordinary long.)"
-	fi	
-	;;
-esac
-$rm -f try.* try
-
 : determine filename position in cpp output
 echo " "
 echo "Computing filename position in cpp output for #include directives..." >&4
@@ -5100,6 +5054,108 @@ do set $yyy; var=$2; eval "was=\$$2";
 	set $yyy; shift; shift; yyy=$@;
 done'
 
+: see if stdlib is available
+set stdlib.h i_stdlib
+eval $inhdr
+
+: check for lengths of integral types
+echo " "
+case "$intsize" in
+'')
+	echo "Checking to see how big your integers are..." >&4
+	$cat >try.c <<EOCP
+#include <stdio.h>
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
+int main()
+{
+	printf("intsize=%d;\n", (int)sizeof(int));
+	printf("longsize=%d;\n", (int)sizeof(long));
+	printf("shortsize=%d;\n", (int)sizeof(short));
+	exit(0);
+}
+EOCP
+	set try
+	if eval $compile_ok && $run ./try > /dev/null; then
+		eval `$run ./try`
+		echo "Your integers are $intsize bytes long."
+		echo "Your long integers are $longsize bytes long."
+		echo "Your short integers are $shortsize bytes long."
+	else
+		$cat >&4 <<EOM
+!
+Help! I can't compile and run the intsize test program: please enlighten me!
+(This is probably a misconfiguration in your system or libraries, and
+you really ought to fix it.  Still, I'll try anyway.)
+!
+EOM
+		dflt=4
+		rp="What is the size of an integer (in bytes)?"
+		. ./myread
+		intsize="$ans"
+		dflt=$intsize
+		rp="What is the size of a long integer (in bytes)?"
+		. ./myread
+		longsize="$ans"
+		dflt=2
+		rp="What is the size of a short integer (in bytes)?"
+		. ./myread
+		shortsize="$ans"
+	fi
+	;;
+esac
+$rm -f try try.*
+
+: check for long long
+echo " "
+echo "Checking to see if you have long long..." >&4
+echo 'int main() { long long x = 7; return 0; }' > try.c
+set try
+if eval $compile; then
+	val="$define"
+	echo "You have long long."
+else
+	val="$undef"
+	echo "You do not have long long."
+fi
+$rm try.*
+set d_longlong
+eval $setvar
+
+: check for length of long long
+case "${d_longlong}${longlongsize}" in
+$define)
+	echo " "
+	echo "Checking to see how big your long longs are..." >&4
+	$cat >try.c <<'EOCP'
+#include <stdio.h>
+int main()
+{
+    printf("%d\n", (int)sizeof(long long));
+    return(0);
+}
+EOCP
+	set try
+	if eval $compile_ok; then
+		longlongsize=`$run ./try`
+		echo "Your long longs are $longlongsize bytes long."
+	else
+		dflt='8'
+		echo " "
+		echo "(I can't seem to compile the test program.  Guessing...)"
+		rp="What is the size of a long long (in bytes)?"
+		. ./myread
+		longlongsize="$ans"
+	fi
+	if $test "X$longsize" = "X$longlongsize"; then
+		echo "(That isn't any different from an ordinary long.)"
+	fi	
+	;;
+esac
+$rm -f try.* try
+
 : see if inttypes.h is available
 : we want a real compile instead of Inhdr because some systems
 : have an inttypes.h which includes non-existent headers
@@ -5378,1040 +5434,335 @@ case "$use64bitall" in
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
+	;;
+esac
+$rm -f try.* try
+
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
+esac
+case "$targetarch" in
+'') ;;
+*)  archname=`echo $targetarch|sed 's,^[^-]*-,,'` ;;
+esac
+myarchname="$tarch"
+case "$archname" in
+'') dflt="$tarch";;
+*) dflt="$archname";;
+esac
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
+	;;
+esac
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
+	;;
+esac
+case "$use64bitint$use64bitall" in
+*"$define"*)
+	case "$archname64" in
+	'')
+		echo "This architecture is naturally 64-bit, not changing architecture name." >&4
 		;;
-	esac
-	case "$dflt" in
-	'') 
-		if $test "$osname" = aix -a ! -f /lib/syscalls.exp; then
-			echo " "
-			echo "Whoops!  This is an AIX system without /lib/syscalls.exp!" >&4
-			echo "'nm' won't be sufficient on this sytem." >&4
-			dflt=n
-		fi
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
 		;;
 	esac
-	case "$dflt" in
-	'') dflt=`$egrep 'inlibc|csym' $rsrc/Configure | wc -l 2>/dev/null`
-		if $test $dflt -gt 20; then
-			dflt=y
-		else
-			dflt=n
-		fi
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
 	esac
 	;;
+esac
+case "$useperlio" in
+$define)
+	echo "Perlio selected." >&4
+	;;
 *)
-	case "$usenm" in
-	true|$define) dflt=y;;
-	*) dflt=n;;
-	esac
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
-$cat <<EOM
 
-I can use $nm to extract the symbols from your C libraries. This
-is a time consuming task which may generate huge output on the disk (up
-to 3 megabytes) but that should make the symbols extraction faster. The
-alternative is to skip the 'nm' extraction part and to compile a small
-test program instead to determine whether each symbol is present. If
-you have a fast C compiler and/or if your 'nm' output cannot be parsed,
-this may be the best solution.
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
 
-You probably shouldn't let me use 'nm' if you are using the GNU C Library.
+By default, $package will be installed in $dflt/bin, manual pages
+under $dflt/man, etc..., i.e. with $dflt as prefix for all
+installation directories. Typically this is something like /usr/local.
+If you wish to have binaries under /usr/bin but other parts of the
+installation under /usr/local, that's ok: you will be prompted
+separately for each of the installation directories, the prefix being
+only used to set the defaults.
 
 EOM
-rp="Shall I use $nm to extract C symbols from the libraries?"
-. ./myread
-case "$ans" in
-[Nn]*) usenm=false;;
-*) usenm=true;;
-esac
-
-runnm=$usenm
-case "$reuseval" in
-true) runnm=false;;
-esac
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
-esac
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
 	esac
 	;;
 esac
+prefix="$ans"
+prefixexp="$ansexp"
 
-case "$runnm" in
-true)
-: get list of predefined functions in a handy place
-echo " "
-case "$libc" in
-'') libc=unknown
-	case "$libs" in
-	*-lc_s*) libc=`./loc libc_s$_a $libc $libpth`
-	esac
-	;;
-esac
-case "$libs" in
-'') ;;
-*)  for thislib in $libs; do
-	case "$thislib" in
-	-lc|-lc_s)
-		: Handle C library specially below.
-		;;
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
-		;;
-	*) libnames="$libnames $thislib" ;;
-	esac
-	done
-	;;
+case "$afsroot" in
+'')	afsroot=/afs ;;
+*)	afsroot=$afsroot ;;
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
-	;;
-*)
-	set blurfl
+
+: is AFS running?
+echo " "
+case "$afs" in
+$define|true)	afs=true ;;
+$undef|false)	afs=false ;;
+*)	if test -d $afsroot; then
+		afs=true
+	else
+		afs=false
+	fi
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
+if $afs; then
+	echo "AFS may be running... I'll be extra cautious then..." >&4
 else
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
-	else
-		libc='blurfl'
-	fi
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
-
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
+installprefix="$ans"
+installprefixexp="$ansexp"
 
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
-else
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
-fi
-nm_extract="$com"
-if $test -f /lib/syscalls.exp; then
-	echo " "
-	echo "Also extracting names from /lib/syscalls.exp for good ole AIX..." >&4
-	$sed -n 's/^\([^ 	]*\)[ 	]*syscall[0-9]*[ 	]*$/\1/p' /lib/syscalls.exp >>libc.list
-fi
-;;
-esac
-$rm -f libnames libpath
-
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
-
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
-*)
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
-	;;
-esac
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
-fi
-$rm try.*
-set d_longdbl
-eval $setvar
-
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
-	;;
-esac
-$rm -f try.* try
-
-echo " "
-
-if $test X"$d_longdbl" = X"$define"; then
-
-echo "Checking how to print long doubles..." >&4
-
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
-fi
-
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
-
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
-
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
-
-if $test X"$sPRIfldbl" = X; then
-	echo "Cannot figure out how to print long doubles." >&4
-else
-	sSCNfldbl=$sPRIfldbl	# expect consistency
-fi
-
-$rm -f try try.*
-
-fi # d_longdbl
-
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
-
-: see if modfl exists
-set modfl d_modfl
-eval $inlibc
-
-d_modfl_pow32_bug="$undef"
-
-case "$d_longdbl$d_modfl" in
-$define$define)
-	$cat <<EOM
-Checking to see whether your modfl() is okay for large values...
-EOM
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
-			esac
-			;;
-		*" 4294967303.150000 0.150000 4294967303.000000")
-			echo >&4 "Your modfl() seems okay for large values."
-			;;
-		*)	echo >&4 "I don't understand your modfl() at all."
-			d_modfl="$undef"
-			;;
-		esac
-		$rm -f try.* try core core.try.*
-	else
-		echo "I cannot figure out whether your modfl() is okay, assuming it isn't."
-		d_modfl="$undef"
-	fi
-	case "$osname:$gccversion" in
-	aix:)	ccflags="$saveccflags" ;; # restore
-	esac
-	;;
-esac
-
-case "$ccflags" in
-*-DUSE_LONG_DOUBLE*|*-DUSE_MORE_BITS*) uselongdouble="$define" ;;
-esac
-
-case "$uselongdouble" in
-$define|true|[yY]*)	dflt='y';;
-*) dflt='n';;
-esac
-cat <<EOM
-
-Perl can be built to take advantage of long doubles which
-(if available) may give more accuracy and range for floating point numbers.
-
-If this doesn't make any sense to you, just accept the default '$dflt'.
-EOM
-rp='Try to use long doubles if available?'
-. ./myread
-case "$ans" in
-y|Y) 	val="$define"	;;
-*)      val="$undef"	;;
-esac
-set uselongdouble
-eval $setvar
-
-case "$uselongdouble" in
-true|[yY]*) uselongdouble="$define" ;;
-esac
-
-case "$uselongdouble" in
-$define)
-: Look for a hint-file generated 'call-back-unit'.  If the
-: user has specified that long doubles should be used,
-: we may need to set or change some other defaults.
-	if $test -f uselongdouble.cbu; then
-		echo "Your platform has some specific hints for long doubles, using them..."
-		. ./uselongdouble.cbu
-	else
-		$cat <<EOM
-(Your platform doesn't have any specific hints for long doubles.)
-EOM
-	fi
-	;;
-esac
-
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
-	;;
-esac
-
-if $test "$message" != X; then
-	$cat <<EOM >&4
-
-*** You requested the use of long doubles but you do not seem to have
-*** the mathematic functions for long doubles.
-*** ($message)
-*** I'm disabling the use of long doubles.
-
-EOM
-
-	uselongdouble=$undef
-fi
-
-: determine the architecture name
-echo " "
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
-	;;
-esac
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
-. ./myread
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
-		;;
-	esac
-	;;
-esac
-case "$useperlio" in
-$define)
-	echo "Perlio selected." >&4
-	;;
-*)
-	echo "Perlio not selected, using stdio." >&4
-	case "$archname" in
-        *-stdio*) echo "...and architecture name already has -stdio." >&4
-                ;;
-        *)      archname="$archname-stdio"
-                echo "...setting architecture name to $archname." >&4
-                ;;
-        esac
-	;;
-esac
-
-: determine root of directory hierarchy where package will be installed.
-case "$prefix" in
-'')
-	dflt=`./loc . /usr/local /usr/local /local /opt /usr`
-	;;
-*)
-	dflt="$prefix"
-	;;
-esac
-$cat <<EOM
-
-By default, $package will be installed in $dflt/bin, manual pages
-under $dflt/man, etc..., i.e. with $dflt as prefix for all
-installation directories. Typically this is something like /usr/local.
-If you wish to have binaries under /usr/bin but other parts of the
-installation under /usr/local, that's ok: you will be prompted
-separately for each of the installation directories, the prefix being
-only used to set the defaults.
-
-EOM
-fn=d~
-rp='Installation prefix to use?'
-. ./getfile
-oldprefix=''
-case "$prefix" in
-'') ;;
-*)
-	case "$ans" in
-	"$prefix") ;;
-	*) oldprefix="$prefix";;
-	esac
-	;;
-esac
-prefix="$ans"
-prefixexp="$ansexp"
-
-case "$afsroot" in
-'')	afsroot=/afs ;;
-*)	afsroot=$afsroot ;;
-esac
-
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
-	;;
-esac
-if $afs; then
-	echo "AFS may be running... I'll be extra cautious then..." >&4
-else
-	echo "AFS does not seem to be running..." >&4
-fi
-
-: determine installation prefix for where package is to be installed.
-if $afs; then 
-$cat <<EOM
-
-Since you are running AFS, I need to distinguish the directory in which
-files will reside from the directory in which they are installed (and from
-which they are presumably copied to the former directory by occult means).
-
-EOM
-	case "$installprefix" in
-	'') dflt=`echo $prefix | sed 's#^/afs/#/afs/.#'`;;
-	*) dflt="$installprefix";;
-	esac
-else
-$cat <<EOM
-
-In some special cases, particularly when building $package for distribution,
-it is convenient to distinguish between the directory in which files should 
-be installed from the directory ($prefix) in which they 
-will eventually reside.  For most users, these two directories are the same.
-
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
-
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
 
 : get the patchlevel
 echo " "
@@ -6669,19 +6020,36 @@ set d_dosuid
 eval $setvar
 
 : see if this is a malloc.h system
-set malloc.h i_malloc
-eval $inhdr
-
-: see if stdlib is available
-set stdlib.h i_stdlib
-eval $inhdr
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
 
 : check for void type
 echo " "
 echo "Checking to see how well your C compiler groks the void type..." >&4
 case "$voidflags" in
 '')
-	$cat >try.c <<'EOCP'
+	$cat >try.c <<EOCP
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
 #if TRY & 1
 void sub() {
 #else
@@ -6760,670 +6128,1165 @@ case "$voidflags" in
     4: operations between pointers to and addresses of void functions.
     8: generic void pointers.
 EOM
-	dflt="$voidflags";
-	rp="Your void support flags add up to what?"
-	. ./myread
-	voidflags="$ans"
+	dflt="$voidflags";
+	rp="Your void support flags add up to what?"
+	. ./myread
+	voidflags="$ans"
+	;;
+esac
+$rm -f try.* .out
+
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
+	;;
+esac
+$rm -f try.c try
+case "$use64bitall" in
+"$define"|true|[yY]*)
+	case "$ptrsize" in
+	4)	cat <<EOM >&4
+
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
+
+EOM
+
+		exit 1
+		;;
+	esac
+	;;
+esac
+
+
+: determine which malloc to compile in
+echo " "
+case "$usemymalloc" in
+[yY]*|true|$define)	dflt='y' ;;
+[nN]*|false|$undef)	dflt='n' ;;
+*)	case "$ptrsize" in
+	4) dflt='y' ;;
+	*) dflt='n' ;;
+	esac
+	;;
+esac
+rp="Do you wish to attempt to use the malloc that comes with $package?"
+. ./myread
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
+		;;
+	esac
+	;;
+*)
+	usemymalloc='n'
+	mallocsrc=''
+	mallocobj=''
+	d_mymalloc="$undef"
+	;;
+esac
+
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
+'')
+	if $cc $ccflags -c -DTRY_MALLOC malloc.c >/dev/null 2>&1; then
+		malloctype='void *'
+	else
+		malloctype='char *'
+	fi
+	;;
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
+	;;
+esac
+echo "Your system uses $freetype free(), it would seem." >&4
+$rm -f malloc.[co]
+$cat <<EOM
+
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
+
+EOM
+fn=d~+
+rp='Installation prefix to use for add-on modules and utilities?'
+: XXX Here might be another good place for an installstyle setting.
+case "$siteprefix" in
+'') dflt=$prefix ;;
+*)  dflt=$siteprefix ;;
+esac
+. ./getfile
+: XXX Prefixit unit does not yet support siteprefix and vendorprefix
+oldsiteprefix=''
+case "$siteprefix" in
+'') ;;
+*)	case "$ans" in
+	"$prefix") ;;
+	*) oldsiteprefix="$prefix";;
+	esac
 	;;
 esac
-$rm -f try.* .out
+siteprefix="$ans"
+siteprefixexp="$ansexp"
 
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
-}
-EOCP
-	set try
-	if eval $compile_ok; then
-		ptrsize=`$run ./try`
-		echo "Your pointers are $ptrsize bytes long."
-	else
-		dflt='4'
-		echo "(I can't seem to compile the test program.  Guessing...)" >&4
-		rp="What is the size of a pointer (in bytes)?"
-		. ./myread
-		ptrsize="$ans"
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
-$rm -f try.c try
-case "$use64bitall" in
-"$define"|true|[yY]*)
-	case "$ptrsize" in
-	4)	cat <<EOM >&4
+$cat <<EOM
 
-*** You have chosen a maximally 64-bit build, but your pointers
-*** are only 4 bytes wide, disabling maximal 64-bitness.
+The installation process will create a directory for
+site-specific extensions and modules.  Most users find it convenient
+to place all site-specific files in this directory rather than in the
+main distribution directory.
 
 EOM
-		use64bitall="$undef"
-		case "$use64bitint" in
-		"$define"|true|[yY]*) ;;
-		*)	cat <<EOM >&4
+fn=d~+
+rp='Pathname for the site-specific library files?'
+. ./getfile
+sitelib="$ans"
+sitelibexp="$ansexp"
+sitelib_stem=`echo "$sitelibexp" | sed "s,/$version$,,"`
+: Change installation prefix, if necessary.
+if $test X"$prefix" != X"$installprefix"; then
+	installsitelib=`echo $sitelibexp | $sed "s#^$prefix#$installprefix#"`
+else
+	installsitelib="$sitelibexp"
+fi
+
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
+$cat <<EOM
 
-*** Downgrading from maximal 64-bitness to using 64-bit integers.
+The installation process will also create a directory for
+architecture-dependent site-specific extensions and modules.
 
 EOM
-			use64bitint="$define"
-			;;
+fn=d~+
+rp='Pathname for the site-specific architecture-dependent library files?'
+. ./getfile
+sitearch="$ans"
+sitearchexp="$ansexp"
+: Change installation prefix, if necessary.
+if $test X"$prefix" != X"$installprefix"; then
+	installsitearch=`echo $sitearchexp | sed "s#^$prefix#$installprefix#"`
+else
+	installsitearch="$sitearchexp"
+fi
+
+$cat <<EOM
+
+The installation process will also create a directory for
+vendor-supplied add-ons.  Vendors who supply perl with their system
+may find it convenient to place all vendor-supplied files in this
+directory rather than in the main distribution directory.  This will
+ease upgrades between binary-compatible maintenance versions of perl.
+
+Of course you may also use these directories in whatever way you see
+fit.  For example, you might use them to access modules shared over a
+company-wide network.
+
+The default answer should be fine for most people.
+This causes further questions about vendor add-ons to be skipped
+and no vendor-specific directories will be configured for perl.
+
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
+esac
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
+	;;
+*)	usevendorprefix="$undef"
+	vendorprefix=''
+	vendorprefixexp=''
+	;;
+esac
+
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
 		esac
 		;;
+	*)	dflt="$vendorlib"
+		;;
+	esac
+	fn=d~+
+	rp='Pathname for the vendor-supplied library files?'
+	. ./getfile
+	vendorlib="$ans"
+	vendorlibexp="$ansexp"
+	;;
+esac
+vendorlib_stem=`echo "$vendorlibexp" | sed "s,/$version$,,"`
+: Change installation prefix, if necessary.
+if $test X"$prefix" != X"$installprefix"; then
+	installvendorlib=`echo $vendorlibexp | $sed "s#^$prefix#$installprefix#"`
+else
+	installvendorlib="$vendorlibexp"
+fi
+
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
 	esac
+	fn=d~+
+	rp='Pathname for vendor-supplied architecture-dependent files?'
+	. ./getfile
+	vendorarch="$ans"
+	vendorarchexp="$ansexp"
 	;;
 esac
+: Change installation prefix, if necessary.
+if $test X"$prefix" != X"$installprefix"; then
+	installvendorarch=`echo $vendorarchexp | sed "s#^$prefix#$installprefix#"`
+else
+	installvendorarch="$vendorarchexp"
+fi
+
+: Final catch-all directories to search
+$cat <<EOM
+
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
 
+EOM
 
-: determine which malloc to compile in
-echo " "
-case "$usemymalloc" in
-[yY]*|true|$define)	dflt='y' ;;
-[nN]*|false|$undef)	dflt='n' ;;
-*)	case "$ptrsize" in
-	4) dflt='y' ;;
-	*) dflt='n' ;;
-	esac
-	;;
-esac
-rp="Do you wish to attempt to use the malloc that comes with $package?"
+rp='Colon-separated list of additional directories for perl to search?'
 . ./myread
-usemymalloc="$ans"
 case "$ans" in
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
-	esac
-	;;
-*)
-	usemymalloc='n'
-	mallocsrc=''
-	mallocobj=''
-	d_mymalloc="$undef"
-	;;
+' '|''|none)	otherlibdirs=' ' ;;     
+*)	otherlibdirs="$ans" ;;
 esac
+case "$otherlibdirs" in
+' ') val=$undef ;;
+*)	val=$define ;;
+esac
+set d_perl_otherlibdirs
+eval $setvar
 
-: compute the return types of malloc and free
+: Cruising for prototypes
 echo " "
-$cat >malloc.c <<END
-#$i_malloc I_MALLOC
+echo "Checking out function prototypes..." >&4
+$cat >prototype.c <<EOCP
 #$i_stdlib I_STDLIB
-#include <stdio.h>
-#include <sys/types.h>
-#ifdef I_MALLOC
-#include <malloc.h>
-#endif
 #ifdef I_STDLIB
 #include <stdlib.h>
 #endif
-#ifdef TRY_MALLOC
-void *malloc();
-#endif
-#ifdef TRY_FREE
-void free();
-#endif
-END
-case "$malloctype" in
-'')
-	if $cc $ccflags -c -DTRY_MALLOC malloc.c >/dev/null 2>&1; then
-		malloctype='void *'
-	else
-		malloctype='char *'
-	fi
+int main(int argc, char *argv[]) {
+	exit(0);}
+EOCP
+if $cc $ccflags -c prototype.c >prototype.out 2>&1 ; then
+	echo "Your C compiler appears to support function prototypes."
+	val="$define"
+else
+	echo "Your C compiler doesn't seem to understand function prototypes."
+	val="$undef"
+fi
+set prototype
+eval $setvar
+$rm -f prototype*
+
+case "$prototype" in
+"$define") ;;
+*)	ansi2knr='ansi2knr'
+	echo " "
+	cat <<EOM >&4
+
+$me:  FATAL ERROR:
+This version of $package can only be compiled by a compiler that 
+understands function prototypes.  Unfortunately, your C compiler 
+	$cc $ccflags
+doesn't seem to understand them.  Sorry about that.
+
+If GNU cc is available for your system, perhaps you could try that instead.  
+
+Eventually, we hope to support building Perl with pre-ANSI compilers.
+If you would like to help in that effort, please contact <perlbug@perl.org>.
+
+Aborting Configure now.
+EOM
+	exit 2
 	;;
 esac
-echo "Your system wants malloc to return '$malloctype', it would seem." >&4
 
-case "$freetype" in
-'')
-	if $cc $ccflags -c -DTRY_FREE malloc.c >/dev/null 2>&1; then
-		freetype='void'
-	else
-		freetype='int'
-	fi
-	;;
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
+
+echo " "
+case "$extras" in
+'') dflt='n';;
+*) dflt='y';;
 esac
-echo "Your system uses $freetype free(), it would seem." >&4
-$rm -f malloc.[co]
-$cat <<EOM
+cat <<EOM
+Perl can be built with extra modules or bundles of modules which
+will be fetched from the CPAN and installed alongside Perl.
 
-After $package is installed, you may wish to install various
-add-on modules and utilities.  Typically, these add-ons will
-be installed under $prefix with the rest
-of this package.  However, you may wish to install such add-ons
-elsewhere under a different prefix.
+Notice that you will need access to the CPAN; either via the Internet,
+or a local copy, for example a CD-ROM or a local CPAN mirror.  (You will
+be asked later to configure the CPAN.pm module which will in turn do
+the installation of the rest of the extra modules or bundles.)
 
-If you do not wish to put everything under a single prefix, that's
-ok.  You will be prompted for the individual locations; this siteprefix
-is only used to suggest the defaults.
+Notice also that if the modules require any external software such as
+libraries and headers (the libz library and the zlib.h header for the
+Compress::Zlib module, for example) you MUST have any such software
+already installed, this configuration process will NOT install such
+things for you.
 
-The default should be fine for most people.
+If this doesn't make any sense to you, just accept the default '$dflt'.
+EOM
+rp='Install any extra modules (y or n)?'
+. ./myread
+case "$ans" in
+y|Y)
+	cat <<EOM
 
+Please list any extra modules or bundles to be installed from CPAN,
+with spaces between the names.  The names can be in any format the
+'install' command of CPAN.pm will understand.  (Answer 'none',
+without the quotes, to install no extra modules or bundles.)
 EOM
-fn=d~+
-rp='Installation prefix to use for add-on modules and utilities?'
-: XXX Here might be another good place for an installstyle setting.
-case "$siteprefix" in
-'') dflt=$prefix ;;
-*)  dflt=$siteprefix ;;
+	rp='Extras?'
+	dflt="$extras"
+	. ./myread
+	extras="$ans"
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
+case "$extras" in
+''|'none')
+	val=''
+	$rm -f ../extras.lst
+	;;
+*)	echo "(Saving the list of extras for later...)"
+	echo "$extras" > ../extras.lst
+	val="'$extras'"
 	;;
 esac
-siteprefix="$ans"
-siteprefixexp="$ansexp"
+set extras
+eval $setvar
+echo " "
+
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
+		fi
+	done
+	;;
+*)	perl5="$perl5"
+	;;
+esac
+case "$perl5" in
+'')	echo "None found.  That's ok.";;
+*)	echo "Using $perl5." ;;
+esac
+
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
+}
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
 
-: determine where site specific libraries go.
-: Usual default is /usr/local/lib/perl5/site_perl/$version
-: The default "style" setting is made in installstyle.U
-: XXX No longer works with Prefixit stuff.
-prog=`echo $package | $sed 's/-*[0-9.]*$//'`
-case "$sitelib" in
-'') case "$installstyle" in
-	*lib/perl5*) dflt=$siteprefix/lib/$package/site_$prog/$version ;;
-	*)	 dflt=$siteprefix/lib/site_$prog/$version ;;
-	esac
-	;;
-*)	dflt="$sitelib"
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
+	else
+		dflt='none'
+	fi
 	;;
+$undef) dflt='none' ;;
+*)  eval dflt=\"$inc_version_list\" ;;
+esac
+case "$dflt" in
+''|' ') dflt=none ;;
+esac
+case "$dflt" in
+5.005) dflt=none ;;
 esac
 $cat <<EOM
 
-The installation process will create a directory for
-site-specific extensions and modules.  Most users find it convenient
-to place all site-specific files in this directory rather than in the
-main distribution directory.
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
-	;;
-*)	dflt="$sitearch"
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
-set sitearch sitearch none
-eval $prefixit
-$cat <<EOM
+$rm -f getverlist
 
-The installation process will also create a directory for
-architecture-dependent site-specific extensions and modules.
+: determine whether to install perl also as /usr/bin/perl
 
+echo " "
+if $test -d /usr/bin -a "X$installbin" != X/usr/bin; then
+	$cat <<EOM
+Many scripts expect perl to be installed as /usr/bin/perl.
+I can install the perl you are about to compile also as /usr/bin/perl
+(in addition to $installbin/perl).
 EOM
-fn=d~+
-rp='Pathname for the site-specific architecture-dependent library files?'
-. ./getfile
-sitearch="$ans"
-sitearchexp="$ansexp"
-: Change installation prefix, if necessary.
-if $test X"$prefix" != X"$installprefix"; then
-	installsitearch=`echo $sitearchexp | sed "s#^$prefix#$installprefix#"`
+	case "$installusrbinperl" in
+	"$undef"|[nN]*)	dflt='n';;
+	*)		dflt='y';;
+	esac
+	rp="Do you want to install perl as /usr/bin/perl?"
+	. ./myread
+	case "$ans" in
+	[yY]*)	val="$define";;
+	*)	val="$undef" ;;
+	esac
 else
-	installsitearch="$sitearchexp"
+	val="$undef"
 fi
+set installusrbinperl
+eval $setvar
 
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
+echo " "
+echo "Checking for GNU C Library..." >&4
+cat >try.c <<'EOCP'
+/* Find out version of GNU C library.  __GLIBC__ and __GLIBC_MINOR__
+   alone are insufficient to distinguish different versions, such as
+   2.0.6 and 2.0.7.  The function gnu_get_libc_version() appeared in
+   libc version 2.1.0.      A. Dougherty,  June 3, 2002.
+*/
+#include <stdio.h>
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
+#endif
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
+: see if nm is to be used to determine whether a symbol is defined or not
+case "$usenm" in
+'')
+	dflt=''
+	case "$d_gnulibc" in
+	"$define")
+		echo " "
+		echo "nm probably won't work on the GNU C Library." >&4
+		dflt=n
 		;;
 	esac
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
+	case "$dflt" in
+	'') 
+		if $test "$osname" = aix -a "X$PASE" != "Xdefine" -a ! -f /lib/syscalls.exp; then
+			echo " "
+			echo "Whoops!  This is an AIX system without /lib/syscalls.exp!" >&4
+			echo "'nm' won't be sufficient on this sytem." >&4
+			dflt=n
+		fi
 		;;
-	*)	dflt="$vendorlib"
+	esac
+	case "$dflt" in
+	'') dflt=`$egrep 'inlibc|csym' $rsrc/Configure | wc -l 2>/dev/null`
+		if $test $dflt -gt 20; then
+			dflt=y
+		else
+			dflt=n
+		fi
 		;;
 	esac
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
+*)
+	case "$usenm" in
+	true|$define) dflt=y;;
+	*) dflt=n;;
 	esac
-	fn=d~+
-	rp='Pathname for vendor-supplied architecture-dependent files?'
-	. ./getfile
-	vendorarch="$ans"
-	vendorarchexp="$ansexp"
 	;;
 esac
-: Change installation prefix, if necessary.
-if $test X"$prefix" != X"$installprefix"; then
-	installvendorarch=`echo $vendorarchexp | sed "s#^$prefix#$installprefix#"`
-else
-	installvendorarch="$vendorarchexp"
-fi
-
-: Final catch-all directories to search
 $cat <<EOM
 
-Lastly, you can have perl look in other directories for extensions and
-modules in addition to those already specified.
-These directories will be searched after 
-	$sitearch 
-	$sitelib 
-EOM
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
+I can use $nm to extract the symbols from your C libraries. This
+is a time consuming task which may generate huge output on the disk (up
+to 3 megabytes) but that should make the symbols extraction faster. The
+alternative is to skip the 'nm' extraction part and to compile a small
+test program instead to determine whether each symbol is present. If
+you have a fast C compiler and/or if your 'nm' output cannot be parsed,
+this may be the best solution.
 
-EOM
+You probably shouldn't let me use 'nm' if you are using the GNU C Library.
 
-rp='Colon-separated list of additional directories for perl to search?'
+EOM
+rp="Shall I use $nm to extract C symbols from the libraries?"
 . ./myread
 case "$ans" in
-' '|''|none)	otherlibdirs=' ' ;;     
-*)	otherlibdirs="$ans" ;;
-esac
-case "$otherlibdirs" in
-' ') val=$undef ;;
-*)	val=$define ;;
+[Nn]*) usenm=false;;
+*) usenm=true;;
 esac
-set d_perl_otherlibdirs
-eval $setvar
-
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
-fi
-set prototype
-eval $setvar
-$rm -f prototype*
-
-case "$prototype" in
-"$define") ;;
-*)	ansi2knr='ansi2knr'
-	echo " "
-	cat <<EOM >&4
 
-$me:  FATAL ERROR:
-This version of $package can only be compiled by a compiler that 
-understands function prototypes.  Unfortunately, your C compiler 
-	$cc $ccflags
-doesn't seem to understand them.  Sorry about that.
-
-If GNU cc is available for your system, perhaps you could try that instead.  
+runnm=$usenm
+case "$reuseval" in
+true) runnm=false;;
+esac
 
-Eventually, we hope to support building Perl with pre-ANSI compilers.
-If you would like to help in that effort, please contact <perlbug@perl.org>.
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
 
-Aborting Configure now.
-EOM
-	exit 2
+: nm options which may be necessary for shared libraries but illegal
+: for archive libraries.  Thank you, Linux.
+case "$nm_so_opt" in
+'')	case "$myuname" in
+	*linux*)
+		if $nm --help | $grep 'dynamic' > /dev/null 2>&1; then
+			nm_so_opt='--dynamic'
+		fi
+		;;
+	esac
 	;;
 esac
 
-: determine where public executables go
+case "$runnm" in
+true)
+: get list of predefined functions in a handy place
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
+case "$libc" in
+'') libc=unknown
+	case "$libs" in
+	*-lc_s*) libc=`./loc libc_s$_a $libc $libpth`
+	esac
+	;;
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
+	;;
+esac
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
+	;;
+*)
+	set blurfl
+	;;
+esac
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
-	installbin="$binexp"
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
 
-echo " "
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
+If the guess above is wrong (which it might be if you're using a strange
+compiler, or your machine supports multiple models), you can override it here.
 
-Notice also that if the modules require any external software such as
-libraries and headers (the libz library and the zlib.h header for the
-Compress::Zlib module, for example) you MUST have any such software
-already installed, this configuration process will NOT install such
-things for you.
+EOM
+else
+	dflt=''
+	echo $libpth | $tr ' ' $trnl | $sort | $uniq > libpath
+	cat >&4 <<EOM
+I can't seem to find your C library.  I've looked in the following places:
 
-If this doesn't make any sense to you, just accept the default '$dflt'.
 EOM
-rp='Install any extra modules (y or n)?'
-. ./myread
-case "$ans" in
-y|Y)
+	$sed 's/^/	/' libpath
 	cat <<EOM
 
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
-echo " "
+None of these seems to contain your C library. I need to get its name...
 
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
+EOM
+fi
+fn=f
+rp='Where is your C library?'
+. ./getfile
+libc="$ans"
 
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
+echo " "
+echo $libc $libnames | $tr ' ' $trnl | $sort | $uniq > libnames
+set X `cat libnames`
+shift
+xxx=files
+case $# in 1) xxx=file; esac
+echo "Extracting names from the following $xxx for later perusal:" >&4
+echo " "
+$sed 's/^/	/' libnames >&4
+echo " "
+$echo $n "This may take a while...$c" >&4
 
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
@@ -7527,10 +7390,13 @@ while other systems (such as those using ELF) use $cc.
 
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
@@ -8655,6 +8521,10 @@ echo "Checking the size of $zzz..." >&4
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
@@ -8759,9 +8629,13 @@ EOCP
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
@@ -8811,12 +8685,127 @@ esac
 if $test X"$prefix" != X"$installprefix"; then
 	installvendorbin=`echo $vendorbinexp | $sed "s#^$prefix#$installprefix#"`
 else
-	installvendorbin="$vendorbinexp"
+	installvendorbin="$vendorbinexp"
+fi
+
+: see if qgcvt exists
+set qgcvt d_qgcvt
+eval $inlibc
+
+echo " "
+
+if $test X"$d_longdbl" = X"$define"; then
+
+echo "Checking how to print long doubles..." >&4
+
+if $test X"$sPRIfldbl" = X -a X"$doublesize" = X"$longdblsize"; then
+	$cat >try.c <<'EOCP'
+#include <sys/types.h>
+#include <stdio.h>
+int main() {
+  double d = 123.456;
+  printf("%.3f\n", d);
+}
+EOCP
+	set try
+	if eval $compile; then
+		yyy=`$run ./try`
+		case "$yyy" in
+		123.456)
+			sPRIfldbl='"f"'; sPRIgldbl='"g"'; sPRIeldbl='"e"';
+                	sPRIFUldbl='"F"'; sPRIGUldbl='"G"'; sPRIEUldbl='"E"';
+			echo "We will use %f."
+			;;
+		esac
+	fi
+fi
+
+if $test X"$sPRIfldbl" = X; then
+	$cat >try.c <<'EOCP'
+#include <sys/types.h>
+#include <stdio.h>
+int main() {
+  long double d = 123.456;
+  printf("%.3Lf\n", d);
+}
+EOCP
+	set try
+	if eval $compile; then
+		yyy=`$run ./try`
+		case "$yyy" in
+		123.456)
+			sPRIfldbl='"Lf"'; sPRIgldbl='"Lg"'; sPRIeldbl='"Le"';
+                	sPRIFUldbl='"LF"'; sPRIGUldbl='"LG"'; sPRIEUldbl='"LE"';
+			echo "We will use %Lf."
+			;;
+		esac
+	fi
+fi
+
+if $test X"$sPRIfldbl" = X; then
+	$cat >try.c <<'EOCP'
+#include <sys/types.h>
+#include <stdio.h>
+int main() {
+  long double d = 123.456;
+  printf("%.3llf\n", d);
+}
+EOCP
+	set try
+	if eval $compile; then
+		yyy=`$run ./try`
+		case "$yyy" in
+		123.456)
+			sPRIfldbl='"llf"'; sPRIgldbl='"llg"'; sPRIeldbl='"lle"';
+                	sPRIFUldbl='"llF"'; sPRIGUldbl='"llG"'; sPRIEUldbl='"llE"';
+			echo "We will use %llf."
+			;;
+		esac
+	fi
+fi
+
+if $test X"$sPRIfldbl" = X; then
+	$cat >try.c <<'EOCP'
+#include <sys/types.h>
+#include <stdio.h>
+int main() {
+  long double d = 123.456;
+  printf("%.3lf\n", d);
+}
+EOCP
+	set try
+	if eval $compile; then
+		yyy=`$run ./try`
+		case "$yyy" in
+		123.456)
+			sPRIfldbl='"lf"'; sPRIgldbl='"lg"'; sPRIeldbl='"le"';
+                	sPRIFUldbl='"lF"'; sPRIGUldbl='"lG"'; sPRIEUldbl='"lE"';
+			echo "We will use %lf."
+			;;
+		esac
+	fi
+fi
+
+if $test X"$sPRIfldbl" = X; then
+	echo "Cannot figure out how to print long doubles." >&4
+else
+	sSCNfldbl=$sPRIfldbl	# expect consistency
 fi
 
-: see if qgcvt exists
-set qgcvt d_qgcvt
-eval $inlibc
+$rm -f try try.*
+
+fi # d_longdbl
+
+case "$sPRIfldbl" in
+'')	d_PRIfldbl="$undef"; d_PRIgldbl="$undef"; d_PRIeldbl="$undef"; 
+	d_PRIFUldbl="$undef"; d_PRIGUldbl="$undef"; d_PRIEUldbl="$undef"; 
+	d_SCNfldbl="$undef";
+	;;
+*)	d_PRIfldbl="$define"; d_PRIgldbl="$define"; d_PRIeldbl="$define"; 
+	d_PRIFUldbl="$define"; d_PRIGUldbl="$define"; d_PRIEUldbl="$define"; 
+	d_SCNfldbl="$define";
+	;;
+esac
 
 : Check how to convert floats to strings.
 
@@ -9071,7 +9060,7 @@ eval $inlibc
 case "$d_access" in
 "$define")
 	echo " "
-	$cat >access.c <<'EOCP'
+	$cat >access.c <<EOCP
 #include <sys/types.h>
 #ifdef I_FCNTL
 #include <fcntl.h>
@@ -9082,6 +9071,10 @@ case "$d_access" in
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
@@ -9219,7 +9212,7 @@ echo " "
 if test "X$timeincl" = X; then
 	echo "Testing to see if we should include <time.h>, <sys/time.h> or both." >&4
 	$echo $n "I'm now running the test program...$c"
-	$cat >try.c <<'EOCP'
+	$cat >try.c <<EOCP
 #include <sys/types.h>
 #ifdef I_TIME
 #include <time.h>
@@ -9233,6 +9226,10 @@ if test "X$timeincl" = X; then
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
@@ -9398,7 +9395,7 @@ echo " "
 echo "Checking whether your compiler can handle __attribute__ ..." >&4
 $cat >attrib.c <<'EOCP'
 #include <stdio.h>
-void croak (char* pat,...) __attribute__((format(printf,1,2),noreturn));
+void croak (char* pat,...) __attribute__((__format__(__printf__,1,2),noreturn));
 EOCP
 if $cc $ccflags -c attrib.c >attrib.out 2>&1 ; then
 	if $contains 'warning' attrib.out >/dev/null 2>&1; then
@@ -9442,6 +9439,10 @@ case "$d_getpgrp" in
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
@@ -9504,6 +9505,10 @@ case "$d_setpgrp" in
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
@@ -9609,6 +9614,10 @@ else
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
@@ -9663,6 +9672,10 @@ echo " "
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
@@ -9759,8 +9772,12 @@ echo " "
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
 
@@ -10299,6 +10316,10 @@ eval $inhdr
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
@@ -10391,6 +10412,10 @@ EOM
 $cat >fred.c<<EOM
 
 #include <stdio.h>
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
 #$i_dlfcn I_DLFCN
 #ifdef I_DLFCN
 #include <dlfcn.h>      /* the dynamic linker include file for SunOS/Solaris */
@@ -10723,537 +10748,832 @@ case "$d_endprotoent_r" in
 		echo "Disabling endprotoent_r, cannot determine prototype." >&4 ;;
 	* )	case "$endprotoent_r_proto" in
 		REENTRANT_PROTO*) ;;
-		*) endprotoent_r_proto="REENTRANT_PROTO_$endprotoent_r_proto" ;;
+		*) endprotoent_r_proto="REENTRANT_PROTO_$endprotoent_r_proto" ;;
+		esac
+		echo "Prototype: $try" ;;
+	esac
+	;;
+	*)	case "$usethreads" in
+		define) echo "endprotoent_r has no prototype, not using it." >&4 ;;
+		esac
+		d_endprotoent_r=undef
+		endprotoent_r_proto=0
+		;;
+	esac
+	;;
+*)	endprotoent_r_proto=0
+	;;
+esac
+
+: see if endpwent exists
+set endpwent d_endpwent
+eval $inlibc
+
+: see if this is a pwd.h system
+set pwd.h i_pwd
+eval $inhdr
+
+case "$i_pwd" in
+$define)
+	xxx=`./findhdr pwd.h`
+	$cppstdin $cppflags $cppminus < $xxx >$$.h
+
+	if $contains 'pw_quota' $$.h >/dev/null 2>&1; then
+		val="$define"
+	else
+		val="$undef"
+	fi
+	set d_pwquota
+	eval $setvar
+
+	if $contains 'pw_age' $$.h >/dev/null 2>&1; then
+		val="$define"
+	else
+		val="$undef"
+	fi
+	set d_pwage
+	eval $setvar
+
+	if $contains 'pw_change' $$.h >/dev/null 2>&1; then
+		val="$define"
+	else
+		val="$undef"
+	fi
+	set d_pwchange
+	eval $setvar
+
+	if $contains 'pw_class' $$.h >/dev/null 2>&1; then
+		val="$define"
+	else
+		val="$undef"
+	fi
+	set d_pwclass
+	eval $setvar
+
+	if $contains 'pw_expire' $$.h >/dev/null 2>&1; then
+		val="$define"
+	else
+		val="$undef"
+	fi
+	set d_pwexpire
+	eval $setvar
+
+	if $contains 'pw_comment' $$.h >/dev/null 2>&1; then
+		val="$define"
+	else
+		val="$undef"
+	fi
+	set d_pwcomment
+	eval $setvar
+
+	if $contains 'pw_gecos' $$.h >/dev/null 2>&1; then
+		val="$define"
+	else
+		val="$undef"
+	fi
+	set d_pwgecos
+	eval $setvar
+
+	if $contains 'pw_passwd' $$.h >/dev/null 2>&1; then
+		val="$define"
+	else
+		val="$undef"
+	fi
+	set d_pwpasswd
+	eval $setvar
+
+	$rm -f $$.h
+	;;
+*)
+	val="$undef"; 
+	set d_pwquota; eval $setvar
+	set d_pwage; eval $setvar
+	set d_pwchange; eval $setvar
+	set d_pwclass; eval $setvar
+	set d_pwexpire; eval $setvar
+	set d_pwcomment; eval $setvar
+	set d_pwgecos; eval $setvar
+	set d_pwpasswd; eval $setvar
+	;;
+esac
+
+: see if endpwent_r exists
+set endpwent_r d_endpwent_r
+eval $inlibc
+case "$d_endpwent_r" in
+"$define")
+	hdrs="$i_systypes sys/types.h define stdio.h $i_pwd pwd.h"
+	case "$d_endpwent_r_proto:$usethreads" in
+	":define")	d_endpwent_r_proto=define
+		set d_endpwent_r_proto endpwent_r $hdrs
+		eval $hasproto ;;
+	*)	;;
+	esac
+	case "$d_endpwent_r_proto" in
+	define)
+	case "$endpwent_r_proto" in
+	''|0) try='int endpwent_r(FILE**);'
+	./protochk "extern $try" $hdrs && endpwent_r_proto=I_H ;;
+	esac
+	case "$endpwent_r_proto" in
+	''|0) try='void endpwent_r(FILE**);'
+	./protochk "extern $try" $hdrs && endpwent_r_proto=V_H ;;
+	esac
+	case "$endpwent_r_proto" in
+	''|0)	d_endpwent_r=undef
+ 	        endpwent_r_proto=0
+		echo "Disabling endpwent_r, cannot determine prototype." >&4 ;;
+	* )	case "$endpwent_r_proto" in
+		REENTRANT_PROTO*) ;;
+		*) endpwent_r_proto="REENTRANT_PROTO_$endpwent_r_proto" ;;
+		esac
+		echo "Prototype: $try" ;;
+	esac
+	;;
+	*)	case "$usethreads" in
+		define) echo "endpwent_r has no prototype, not using it." >&4 ;;
+		esac
+		d_endpwent_r=undef
+		endpwent_r_proto=0
+		;;
+	esac
+	;;
+*)	endpwent_r_proto=0
+	;;
+esac
+
+: see if endservent exists
+set endservent d_endsent
+eval $inlibc
+
+: see if endservent_r exists
+set endservent_r d_endservent_r
+eval $inlibc
+case "$d_endservent_r" in
+"$define")
+	hdrs="$i_systypes sys/types.h define stdio.h $i_netdb netdb.h"
+	case "$d_endservent_r_proto:$usethreads" in
+	":define")	d_endservent_r_proto=define
+		set d_endservent_r_proto endservent_r $hdrs
+		eval $hasproto ;;
+	*)	;;
+	esac
+	case "$d_endservent_r_proto" in
+	define)
+	case "$endservent_r_proto" in
+	''|0) try='int endservent_r(struct servent_data*);'
+	./protochk "extern $try" $hdrs && endservent_r_proto=I_D ;;
+	esac
+	case "$endservent_r_proto" in
+	''|0) try='void endservent_r(struct servent_data*);'
+	./protochk "extern $try" $hdrs && endservent_r_proto=V_D ;;
+	esac
+	case "$endservent_r_proto" in
+	''|0)	d_endservent_r=undef
+ 	        endservent_r_proto=0
+		echo "Disabling endservent_r, cannot determine prototype." >&4 ;;
+	* )	case "$endservent_r_proto" in
+		REENTRANT_PROTO*) ;;
+		*) endservent_r_proto="REENTRANT_PROTO_$endservent_r_proto" ;;
 		esac
 		echo "Prototype: $try" ;;
 	esac
 	;;
 	*)	case "$usethreads" in
-		define) echo "endprotoent_r has no prototype, not using it." >&4 ;;
+		define) echo "endservent_r has no prototype, not using it." >&4 ;;
 		esac
-		d_endprotoent_r=undef
-		endprotoent_r_proto=0
+		d_endservent_r=undef
+		endservent_r_proto=0
 		;;
 	esac
 	;;
-*)	endprotoent_r_proto=0
+*)	endservent_r_proto=0
 	;;
 esac
 
-: see if endpwent exists
-set endpwent d_endpwent
-eval $inlibc
-
-: see if this is a pwd.h system
-set pwd.h i_pwd
-eval $inhdr
-
-case "$i_pwd" in
-$define)
-	xxx=`./findhdr pwd.h`
-	$cppstdin $cppflags $cppminus < $xxx >$$.h
-
-	if $contains 'pw_quota' $$.h >/dev/null 2>&1; then
+: Locate the flags for 'open()'
+echo " "
+$cat >try.c <<EOCP
+#include <sys/types.h>
+#ifdef I_FCNTL
+#include <fcntl.h>
+#endif
+#ifdef I_SYS_FILE
+#include <sys/file.h>
+#endif
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
+int main() {
+	if(O_RDONLY);
+#ifdef O_TRUNC
+	exit(0);
+#else
+	exit(1);
+#endif
+}
+EOCP
+: check sys/file.h first to get FREAD on Sun
+if $test `./findhdr sys/file.h` && \
+		set try -DI_SYS_FILE && eval $compile; then
+	h_sysfile=true;
+	echo "<sys/file.h> defines the O_* constants..." >&4
+	if $run ./try; then
+		echo "and you have the 3 argument form of open()." >&4
 		val="$define"
 	else
+		echo "but not the 3 argument form of open().  Oh, well." >&4
 		val="$undef"
 	fi
-	set d_pwquota
-	eval $setvar
-
-	if $contains 'pw_age' $$.h >/dev/null 2>&1; then
+elif $test `./findhdr fcntl.h` && \
+		set try -DI_FCNTL && eval $compile; then
+	h_fcntl=true;
+	echo "<fcntl.h> defines the O_* constants..." >&4
+	if $run ./try; then
+		echo "and you have the 3 argument form of open()." >&4
 		val="$define"
 	else
+		echo "but not the 3 argument form of open().  Oh, well." >&4
 		val="$undef"
 	fi
-	set d_pwage
-	eval $setvar
+else
+	val="$undef"
+	echo "I can't find the O_* constant definitions!  You got problems." >&4
+fi
+set d_open3
+eval $setvar
+$rm -f try try.*
 
-	if $contains 'pw_change' $$.h >/dev/null 2>&1; then
-		val="$define"
+: see which of string.h or strings.h is needed
+echo " "
+strings=`./findhdr string.h`
+if $test "$strings" && $test -r "$strings"; then
+	echo "Using <string.h> instead of <strings.h>." >&4
+	val="$define"
+else
+	val="$undef"
+	strings=`./findhdr strings.h`
+	if $test "$strings" && $test -r "$strings"; then
+		echo "Using <strings.h> instead of <string.h>." >&4
 	else
-		val="$undef"
+		echo "No string header found -- You'll surely have problems." >&4
 	fi
-	set d_pwchange
-	eval $setvar
+fi
+set i_string
+eval $setvar
+case "$i_string" in
+"$undef") strings=`./findhdr strings.h`;;
+*)	  strings=`./findhdr string.h`;;
+esac
 
-	if $contains 'pw_class' $$.h >/dev/null 2>&1; then
-		val="$define"
-	else
-		val="$undef"
-	fi
-	set d_pwclass
-	eval $setvar
+: see if this is a sys/file.h system
+val=''
+set sys/file.h val
+eval $inhdr
 
-	if $contains 'pw_expire' $$.h >/dev/null 2>&1; then
+: do we need to include sys/file.h ?
+case "$val" in
+"$define")
+	echo " "
+	if $h_sysfile; then
 		val="$define"
+		echo "We'll be including <sys/file.h>." >&4
 	else
 		val="$undef"
+		echo "We won't be including <sys/file.h>." >&4
 	fi
-	set d_pwexpire
-	eval $setvar
+	;;
+*)
+	h_sysfile=false
+	;;
+esac
+set i_sysfile
+eval $setvar
 
-	if $contains 'pw_comment' $$.h >/dev/null 2>&1; then
+: see if fcntl.h is there
+val=''
+set fcntl.h val
+eval $inhdr
+
+: see if we can include fcntl.h
+case "$val" in
+"$define")
+	echo " "
+	if $h_fcntl; then
 		val="$define"
+		echo "We'll be including <fcntl.h>." >&4
 	else
 		val="$undef"
+		if $h_sysfile; then
+	echo "We don't need to include <fcntl.h> if we include <sys/file.h>." >&4
+		else
+			echo "We won't be including <fcntl.h>." >&4
+		fi
 	fi
-	set d_pwcomment
-	eval $setvar
+	;;
+*)
+	h_fcntl=false
+	val="$undef"
+	;;
+esac
+set i_fcntl
+eval $setvar
 
-	if $contains 'pw_gecos' $$.h >/dev/null 2>&1; then
-		val="$define"
+: check for non-blocking I/O stuff
+case "$h_sysfile" in
+true) echo "#include <sys/file.h>" > head.c;;
+*)
+       case "$h_fcntl" in
+       true) echo "#include <fcntl.h>" > head.c;;
+       *) echo "#include <sys/fcntl.h>" > head.c;;
+       esac
+       ;;
+esac
+echo " "
+echo "Figuring out the flag used by open() for non-blocking I/O..." >&4
+case "$o_nonblock" in
+'')
+	$cat head.c > try.c
+	$cat >>try.c <<EOCP
+#include <stdio.h>
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
+#$i_fcntl I_FCNTL
+#ifdef I_FCNTL
+#include <fcntl.h>
+#endif
+int main() {
+#ifdef O_NONBLOCK
+	printf("O_NONBLOCK\n");
+	exit(0);
+#endif
+#ifdef O_NDELAY
+	printf("O_NDELAY\n");
+	exit(0);
+#endif
+#ifdef FNDELAY
+	printf("FNDELAY\n");
+	exit(0);
+#endif
+	exit(0);
+}
+EOCP
+	set try
+	if eval $compile_ok; then
+		o_nonblock=`$run ./try`
+		case "$o_nonblock" in
+		'') echo "I can't figure it out, assuming O_NONBLOCK will do.";;
+		*) echo "Seems like we can use $o_nonblock.";;
+		esac
 	else
-		val="$undef"
+		echo "(I can't compile the test program; pray O_NONBLOCK is right!)"
 	fi
-	set d_pwgecos
-	eval $setvar
+	;;
+*) echo "Using $hint value $o_nonblock.";;
+esac
+$rm -f try try.* .out core
+
+echo " "
+echo "Let's see what value errno gets from read() on a $o_nonblock file..." >&4
+case "$eagain" in
+'')
+	$cat head.c > try.c
+	$cat >>try.c <<EOCP
+#include <errno.h>
+#include <sys/types.h>
+#include <signal.h>
+#include <stdio.h> 
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
+#$i_fcntl I_FCNTL
+#ifdef I_FCNTL
+#include <fcntl.h>
+#endif
+#define MY_O_NONBLOCK $o_nonblock
+#ifndef errno  /* XXX need better Configure test */
+extern int errno;
+#endif
+#$i_unistd I_UNISTD
+#ifdef I_UNISTD
+#include <unistd.h>
+#endif
+#$i_string I_STRING
+#ifdef I_STRING
+#include <string.h>
+#else
+#include <strings.h>
+#endif
+$signal_t blech(x) int x; { exit(3); }
+EOCP
+	$cat >> try.c <<'EOCP'
+int main()
+{
+	int pd[2];
+	int pu[2];
+	char buf[1];
+	char string[100];
+
+	pipe(pd);	/* Down: child -> parent */
+	pipe(pu);	/* Up: parent -> child */
+	if (0 != fork()) {
+		int ret;
+		close(pd[1]);	/* Parent reads from pd[0] */
+		close(pu[0]);	/* Parent writes (blocking) to pu[1] */
+#ifdef F_SETFL
+		if (-1 == fcntl(pd[0], F_SETFL, MY_O_NONBLOCK))
+			exit(1);
+#else
+		exit(4);
+#endif
+		signal(SIGALRM, blech);
+		alarm(5);
+		if ((ret = read(pd[0], buf, 1)) > 0)	/* Nothing to read! */
+			exit(2);
+		sprintf(string, "%d\n", ret);
+		write(2, string, strlen(string));
+		alarm(0);
+#ifdef EAGAIN
+		if (errno == EAGAIN) {
+			printf("EAGAIN\n");
+			goto ok;
+		}
+#endif
+#ifdef EWOULDBLOCK
+		if (errno == EWOULDBLOCK)
+			printf("EWOULDBLOCK\n");
+#endif
+	ok:
+		write(pu[1], buf, 1);	/* Unblocks child, tell it to close our pipe */
+		sleep(2);				/* Give it time to close our pipe */
+		alarm(5);
+		ret = read(pd[0], buf, 1);	/* Should read EOF */
+		alarm(0);
+		sprintf(string, "%d\n", ret);
+		write(4, string, strlen(string));
+		exit(0);
+	}
 
-	if $contains 'pw_passwd' $$.h >/dev/null 2>&1; then
+	close(pd[0]);			/* We write to pd[1] */
+	close(pu[1]);			/* We read from pu[0] */
+	read(pu[0], buf, 1);	/* Wait for parent to signal us we may continue */
+	close(pd[1]);			/* Pipe pd is now fully closed! */
+	exit(0);				/* Bye bye, thank you for playing! */
+}
+EOCP
+	set try
+	if eval $compile_ok; then
+		echo "$startsh" >mtry
+		echo "$run ./try >try.out 2>try.ret 4>try.err || exit 4" >>mtry
+		chmod +x mtry
+		./mtry >/dev/null 2>&1
+		case $? in
+		0) eagain=`$cat try.out`;;
+		1) echo "Could not perform non-blocking setting!";;
+		2) echo "I did a successful read() for something that was not there!";;
+		3) echo "Hmm... non-blocking I/O does not seem to be working!";;
+		4) echo "Could not find F_SETFL!";;
+		*) echo "Something terribly wrong happened during testing.";;
+		esac
+		rd_nodata=`$cat try.ret`
+		echo "A read() system call with no data present returns $rd_nodata."
+		case "$rd_nodata" in
+		0|-1) ;;
+		*)
+			echo "(That's peculiar, fixing that to be -1.)"
+			rd_nodata=-1
+			;;
+		esac
+		case "$eagain" in
+		'')
+			echo "Forcing errno EAGAIN on read() with no data available."
+			eagain=EAGAIN
+			;;
+		*)
+			echo "Your read() sets errno to $eagain when no data is available."
+			;;
+		esac
+		status=`$cat try.err`
+		case "$status" in
+		0) echo "And it correctly returns 0 to signal EOF.";;
+		-1) echo "But it also returns -1 to signal EOF, so be careful!";;
+		*) echo "However, your read() returns '$status' on EOF??";;
+		esac
 		val="$define"
+		if test "$status" = "$rd_nodata"; then
+			echo "WARNING: you can't distinguish between EOF and no data!"
+			val="$undef"
+		fi
 	else
-		val="$undef"
+		echo "I can't compile the test program--assuming errno EAGAIN will do."
+		eagain=EAGAIN
 	fi
-	set d_pwpasswd
+	set d_eofnblk
 	eval $setvar
-
-	$rm -f $$.h
 	;;
 *)
-	val="$undef"; 
-	set d_pwquota; eval $setvar
-	set d_pwage; eval $setvar
-	set d_pwchange; eval $setvar
-	set d_pwclass; eval $setvar
-	set d_pwexpire; eval $setvar
-	set d_pwcomment; eval $setvar
-	set d_pwgecos; eval $setvar
-	set d_pwpasswd; eval $setvar
+	echo "Using $hint value $eagain."
+	echo "Your read() returns $rd_nodata when no data is present."
+	case "$d_eofnblk" in
+	"$define") echo "And you can see EOF because read() returns 0.";;
+	"$undef") echo "But you can't see EOF status from read() returned value.";;
+	*)
+		echo "(Assuming you can't see EOF status from read anyway.)"
+		d_eofnblk=$undef
+		;;
+	esac
 	;;
 esac
+$rm -f try try.* .out core head.c mtry
 
-: see if endpwent_r exists
-set endpwent_r d_endpwent_r
-eval $inlibc
-case "$d_endpwent_r" in
-"$define")
-	hdrs="$i_systypes sys/types.h define stdio.h $i_pwd pwd.h"
-	case "$d_endpwent_r_proto:$usethreads" in
-	":define")	d_endpwent_r_proto=define
-		set d_endpwent_r_proto endpwent_r $hdrs
-		eval $hasproto ;;
-	*)	;;
+: see if _ptr and _cnt from stdio act std
+echo " "
+
+if $contains '_lbfsize' `./findhdr stdio.h` >/dev/null 2>&1 ; then
+	echo "(Looks like you have stdio.h from BSD.)"
+	case "$stdio_ptr" in
+	'') stdio_ptr='((fp)->_p)'
+		ptr_lval=$define
+		;;
+	*)	ptr_lval=$d_stdio_ptr_lval;;
 	esac
-	case "$d_endpwent_r_proto" in
-	define)
-	case "$endpwent_r_proto" in
-	''|0) try='int endpwent_r(FILE**);'
-	./protochk "extern $try" $hdrs && endpwent_r_proto=I_H ;;
+	case "$stdio_cnt" in
+	'') stdio_cnt='((fp)->_r)'
+		cnt_lval=$define
+		;;
+	*)	cnt_lval=$d_stdio_cnt_lval;;
 	esac
-	case "$endpwent_r_proto" in
-	''|0) try='void endpwent_r(FILE**);'
-	./protochk "extern $try" $hdrs && endpwent_r_proto=V_H ;;
+	case "$stdio_base" in
+	'') stdio_base='((fp)->_ub._base ? (fp)->_ub._base : (fp)->_bf._base)';;
 	esac
-	case "$endpwent_r_proto" in
-	''|0)	d_endpwent_r=undef
- 	        endpwent_r_proto=0
-		echo "Disabling endpwent_r, cannot determine prototype." >&4 ;;
-	* )	case "$endpwent_r_proto" in
-		REENTRANT_PROTO*) ;;
-		*) endpwent_r_proto="REENTRANT_PROTO_$endpwent_r_proto" ;;
-		esac
-		echo "Prototype: $try" ;;
+	case "$stdio_bufsiz" in
+	'') stdio_bufsiz='((fp)->_ub._base ? (fp)->_ub._size : (fp)->_bf._size)';;
 	esac
-	;;
-	*)	case "$usethreads" in
-		define) echo "endpwent_r has no prototype, not using it." >&4 ;;
-		esac
-		d_endpwent_r=undef
-		endpwent_r_proto=0
+elif $contains '_IO_fpos_t' `./findhdr stdio.h` `./findhdr libio.h` >/dev/null 2>&1 ; then
+	echo "(Looks like you have stdio.h from Linux.)"
+	case "$stdio_ptr" in
+	'') stdio_ptr='((fp)->_IO_read_ptr)'
+		ptr_lval=$define
 		;;
+	*)	ptr_lval=$d_stdio_ptr_lval;;
 	esac
-	;;
-*)	endpwent_r_proto=0
-	;;
-esac
-
-: see if endservent exists
-set endservent d_endsent
-eval $inlibc
-
-: see if endservent_r exists
-set endservent_r d_endservent_r
-eval $inlibc
-case "$d_endservent_r" in
-"$define")
-	hdrs="$i_systypes sys/types.h define stdio.h $i_netdb netdb.h"
-	case "$d_endservent_r_proto:$usethreads" in
-	":define")	d_endservent_r_proto=define
-		set d_endservent_r_proto endservent_r $hdrs
-		eval $hasproto ;;
-	*)	;;
+	case "$stdio_cnt" in
+	'') stdio_cnt='((fp)->_IO_read_end - (fp)->_IO_read_ptr)'
+		cnt_lval=$undef
+		;;
+	*)	cnt_lval=$d_stdio_cnt_lval;;
 	esac
-	case "$d_endservent_r_proto" in
-	define)
-	case "$endservent_r_proto" in
-	''|0) try='int endservent_r(struct servent_data*);'
-	./protochk "extern $try" $hdrs && endservent_r_proto=I_D ;;
+	case "$stdio_base" in
+	'') stdio_base='((fp)->_IO_read_base)';;
 	esac
-	case "$endservent_r_proto" in
-	''|0) try='void endservent_r(struct servent_data*);'
-	./protochk "extern $try" $hdrs && endservent_r_proto=V_D ;;
+	case "$stdio_bufsiz" in
+	'') stdio_bufsiz='((fp)->_IO_read_end - (fp)->_IO_read_base)';;
 	esac
-	case "$endservent_r_proto" in
-	''|0)	d_endservent_r=undef
- 	        endservent_r_proto=0
-		echo "Disabling endservent_r, cannot determine prototype." >&4 ;;
-	* )	case "$endservent_r_proto" in
-		REENTRANT_PROTO*) ;;
-		*) endservent_r_proto="REENTRANT_PROTO_$endservent_r_proto" ;;
-		esac
-		echo "Prototype: $try" ;;
+else
+	case "$stdio_ptr" in
+	'') stdio_ptr='((fp)->_ptr)'
+		ptr_lval=$define
+		;;
+	*)	ptr_lval=$d_stdio_ptr_lval;;
 	esac
-	;;
-	*)	case "$usethreads" in
-		define) echo "endservent_r has no prototype, not using it." >&4 ;;
-		esac
-		d_endservent_r=undef
-		endservent_r_proto=0
+	case "$stdio_cnt" in
+	'') stdio_cnt='((fp)->_cnt)'
+		cnt_lval=$define
 		;;
+	*)	cnt_lval=$d_stdio_cnt_lval;;
 	esac
-	;;
-*)	endservent_r_proto=0
-	;;
-esac
-
-: Locate the flags for 'open()'
-echo " "
-$cat >try.c <<'EOCP'
-#include <sys/types.h>
-#ifdef I_FCNTL
-#include <fcntl.h>
-#endif
-#ifdef I_SYS_FILE
-#include <sys/file.h>
+	case "$stdio_base" in
+	'') stdio_base='((fp)->_base)';;
+	esac
+	case "$stdio_bufsiz" in
+	'') stdio_bufsiz='((fp)->_cnt + (fp)->_ptr - (fp)->_base)';;
+	esac
+fi
+
+: test whether _ptr and _cnt really work
+echo "Checking how std your stdio is..." >&4
+$cat >try.c <<EOP
+#include <stdio.h>
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
 #endif
+#define FILE_ptr(fp)	$stdio_ptr
+#define FILE_cnt(fp)	$stdio_cnt
 int main() {
-	if(O_RDONLY);
-#ifdef O_TRUNC
-	exit(0);
-#else
+	FILE *fp = fopen("try.c", "r");
+	char c = getc(fp);
+	if (
+		18 <= FILE_cnt(fp) &&
+		strncmp(FILE_ptr(fp), "include <stdio.h>\n", 18) == 0
+	)
+		exit(0);
 	exit(1);
-#endif
 }
-EOCP
-: check sys/file.h first to get FREAD on Sun
-if $test `./findhdr sys/file.h` && \
-		set try -DI_SYS_FILE && eval $compile; then
-	h_sysfile=true;
-	echo "<sys/file.h> defines the O_* constants..." >&4
-	if $run ./try; then
-		echo "and you have the 3 argument form of open()." >&4
-		val="$define"
-	else
-		echo "but not the 3 argument form of open().  Oh, well." >&4
-		val="$undef"
-	fi
-elif $test `./findhdr fcntl.h` && \
-		set try -DI_FCNTL && eval $compile; then
-	h_fcntl=true;
-	echo "<fcntl.h> defines the O_* constants..." >&4
+EOP
+val="$undef"
+set try
+if eval $compile && $to try.c; then
 	if $run ./try; then
-		echo "and you have the 3 argument form of open()." >&4
+		echo "Your stdio acts pretty std."
 		val="$define"
 	else
-		echo "but not the 3 argument form of open().  Oh, well." >&4
-		val="$undef"
+		echo "Your stdio isn't very std."
 	fi
 else
-	val="$undef"
-	echo "I can't find the O_* constant definitions!  You got problems." >&4
-fi
-set d_open3
-eval $setvar
-$rm -f try try.*
-
-: see which of string.h or strings.h is needed
-echo " "
-strings=`./findhdr string.h`
-if $test "$strings" && $test -r "$strings"; then
-	echo "Using <string.h> instead of <strings.h>." >&4
-	val="$define"
-else
-	val="$undef"
-	strings=`./findhdr strings.h`
-	if $test "$strings" && $test -r "$strings"; then
-		echo "Using <strings.h> instead of <string.h>." >&4
-	else
-		echo "No string header found -- You'll surely have problems." >&4
-	fi
+	echo "Your stdio doesn't appear very std."
 fi
-set i_string
-eval $setvar
-case "$i_string" in
-"$undef") strings=`./findhdr strings.h`;;
-*)	  strings=`./findhdr string.h`;;
-esac
-
-: see if this is a sys/file.h system
-val=''
-set sys/file.h val
-eval $inhdr
+$rm -f try.c try
 
-: do we need to include sys/file.h ?
-case "$val" in
-"$define")
-	echo " "
-	if $h_sysfile; then
-		val="$define"
-		echo "We'll be including <sys/file.h>." >&4
-	else
+# glibc 2.2.90 and above apparently change stdio streams so Perl's
+# direct buffer manipulation no longer works.  The Configure tests
+# should be changed to correctly detect this, but until then,
+# the following check should at least let perl compile and run.
+# (This quick fix should be updated before 5.8.1.)
+# To be defensive, reject all unknown versions, and all versions  > 2.2.9.
+# A. Dougherty, June 3, 2002.
+case "$d_gnulibc" in
+$define)
+	case "$gnulibc_version" in
+	2.[01]*)  ;;
+	2.2) ;;
+	2.2.[0-9]) ;;
+	*)  echo "But I will not snoop inside glibc $gnulibc_version stdio buffers."
 		val="$undef"
-		echo "We won't be including <sys/file.h>." >&4
-	fi
-	;;
-*)
-	h_sysfile=false
+		;;
+	esac
 	;;
 esac
-set i_sysfile
+set d_stdstdio
 eval $setvar
 
-: see if fcntl.h is there
-val=''
-set fcntl.h val
-eval $inhdr
-
-: see if we can include fcntl.h
-case "$val" in
-"$define")
-	echo " "
-	if $h_fcntl; then
-		val="$define"
-		echo "We'll be including <fcntl.h>." >&4
-	else
-		val="$undef"
-		if $h_sysfile; then
-	echo "We don't need to include <fcntl.h> if we include <sys/file.h>." >&4
-		else
-			echo "We won't be including <fcntl.h>." >&4
-		fi
-	fi
-	;;
-*)
-	h_fcntl=false
-	val="$undef"
-	;;
+: Can _ptr be used as an lvalue?
+case "$d_stdstdio$ptr_lval" in
+$define$define) val=$define ;;
+*) val=$undef ;;
 esac
-set i_fcntl
+set d_stdio_ptr_lval
 eval $setvar
 
-: check for non-blocking I/O stuff
-case "$h_sysfile" in
-true) echo "#include <sys/file.h>" > head.c;;
-*)
-       case "$h_fcntl" in
-       true) echo "#include <fcntl.h>" > head.c;;
-       *) echo "#include <sys/fcntl.h>" > head.c;;
-       esac
-       ;;
+: Can _cnt be used as an lvalue?
+case "$d_stdstdio$cnt_lval" in
+$define$define) val=$define ;;
+*) val=$undef ;;
 esac
-echo " "
-echo "Figuring out the flag used by open() for non-blocking I/O..." >&4
-case "$o_nonblock" in
-'')
-	$cat head.c > try.c
-	$cat >>try.c <<EOCP
+set d_stdio_cnt_lval
+eval $setvar
+
+
+: test whether setting _ptr sets _cnt as a side effect
+d_stdio_ptr_lval_sets_cnt="$undef"
+d_stdio_ptr_lval_nochange_cnt="$undef"
+case "$d_stdio_ptr_lval$d_stdstdio" in
+$define$define)
+	echo "Checking to see what happens if we set the stdio ptr..." >&4
+$cat >try.c <<EOP
 #include <stdio.h>
+/* Can we scream? */
+/* Eat dust sed :-) */
+/* In the buffer space, no one can hear you scream. */
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
 #include <stdlib.h>
-#$i_fcntl I_FCNTL
-#ifdef I_FCNTL
-#include <fcntl.h>
 #endif
+#define FILE_ptr(fp)	$stdio_ptr
+#define FILE_cnt(fp)	$stdio_cnt
+#include <sys/types.h>
 int main() {
-#ifdef O_NONBLOCK
-	printf("O_NONBLOCK\n");
-	exit(0);
-#endif
-#ifdef O_NDELAY
-	printf("O_NDELAY\n");
-	exit(0);
-#endif
-#ifdef FNDELAY
-	printf("FNDELAY\n");
-	exit(0);
-#endif
-	exit(0);
+	FILE *fp = fopen("try.c", "r");
+	int c;
+	char *ptr;
+	size_t cnt;
+	if (!fp) {
+	    puts("Fail even to read");
+	    exit(1);
+	}
+	c = getc(fp); /* Read away the first # */
+	if (c == EOF) {
+	    puts("Fail even to read");
+	    exit(1);
+	}
+	if (!(
+		18 <= FILE_cnt(fp) &&
+		strncmp(FILE_ptr(fp), "include <stdio.h>\n", 18) == 0
+	)) {
+		puts("Fail even to read");
+		exit (1);
+	}
+	ptr = (char*) FILE_ptr(fp);
+	cnt = (size_t)FILE_cnt(fp);
+
+	FILE_ptr(fp) += 42;
+
+	if ((char*)FILE_ptr(fp) != (ptr + 42)) {
+		printf("Fail ptr check %p != %p", FILE_ptr(fp), (ptr + 42));
+		exit (1);
+	}
+	if (FILE_cnt(fp) <= 20) {
+		printf ("Fail (<20 chars to test)");
+		exit (1);
+	}
+	if (strncmp(FILE_ptr(fp), "Eat dust sed :-) */\n", 20) != 0) {
+		puts("Fail compare");
+		exit (1);
+	}
+	if (cnt == FILE_cnt(fp)) {
+		puts("Pass_unchanged");
+		exit (0);
+	}	
+	if (FILE_cnt(fp) == (cnt - 42)) {
+		puts("Pass_changed");
+		exit (0);
+	}
+	printf("Fail count was %d now %d\n", cnt, FILE_cnt(fp));
+	return 1;
+
 }
-EOCP
-	set try
-	if eval $compile_ok; then
-		o_nonblock=`$run ./try`
-		case "$o_nonblock" in
-		'') echo "I can't figure it out, assuming O_NONBLOCK will do.";;
-		*) echo "Seems like we can use $o_nonblock.";;
-		esac
+EOP
+	set try
+	if eval $compile && $to try.c; then
+ 		case `$run ./try` in
+		Pass_changed)
+			echo "Increasing ptr in your stdio decreases cnt by the same amount.  Good." >&4
+			d_stdio_ptr_lval_sets_cnt="$define" ;;
+		Pass_unchanged)
+			echo "Increasing ptr in your stdio leaves cnt unchanged.  Good." >&4
+			d_stdio_ptr_lval_nochange_cnt="$define" ;;
+		Fail*)
+			echo "Increasing ptr in your stdio didn't do exactly what I expected.  We'll not be doing that then." >&4 ;;
+		*)
+			echo "It appears attempting to set ptr in your stdio is a bad plan." >&4 ;;
+	esac
 	else
-		echo "(I can't compile the test program; pray O_NONBLOCK is right!)"
+		echo "It seems we can't set ptr in your stdio.  Nevermind." >&4
 	fi
+	$rm -f try.c try
 	;;
-*) echo "Using $hint value $o_nonblock.";;
 esac
-$rm -f try try.* .out core
-
-echo " "
-echo "Let's see what value errno gets from read() on a $o_nonblock file..." >&4
-case "$eagain" in
-'')
-	$cat head.c > try.c
-	$cat >>try.c <<EOCP
-#include <errno.h>
-#include <sys/types.h>
-#include <signal.h>
-#include <stdio.h> 
-#include <stdlib.h> 
-#$i_fcntl I_FCNTL
-#ifdef I_FCNTL
-#include <fcntl.h>
-#endif
-#define MY_O_NONBLOCK $o_nonblock
-#ifndef errno  /* XXX need better Configure test */
-extern int errno;
-#endif
-#$i_unistd I_UNISTD
-#ifdef I_UNISTD
-#include <unistd.h>
-#endif
-#$i_string I_STRING
-#ifdef I_STRING
-#include <string.h>
-#else
-#include <strings.h>
-#endif
-$signal_t blech(x) int x; { exit(3); }
-EOCP
-	$cat >> try.c <<'EOCP'
-int main()
-{
-	int pd[2];
-	int pu[2];
-	char buf[1];
-	char string[100];
 
-	pipe(pd);	/* Down: child -> parent */
-	pipe(pu);	/* Up: parent -> child */
-	if (0 != fork()) {
-		int ret;
-		close(pd[1]);	/* Parent reads from pd[0] */
-		close(pu[0]);	/* Parent writes (blocking) to pu[1] */
-#ifdef F_SETFL
-		if (-1 == fcntl(pd[0], F_SETFL, MY_O_NONBLOCK))
-			exit(1);
-#else
-		exit(4);
-#endif
-		signal(SIGALRM, blech);
-		alarm(5);
-		if ((ret = read(pd[0], buf, 1)) > 0)	/* Nothing to read! */
-			exit(2);
-		sprintf(string, "%d\n", ret);
-		write(2, string, strlen(string));
-		alarm(0);
-#ifdef EAGAIN
-		if (errno == EAGAIN) {
-			printf("EAGAIN\n");
-			goto ok;
-		}
-#endif
-#ifdef EWOULDBLOCK
-		if (errno == EWOULDBLOCK)
-			printf("EWOULDBLOCK\n");
+: see if _base is also standard
+val="$undef"
+case "$d_stdstdio" in
+$define)
+	$cat >try.c <<EOP
+#include <stdio.h>
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
 #endif
-	ok:
-		write(pu[1], buf, 1);	/* Unblocks child, tell it to close our pipe */
-		sleep(2);				/* Give it time to close our pipe */
-		alarm(5);
-		ret = read(pd[0], buf, 1);	/* Should read EOF */
-		alarm(0);
-		sprintf(string, "%d\n", ret);
-		write(4, string, strlen(string));
+#define FILE_base(fp)	$stdio_base
+#define FILE_bufsiz(fp)	$stdio_bufsiz
+int main() {
+	FILE *fp = fopen("try.c", "r");
+	char c = getc(fp);
+	if (
+		19 <= FILE_bufsiz(fp) &&
+		strncmp(FILE_base(fp), "#include <stdio.h>\n", 19) == 0
+	)
 		exit(0);
-	}
-
-	close(pd[0]);			/* We write to pd[1] */
-	close(pu[1]);			/* We read from pu[0] */
-	read(pu[0], buf, 1);	/* Wait for parent to signal us we may continue */
-	close(pd[1]);			/* Pipe pd is now fully closed! */
-	exit(0);				/* Bye bye, thank you for playing! */
+	exit(1);
 }
-EOCP
+EOP
 	set try
-	if eval $compile_ok; then
-		echo "$startsh" >mtry
-		echo "$run ./try >try.out 2>try.ret 4>try.err || exit 4" >>mtry
-		chmod +x mtry
-		./mtry >/dev/null 2>&1
-		case $? in
-		0) eagain=`$cat try.out`;;
-		1) echo "Could not perform non-blocking setting!";;
-		2) echo "I did a successful read() for something that was not there!";;
-		3) echo "Hmm... non-blocking I/O does not seem to be working!";;
-		4) echo "Could not find F_SETFL!";;
-		*) echo "Something terribly wrong happened during testing.";;
-		esac
-		rd_nodata=`$cat try.ret`
-		echo "A read() system call with no data present returns $rd_nodata."
-		case "$rd_nodata" in
-		0|-1) ;;
-		*)
-			echo "(That's peculiar, fixing that to be -1.)"
-			rd_nodata=-1
-			;;
-		esac
-		case "$eagain" in
-		'')
-			echo "Forcing errno EAGAIN on read() with no data available."
-			eagain=EAGAIN
-			;;
-		*)
-			echo "Your read() sets errno to $eagain when no data is available."
-			;;
-		esac
-		status=`$cat try.err`
-		case "$status" in
-		0) echo "And it correctly returns 0 to signal EOF.";;
-		-1) echo "But it also returns -1 to signal EOF, so be careful!";;
-		*) echo "However, your read() returns '$status' on EOF??";;
-		esac
-		val="$define"
-		if test "$status" = "$rd_nodata"; then
-			echo "WARNING: you can't distinguish between EOF and no data!"
-			val="$undef"
+	if eval $compile && $to try.c; then
+		if $run ./try; then
+			echo "And its _base field acts std."
+			val="$define"
+		else
+			echo "But its _base field isn't std."
 		fi
 	else
-		echo "I can't compile the test program--assuming errno EAGAIN will do."
-		eagain=EAGAIN
+		echo "However, it seems to be lacking the _base field."
 	fi
-	set d_eofnblk
-	eval $setvar
+	$rm -f try.c try
 	;;
-*)
-	echo "Using $hint value $eagain."
-	echo "Your read() returns $rd_nodata when no data is present."
-	case "$d_eofnblk" in
-	"$define") echo "And you can see EOF because read() returns 0.";;
-	"$undef") echo "But you can't see EOF status from read() returned value.";;
-	*)
-		echo "(Assuming you can't see EOF status from read anyway.)"
-		d_eofnblk=$undef
+esac
+set d_stdiobase
+eval $setvar
+
+: see if fast_stdio exists
+val="$undef"
+case "$d_stdstdio:$d_stdio_ptr_lval" in
+"$define:$define")
+	case "$d_stdio_cnt_lval$d_stdio_ptr_lval_sets_cnt" in
+	*$define*)
+		echo "You seem to have 'fast stdio' to directly manipulate the stdio buffers." >& 4
+		val="$define"
 		;;
 	esac
 	;;
 esac
-$rm -f try try.* .out core head.c mtry
+set d_faststdio
+eval $setvar
+
+
 
 : see if fchdir exists
 set fchdir d_fchdir
@@ -11274,7 +11594,10 @@ eval $inlibc
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
@@ -11341,6 +11664,10 @@ $cat <<EOM
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
@@ -13021,9 +13348,13 @@ eval $inlibc
 
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
@@ -13268,13 +13599,129 @@ END
 	if $cc $ccflags -c mmap.c >/dev/null 2>&1; then
 		mmaptype='void *'
 	else
-		mmaptype='caddr_t'
+		mmaptype='caddr_t'
+	fi
+	echo "and it returns ($mmaptype)." >&4
+	;;
+esac
+
+
+
+
+: see if sqrtl exists
+set sqrtl d_sqrtl
+eval $inlibc
+
+: see if scalbnl exists
+set scalbnl d_scalbnl
+eval $inlibc
+
+: see if modfl exists
+set modfl d_modfl
+eval $inlibc
+
+: see if prototype for modfl is available
+echo " "
+set d_modflproto modfl math.h
+eval $hasproto
+
+d_modfl_pow32_bug="$undef"
+
+case "$d_longdbl$d_modfl" in
+$define$define)
+	$cat <<EOM
+Checking to see whether your modfl() is okay for large values...
+EOM
+$cat >try.c <<EOCP
+#include <math.h> 
+#include <stdio.h>
+EOCP
+if $test "X$d_modflproto" != "X$define"; then
+	$cat >>try.c <<EOCP
+/* Sigh. many current glibcs provide the function, but do not prototype it.  */ 
+long double modfl (long double, long double *);
+EOCP
+fi
+$cat >>try.c <<EOCP
+int main() {
+    long double nv = 4294967303.15;
+    long double v, w;
+    v = modfl(nv, &w);         
+#ifdef __GLIBC__
+    printf("glibc");
+#endif
+    printf(" %"$sPRIfldbl" %"$sPRIfldbl" %"$sPRIfldbl"\n", nv, v, w);
+    return 0;
+}
+EOCP
+	case "$osname:$gccversion" in
+	aix:)	saveccflags="$ccflags"
+		ccflags="$ccflags -qlongdouble" ;; # to avoid core dump
+	esac
+	set try
+	if eval $compile; then
+		foo=`$run ./try`
+		case "$foo" in
+		*" 4294967303.150000 1.150000 4294967302.000000")
+			echo >&4 "Your modfl() is broken for large values."
+			d_modfl_pow32_bug="$define"
+			case "$foo" in
+			glibc)	echo >&4 "You should upgrade your glibc to at least 2.2.2 to get a fixed modfl()."
+			;;
+			esac
+			;;
+		*" 4294967303.150000 0.150000 4294967303.000000")
+			echo >&4 "Your modfl() seems okay for large values."
+			;;
+		*)	echo >&4 "I don't understand your modfl() at all."
+			d_modfl="$undef"
+			;;
+		esac
+		$rm -f try.* try core core.try.*
+	else
+		echo "I cannot figure out whether your modfl() is okay, assuming it isn't."
+		d_modfl="$undef"
 	fi
-	echo "and it returns ($mmaptype)." >&4
+	case "$osname:$gccversion" in
+	aix:)	ccflags="$saveccflags" ;; # restore
+	esac
 	;;
 esac
 
+if $test "$uselongdouble" = "$define"; then
+    message=""
+    if $test "$d_sqrtl" != "$define"; then
+	message="$message sqrtl"
+    fi
+    if $test "$d_modfl" != "$define"; then
+	if $test "$d_aintl:$d_copysignl" = "$define:$define"; then
+	    echo "You have both aintl and copysignl, so I can emulate modfl."
+	else
+	    message="$message modfl"
+	fi
+    fi
+    if $test "$d_frexpl" != "$define"; then
+	if $test "$d_ilogbl:$d_scalbnl" = "$define:$define"; then
+	    echo "You have both ilogbl and scalbnl, so I can emulate frexpl."
+	else
+	    message="$message frexpl"
+	fi
+    fi
+
+    if $test "$message" != ""; then
+	$cat <<EOM >&4
+
+*** You requested the use of long doubles but you do not seem to have
+*** the following mathematical functions needed for long double support:
+***    $message
+*** Please rerun Configure without -Duselongdouble and/or -Dusemorebits.
+*** Cannot continue, aborting.
+
+EOM
 
+	exit 1
+    fi
+fi
 
 : see if mprotect exists
 set mprotect d_mprotect
@@ -13368,8 +13815,12 @@ echo " "
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
@@ -13609,6 +14060,10 @@ if test X"$d_volatile" = X"$define"; then
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
@@ -14379,7 +14834,7 @@ $define)
 #endif
 END
 
-    $cat > try.c <<END
+      $cat > try.c <<END
 #include <sys/types.h>
 #include <sys/ipc.h>
 #include <sys/sem.h>
@@ -15081,10 +15536,14 @@ echo " "
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
@@ -15116,8 +15575,12 @@ eval $inlibc
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
@@ -15231,343 +15694,87 @@ case "$d_srandom_r" in
 	esac
 	case "$srandom_r_proto" in
 	''|0)	d_srandom_r=undef
- 	        srandom_r_proto=0
-		echo "Disabling srandom_r, cannot determine prototype." >&4 ;;
-	* )	case "$srandom_r_proto" in
-		REENTRANT_PROTO*) ;;
-		*) srandom_r_proto="REENTRANT_PROTO_$srandom_r_proto" ;;
-		esac
-		echo "Prototype: $try" ;;
-	esac
-	;;
-	*)	case "$usethreads" in
-		define) echo "srandom_r has no prototype, not using it." >&4 ;;
-		esac
-		d_srandom_r=undef
-		srandom_r_proto=0
-		;;
-	esac
-	;;
-*)	srandom_r_proto=0
-	;;
-esac
-
-: see if prototype for setresgid is available
-echo " "
-set d_sresgproto setresgid $i_unistd unistd.h
-eval $hasproto
-
-: see if prototype for setresuid is available
-echo " "
-set d_sresuproto setresuid $i_unistd unistd.h
-eval $hasproto
-
-: see if sys/stat.h is available
-set sys/stat.h i_sysstat
-eval $inhdr
-
-
-: see if stat knows about block sizes
-echo " "
-echo "Checking to see if your struct stat has st_blocks field..." >&4
-set d_statblks stat st_blocks $i_sysstat sys/stat.h
-eval $hasfield
-
-
-: see if this is a sys/vfs.h system
-set sys/vfs.h i_sysvfs
-eval $inhdr
-
-
-: see if this is a sys/statfs.h system
-set sys/statfs.h i_sysstatfs
-eval $inhdr
-
-
-echo " "
-echo "Checking to see if your system supports struct statfs..." >&4
-set d_statfs_s statfs $i_systypes sys/types.h $i_sysparam sys/param.h $i_sysmount sys/mount.h $i_sysvfs sys/vfs.h $i_sysstatfs sys/statfs.h
-eval $hasstruct
-case "$d_statfs_s" in
-"$define")      echo "Yes, it does."   ;;
-*)              echo "No, it doesn't." ;;
-esac
-
-
-
-: see if struct statfs knows about f_flags
-case "$d_statfs_s" in
-define)	
-	echo " "
-	echo "Checking to see if your struct statfs has f_flags field..." >&4
-	set d_statfs_f_flags statfs f_flags $i_systypes sys/types.h $i_sysparam sys/param.h $i_sysmount sys/mount.h $i_sysvfs sys/vfs.h $i_sysstatfs sys/statfs.h
-	eval $hasfield
-	;;
-*)	val="$undef"
-	set d_statfs_f_flags
-	eval $setvar
-	;;
-esac
-case "$d_statfs_f_flags" in
-"$define")      echo "Yes, it does."   ;;
-*)              echo "No, it doesn't." ;;
-esac
-
-: see if _ptr and _cnt from stdio act std
-echo " "
-
-if $contains '_lbfsize' `./findhdr stdio.h` >/dev/null 2>&1 ; then
-	echo "(Looks like you have stdio.h from BSD.)"
-	case "$stdio_ptr" in
-	'') stdio_ptr='((fp)->_p)'
-		ptr_lval=$define
-		;;
-	*)	ptr_lval=$d_stdio_ptr_lval;;
-	esac
-	case "$stdio_cnt" in
-	'') stdio_cnt='((fp)->_r)'
-		cnt_lval=$define
-		;;
-	*)	cnt_lval=$d_stdio_cnt_lval;;
-	esac
-	case "$stdio_base" in
-	'') stdio_base='((fp)->_ub._base ? (fp)->_ub._base : (fp)->_bf._base)';;
-	esac
-	case "$stdio_bufsiz" in
-	'') stdio_bufsiz='((fp)->_ub._base ? (fp)->_ub._size : (fp)->_bf._size)';;
-	esac
-elif $contains '_IO_fpos_t' `./findhdr stdio.h` `./findhdr libio.h` >/dev/null 2>&1 ; then
-	echo "(Looks like you have stdio.h from Linux.)"
-	case "$stdio_ptr" in
-	'') stdio_ptr='((fp)->_IO_read_ptr)'
-		ptr_lval=$define
-		;;
-	*)	ptr_lval=$d_stdio_ptr_lval;;
-	esac
-	case "$stdio_cnt" in
-	'') stdio_cnt='((fp)->_IO_read_end - (fp)->_IO_read_ptr)'
-		cnt_lval=$undef
-		;;
-	*)	cnt_lval=$d_stdio_cnt_lval;;
-	esac
-	case "$stdio_base" in
-	'') stdio_base='((fp)->_IO_read_base)';;
-	esac
-	case "$stdio_bufsiz" in
-	'') stdio_bufsiz='((fp)->_IO_read_end - (fp)->_IO_read_base)';;
-	esac
-else
-	case "$stdio_ptr" in
-	'') stdio_ptr='((fp)->_ptr)'
-		ptr_lval=$define
-		;;
-	*)	ptr_lval=$d_stdio_ptr_lval;;
-	esac
-	case "$stdio_cnt" in
-	'') stdio_cnt='((fp)->_cnt)'
-		cnt_lval=$define
-		;;
-	*)	cnt_lval=$d_stdio_cnt_lval;;
-	esac
-	case "$stdio_base" in
-	'') stdio_base='((fp)->_base)';;
-	esac
-	case "$stdio_bufsiz" in
-	'') stdio_bufsiz='((fp)->_cnt + (fp)->_ptr - (fp)->_base)';;
-	esac
-fi
-
-: test whether _ptr and _cnt really work
-echo "Checking how std your stdio is..." >&4
-$cat >try.c <<EOP
-#include <stdio.h>
-#define FILE_ptr(fp)	$stdio_ptr
-#define FILE_cnt(fp)	$stdio_cnt
-int main() {
-	FILE *fp = fopen("try.c", "r");
-	char c = getc(fp);
-	if (
-		18 <= FILE_cnt(fp) &&
-		strncmp(FILE_ptr(fp), "include <stdio.h>\n", 18) == 0
-	)
-		exit(0);
-	exit(1);
-}
-EOP
-val="$undef"
-set try
-if eval $compile && $to try.c; then
-	if $run ./try; then
-		echo "Your stdio acts pretty std."
-		val="$define"
-	else
-		echo "Your stdio isn't very std."
-	fi
-else
-	echo "Your stdio doesn't appear very std."
-fi
-$rm -f try.c try
-
-# glibc 2.2.90 and above apparently change stdio streams so Perl's
-# direct buffer manipulation no longer works.  The Configure tests
-# should be changed to correctly detect this, but until then,
-# the following check should at least let perl compile and run.
-# (This quick fix should be updated before 5.8.1.)
-# To be defensive, reject all unknown versions, and all versions  > 2.2.9.
-# A. Dougherty, June 3, 2002.
-case "$d_gnulibc" in
-$define)
-	case "$gnulibc_version" in
-	2.[01]*)  ;;
-	2.2) ;;
-	2.2.[0-9]) ;;
-	*)  echo "But I will not snoop inside glibc $gnulibc_version stdio buffers."
-		val="$undef"
+ 	        srandom_r_proto=0
+		echo "Disabling srandom_r, cannot determine prototype." >&4 ;;
+	* )	case "$srandom_r_proto" in
+		REENTRANT_PROTO*) ;;
+		*) srandom_r_proto="REENTRANT_PROTO_$srandom_r_proto" ;;
+		esac
+		echo "Prototype: $try" ;;
+	esac
+	;;
+	*)	case "$usethreads" in
+		define) echo "srandom_r has no prototype, not using it." >&4 ;;
+		esac
+		d_srandom_r=undef
+		srandom_r_proto=0
 		;;
 	esac
 	;;
+*)	srandom_r_proto=0
+	;;
 esac
-set d_stdstdio
-eval $setvar
 
-: Can _ptr be used as an lvalue?
-case "$d_stdstdio$ptr_lval" in
-$define$define) val=$define ;;
-*) val=$undef ;;
-esac
-set d_stdio_ptr_lval
-eval $setvar
+: see if prototype for setresgid is available
+echo " "
+set d_sresgproto setresgid $i_unistd unistd.h
+eval $hasproto
 
-: Can _cnt be used as an lvalue?
-case "$d_stdstdio$cnt_lval" in
-$define$define) val=$define ;;
-*) val=$undef ;;
-esac
-set d_stdio_cnt_lval
-eval $setvar
+: see if prototype for setresuid is available
+echo " "
+set d_sresuproto setresuid $i_unistd unistd.h
+eval $hasproto
 
+: see if sys/stat.h is available
+set sys/stat.h i_sysstat
+eval $inhdr
 
-: test whether setting _ptr sets _cnt as a side effect
-d_stdio_ptr_lval_sets_cnt="$undef"
-d_stdio_ptr_lval_nochange_cnt="$undef"
-case "$d_stdio_ptr_lval$d_stdstdio" in
-$define$define)
-	echo "Checking to see what happens if we set the stdio ptr..." >&4
-$cat >try.c <<EOP
-#include <stdio.h>
-/* Can we scream? */
-/* Eat dust sed :-) */
-/* In the buffer space, no one can hear you scream. */
-#define FILE_ptr(fp)	$stdio_ptr
-#define FILE_cnt(fp)	$stdio_cnt
-#include <sys/types.h>
-int main() {
-	FILE *fp = fopen("try.c", "r");
-	int c;
-	char *ptr;
-	size_t cnt;
-	if (!fp) {
-	    puts("Fail even to read");
-	    exit(1);
-	}
-	c = getc(fp); /* Read away the first # */
-	if (c == EOF) {
-	    puts("Fail even to read");
-	    exit(1);
-	}
-	if (!(
-		18 <= FILE_cnt(fp) &&
-		strncmp(FILE_ptr(fp), "include <stdio.h>\n", 18) == 0
-	)) {
-		puts("Fail even to read");
-		exit (1);
-	}
-	ptr = (char*) FILE_ptr(fp);
-	cnt = (size_t)FILE_cnt(fp);
 
-	FILE_ptr(fp) += 42;
+: see if stat knows about block sizes
+echo " "
+echo "Checking to see if your struct stat has st_blocks field..." >&4
+set d_statblks stat st_blocks $i_sysstat sys/stat.h
+eval $hasfield
 
-	if ((char*)FILE_ptr(fp) != (ptr + 42)) {
-		printf("Fail ptr check %p != %p", FILE_ptr(fp), (ptr + 42));
-		exit (1);
-	}
-	if (FILE_cnt(fp) <= 20) {
-		printf ("Fail (<20 chars to test)");
-		exit (1);
-	}
-	if (strncmp(FILE_ptr(fp), "Eat dust sed :-) */\n", 20) != 0) {
-		puts("Fail compare");
-		exit (1);
-	}
-	if (cnt == FILE_cnt(fp)) {
-		puts("Pass_unchanged");
-		exit (0);
-	}	
-	if (FILE_cnt(fp) == (cnt - 42)) {
-		puts("Pass_changed");
-		exit (0);
-	}
-	printf("Fail count was %d now %d\n", cnt, FILE_cnt(fp));
-	return 1;
 
-}
-EOP
-	set try
-	if eval $compile && $to try.c; then
- 		case `$run ./try` in
-		Pass_changed)
-			echo "Increasing ptr in your stdio decreases cnt by the same amount.  Good." >&4
-			d_stdio_ptr_lval_sets_cnt="$define" ;;
-		Pass_unchanged)
-			echo "Increasing ptr in your stdio leaves cnt unchanged.  Good." >&4
-			d_stdio_ptr_lval_nochange_cnt="$define" ;;
-		Fail*)
-			echo "Increasing ptr in your stdio didn't do exactly what I expected.  We'll not be doing that then." >&4 ;;
-		*)
-			echo "It appears attempting to set ptr in your stdio is a bad plan." >&4 ;;
-	esac
-	else
-		echo "It seems we can't set ptr in your stdio.  Nevermind." >&4
-	fi
-	$rm -f try.c try
-	;;
+: see if this is a sys/vfs.h system
+set sys/vfs.h i_sysvfs
+eval $inhdr
+
+
+: see if this is a sys/statfs.h system
+set sys/statfs.h i_sysstatfs
+eval $inhdr
+
+
+echo " "
+echo "Checking to see if your system supports struct statfs..." >&4
+set d_statfs_s statfs $i_systypes sys/types.h $i_sysparam sys/param.h $i_sysmount sys/mount.h $i_sysvfs sys/vfs.h $i_sysstatfs sys/statfs.h
+eval $hasstruct
+case "$d_statfs_s" in
+"$define")      echo "Yes, it does."   ;;
+*)              echo "No, it doesn't." ;;
 esac
 
-: see if _base is also standard
-val="$undef"
-case "$d_stdstdio" in
-$define)
-	$cat >try.c <<EOP
-#include <stdio.h>
-#define FILE_base(fp)	$stdio_base
-#define FILE_bufsiz(fp)	$stdio_bufsiz
-int main() {
-	FILE *fp = fopen("try.c", "r");
-	char c = getc(fp);
-	if (
-		19 <= FILE_bufsiz(fp) &&
-		strncmp(FILE_base(fp), "#include <stdio.h>\n", 19) == 0
-	)
-		exit(0);
-	exit(1);
-}
-EOP
-	set try
-	if eval $compile && $to try.c; then
-		if $run ./try; then
-			echo "And its _base field acts std."
-			val="$define"
-		else
-			echo "But its _base field isn't std."
-		fi
-	else
-		echo "However, it seems to be lacking the _base field."
-	fi
-	$rm -f try.c try
+
+
+: see if struct statfs knows about f_flags
+case "$d_statfs_s" in
+define)	
+	echo " "
+	echo "Checking to see if your struct statfs has f_flags field..." >&4
+	set d_statfs_f_flags statfs f_flags $i_systypes sys/types.h $i_sysparam sys/param.h $i_sysmount sys/mount.h $i_sysvfs sys/vfs.h $i_sysstatfs sys/statfs.h
+	eval $hasfield
+	;;
+*)	val="$undef"
+	set d_statfs_f_flags
+	eval $setvar
 	;;
 esac
-set d_stdiobase
-eval $setvar
+case "$d_statfs_f_flags" in
+"$define")      echo "Yes, it does."   ;;
+*)              echo "No, it doesn't." ;;
+esac
 
 $cat >&4 <<EOM
 Checking how to access stdio streams by file descriptor number...
@@ -16198,6 +16405,10 @@ I'm now running the test program...
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
@@ -16260,6 +16471,10 @@ EOM
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
@@ -16611,6 +16826,10 @@ $define)
 #endif
 #include <sys/types.h>
 #include <stdio.h>
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
 #include <db3/db.h>
 int main(int argc, char *argv[])
 {
@@ -16949,6 +17168,10 @@ sunos) $echo '#define PERL_FFLUSH_ALL_FOPEN_MAX 32' > try.c ;;
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
@@ -17265,6 +17488,10 @@ echo "Checking the size of $zzz..." >&4
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
@@ -17975,7 +18202,11 @@ echo " "
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
@@ -18065,7 +18296,8 @@ esac
 
 : check for the select 'width'
 case "$selectminbits" in
-'') case "$d_select" in
+'') safebits=`expr $ptrsize \* 8`
+    case "$d_select" in
 	$define)
 		$cat <<EOM
 
@@ -18097,25 +18329,31 @@ EOM
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
@@ -18123,6 +18361,7 @@ int main() {
     t.tv_usec = 0;
     select(fd + 1, b, 0, 0, &t);
     for (i = NBITS - 1; i > fd && FD_ISSET(i, b); i--);
+    free(s);
     printf("%d\n", i + 1);
     return 0;
 }
@@ -18133,10 +18372,10 @@ EOCP
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
@@ -18145,7 +18384,8 @@ EOM
 		else
 			rp='What is the minimum number of bits your select() operates on?'
 			case "$byteorder" in
-			1234|12345678)	dflt=32 ;;
+			12345678)	dflt=64 ;;
+			1234)		dflt=32 ;;
 			*)		dflt=1	;;
 			esac
 			. ./myread
@@ -18155,7 +18395,7 @@ EOM
 		$rm -f try.* try
 		;;
 	*)	: no select, so pick a harmless default
-		selectminbits='32'
+		selectminbits=$safebits
 		;;
 	esac
 	;;
@@ -18202,9 +18442,13 @@ xxx="$xxx SYS TERM THAW TRAP TSTP TTIN TTOU URG USR1 USR2"
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
 
@@ -18279,7 +18523,7 @@ END {
 $cat >signal.awk <<'EOP'
 BEGIN { ndups = 0 }
 $1 ~ /^NSIG$/ { nsig = $2 }
-($1 !~ /^NSIG$/) && (NF == 2) {
+($1 !~ /^NSIG$/) && (NF == 2) && ($2 ~ /^[0-9][0-9]*$/) {
     if ($2 > maxsig) { maxsig = $2 }
     if (sig_name[$2]) {
 	dup_name[ndups] = $1
@@ -18432,6 +18676,10 @@ echo "Checking the size of $zzz..." >&4
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
@@ -18535,6 +18783,10 @@ eval $typedef
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
@@ -18617,6 +18869,10 @@ echo "Checking the size of $zzz..." >&4
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
@@ -19440,7 +19696,19 @@ Note that DynaLoader is always built and need not be mentioned here.
 
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
        return;
    }

    if (_ge($version, "5.6.2")) {
        _patch(<<'PATCH');
--- Configure
+++ Configure
@@ -165,6 +165,11 @@ ccversion=''
 ccsymbols=''
 cppccsymbols=''
 cppsymbols=''
+from=''
+run=''
+targetarch=''
+to=''
+usecrosscompile=''
 perllibs=''
 dynamic_ext=''
 extensions=''
@@ -973,6 +978,21 @@ if test -f /etc/unixtovms.exe; then
 	eunicefix=/etc/unixtovms.exe
 fi
 
+: Set executable suffix now -- needed before hints available
+if test -f "/libs/version.library"; then
+: Amiga OS
+    _exe=""
+elif test -f "/system/gnu_library/bin/ar.pm"; then
+: Stratus VOS
+    _exe=".pm"
+elif test -n "$DJGPP"; then
+: DOS DJGPP
+    _exe=".exe"
+elif test -d c:/. ; then
+: OS/2 or cygwin
+    _exe=".exe"
+fi
+
 i_whoami=''
 ccname=''
 ccversion=''
@@ -1060,6 +1080,9 @@ case "$sh" in
 			if test -f "$xxx"; then
 				sh="$xxx";
 				break
+			elif test "X$_exe" != X -a -f "$xxx$_exe"; then
+				sh="$xxx";
+				break
 			elif test -f "$xxx.exe"; then
 				sh="$xxx";
 				break
@@ -1070,7 +1093,7 @@ case "$sh" in
 esac
 
 case "$sh" in
-'')	cat <<EOM >&2
+'')	cat >&2 <<EOM
 $me:  Fatal Error:  I can't find a Bourne Shell anywhere.  
 
 Usually it's in /bin/sh.  How did you even get this far?
@@ -1086,18 +1109,30 @@ if `$sh -c '#' >/dev/null 2>&1`; then
 	shsharp=true
 	spitshell=cat
 	xcat=/bin/cat
-	test -f $xcat || xcat=/usr/bin/cat
-	echo "#!$xcat" >try
-	$eunicefix try
-	chmod +x try
-	./try > today
+	test -f $xcat$_exe || xcat=/usr/bin/cat
+	if test ! -f $xcat$_exe; then
+		for p in `echo $PATH | sed -e "s/$p_/ /g"` $paths; do
+			if test -f $p/cat$_exe; then
+				xcat=$p/cat
+				break
+			fi
+		done
+		if test ! -f $xcat$_exe; then
+			echo "Can't find cat anywhere!"
+			exit 1
+		fi
+	fi
+	echo "#!$xcat" >sharp
+	$eunicefix sharp
+	chmod +x sharp
+	./sharp > today
 	if test -s today; then
 		sharpbang='#!'
 	else
-		echo "#! $xcat" > try
-		$eunicefix try
-		chmod +x try
-		./try > today
+		echo "#! $xcat" > sharp
+		$eunicefix sharp
+		chmod +x sharp
+		./sharp > today
 		if test -s today; then
 			sharpbang='#! '
 		else
@@ -1117,28 +1152,28 @@ else
 	echo "I presume that if # doesn't work, #! won't work either!"
 	sharpbang=': use '
 fi
-rm -f try today
+rm -f sharp today
 
 : figure out how to guarantee sh startup
 case "$startsh" in
 '') startsh=${sharpbang}${sh} ;;
 *)
 esac
-cat >try <<EOSS
+cat >sharp <<EOSS
 $startsh
 set abc
 test "$?abc" != 1
 EOSS
 
-chmod +x try
-$eunicefix try
-if ./try; then
+chmod +x sharp
+$eunicefix sharp
+if ./sharp; then
 	: echo "Yup, it does."
 else
 	echo "Hmm... '$startsh' does not guarantee sh startup..."
 	echo "You may have to fix up the shell scripts to make sure $sh runs them."
 fi
-rm -f try
+rm -f sharp
 
 
 : Save command line options in file UU/cmdline.opt for later use in
@@ -1150,12 +1185,24 @@ config_args='$*'
 config_argc=$#
 EOSH
 argn=1
+args_exp=''
+args_sep=''
 for arg in "$@"; do
 	cat >>cmdline.opt <<EOSH
 config_arg$argn='$arg'
 EOSH
+	# Extreme backslashitis: replace each ' by '"'"'
+	cat <<EOC | sed -e "s/'/'"'"'"'"'"'"'/g" > cmdl.opt
+$arg
+EOC
+	arg_exp=`cat cmdl.opt`
+	args_exp="$args_exp$args_sep'$arg_exp'"
 	argn=`expr $argn + 1`
+	args_sep=' '
 done
+# args_exp is good for restarting self: eval "set X $args_exp"; shift; $0 "$@"
+# used by ./hints/os2.sh
+rm -f cmdl.opt
 
 : produce awk script to parse command line options
 cat >options.awk <<'EOF'
@@ -1518,7 +1565,7 @@ for file in $*; do
 		*/*)
 			dir=`expr X$file : 'X\(.*\)/'`
 			file=`expr X$file : 'X.*/\(.*\)'`
-			(cd $dir && . ./$file)
+			(cd "$dir" && . ./$file)
 			;;
 		*)
 			. ./$file
@@ -1531,19 +1578,19 @@ for file in $*; do
 			dir=`expr X$file : 'X\(.*\)/'`
 			file=`expr X$file : 'X.*/\(.*\)'`
 			(set x $dir; shift; eval $mkdir_p)
-			sh <$src/$dir/$file
+			sh <"$src/$dir/$file"
 			;;
 		*)
-			sh <$src/$file
+			sh <"$src/$file"
 			;;
 		esac
 		;;
 	esac
 done
-if test -f $src/config_h.SH; then
+if test -f "$src/config_h.SH"; then
 	if test ! -f config.h; then
 	: oops, they left it out of MANIFEST, probably, so do it anyway.
-	. $src/config_h.SH
+	. "$src/config_h.SH"
 	fi
 fi
 EOS
@@ -1599,13 +1646,13 @@ rm -f .echotmp
 
 : Now test for existence of everything in MANIFEST
 echo " "
-if test -f $rsrc/MANIFEST; then
+if test -f "$rsrc/MANIFEST"; then
 	echo "First let's make sure your kit is complete.  Checking..." >&4
-	awk '$1 !~ /PACK[A-Z]+/ {print $1}' $rsrc/MANIFEST | split -50
+	awk '$1 !~ /PACK[A-Z]+/ {print $1}' "$rsrc/MANIFEST" | (split -l 50 2>/dev/null || split -50)
 	rm -f missing
 	tmppwd=`pwd`
 	for filelist in x??; do
-		(cd $rsrc; ls `cat $tmppwd/$filelist` >/dev/null 2>>$tmppwd/missing)
+		(cd "$rsrc"; ls `cat "$tmppwd/$filelist"` >/dev/null 2>>"$tmppwd/missing")
 	done
 	if test -s missing; then
 		cat missing >&4
@@ -1654,6 +1701,11 @@ if test X"$trnl" = X; then
 	foox) trnl='\012' ;;
 	esac
 fi
+if test X"$trnl" = X; then
+       case "`echo foo|tr '\r\n' xy 2>/dev/null`" in
+       fooxy) trnl='\n\r' ;;
+       esac
+fi
 if test X"$trnl" = X; then
 	cat <<EOM >&2
 
@@ -2008,7 +2060,7 @@ for file in $loclist; do
 	'') xxx=`./loc $file $file $pth`;;
 	*) xxx=`./loc $xxx $xxx $pth`;;
 	esac
-	eval $file=$xxx
+	eval $file=$xxx$_exe
 	eval _$file=$xxx
 	case "$xxx" in
 	/*)
@@ -2041,7 +2093,7 @@ for file in $trylist; do
 	'') xxx=`./loc $file $file $pth`;;
 	*) xxx=`./loc $xxx $xxx $pth`;;
 	esac
-	eval $file=$xxx
+	eval $file=$xxx$_exe
 	eval _$file=$xxx
 	case "$xxx" in
 	/*)
@@ -2074,7 +2126,6 @@ test)
 	;;
 *)
 	if `sh -c "PATH= test true" >/dev/null 2>&1`; then
-		echo "Using the test built into your sh."
 		echo "Using the test built into your sh."
 		test=test
 		_test=test
@@ -2112,10 +2163,10 @@ FOO
 	;;
 esac
 
-cat <<EOS >checkcc
+cat <<EOS >trygcc
 $startsh
 EOS
-cat <<'EOSC' >>checkcc
+cat <<'EOSC' >>trygcc
 case "$cc" in
 '') ;;
 *)  $rm -f try try.*
@@ -2124,7 +2175,7 @@ int main(int argc, char *argv[]) {
   return 0;
 }
 EOM
-    if $cc -o try $ccflags try.c; then
+    if $cc -o try $ccflags $ldflags try.c; then
        :
     else
         echo "Uh-oh, the C compiler '$cc' doesn't seem to be working." >&4
@@ -2153,11 +2204,43 @@ EOM
                     fi
                 fi  
                 case "$ans" in
-                [yY]*) cc=gcc; ccname=gcc; ccflags=''; despair=no ;;
+                [yY]*) cc=gcc; ccname=gcc; ccflags=''; despair=no;
+                       if $test -f usethreads.cbu; then
+                           $cat >&4 <<EOM 
+
+*** However, any setting of the C compiler flags (e.g. for thread support)
+*** has been lost.  It may be necessary to pass -Dcc=gcc to Configure
+*** (together with e.g. -Dusethreads).
+
+EOM
+                       fi;;
                 esac
             fi
         fi
+    fi
+    $rm -f try try.*
+    ;;
+esac
+EOSC
+
+cat <<EOS >checkcc
+$startsh
+EOS
+cat <<'EOSC' >>checkcc
+case "$cc" in        
+'') ;;
+*)  $rm -f try try.*              
+    $cat >try.c <<EOM
+int main(int argc, char *argv[]) {
+  return 0;
+}
+EOM
+    if $cc -o try $ccflags $ldflags try.c; then
+       :
+    else
         if $test X"$despair" = Xyes; then
+           echo "Uh-oh, the C compiler '$cc' doesn't seem to be working." >&4
+        fi
 	    $cat >&4 <<EOM
 You need to find a working C compiler.
 Either (purchase and) install the C compiler supplied by your OS vendor,
@@ -2166,7 +2249,6 @@ I cannot continue any further, aborting.
 EOM
             exit 1
         fi
-    fi
     $rm -f try try.*
     ;;
 esac
@@ -2187,24 +2269,47 @@ $rm -f blurfl sym
 : determine whether symbolic links are supported
 echo " "
 case "$lns" in
-*"ln -s")
+*"ln"*" -s")
 	echo "Checking how to test for symbolic links..." >&4
 	$lns blurfl sym
 	if $test "X$issymlink" = X; then
-		sh -c "PATH= test -h sym" >/dev/null 2>&1
+		case "$newsh" in
+		'') sh     -c "PATH= test -h sym" >/dev/null 2>&1 ;;
+		*)  $newsh -c "PATH= test -h sym" >/dev/null 2>&1 ;;
+		esac
 		if test $? = 0; then
 			issymlink="test -h"
+		else
+			echo "Your builtin 'test -h' may be broken." >&4
+			case "$test" in
+			/*)	;;
+			*)	pth=`echo $PATH | sed -e "s/$p_/ /g"`
+				for p in $pth
+				do
+					if test -f "$p/$test"; then
+						test="$p/$test"
+						break
 		fi		
-	fi
-	if $test "X$issymlink" = X; then
-		if  $test -h >/dev/null 2>&1; then
+				done
+				;;
+			esac
+			case "$test" in
+			/*)
+				echo "Trying external '$test -h'." >&4
 			issymlink="$test -h"
-			echo "Your builtin 'test -h' may be broken, I'm using external '$test -h'." >&4
+				if $test ! -h sym >/dev/null 2>&1; then
+					echo "External '$test -h' is broken, too." >&4
+					issymlink=''
 		fi		
+				;;
+			*)	issymlink='' ;;
+			esac
+	fi
 	fi
 	if $test "X$issymlink" = X; then
 		if $test -L sym 2>/dev/null; then
 			issymlink="$test -L"
+			echo "The builtin '$test -L' worked." >&4
 		fi
 	fi
 	if $test "X$issymlink" != X; then
@@ -2227,7 +2332,7 @@ $define|true|[yY]*)
 		exit 1
 		;;
 	*)	case "$lns:$issymlink" in
-		*"ln -s:"*"test -"?)
+		*"ln"*" -s:"*"test -"?)
 			echo "Creating the symbolic links..." >&4
 			echo "(First creating the subdirectories...)" >&4
 			cd ..
@@ -2257,8 +2362,8 @@ $define|true|[yY]*)
 				fi
 			done
 			# Sanity check 2.
-			if test ! -f t/base/cond.t; then
-				echo "Failed to create the symlinks.  Aborting." >&4
+			if test ! -f t/base/lex.t; then
+				echo "Failed to create the symlinks (t/base/lex.t missing).  Aborting." >&4
 				exit 1
 			fi
 			cd UU
@@ -2271,6 +2376,250 @@ $define|true|[yY]*)
 	;;
 esac
 
+
+case "$usecrosscompile" in
+$define|true|[yY]*)
+	$echo "Cross-compiling..."
+        croak=''
+    	case "$cc" in
+	*-*-gcc) # A cross-compiling gcc, probably.
+	    targetarch=`$echo $cc|$sed 's/-gcc$//'`
+	    ar=$targetarch-ar
+	    # leave out ld, choosing it is more complex
+	    nm=$targetarch-nm
+	    ranlib=$targetarch-ranlib
+	    $echo 'extern int foo;' > try.c
+	    set X `$cc -v -E try.c 2>&1 | $awk '/^#include </,/^End of search /'|$grep '/include'`
+	    shift
+            if $test $# -gt 0; then
+	        incpth="$incpth $*"
+		incpth="`$echo $incpth|$sed 's/^ //'`"
+                echo "Guessing incpth '$incpth'." >&4
+                for i in $*; do
+		    j="`$echo $i|$sed 's,/include$,/lib,'`"
+		    if $test -d $j; then
+			libpth="$libpth $j"
+		    fi
+                done   
+		libpth="`$echo $libpth|$sed 's/^ //'`"
+                echo "Guessing libpth '$libpth'." >&4
+	    fi
+	    $rm -f try.c
+	    ;;
+	esac
+	case "$targetarch" in
+	'') echo "Targetarch not defined." >&4; croak=y ;;
+        *)  echo "Using targetarch $targetarch." >&4 ;;
+	esac
+	case "$incpth" in
+	'') echo "Incpth not defined." >&4; croak=y ;;
+        *)  echo "Using incpth '$incpth'." >&4 ;;
+	esac
+	case "$libpth" in
+	'') echo "Libpth not defined." >&4; croak=y ;;
+        *)  echo "Using libpth '$libpth'." >&4 ;;
+	esac
+	case "$usrinc" in
+	'') for i in $incpth; do
+	        if $test -f $i/errno.h -a -f $i/stdio.h -a -f $i/time.h; then
+		    usrinc=$i
+	            echo "Guessing usrinc $usrinc." >&4
+		    break
+		fi
+	    done
+	    case "$usrinc" in
+	    '') echo "Usrinc not defined." >&4; croak=y ;;
+	    esac
+            ;;
+        *)  echo "Using usrinc $usrinc." >&4 ;;
+	esac
+	case "$targethost" in
+	'') echo "Targethost not defined." >&4; croak=y ;;
+        *)  echo "Using targethost $targethost." >&4
+	esac
+	locincpth=' '
+	loclibpth=' '
+	case "$croak" in
+	y) echo "Cannot continue, aborting." >&4; exit 1 ;;
+	esac
+	case "$src" in
+	/*) run=$src/Cross/run
+	    targetmkdir=$src/Cross/mkdir
+	    to=$src/Cross/to
+	    from=$src/Cross/from
+	    ;;
+	*)  pwd=`$test -f ../Configure & cd ..; pwd`
+	    run=$pwd/Cross/run
+	    targetmkdir=$pwd/Cross/mkdir
+	    to=$pwd/Cross/to
+	    from=$pwd/Cross/from
+	    ;;
+	esac
+	case "$targetrun" in
+	'') targetrun=ssh ;;
+	esac
+	case "$targetto" in
+	'') targetto=scp ;;
+	esac
+	case "$targetfrom" in
+	'') targetfrom=scp ;;
+	esac
+    	run=$run-$targetrun
+    	to=$to-$targetto
+    	from=$from-$targetfrom
+	case "$targetdir" in
+	'')  targetdir=/tmp
+             echo "Guessing targetdir $targetdir." >&4
+             ;;
+	esac
+	case "$targetuser" in
+	'')  targetuser=root
+             echo "Guessing targetuser $targetuser." >&4
+             ;;
+	esac
+	case "$targetfrom" in
+	scp)	q=-q ;;
+	*)	q='' ;;
+	esac
+	case "$targetrun" in
+	ssh|rsh)
+	    cat >$run <<EOF
+#!/bin/sh
+case "\$1" in
+-cwd)
+  shift
+  cwd=\$1
+  shift
+  ;;
+esac
+case "\$cwd" in
+'') cwd=$targetdir ;;
+esac
+exe=\$1
+shift
+if $test ! -f \$exe.xok; then
+  $to \$exe
+  $touch \$exe.xok
+fi
+$targetrun -l $targetuser $targethost "cd \$cwd && ./\$exe \$@"
+EOF
+	    ;;
+	*)  echo "Unknown targetrun '$targetrun'" >&4
+	    exit 1
+	    ;;
+	esac
+	case "$targetmkdir" in
+	*/Cross/mkdir)
+	    cat >$targetmkdir <<EOF
+#!/bin/sh
+$targetrun -l $targetuser $targethost "mkdir -p \$@"
+EOF
+	    $chmod a+rx $targetmkdir
+	    ;;
+	*)  echo "Unknown targetmkdir '$targetmkdir'" >&4
+	    exit 1
+	    ;;
+	esac
+	case "$targetto" in
+	scp|rcp)
+	    cat >$to <<EOF
+#!/bin/sh
+for f in \$@
+do
+  case "\$f" in
+  /*)
+    $targetmkdir \`dirname \$f\`
+    $targetto $q \$f $targetuser@$targethost:\$f            || exit 1
+    ;;
+  *)
+    $targetmkdir $targetdir/\`dirname \$f\`
+    $targetto $q \$f $targetuser@$targethost:$targetdir/\$f || exit 1
+    ;;
+  esac
+done
+exit 0
+EOF
+	    ;;
+	cp) cat >$to <<EOF
+#!/bin/sh
+for f in \$@
+do
+  case "\$f" in
+  /*)
+    $mkdir -p $targetdir/\`dirname \$f\`
+    $cp \$f $targetdir/\$f || exit 1
+    ;;
+  *)
+    $targetmkdir $targetdir/\`dirname \$f\`
+    $cp \$f $targetdir/\$f || exit 1
+    ;;
+  esac
+done
+exit 0
+EOF
+	    ;;
+	*)  echo "Unknown targetto '$targetto'" >&4
+	    exit 1
+	    ;;
+	esac
+	case "$targetfrom" in
+	scp|rcp)
+	  cat >$from <<EOF
+#!/bin/sh
+for f in \$@
+do
+  $rm -f \$f
+  $targetfrom $q $targetuser@$targethost:$targetdir/\$f . || exit 1
+done
+exit 0
+EOF
+	    ;;
+	cp) cat >$from <<EOF
+#!/bin/sh
+for f in \$@
+do
+  $rm -f \$f
+  cp $targetdir/\$f . || exit 1
+done
+exit 0
+EOF
+	    ;;
+	*)  echo "Unknown targetfrom '$targetfrom'" >&4
+	    exit 1
+	    ;;
+	esac
+	if $test ! -f $run; then
+	    echo "Target 'run' script '$run' not found." >&4
+	else
+	    $chmod a+rx $run
+	fi
+	if $test ! -f $to; then
+	    echo "Target 'to' script '$to' not found." >&4
+	else
+	    $chmod a+rx $to
+	fi
+	if $test ! -f $from; then
+	    echo "Target 'from' script '$from' not found." >&4
+	else
+	    $chmod a+rx $from
+	fi
+	if $test ! -f $run -o ! -f $to -o ! -f $from; then
+	    exit 1
+	fi
+	cat >&4 <<EOF
+Using '$run' for remote execution,
+and '$from' and '$to'
+for remote file transfer.
+EOF
+	;;
+*)	run=''
+	to=:
+	from=:
+	usecrosscompile='undef'
+	targetarch=''
+	;;
+esac
+
 : see whether [:lower:] and [:upper:] are supported character classes
 echo " "
 case "`echo AbyZ | $tr '[:lower:]' '[:upper:]' 2>/dev/null`" in
@@ -2542,6 +2891,9 @@ EOM
 			;;
 		next*) osname=next ;;
 		nonstop-ux) osname=nonstopux ;;
+		openbsd) osname=openbsd
+                	osvers="$3"
+                	;;
 		POSIX-BC | posix-bc ) osname=posix-bc
 			osvers="$3"
 			;;
@@ -2735,7 +3087,7 @@ EOM
 		elif $test -f $src/hints/$file.sh; then
 			. $src/hints/$file.sh
 			$cat $src/hints/$file.sh >> UU/config.sh
-		elif $test X$tans = X -o X$tans = Xnone ; then
+		elif $test X"$tans" = X -o X"$tans" = Xnone ; then
 			: nothing
 		else
 			: Give one chance to correct a possible typo.
@@ -3124,7 +3476,7 @@ fi
 
 echo " "
 echo "Checking for GNU cc in disguise and/or its version number..." >&4
-$cat >gccvers.c <<EOM
+$cat >try.c <<EOM
 #include <stdio.h>
 int main() {
 #ifdef __GNUC__
@@ -3134,11 +3486,11 @@ int main() {
 	printf("%s\n", "1");
 #endif
 #endif
-	exit(0);
+	return(0);
 }
 EOM
-if $cc -o gccvers $ccflags $ldflags gccvers.c; then
-	gccversion=`./gccvers`
+if $cc -o try $ccflags $ldflags try.c; then
+	gccversion=`$run ./try`
 	case "$gccversion" in
 	'') echo "You are not using GNU cc." ;;
 	*)  echo "You are using GNU cc $gccversion."
@@ -3156,7 +3508,7 @@ else
 		;;
 	esac
 fi
-$rm -f gccvers*
+$rm -f try try.*
 case "$gccversion" in
 1.*) cpp=`./loc gcc-cpp $cpp $pth` ;;
 esac
@@ -3409,7 +3761,9 @@ esac
 
 case "$fn" in
 *\(*)
-	expr $fn : '.*(\(.*\)).*' | $tr ',' $trnl >getfile.ok
+	: getfile will accept an answer from the comma-separated list
+	: enclosed in parentheses even if it does not meet other criteria.
+	expr "$fn" : '.*(\(.*\)).*' | $tr ',' $trnl >getfile.ok
 	fn=`echo $fn | sed 's/(.*)//'`
 	;;
 esac
@@ -3851,7 +4205,7 @@ for thislib in $libswanted; do
 	for thisdir in $libspath; do
 	    xxx=''
 	    if $test ! -f "$xxx" -a "X$ignore_versioned_solibs" = "X"; then
-		xxx=`ls $thisdir/lib$thislib.$so.[0-9] 2>/dev/null|tail -1`
+		xxx=`ls $thisdir/lib$thislib.$so.[0-9] 2>/dev/null|sed -n '$p'`
 	        $test -f "$xxx" && eval $libscheck
 		$test -f "$xxx" && libstyle=shared
 	    fi
@@ -4063,7 +4417,10 @@ none) ccflags='';;
 esac
 
 : the following weeds options from ccflags that are of no interest to cpp
-cppflags="$ccflags"
+case "$cppflags" in
+'') cppflags="$ccflags" ;;
+*)  cppflags="$cppflags $ccflags" ;;
+esac
 case "$gccversion" in
 1.*) cppflags="$cppflags -D__GNUC__"
 esac
@@ -4171,7 +4528,7 @@ echo " "
 echo "Checking your choice of C compiler and flags for coherency..." >&4
 $cat > try.c <<'EOF'
 #include <stdio.h>
-int main() { printf("Ok\n"); exit(0); }
+int main() { printf("Ok\n"); return(0); }
 EOF
 set X $cc -o try $optimize $ccflags $ldflags try.c $libs
 shift
@@ -4186,15 +4543,15 @@ $cat >> try.msg <<EOM
 I used the command:
 
 	$*
-	./try
+	$run ./try
 
 and I got the following output:
 
 EOM
 dflt=y
 if $sh -c "$cc -o try $optimize $ccflags $ldflags try.c $libs" >>try.msg 2>&1; then
-	if $sh -c './try' >>try.msg 2>&1; then
-		xxx=`./try`
+	if $sh -c "$run ./try" >>try.msg 2>&1; then
+		xxx=`$run ./try`
 		case "$xxx" in
 		"Ok") dflt=n ;;
 		*)	echo 'The program compiled OK, but produced no output.' >> try.msg
@@ -4311,13 +4668,130 @@ mc_file=$1;
 shift;
 $cc -o ${mc_file} $optimize $ccflags $ldflags $* ${mc_file}.c $libs;'
 
+: determine filename position in cpp output
+echo " "
+echo "Computing filename position in cpp output for #include directives..." >&4
+case "$osname" in
+vos) testaccess=-e ;;
+*)   testaccess=-r ;;
+esac
+echo '#include <stdio.h>' > foo.c
+$cat >fieldn <<EOF
+$startsh
+$cppstdin $cppflags $cppminus <foo.c 2>/dev/null | \
+$grep '^[ 	]*#.*stdio\.h' | \
+while read cline; do
+	pos=1
+	set \$cline
+	while $test \$# -gt 0; do
+		if $test $testaccess \`echo \$1 | $tr -d '"'\`; then
+			echo "\$pos"
+			exit 0
+		fi
+		shift
+		pos=\`expr \$pos + 1\`
+	done
+done
+EOF
+chmod +x fieldn
+fieldn=`./fieldn`
+$rm -f foo.c fieldn
+case $fieldn in
+'') pos='???';;
+1) pos=first;;
+2) pos=second;;
+3) pos=third;;
+*) pos="${fieldn}th";;
+esac
+echo "Your cpp writes the filename in the $pos field of the line."
+
+case "$osname" in
+vos) cppfilter="tr '\\\\>' '/' |" ;; # path component separator is >
+*)   cppfilter='' ;;
+esac
+: locate header file
+$cat >findhdr <<EOF
+$startsh
+wanted=\$1
+name=''
+for usrincdir in $usrinc
+do
+	if test -f \$usrincdir/\$wanted; then
+		echo "\$usrincdir/\$wanted"
+		exit 0
+	fi
+done
+awkprg='{ print \$$fieldn }'
+echo "#include <\$wanted>" > foo\$\$.c
+$cppstdin $cppminus $cppflags < foo\$\$.c 2>/dev/null | \
+$cppfilter $grep "^[ 	]*#.*\$wanted" | \
+while read cline; do
+	name=\`echo \$cline | $awk "\$awkprg" | $tr -d '"'\`
+	case "\$name" in
+	*[/\\\\]\$wanted) echo "\$name"; exit 1;;
+	*[\\\\/]\$wanted) echo "\$name"; exit 1;;
+	*) exit 2;;
+	esac;
+done;
+#
+# status = 0: grep returned 0 lines, case statement not executed
+# status = 1: headerfile found
+# status = 2: while loop executed, no headerfile found
+#
+status=\$?
+$rm -f foo\$\$.c;
+if test \$status -eq 1; then
+	exit 0;
+fi
+exit 1
+EOF
+chmod +x findhdr
+
+: define an alternate in-header-list? function
+inhdr='echo " "; td=$define; tu=$undef; yyy=$@;
+cont=true; xxf="echo \"<\$1> found.\" >&4";
+case $# in 2) xxnf="echo \"<\$1> NOT found.\" >&4";;
+*) xxnf="echo \"<\$1> NOT found, ...\" >&4";;
+esac;
+case $# in 4) instead=instead;; *) instead="at last";; esac;
+while $test "$cont"; do
+	xxx=`./findhdr $1`
+	var=$2; eval "was=\$$2";
+	if $test "$xxx" && $test -r "$xxx";
+	then eval $xxf;
+	eval "case \"\$$var\" in $undef) . ./whoa; esac"; eval "$var=\$td";
+		cont="";
+	else eval $xxnf;
+	eval "case \"\$$var\" in $define) . ./whoa; esac"; eval "$var=\$tu"; fi;
+	set $yyy; shift; shift; yyy=$@;
+	case $# in 0) cont="";;
+	2) xxf="echo \"but I found <\$1> $instead.\" >&4";
+		xxnf="echo \"and I did not find <\$1> either.\" >&4";;
+	*) xxf="echo \"but I found <\$1\> instead.\" >&4";
+		xxnf="echo \"there is no <\$1>, ...\" >&4";;
+	esac;
+done;
+while $test "$yyy";
+do set $yyy; var=$2; eval "was=\$$2";
+	eval "case \"\$$var\" in $define) . ./whoa; esac"; eval "$var=\$tu";
+	set $yyy; shift; shift; yyy=$@;
+done'
+
+: see if stdlib is available
+set stdlib.h i_stdlib
+eval $inhdr
+
 : check for lengths of integral types
 echo " "
 case "$intsize" in
 '')
 	echo "Checking to see how big your integers are..." >&4
-	$cat >intsize.c <<'EOCP'
+	$cat >try.c <<EOCP
 #include <stdio.h>
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
 int main()
 {
 	printf("intsize=%d;\n", (int)sizeof(int));
@@ -4326,9 +4800,9 @@ int main()
 	exit(0);
 }
 EOCP
-	set intsize
-	if eval $compile_ok && ./intsize > /dev/null; then
-		eval `./intsize`
+	set try
+	if eval $compile_ok && $run ./try > /dev/null; then
+		eval `$run ./try`
 		echo "Your integers are $intsize bytes long."
 		echo "Your long integers are $longsize bytes long."
 		echo "Your short integers are $shortsize bytes long."
@@ -4355,7 +4829,7 @@ EOM
 	fi
 	;;
 esac
-$rm -f intsize intsize.*
+$rm -f try try.*
 
 : see what type lseek is declared as in the kernel
 rp="What is the type used for lseek's offset on this system?"
@@ -4375,7 +4849,7 @@ int main()
 EOCP
 set try
 if eval $compile_ok; then
-	lseeksize=`./try`
+	lseeksize=`$run ./try`
 	echo "Your file offsets are $lseeksize bytes long."
 else
 	dflt=$longsize
@@ -4401,6 +4875,10 @@ echo "Checking the size of $zzz..." >&4
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
@@ -4408,7 +4886,7 @@ int main() {
 EOCP
 set try
 if eval $compile_ok; then
-	yyy=`./try`
+	yyy=`$run ./try`
 	case "$yyy" in
 	'')	fpossize=4
 		echo "(I can't execute the test program--guessing $fpossize.)" >&4
@@ -4487,7 +4965,7 @@ int main()
 EOCP
 		set try
 		if eval $compile_ok; then
-			lseeksize=`./try`
+			lseeksize=`$run ./try`
 			$echo "Your file offsets are now $lseeksize bytes long."
 		else
 			dflt="$lseeksize"
@@ -4505,14 +4983,18 @@ EOCP
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
 		if eval $compile_ok; then
-			yyy=`./try`
+			yyy=`$run ./try`
 			dflt="$lseeksize"
 			case "$yyy" in
 			'')	echo " "
@@ -4716,26 +5198,43 @@ esac
 
 echo " "
 echo "Checking for GNU C Library..." >&4
-cat >gnulibc.c <<EOM
+cat >try.c <<'EOCP'
+/* Find out version of GNU C library.  __GLIBC__ and __GLIBC_MINOR__
+   alone are insufficient to distinguish different versions, such as
+   2.0.6 and 2.0.7.  The function gnu_get_libc_version() appeared in
+   libc version 2.1.0.      A. Dougherty,  June 3, 2002.
+*/
 #include <stdio.h>
-int main()
+int main(void)
 {
 #ifdef __GLIBC__
-    exit(0);
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
 #else
-    exit(1);
+    return 1;
 #endif
 }
-EOM
-set gnulibc
-if eval $compile_ok && ./gnulibc; then
+EOCP
+set try
+if eval $compile_ok && $run ./try > glibc.ver; then
 	val="$define"
-	echo "You are using the GNU C Library"
+	gnulibc_version=`$cat glibc.ver`
+	echo "You are using the GNU C Library version $gnulibc_version"
 else
 	val="$undef"
+	gnulibc_version=''
 	echo "You are not using the GNU C Library"
 fi
-$rm -f gnulibc*
+$rm -f try try.* glibc.ver
 set d_gnulibc
 eval $setvar
 
@@ -4752,7 +5251,7 @@ case "$usenm" in
 	esac
 	case "$dflt" in
 	'') 
-		if $test "$osname" = aix -a ! -f /lib/syscalls.exp; then
+		if $test "$osname" = aix -a "X$PASE" != "Xdefine" -a ! -f /lib/syscalls.exp; then
 			echo " "
 			echo "Whoops!  This is an AIX system without /lib/syscalls.exp!" >&4
 			echo "'nm' won't be sufficient on this sytem." >&4
@@ -4989,9 +5488,9 @@ done >libc.tmp
 $echo $n ".$c"
 $grep fprintf libc.tmp > libc.ptf
 xscan='eval "<libc.ptf $com >libc.list"; $echo $n ".$c" >&4'
-xrun='eval "<libc.tmp $com >libc.list"; echo "done" >&4'
+xrun='eval "<libc.tmp $com >libc.list"; echo "done." >&4'
 xxx='[ADTSIW]'
-if com="$sed -n -e 's/__IO//' -e 's/^.* $xxx  *_[_.]*//p' -e 's/^.* $xxx  *//p'";\
+if com="$sed -n -e 's/__IO//' -e 's/^.* $xxx  *//p'";\
 	eval $xscan;\
 	$contains '^fprintf$' libc.list >/dev/null 2>&1; then
 		eval $xrun
@@ -5241,8 +5740,12 @@ echo " "
 case "$doublesize" in
 '')
 	echo "Checking to see how big your double precision numbers are..." >&4
-	$cat >try.c <<'EOCP'
+	$cat >try.c <<EOCP
 #include <stdio.h>
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
 int main()
 {
     printf("%d\n", (int)sizeof(double));
@@ -5251,7 +5754,7 @@ int main()
 EOCP
 	set try
 	if eval $compile_ok; then
-		doublesize=`./try`
+		doublesize=`$run ./try`
 		echo "Your double is $doublesize bytes long."
 	else
 		dflt='8'
@@ -5295,7 +5798,7 @@ EOCP
 	set try
 	set try
 	if eval $compile; then
-		longdblsize=`./try$exe_ext`
+		longdblsize=`$run ./try`
 		echo "Your long doubles are $longdblsize bytes long."
 	else
 		dflt='8'
@@ -5306,7 +5809,9 @@ EOCP
 		longdblsize="$ans"
 	fi
 	if $test "X$doublesize" = "X$longdblsize"; then
-		echo "(That isn't any different from an ordinary double.)"
+		echo "That isn't any different from an ordinary double."
+		echo "I'll keep your setting anyway, but you may see some"
+		echo "harmless compilation warnings."
 	fi	
 	;;
 esac
@@ -5334,6 +5839,10 @@ case "$myarchname" in
 	archname=''
 	;;
 esac
+case "$targetarch" in
+'') ;;
+*)  archname=`echo $targetarch|sed 's,^[^-]*-,,'` ;;
+esac
 myarchname="$tarch"
 case "$archname" in
 '') dflt="$tarch";;
@@ -5394,7 +5903,7 @@ $define)
 	echo "Long doubles selected." >&4
 	case "$longdblsize" in
 	$doublesize)
-		"...but long doubles are equal to doubles, not changing architecture name." >&4
+		echo "...but long doubles are equal to doubles, not changing architecture name." >&4
 		;;
 	*)
 		case "$archname" in
@@ -5411,10 +5920,13 @@ esac
 case "$useperlio" in
 $define)
 	echo "Perlio selected." >&4
+	;;
+*)
+	echo "Perlio not selected, using stdio." >&4
 	case "$archname" in
-        *-perlio*) echo "...and architecture name already has -perlio." >&4
+        *-stdio*) echo "...and architecture name already has -stdio." >&4
                 ;;
-        *)      archname="$archname-perlio"
+        *)      archname="$archname-stdio"
                 echo "...setting architecture name to $archname." >&4
                 ;;
         esac
@@ -5457,12 +5969,17 @@ esac
 prefix="$ans"
 prefixexp="$ansexp"
 
+case "$afsroot" in
+'')	afsroot=/afs ;;
+*)	afsroot=$afsroot ;;
+esac
+
 : is AFS running?
 echo " "
 case "$afs" in
 $define|true)	afs=true ;;
 $undef|false)	afs=false ;;
-*)	if test -d /afs; then
+*)	if test -d $afsroot; then
 		afs=true
 	else
 		afs=false
@@ -5786,7 +6303,7 @@ val="$undef"
 case "$d_suidsafe" in
 "$define")
 	val="$undef"
-	echo "No need to emulate SUID scripts since they are secure here." >& 4
+	echo "No need to emulate SUID scripts since they are secure here." >&4
 	;;
 *)
 	$cat <<EOM
@@ -5813,107 +6330,6 @@ esac
 set d_dosuid
 eval $setvar
 
-: determine filename position in cpp output
-echo " "
-echo "Computing filename position in cpp output for #include directives..." >&4
-echo '#include <stdio.h>' > foo.c
-$cat >fieldn <<EOF
-$startsh
-$cppstdin $cppflags $cppminus <foo.c 2>/dev/null | \
-$grep '^[ 	]*#.*stdio\.h' | \
-while read cline; do
-	pos=1
-	set \$cline
-	while $test \$# -gt 0; do
-		if $test -r \`echo \$1 | $tr -d '"'\`; then
-			echo "\$pos"
-			exit 0
-		fi
-		shift
-		pos=\`expr \$pos + 1\`
-	done
-done
-EOF
-chmod +x fieldn
-fieldn=`./fieldn`
-$rm -f foo.c fieldn
-case $fieldn in
-'') pos='???';;
-1) pos=first;;
-2) pos=second;;
-3) pos=third;;
-*) pos="${fieldn}th";;
-esac
-echo "Your cpp writes the filename in the $pos field of the line."
-
-: locate header file
-$cat >findhdr <<EOF
-$startsh
-wanted=\$1
-name=''
-for usrincdir in $usrinc
-do
-	if test -f \$usrincdir/\$wanted; then
-		echo "\$usrincdir/\$wanted"
-		exit 0
-	fi
-done
-awkprg='{ print \$$fieldn }'
-echo "#include <\$wanted>" > foo\$\$.c
-$cppstdin $cppminus $cppflags < foo\$\$.c 2>/dev/null | \
-$grep "^[ 	]*#.*\$wanted" | \
-while read cline; do
-	name=\`echo \$cline | $awk "\$awkprg" | $tr -d '"'\`
-	case "\$name" in
-	*[/\\\\]\$wanted) echo "\$name"; exit 1;;
-	*[\\\\/]\$wanted) echo "\$name"; exit 1;;
-	*) exit 2;;
-	esac;
-done;
-#
-# status = 0: grep returned 0 lines, case statement not executed
-# status = 1: headerfile found
-# status = 2: while loop executed, no headerfile found
-#
-status=\$?
-$rm -f foo\$\$.c;
-if test \$status -eq 1; then
-	exit 0;
-fi
-exit 1
-EOF
-chmod +x findhdr
-
-: define an alternate in-header-list? function
-inhdr='echo " "; td=$define; tu=$undef; yyy=$@;
-cont=true; xxf="echo \"<\$1> found.\" >&4";
-case $# in 2) xxnf="echo \"<\$1> NOT found.\" >&4";;
-*) xxnf="echo \"<\$1> NOT found, ...\" >&4";;
-esac;
-case $# in 4) instead=instead;; *) instead="at last";; esac;
-while $test "$cont"; do
-	xxx=`./findhdr $1`
-	var=$2; eval "was=\$$2";
-	if $test "$xxx" && $test -r "$xxx";
-	then eval $xxf;
-	eval "case \"\$$var\" in $undef) . ./whoa; esac"; eval "$var=\$td";
-		cont="";
-	else eval $xxnf;
-	eval "case \"\$$var\" in $define) . ./whoa; esac"; eval "$var=\$tu"; fi;
-	set $yyy; shift; shift; yyy=$@;
-	case $# in 0) cont="";;
-	2) xxf="echo \"but I found <\$1> $instead.\" >&4";
-		xxnf="echo \"and I did not find <\$1> either.\" >&4";;
-	*) xxf="echo \"but I found <\$1\> instead.\" >&4";
-		xxnf="echo \"there is no <\$1>, ...\" >&4";;
-	esac;
-done;
-while $test "$yyy";
-do set $yyy; var=$2; eval "was=\$$2";
-	eval "case \"\$$var\" in $define) . ./whoa; esac"; eval "$var=\$tu";
-	set $yyy; shift; shift; yyy=$@;
-done'
-
 : see if this is a malloc.h system
 : we want a real compile instead of Inhdr because some systems have a
 : malloc.h that just gives a compile error saying to use stdlib.h instead
@@ -5935,15 +6351,16 @@ $rm -f try.c try
 set i_malloc
 eval $setvar
 
-: see if stdlib is available
-set stdlib.h i_stdlib
-eval $inhdr
-
 : determine which malloc to compile in
 echo " "
 case "$usemymalloc" in
-''|[yY]*|true|$define)	dflt='y' ;;
-*)	dflt='n' ;;
+[yY]*|true|$define)	dflt='y' ;;
+[nN]*|false|$undef)	dflt='n' ;;
+*)	case "$ptrsize" in
+	4) dflt='y' ;;
+	*) dflt='n' ;;
+	esac
+	;;
 esac
 rp="Do you wish to attempt to use the malloc that comes with $package?"
 . ./myread
@@ -6275,7 +6692,11 @@ eval $setvar
 : Cruising for prototypes
 echo " "
 echo "Checking out function prototypes..." >&4
-$cat >prototype.c <<'EOCP'
+$cat >prototype.c <<EOCP
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
 int main(int argc, char *argv[]) {
 	exit(0);}
 EOCP
@@ -6336,13 +6757,13 @@ fi
 : Find perl5.005 or later.
 echo "Looking for a previously installed perl5.005 or later... "
 case "$perl5" in
-'')	for tdir in `echo "$binexp:$PATH" | $sed "s/$path_sep/ /g"`; do
+'')	for tdir in `echo "$binexp$path_sep$PATH" | $sed "s/$path_sep/ /g"`; do
 		: Check if this perl is recent and can load a simple module
-		if $test -x $tdir/perl && $tdir/perl -Mless -e 'use 5.005;' >/dev/null 2>&1; then
+		if $test -x $tdir/perl$exe_ext && $tdir/perl -Mless -e 'use 5.005;' >/dev/null 2>&1; then
 			perl5=$tdir/perl
 			break;
-		elif $test -x $tdir/perl5 && $tdir/perl5 -Mless -e 'use 5.005;' >/dev/null 2>&1; then
-			perl5=$tdir/perl
+		elif $test -x $tdir/perl5$exe_ext && $tdir/perl5 -Mless -e 'use 5.005;' >/dev/null 2>&1; then
+			perl5=$tdir/perl5
 			break;
 		fi
 	done
@@ -6407,14 +6828,14 @@ else {
 EOPL
 chmod +x getverlist
 case "$inc_version_list" in
-'')	if test -x "$perl5"; then
+'')	if test -x "$perl5$exe_ext"; then
 		dflt=`$perl5 getverlist`
 	else
 		dflt='none'
 	fi
 	;;
 $undef) dflt='none' ;;
-*)  dflt="$inc_version_list" ;;
+*)  eval dflt=\"$inc_version_list\" ;;
 esac
 case "$dflt" in
 ''|' ') dflt=none ;;
@@ -6557,7 +6978,7 @@ y*) usedl="$define"
 	esac
     echo "The following dynamic loading files are available:"
 	: Can not go over to $dldir because getfile has path hard-coded in.
-	tdir=`pwd`; cd $rsrc; $ls -C $dldir/dl*.xs; cd $tdir
+	tdir=`pwd`; cd "$rsrc"; $ls -C $dldir/dl*.xs; cd "$tdir"
 	rp="Source file to use for dynamic loading"
 	fn="fne"
 	gfpth="$src"
@@ -6585,6 +7006,7 @@ EOM
 		    esac
 			;;
 		*)  case "$osname" in
+	                darwin) dflt='none' ;;
 			svr4*|esix*|solaris|nonstopux) dflt='-fPIC' ;;
 			*)	dflt='-fpic' ;;
 		    esac ;;
@@ -6606,10 +7028,13 @@ while other systems (such as those using ELF) use $cc.
 
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
@@ -6621,7 +7046,7 @@ int main() {
 		exit(1); /* fail */
 }
 EOM
-		if $cc $ccflags try.c >/dev/null 2>&1 && ./a.out; then
+		if $cc $ccflags $ldflags try.c >/dev/null 2>&1 && $run ./a.out; then
 			cat <<EOM
 You appear to have ELF support.  I'll use $cc to build dynamic libraries.
 EOM
@@ -6675,7 +7100,7 @@ EOM
 	esac
 	for thisflag in $ldflags; do
 		case "$thisflag" in
-		-L*|-R*)
+		-L*|-R*|-Wl,-R*)
 			case " $dflt " in
 			*" $thisflag "*) ;;
 			*) dflt="$dflt $thisflag" ;;
@@ -6806,8 +7231,8 @@ true)
 		linux*)  # ld won't link with a bare -lperl otherwise.
 			dflt=libperl.$so
 			;;
-		cygwin*) # include version
-			dflt=`echo libperl$version | sed -e 's/\./_/g'`$lib_ext
+		cygwin*) # ld links against an importlib
+			dflt=libperl$lib_ext
 			;;
 		*)	# Try to guess based on whether libc has major.minor.
 			case "$libc" in
@@ -6884,13 +7309,13 @@ if "$useshrplib"; then
 	aix)
 		# We'll set it in Makefile.SH...
 		;;
-	solaris|netbsd)
+	solaris)
 		xxx="-R $shrpdir"
 		;;
-	freebsd)
+	freebsd|netbsd)
 		xxx="-Wl,-R$shrpdir"
 		;;
-	linux|irix*|dec_osf)
+	bsdos|linux|irix*|dec_osf)
 		xxx="-Wl,-rpath,$shrpdir"
 		;;
 	next)
@@ -6945,8 +7370,9 @@ esac
 echo " "
 case "$sysman" in
 '') 
-	syspath='/usr/man/man1 /usr/man/mann /usr/man/manl /usr/man/local/man1'
-	syspath="$syspath /usr/man/u_man/man1 /usr/share/man/man1"
+	syspath='/usr/share/man/man1 /usr/man/man1'
+	syspath="$syspath /usr/man/mann /usr/man/manl /usr/man/local/man1"
+	syspath="$syspath /usr/man/u_man/man1"
 	syspath="$syspath /usr/catman/u_man/man1 /usr/man/l_man/man1"
 	syspath="$syspath /usr/local/man/u_man/man1 /usr/local/man/l_man/man1"
 	syspath="$syspath /usr/man/man.L /local/man/man1 /usr/local/man/man1"
@@ -6978,7 +7404,8 @@ case "$man1dir" in
 ' ') dflt=none
 	;;
 '')
-	lookpath="$prefixexp/man/man1 $prefixexp/man/l_man/man1"
+	lookpath="$prefixexp/share/man/man1"
+	lookpath="$lookpath $prefixexp/man/man1 $prefixexp/man/l_man/man1"
 	lookpath="$lookpath $prefixexp/man/p_man/man1"
 	lookpath="$lookpath $prefixexp/man/u_man/man1"
 	lookpath="$lookpath $prefixexp/man/man.1"
@@ -7168,7 +7595,7 @@ case "$man3dir" in
 esac
 
 : see if we have to deal with yellow pages, now NIS.
-if $test -d /usr/etc/yp || $test -d /etc/yp; then
+if $test -d /usr/etc/yp || $test -d /etc/yp || $test -d /usr/lib/yp; then
 	if $test -f /usr/etc/nibindd; then
 		echo " "
 		echo "I'm fairly confident you're on a NeXT."
@@ -7275,6 +7702,9 @@ if $test "$cont"; then
 		fi
 	fi
 fi
+case "$myhostname" in
+'') myhostname=noname ;;
+esac
 : you do not want to know about this
 set $myhostname
 myhostname=$1
@@ -7375,7 +7805,7 @@ case "$myhostname" in
 		esac
 		case "$dflt" in
 		.) echo "(Lost all hope -- silly guess then)"
-			dflt='.uucp'
+			dflt='.nonet'
 			;;
 		esac
 		$rm -f hosts
@@ -7621,7 +8051,7 @@ else
 fi
 
 case "$useperlio" in
-$define|true|[yY]*)	dflt='y';;
+$define|true|[yY]*|'')	dflt='y';;
 *) dflt='n';;
 esac
 cat <<EOM
@@ -7643,7 +8073,7 @@ y|Y)
 	val="$define"
 	;;     
 *)      
-	echo "Ok, doing things the stdio way"
+	echo "Ok, doing things the stdio way."
 	val="$undef"
 	;;
 esac
@@ -7696,7 +8126,7 @@ int main() {
 EOCP
 	set try
 	if eval $compile; then
-		yyy=`./try$exe_ext`
+		yyy=`$run ./try`
 		case "$yyy" in
 		123.456)
 			sPRIfldbl='"f"'; sPRIgldbl='"g"'; sPRIeldbl='"e"';
@@ -7713,17 +8143,17 @@ if $test X"$sPRIfldbl" = X; then
 #include <stdio.h>
 int main() {
   long double d = 123.456;
-  printf("%.3llf\n", d);
+  printf("%.3Lf\n", d);
 }
 EOCP
 	set try
 	if eval $compile; then
-		yyy=`./try$exe_ext`
+		yyy=`$run ./try`
 		case "$yyy" in
 		123.456)
-			sPRIfldbl='"llf"'; sPRIgldbl='"llg"'; sPRIeldbl='"lle"';
-                	sPRIFUldbl='"llF"'; sPRIGUldbl='"llG"'; sPRIEUldbl='"llE"';
-			echo "We will use %llf."
+			sPRIfldbl='"Lf"'; sPRIgldbl='"Lg"'; sPRIeldbl='"Le"';
+                	sPRIFUldbl='"LF"'; sPRIGUldbl='"LG"'; sPRIEUldbl='"LE"';
+			echo "We will use %Lf."
 			;;
 		esac
 	fi
@@ -7735,17 +8165,17 @@ if $test X"$sPRIfldbl" = X; then
 #include <stdio.h>
 int main() {
   long double d = 123.456;
-  printf("%.3Lf\n", d);
+  printf("%.3llf\n", d);
 }
 EOCP
 	set try
 	if eval $compile; then
-		yyy=`./try$exe_ext`
+		yyy=`$run ./try`
 		case "$yyy" in
 		123.456)
-			sPRIfldbl='"Lf"'; sPRIgldbl='"Lg"'; sPRIeldbl='"Le"';
-                	sPRIFUldbl='"LF"'; sPRIGUldbl='"LG"'; sPRIEUldbl='"LE"';
-			echo "We will use %Lf."
+			sPRIfldbl='"llf"'; sPRIgldbl='"llg"'; sPRIeldbl='"lle"';
+                	sPRIFUldbl='"llF"'; sPRIGUldbl='"llG"'; sPRIEUldbl='"llE"';
+			echo "We will use %llf."
 			;;
 		esac
 	fi
@@ -7762,7 +8192,7 @@ int main() {
 EOCP
 	set try
 	if eval $compile; then
-		yyy=`./try$exe_ext`
+		yyy=`$run ./try`
 		case "$yyy" in
 		123.456)
 			sPRIfldbl='"lf"'; sPRIgldbl='"lg"'; sPRIeldbl='"le"';
@@ -7795,6 +8225,9 @@ case "$sPRIfldbl" in
 esac
 
 : Check how to convert floats to strings.
+
+if test "X$d_Gconvert" = X; then
+
 echo " "
 echo "Checking for an efficient way to convert floats to strings."
 echo " " > try.c
@@ -7822,9 +8255,13 @@ char *myname = "qgcvt";
 #define DOUBLETYPE long double
 #endif
 #ifdef TRY_sprintf
-#if defined(USE_LONG_DOUBLE) && defined(HAS_LONG_DOUBLE) && defined(HAS_PRIgldbl)
+#if defined(USE_LONG_DOUBLE) && defined(HAS_LONG_DOUBLE)
+#ifdef HAS_PRIgldbl
 #define Gconvert(x,n,t,b) sprintf((b),"%.*"$sPRIgldbl,(n),(x))
 #else
+#define Gconvert(x,n,t,b) sprintf((b),"%.*g",(n),(double)(x))
+#endif
+#else
 #define Gconvert(x,n,t,b) sprintf((b),"%.*g",(n),(x))
 #endif
 char *myname = "sprintf";
@@ -7936,21 +8373,49 @@ int main()
 	exit(0);
 }
 EOP
-case "$d_Gconvert" in
-gconvert*) xxx_list='gconvert gcvt sprintf' ;;
-gcvt*) xxx_list='gcvt gconvert sprintf' ;;
-sprintf*) xxx_list='sprintf gconvert gcvt' ;;
-*) xxx_list='gconvert gcvt sprintf' ;;
-esac
-
-case "$d_longdbl$uselongdouble$d_PRIgldbl" in
-"$define$define$define")
-    # for long doubles prefer first qgcvt, then sprintf
-    xxx_list="`echo $xxx_list|sed s/sprintf//`" 
-    xxx_list="sprintf $xxx_list"
-    case "$d_qgcvt" in
-    "$define") xxx_list="qgcvt $xxx_list" ;;
+: first add preferred functions to our list
+xxx_list=""
+for xxx_convert in $gconvert_preference; do
+    case $xxx_convert in
+    gcvt|gconvert|sprintf) xxx_list="$xxx_list $xxx_convert" ;;
+    *) echo "Discarding unrecognized gconvert_preference $xxx_convert" >&4 ;;
+esac
+done
+: then add any others
+for xxx_convert in gconvert gcvt sprintf; do
+    case "$xxx_list" in
+    *$xxx_convert*) ;;
+    *) xxx_list="$xxx_list $xxx_convert" ;;
+esac
+done
+
+case "$d_longdbl$uselongdouble" in
+"$define$define")
+    : again, add prefered functions to our list first
+    xxx_ld_list=""
+    for xxx_convert in $gconvert_ld_preference; do
+        case $xxx_convert in
+        qgcvt|gcvt|gconvert|sprintf) xxx_ld_list="$xxx_ld_list $xxx_convert" ;;
+        *) echo "Discarding unrecognized gconvert_ld_preference $xxx_convert" ;;
+    esac
+    done
+    : then add qgcvt, sprintf--then, in xxx_list order, gconvert and gcvt
+    for xxx_convert in qgcvt sprintf $xxx_list; do
+        case "$xxx_ld_list" in
+        $xxx_convert*|*" $xxx_convert"*) ;;
+        *) xxx_ld_list="$xxx_ld_list $xxx_convert" ;;
     esac
+    done
+    : if sprintf cannot do long doubles, move it to the end
+    if test "$d_PRIgldbl" != "$define"; then
+        xxx_ld_list="`echo $xxx_ld_list|sed s/sprintf//` sprintf"
+    fi
+    : if no qgcvt, remove it
+    if test "$d_qgcvt" != "$define"; then
+        xxx_ld_list="`echo $xxx_ld_list|sed s/qgcvt//`"
+    fi
+    : use the ld_list
+    xxx_list="$xxx_ld_list"
     ;;
 esac
 
@@ -7960,17 +8425,24 @@ for xxx_convert in $xxx_list; do
 	set try -DTRY_$xxx_convert
 	if eval $compile; then
 		echo "$xxx_convert() found." >&4
-		if ./try; then
+		if $run ./try; then
 			echo "I'll use $xxx_convert to convert floats into a string." >&4
 			break;
 		else
 			echo "...But $xxx_convert didn't work as I expected."
+			xxx_convert=''
 		fi
 	else
 		echo "$xxx_convert NOT found." >&4
 	fi
 done
 	
+if test X$xxx_convert = X; then
+    echo "*** WHOA THERE!!! ***" >&4
+    echo "None of ($xxx_list)  seemed to work properly.  I'll use sprintf." >&4
+    xxx_convert=sprintf
+fi
+
 case "$xxx_convert" in
 gconvert) d_Gconvert='gconvert((x),(n),(t),(b))' ;;
 gcvt) d_Gconvert='gcvt((x),(n),(b))' ;;
@@ -7978,11 +8450,15 @@ qgcvt) d_Gconvert='qgcvt((x),(n),(b))' ;;
 *) case "$uselongdouble$d_longdbl$d_PRIgldbl" in
    "$define$define$define")
       d_Gconvert="sprintf((b),\"%.*\"$sPRIgldbl,(n),(x))" ;;
+   "$define$define$undef")
+      d_Gconvert='sprintf((b),"%.*g",(n),(double)(x))' ;;
    *) d_Gconvert='sprintf((b),"%.*g",(n),(x))' ;;
    esac
    ;;  
 esac
 
+fi
+
 : see if _fwalk exists
 set fwalk d__fwalk
 eval $inlibc
@@ -8001,7 +8477,7 @@ eval $inlibc
 case "$d_access" in
 "$define")
 	echo " "
-	$cat >access.c <<'EOCP'
+	$cat >access.c <<EOCP
 #include <sys/types.h>
 #ifdef I_FCNTL
 #include <fcntl.h>
@@ -8012,6 +8488,10 @@ case "$d_access" in
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
@@ -8056,7 +8536,7 @@ echo " "
 echo "Checking whether your compiler can handle __attribute__ ..." >&4
 $cat >attrib.c <<'EOCP'
 #include <stdio.h>
-void croak (char* pat,...) __attribute__((format(printf,1,2),noreturn));
+void croak (char* pat,...) __attribute__((__format__(__printf__,1,2),noreturn));
 EOCP
 if $cc $ccflags -c attrib.c >attrib.out 2>&1 ; then
 	if $contains 'warning' attrib.out >/dev/null 2>&1; then
@@ -8094,12 +8574,16 @@ case "$d_getpgrp" in
 "$define")
 	echo " "
 	echo "Checking to see which flavor of getpgrp is in use..."
-	$cat >set.c <<EOP
+	$cat >try.c <<EOP
 #$i_unistd I_UNISTD
 #include <sys/types.h>
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
@@ -8116,10 +8600,10 @@ int main()
 	exit(1);
 }
 EOP
-	if $cc -o set -DTRY_BSD_PGRP $ccflags $ldflags set.c $libs >/dev/null 2>&1 && ./set; then
+	if $cc -o try -DTRY_BSD_PGRP $ccflags $ldflags try.c $libs >/dev/null 2>&1 && $run ./try; then
 		echo "You have to use getpgrp(pid) instead of getpgrp()." >&4
 		val="$define"
-	elif $cc -o set $ccflags $ldflags set.c $libs >/dev/null 2>&1 && ./set; then
+	elif $cc -o try $ccflags $ldflags try.c $libs >/dev/null 2>&1 && $run ./try; then
 		echo "You have to use getpgrp() instead of getpgrp(pid)." >&4
 		val="$undef"
 	else
@@ -8146,7 +8630,7 @@ EOP
 esac
 set d_bsdgetpgrp
 eval $setvar
-$rm -f set set.c
+$rm -f try try.*
 
 : see if setpgrp exists
 set setpgrp d_setpgrp
@@ -8156,12 +8640,16 @@ case "$d_setpgrp" in
 "$define")
 	echo " "
 	echo "Checking to see which flavor of setpgrp is in use..."
-	$cat >set.c <<EOP
+	$cat >try.c <<EOP
 #$i_unistd I_UNISTD
 #include <sys/types.h>
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
@@ -8178,10 +8666,10 @@ int main()
 	exit(1);
 }
 EOP
-	if $cc -o set -DTRY_BSD_PGRP $ccflags $ldflags set.c $libs >/dev/null 2>&1 && ./set; then
+	if $cc -o try -DTRY_BSD_PGRP $ccflags $ldflags try.c $libs >/dev/null 2>&1 && $run ./try; then
 		echo 'You have to use setpgrp(pid,pgrp) instead of setpgrp().' >&4
 		val="$define"
-	elif $cc -o set $ccflags $ldflags set.c $libs >/dev/null 2>&1 && ./set; then
+	elif $cc -o try $ccflags $ldflags try.c $libs >/dev/null 2>&1 && $run ./try; then
 		echo 'You have to use setpgrp() instead of setpgrp(pid,pgrp).' >&4
 		val="$undef"
 	else
@@ -8208,7 +8696,7 @@ EOP
 esac
 set d_bsdsetpgrp
 eval $setvar
-$rm -f set set.c
+$rm -f try try.*
 : see if bzero exists
 set bzero d_bzero
 eval $inlibc
@@ -8267,6 +8755,10 @@ else
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
@@ -8298,7 +8790,7 @@ int main()
 EOCP
 set try
 if eval $compile_ok; then
-	./try
+	$run ./try
 	yyy=$?
 else
 	echo "(I can't seem to compile the test program--assuming it can't)"
@@ -8321,6 +8813,10 @@ echo " "
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
@@ -8394,7 +8890,7 @@ int main()
 EOCP
 set try
 if eval $compile_ok; then
-	./try
+	$run ./try
 	castflags=$?
 else
 	echo "(I can't seem to compile the test program--assuming it can't)"
@@ -8417,8 +8913,12 @@ echo " "
 if set vprintf val -f d_vprintf; eval $csym; $val; then
 	echo 'vprintf() found.' >&4
 	val="$define"
-	$cat >vprintf.c <<'EOF'
+	$cat >try.c <<EOF
 #include <varargs.h>
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
 
 int main() { xxx("foo"); }
 
@@ -8432,8 +8932,8 @@ va_dcl
 	exit((unsigned long)vsprintf(buf,"%s",args) > 10L);
 }
 EOF
-	set vprintf
-	if eval $compile && ./vprintf; then
+	set try
+	if eval $compile && $run ./try; then
 		echo "Your vsprintf() returns (int)." >&4
 		val2="$undef"
 	else
@@ -8445,6 +8945,7 @@ else
 		val="$undef"
 		val2="$undef"
 fi
+$rm -f try try.*
 set d_vprintf
 eval $setvar
 val=$val2
@@ -8486,7 +8987,11 @@ eval $setvar
 
 : see if crypt exists
 echo " "
-if set crypt val -f d_crypt; eval $csym; $val; then
+set crypt d_crypt
+eval $inlibc
+case "$d_crypt" in
+$define) cryptlib='' ;;
+*)	if set crypt val -f d_crypt; eval $csym; $val; then
 	echo 'crypt() found.' >&4
 	val="$define"
 	cryptlib=''
@@ -8516,6 +9021,8 @@ else
 fi
 set d_crypt
 eval $setvar
+	;;
+esac
 
 : get csh whereabouts
 case "$csh" in
@@ -8687,9 +9194,13 @@ EOM
 $cat >fred.c<<EOM
 
 #include <stdio.h>
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
 #$i_dlfcn I_DLFCN
 #ifdef I_DLFCN
-#include <dlfcn.h>      /* the dynamic linker include file for Sunos/Solaris */
+#include <dlfcn.h>      /* the dynamic linker include file for SunOS/Solaris */
 #else
 #include <sys/types.h>
 #include <nlist.h>
@@ -8733,9 +9244,9 @@ EOM
 	: Call the object file tmp-dyna.o in case dlext=o.
 	if $cc $ccflags $cccdlflags -c dyna.c > /dev/null 2>&1 && 
 		mv dyna${_o} tmp-dyna${_o} > /dev/null 2>&1 && 
-		$ld -o dyna.$dlext $lddlflags tmp-dyna${_o} > /dev/null 2>&1 && 
-		$cc -o fred $ccflags $ldflags $cccdlflags $ccdlflags fred.c $libs > /dev/null 2>&1; then
-		xxx=`./fred`
+		$ld -o dyna.$dlext $ldflags $lddlflags tmp-dyna${_o} > /dev/null 2>&1 && 
+		$cc -o fred $ccflags $ldflags $cccdlflags $ccdlflags fred.c $libs > /dev/null 2>&1 && $to dyna.$dlext; then
+		xxx=`$run ./fred`
 		case $xxx in
 		1)	echo "Test program failed using dlopen." >&4
 			echo "Perhaps you should not use dynamic loading." >&4;;
@@ -8752,7 +9263,7 @@ EOM
 	;;
 esac
 		
-$rm -f fred fred.? dyna.$dlext dyna.? tmp-dyna.?
+$rm -f fred fred.* dyna.$dlext dyna.* tmp-dyna.*
 
 set d_dlsymun
 eval $setvar
@@ -8815,7 +9326,7 @@ eval $inlibc
 
 : Locate the flags for 'open()'
 echo " "
-$cat >open3.c <<'EOCP'
+$cat >try.c <<EOCP
 #include <sys/types.h>
 #ifdef I_FCNTL
 #include <fcntl.h>
@@ -8823,6 +9334,10 @@ $cat >open3.c <<'EOCP'
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
@@ -8834,10 +9349,10 @@ int main() {
 EOCP
 : check sys/file.h first to get FREAD on Sun
 if $test `./findhdr sys/file.h` && \
-		set open3 -DI_SYS_FILE && eval $compile; then
+		set try -DI_SYS_FILE && eval $compile; then
 	h_sysfile=true;
 	echo "<sys/file.h> defines the O_* constants..." >&4
-	if ./open3; then
+	if $run ./try; then
 		echo "and you have the 3 argument form of open()." >&4
 		val="$define"
 	else
@@ -8845,10 +9360,10 @@ if $test `./findhdr sys/file.h` && \
 		val="$undef"
 	fi
 elif $test `./findhdr fcntl.h` && \
-		set open3 -DI_FCNTL && eval $compile; then
+		set try -DI_FCNTL && eval $compile; then
 	h_fcntl=true;
 	echo "<fcntl.h> defines the O_* constants..." >&4
-	if ./open3; then
+	if $run ./try; then
 		echo "and you have the 3 argument form of open()." >&4
 		val="$define"
 	else
@@ -8861,7 +9376,7 @@ else
 fi
 set d_open3
 eval $setvar
-$rm -f open3*
+$rm -f try try.*
 
 : see which of string.h or strings.h is needed
 echo " "
@@ -8885,6 +9400,35 @@ case "$i_string" in
 *)	  strings=`./findhdr string.h`;;
 esac
 
+: see if fcntl.h is there
+val=''
+set fcntl.h val
+eval $inhdr
+
+: see if we can include fcntl.h
+case "$val" in
+"$define")
+	echo " "
+	if $h_fcntl; then
+		val="$define"
+		echo "We'll be including <fcntl.h>." >&4
+	else
+		val="$undef"
+		if $h_sysfile; then
+	echo "We don't need to include <fcntl.h> if we include <sys/file.h>." >&4
+		else
+			echo "We won't be including <fcntl.h>." >&4
+		fi
+	fi
+	;;
+*)
+	h_fcntl=false
+	val="$undef"
+	;;
+esac
+set i_fcntl
+eval $setvar
+
 : check for non-blocking I/O stuff
 case "$h_sysfile" in
 true) echo "#include <sys/file.h>" > head.c;;
@@ -8900,8 +9444,16 @@ echo "Figuring out the flag used by open() for non-blocking I/O..." >&4
 case "$o_nonblock" in
 '')
 	$cat head.c > try.c
-	$cat >>try.c <<'EOCP'
+	$cat >>try.c <<EOCP
 #include <stdio.h>
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
+#$i_fcntl I_FCNTL
+#ifdef I_FCNTL
+#include <fcntl.h>
+#endif
 int main() {
 #ifdef O_NONBLOCK
 	printf("O_NONBLOCK\n");
@@ -8920,7 +9472,7 @@ int main() {
 EOCP
 	set try
 	if eval $compile_ok; then
-		o_nonblock=`./try`
+		o_nonblock=`$run ./try`
 		case "$o_nonblock" in
 		'') echo "I can't figure it out, assuming O_NONBLOCK will do.";;
 		*) echo "Seems like we can use $o_nonblock.";;
@@ -8943,6 +9495,14 @@ case "$eagain" in
 #include <sys/types.h>
 #include <signal.h>
 #include <stdio.h> 
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
+#$i_fcntl I_FCNTL
+#ifdef I_FCNTL
+#include <fcntl.h>
+#endif
 #define MY_O_NONBLOCK $o_nonblock
 #ifndef errno  /* XXX need better Configure test */
 extern int errno;
@@ -9003,7 +9563,7 @@ int main()
 		ret = read(pd[0], buf, 1);	/* Should read EOF */
 		alarm(0);
 		sprintf(string, "%d\n", ret);
-		write(3, string, strlen(string));
+		write(4, string, strlen(string));
 		exit(0);
 	}
 
@@ -9017,7 +9577,7 @@ EOCP
 	set try
 	if eval $compile_ok; then
 		echo "$startsh" >mtry
-		echo "./try >try.out 2>try.ret 3>try.err || exit 4" >>mtry
+		echo "$run ./try >try.out 2>try.ret 4>try.err || exit 4" >>mtry
 		chmod +x mtry
 		./mtry >/dev/null 2>&1
 		case $? in
@@ -9093,10 +9653,15 @@ eval $inlibc
 
 echo " "
 : See if fcntl-based locking works.
-$cat >try.c <<'EOCP'
+$cat >try.c <<EOCP
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
 #include <stdlib.h>
+#endif
 #include <unistd.h>
 #include <fcntl.h>
+#include <signal.h>
+$signal_t blech(x) int x; { exit(3); }
 int main() {
 #if defined(F_SETLK) && defined(F_SETLKW)
      struct flock flock;
@@ -9105,6 +9670,8 @@ int main() {
      flock.l_type = F_RDLCK;
      flock.l_whence = SEEK_SET;
      flock.l_start = flock.l_len = 0;
+     signal(SIGALRM, blech);
+     alarm(10);
      retval = fcntl(fd, F_SETLK, &flock);
      close(fd);
      (retval < 0 ? exit(2) : exit(0));
@@ -9118,12 +9685,24 @@ case "$d_fcntl" in
 "$define")
 	set try
 	if eval $compile_ok; then
-		if ./try; then
+		if $run ./try; then
 			echo "Yes, it seems to work."
 			val="$define"
 		else
 			echo "Nope, it didn't work."
 			val="$undef"
+			case "$?" in
+			3) $cat >&4 <<EOM
+***
+*** I had to forcibly timeout from fcntl(..., F_SETLK, ...).
+*** This is (almost) impossible.
+*** If your NFS lock daemons are not feeling well, something like
+*** this may happen, please investigate.  Cannot continue, aborting.
+***
+EOM
+				exit 1
+				;;
+			esac
 		fi
 	else
 		echo "I'm unable to compile the test program, so I'll assume not."
@@ -9196,7 +9775,7 @@ else
 							sockethdr="-I/usr/netinclude"
 							;;
 						esac
-						echo "Found Berkeley sockets interface in lib$net." >& 4 
+						echo "Found Berkeley sockets interface in lib$net." >&4 
 						if $contains setsockopt libc.list >/dev/null 2>&1; then
 							d_oldsock="$undef"
 						else
@@ -9222,7 +9801,7 @@ eval $inlibc
 
 
 echo " "
-echo "Checking the availability of certain socket constants..." >& 4
+echo "Checking the availability of certain socket constants..." >&4
 for ENUM in MSG_CTRUNC MSG_DONTROUTE MSG_OOB MSG_PEEK MSG_PROXY SCM_RIGHTS; do
 	enum=`$echo $ENUM|./tr '[A-Z]' '[a-z]'`
 	$cat >try.c <<EOF
@@ -9249,7 +9828,7 @@ echo " "
 if test "X$timeincl" = X; then
 	echo "Testing to see if we should include <time.h>, <sys/time.h> or both." >&4
 	$echo $n "I'm now running the test program...$c"
-	$cat >try.c <<'EOCP'
+	$cat >try.c <<EOCP
 #include <sys/types.h>
 #ifdef I_TIME
 #include <time.h>
@@ -9263,6 +9842,10 @@ if test "X$timeincl" = X; then
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
@@ -9333,7 +9916,11 @@ $cat <<EOM
 
 Checking to see how well your C compiler handles fd_set and friends ...
 EOM
-$cat >fd_set.c <<EOCP
+$cat >try.c <<EOCP
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
 #$i_systime I_SYS_TIME
 #$i_sysselct I_SYS_SELECT
 #$d_socket HAS_SOCKET
@@ -9361,12 +9948,12 @@ int main() {
 #endif
 }
 EOCP
-set fd_set -DTRYBITS
+set try -DTRYBITS
 if eval $compile; then
 	d_fds_bits="$define"
 	d_fd_set="$define"
 	echo "Well, your system knows about the normal fd_set typedef..." >&4
-	if ./fd_set; then
+	if $run ./try; then
 		echo "and you have the normal fd_set macros (just as I'd expect)." >&4
 		d_fd_macros="$define"
 	else
@@ -9379,12 +9966,12 @@ else
 	$cat <<'EOM'
 Hmm, your compiler has some difficulty with fd_set.  Checking further...
 EOM
-	set fd_set
+	set try
 	if eval $compile; then
 		d_fds_bits="$undef"
 		d_fd_set="$define"
 		echo "Well, your system has some sort of fd_set available..." >&4
-		if ./fd_set; then
+		if $run ./try; then
 			echo "and you have the normal fd_set macros." >&4
 			d_fd_macros="$define"
 		else
@@ -9400,7 +9987,7 @@ EOM
 		d_fd_macros="$undef"
 	fi
 fi
-$rm -f fd_set*
+$rm -f try try.*
 
 : see if fgetpos exists
 set fgetpos d_fgetpos
@@ -9924,9 +10511,13 @@ eval $setvar
 
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
@@ -10061,7 +10652,7 @@ int main()
 EOCP
 	set try
 	if eval $compile_ok; then
-		longlongsize=`./try$exe_ext`
+		longlongsize=`$run ./try`
 		echo "Your long longs are $longlongsize bytes long."
 	else
 		dflt='8'
@@ -10300,12 +10891,7 @@ case "$quadtype" in
 '')	echo "Alas, no 64-bit integer types in sight." >&4
 	d_quad="$undef"
 	;;
-*)	if test X"$use64bitint" = Xdefine -o X"$longsize" = X8; then
-	    verb="will"
-	else
-	    verb="could"
-	fi
-	echo "We $verb use '$quadtype' for 64-bit integers." >&4
+*)	echo "We could use '$quadtype' for 64-bit integers." >&4
 	d_quad="$define"
 	;;
 esac
@@ -10315,8 +10901,12 @@ echo " "
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
@@ -10325,7 +10915,7 @@ int main()
 EOCP
 	set try
 	if eval $compile_ok; then
-		dflt=`./try`
+		dflt=`$run ./try`
 	else
 		dflt='1'
 		echo "(I can't seem to compile the test program.  Guessing...)"
@@ -10441,7 +11031,7 @@ esac
 case "$i8type" in
 '')	set try -DINT8
 	if eval $compile; then
-		case "`./try$exe_ext`" in
+		case "`$run ./try`" in
 		int8_t)	i8type=int8_t
 			u8type=uint8_t
 			i8size=1
@@ -10474,7 +11064,7 @@ esac
 case "$i16type" in
 '')	set try -DINT16
 	if eval $compile; then
-		case "`./try$exe_ext`" in
+		case "`$run ./try`" in
 		int16_t)
 			i16type=int16_t
 			u16type=uint16_t
@@ -10516,7 +11106,7 @@ esac
 case "$i32type" in
 '')	set try -DINT32
 	if eval $compile; then
-		case "`./try$exe_ext`" in
+		case "`$run ./try`" in
 		int32_t)
 			i32type=int32_t
 			u32type=uint32_t
@@ -10556,6 +11146,10 @@ if test X"$d_volatile" = X"$define"; then
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
@@ -10595,18 +11189,18 @@ set try
 
 d_nv_preserves_uv="$undef"
 if eval $compile; then
-	d_nv_preserves_uv_bits="`./try$exe_ext`"
+	nv_preserves_uv_bits="`$run ./try`"
 fi
-case "$d_nv_preserves_uv_bits" in
+case "$nv_preserves_uv_bits" in
 \-[1-9]*)	
-	d_nv_preserves_uv_bits=`expr 0 - $d_nv_preserves_uv_bits`
-	$echo "Your NVs can preserve all $d_nv_preserves_uv_bits bits of your UVs."  2>&1
+	nv_preserves_uv_bits=`expr 0 - $nv_preserves_uv_bits`
+	$echo "Your NVs can preserve all $nv_preserves_uv_bits bits of your UVs."  2>&1
 	d_nv_preserves_uv="$define"
 	;;
-[1-9]*)	$echo "Your NVs can preserve only $d_nv_preserves_uv_bits bits of your UVs."  2>&1
+[1-9]*)	$echo "Your NVs can preserve only $nv_preserves_uv_bits bits of your UVs."  2>&1
 	d_nv_preserves_uv="$undef" ;;
 *)	$echo "Can't figure out how many bits your NVs preserve." 2>&1
-	d_nv_preserves_uv_bits="$undef" ;;
+	nv_preserves_uv_bits="$undef" ;;
 esac
 
 $rm -f try.* try
@@ -11109,7 +11703,7 @@ exit(0);
 EOCP
 	set try
 	if eval $compile_ok; then
-		if ./try 2>/dev/null; then
+		if $run ./try 2>/dev/null; then
 			echo "Yes, it can."
 			val="$define"
 		else
@@ -11278,7 +11872,7 @@ END
     val="$undef"
     set try
     if eval $compile; then
-	xxx=`./try`
+	xxx=`$run ./try`
         case "$xxx" in
         semun) val="$define" ;;
         esac
@@ -11336,7 +11930,7 @@ END
     val="$undef"
     set try
     if eval $compile; then
-        xxx=`./try`
+        xxx=`$run ./try`
         case "$xxx" in
         semid_ds) val="$define" ;;
         esac
@@ -11603,10 +12197,14 @@ echo " "
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
@@ -11634,8 +12232,12 @@ $rm -f try try$_o try.c
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
@@ -11649,7 +12251,7 @@ int main()
 EOP
 	set try
 	if eval $compile; then
-		if ./try >/dev/null 2>&1; then
+		if $run ./try >/dev/null 2>&1; then
 			echo "POSIX sigsetjmp found." >&4
 			val="$define"
 		else
@@ -11798,6 +12400,10 @@ fi
 echo "Checking how std your stdio is..." >&4
 $cat >try.c <<EOP
 #include <stdio.h>
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
 #define FILE_ptr(fp)	$stdio_ptr
 #define FILE_cnt(fp)	$stdio_cnt
 int main() {
@@ -11813,8 +12419,8 @@ int main() {
 EOP
 val="$undef"
 set try
-if eval $compile; then
-	if ./try; then
+if eval $compile && $to try.c; then
+	if $run ./try; then
 		echo "Your stdio acts pretty std."
 		val="$define"
 	else
@@ -11824,6 +12430,26 @@ else
 	echo "Your stdio doesn't appear very std."
 fi
 $rm -f try.c try
+
+# glibc 2.2.90 and above apparently change stdio streams so Perl's
+# direct buffer manipulation no longer works.  The Configure tests
+# should be changed to correctly detect this, but until then,
+# the following check should at least let perl compile and run.
+# (This quick fix should be updated before 5.8.1.)
+# To be defensive, reject all unknown versions, and all versions  > 2.2.9.
+# A. Dougherty, June 3, 2002.
+case "$d_gnulibc" in
+$define)
+	case "$gnulibc_version" in
+	2.[01]*)  ;;
+	2.2) ;;
+	2.2.[0-9]) ;;
+	*)  echo "But I will not snoop inside glibc $gnulibc_version stdio buffers."
+		val="$undef"
+		;;
+	esac
+	;;
+esac
 set d_stdstdio
 eval $setvar
 
@@ -11855,6 +12481,10 @@ $cat >try.c <<EOP
 /* Can we scream? */
 /* Eat dust sed :-) */
 /* In the buffer space, no one can hear you scream. */
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
 #define FILE_ptr(fp)	$stdio_ptr
 #define FILE_cnt(fp)	$stdio_cnt
 #include <sys/types.h>
@@ -11910,8 +12540,8 @@ int main() {
 }
 EOP
 	set try
-	if eval $compile; then
- 		case `./try$exe_ext` in
+	if eval $compile && $to try.c; then
+ 		case `$run ./try` in
 		Pass_changed)
 			echo "Increasing ptr in your stdio decreases cnt by the same amount.  Good." >&4
 			d_stdio_ptr_lval_sets_cnt="$define" ;;
@@ -11936,6 +12566,10 @@ case "$d_stdstdio" in
 $define)
 	$cat >try.c <<EOP
 #include <stdio.h>
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
 #define FILE_base(fp)	$stdio_base
 #define FILE_bufsiz(fp)	$stdio_bufsiz
 int main() {
@@ -11950,8 +12584,8 @@ int main() {
 }
 EOP
 	set try
-	if eval $compile; then
-		if ./try; then
+	if eval $compile && $to try.c; then
+		if $run ./try; then
 			echo "And its _base field acts std."
 			val="$define"
 		else
@@ -11981,7 +12615,7 @@ EOCP
 	do
 	        set try -DSTDIO_STREAM_ARRAY=$s
 		if eval $compile; then
-		    	case "`./try$exe_ext`" in
+		    	case "`$run ./try`" in
 			yes)	stdio_stream_array=$s; break ;;
 			esac
 		fi
@@ -12123,7 +12757,7 @@ int main() {
 EOCP
 	set try
 	if eval $compile; then
-		yyy=`./try`
+		yyy=`$run ./try`
 		case "$yyy" in
 		ok) echo "Your strtoll() seems to be working okay." ;;
 		*) cat <<EOM >&4
@@ -12178,7 +12812,7 @@ int main() {
 EOCP
 	set try
 	if eval $compile; then
-		case "`./try`" in
+		case "`$run ./try`" in
 		ok) echo "Your strtoull() seems to be working okay." ;;
 		*) cat <<EOM >&4
 Your strtoull() doesn't seem to be working okay.
@@ -12194,6 +12828,54 @@ esac
 set strtouq d_strtouq
 eval $inlibc
 
+case "$d_strtouq" in
+"$define")
+	$cat <<EOM
+Checking whether your strtouq() works okay...
+EOM
+	$cat >try.c <<'EOCP'
+#include <errno.h>
+#include <stdio.h>
+extern unsigned long long int strtouq(char *s, char **, int); 
+static int bad = 0;
+void check(char *s, unsigned long long eull, int een) {
+	unsigned long long gull;
+	errno = 0;
+	gull = strtouq(s, 0, 10);
+	if (!((gull == eull) && (errno == een)))
+		bad++;
+}
+int main() {
+	check(" 1",                                        1LL, 0);
+	check(" 0",                                        0LL, 0);
+	check("18446744073709551615",  18446744073709551615ULL, 0);
+	check("18446744073709551616",  18446744073709551615ULL, ERANGE);
+#if 0 /* strtouq() for /^-/ strings is undefined. */
+	check("-1",                    18446744073709551615ULL, 0);
+	check("-18446744073709551614",                     2LL, 0);
+	check("-18446744073709551615",                     1LL, 0);
+       	check("-18446744073709551616", 18446744073709551615ULL, ERANGE);
+	check("-18446744073709551617", 18446744073709551615ULL, ERANGE);
+#endif
+	if (!bad)
+		printf("ok\n");
+	return 0;
+}
+EOCP
+	set try
+	if eval $compile; then
+		case "`$run ./try`" in
+		ok) echo "Your strtouq() seems to be working okay." ;;
+		*) cat <<EOM >&4
+Your strtouq() doesn't seem to be working okay.
+EOM
+		   d_strtouq="$undef"
+		   ;;
+		esac
+	fi
+	;;
+esac
+
 : see if strxfrm exists
 set strxfrm d_strxfrm
 eval $inlibc
@@ -12335,7 +13017,7 @@ case "$d_closedir" in
 "$define")
 	echo " "
 	echo "Checking whether closedir() returns a status..." >&4
-	cat > closedir.c <<EOM
+	cat > try.c <<EOM
 #$i_dirent I_DIRENT		/**/
 #$i_sysdir I_SYS_DIR		/**/
 #$i_sysndir I_SYS_NDIR		/**/
@@ -12364,9 +13046,9 @@ case "$d_closedir" in
 #endif 
 int main() { return closedir(opendir(".")); }
 EOM
-	set closedir
+	set try
 	if eval $compile_ok; then
-		if ./closedir > /dev/null 2>&1 ; then
+		if $run ./try > /dev/null 2>&1 ; then
 			echo "Yes, it does."
 			val="$undef"
 		else
@@ -12384,7 +13066,7 @@ EOM
 esac
 set d_void_closedir
 eval $setvar
-$rm -f closedir*
+$rm -f try try.*
 : see if there is a wait4
 set wait4 d_wait4
 eval $inlibc
@@ -12458,7 +13140,7 @@ int main()
 EOCP
 		set try
 		if eval $compile_ok; then
-			dflt=`./try`
+			dflt=`$run ./try`
 		else
 			dflt='8'
 			echo "(I can't seem to compile the test program...)"
@@ -12478,16 +13160,16 @@ esac
 : set the base revision
 baserev=5.0
 
-: check for ordering of bytes in a long
+: check for ordering of bytes in a UV
 echo " "
-case "$crosscompile$multiarch" in
+case "$usecrosscompile$multiarch" in
 *$define*)
 	$cat <<EOM
 You seem to be either cross-compiling or doing a multiarchitecture build,
 skipping the byteorder check.
 
 EOM
-	byteorder='0xffff'
+	byteorder='ffff'
 	;;
 *)
 	case "$byteorder" in
@@ -12501,21 +13183,27 @@ an Alpha will report 12345678. If the test program works the default is
 probably right.
 I'm now running the test program...
 EOM
-		$cat >try.c <<'EOCP'
+		$cat >try.c <<EOCP
 #include <stdio.h>
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
+#include <sys/types.h>
+typedef $uvtype UV;
 int main()
 {
 	int i;
 	union {
-		unsigned long l;
-		char c[sizeof(long)];
+		UV l;
+		char c[$uvsize];
 	} u;
 
-	if (sizeof(long) > 4)
-		u.l = (0x08070605L << 32) | 0x04030201L;
+	if ($uvsize > 4)
+		u.l = (((UV)0x08070605) << 32) | (UV)0x04030201;
 	else
-		u.l = 0x04030201L;
-	for (i = 0; i < sizeof(long); i++)
+		u.l = (UV)0x04030201;
+	for (i = 0; i < $uvsize; i++)
 		printf("%c", u.c[i]+'0');
 	printf("\n");
 	exit(0);
@@ -12524,7 +13212,7 @@ EOCP
 		xxx_prompt=y
 		set try
 		if eval $compile && ./try > /dev/null; then
-			dflt=`./try`
+			dflt=`$run ./try`
 			case "$dflt" in
 			[1-4][1-4][1-4][1-4]|12345678|87654321)
 				echo "(The test program ran ok.)"
@@ -12542,7 +13230,7 @@ EOM
 		fi
 		case "$xxx_prompt" in
 		y)
-			rp="What is the order of bytes in a long?"
+			rp="What is the order of bytes in $uvtype?"
 			. ./myread
 			byteorder="$ans"
 			;;
@@ -12600,14 +13288,24 @@ $define)
 #endif
 #include <sys/types.h>
 #include <stdio.h>
-#include <db.h>
-int main()
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
+#include <db3/db.h>
+int main(int argc, char *argv[])
 {
 #ifdef DB_VERSION_MAJOR	/* DB version >= 2 */
     int Major, Minor, Patch ;
     unsigned long Version ;
     (void)db_version(&Major, &Minor, &Patch) ;
-    printf("You have Berkeley DB Version 2 or greater\n");
+    if (argc == 2) {
+        printf("%d %d %d %d %d %d\n",
+               DB_VERSION_MAJOR, DB_VERSION_MINOR, DB_VERSION_PATCH,
+               Major, Minor, Patch);
+        exit(0);
+    }
+    printf("You have Berkeley DB Version 2 or greater.\n");
 
     printf("db.h is from Berkeley DB Version %d.%d.%d\n",
 		DB_VERSION_MAJOR, DB_VERSION_MINOR, DB_VERSION_PATCH);
@@ -12616,11 +13314,11 @@ int main()
 
     /* check that db.h & libdb are compatible */
     if (DB_VERSION_MAJOR != Major || DB_VERSION_MINOR != Minor || DB_VERSION_PATCH != Patch) {
-	printf("db.h and libdb are incompatible\n") ;
+	printf("db.h and libdb are incompatible.\n") ;
         exit(3);	
     }
 
-    printf("db.h and libdb are compatible\n") ;
+    printf("db.h and libdb are compatible.\n") ;
 
     Version = DB_VERSION_MAJOR * 1000000 + DB_VERSION_MINOR * 1000
 		+ DB_VERSION_PATCH ;
@@ -12628,26 +13326,34 @@ int main()
     /* needs to be >= 2.3.4 */
     if (Version < 2003004) {
     /* if (DB_VERSION_MAJOR == 2 && DB_VERSION_MINOR == 0 && DB_VERSION_PATCH < 5) { */
-	printf("but Perl needs Berkeley DB 2.3.4 or greater\n") ;
+	printf("Perl needs Berkeley DB 2.3.4 or greater.\n") ;
         exit(2);	
     }
 
     exit(0);
 #else
 #if defined(_DB_H_) && defined(BTREEMAGIC) && defined(HASHMAGIC)
-    printf("You have Berkeley DB Version 1\n");
+    if (argc == 2) {
+        printf("1 0 0\n");
+        exit(0);
+    }
+    printf("You have Berkeley DB Version 1.\n");
     exit(0);	/* DB version < 2: the coast is clear. */
 #else
-    exit(1);	/* <db.h> not Berkeley DB? */
+    exit(1);	/* <db3/db.h> not Berkeley DB? */
 #endif
 #endif
 }
 EOCP
 	set try
-	if eval $compile_ok && ./try; then
+	if eval $compile_ok && $run ./try; then
 		echo 'Looks OK.' >&4
+		set `$run ./try 1`
+		db_version_major=$1
+		db_version_minor=$2
+		db_version_patch=$3
 	else
-		echo "I can't use Berkeley DB with your <db.h>.  I'll disable Berkeley DB." >&4
+		echo "I can't use Berkeley DB with your <db3/db.h>.  I'll disable Berkeley DB." >&4
 		i_db=$undef
 		case " $libs " in
 		*"-ldb "*)
@@ -12675,7 +13381,7 @@ define)
 #define const
 #endif
 #include <sys/types.h>
-#include <db.h>
+#include <db3/db.h>
 
 #ifndef DB_VERSION_MAJOR
 u_int32_t hash_cb (ptr, size)
@@ -12720,7 +13426,7 @@ define)
 #define const
 #endif
 #include <sys/types.h>
-#include <db.h>
+#include <db3/db.h>
 
 #ifndef DB_VERSION_MAJOR
 size_t prefix_cb (key1, key2)
@@ -12760,7 +13466,11 @@ echo " "
 echo "Checking to see how well your C compiler groks the void type..." >&4
 case "$voidflags" in
 '')
-	$cat >try.c <<'EOCP'
+	$cat >try.c <<EOCP
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
 #if TRY & 1
 void sub() {
 #else
@@ -12980,7 +13690,7 @@ done
 
 echo " "
 echo "Determining whether or not we are on an EBCDIC system..." >&4
-$cat >tebcdic.c <<'EOM'
+$cat >try.c <<'EOM'
 int main()
 {
   if ('M'==0xd4) return 0;
@@ -12989,19 +13699,19 @@ int main()
 EOM
 
 val=$undef
-set tebcdic
+set try
 if eval $compile_ok; then
-	if ./tebcdic; then
+	if $run ./try; then
 		echo "You seem to speak EBCDIC." >&4
 		val="$define"
 	else
-		echo "Nope, no EBCDIC, probably ASCII or some ISO Latin. Or UTF8." >&4
+		echo "Nope, no EBCDIC, probably ASCII or some ISO Latin. Or UTF-8." >&4
 	fi
 else
 	echo "I'm unable to compile the test program." >&4
 	echo "I'll assume ASCII or some ISO Latin. Or UTF8." >&4
 fi
-$rm -f tebcdic.c tebcdic
+$rm -f try try.*
 set ebcdic
 eval $setvar
 
@@ -13016,6 +13726,10 @@ sunos) $echo '#define PERL_FFLUSH_ALL_FOPEN_MAX 32' > try.c ;;
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
@@ -13026,7 +13740,9 @@ $cat >>try.c <<EOCP
 # define STDIO_STREAM_ARRAY $stdio_stream_array
 #endif
 int main() {
-  FILE* p = fopen("try.out", "w");
+  FILE* p;
+  unlink("try.out");
+  p = fopen("try.out", "w");
 #ifdef TRY_FPUTC
   fputc('x', p);
 #else
@@ -13075,24 +13791,26 @@ int main() {
 }
 EOCP
 : first we have to find out how _not_ to flush
+$to try.c
 if $test "X$fflushNULL" = X -o "X$fflushall" = X; then
     output=''
     set try -DTRY_FPUTC
     if eval $compile; then
-	    $rm -f try.out
- 	    ./try$exe_ext 2>/dev/null
-	    if $test ! -s try.out -a "X$?" = X42; then
+ 	    $run ./try 2>/dev/null
+	    code="$?"
+	    $from try.out
+	    if $test ! -s try.out -a "X$code" = X42; then
 		output=-DTRY_FPUTC
 	    fi
     fi
     case "$output" in
     '')
 	    set try -DTRY_FPRINTF
-	    $rm -f try.out
 	    if eval $compile; then
-		    $rm -f try.out
- 		    ./try$exe_ext 2>/dev/null
-		    if $test ! -s try.out -a "X$?" = X42; then
+ 		    $run ./try 2>/dev/null
+		    code="$?"
+		    $from try.out
+		    if $test ! -s try.out -a "X$code" = X42; then
 			output=-DTRY_FPRINTF
 		    fi
 	    fi
@@ -13103,9 +13821,9 @@ fi
 case "$fflushNULL" in
 '') 	set try -DTRY_FFLUSH_NULL $output
 	if eval $compile; then
-	        $rm -f try.out
-	    	./try$exe_ext 2>/dev/null
+	    	$run ./try 2>/dev/null
 		code="$?"
+		$from try.out
 		if $test -s try.out -a "X$code" = X42; then
 			fflushNULL="`$cat try.out`"
 		else
@@ -13151,7 +13869,7 @@ EOCP
                 set tryp
                 if eval $compile; then
                     $rm -f tryp.out
-                    $cat tryp.c | ./tryp$exe_ext 2>/dev/null > tryp.out
+                    $cat tryp.c | $run ./tryp 2>/dev/null > tryp.out
                     if cmp tryp.c tryp.out >/dev/null 2>&1; then
                        $cat >&4 <<EOM
 fflush(NULL) seems to behave okay with input streams.
@@ -13215,7 +13933,7 @@ EOCP
 	set tryp
 	if eval $compile; then
 	    $rm -f tryp.out
-	    $cat tryp.c | ./tryp$exe_ext 2>/dev/null > tryp.out
+	    $cat tryp.c | $run ./tryp 2>/dev/null > tryp.out
 	    if cmp tryp.c tryp.out >/dev/null 2>&1; then
 	       $cat >&4 <<EOM
 Good, at least fflush(stdin) seems to behave okay when stdin is a pipe.
@@ -13227,9 +13945,10 @@ EOM
 				$cat >&4 <<EOM
 (Now testing the other method--but note that this also may fail.)
 EOM
-				$rm -f try.out
-				./try$exe_ext 2>/dev/null
-				if $test -s try.out -a "X$?" = X42; then
+				$run ./try 2>/dev/null
+				code=$?
+				$from try.out
+				if $test -s try.out -a "X$code" = X42; then
 					fflushall="`$cat try.out`"
 				fi
 			fi
@@ -13327,6 +14046,10 @@ echo "Checking the size of $zzz..." >&4
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
@@ -13334,7 +14057,7 @@ int main() {
 EOCP
 set try
 if eval $compile_ok; then
-	yyy=`./try`
+	yyy=`$run ./try`
 	case "$yyy" in
 	'')	gidsize=4
 		echo "(I can't execute the test program--guessing $gidsize.)" >&4
@@ -13368,7 +14091,7 @@ int main() {
 EOCP
 set try
 if eval $compile; then
-	yyy=`./try`
+	yyy=`$run ./try`
 	case "$yyy" in
 	'')	gidsign=1
 		echo "(I can't execute the test program--guessing unsigned.)" >&4
@@ -13403,7 +14126,7 @@ int main() {
 EOCP
 	set try
 	if eval $compile; then
-		yyy=`./try$exe_ext`
+		yyy=`$run ./try`
 		case "$yyy" in
 		12345678901)
 			sPRId64='"d"'; sPRIi64='"i"'; sPRIu64='"u"';
@@ -13425,7 +14148,7 @@ int main() {
 EOCP
 	set try
 	if eval $compile; then
-		yyy=`./try$exe_ext`
+		yyy=`$run ./try`
 		case "$yyy" in
 		12345678901)
 			sPRId64='"ld"'; sPRIi64='"li"'; sPRIu64='"lu"';
@@ -13448,7 +14171,7 @@ int main() {
 EOCP
 	set try
 	if eval $compile; then
-		yyy=`./try$exe_ext`
+		yyy=`$run ./try`
 		case "$yyy" in
 		12345678901)
 			sPRId64=PRId64; sPRIi64=PRIi64; sPRIu64=PRIu64;
@@ -13459,45 +14182,45 @@ EOCP
 	fi
 fi
 
-if $test X"$sPRId64" = X -a X"$quadtype" = X"long long"; then
-	$cat >try.c <<'EOCP'
+if $test X"$sPRId64" = X -a X"$quadtype" != X; then
+	$cat >try.c <<EOCP
 #include <sys/types.h>
 #include <stdio.h>
 int main() {
-  long long q = 12345678901LL; /* AIX cc requires the LL suffix. */
-  printf("%lld\n", q);
+  $quadtype q = 12345678901;
+  printf("%Ld\n", q);
 }
 EOCP
 	set try
 	if eval $compile; then
-		yyy=`./try$exe_ext`
+		yyy=`$run ./try`
 		case "$yyy" in
 		12345678901)
-			sPRId64='"lld"'; sPRIi64='"lli"'; sPRIu64='"llu"';
-                	sPRIo64='"llo"'; sPRIx64='"llx"'; sPRIXU64='"llX"';
-			echo "We will use the %lld style."
+			sPRId64='"Ld"'; sPRIi64='"Li"'; sPRIu64='"Lu"';
+                	sPRIo64='"Lo"'; sPRIx64='"Lx"'; sPRIXU64='"LX"';
+			echo "We will use %Ld."
 			;;
 		esac
 	fi
 fi
 
-if $test X"$sPRId64" = X -a X"$quadtype" != X; then
-	$cat >try.c <<EOCP
+if $test X"$sPRId64" = X -a X"$quadtype" = X"long long"; then
+	$cat >try.c <<'EOCP'
 #include <sys/types.h>
 #include <stdio.h>
 int main() {
-  $quadtype q = 12345678901;
-  printf("%Ld\n", q);
+  long long q = 12345678901LL; /* AIX cc requires the LL suffix. */
+  printf("%lld\n", q);
 }
 EOCP
 	set try
 	if eval $compile; then
-		yyy=`./try$exe_ext`
+		yyy=`$run ./try`
 		case "$yyy" in
 		12345678901)
-			sPRId64='"Ld"'; sPRIi64='"Li"'; sPRIu64='"Lu"';
-                	sPRIo64='"Lo"'; sPRIx64='"Lx"'; sPRIXU64='"LX"';
-			echo "We will use %Ld."
+			sPRId64='"lld"'; sPRIi64='"lli"'; sPRIu64='"llu"';
+                	sPRIo64='"llo"'; sPRIx64='"llx"'; sPRIXU64='"llX"';
+			echo "We will use the %lld style."
 			;;
 		esac
 	fi
@@ -13514,7 +14237,7 @@ int main() {
 EOCP
 	set try
 	if eval $compile; then
-		yyy=`./try$exe_ext`
+		yyy=`$run ./try`
 		case "$yyy" in
 		12345678901)
 			sPRId64='"qd"'; sPRIi64='"qi"'; sPRIu64='"qu"';
@@ -13596,7 +14319,7 @@ else
 fi
 
 case "$ivdformat" in
-'') echo "$0: Fatal: failed to find format strings, cannot continue." >& 4
+'') echo "$0: Fatal: failed to find format strings, cannot continue." >&4
     exit 1
     ;;
 esac
@@ -13919,8 +14642,12 @@ case "$ptrsize" in
 	else
 		echo '#define VOID_PTR void *' > try.c
 	fi
-	$cat >>try.c <<'EOCP'
+	$cat >>try.c <<EOCP
 #include <stdio.h>
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
 int main()
 {
     printf("%d\n", (int)sizeof(VOID_PTR));
@@ -13929,7 +14656,7 @@ int main()
 EOCP
 	set try
 	if eval $compile_ok; then
-		ptrsize=`./try`
+		ptrsize=`$run ./try`
 		echo "Your pointers are $ptrsize bytes long."
 	else
 		dflt='4'
@@ -13942,12 +14669,44 @@ EOCP
 esac
 $rm -f try.c try
 
+case "$use64bitall" in
+"$define"|true|[yY]*)
+	case "$ptrsize" in
+	4)	cat <<EOM >&4
+
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
+
+EOM
+
+		exit 1
+		;;
+	esac
+	;;
+esac
+
+
 : see if ar generates random libraries by itself
 echo " "
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
@@ -13955,13 +14714,13 @@ $cc $ccflags -c bar2.c >/dev/null 2>&1
 $cc $ccflags -c foo.c >/dev/null 2>&1
 $ar rc bar$_a bar2$_o bar1$_o >/dev/null 2>&1
 if $cc -o foobar $ccflags $ldflags foo$_o bar$_a $libs > /dev/null 2>&1 &&
-	./foobar >/dev/null 2>&1; then
+	$run ./foobar >/dev/null 2>&1; then
 	echo "$ar appears to generate random libraries itself."
 	orderlib=false
 	ranlib=":"
 elif $ar ts bar$_a >/dev/null 2>&1 &&
 	$cc -o foobar $ccflags $ldflags foo$_o bar$_a $libs > /dev/null 2>&1 &&
-	./foobar >/dev/null 2>&1; then
+	$run ./foobar >/dev/null 2>&1; then
 		echo "a table of contents needs to be added with '$ar ts'."
 		orderlib=false
 		ranlib="$ar ts"
@@ -14037,7 +14796,8 @@ esac
 
 : check for the select 'width'
 case "$selectminbits" in
-'') case "$d_select" in
+'') safebits=`expr $ptrsize \* 8`
+    case "$d_select" in
 	$define)
 		$cat <<EOM
 
@@ -14069,25 +14829,31 @@ EOM
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
@@ -14095,20 +14861,21 @@ int main() {
     t.tv_usec = 0;
     select(fd + 1, b, 0, 0, &t);
     for (i = NBITS - 1; i > fd && FD_ISSET(i, b); i--);
+    free(s);
     printf("%d\n", i + 1);
     return 0;
 }
 EOCP
 		set try
 		if eval $compile_ok; then
-			selectminbits=`./try`
+			selectminbits=`$run ./try`
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
@@ -14117,7 +14884,8 @@ EOM
 		else
 			rp='What is the minimum number of bits your select() operates on?'
 			case "$byteorder" in
-			1234|12345678)	dflt=32 ;;
+			12345678)	dflt=64 ;;
+			1234)		dflt=32 ;;
 			*)		dflt=1	;;
 			esac
 			. ./myread
@@ -14127,7 +14895,7 @@ EOM
 		$rm -f try.* try
 		;;
 	*)	: no select, so pick a harmless default
-		selectminbits='32'
+		selectminbits=$safebits
 		;;
 	esac
 	;;
@@ -14146,7 +14914,7 @@ else
 	xxx=`echo '#include <signal.h>' |
 	$cppstdin $cppminus $cppflags 2>/dev/null |
 	$grep '^[ 	]*#.*include' | 
-	$awk "{print \\$$fieldn}" | $sed 's!"!!g' | $sort | $uniq`
+	$awk "{print \\$$fieldn}" | $sed 's!"!!g' | $sed 's!\\\\\\\\!/!g' | $sort | $uniq`
 fi
 : Check this list of files to be sure we have parsed the cpp output ok.
 : This will also avoid potentially non-existent files, such 
@@ -14174,9 +14942,13 @@ xxx="$xxx SYS TERM THAW TRAP TSTP TTIN TTOU URG USR1 USR2"
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
 
@@ -14251,7 +15023,7 @@ END {
 $cat >signal.awk <<'EOP'
 BEGIN { ndups = 0 }
 $1 ~ /^NSIG$/ { nsig = $2 }
-($1 !~ /^NSIG$/) && (NF == 2) {
+($1 !~ /^NSIG$/) && (NF == 2) && ($2 ~ /^[0-9][0-9]*$/) {
     if ($2 > maxsig) { maxsig = $2 }
     if (sig_name[$2]) {
 	dup_name[ndups] = $1
@@ -14293,13 +15065,13 @@ $cat >>signal_cmd <<'EOS'
 
 set signal
 if eval $compile_ok; then
-	./signal$_exe | ($sort -n -k 2 2>/dev/null || $sort -n +1) | $uniq | $awk -f signal.awk >signal.lst
+	$run ./signal$_exe | ($sort -n -k 2 2>/dev/null || $sort -n +1) | $uniq | $awk -f signal.awk >signal.lst
 else
 	echo "(I can't seem be able to compile the whole test program)" >&4
 	echo "(I'll try it in little pieces.)" >&4
 	set signal -DJUST_NSIG
 	if eval $compile_ok; then
-		./signal$_exe > signal.nsg
+		$run ./signal$_exe > signal.nsg
 		$cat signal.nsg
 	else
 		echo "I can't seem to figure out how many signals you have." >&4
@@ -14320,14 +15092,14 @@ EOCP
 		set signal
 		if eval $compile; then
 			echo "SIG${xx} found."
-			./signal$_exe  >> signal.ls1
+			$run ./signal$_exe  >> signal.ls1
 		else
 			echo "SIG${xx} NOT found."
 		fi
 	done
 	if $test -s signal.ls1; then
 		$cat signal.nsg signal.ls1 |
-			($sort -n -k 2 2>/dev/null || $sort -n +1) | $uniq | $awk -f signal.awk >signal.lst
+			$sort -n | $uniq | $awk -f signal.awk >signal.lst
 	fi
 
 fi
@@ -14403,6 +15175,10 @@ echo "Checking the size of $zzz..." >&4
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
@@ -14410,7 +15186,7 @@ int main() {
 EOCP
 set try
 if eval $compile_ok; then
-	yyy=`./try`
+	yyy=`$run ./try`
 	case "$yyy" in
 	'')	sizesize=4
 		echo "(I can't execute the test program--guessing $sizesize.)" >&4
@@ -14504,8 +15280,12 @@ esac
 set ssize_t ssizetype int stdio.h sys/types.h
 eval $typedef
 dflt="$ssizetype"
-$cat > ssize.c <<EOM
+$cat > try.c <<EOM
 #include <stdio.h>
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
 #include <sys/types.h>
 #define Size_t $sizetype
 #define SSize_t $dflt
@@ -14521,9 +15301,9 @@ int main()
 }
 EOM
 echo " "
-set ssize
-if eval $compile_ok && ./ssize > /dev/null; then
-	ssizetype=`./ssize`
+set try
+if eval $compile_ok && $run ./try > /dev/null; then
+	ssizetype=`$run ./try`
 	echo "I'll be using $ssizetype for functions returning a byte count." >&4
 else
 	$cat >&4 <<EOM
@@ -14539,7 +15319,7 @@ EOM
 	. ./myread
 	ssizetype="$ans"
 fi
-$rm -f ssize ssize.*
+$rm -f try try.*
 
 : see what type of char stdio uses.
 echo " "
@@ -14604,6 +15384,10 @@ echo "Checking the size of $zzz..." >&4
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
@@ -14611,7 +15395,7 @@ int main() {
 EOCP
 set try
 if eval $compile_ok; then
-	yyy=`./try`
+	yyy=`$run ./try`
 	case "$yyy" in
 	'')	uidsize=4
 		echo "(I can't execute the test program--guessing $uidsize.)" >&4
@@ -14644,7 +15428,7 @@ int main() {
 EOCP
 set try
 if eval $compile; then
-	yyy=`./try`
+	yyy=`$run ./try`
 	case "$yyy" in
 	'')	uidsign=1
 		echo "(I can't execute the test program--guessing unsigned.)" >&4
@@ -14710,11 +15494,11 @@ case "$yacc" in
 esac
 echo " "
 comp='yacc'
-if $test -f "$byacc"; then
+if $test -f "$byacc$_exe"; then
 	dflt="$byacc"
 	comp="byacc or $comp"
 fi
-if $test -f "$bison"; then
+if $test -f "$bison$_exe"; then
 	comp="$comp or bison -y"
 fi
 rp="Which compiler compiler ($comp) shall I use?"
@@ -14786,35 +15570,6 @@ esac
 set i_sysfile
 eval $setvar
 
-: see if fcntl.h is there
-val=''
-set fcntl.h val
-eval $inhdr
-
-: see if we can include fcntl.h
-case "$val" in
-"$define")
-	echo " "
-	if $h_fcntl; then
-		val="$define"
-		echo "We'll be including <fcntl.h>." >&4
-	else
-		val="$undef"
-		if $h_sysfile; then
-	echo "We don't need to include <fcntl.h> if we include <sys/file.h>." >&4
-		else
-			echo "We won't be including <fcntl.h>." >&4
-		fi
-	fi
-	;;
-*)
-	h_fcntl=false
-	val="$undef"
-	;;
-esac
-set i_fcntl
-eval $setvar
-
 : see if this is a ieeefp.h system
 set ieeefp.h i_ieeefp
 eval $inhdr
@@ -14848,6 +15603,20 @@ eval $inhdr
 : see if ndbm.h is available
 set ndbm.h t_ndbm
 eval $inhdr
+
+case "$t_ndbm" in
+$undef)
+    # Some Linux distributions such as RedHat 7.1 put the
+    # ndbm.h header in /usr/include/gdbm/ndbm.h.
+    if $test -f /usr/include/gdbm/ndbm.h; then
+	echo '<gdbm/ndbm.h> found.'
+        ccflags="$ccflags -I/usr/include/gdbm"
+        cppflags="$cppflags -I/usr/include/gdbm"
+        t_ndbm=$define
+    fi
+    ;;
+esac
+
 case "$t_ndbm" in
 $define)
 	: see if dbm_open exists
@@ -15005,12 +15774,12 @@ $awk \\
 EOSH
 cat <<'EOSH' >> Cppsym.try
 'length($1) > 0 {
-    printf "#ifdef %s\n#if %s+0\nprintf(\"%s=%%ld\\n\", %s);\n#else\nprintf(\"%s\\n\");\n#endif\n#endif\n", $1, $1, $1, $1, $1
-    printf "#ifdef _%s\n#if _%s+0\nprintf(\"_%s=%%ld\\n\", _%s);\n#else\nprintf(\"_%s\\n\");\n#endif\n#endif\n", $1, $1, $1, $1, $1
-    printf "#ifdef __%s\n#if __%s+0\nprintf(\"__%s=%%ld\\n\", __%s);\n#else\nprintf(\"__%s\\n\");\n#endif\n#endif\n", $1, $1, $1, $1, $1
-    printf "#ifdef __%s__\n#if __%s__+0\nprintf(\"__%s__=%%ld\\n\", __%s__);\n#else\nprintf(\"__%s__\\n\");\n#endif\n#endif\n", $1, $1, $1, $1, $1
+    printf "#ifdef %s\n#if %s+0\nprintf(\"%s=%%ld\\n\", (long)%s);\n#else\nprintf(\"%s\\n\");\n#endif\n#endif\n", $1, $1, $1, $1, $1
+    printf "#ifdef _%s\n#if _%s+0\nprintf(\"_%s=%%ld\\n\", (long)_%s);\n#else\nprintf(\"_%s\\n\");\n#endif\n#endif\n", $1, $1, $1, $1, $1
+    printf "#ifdef __%s\n#if __%s+0\nprintf(\"__%s=%%ld\\n\", (long)__%s);\n#else\nprintf(\"__%s\\n\");\n#endif\n#endif\n", $1, $1, $1, $1, $1
+    printf "#ifdef __%s__\n#if __%s__+0\nprintf(\"__%s__=%%ld\\n\", (long)__%s__);\n#else\nprintf(\"__%s__\\n\");\n#endif\n#endif\n", $1, $1, $1, $1, $1
 }'	 >> try.c
-echo '}' >> try.c
+echo 'return 0;}' >> try.c
 EOSH
 cat <<EOSH >> Cppsym.try
 ccflags="$ccflags"
@@ -15018,7 +15787,7 @@ case "$osname-$gccversion" in
 irix-) ccflags="\$ccflags -woff 1178" ;;
 os2-*) ccflags="\$ccflags -Zlinker /PM:VIO" ;;
 esac
-$cc -o try $optimize \$ccflags $ldflags try.c $libs && ./try$exe_ext
+$cc -o try $optimize \$ccflags $ldflags try.c $libs && $run ./try
 EOSH
 chmod +x Cppsym.try
 $eunicefix Cppsym.try
@@ -15037,7 +15806,7 @@ for i in \`$cc -v -c tmp.c 2>&1 $postprocess_cc_v\`
 do
 	case "\$i" in
 	-D*) echo "\$i" | $sed 's/^-D//';;
-	-A*) $test "$gccversion" && echo "\$i" | $sed 's/^-A\(.*\)(\(.*\))/\1=\2/';;
+	-A*) $test "$gccversion" && echo "\$i" | $sed 's/^-A//' | $sed 's/\(.*\)(\(.*\))/\1=\2/';;
 	esac
 done
 $rm -f try.c
@@ -15397,7 +16166,7 @@ find_extensions='
            else
                if $test -d $xxx -a $# -lt 10; then
                    set $1$xxx/ $*;
-                   cd $xxx;
+                   cd "$xxx";
                    eval $find_extensions;
                    cd ..;
                    shift;
@@ -15407,17 +16176,21 @@ find_extensions='
        esac;
     done'
 tdir=`pwd`
-cd $rsrc/ext
+cd "$rsrc/ext"
 set X
 shift
 eval $find_extensions
+# Special case:  Add in threads/shared since it is not picked up by the
+# recursive find above (and adding in general recursive finding breaks
+# SDBM_File/sdbm).  A.D.  10/25/2001.
+known_extensions="$known_extensions threads/shared"
 set X $nonxs_extensions
 shift
 nonxs_extensions="$*"
 set X $known_extensions
 shift
 known_extensions="$*"
-cd $tdir
+cd "$tdir"
 
 : Now see which are supported on this system.
 avail_ext=''
PATCH
        return;
    }

    if (_ge($version, "5.6.1")) {
        _patch(<<'PATCH');
--- Configure
+++ Configure
@@ -165,6 +165,11 @@ ccversion=''
 ccsymbols=''
 cppccsymbols=''
 cppsymbols=''
+from=''
+run=''
+targetarch=''
+to=''
+usecrosscompile=''
 perllibs=''
 dynamic_ext=''
 extensions=''
@@ -975,6 +980,21 @@ if test -f /etc/unixtovms.exe; then
 	eunicefix=/etc/unixtovms.exe
 fi
 
+: Set executable suffix now -- needed before hints available
+if test -f "/libs/version.library"; then
+: Amiga OS
+    _exe=""
+elif test -f "/system/gnu_library/bin/ar.pm"; then
+: Stratus VOS
+    _exe=".pm"
+elif test -n "$DJGPP"; then
+: DOS DJGPP
+    _exe=".exe"
+elif test -d c:/. ; then
+: OS/2 or cygwin
+    _exe=".exe"
+fi
+
 i_whoami=''
 ccname=''
 ccversion=''
@@ -1062,6 +1082,9 @@ case "$sh" in
 			if test -f "$xxx"; then
 				sh="$xxx";
 				break
+			elif test "X$_exe" != X -a -f "$xxx$_exe"; then
+				sh="$xxx";
+				break
 			elif test -f "$xxx.exe"; then
 				sh="$xxx";
 				break
@@ -1072,7 +1095,7 @@ case "$sh" in
 esac
 
 case "$sh" in
-'')	cat <<EOM >&2
+'')	cat >&2 <<EOM
 $me:  Fatal Error:  I can't find a Bourne Shell anywhere.  
 
 Usually it's in /bin/sh.  How did you even get this far?
@@ -1088,18 +1111,30 @@ if `$sh -c '#' >/dev/null 2>&1`; then
 	shsharp=true
 	spitshell=cat
 	xcat=/bin/cat
-	test -f $xcat || xcat=/usr/bin/cat
-	echo "#!$xcat" >try
-	$eunicefix try
-	chmod +x try
-	./try > today
+	test -f $xcat$_exe || xcat=/usr/bin/cat
+	if test ! -f $xcat$_exe; then
+		for p in `echo $PATH | sed -e "s/$p_/ /g"` $paths; do
+			if test -f $p/cat$_exe; then
+				xcat=$p/cat
+				break
+			fi
+		done
+		if test ! -f $xcat$_exe; then
+			echo "Can't find cat anywhere!"
+			exit 1
+		fi
+	fi
+	echo "#!$xcat" >sharp
+	$eunicefix sharp
+	chmod +x sharp
+	./sharp > today
 	if test -s today; then
 		sharpbang='#!'
 	else
-		echo "#! $xcat" > try
-		$eunicefix try
-		chmod +x try
-		./try > today
+		echo "#! $xcat" > sharp
+		$eunicefix sharp
+		chmod +x sharp
+		./sharp > today
 		if test -s today; then
 			sharpbang='#! '
 		else
@@ -1119,28 +1154,28 @@ else
 	echo "I presume that if # doesn't work, #! won't work either!"
 	sharpbang=': use '
 fi
-rm -f try today
+rm -f sharp today
 
 : figure out how to guarantee sh startup
 case "$startsh" in
 '') startsh=${sharpbang}${sh} ;;
 *)
 esac
-cat >try <<EOSS
+cat >sharp <<EOSS
 $startsh
 set abc
 test "$?abc" != 1
 EOSS
 
-chmod +x try
-$eunicefix try
-if ./try; then
+chmod +x sharp
+$eunicefix sharp
+if ./sharp; then
 	: echo "Yup, it does."
 else
 	echo "Hmm... '$startsh' does not guarantee sh startup..."
 	echo "You may have to fix up the shell scripts to make sure $sh runs them."
 fi
-rm -f try
+rm -f sharp
 
 
 : Save command line options in file UU/cmdline.opt for later use in
@@ -1152,12 +1187,24 @@ config_args='$*'
 config_argc=$#
 EOSH
 argn=1
+args_exp=''
+args_sep=''
 for arg in "$@"; do
 	cat >>cmdline.opt <<EOSH
 config_arg$argn='$arg'
 EOSH
+	# Extreme backslashitis: replace each ' by '"'"'
+	cat <<EOC | sed -e "s/'/'"'"'"'"'"'"'/g" > cmdl.opt
+$arg
+EOC
+	arg_exp=`cat cmdl.opt`
+	args_exp="$args_exp$args_sep'$arg_exp'"
 	argn=`expr $argn + 1`
+	args_sep=' '
 done
+# args_exp is good for restarting self: eval "set X $args_exp"; shift; $0 "$@"
+# used by ./hints/os2.sh
+rm -f cmdl.opt
 
 : produce awk script to parse command line options
 cat >options.awk <<'EOF'
@@ -1520,7 +1567,7 @@ for file in $*; do
 		*/*)
 			dir=`expr X$file : 'X\(.*\)/'`
 			file=`expr X$file : 'X.*/\(.*\)'`
-			(cd $dir && . ./$file)
+			(cd "$dir" && . ./$file)
 			;;
 		*)
 			. ./$file
@@ -1533,19 +1580,19 @@ for file in $*; do
 			dir=`expr X$file : 'X\(.*\)/'`
 			file=`expr X$file : 'X.*/\(.*\)'`
 			(set x $dir; shift; eval $mkdir_p)
-			sh <$src/$dir/$file
+			sh <"$src/$dir/$file"
 			;;
 		*)
-			sh <$src/$file
+			sh <"$src/$file"
 			;;
 		esac
 		;;
 	esac
 done
-if test -f $src/config_h.SH; then
+if test -f "$src/config_h.SH"; then
 	if test ! -f config.h; then
 	: oops, they left it out of MANIFEST, probably, so do it anyway.
-	. $src/config_h.SH
+	. "$src/config_h.SH"
 	fi
 fi
 EOS
@@ -1601,13 +1648,13 @@ rm -f .echotmp
 
 : Now test for existence of everything in MANIFEST
 echo " "
-if test -f $rsrc/MANIFEST; then
+if test -f "$rsrc/MANIFEST"; then
 	echo "First let's make sure your kit is complete.  Checking..." >&4
-	awk '$1 !~ /PACK[A-Z]+/ {print $1}' $rsrc/MANIFEST | split -50
+	awk '$1 !~ /PACK[A-Z]+/ {print $1}' "$rsrc/MANIFEST" | (split -l 50 2>/dev/null || split -50)
 	rm -f missing
 	tmppwd=`pwd`
 	for filelist in x??; do
-		(cd $rsrc; ls `cat $tmppwd/$filelist` >/dev/null 2>>$tmppwd/missing)
+		(cd "$rsrc"; ls `cat "$tmppwd/$filelist"` >/dev/null 2>>"$tmppwd/missing")
 	done
 	if test -s missing; then
 		cat missing >&4
@@ -1656,6 +1703,11 @@ if test X"$trnl" = X; then
 	foox) trnl='\012' ;;
 	esac
 fi
+if test X"$trnl" = X; then
+       case "`echo foo|tr '\r\n' xy 2>/dev/null`" in
+       fooxy) trnl='\n\r' ;;
+       esac
+fi
 if test X"$trnl" = X; then
 	cat <<EOM >&2
 
@@ -1999,7 +2051,7 @@ for file in $loclist; do
 	'') xxx=`./loc $file $file $pth`;;
 	*) xxx=`./loc $xxx $xxx $pth`;;
 	esac
-	eval $file=$xxx
+	eval $file=$xxx$_exe
 	eval _$file=$xxx
 	case "$xxx" in
 	/*)
@@ -2032,7 +2084,7 @@ for file in $trylist; do
 	'') xxx=`./loc $file $file $pth`;;
 	*) xxx=`./loc $xxx $xxx $pth`;;
 	esac
-	eval $file=$xxx
+	eval $file=$xxx$_exe
 	eval _$file=$xxx
 	case "$xxx" in
 	/*)
@@ -2065,7 +2117,6 @@ test)
 	;;
 *)
 	if `sh -c "PATH= test true" >/dev/null 2>&1`; then
-		echo "Using the test built into your sh."
 		echo "Using the test built into your sh."
 		test=test
 		_test=test
@@ -2103,10 +2154,10 @@ FOO
 	;;
 esac
 
-cat <<EOS >checkcc
+cat <<EOS >trygcc
 $startsh
 EOS
-cat <<'EOSC' >>checkcc
+cat <<'EOSC' >>trygcc
 case "$cc" in
 '') ;;
 *)  $rm -f try try.*
@@ -2115,7 +2166,7 @@ int main(int argc, char *argv[]) {
   return 0;
 }
 EOM
-    if $cc -o try $ccflags try.c; then
+    if $cc -o try $ccflags $ldflags try.c; then
        :
     else
         echo "Uh-oh, the C compiler '$cc' doesn't seem to be working." >&4
@@ -2144,11 +2195,43 @@ EOM
                     fi
                 fi  
                 case "$ans" in
-                [yY]*) cc=gcc; ccname=gcc; ccflags=''; despair=no ;;
+                [yY]*) cc=gcc; ccname=gcc; ccflags=''; despair=no;
+                       if $test -f usethreads.cbu; then
+                           $cat >&4 <<EOM 
+
+*** However, any setting of the C compiler flags (e.g. for thread support)
+*** has been lost.  It may be necessary to pass -Dcc=gcc to Configure
+*** (together with e.g. -Dusethreads).
+
+EOM
+                       fi;;
                 esac
             fi
         fi
+    fi
+    $rm -f try try.*
+    ;;
+esac
+EOSC
+
+cat <<EOS >checkcc
+$startsh
+EOS
+cat <<'EOSC' >>checkcc
+case "$cc" in        
+'') ;;
+*)  $rm -f try try.*              
+    $cat >try.c <<EOM
+int main(int argc, char *argv[]) {
+  return 0;
+}
+EOM
+    if $cc -o try $ccflags $ldflags try.c; then
+       :
+    else
         if $test X"$despair" = Xyes; then
+           echo "Uh-oh, the C compiler '$cc' doesn't seem to be working." >&4
+        fi
 	    $cat >&4 <<EOM
 You need to find a working C compiler.
 Either (purchase and) install the C compiler supplied by your OS vendor,
@@ -2157,7 +2240,6 @@ I cannot continue any further, aborting.
 EOM
             exit 1
         fi
-    fi
     $rm -f try try.*
     ;;
 esac
@@ -2178,24 +2260,47 @@ $rm -f blurfl sym
 : determine whether symbolic links are supported
 echo " "
 case "$lns" in
-*"ln -s")
+*"ln"*" -s")
 	echo "Checking how to test for symbolic links..." >&4
 	$lns blurfl sym
 	if $test "X$issymlink" = X; then
-		sh -c "PATH= test -h sym" >/dev/null 2>&1
+		case "$newsh" in
+		'') sh     -c "PATH= test -h sym" >/dev/null 2>&1 ;;
+		*)  $newsh -c "PATH= test -h sym" >/dev/null 2>&1 ;;
+		esac
 		if test $? = 0; then
 			issymlink="test -h"
+		else
+			echo "Your builtin 'test -h' may be broken." >&4
+			case "$test" in
+			/*)	;;
+			*)	pth=`echo $PATH | sed -e "s/$p_/ /g"`
+				for p in $pth
+				do
+					if test -f "$p/$test"; then
+						test="$p/$test"
+						break
 		fi		
-	fi
-	if $test "X$issymlink" = X; then
-		if  $test -h >/dev/null 2>&1; then
+				done
+				;;
+			esac
+			case "$test" in
+			/*)
+				echo "Trying external '$test -h'." >&4
 			issymlink="$test -h"
-			echo "Your builtin 'test -h' may be broken, I'm using external '$test -h'." >&4
+				if $test ! -h sym >/dev/null 2>&1; then
+					echo "External '$test -h' is broken, too." >&4
+					issymlink=''
 		fi		
+				;;
+			*)	issymlink='' ;;
+			esac
+	fi
 	fi
 	if $test "X$issymlink" = X; then
 		if $test -L sym 2>/dev/null; then
 			issymlink="$test -L"
+			echo "The builtin '$test -L' worked." >&4
 		fi
 	fi
 	if $test "X$issymlink" != X; then
@@ -2218,7 +2323,7 @@ $define|true|[yY]*)
 		exit 1
 		;;
 	*)	case "$lns:$issymlink" in
-		*"ln -s:"*"test -"?)
+		*"ln"*" -s:"*"test -"?)
 			echo "Creating the symbolic links..." >&4
 			echo "(First creating the subdirectories...)" >&4
 			cd ..
@@ -2248,8 +2353,8 @@ $define|true|[yY]*)
 				fi
 			done
 			# Sanity check 2.
-			if test ! -f t/base/cond.t; then
-				echo "Failed to create the symlinks.  Aborting." >&4
+			if test ! -f t/base/lex.t; then
+				echo "Failed to create the symlinks (t/base/lex.t missing).  Aborting." >&4
 				exit 1
 			fi
 			cd UU
@@ -2262,6 +2367,250 @@ $define|true|[yY]*)
 	;;
 esac
 
+
+case "$usecrosscompile" in
+$define|true|[yY]*)
+	$echo "Cross-compiling..."
+        croak=''
+    	case "$cc" in
+	*-*-gcc) # A cross-compiling gcc, probably.
+	    targetarch=`$echo $cc|$sed 's/-gcc$//'`
+	    ar=$targetarch-ar
+	    # leave out ld, choosing it is more complex
+	    nm=$targetarch-nm
+	    ranlib=$targetarch-ranlib
+	    $echo 'extern int foo;' > try.c
+	    set X `$cc -v -E try.c 2>&1 | $awk '/^#include </,/^End of search /'|$grep '/include'`
+	    shift
+            if $test $# -gt 0; then
+	        incpth="$incpth $*"
+		incpth="`$echo $incpth|$sed 's/^ //'`"
+                echo "Guessing incpth '$incpth'." >&4
+                for i in $*; do
+		    j="`$echo $i|$sed 's,/include$,/lib,'`"
+		    if $test -d $j; then
+			libpth="$libpth $j"
+		    fi
+                done   
+		libpth="`$echo $libpth|$sed 's/^ //'`"
+                echo "Guessing libpth '$libpth'." >&4
+	    fi
+	    $rm -f try.c
+	    ;;
+	esac
+	case "$targetarch" in
+	'') echo "Targetarch not defined." >&4; croak=y ;;
+        *)  echo "Using targetarch $targetarch." >&4 ;;
+	esac
+	case "$incpth" in
+	'') echo "Incpth not defined." >&4; croak=y ;;
+        *)  echo "Using incpth '$incpth'." >&4 ;;
+	esac
+	case "$libpth" in
+	'') echo "Libpth not defined." >&4; croak=y ;;
+        *)  echo "Using libpth '$libpth'." >&4 ;;
+	esac
+	case "$usrinc" in
+	'') for i in $incpth; do
+	        if $test -f $i/errno.h -a -f $i/stdio.h -a -f $i/time.h; then
+		    usrinc=$i
+	            echo "Guessing usrinc $usrinc." >&4
+		    break
+		fi
+	    done
+	    case "$usrinc" in
+	    '') echo "Usrinc not defined." >&4; croak=y ;;
+	    esac
+            ;;
+        *)  echo "Using usrinc $usrinc." >&4 ;;
+	esac
+	case "$targethost" in
+	'') echo "Targethost not defined." >&4; croak=y ;;
+        *)  echo "Using targethost $targethost." >&4
+	esac
+	locincpth=' '
+	loclibpth=' '
+	case "$croak" in
+	y) echo "Cannot continue, aborting." >&4; exit 1 ;;
+	esac
+	case "$src" in
+	/*) run=$src/Cross/run
+	    targetmkdir=$src/Cross/mkdir
+	    to=$src/Cross/to
+	    from=$src/Cross/from
+	    ;;
+	*)  pwd=`$test -f ../Configure & cd ..; pwd`
+	    run=$pwd/Cross/run
+	    targetmkdir=$pwd/Cross/mkdir
+	    to=$pwd/Cross/to
+	    from=$pwd/Cross/from
+	    ;;
+	esac
+	case "$targetrun" in
+	'') targetrun=ssh ;;
+	esac
+	case "$targetto" in
+	'') targetto=scp ;;
+	esac
+	case "$targetfrom" in
+	'') targetfrom=scp ;;
+	esac
+    	run=$run-$targetrun
+    	to=$to-$targetto
+    	from=$from-$targetfrom
+	case "$targetdir" in
+	'')  targetdir=/tmp
+             echo "Guessing targetdir $targetdir." >&4
+             ;;
+	esac
+	case "$targetuser" in
+	'')  targetuser=root
+             echo "Guessing targetuser $targetuser." >&4
+             ;;
+	esac
+	case "$targetfrom" in
+	scp)	q=-q ;;
+	*)	q='' ;;
+	esac
+	case "$targetrun" in
+	ssh|rsh)
+	    cat >$run <<EOF
+#!/bin/sh
+case "\$1" in
+-cwd)
+  shift
+  cwd=\$1
+  shift
+  ;;
+esac
+case "\$cwd" in
+'') cwd=$targetdir ;;
+esac
+exe=\$1
+shift
+if $test ! -f \$exe.xok; then
+  $to \$exe
+  $touch \$exe.xok
+fi
+$targetrun -l $targetuser $targethost "cd \$cwd && ./\$exe \$@"
+EOF
+	    ;;
+	*)  echo "Unknown targetrun '$targetrun'" >&4
+	    exit 1
+	    ;;
+	esac
+	case "$targetmkdir" in
+	*/Cross/mkdir)
+	    cat >$targetmkdir <<EOF
+#!/bin/sh
+$targetrun -l $targetuser $targethost "mkdir -p \$@"
+EOF
+	    $chmod a+rx $targetmkdir
+	    ;;
+	*)  echo "Unknown targetmkdir '$targetmkdir'" >&4
+	    exit 1
+	    ;;
+	esac
+	case "$targetto" in
+	scp|rcp)
+	    cat >$to <<EOF
+#!/bin/sh
+for f in \$@
+do
+  case "\$f" in
+  /*)
+    $targetmkdir \`dirname \$f\`
+    $targetto $q \$f $targetuser@$targethost:\$f            || exit 1
+    ;;
+  *)
+    $targetmkdir $targetdir/\`dirname \$f\`
+    $targetto $q \$f $targetuser@$targethost:$targetdir/\$f || exit 1
+    ;;
+  esac
+done
+exit 0
+EOF
+	    ;;
+	cp) cat >$to <<EOF
+#!/bin/sh
+for f in \$@
+do
+  case "\$f" in
+  /*)
+    $mkdir -p $targetdir/\`dirname \$f\`
+    $cp \$f $targetdir/\$f || exit 1
+    ;;
+  *)
+    $targetmkdir $targetdir/\`dirname \$f\`
+    $cp \$f $targetdir/\$f || exit 1
+    ;;
+  esac
+done
+exit 0
+EOF
+	    ;;
+	*)  echo "Unknown targetto '$targetto'" >&4
+	    exit 1
+	    ;;
+	esac
+	case "$targetfrom" in
+	scp|rcp)
+	  cat >$from <<EOF
+#!/bin/sh
+for f in \$@
+do
+  $rm -f \$f
+  $targetfrom $q $targetuser@$targethost:$targetdir/\$f . || exit 1
+done
+exit 0
+EOF
+	    ;;
+	cp) cat >$from <<EOF
+#!/bin/sh
+for f in \$@
+do
+  $rm -f \$f
+  cp $targetdir/\$f . || exit 1
+done
+exit 0
+EOF
+	    ;;
+	*)  echo "Unknown targetfrom '$targetfrom'" >&4
+	    exit 1
+	    ;;
+	esac
+	if $test ! -f $run; then
+	    echo "Target 'run' script '$run' not found." >&4
+	else
+	    $chmod a+rx $run
+	fi
+	if $test ! -f $to; then
+	    echo "Target 'to' script '$to' not found." >&4
+	else
+	    $chmod a+rx $to
+	fi
+	if $test ! -f $from; then
+	    echo "Target 'from' script '$from' not found." >&4
+	else
+	    $chmod a+rx $from
+	fi
+	if $test ! -f $run -o ! -f $to -o ! -f $from; then
+	    exit 1
+	fi
+	cat >&4 <<EOF
+Using '$run' for remote execution,
+and '$from' and '$to'
+for remote file transfer.
+EOF
+	;;
+*)	run=''
+	to=:
+	from=:
+	usecrosscompile='undef'
+	targetarch=''
+	;;
+esac
+
 : see whether [:lower:] and [:upper:] are supported character classes
 echo " "
 case "`echo AbyZ | $tr '[:lower:]' '[:upper:]' 2>/dev/null`" in
@@ -2533,6 +2882,9 @@ EOM
 			;;
 		next*) osname=next ;;
 		nonstop-ux) osname=nonstopux ;;
+		openbsd) osname=openbsd
+                	osvers="$3"
+                	;;
 		POSIX-BC | posix-bc ) osname=posix-bc
 			osvers="$3"
 			;;
@@ -2726,7 +3078,7 @@ EOM
 		elif $test -f $src/hints/$file.sh; then
 			. $src/hints/$file.sh
 			$cat $src/hints/$file.sh >> UU/config.sh
-		elif $test X$tans = X -o X$tans = Xnone ; then
+		elif $test X"$tans" = X -o X"$tans" = Xnone ; then
 			: nothing
 		else
 			: Give one chance to correct a possible typo.
@@ -3115,7 +3467,7 @@ fi
 
 echo " "
 echo "Checking for GNU cc in disguise and/or its version number..." >&4
-$cat >gccvers.c <<EOM
+$cat >try.c <<EOM
 #include <stdio.h>
 int main() {
 #ifdef __GNUC__
@@ -3125,11 +3477,11 @@ int main() {
 	printf("%s\n", "1");
 #endif
 #endif
-	exit(0);
+	return(0);
 }
 EOM
-if $cc -o gccvers $ccflags $ldflags gccvers.c; then
-	gccversion=`./gccvers`
+if $cc -o try $ccflags $ldflags try.c; then
+	gccversion=`$run ./try`
 	case "$gccversion" in
 	'') echo "You are not using GNU cc." ;;
 	*)  echo "You are using GNU cc $gccversion."
@@ -3147,7 +3499,7 @@ else
 		;;
 	esac
 fi
-$rm -f gccvers*
+$rm -f try try.*
 case "$gccversion" in
 1.*) cpp=`./loc gcc-cpp $cpp $pth` ;;
 esac
@@ -3400,7 +3752,9 @@ esac
 
 case "$fn" in
 *\(*)
-	expr $fn : '.*(\(.*\)).*' | $tr ',' $trnl >getfile.ok
+	: getfile will accept an answer from the comma-separated list
+	: enclosed in parentheses even if it does not meet other criteria.
+	expr "$fn" : '.*(\(.*\)).*' | $tr ',' $trnl >getfile.ok
 	fn=`echo $fn | sed 's/(.*)//'`
 	;;
 esac
@@ -3842,7 +4196,7 @@ for thislib in $libswanted; do
 	for thisdir in $libspath; do
 	    xxx=''
 	    if $test ! -f "$xxx" -a "X$ignore_versioned_solibs" = "X"; then
-		xxx=`ls $thisdir/lib$thislib.$so.[0-9] 2>/dev/null|tail -1`
+		xxx=`ls $thisdir/lib$thislib.$so.[0-9] 2>/dev/null|sed -n '$p'`
 	        $test -f "$xxx" && eval $libscheck
 		$test -f "$xxx" && libstyle=shared
 	    fi
@@ -4054,7 +4408,10 @@ none) ccflags='';;
 esac
 
 : the following weeds options from ccflags that are of no interest to cpp
-cppflags="$ccflags"
+case "$cppflags" in
+'') cppflags="$ccflags" ;;
+*)  cppflags="$cppflags $ccflags" ;;
+esac
 case "$gccversion" in
 1.*) cppflags="$cppflags -D__GNUC__"
 esac
@@ -4162,7 +4519,7 @@ echo " "
 echo "Checking your choice of C compiler and flags for coherency..." >&4
 $cat > try.c <<'EOF'
 #include <stdio.h>
-int main() { printf("Ok\n"); exit(0); }
+int main() { printf("Ok\n"); return(0); }
 EOF
 set X $cc -o try $optimize $ccflags $ldflags try.c $libs
 shift
@@ -4177,15 +4534,15 @@ $cat >> try.msg <<EOM
 I used the command:
 
 	$*
-	./try
+	$run ./try
 
 and I got the following output:
 
 EOM
 dflt=y
 if $sh -c "$cc -o try $optimize $ccflags $ldflags try.c $libs" >>try.msg 2>&1; then
-	if $sh -c './try' >>try.msg 2>&1; then
-		xxx=`./try`
+	if $sh -c "$run ./try" >>try.msg 2>&1; then
+		xxx=`$run ./try`
 		case "$xxx" in
 		"Ok") dflt=n ;;
 		*)	echo 'The program compiled OK, but produced no output.' >> try.msg
@@ -4302,13 +4659,130 @@ mc_file=$1;
 shift;
 $cc -o ${mc_file} $optimize $ccflags $ldflags $* ${mc_file}.c $libs;'
 
+: determine filename position in cpp output
+echo " "
+echo "Computing filename position in cpp output for #include directives..." >&4
+case "$osname" in
+vos) testaccess=-e ;;
+*)   testaccess=-r ;;
+esac
+echo '#include <stdio.h>' > foo.c
+$cat >fieldn <<EOF
+$startsh
+$cppstdin $cppflags $cppminus <foo.c 2>/dev/null | \
+$grep '^[ 	]*#.*stdio\.h' | \
+while read cline; do
+	pos=1
+	set \$cline
+	while $test \$# -gt 0; do
+		if $test $testaccess \`echo \$1 | $tr -d '"'\`; then
+			echo "\$pos"
+			exit 0
+		fi
+		shift
+		pos=\`expr \$pos + 1\`
+	done
+done
+EOF
+chmod +x fieldn
+fieldn=`./fieldn`
+$rm -f foo.c fieldn
+case $fieldn in
+'') pos='???';;
+1) pos=first;;
+2) pos=second;;
+3) pos=third;;
+*) pos="${fieldn}th";;
+esac
+echo "Your cpp writes the filename in the $pos field of the line."
+
+case "$osname" in
+vos) cppfilter="tr '\\\\>' '/' |" ;; # path component separator is >
+*)   cppfilter='' ;;
+esac
+: locate header file
+$cat >findhdr <<EOF
+$startsh
+wanted=\$1
+name=''
+for usrincdir in $usrinc
+do
+	if test -f \$usrincdir/\$wanted; then
+		echo "\$usrincdir/\$wanted"
+		exit 0
+	fi
+done
+awkprg='{ print \$$fieldn }'
+echo "#include <\$wanted>" > foo\$\$.c
+$cppstdin $cppminus $cppflags < foo\$\$.c 2>/dev/null | \
+$cppfilter $grep "^[ 	]*#.*\$wanted" | \
+while read cline; do
+	name=\`echo \$cline | $awk "\$awkprg" | $tr -d '"'\`
+	case "\$name" in
+	*[/\\\\]\$wanted) echo "\$name"; exit 1;;
+	*[\\\\/]\$wanted) echo "\$name"; exit 1;;
+	*) exit 2;;
+	esac;
+done;
+#
+# status = 0: grep returned 0 lines, case statement not executed
+# status = 1: headerfile found
+# status = 2: while loop executed, no headerfile found
+#
+status=\$?
+$rm -f foo\$\$.c;
+if test \$status -eq 1; then
+	exit 0;
+fi
+exit 1
+EOF
+chmod +x findhdr
+
+: define an alternate in-header-list? function
+inhdr='echo " "; td=$define; tu=$undef; yyy=$@;
+cont=true; xxf="echo \"<\$1> found.\" >&4";
+case $# in 2) xxnf="echo \"<\$1> NOT found.\" >&4";;
+*) xxnf="echo \"<\$1> NOT found, ...\" >&4";;
+esac;
+case $# in 4) instead=instead;; *) instead="at last";; esac;
+while $test "$cont"; do
+	xxx=`./findhdr $1`
+	var=$2; eval "was=\$$2";
+	if $test "$xxx" && $test -r "$xxx";
+	then eval $xxf;
+	eval "case \"\$$var\" in $undef) . ./whoa; esac"; eval "$var=\$td";
+		cont="";
+	else eval $xxnf;
+	eval "case \"\$$var\" in $define) . ./whoa; esac"; eval "$var=\$tu"; fi;
+	set $yyy; shift; shift; yyy=$@;
+	case $# in 0) cont="";;
+	2) xxf="echo \"but I found <\$1> $instead.\" >&4";
+		xxnf="echo \"and I did not find <\$1> either.\" >&4";;
+	*) xxf="echo \"but I found <\$1\> instead.\" >&4";
+		xxnf="echo \"there is no <\$1>, ...\" >&4";;
+	esac;
+done;
+while $test "$yyy";
+do set $yyy; var=$2; eval "was=\$$2";
+	eval "case \"\$$var\" in $define) . ./whoa; esac"; eval "$var=\$tu";
+	set $yyy; shift; shift; yyy=$@;
+done'
+
+: see if stdlib is available
+set stdlib.h i_stdlib
+eval $inhdr
+
 : check for lengths of integral types
 echo " "
 case "$intsize" in
 '')
 	echo "Checking to see how big your integers are..." >&4
-	$cat >intsize.c <<'EOCP'
+	$cat >try.c <<EOCP
 #include <stdio.h>
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
 int main()
 {
 	printf("intsize=%d;\n", (int)sizeof(int));
@@ -4317,9 +4791,9 @@ int main()
 	exit(0);
 }
 EOCP
-	set intsize
-	if eval $compile_ok && ./intsize > /dev/null; then
-		eval `./intsize`
+	set try
+	if eval $compile_ok && $run ./try > /dev/null; then
+		eval `$run ./try`
 		echo "Your integers are $intsize bytes long."
 		echo "Your long integers are $longsize bytes long."
 		echo "Your short integers are $shortsize bytes long."
@@ -4346,7 +4820,7 @@ EOM
 	fi
 	;;
 esac
-$rm -f intsize intsize.*
+$rm -f try try.*
 
 : see what type lseek is declared as in the kernel
 rp="What is the type used for lseek's offset on this system?"
@@ -4366,7 +4840,7 @@ int main()
 EOCP
 set try
 if eval $compile_ok; then
-	lseeksize=`./try`
+	lseeksize=`$run ./try`
 	echo "Your file offsets are $lseeksize bytes long."
 else
 	dflt=$longsize
@@ -4392,6 +4866,10 @@ echo "Checking the size of $zzz..." >&4
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
@@ -4399,7 +4877,7 @@ int main() {
 EOCP
 set try
 if eval $compile_ok; then
-	yyy=`./try`
+	yyy=`$run ./try`
 	case "$yyy" in
 	'')	fpossize=4
 		echo "(I can't execute the test program--guessing $fpossize.)" >&4
@@ -4478,7 +4956,7 @@ int main()
 EOCP
 		set try
 		if eval $compile_ok; then
-			lseeksize=`./try`
+			lseeksize=`$run ./try`
 			$echo "Your file offsets are now $lseeksize bytes long."
 		else
 			dflt="$lseeksize"
@@ -4496,14 +4974,18 @@ EOCP
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
 		if eval $compile_ok; then
-			yyy=`./try`
+			yyy=`$run ./try`
 			dflt="$lseeksize"
 			case "$yyy" in
 			'')	echo " "
@@ -4707,26 +5189,43 @@ esac
 
 echo " "
 echo "Checking for GNU C Library..." >&4
-cat >gnulibc.c <<EOM
+cat >try.c <<'EOCP'
+/* Find out version of GNU C library.  __GLIBC__ and __GLIBC_MINOR__
+   alone are insufficient to distinguish different versions, such as
+   2.0.6 and 2.0.7.  The function gnu_get_libc_version() appeared in
+   libc version 2.1.0.      A. Dougherty,  June 3, 2002.
+*/
 #include <stdio.h>
-int main()
+int main(void)
 {
 #ifdef __GLIBC__
-    exit(0);
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
 #else
-    exit(1);
+    return 1;
 #endif
 }
-EOM
-set gnulibc
-if eval $compile_ok && ./gnulibc; then
+EOCP
+set try
+if eval $compile_ok && $run ./try > glibc.ver; then
 	val="$define"
-	echo "You are using the GNU C Library"
+	gnulibc_version=`$cat glibc.ver`
+	echo "You are using the GNU C Library version $gnulibc_version"
 else
 	val="$undef"
+	gnulibc_version=''
 	echo "You are not using the GNU C Library"
 fi
-$rm -f gnulibc*
+$rm -f try try.* glibc.ver
 set d_gnulibc
 eval $setvar
 
@@ -4743,7 +5242,7 @@ case "$usenm" in
 	esac
 	case "$dflt" in
 	'') 
-		if $test "$osname" = aix -a ! -f /lib/syscalls.exp; then
+		if $test "$osname" = aix -a "X$PASE" != "Xdefine" -a ! -f /lib/syscalls.exp; then
 			echo " "
 			echo "Whoops!  This is an AIX system without /lib/syscalls.exp!" >&4
 			echo "'nm' won't be sufficient on this sytem." >&4
@@ -4980,9 +5479,9 @@ done >libc.tmp
 $echo $n ".$c"
 $grep fprintf libc.tmp > libc.ptf
 xscan='eval "<libc.ptf $com >libc.list"; $echo $n ".$c" >&4'
-xrun='eval "<libc.tmp $com >libc.list"; echo "done" >&4'
+xrun='eval "<libc.tmp $com >libc.list"; echo "done." >&4'
 xxx='[ADTSIW]'
-if com="$sed -n -e 's/__IO//' -e 's/^.* $xxx  *_[_.]*//p' -e 's/^.* $xxx  *//p'";\
+if com="$sed -n -e 's/__IO//' -e 's/^.* $xxx  *//p'";\
 	eval $xscan;\
 	$contains '^fprintf$' libc.list >/dev/null 2>&1; then
 		eval $xrun
@@ -5103,9 +5602,9 @@ $rm -f libnames libpath
 : is a C symbol defined?
 csym='tlook=$1;
 case "$3" in
--v) tf=libc.tmp; tc=""; tdc="";;
--a) tf=libc.tmp; tc="[0]"; tdc="[]";;
-*) tlook="^$1\$"; tf=libc.list; tc="()"; tdc="()";;
+-v) tf=libc.tmp; tdc="";;
+-a) tf=libc.tmp; tdc="[]";;
+*) tlook="^$1\$"; tf=libc.list; tdc="()";;
 esac;
 tx=yes;
 case "$reuseval-$4" in
@@ -5114,25 +5613,28 @@ true-*) tx=no; eval "tval=\$$4"; case "$tval" in "") tx=yes;; esac;;
 esac;
 case "$tx" in
 yes)
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
+	tval=false;
+	if $test "$runnm" = true; then
+		if $contains $tlook $tf >/dev/null 2>&1; then
+			tval=true;
+		elif $test "$mistrustnm" = compile -o "$mistrustnm" = run; then
+			echo "void *(*(p()))$tdc { extern void *$1$tdc; return &$1; } int main() { if(p()) return(0); else return(1); }"> try.c;
+			$cc -o try $optimize $ccflags $ldflags try.c >/dev/null 2>&1 $libs && tval=true;
+			$test "$mistrustnm" = run -a -x try && { $run ./try$_exe >/dev/null 2>&1 || tval=false; };
+			$rm -f try$_exe try.c core core.* try.core;
 		fi;
-		$rm -f t t.c;;
-	esac;;
+	else
+		echo "void *(*(p()))$tdc { extern void *$1$tdc; return &$1; } int main() { if(p()) return(0); else return(1); }"> try.c;
+		$cc -o try $optimize $ccflags $ldflags try.c $libs >/dev/null 2>&1 && tval=true;
+		$rm -f try$_exe try.c;
+	fi;
+	;;
 *)
 	case "$tval" in
 	$define) tval=true;;
 	*) tval=false;;
-	esac;;
+	esac;
+	;;
 esac;
 eval "$2=$tval"'
 
@@ -5229,8 +5731,12 @@ echo " "
 case "$doublesize" in
 '')
 	echo "Checking to see how big your double precision numbers are..." >&4
-	$cat >try.c <<'EOCP'
+	$cat >try.c <<EOCP
 #include <stdio.h>
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
 int main()
 {
     printf("%d\n", (int)sizeof(double));
@@ -5239,7 +5745,7 @@ int main()
 EOCP
 	set try
 	if eval $compile_ok; then
-		doublesize=`./try`
+		doublesize=`$run ./try`
 		echo "Your double is $doublesize bytes long."
 	else
 		dflt='8'
@@ -5283,7 +5789,7 @@ EOCP
 	set try
 	set try
 	if eval $compile; then
-		longdblsize=`./try$exe_ext`
+		longdblsize=`$run ./try`
 		echo "Your long doubles are $longdblsize bytes long."
 	else
 		dflt='8'
@@ -5294,7 +5800,9 @@ EOCP
 		longdblsize="$ans"
 	fi
 	if $test "X$doublesize" = "X$longdblsize"; then
-		echo "(That isn't any different from an ordinary double.)"
+		echo "That isn't any different from an ordinary double."
+		echo "I'll keep your setting anyway, but you may see some"
+		echo "harmless compilation warnings."
 	fi	
 	;;
 esac
@@ -5322,6 +5830,10 @@ case "$myarchname" in
 	archname=''
 	;;
 esac
+case "$targetarch" in
+'') ;;
+*)  archname=`echo $targetarch|sed 's,^[^-]*-,,'` ;;
+esac
 myarchname="$tarch"
 case "$archname" in
 '') dflt="$tarch";;
@@ -5382,7 +5894,7 @@ $define)
 	echo "Long doubles selected." >&4
 	case "$longdblsize" in
 	$doublesize)
-		"...but long doubles are equal to doubles, not changing architecture name." >&4
+		echo "...but long doubles are equal to doubles, not changing architecture name." >&4
 		;;
 	*)
 		case "$archname" in
@@ -5399,10 +5911,13 @@ esac
 case "$useperlio" in
 $define)
 	echo "Perlio selected." >&4
+	;;
+*)
+	echo "Perlio not selected, using stdio." >&4
 	case "$archname" in
-        *-perlio*) echo "...and architecture name already has -perlio." >&4
+        *-stdio*) echo "...and architecture name already has -stdio." >&4
                 ;;
-        *)      archname="$archname-perlio"
+        *)      archname="$archname-stdio"
                 echo "...setting architecture name to $archname." >&4
                 ;;
         esac
@@ -5445,12 +5960,17 @@ esac
 prefix="$ans"
 prefixexp="$ansexp"
 
+case "$afsroot" in
+'')	afsroot=/afs ;;
+*)	afsroot=$afsroot ;;
+esac
+
 : is AFS running?
 echo " "
 case "$afs" in
 $define|true)	afs=true ;;
 $undef|false)	afs=false ;;
-*)	if test -d /afs; then
+*)	if test -d $afsroot; then
 		afs=true
 	else
 		afs=false
@@ -5774,7 +6294,7 @@ val="$undef"
 case "$d_suidsafe" in
 "$define")
 	val="$undef"
-	echo "No need to emulate SUID scripts since they are secure here." >& 4
+	echo "No need to emulate SUID scripts since they are secure here." >&4
 	;;
 *)
 	$cat <<EOM
@@ -5801,120 +6321,20 @@ esac
 set d_dosuid
 eval $setvar
 
-: determine filename position in cpp output
-echo " "
-echo "Computing filename position in cpp output for #include directives..." >&4
-echo '#include <stdio.h>' > foo.c
-$cat >fieldn <<EOF
-$startsh
-$cppstdin $cppflags $cppminus <foo.c 2>/dev/null | \
-$grep '^[ 	]*#.*stdio\.h' | \
-while read cline; do
-	pos=1
-	set \$cline
-	while $test \$# -gt 0; do
-		if $test -r \`echo \$1 | $tr -d '"'\`; then
-			echo "\$pos"
-			exit 0
-		fi
-		shift
-		pos=\`expr \$pos + 1\`
-	done
-done
-EOF
-chmod +x fieldn
-fieldn=`./fieldn`
-$rm -f foo.c fieldn
-case $fieldn in
-'') pos='???';;
-1) pos=first;;
-2) pos=second;;
-3) pos=third;;
-*) pos="${fieldn}th";;
-esac
-echo "Your cpp writes the filename in the $pos field of the line."
-
-: locate header file
-$cat >findhdr <<EOF
-$startsh
-wanted=\$1
-name=''
-for usrincdir in $usrinc
-do
-	if test -f \$usrincdir/\$wanted; then
-		echo "\$usrincdir/\$wanted"
-		exit 0
-	fi
-done
-awkprg='{ print \$$fieldn }'
-echo "#include <\$wanted>" > foo\$\$.c
-$cppstdin $cppminus $cppflags < foo\$\$.c 2>/dev/null | \
-$grep "^[ 	]*#.*\$wanted" | \
-while read cline; do
-	name=\`echo \$cline | $awk "\$awkprg" | $tr -d '"'\`
-	case "\$name" in
-	*[/\\\\]\$wanted) echo "\$name"; exit 1;;
-	*[\\\\/]\$wanted) echo "\$name"; exit 1;;
-	*) exit 2;;
-	esac;
-done;
-#
-# status = 0: grep returned 0 lines, case statement not executed
-# status = 1: headerfile found
-# status = 2: while loop executed, no headerfile found
-#
-status=\$?
-$rm -f foo\$\$.c;
-if test \$status -eq 1; then
-	exit 0;
-fi
-exit 1
-EOF
-chmod +x findhdr
-
-: define an alternate in-header-list? function
-inhdr='echo " "; td=$define; tu=$undef; yyy=$@;
-cont=true; xxf="echo \"<\$1> found.\" >&4";
-case $# in 2) xxnf="echo \"<\$1> NOT found.\" >&4";;
-*) xxnf="echo \"<\$1> NOT found, ...\" >&4";;
-esac;
-case $# in 4) instead=instead;; *) instead="at last";; esac;
-while $test "$cont"; do
-	xxx=`./findhdr $1`
-	var=$2; eval "was=\$$2";
-	if $test "$xxx" && $test -r "$xxx";
-	then eval $xxf;
-	eval "case \"\$$var\" in $undef) . ./whoa; esac"; eval "$var=\$td";
-		cont="";
-	else eval $xxnf;
-	eval "case \"\$$var\" in $define) . ./whoa; esac"; eval "$var=\$tu"; fi;
-	set $yyy; shift; shift; yyy=$@;
-	case $# in 0) cont="";;
-	2) xxf="echo \"but I found <\$1> $instead.\" >&4";
-		xxnf="echo \"and I did not find <\$1> either.\" >&4";;
-	*) xxf="echo \"but I found <\$1\> instead.\" >&4";
-		xxnf="echo \"there is no <\$1>, ...\" >&4";;
-	esac;
-done;
-while $test "$yyy";
-do set $yyy; var=$2; eval "was=\$$2";
-	eval "case \"\$$var\" in $define) . ./whoa; esac"; eval "$var=\$tu";
-	set $yyy; shift; shift; yyy=$@;
-done'
-
 : see if this is a malloc.h system
 set malloc.h i_malloc
 eval $inhdr
 
-: see if stdlib is available
-set stdlib.h i_stdlib
-eval $inhdr
-
 : determine which malloc to compile in
 echo " "
 case "$usemymalloc" in
-''|[yY]*|true|$define)	dflt='y' ;;
-*)	dflt='n' ;;
+[yY]*|true|$define)	dflt='y' ;;
+[nN]*|false|$undef)	dflt='n' ;;
+*)	case "$ptrsize" in
+	4) dflt='y' ;;
+	*) dflt='n' ;;
+	esac
+	;;
 esac
 rp="Do you wish to attempt to use the malloc that comes with $package?"
 . ./myread
@@ -6246,7 +6666,11 @@ eval $setvar
 : Cruising for prototypes
 echo " "
 echo "Checking out function prototypes..." >&4
-$cat >prototype.c <<'EOCP'
+$cat >prototype.c <<EOCP
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
 int main(int argc, char *argv[]) {
 	exit(0);}
 EOCP
@@ -6307,13 +6731,13 @@ fi
 : Find perl5.005 or later.
 echo "Looking for a previously installed perl5.005 or later... "
 case "$perl5" in
-'')	for tdir in `echo "$binexp:$PATH" | $sed "s/$path_sep/ /g"`; do
+'')	for tdir in `echo "$binexp$path_sep$PATH" | $sed "s/$path_sep/ /g"`; do
 		: Check if this perl is recent and can load a simple module
-		if $test -x $tdir/perl && $tdir/perl -Mless -e 'use 5.005;' >/dev/null 2>&1; then
+		if $test -x $tdir/perl$exe_ext && $tdir/perl -Mless -e 'use 5.005;' >/dev/null 2>&1; then
 			perl5=$tdir/perl
 			break;
-		elif $test -x $tdir/perl5 && $tdir/perl5 -Mless -e 'use 5.005;' >/dev/null 2>&1; then
-			perl5=$tdir/perl
+		elif $test -x $tdir/perl5$exe_ext && $tdir/perl5 -Mless -e 'use 5.005;' >/dev/null 2>&1; then
+			perl5=$tdir/perl5
 			break;
 		fi
 	done
@@ -6378,14 +6802,14 @@ else {
 EOPL
 chmod +x getverlist
 case "$inc_version_list" in
-'')	if test -x "$perl5"; then
+'')	if test -x "$perl5$exe_ext"; then
 		dflt=`$perl5 getverlist`
 	else
 		dflt='none'
 	fi
 	;;
 $undef) dflt='none' ;;
-*)  dflt="$inc_version_list" ;;
+*)  eval dflt=\"$inc_version_list\" ;;
 esac
 case "$dflt" in
 ''|' ') dflt=none ;;
@@ -6508,7 +6932,7 @@ y*) usedl="$define"
 	esac
     echo "The following dynamic loading files are available:"
 	: Can not go over to $dldir because getfile has path hard-coded in.
-	tdir=`pwd`; cd $rsrc; $ls -C $dldir/dl*.xs; cd $tdir
+	tdir=`pwd`; cd "$rsrc"; $ls -C $dldir/dl*.xs; cd "$tdir"
 	rp="Source file to use for dynamic loading"
 	fn="fne"
 	gfpth="$src"
@@ -6536,6 +6960,7 @@ EOM
 		    esac
 			;;
 		*)  case "$osname" in
+	                darwin) dflt='none' ;;
 			svr4*|esix*|solaris|nonstopux) dflt='-fPIC' ;;
 			*)	dflt='-fpic' ;;
 		    esac ;;
@@ -6557,10 +6982,13 @@ while other systems (such as those using ELF) use $cc.
 
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
@@ -6572,7 +7000,7 @@ int main() {
 		exit(1); /* fail */
 }
 EOM
-		if $cc $ccflags try.c >/dev/null 2>&1 && ./a.out; then
+		if $cc $ccflags $ldflags try.c >/dev/null 2>&1 && $run ./a.out; then
 			cat <<EOM
 You appear to have ELF support.  I'll use $cc to build dynamic libraries.
 EOM
@@ -6626,7 +7054,7 @@ EOM
 	esac
 	for thisflag in $ldflags; do
 		case "$thisflag" in
-		-L*|-R*)
+		-L*|-R*|-Wl,-R*)
 			case " $dflt " in
 			*" $thisflag "*) ;;
 			*) dflt="$dflt $thisflag" ;;
@@ -6757,8 +7185,8 @@ true)
 		linux*)  # ld won't link with a bare -lperl otherwise.
 			dflt=libperl.$so
 			;;
-		cygwin*) # include version
-			dflt=`echo libperl$version | sed -e 's/\./_/g'`$lib_ext
+		cygwin*) # ld links against an importlib
+			dflt=libperl$lib_ext
 			;;
 		*)	# Try to guess based on whether libc has major.minor.
 			case "$libc" in
@@ -6835,13 +7263,13 @@ if "$useshrplib"; then
 	aix)
 		# We'll set it in Makefile.SH...
 		;;
-	solaris|netbsd)
+	solaris)
 		xxx="-R $shrpdir"
 		;;
-	freebsd)
+	freebsd|netbsd)
 		xxx="-Wl,-R$shrpdir"
 		;;
-	linux|irix*|dec_osf)
+	bsdos|linux|irix*|dec_osf)
 		xxx="-Wl,-rpath,$shrpdir"
 		;;
 	next)
@@ -6896,8 +7324,9 @@ esac
 echo " "
 case "$sysman" in
 '') 
-	syspath='/usr/man/man1 /usr/man/mann /usr/man/manl /usr/man/local/man1'
-	syspath="$syspath /usr/man/u_man/man1 /usr/share/man/man1"
+	syspath='/usr/share/man/man1 /usr/man/man1'
+	syspath="$syspath /usr/man/mann /usr/man/manl /usr/man/local/man1"
+	syspath="$syspath /usr/man/u_man/man1"
 	syspath="$syspath /usr/catman/u_man/man1 /usr/man/l_man/man1"
 	syspath="$syspath /usr/local/man/u_man/man1 /usr/local/man/l_man/man1"
 	syspath="$syspath /usr/man/man.L /local/man/man1 /usr/local/man/man1"
@@ -6929,7 +7358,8 @@ case "$man1dir" in
 ' ') dflt=none
 	;;
 '')
-	lookpath="$prefixexp/man/man1 $prefixexp/man/l_man/man1"
+	lookpath="$prefixexp/share/man/man1"
+	lookpath="$lookpath $prefixexp/man/man1 $prefixexp/man/l_man/man1"
 	lookpath="$lookpath $prefixexp/man/p_man/man1"
 	lookpath="$lookpath $prefixexp/man/u_man/man1"
 	lookpath="$lookpath $prefixexp/man/man.1"
@@ -7119,7 +7549,7 @@ case "$man3dir" in
 esac
 
 : see if we have to deal with yellow pages, now NIS.
-if $test -d /usr/etc/yp || $test -d /etc/yp; then
+if $test -d /usr/etc/yp || $test -d /etc/yp || $test -d /usr/lib/yp; then
 	if $test -f /usr/etc/nibindd; then
 		echo " "
 		echo "I'm fairly confident you're on a NeXT."
@@ -7226,6 +7656,9 @@ if $test "$cont"; then
 		fi
 	fi
 fi
+case "$myhostname" in
+'') myhostname=noname ;;
+esac
 : you do not want to know about this
 set $myhostname
 myhostname=$1
@@ -7326,7 +7759,7 @@ case "$myhostname" in
 		esac
 		case "$dflt" in
 		.) echo "(Lost all hope -- silly guess then)"
-			dflt='.uucp'
+			dflt='.nonet'
 			;;
 		esac
 		$rm -f hosts
@@ -7572,7 +8005,7 @@ else
 fi
 
 case "$useperlio" in
-$define|true|[yY]*)	dflt='y';;
+$define|true|[yY]*|'')	dflt='y';;
 *) dflt='n';;
 esac
 cat <<EOM
@@ -7594,7 +8027,7 @@ y|Y)
 	val="$define"
 	;;     
 *)      
-	echo "Ok, doing things the stdio way"
+	echo "Ok, doing things the stdio way."
 	val="$undef"
 	;;
 esac
@@ -7647,7 +8080,7 @@ int main() {
 EOCP
 	set try
 	if eval $compile; then
-		yyy=`./try$exe_ext`
+		yyy=`$run ./try`
 		case "$yyy" in
 		123.456)
 			sPRIfldbl='"f"'; sPRIgldbl='"g"'; sPRIeldbl='"e"';
@@ -7664,17 +8097,17 @@ if $test X"$sPRIfldbl" = X; then
 #include <stdio.h>
 int main() {
   long double d = 123.456;
-  printf("%.3llf\n", d);
+  printf("%.3Lf\n", d);
 }
 EOCP
 	set try
 	if eval $compile; then
-		yyy=`./try$exe_ext`
+		yyy=`$run ./try`
 		case "$yyy" in
 		123.456)
-			sPRIfldbl='"llf"'; sPRIgldbl='"llg"'; sPRIeldbl='"lle"';
-                	sPRIFUldbl='"llF"'; sPRIGUldbl='"llG"'; sPRIEUldbl='"llE"';
-			echo "We will use %llf."
+			sPRIfldbl='"Lf"'; sPRIgldbl='"Lg"'; sPRIeldbl='"Le"';
+                	sPRIFUldbl='"LF"'; sPRIGUldbl='"LG"'; sPRIEUldbl='"LE"';
+			echo "We will use %Lf."
 			;;
 		esac
 	fi
@@ -7686,17 +8119,17 @@ if $test X"$sPRIfldbl" = X; then
 #include <stdio.h>
 int main() {
   long double d = 123.456;
-  printf("%.3Lf\n", d);
+  printf("%.3llf\n", d);
 }
 EOCP
 	set try
 	if eval $compile; then
-		yyy=`./try$exe_ext`
+		yyy=`$run ./try`
 		case "$yyy" in
 		123.456)
-			sPRIfldbl='"Lf"'; sPRIgldbl='"Lg"'; sPRIeldbl='"Le"';
-                	sPRIFUldbl='"LF"'; sPRIGUldbl='"LG"'; sPRIEUldbl='"LE"';
-			echo "We will use %Lf."
+			sPRIfldbl='"llf"'; sPRIgldbl='"llg"'; sPRIeldbl='"lle"';
+                	sPRIFUldbl='"llF"'; sPRIGUldbl='"llG"'; sPRIEUldbl='"llE"';
+			echo "We will use %llf."
 			;;
 		esac
 	fi
@@ -7713,7 +8146,7 @@ int main() {
 EOCP
 	set try
 	if eval $compile; then
-		yyy=`./try$exe_ext`
+		yyy=`$run ./try`
 		case "$yyy" in
 		123.456)
 			sPRIfldbl='"lf"'; sPRIgldbl='"lg"'; sPRIeldbl='"le"';
@@ -7746,6 +8179,9 @@ case "$sPRIfldbl" in
 esac
 
 : Check how to convert floats to strings.
+
+if test "X$d_Gconvert" = X; then
+
 echo " "
 echo "Checking for an efficient way to convert floats to strings."
 echo " " > try.c
@@ -7773,9 +8209,13 @@ char *myname = "qgcvt";
 #define DOUBLETYPE long double
 #endif
 #ifdef TRY_sprintf
-#if defined(USE_LONG_DOUBLE) && defined(HAS_LONG_DOUBLE) && defined(HAS_PRIgldbl)
+#if defined(USE_LONG_DOUBLE) && defined(HAS_LONG_DOUBLE)
+#ifdef HAS_PRIgldbl
 #define Gconvert(x,n,t,b) sprintf((b),"%.*"$sPRIgldbl,(n),(x))
 #else
+#define Gconvert(x,n,t,b) sprintf((b),"%.*g",(n),(double)(x))
+#endif
+#else
 #define Gconvert(x,n,t,b) sprintf((b),"%.*g",(n),(x))
 #endif
 char *myname = "sprintf";
@@ -7887,21 +8327,49 @@ int main()
 	exit(0);
 }
 EOP
-case "$d_Gconvert" in
-gconvert*) xxx_list='gconvert gcvt sprintf' ;;
-gcvt*) xxx_list='gcvt gconvert sprintf' ;;
-sprintf*) xxx_list='sprintf gconvert gcvt' ;;
-*) xxx_list='gconvert gcvt sprintf' ;;
-esac
-
-case "$d_longdbl$uselongdouble$d_PRIgldbl" in
-"$define$define$define")
-    # for long doubles prefer first qgcvt, then sprintf
-    xxx_list="`echo $xxx_list|sed s/sprintf//`" 
-    xxx_list="sprintf $xxx_list"
-    case "$d_qgcvt" in
-    "$define") xxx_list="qgcvt $xxx_list" ;;
+: first add preferred functions to our list
+xxx_list=""
+for xxx_convert in $gconvert_preference; do
+    case $xxx_convert in
+    gcvt|gconvert|sprintf) xxx_list="$xxx_list $xxx_convert" ;;
+    *) echo "Discarding unrecognized gconvert_preference $xxx_convert" >&4 ;;
+esac
+done
+: then add any others
+for xxx_convert in gconvert gcvt sprintf; do
+    case "$xxx_list" in
+    *$xxx_convert*) ;;
+    *) xxx_list="$xxx_list $xxx_convert" ;;
+esac
+done
+
+case "$d_longdbl$uselongdouble" in
+"$define$define")
+    : again, add prefered functions to our list first
+    xxx_ld_list=""
+    for xxx_convert in $gconvert_ld_preference; do
+        case $xxx_convert in
+        qgcvt|gcvt|gconvert|sprintf) xxx_ld_list="$xxx_ld_list $xxx_convert" ;;
+        *) echo "Discarding unrecognized gconvert_ld_preference $xxx_convert" ;;
+    esac
+    done
+    : then add qgcvt, sprintf--then, in xxx_list order, gconvert and gcvt
+    for xxx_convert in qgcvt sprintf $xxx_list; do
+        case "$xxx_ld_list" in
+        $xxx_convert*|*" $xxx_convert"*) ;;
+        *) xxx_ld_list="$xxx_ld_list $xxx_convert" ;;
     esac
+    done
+    : if sprintf cannot do long doubles, move it to the end
+    if test "$d_PRIgldbl" != "$define"; then
+        xxx_ld_list="`echo $xxx_ld_list|sed s/sprintf//` sprintf"
+    fi
+    : if no qgcvt, remove it
+    if test "$d_qgcvt" != "$define"; then
+        xxx_ld_list="`echo $xxx_ld_list|sed s/qgcvt//`"
+    fi
+    : use the ld_list
+    xxx_list="$xxx_ld_list"
     ;;
 esac
 
@@ -7911,17 +8379,24 @@ for xxx_convert in $xxx_list; do
 	set try -DTRY_$xxx_convert
 	if eval $compile; then
 		echo "$xxx_convert() found." >&4
-		if ./try; then
+		if $run ./try; then
 			echo "I'll use $xxx_convert to convert floats into a string." >&4
 			break;
 		else
 			echo "...But $xxx_convert didn't work as I expected."
+			xxx_convert=''
 		fi
 	else
 		echo "$xxx_convert NOT found." >&4
 	fi
 done
 	
+if test X$xxx_convert = X; then
+    echo "*** WHOA THERE!!! ***" >&4
+    echo "None of ($xxx_list)  seemed to work properly.  I'll use sprintf." >&4
+    xxx_convert=sprintf
+fi
+
 case "$xxx_convert" in
 gconvert) d_Gconvert='gconvert((x),(n),(t),(b))' ;;
 gcvt) d_Gconvert='gcvt((x),(n),(b))' ;;
@@ -7929,11 +8404,15 @@ qgcvt) d_Gconvert='qgcvt((x),(n),(b))' ;;
 *) case "$uselongdouble$d_longdbl$d_PRIgldbl" in
    "$define$define$define")
       d_Gconvert="sprintf((b),\"%.*\"$sPRIgldbl,(n),(x))" ;;
+   "$define$define$undef")
+      d_Gconvert='sprintf((b),"%.*g",(n),(double)(x))' ;;
    *) d_Gconvert='sprintf((b),"%.*g",(n),(x))' ;;
    esac
    ;;  
 esac
 
+fi
+
 : see if _fwalk exists
 set fwalk d__fwalk
 eval $inlibc
@@ -7952,7 +8431,7 @@ eval $inlibc
 case "$d_access" in
 "$define")
 	echo " "
-	$cat >access.c <<'EOCP'
+	$cat >access.c <<EOCP
 #include <sys/types.h>
 #ifdef I_FCNTL
 #include <fcntl.h>
@@ -7963,6 +8442,10 @@ case "$d_access" in
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
@@ -8007,7 +8490,7 @@ echo " "
 echo "Checking whether your compiler can handle __attribute__ ..." >&4
 $cat >attrib.c <<'EOCP'
 #include <stdio.h>
-void croak (char* pat,...) __attribute__((format(printf,1,2),noreturn));
+void croak (char* pat,...) __attribute__((__format__(__printf__,1,2),noreturn));
 EOCP
 if $cc $ccflags -c attrib.c >attrib.out 2>&1 ; then
 	if $contains 'warning' attrib.out >/dev/null 2>&1; then
@@ -8045,12 +8528,16 @@ case "$d_getpgrp" in
 "$define")
 	echo " "
 	echo "Checking to see which flavor of getpgrp is in use..."
-	$cat >set.c <<EOP
+	$cat >try.c <<EOP
 #$i_unistd I_UNISTD
 #include <sys/types.h>
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
@@ -8067,10 +8554,10 @@ int main()
 	exit(1);
 }
 EOP
-	if $cc -o set -DTRY_BSD_PGRP $ccflags $ldflags set.c $libs >/dev/null 2>&1 && ./set; then
+	if $cc -o try -DTRY_BSD_PGRP $ccflags $ldflags try.c $libs >/dev/null 2>&1 && $run ./try; then
 		echo "You have to use getpgrp(pid) instead of getpgrp()." >&4
 		val="$define"
-	elif $cc -o set $ccflags $ldflags set.c $libs >/dev/null 2>&1 && ./set; then
+	elif $cc -o try $ccflags $ldflags try.c $libs >/dev/null 2>&1 && $run ./try; then
 		echo "You have to use getpgrp() instead of getpgrp(pid)." >&4
 		val="$undef"
 	else
@@ -8097,7 +8584,7 @@ EOP
 esac
 set d_bsdgetpgrp
 eval $setvar
-$rm -f set set.c
+$rm -f try try.*
 
 : see if setpgrp exists
 set setpgrp d_setpgrp
@@ -8107,12 +8594,16 @@ case "$d_setpgrp" in
 "$define")
 	echo " "
 	echo "Checking to see which flavor of setpgrp is in use..."
-	$cat >set.c <<EOP
+	$cat >try.c <<EOP
 #$i_unistd I_UNISTD
 #include <sys/types.h>
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
@@ -8129,10 +8620,10 @@ int main()
 	exit(1);
 }
 EOP
-	if $cc -o set -DTRY_BSD_PGRP $ccflags $ldflags set.c $libs >/dev/null 2>&1 && ./set; then
+	if $cc -o try -DTRY_BSD_PGRP $ccflags $ldflags try.c $libs >/dev/null 2>&1 && $run ./try; then
 		echo 'You have to use setpgrp(pid,pgrp) instead of setpgrp().' >&4
 		val="$define"
-	elif $cc -o set $ccflags $ldflags set.c $libs >/dev/null 2>&1 && ./set; then
+	elif $cc -o try $ccflags $ldflags try.c $libs >/dev/null 2>&1 && $run ./try; then
 		echo 'You have to use setpgrp() instead of setpgrp(pid,pgrp).' >&4
 		val="$undef"
 	else
@@ -8159,7 +8650,7 @@ EOP
 esac
 set d_bsdsetpgrp
 eval $setvar
-$rm -f set set.c
+$rm -f try try.*
 : see if bzero exists
 set bzero d_bzero
 eval $inlibc
@@ -8218,6 +8709,10 @@ else
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
@@ -8249,7 +8744,7 @@ int main()
 EOCP
 set try
 if eval $compile_ok; then
-	./try
+	$run ./try
 	yyy=$?
 else
 	echo "(I can't seem to compile the test program--assuming it can't)"
@@ -8272,6 +8767,10 @@ echo " "
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
@@ -8345,7 +8844,7 @@ int main()
 EOCP
 set try
 if eval $compile_ok; then
-	./try
+	$run ./try
 	castflags=$?
 else
 	echo "(I can't seem to compile the test program--assuming it can't)"
@@ -8368,8 +8867,12 @@ echo " "
 if set vprintf val -f d_vprintf; eval $csym; $val; then
 	echo 'vprintf() found.' >&4
 	val="$define"
-	$cat >vprintf.c <<'EOF'
+	$cat >try.c <<EOF
 #include <varargs.h>
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
 
 int main() { xxx("foo"); }
 
@@ -8383,8 +8886,8 @@ va_dcl
 	exit((unsigned long)vsprintf(buf,"%s",args) > 10L);
 }
 EOF
-	set vprintf
-	if eval $compile && ./vprintf; then
+	set try
+	if eval $compile && $run ./try; then
 		echo "Your vsprintf() returns (int)." >&4
 		val2="$undef"
 	else
@@ -8396,6 +8899,7 @@ else
 		val="$undef"
 		val2="$undef"
 fi
+$rm -f try try.*
 set d_vprintf
 eval $setvar
 val=$val2
@@ -8437,7 +8941,11 @@ eval $setvar
 
 : see if crypt exists
 echo " "
-if set crypt val -f d_crypt; eval $csym; $val; then
+set crypt d_crypt
+eval $inlibc
+case "$d_crypt" in
+$define) cryptlib='' ;;
+*)	if set crypt val -f d_crypt; eval $csym; $val; then
 	echo 'crypt() found.' >&4
 	val="$define"
 	cryptlib=''
@@ -8467,6 +8975,8 @@ else
 fi
 set d_crypt
 eval $setvar
+	;;
+esac
 
 : get csh whereabouts
 case "$csh" in
@@ -8638,9 +9148,13 @@ EOM
 $cat >fred.c<<EOM
 
 #include <stdio.h>
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
 #$i_dlfcn I_DLFCN
 #ifdef I_DLFCN
-#include <dlfcn.h>      /* the dynamic linker include file for Sunos/Solaris */
+#include <dlfcn.h>      /* the dynamic linker include file for SunOS/Solaris */
 #else
 #include <sys/types.h>
 #include <nlist.h>
@@ -8684,9 +9198,9 @@ EOM
 	: Call the object file tmp-dyna.o in case dlext=o.
 	if $cc $ccflags $cccdlflags -c dyna.c > /dev/null 2>&1 && 
 		mv dyna${_o} tmp-dyna${_o} > /dev/null 2>&1 && 
-		$ld -o dyna.$dlext $lddlflags tmp-dyna${_o} > /dev/null 2>&1 && 
-		$cc -o fred $ccflags $ldflags $cccdlflags $ccdlflags fred.c $libs > /dev/null 2>&1; then
-		xxx=`./fred`
+		$ld -o dyna.$dlext $ldflags $lddlflags tmp-dyna${_o} > /dev/null 2>&1 && 
+		$cc -o fred $ccflags $ldflags $cccdlflags $ccdlflags fred.c $libs > /dev/null 2>&1 && $to dyna.$dlext; then
+		xxx=`$run ./fred`
 		case $xxx in
 		1)	echo "Test program failed using dlopen." >&4
 			echo "Perhaps you should not use dynamic loading." >&4;;
@@ -8703,7 +9217,7 @@ EOM
 	;;
 esac
 		
-$rm -f fred fred.? dyna.$dlext dyna.? tmp-dyna.?
+$rm -f fred fred.* dyna.$dlext dyna.* tmp-dyna.*
 
 set d_dlsymun
 eval $setvar
@@ -8766,7 +9280,7 @@ eval $inlibc
 
 : Locate the flags for 'open()'
 echo " "
-$cat >open3.c <<'EOCP'
+$cat >try.c <<EOCP
 #include <sys/types.h>
 #ifdef I_FCNTL
 #include <fcntl.h>
@@ -8774,6 +9288,10 @@ $cat >open3.c <<'EOCP'
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
@@ -8785,10 +9303,10 @@ int main() {
 EOCP
 : check sys/file.h first to get FREAD on Sun
 if $test `./findhdr sys/file.h` && \
-		set open3 -DI_SYS_FILE && eval $compile; then
+		set try -DI_SYS_FILE && eval $compile; then
 	h_sysfile=true;
 	echo "<sys/file.h> defines the O_* constants..." >&4
-	if ./open3; then
+	if $run ./try; then
 		echo "and you have the 3 argument form of open()." >&4
 		val="$define"
 	else
@@ -8796,10 +9314,10 @@ if $test `./findhdr sys/file.h` && \
 		val="$undef"
 	fi
 elif $test `./findhdr fcntl.h` && \
-		set open3 -DI_FCNTL && eval $compile; then
+		set try -DI_FCNTL && eval $compile; then
 	h_fcntl=true;
 	echo "<fcntl.h> defines the O_* constants..." >&4
-	if ./open3; then
+	if $run ./try; then
 		echo "and you have the 3 argument form of open()." >&4
 		val="$define"
 	else
@@ -8812,7 +9330,7 @@ else
 fi
 set d_open3
 eval $setvar
-$rm -f open3*
+$rm -f try try.*
 
 : see which of string.h or strings.h is needed
 echo " "
@@ -8826,15 +9344,44 @@ else
 	if $test "$strings" && $test -r "$strings"; then
 		echo "Using <strings.h> instead of <string.h>." >&4
 	else
-		echo "No string header found -- You'll surely have problems." >&4
+		echo "No string header found -- You'll surely have problems." >&4
+	fi
+fi
+set i_string
+eval $setvar
+case "$i_string" in
+"$undef") strings=`./findhdr strings.h`;;
+*)	  strings=`./findhdr string.h`;;
+esac
+
+: see if fcntl.h is there
+val=''
+set fcntl.h val
+eval $inhdr
+
+: see if we can include fcntl.h
+case "$val" in
+"$define")
+	echo " "
+	if $h_fcntl; then
+		val="$define"
+		echo "We'll be including <fcntl.h>." >&4
+	else
+		val="$undef"
+		if $h_sysfile; then
+	echo "We don't need to include <fcntl.h> if we include <sys/file.h>." >&4
+		else
+			echo "We won't be including <fcntl.h>." >&4
+		fi
 	fi
-fi
-set i_string
-eval $setvar
-case "$i_string" in
-"$undef") strings=`./findhdr strings.h`;;
-*)	  strings=`./findhdr string.h`;;
+	;;
+*)
+	h_fcntl=false
+	val="$undef"
+	;;
 esac
+set i_fcntl
+eval $setvar
 
 : check for non-blocking I/O stuff
 case "$h_sysfile" in
@@ -8851,8 +9398,16 @@ echo "Figuring out the flag used by open() for non-blocking I/O..." >&4
 case "$o_nonblock" in
 '')
 	$cat head.c > try.c
-	$cat >>try.c <<'EOCP'
+	$cat >>try.c <<EOCP
 #include <stdio.h>
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
+#$i_fcntl I_FCNTL
+#ifdef I_FCNTL
+#include <fcntl.h>
+#endif
 int main() {
 #ifdef O_NONBLOCK
 	printf("O_NONBLOCK\n");
@@ -8871,7 +9426,7 @@ int main() {
 EOCP
 	set try
 	if eval $compile_ok; then
-		o_nonblock=`./try`
+		o_nonblock=`$run ./try`
 		case "$o_nonblock" in
 		'') echo "I can't figure it out, assuming O_NONBLOCK will do.";;
 		*) echo "Seems like we can use $o_nonblock.";;
@@ -8894,6 +9449,14 @@ case "$eagain" in
 #include <sys/types.h>
 #include <signal.h>
 #include <stdio.h> 
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
+#$i_fcntl I_FCNTL
+#ifdef I_FCNTL
+#include <fcntl.h>
+#endif
 #define MY_O_NONBLOCK $o_nonblock
 #ifndef errno  /* XXX need better Configure test */
 extern int errno;
@@ -8954,7 +9517,7 @@ int main()
 		ret = read(pd[0], buf, 1);	/* Should read EOF */
 		alarm(0);
 		sprintf(string, "%d\n", ret);
-		write(3, string, strlen(string));
+		write(4, string, strlen(string));
 		exit(0);
 	}
 
@@ -8968,7 +9531,7 @@ EOCP
 	set try
 	if eval $compile_ok; then
 		echo "$startsh" >mtry
-		echo "./try >try.out 2>try.ret 3>try.err || exit 4" >>mtry
+		echo "$run ./try >try.out 2>try.ret 4>try.err || exit 4" >>mtry
 		chmod +x mtry
 		./mtry >/dev/null 2>&1
 		case $? in
@@ -9044,10 +9607,15 @@ eval $inlibc
 
 echo " "
 : See if fcntl-based locking works.
-$cat >try.c <<'EOCP'
+$cat >try.c <<EOCP
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
 #include <stdlib.h>
+#endif
 #include <unistd.h>
 #include <fcntl.h>
+#include <signal.h>
+$signal_t blech(x) int x; { exit(3); }
 int main() {
 #if defined(F_SETLK) && defined(F_SETLKW)
      struct flock flock;
@@ -9056,6 +9624,8 @@ int main() {
      flock.l_type = F_RDLCK;
      flock.l_whence = SEEK_SET;
      flock.l_start = flock.l_len = 0;
+     signal(SIGALRM, blech);
+     alarm(10);
      retval = fcntl(fd, F_SETLK, &flock);
      close(fd);
      (retval < 0 ? exit(2) : exit(0));
@@ -9069,12 +9639,24 @@ case "$d_fcntl" in
 "$define")
 	set try
 	if eval $compile_ok; then
-		if ./try; then
+		if $run ./try; then
 			echo "Yes, it seems to work."
 			val="$define"
 		else
 			echo "Nope, it didn't work."
 			val="$undef"
+			case "$?" in
+			3) $cat >&4 <<EOM
+***
+*** I had to forcibly timeout from fcntl(..., F_SETLK, ...).
+*** This is (almost) impossible.
+*** If your NFS lock daemons are not feeling well, something like
+*** this may happen, please investigate.  Cannot continue, aborting.
+***
+EOM
+				exit 1
+				;;
+			esac
 		fi
 	else
 		echo "I'm unable to compile the test program, so I'll assume not."
@@ -9147,7 +9729,7 @@ else
 							sockethdr="-I/usr/netinclude"
 							;;
 						esac
-						echo "Found Berkeley sockets interface in lib$net." >& 4 
+						echo "Found Berkeley sockets interface in lib$net." >&4 
 						if $contains setsockopt libc.list >/dev/null 2>&1; then
 							d_oldsock="$undef"
 						else
@@ -9173,7 +9755,7 @@ eval $inlibc
 
 
 echo " "
-echo "Checking the availability of certain socket constants..." >& 4
+echo "Checking the availability of certain socket constants..." >&4
 for ENUM in MSG_CTRUNC MSG_DONTROUTE MSG_OOB MSG_PEEK MSG_PROXY SCM_RIGHTS; do
 	enum=`$echo $ENUM|./tr '[A-Z]' '[a-z]'`
 	$cat >try.c <<EOF
@@ -9200,7 +9782,7 @@ echo " "
 if test "X$timeincl" = X; then
 	echo "Testing to see if we should include <time.h>, <sys/time.h> or both." >&4
 	$echo $n "I'm now running the test program...$c"
-	$cat >try.c <<'EOCP'
+	$cat >try.c <<EOCP
 #include <sys/types.h>
 #ifdef I_TIME
 #include <time.h>
@@ -9214,6 +9796,10 @@ if test "X$timeincl" = X; then
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
@@ -9284,7 +9870,11 @@ $cat <<EOM
 
 Checking to see how well your C compiler handles fd_set and friends ...
 EOM
-$cat >fd_set.c <<EOCP
+$cat >try.c <<EOCP
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
 #$i_systime I_SYS_TIME
 #$i_sysselct I_SYS_SELECT
 #$d_socket HAS_SOCKET
@@ -9312,12 +9902,12 @@ int main() {
 #endif
 }
 EOCP
-set fd_set -DTRYBITS
+set try -DTRYBITS
 if eval $compile; then
 	d_fds_bits="$define"
 	d_fd_set="$define"
 	echo "Well, your system knows about the normal fd_set typedef..." >&4
-	if ./fd_set; then
+	if $run ./try; then
 		echo "and you have the normal fd_set macros (just as I'd expect)." >&4
 		d_fd_macros="$define"
 	else
@@ -9330,12 +9920,12 @@ else
 	$cat <<'EOM'
 Hmm, your compiler has some difficulty with fd_set.  Checking further...
 EOM
-	set fd_set
+	set try
 	if eval $compile; then
 		d_fds_bits="$undef"
 		d_fd_set="$define"
 		echo "Well, your system has some sort of fd_set available..." >&4
-		if ./fd_set; then
+		if $run ./try; then
 			echo "and you have the normal fd_set macros." >&4
 			d_fd_macros="$define"
 		else
@@ -9351,7 +9941,7 @@ EOM
 		d_fd_macros="$undef"
 	fi
 fi
-$rm -f fd_set*
+$rm -f try try.*
 
 : see if fgetpos exists
 set fgetpos d_fgetpos
@@ -9879,9 +10469,13 @@ eval $setvar
 
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
@@ -10016,7 +10610,7 @@ int main()
 EOCP
 	set try
 	if eval $compile_ok; then
-		longlongsize=`./try$exe_ext`
+		longlongsize=`$run ./try`
 		echo "Your long longs are $longlongsize bytes long."
 	else
 		dflt='8'
@@ -10255,12 +10849,7 @@ case "$quadtype" in
 '')	echo "Alas, no 64-bit integer types in sight." >&4
 	d_quad="$undef"
 	;;
-*)	if test X"$use64bitint" = Xdefine -o X"$longsize" = X8; then
-	    verb="will"
-	else
-	    verb="could"
-	fi
-	echo "We $verb use '$quadtype' for 64-bit integers." >&4
+*)	echo "We could use '$quadtype' for 64-bit integers." >&4
 	d_quad="$define"
 	;;
 esac
@@ -10270,8 +10859,12 @@ echo " "
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
@@ -10280,7 +10873,7 @@ int main()
 EOCP
 	set try
 	if eval $compile_ok; then
-		dflt=`./try`
+		dflt=`$run ./try`
 	else
 		dflt='1'
 		echo "(I can't seem to compile the test program.  Guessing...)"
@@ -10396,7 +10989,7 @@ esac
 case "$i8type" in
 '')	set try -DINT8
 	if eval $compile; then
-		case "`./try$exe_ext`" in
+		case "`$run ./try`" in
 		int8_t)	i8type=int8_t
 			u8type=uint8_t
 			i8size=1
@@ -10429,7 +11022,7 @@ esac
 case "$i16type" in
 '')	set try -DINT16
 	if eval $compile; then
-		case "`./try$exe_ext`" in
+		case "`$run ./try`" in
 		int16_t)
 			i16type=int16_t
 			u16type=uint16_t
@@ -10471,7 +11064,7 @@ esac
 case "$i32type" in
 '')	set try -DINT32
 	if eval $compile; then
-		case "`./try$exe_ext`" in
+		case "`$run ./try`" in
 		int32_t)
 			i32type=int32_t
 			u32type=uint32_t
@@ -10511,6 +11104,10 @@ if test X"$d_volatile" = X"$define"; then
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
@@ -10550,18 +11147,18 @@ set try
 
 d_nv_preserves_uv="$undef"
 if eval $compile; then
-	d_nv_preserves_uv_bits="`./try$exe_ext`"
+	nv_preserves_uv_bits="`$run ./try`"
 fi
-case "$d_nv_preserves_uv_bits" in
+case "$nv_preserves_uv_bits" in
 \-[1-9]*)	
-	d_nv_preserves_uv_bits=`expr 0 - $d_nv_preserves_uv_bits`
-	$echo "Your NVs can preserve all $d_nv_preserves_uv_bits bits of your UVs."  2>&1
+	nv_preserves_uv_bits=`expr 0 - $nv_preserves_uv_bits`
+	$echo "Your NVs can preserve all $nv_preserves_uv_bits bits of your UVs."  2>&1
 	d_nv_preserves_uv="$define"
 	;;
-[1-9]*)	$echo "Your NVs can preserve only $d_nv_preserves_uv_bits bits of your UVs."  2>&1
+[1-9]*)	$echo "Your NVs can preserve only $nv_preserves_uv_bits bits of your UVs."  2>&1
 	d_nv_preserves_uv="$undef" ;;
 *)	$echo "Can't figure out how many bits your NVs preserve." 2>&1
-	d_nv_preserves_uv_bits="$undef" ;;
+	nv_preserves_uv_bits="$undef" ;;
 esac
 
 $rm -f try.* try
@@ -11064,7 +11661,7 @@ exit(0);
 EOCP
 	set try
 	if eval $compile_ok; then
-		if ./try 2>/dev/null; then
+		if $run ./try 2>/dev/null; then
 			echo "Yes, it can."
 			val="$define"
 		else
@@ -11233,7 +11830,7 @@ END
     val="$undef"
     set try
     if eval $compile; then
-	xxx=`./try`
+	xxx=`$run ./try`
         case "$xxx" in
         semun) val="$define" ;;
         esac
@@ -11291,7 +11888,7 @@ END
     val="$undef"
     set try
     if eval $compile; then
-        xxx=`./try`
+        xxx=`$run ./try`
         case "$xxx" in
         semid_ds) val="$define" ;;
         esac
@@ -11558,10 +12155,14 @@ echo " "
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
@@ -11589,8 +12190,12 @@ $rm -f try try$_o try.c
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
@@ -11604,7 +12209,7 @@ int main()
 EOP
 	set try
 	if eval $compile; then
-		if ./try >/dev/null 2>&1; then
+		if $run ./try >/dev/null 2>&1; then
 			echo "POSIX sigsetjmp found." >&4
 			val="$define"
 		else
@@ -11753,6 +12358,10 @@ fi
 echo "Checking how std your stdio is..." >&4
 $cat >try.c <<EOP
 #include <stdio.h>
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
 #define FILE_ptr(fp)	$stdio_ptr
 #define FILE_cnt(fp)	$stdio_cnt
 int main() {
@@ -11768,8 +12377,8 @@ int main() {
 EOP
 val="$undef"
 set try
-if eval $compile; then
-	if ./try; then
+if eval $compile && $to try.c; then
+	if $run ./try; then
 		echo "Your stdio acts pretty std."
 		val="$define"
 	else
@@ -11779,6 +12388,26 @@ else
 	echo "Your stdio doesn't appear very std."
 fi
 $rm -f try.c try
+
+# glibc 2.2.90 and above apparently change stdio streams so Perl's
+# direct buffer manipulation no longer works.  The Configure tests
+# should be changed to correctly detect this, but until then,
+# the following check should at least let perl compile and run.
+# (This quick fix should be updated before 5.8.1.)
+# To be defensive, reject all unknown versions, and all versions  > 2.2.9.
+# A. Dougherty, June 3, 2002.
+case "$d_gnulibc" in
+$define)
+	case "$gnulibc_version" in
+	2.[01]*)  ;;
+	2.2) ;;
+	2.2.[0-9]) ;;
+	*)  echo "But I will not snoop inside glibc $gnulibc_version stdio buffers."
+		val="$undef"
+		;;
+	esac
+	;;
+esac
 set d_stdstdio
 eval $setvar
 
@@ -11810,6 +12439,10 @@ $cat >try.c <<EOP
 /* Can we scream? */
 /* Eat dust sed :-) */
 /* In the buffer space, no one can hear you scream. */
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
 #define FILE_ptr(fp)	$stdio_ptr
 #define FILE_cnt(fp)	$stdio_cnt
 #include <sys/types.h>
@@ -11865,8 +12498,8 @@ int main() {
 }
 EOP
 	set try
-	if eval $compile; then
- 		case `./try$exe_ext` in
+	if eval $compile && $to try.c; then
+ 		case `$run ./try` in
 		Pass_changed)
 			echo "Increasing ptr in your stdio decreases cnt by the same amount.  Good." >&4
 			d_stdio_ptr_lval_sets_cnt="$define" ;;
@@ -11891,6 +12524,10 @@ case "$d_stdstdio" in
 $define)
 	$cat >try.c <<EOP
 #include <stdio.h>
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
 #define FILE_base(fp)	$stdio_base
 #define FILE_bufsiz(fp)	$stdio_bufsiz
 int main() {
@@ -11905,8 +12542,8 @@ int main() {
 }
 EOP
 	set try
-	if eval $compile; then
-		if ./try; then
+	if eval $compile && $to try.c; then
+		if $run ./try; then
 			echo "And its _base field acts std."
 			val="$define"
 		else
@@ -11936,7 +12573,7 @@ EOCP
 	do
 	        set try -DSTDIO_STREAM_ARRAY=$s
 		if eval $compile; then
-		    	case "`./try$exe_ext`" in
+		    	case "`$run ./try`" in
 			yes)	stdio_stream_array=$s; break ;;
 			esac
 		fi
@@ -12078,7 +12715,7 @@ int main() {
 EOCP
 	set try
 	if eval $compile; then
-		yyy=`./try`
+		yyy=`$run ./try`
 		case "$yyy" in
 		ok) echo "Your strtoll() seems to be working okay." ;;
 		*) cat <<EOM >&4
@@ -12133,7 +12770,7 @@ int main() {
 EOCP
 	set try
 	if eval $compile; then
-		case "`./try`" in
+		case "`$run ./try`" in
 		ok) echo "Your strtoull() seems to be working okay." ;;
 		*) cat <<EOM >&4
 Your strtoull() doesn't seem to be working okay.
@@ -12149,6 +12786,54 @@ esac
 set strtouq d_strtouq
 eval $inlibc
 
+case "$d_strtouq" in
+"$define")
+	$cat <<EOM
+Checking whether your strtouq() works okay...
+EOM
+	$cat >try.c <<'EOCP'
+#include <errno.h>
+#include <stdio.h>
+extern unsigned long long int strtouq(char *s, char **, int); 
+static int bad = 0;
+void check(char *s, unsigned long long eull, int een) {
+	unsigned long long gull;
+	errno = 0;
+	gull = strtouq(s, 0, 10);
+	if (!((gull == eull) && (errno == een)))
+		bad++;
+}
+int main() {
+	check(" 1",                                        1LL, 0);
+	check(" 0",                                        0LL, 0);
+	check("18446744073709551615",  18446744073709551615ULL, 0);
+	check("18446744073709551616",  18446744073709551615ULL, ERANGE);
+#if 0 /* strtouq() for /^-/ strings is undefined. */
+	check("-1",                    18446744073709551615ULL, 0);
+	check("-18446744073709551614",                     2LL, 0);
+	check("-18446744073709551615",                     1LL, 0);
+       	check("-18446744073709551616", 18446744073709551615ULL, ERANGE);
+	check("-18446744073709551617", 18446744073709551615ULL, ERANGE);
+#endif
+	if (!bad)
+		printf("ok\n");
+	return 0;
+}
+EOCP
+	set try
+	if eval $compile; then
+		case "`$run ./try`" in
+		ok) echo "Your strtouq() seems to be working okay." ;;
+		*) cat <<EOM >&4
+Your strtouq() doesn't seem to be working okay.
+EOM
+		   d_strtouq="$undef"
+		   ;;
+		esac
+	fi
+	;;
+esac
+
 : see if strxfrm exists
 set strxfrm d_strxfrm
 eval $inlibc
@@ -12290,7 +12975,7 @@ case "$d_closedir" in
 "$define")
 	echo " "
 	echo "Checking whether closedir() returns a status..." >&4
-	cat > closedir.c <<EOM
+	cat > try.c <<EOM
 #$i_dirent I_DIRENT		/**/
 #$i_sysdir I_SYS_DIR		/**/
 #$i_sysndir I_SYS_NDIR		/**/
@@ -12319,9 +13004,9 @@ case "$d_closedir" in
 #endif 
 int main() { return closedir(opendir(".")); }
 EOM
-	set closedir
+	set try
 	if eval $compile_ok; then
-		if ./closedir > /dev/null 2>&1 ; then
+		if $run ./try > /dev/null 2>&1 ; then
 			echo "Yes, it does."
 			val="$undef"
 		else
@@ -12339,7 +13024,7 @@ EOM
 esac
 set d_void_closedir
 eval $setvar
-$rm -f closedir*
+$rm -f try try.*
 : see if there is a wait4
 set wait4 d_wait4
 eval $inlibc
@@ -12413,7 +13098,7 @@ int main()
 EOCP
 		set try
 		if eval $compile_ok; then
-			dflt=`./try`
+			dflt=`$run ./try`
 		else
 			dflt='8'
 			echo "(I can't seem to compile the test program...)"
@@ -12433,16 +13118,16 @@ esac
 : set the base revision
 baserev=5.0
 
-: check for ordering of bytes in a long
+: check for ordering of bytes in a UV
 echo " "
-case "$crosscompile$multiarch" in
+case "$usecrosscompile$multiarch" in
 *$define*)
 	$cat <<EOM
 You seem to be either cross-compiling or doing a multiarchitecture build,
 skipping the byteorder check.
 
 EOM
-	byteorder='0xffff'
+	byteorder='ffff'
 	;;
 *)
 	case "$byteorder" in
@@ -12456,21 +13141,27 @@ an Alpha will report 12345678. If the test program works the default is
 probably right.
 I'm now running the test program...
 EOM
-		$cat >try.c <<'EOCP'
+		$cat >try.c <<EOCP
 #include <stdio.h>
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
+#include <sys/types.h>
+typedef $uvtype UV;
 int main()
 {
 	int i;
 	union {
-		unsigned long l;
-		char c[sizeof(long)];
+		UV l;
+		char c[$uvsize];
 	} u;
 
-	if (sizeof(long) > 4)
-		u.l = (0x08070605L << 32) | 0x04030201L;
+	if ($uvsize > 4)
+		u.l = (((UV)0x08070605) << 32) | (UV)0x04030201;
 	else
-		u.l = 0x04030201L;
-	for (i = 0; i < sizeof(long); i++)
+		u.l = (UV)0x04030201;
+	for (i = 0; i < $uvsize; i++)
 		printf("%c", u.c[i]+'0');
 	printf("\n");
 	exit(0);
@@ -12479,7 +13170,7 @@ EOCP
 		xxx_prompt=y
 		set try
 		if eval $compile && ./try > /dev/null; then
-			dflt=`./try`
+			dflt=`$run ./try`
 			case "$dflt" in
 			[1-4][1-4][1-4][1-4]|12345678|87654321)
 				echo "(The test program ran ok.)"
@@ -12497,7 +13188,7 @@ EOM
 		fi
 		case "$xxx_prompt" in
 		y)
-			rp="What is the order of bytes in a long?"
+			rp="What is the order of bytes in $uvtype?"
 			. ./myread
 			byteorder="$ans"
 			;;
@@ -12555,8 +13246,12 @@ $define)
 #endif
 #include <sys/types.h>
 #include <stdio.h>
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
 #include <db3/db.h>
-int main()
+int main(int argc, char *argv[])
 {
 #ifdef DB_VERSION_MAJOR	/* DB version >= 2 */
     int Major, Minor, Patch ;
@@ -12571,11 +13266,11 @@ int main()
 
     /* check that db.h & libdb are compatible */
     if (DB_VERSION_MAJOR != Major || DB_VERSION_MINOR != Minor || DB_VERSION_PATCH != Patch) {
-	printf("db.h and libdb are incompatible\n") ;
+	printf("db.h and libdb are incompatible.\n") ;
         exit(3);	
     }
 
-    printf("db.h and libdb are compatible\n") ;
+    printf("db.h and libdb are compatible.\n") ;
 
     Version = DB_VERSION_MAJOR * 1000000 + DB_VERSION_MINOR * 1000
 		+ DB_VERSION_PATCH ;
@@ -12715,7 +13410,11 @@ echo " "
 echo "Checking to see how well your C compiler groks the void type..." >&4
 case "$voidflags" in
 '')
-	$cat >try.c <<'EOCP'
+	$cat >try.c <<EOCP
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
 #if TRY & 1
 void sub() {
 #else
@@ -12935,7 +13634,7 @@ done
 
 echo " "
 echo "Determining whether or not we are on an EBCDIC system..." >&4
-$cat >tebcdic.c <<'EOM'
+$cat >try.c <<'EOM'
 int main()
 {
   if ('M'==0xd4) return 0;
@@ -12944,19 +13643,19 @@ int main()
 EOM
 
 val=$undef
-set tebcdic
+set try
 if eval $compile_ok; then
-	if ./tebcdic; then
+	if $run ./try; then
 		echo "You seem to speak EBCDIC." >&4
 		val="$define"
 	else
-		echo "Nope, no EBCDIC, probably ASCII or some ISO Latin. Or UTF8." >&4
+		echo "Nope, no EBCDIC, probably ASCII or some ISO Latin. Or UTF-8." >&4
 	fi
 else
 	echo "I'm unable to compile the test program." >&4
 	echo "I'll assume ASCII or some ISO Latin. Or UTF8." >&4
 fi
-$rm -f tebcdic.c tebcdic
+$rm -f try try.*
 set ebcdic
 eval $setvar
 
@@ -12971,6 +13670,10 @@ sunos) $echo '#define PERL_FFLUSH_ALL_FOPEN_MAX 32' > try.c ;;
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
@@ -12981,7 +13684,9 @@ $cat >>try.c <<EOCP
 # define STDIO_STREAM_ARRAY $stdio_stream_array
 #endif
 int main() {
-  FILE* p = fopen("try.out", "w");
+  FILE* p;
+  unlink("try.out");
+  p = fopen("try.out", "w");
 #ifdef TRY_FPUTC
   fputc('x', p);
 #else
@@ -13030,24 +13735,26 @@ int main() {
 }
 EOCP
 : first we have to find out how _not_ to flush
+$to try.c
 if $test "X$fflushNULL" = X -o "X$fflushall" = X; then
     output=''
     set try -DTRY_FPUTC
     if eval $compile; then
-	    $rm -f try.out
- 	    ./try$exe_ext 2>/dev/null
-	    if $test ! -s try.out -a "X$?" = X42; then
+ 	    $run ./try 2>/dev/null
+	    code="$?"
+	    $from try.out
+	    if $test ! -s try.out -a "X$code" = X42; then
 		output=-DTRY_FPUTC
 	    fi
     fi
     case "$output" in
     '')
 	    set try -DTRY_FPRINTF
-	    $rm -f try.out
 	    if eval $compile; then
-		    $rm -f try.out
- 		    ./try$exe_ext 2>/dev/null
-		    if $test ! -s try.out -a "X$?" = X42; then
+ 		    $run ./try 2>/dev/null
+		    code="$?"
+		    $from try.out
+		    if $test ! -s try.out -a "X$code" = X42; then
 			output=-DTRY_FPRINTF
 		    fi
 	    fi
@@ -13058,9 +13765,9 @@ fi
 case "$fflushNULL" in
 '') 	set try -DTRY_FFLUSH_NULL $output
 	if eval $compile; then
-	        $rm -f try.out
-	    	./try$exe_ext 2>/dev/null
+	    	$run ./try 2>/dev/null
 		code="$?"
+		$from try.out
 		if $test -s try.out -a "X$code" = X42; then
 			fflushNULL="`$cat try.out`"
 		else
@@ -13106,7 +13813,7 @@ EOCP
                 set tryp
                 if eval $compile; then
                     $rm -f tryp.out
-                    $cat tryp.c | ./tryp$exe_ext 2>/dev/null > tryp.out
+                    $cat tryp.c | $run ./tryp 2>/dev/null > tryp.out
                     if cmp tryp.c tryp.out >/dev/null 2>&1; then
                        $cat >&4 <<EOM
 fflush(NULL) seems to behave okay with input streams.
@@ -13170,7 +13877,7 @@ EOCP
 	set tryp
 	if eval $compile; then
 	    $rm -f tryp.out
-	    $cat tryp.c | ./tryp$exe_ext 2>/dev/null > tryp.out
+	    $cat tryp.c | $run ./tryp 2>/dev/null > tryp.out
 	    if cmp tryp.c tryp.out >/dev/null 2>&1; then
 	       $cat >&4 <<EOM
 Good, at least fflush(stdin) seems to behave okay when stdin is a pipe.
@@ -13182,9 +13889,10 @@ EOM
 				$cat >&4 <<EOM
 (Now testing the other method--but note that this also may fail.)
 EOM
-				$rm -f try.out
-				./try$exe_ext 2>/dev/null
-				if $test -s try.out -a "X$?" = X42; then
+				$run ./try 2>/dev/null
+				code=$?
+				$from try.out
+				if $test -s try.out -a "X$code" = X42; then
 					fflushall="`$cat try.out`"
 				fi
 			fi
@@ -13282,6 +13990,10 @@ echo "Checking the size of $zzz..." >&4
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
@@ -13289,7 +14001,7 @@ int main() {
 EOCP
 set try
 if eval $compile_ok; then
-	yyy=`./try`
+	yyy=`$run ./try`
 	case "$yyy" in
 	'')	gidsize=4
 		echo "(I can't execute the test program--guessing $gidsize.)" >&4
@@ -13323,7 +14035,7 @@ int main() {
 EOCP
 set try
 if eval $compile; then
-	yyy=`./try`
+	yyy=`$run ./try`
 	case "$yyy" in
 	'')	gidsign=1
 		echo "(I can't execute the test program--guessing unsigned.)" >&4
@@ -13358,7 +14070,7 @@ int main() {
 EOCP
 	set try
 	if eval $compile; then
-		yyy=`./try$exe_ext`
+		yyy=`$run ./try`
 		case "$yyy" in
 		12345678901)
 			sPRId64='"d"'; sPRIi64='"i"'; sPRIu64='"u"';
@@ -13380,7 +14092,7 @@ int main() {
 EOCP
 	set try
 	if eval $compile; then
-		yyy=`./try$exe_ext`
+		yyy=`$run ./try`
 		case "$yyy" in
 		12345678901)
 			sPRId64='"ld"'; sPRIi64='"li"'; sPRIu64='"lu"';
@@ -13403,7 +14115,7 @@ int main() {
 EOCP
 	set try
 	if eval $compile; then
-		yyy=`./try$exe_ext`
+		yyy=`$run ./try`
 		case "$yyy" in
 		12345678901)
 			sPRId64=PRId64; sPRIi64=PRIi64; sPRIu64=PRIu64;
@@ -13414,45 +14126,45 @@ EOCP
 	fi
 fi
 
-if $test X"$sPRId64" = X -a X"$quadtype" = X"long long"; then
-	$cat >try.c <<'EOCP'
+if $test X"$sPRId64" = X -a X"$quadtype" != X; then
+	$cat >try.c <<EOCP
 #include <sys/types.h>
 #include <stdio.h>
 int main() {
-  long long q = 12345678901LL; /* AIX cc requires the LL suffix. */
-  printf("%lld\n", q);
+  $quadtype q = 12345678901;
+  printf("%Ld\n", q);
 }
 EOCP
 	set try
 	if eval $compile; then
-		yyy=`./try$exe_ext`
+		yyy=`$run ./try`
 		case "$yyy" in
 		12345678901)
-			sPRId64='"lld"'; sPRIi64='"lli"'; sPRIu64='"llu"';
-                	sPRIo64='"llo"'; sPRIx64='"llx"'; sPRIXU64='"llX"';
-			echo "We will use the %lld style."
+			sPRId64='"Ld"'; sPRIi64='"Li"'; sPRIu64='"Lu"';
+                	sPRIo64='"Lo"'; sPRIx64='"Lx"'; sPRIXU64='"LX"';
+			echo "We will use %Ld."
 			;;
 		esac
 	fi
 fi
 
-if $test X"$sPRId64" = X -a X"$quadtype" != X; then
-	$cat >try.c <<EOCP
+if $test X"$sPRId64" = X -a X"$quadtype" = X"long long"; then
+	$cat >try.c <<'EOCP'
 #include <sys/types.h>
 #include <stdio.h>
 int main() {
-  $quadtype q = 12345678901;
-  printf("%Ld\n", q);
+  long long q = 12345678901LL; /* AIX cc requires the LL suffix. */
+  printf("%lld\n", q);
 }
 EOCP
 	set try
 	if eval $compile; then
-		yyy=`./try$exe_ext`
+		yyy=`$run ./try`
 		case "$yyy" in
 		12345678901)
-			sPRId64='"Ld"'; sPRIi64='"Li"'; sPRIu64='"Lu"';
-                	sPRIo64='"Lo"'; sPRIx64='"Lx"'; sPRIXU64='"LX"';
-			echo "We will use %Ld."
+			sPRId64='"lld"'; sPRIi64='"lli"'; sPRIu64='"llu"';
+                	sPRIo64='"llo"'; sPRIx64='"llx"'; sPRIXU64='"llX"';
+			echo "We will use the %lld style."
 			;;
 		esac
 	fi
@@ -13469,7 +14181,7 @@ int main() {
 EOCP
 	set try
 	if eval $compile; then
-		yyy=`./try$exe_ext`
+		yyy=`$run ./try`
 		case "$yyy" in
 		12345678901)
 			sPRId64='"qd"'; sPRIi64='"qi"'; sPRIu64='"qu"';
@@ -13551,7 +14263,7 @@ else
 fi
 
 case "$ivdformat" in
-'') echo "$0: Fatal: failed to find format strings, cannot continue." >& 4
+'') echo "$0: Fatal: failed to find format strings, cannot continue." >&4
     exit 1
     ;;
 esac
@@ -13874,8 +14586,12 @@ case "$ptrsize" in
 	else
 		echo '#define VOID_PTR void *' > try.c
 	fi
-	$cat >>try.c <<'EOCP'
+	$cat >>try.c <<EOCP
 #include <stdio.h>
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
 int main()
 {
     printf("%d\n", (int)sizeof(VOID_PTR));
@@ -13884,7 +14600,7 @@ int main()
 EOCP
 	set try
 	if eval $compile_ok; then
-		ptrsize=`./try`
+		ptrsize=`$run ./try`
 		echo "Your pointers are $ptrsize bytes long."
 	else
 		dflt='4'
@@ -13897,12 +14613,44 @@ EOCP
 esac
 $rm -f try.c try
 
+case "$use64bitall" in
+"$define"|true|[yY]*)
+	case "$ptrsize" in
+	4)	cat <<EOM >&4
+
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
+
+EOM
+
+		exit 1
+		;;
+	esac
+	;;
+esac
+
+
 : see if ar generates random libraries by itself
 echo " "
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
@@ -13910,13 +14658,13 @@ $cc $ccflags -c bar2.c >/dev/null 2>&1
 $cc $ccflags -c foo.c >/dev/null 2>&1
 $ar rc bar$_a bar2$_o bar1$_o >/dev/null 2>&1
 if $cc -o foobar $ccflags $ldflags foo$_o bar$_a $libs > /dev/null 2>&1 &&
-	./foobar >/dev/null 2>&1; then
+	$run ./foobar >/dev/null 2>&1; then
 	echo "$ar appears to generate random libraries itself."
 	orderlib=false
 	ranlib=":"
 elif $ar ts bar$_a >/dev/null 2>&1 &&
 	$cc -o foobar $ccflags $ldflags foo$_o bar$_a $libs > /dev/null 2>&1 &&
-	./foobar >/dev/null 2>&1; then
+	$run ./foobar >/dev/null 2>&1; then
 		echo "a table of contents needs to be added with '$ar ts'."
 		orderlib=false
 		ranlib="$ar ts"
@@ -13992,7 +14740,8 @@ esac
 
 : check for the select 'width'
 case "$selectminbits" in
-'') case "$d_select" in
+'') safebits=`expr $ptrsize \* 8`
+    case "$d_select" in
 	$define)
 		$cat <<EOM
 
@@ -14024,25 +14773,31 @@ EOM
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
@@ -14050,20 +14805,21 @@ int main() {
     t.tv_usec = 0;
     select(fd + 1, b, 0, 0, &t);
     for (i = NBITS - 1; i > fd && FD_ISSET(i, b); i--);
+    free(s);
     printf("%d\n", i + 1);
     return 0;
 }
 EOCP
 		set try
 		if eval $compile_ok; then
-			selectminbits=`./try`
+			selectminbits=`$run ./try`
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
@@ -14072,7 +14828,8 @@ EOM
 		else
 			rp='What is the minimum number of bits your select() operates on?'
 			case "$byteorder" in
-			1234|12345678)	dflt=32 ;;
+			12345678)	dflt=64 ;;
+			1234)		dflt=32 ;;
 			*)		dflt=1	;;
 			esac
 			. ./myread
@@ -14082,7 +14839,7 @@ EOM
 		$rm -f try.* try
 		;;
 	*)	: no select, so pick a harmless default
-		selectminbits='32'
+		selectminbits=$safebits
 		;;
 	esac
 	;;
@@ -14101,7 +14858,7 @@ else
 	xxx=`echo '#include <signal.h>' |
 	$cppstdin $cppminus $cppflags 2>/dev/null |
 	$grep '^[ 	]*#.*include' | 
-	$awk "{print \\$$fieldn}" | $sed 's!"!!g' | $sort | $uniq`
+	$awk "{print \\$$fieldn}" | $sed 's!"!!g' | $sed 's!\\\\\\\\!/!g' | $sort | $uniq`
 fi
 : Check this list of files to be sure we have parsed the cpp output ok.
 : This will also avoid potentially non-existent files, such 
@@ -14129,9 +14886,13 @@ xxx="$xxx SYS TERM THAW TRAP TSTP TTIN TTOU URG USR1 USR2"
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
 
@@ -14206,7 +14967,7 @@ END {
 $cat >signal.awk <<'EOP'
 BEGIN { ndups = 0 }
 $1 ~ /^NSIG$/ { nsig = $2 }
-($1 !~ /^NSIG$/) && (NF == 2) {
+($1 !~ /^NSIG$/) && (NF == 2) && ($2 ~ /^[0-9][0-9]*$/) {
     if ($2 > maxsig) { maxsig = $2 }
     if (sig_name[$2]) {
 	dup_name[ndups] = $1
@@ -14248,13 +15009,13 @@ $cat >>signal_cmd <<'EOS'
 
 set signal
 if eval $compile_ok; then
-	./signal$_exe | ($sort -n -k 2 2>/dev/null || $sort -n +1) | $uniq | $awk -f signal.awk >signal.lst
+	$run ./signal$_exe | ($sort -n -k 2 2>/dev/null || $sort -n +1) | $uniq | $awk -f signal.awk >signal.lst
 else
 	echo "(I can't seem be able to compile the whole test program)" >&4
 	echo "(I'll try it in little pieces.)" >&4
 	set signal -DJUST_NSIG
 	if eval $compile_ok; then
-		./signal$_exe > signal.nsg
+		$run ./signal$_exe > signal.nsg
 		$cat signal.nsg
 	else
 		echo "I can't seem to figure out how many signals you have." >&4
@@ -14275,14 +15036,14 @@ EOCP
 		set signal
 		if eval $compile; then
 			echo "SIG${xx} found."
-			./signal$_exe  >> signal.ls1
+			$run ./signal$_exe  >> signal.ls1
 		else
 			echo "SIG${xx} NOT found."
 		fi
 	done
 	if $test -s signal.ls1; then
 		$cat signal.nsg signal.ls1 |
-			($sort -n -k 2 2>/dev/null || $sort -n +1) | $uniq | $awk -f signal.awk >signal.lst
+			$sort -n | $uniq | $awk -f signal.awk >signal.lst
 	fi
 
 fi
@@ -14358,6 +15119,10 @@ echo "Checking the size of $zzz..." >&4
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
@@ -14365,7 +15130,7 @@ int main() {
 EOCP
 set try
 if eval $compile_ok; then
-	yyy=`./try`
+	yyy=`$run ./try`
 	case "$yyy" in
 	'')	sizesize=4
 		echo "(I can't execute the test program--guessing $sizesize.)" >&4
@@ -14459,8 +15224,12 @@ esac
 set ssize_t ssizetype int stdio.h sys/types.h
 eval $typedef
 dflt="$ssizetype"
-$cat > ssize.c <<EOM
+$cat > try.c <<EOM
 #include <stdio.h>
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
 #include <sys/types.h>
 #define Size_t $sizetype
 #define SSize_t $dflt
@@ -14476,9 +15245,9 @@ int main()
 }
 EOM
 echo " "
-set ssize
-if eval $compile_ok && ./ssize > /dev/null; then
-	ssizetype=`./ssize`
+set try
+if eval $compile_ok && $run ./try > /dev/null; then
+	ssizetype=`$run ./try`
 	echo "I'll be using $ssizetype for functions returning a byte count." >&4
 else
 	$cat >&4 <<EOM
@@ -14494,7 +15263,7 @@ EOM
 	. ./myread
 	ssizetype="$ans"
 fi
-$rm -f ssize ssize.*
+$rm -f try try.*
 
 : see what type of char stdio uses.
 echo " "
@@ -14559,6 +15328,10 @@ echo "Checking the size of $zzz..." >&4
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
@@ -14566,7 +15339,7 @@ int main() {
 EOCP
 set try
 if eval $compile_ok; then
-	yyy=`./try`
+	yyy=`$run ./try`
 	case "$yyy" in
 	'')	uidsize=4
 		echo "(I can't execute the test program--guessing $uidsize.)" >&4
@@ -14599,7 +15372,7 @@ int main() {
 EOCP
 set try
 if eval $compile; then
-	yyy=`./try`
+	yyy=`$run ./try`
 	case "$yyy" in
 	'')	uidsign=1
 		echo "(I can't execute the test program--guessing unsigned.)" >&4
@@ -14665,11 +15438,11 @@ case "$yacc" in
 esac
 echo " "
 comp='yacc'
-if $test -f "$byacc"; then
+if $test -f "$byacc$_exe"; then
 	dflt="$byacc"
 	comp="byacc or $comp"
 fi
-if $test -f "$bison"; then
+if $test -f "$bison$_exe"; then
 	comp="$comp or bison -y"
 fi
 rp="Which compiler compiler ($comp) shall I use?"
@@ -14807,6 +15580,20 @@ eval $inhdr
 : see if ndbm.h is available
 set ndbm.h t_ndbm
 eval $inhdr
+
+case "$t_ndbm" in
+$undef)
+    # Some Linux distributions such as RedHat 7.1 put the
+    # ndbm.h header in /usr/include/gdbm/ndbm.h.
+    if $test -f /usr/include/gdbm/ndbm.h; then
+	echo '<gdbm/ndbm.h> found.'
+        ccflags="$ccflags -I/usr/include/gdbm"
+        cppflags="$cppflags -I/usr/include/gdbm"
+        t_ndbm=$define
+    fi
+    ;;
+esac
+
 case "$t_ndbm" in
 $define)
 	: see if dbm_open exists
@@ -14964,12 +15751,12 @@ $awk \\
 EOSH
 cat <<'EOSH' >> Cppsym.try
 'length($1) > 0 {
-    printf "#ifdef %s\n#if %s+0\nprintf(\"%s=%%ld\\n\", %s);\n#else\nprintf(\"%s\\n\");\n#endif\n#endif\n", $1, $1, $1, $1, $1
-    printf "#ifdef _%s\n#if _%s+0\nprintf(\"_%s=%%ld\\n\", _%s);\n#else\nprintf(\"_%s\\n\");\n#endif\n#endif\n", $1, $1, $1, $1, $1
-    printf "#ifdef __%s\n#if __%s+0\nprintf(\"__%s=%%ld\\n\", __%s);\n#else\nprintf(\"__%s\\n\");\n#endif\n#endif\n", $1, $1, $1, $1, $1
-    printf "#ifdef __%s__\n#if __%s__+0\nprintf(\"__%s__=%%ld\\n\", __%s__);\n#else\nprintf(\"__%s__\\n\");\n#endif\n#endif\n", $1, $1, $1, $1, $1
+    printf "#ifdef %s\n#if %s+0\nprintf(\"%s=%%ld\\n\", (long)%s);\n#else\nprintf(\"%s\\n\");\n#endif\n#endif\n", $1, $1, $1, $1, $1
+    printf "#ifdef _%s\n#if _%s+0\nprintf(\"_%s=%%ld\\n\", (long)_%s);\n#else\nprintf(\"_%s\\n\");\n#endif\n#endif\n", $1, $1, $1, $1, $1
+    printf "#ifdef __%s\n#if __%s+0\nprintf(\"__%s=%%ld\\n\", (long)__%s);\n#else\nprintf(\"__%s\\n\");\n#endif\n#endif\n", $1, $1, $1, $1, $1
+    printf "#ifdef __%s__\n#if __%s__+0\nprintf(\"__%s__=%%ld\\n\", (long)__%s__);\n#else\nprintf(\"__%s__\\n\");\n#endif\n#endif\n", $1, $1, $1, $1, $1
 }'	 >> try.c
-echo '}' >> try.c
+echo 'return 0;}' >> try.c
 EOSH
 cat <<EOSH >> Cppsym.try
 ccflags="$ccflags"
@@ -14977,7 +15764,7 @@ case "$osname-$gccversion" in
 irix-) ccflags="\$ccflags -woff 1178" ;;
 os2-*) ccflags="\$ccflags -Zlinker /PM:VIO" ;;
 esac
-$cc -o try $optimize \$ccflags $ldflags try.c $libs && ./try$exe_ext
+$cc -o try $optimize \$ccflags $ldflags try.c $libs && $run ./try
 EOSH
 chmod +x Cppsym.try
 $eunicefix Cppsym.try
@@ -14996,7 +15783,7 @@ for i in \`$cc -v -c tmp.c 2>&1 $postprocess_cc_v\`
 do
 	case "\$i" in
 	-D*) echo "\$i" | $sed 's/^-D//';;
-	-A*) $test "$gccversion" && echo "\$i" | $sed 's/^-A\(.*\)(\(.*\))/\1=\2/';;
+	-A*) $test "$gccversion" && echo "\$i" | $sed 's/^-A//' | $sed 's/\(.*\)(\(.*\))/\1=\2/';;
 	esac
 done
 $rm -f try.c
@@ -15356,7 +16143,7 @@ find_extensions='
            else
                if $test -d $xxx -a $# -lt 10; then
                    set $1$xxx/ $*;
-                   cd $xxx;
+                   cd "$xxx";
                    eval $find_extensions;
                    cd ..;
                    shift;
@@ -15366,17 +16153,21 @@ find_extensions='
        esac;
     done'
 tdir=`pwd`
-cd $rsrc/ext
+cd "$rsrc/ext"
 set X
 shift
 eval $find_extensions
+# Special case:  Add in threads/shared since it is not picked up by the
+# recursive find above (and adding in general recursive finding breaks
+# SDBM_File/sdbm).  A.D.  10/25/2001.
+known_extensions="$known_extensions threads/shared"
 set X $nonxs_extensions
 shift
 nonxs_extensions="$*"
 set X $known_extensions
 shift
 known_extensions="$*"
-cd $tdir
+cd "$tdir"
 
 : Now see which are supported on this system.
 avail_ext=''
PATCH
        return;
    }

    _patch(<<'PATCH');
--- Configure
+++ Configure
@@ -944,6 +944,21 @@ if test -f /etc/unixtovms.exe; then
 	eunicefix=/etc/unixtovms.exe
 fi
 
+: Set executable suffix now -- needed before hints available
+if test -f "/libs/version.library"; then
+: Amiga OS
+    _exe=""
+elif test -f "/system/gnu_library/bin/ar.pm"; then
+: Stratus VOS
+    _exe=".pm"
+elif test -n "$DJGPP"; then
+: DOS DJGPP
+    _exe=".exe"
+elif test -d c:/. ; then
+: OS/2 or cygwin
+    _exe=".exe"
+fi
+
 i_whoami=''
 : set useposix=false in your hint file to disable the POSIX extension.
 useposix=true
@@ -1024,6 +1039,9 @@ case "$sh" in
 			if test -f "$xxx"; then
 				sh="$xxx";
 				break
+			elif test "X$_exe" != X -a -f "$xxx$_exe"; then
+				sh="$xxx";
+				break
 			elif test -f "$xxx.exe"; then
 				sh="$xxx";
 				break
@@ -1034,7 +1052,7 @@ case "$sh" in
 esac
 
 case "$sh" in
-'')	cat <<EOM >&2
+'')	cat >&2 <<EOM
 $me:  Fatal Error:  I can't find a Bourne Shell anywhere.  
 
 Usually it's in /bin/sh.  How did you even get this far?
@@ -1050,18 +1068,30 @@ if `$sh -c '#' >/dev/null 2>&1`; then
 	shsharp=true
 	spitshell=cat
 	xcat=/bin/cat
-	test -f $xcat || xcat=/usr/bin/cat
-	echo "#!$xcat" >try
-	$eunicefix try
-	chmod +x try
-	./try > today
+	test -f $xcat$_exe || xcat=/usr/bin/cat
+	if test ! -f $xcat$_exe; then
+		for p in `echo $PATH | sed -e "s/$p_/ /g"` $paths; do
+			if test -f $p/cat$_exe; then
+				xcat=$p/cat
+				break
+			fi
+		done
+		if test ! -f $xcat$_exe; then
+			echo "Can't find cat anywhere!"
+			exit 1
+		fi
+	fi
+	echo "#!$xcat" >sharp
+	$eunicefix sharp
+	chmod +x sharp
+	./sharp > today
 	if test -s today; then
 		sharpbang='#!'
 	else
-		echo "#! $xcat" > try
-		$eunicefix try
-		chmod +x try
-		./try > today
+		echo "#! $xcat" > sharp
+		$eunicefix sharp
+		chmod +x sharp
+		./sharp > today
 		if test -s today; then
 			sharpbang='#! '
 		else
@@ -1081,28 +1111,28 @@ else
 	echo "I presume that if # doesn't work, #! won't work either!"
 	sharpbang=': use '
 fi
-rm -f try today
+rm -f sharp today
 
 : figure out how to guarantee sh startup
 case "$startsh" in
 '') startsh=${sharpbang}${sh} ;;
 *)
 esac
-cat >try <<EOSS
+cat >sharp <<EOSS
 $startsh
 set abc
 test "$?abc" != 1
 EOSS
 
-chmod +x try
-$eunicefix try
-if ./try; then
+chmod +x sharp
+$eunicefix sharp
+if ./sharp; then
 	: echo "Yup, it does."
 else
 	echo "Hmm... '$startsh' does not guarantee sh startup..."
 	echo "You may have to fix up the shell scripts to make sure $sh runs them."
 fi
-rm -f try
+rm -f sharp
 
 
 : Save command line options in file UU/cmdline.opt for later use in
@@ -1114,12 +1144,24 @@ config_args='$*'
 config_argc=$#
 EOSH
 argn=1
+args_exp=''
+args_sep=''
 for arg in "$@"; do
 	cat >>cmdline.opt <<EOSH
 config_arg$argn='$arg'
 EOSH
+	# Extreme backslashitis: replace each ' by '"'"'
+	cat <<EOC | sed -e "s/'/'"'"'"'"'"'"'/g" > cmdl.opt
+$arg
+EOC
+	arg_exp=`cat cmdl.opt`
+	args_exp="$args_exp$args_sep'$arg_exp'"
 	argn=`expr $argn + 1`
+	args_sep=' '
 done
+# args_exp is good for restarting self: eval "set X $args_exp"; shift; $0 "$@"
+# used by ./hints/os2.sh
+rm -f cmdl.opt
 
 : produce awk script to parse command line options
 cat >options.awk <<'EOF'
@@ -1337,12 +1379,17 @@ esac
 case "$fastread$alldone" in
 yescont|yesexit) ;;
 *)
+	case "$extractsh" in
+	true) ;;
+	*)
 	if test ! -t 0; then
 		echo "Say 'sh Configure', not 'sh <Configure'"
 		exit 1
 	fi
 	;;
 esac
+	;;
+esac
 
 exec 4>&1
 case "$silent" in
@@ -1391,6 +1438,7 @@ case "$src" in
     */*) src=`echo $0 | sed -e 's%/[^/][^/]*$%%'`
          case "$src" in
 	 /*)	;;
+	 .)	;;
          *)	src=`cd ../$src && pwd` ;;
 	 esac
          ;;
@@ -1476,7 +1524,7 @@ for file in $*; do
 		*/*)
 			dir=`expr X$file : 'X\(.*\)/'`
 			file=`expr X$file : 'X.*/\(.*\)'`
-			(cd $dir && . ./$file)
+			(cd "$dir" && . ./$file)
 			;;
 		*)
 			. ./$file
@@ -1489,19 +1537,19 @@ for file in $*; do
 			dir=`expr X$file : 'X\(.*\)/'`
 			file=`expr X$file : 'X.*/\(.*\)'`
 			(set x $dir; shift; eval $mkdir_p)
-			sh <$src/$dir/$file
+			sh <"$src/$dir/$file"
 			;;
 		*)
-			sh <$src/$file
+			sh <"$src/$file"
 			;;
 		esac
 		;;
 	esac
 done
-if test -f $src/config_h.SH; then
+if test -f "$src/config_h.SH"; then
 	if test ! -f config.h; then
 	: oops, they left it out of MANIFEST, probably, so do it anyway.
-	. $src/config_h.SH
+	. "$src/config_h.SH"
 	fi
 fi
 EOS
@@ -1557,13 +1605,13 @@ rm -f .echotmp
 
 : Now test for existence of everything in MANIFEST
 echo " "
-if test -f $rsrc/MANIFEST; then
+if test -f "$rsrc/MANIFEST"; then
 	echo "First let's make sure your kit is complete.  Checking..." >&4
-	awk '$1 !~ /PACK[A-Z]+/ {print $1}' $rsrc/MANIFEST | split -50
+	awk '$1 !~ /PACK[A-Z]+/ {print $1}' "$rsrc/MANIFEST" | (split -l 50 2>/dev/null || split -50)
 	rm -f missing
 	tmppwd=`pwd`
 	for filelist in x??; do
-		(cd $rsrc; ls `cat $tmppwd/$filelist` >/dev/null 2>>$tmppwd/missing)
+		(cd "$rsrc"; ls `cat "$tmppwd/$filelist"` >/dev/null 2>>"$tmppwd/missing")
 	done
 	if test -s missing; then
 		cat missing >&4
@@ -1612,6 +1660,11 @@ if test X"$trnl" = X; then
 	foox) trnl='\012' ;;
 	esac
 fi
+if test X"$trnl" = X; then
+       case "`echo foo|tr '\r\n' xy 2>/dev/null`" in
+       fooxy) trnl='\n\r' ;;
+       esac
+fi
 if test X"$trnl" = X; then
 	cat <<EOM >&2
 
@@ -1917,7 +1970,7 @@ for file in $loclist; do
 	'') xxx=`./loc $file $file $pth`;;
 	*) xxx=`./loc $xxx $xxx $pth`;;
 	esac
-	eval $file=$xxx
+	eval $file=$xxx$_exe
 	eval _$file=$xxx
 	case "$xxx" in
 	/*)
@@ -1950,7 +2003,7 @@ for file in $trylist; do
 	'') xxx=`./loc $file $file $pth`;;
 	*) xxx=`./loc $xxx $xxx $pth`;;
 	esac
-	eval $file=$xxx
+	eval $file=$xxx$_exe
 	eval _$file=$xxx
 	case "$xxx" in
 	/*)
@@ -2020,6 +2073,97 @@ FOO
 	;;
 esac
 
+cat <<EOS >trygcc
+$startsh
+EOS
+cat <<'EOSC' >>trygcc
+case "$cc" in
+'') ;;
+*)  $rm -f try try.*
+    $cat >try.c <<EOM
+int main(int argc, char *argv[]) {
+  return 0;
+}
+EOM
+    if $cc -o try $ccflags $ldflags try.c; then
+       :
+    else
+        echo "Uh-oh, the C compiler '$cc' doesn't seem to be working." >&4
+        despair=yes
+        trygcc=yes
+        case "$cc" in
+        *gcc*) trygcc=no ;;
+        esac
+        case "`$cc -v -c try.c 2>&1`" in
+        *gcc*) trygcc=no ;;
+        esac
+        if $test X"$trygcc" = Xyes; then
+            if gcc -o try -c try.c; then
+                echo " "
+                echo "You seem to have a working gcc, though." >&4
+                rp="Would you like to use it?"
+                dflt=y
+                if $test -f myread; then
+                    . ./myread
+                else
+                    if $test -f UU/myread; then
+                        . ./UU/myread
+                    else
+                        echo "Cannot find myread, sorry.  Aborting." >&2
+                        exit 1
+                    fi
+                fi  
+                case "$ans" in
+                [yY]*) cc=gcc; ccname=gcc; ccflags=''; despair=no;
+                       if $test -f usethreads.cbu; then
+                           $cat >&4 <<EOM 
+
+*** However, any setting of the C compiler flags (e.g. for thread support)
+*** has been lost.  It may be necessary to pass -Dcc=gcc to Configure
+*** (together with e.g. -Dusethreads).
+
+EOM
+                       fi;;
+                esac
+            fi
+        fi
+    fi
+    $rm -f try try.*
+    ;;
+esac
+EOSC
+
+cat <<EOS >checkcc
+$startsh
+EOS
+cat <<'EOSC' >>checkcc
+case "$cc" in        
+'') ;;
+*)  $rm -f try try.*              
+    $cat >try.c <<EOM
+int main(int argc, char *argv[]) {
+  return 0;
+}
+EOM
+    if $cc -o try $ccflags $ldflags try.c; then
+       :
+    else
+        if $test X"$despair" = Xyes; then
+           echo "Uh-oh, the C compiler '$cc' doesn't seem to be working." >&4
+        fi
+	    $cat >&4 <<EOM
+You need to find a working C compiler.
+Either (purchase and) install the C compiler supplied by your OS vendor,
+or for a free C compiler try http://gcc.gnu.org/
+I cannot continue any further, aborting.
+EOM
+            exit 1
+        fi
+    $rm -f try try.*
+    ;;
+esac
+EOSC
+
 : determine whether symbolic links are supported
 echo " "
 $touch blurfl
@@ -2032,6 +2176,250 @@ else
 fi
 $rm -f blurfl sym
 
+
+case "$usecrosscompile" in
+$define|true|[yY]*)
+	$echo "Cross-compiling..."
+        croak=''
+    	case "$cc" in
+	*-*-gcc) # A cross-compiling gcc, probably.
+	    targetarch=`$echo $cc|$sed 's/-gcc$//'`
+	    ar=$targetarch-ar
+	    # leave out ld, choosing it is more complex
+	    nm=$targetarch-nm
+	    ranlib=$targetarch-ranlib
+	    $echo 'extern int foo;' > try.c
+	    set X `$cc -v -E try.c 2>&1 | $awk '/^#include </,/^End of search /'|$grep '/include'`
+	    shift
+            if $test $# -gt 0; then
+	        incpth="$incpth $*"
+		incpth="`$echo $incpth|$sed 's/^ //'`"
+                echo "Guessing incpth '$incpth'." >&4
+                for i in $*; do
+		    j="`$echo $i|$sed 's,/include$,/lib,'`"
+		    if $test -d $j; then
+			libpth="$libpth $j"
+		    fi
+                done   
+		libpth="`$echo $libpth|$sed 's/^ //'`"
+                echo "Guessing libpth '$libpth'." >&4
+	    fi
+	    $rm -f try.c
+	    ;;
+	esac
+	case "$targetarch" in
+	'') echo "Targetarch not defined." >&4; croak=y ;;
+        *)  echo "Using targetarch $targetarch." >&4 ;;
+	esac
+	case "$incpth" in
+	'') echo "Incpth not defined." >&4; croak=y ;;
+        *)  echo "Using incpth '$incpth'." >&4 ;;
+	esac
+	case "$libpth" in
+	'') echo "Libpth not defined." >&4; croak=y ;;
+        *)  echo "Using libpth '$libpth'." >&4 ;;
+	esac
+	case "$usrinc" in
+	'') for i in $incpth; do
+	        if $test -f $i/errno.h -a -f $i/stdio.h -a -f $i/time.h; then
+		    usrinc=$i
+	            echo "Guessing usrinc $usrinc." >&4
+		    break
+		fi
+	    done
+	    case "$usrinc" in
+	    '') echo "Usrinc not defined." >&4; croak=y ;;
+	    esac
+            ;;
+        *)  echo "Using usrinc $usrinc." >&4 ;;
+	esac
+	case "$targethost" in
+	'') echo "Targethost not defined." >&4; croak=y ;;
+        *)  echo "Using targethost $targethost." >&4
+	esac
+	locincpth=' '
+	loclibpth=' '
+	case "$croak" in
+	y) echo "Cannot continue, aborting." >&4; exit 1 ;;
+	esac
+	case "$src" in
+	/*) run=$src/Cross/run
+	    targetmkdir=$src/Cross/mkdir
+	    to=$src/Cross/to
+	    from=$src/Cross/from
+	    ;;
+	*)  pwd=`$test -f ../Configure & cd ..; pwd`
+	    run=$pwd/Cross/run
+	    targetmkdir=$pwd/Cross/mkdir
+	    to=$pwd/Cross/to
+	    from=$pwd/Cross/from
+	    ;;
+	esac
+	case "$targetrun" in
+	'') targetrun=ssh ;;
+	esac
+	case "$targetto" in
+	'') targetto=scp ;;
+	esac
+	case "$targetfrom" in
+	'') targetfrom=scp ;;
+	esac
+    	run=$run-$targetrun
+    	to=$to-$targetto
+    	from=$from-$targetfrom
+	case "$targetdir" in
+	'')  targetdir=/tmp
+             echo "Guessing targetdir $targetdir." >&4
+             ;;
+	esac
+	case "$targetuser" in
+	'')  targetuser=root
+             echo "Guessing targetuser $targetuser." >&4
+             ;;
+	esac
+	case "$targetfrom" in
+	scp)	q=-q ;;
+	*)	q='' ;;
+	esac
+	case "$targetrun" in
+	ssh|rsh)
+	    cat >$run <<EOF
+#!/bin/sh
+case "\$1" in
+-cwd)
+  shift
+  cwd=\$1
+  shift
+  ;;
+esac
+case "\$cwd" in
+'') cwd=$targetdir ;;
+esac
+exe=\$1
+shift
+if $test ! -f \$exe.xok; then
+  $to \$exe
+  $touch \$exe.xok
+fi
+$targetrun -l $targetuser $targethost "cd \$cwd && ./\$exe \$@"
+EOF
+	    ;;
+	*)  echo "Unknown targetrun '$targetrun'" >&4
+	    exit 1
+	    ;;
+	esac
+	case "$targetmkdir" in
+	*/Cross/mkdir)
+	    cat >$targetmkdir <<EOF
+#!/bin/sh
+$targetrun -l $targetuser $targethost "mkdir -p \$@"
+EOF
+	    $chmod a+rx $targetmkdir
+	    ;;
+	*)  echo "Unknown targetmkdir '$targetmkdir'" >&4
+	    exit 1
+	    ;;
+	esac
+	case "$targetto" in
+	scp|rcp)
+	    cat >$to <<EOF
+#!/bin/sh
+for f in \$@
+do
+  case "\$f" in
+  /*)
+    $targetmkdir \`dirname \$f\`
+    $targetto $q \$f $targetuser@$targethost:\$f            || exit 1
+    ;;
+  *)
+    $targetmkdir $targetdir/\`dirname \$f\`
+    $targetto $q \$f $targetuser@$targethost:$targetdir/\$f || exit 1
+    ;;
+  esac
+done
+exit 0
+EOF
+	    ;;
+	cp) cat >$to <<EOF
+#!/bin/sh
+for f in \$@
+do
+  case "\$f" in
+  /*)
+    $mkdir -p $targetdir/\`dirname \$f\`
+    $cp \$f $targetdir/\$f || exit 1
+    ;;
+  *)
+    $targetmkdir $targetdir/\`dirname \$f\`
+    $cp \$f $targetdir/\$f || exit 1
+    ;;
+  esac
+done
+exit 0
+EOF
+	    ;;
+	*)  echo "Unknown targetto '$targetto'" >&4
+	    exit 1
+	    ;;
+	esac
+	case "$targetfrom" in
+	scp|rcp)
+	  cat >$from <<EOF
+#!/bin/sh
+for f in \$@
+do
+  $rm -f \$f
+  $targetfrom $q $targetuser@$targethost:$targetdir/\$f . || exit 1
+done
+exit 0
+EOF
+	    ;;
+	cp) cat >$from <<EOF
+#!/bin/sh
+for f in \$@
+do
+  $rm -f \$f
+  cp $targetdir/\$f . || exit 1
+done
+exit 0
+EOF
+	    ;;
+	*)  echo "Unknown targetfrom '$targetfrom'" >&4
+	    exit 1
+	    ;;
+	esac
+	if $test ! -f $run; then
+	    echo "Target 'run' script '$run' not found." >&4
+	else
+	    $chmod a+rx $run
+	fi
+	if $test ! -f $to; then
+	    echo "Target 'to' script '$to' not found." >&4
+	else
+	    $chmod a+rx $to
+	fi
+	if $test ! -f $from; then
+	    echo "Target 'from' script '$from' not found." >&4
+	else
+	    $chmod a+rx $from
+	fi
+	if $test ! -f $run -o ! -f $to -o ! -f $from; then
+	    exit 1
+	fi
+	cat >&4 <<EOF
+Using '$run' for remote execution,
+and '$from' and '$to'
+for remote file transfer.
+EOF
+	;;
+*)	run=''
+	to=:
+	from=:
+	usecrosscompile='undef'
+	targetarch=''
+	;;
+esac
+
 : see whether [:lower:] and [:upper:] are supported character classes
 echo " "
 case "`echo AbyZ | $tr '[:lower:]' '[:upper:]' 2>/dev/null`" in
@@ -2134,7 +2522,10 @@ if test -f config.sh; then
 	rp="I see a config.sh file.  Shall I use it to set the defaults?"
 	. UU/myread
 	case "$ans" in
-	n*|N*) echo "OK, I'll ignore it."; mv config.sh config.sh.old;;
+	n*|N*) echo "OK, I'll ignore it."
+		mv config.sh config.sh.old
+		myuname="$newmyuname"
+		;;
 	*)  echo "Fetching default answers from your old config.sh file..." >&4
 		tmp_n="$n"
 		tmp_c="$c"
@@ -2298,6 +2689,10 @@ EOM
 			esac
 			;;
 		next*) osname=next ;;
+		nonstop-ux) osname=nonstopux ;;
+		openbsd) osname=openbsd
+                	osvers="$3"
+                	;;
 		POSIX-BC | posix-bc ) osname=posix-bc
 			osvers="$3"
 			;;
@@ -2491,7 +2886,7 @@ EOM
 		elif $test -f $src/hints/$file.sh; then
 			. $src/hints/$file.sh
 			$cat $src/hints/$file.sh >> UU/config.sh
-		elif $test X$tans = X -o X$tans = Xnone ; then
+		elif $test X"$tans" = X -o X"$tans" = Xnone ; then
 			: nothing
 		else
 			: Give one chance to correct a possible typo.
@@ -2937,7 +3332,7 @@ if test -f /osf_boot || $contains 'OSF/1' /usr/include/ctype.h >/dev/null 2>&1
 then
 	echo "Looks kind of like an OSF/1 system, but we'll see..."
 	echo exit 0 >osf1
-elif test `echo abc | tr a-z A-Z` = Abc ; then
+elif test `echo abc | $tr a-z A-Z` = Abc ; then
 	xxx=`./loc addbib blurfl $pth`
 	if $test -f $xxx; then
 	echo "Looks kind of like a USG system with BSD features, but we'll see..."
@@ -3063,9 +3458,11 @@ fi
 if $test -f cc.cbu; then
     . ./cc.cbu
 fi
+. ./checkcc
+
 echo " "
 echo "Checking for GNU cc in disguise and/or its version number..." >&4
-$cat >gccvers.c <<EOM
+$cat >try.c <<EOM
 #include <stdio.h>
 int main() {
 #ifdef __GNUC__
@@ -3075,14 +3472,15 @@ int main() {
 	printf("%s\n", "1");
 #endif
 #endif
-	exit(0);
+	return(0);
 }
 EOM
-if $cc $ldflags -o gccvers gccvers.c; then
-	gccversion=`./gccvers`
+if $cc -o try $ccflags $ldflags try.c; then
+	gccversion=`$run ./try`
 	case "$gccversion" in
 	'') echo "You are not using GNU cc." ;;
 	*)  echo "You are using GNU cc $gccversion."
+	    ccname=gcc	
 		;;
 	esac
 else
@@ -3096,88 +3494,272 @@ else
 		;;
 	esac
 fi
-$rm -f gccvers*
+$rm -f try try.*
 case "$gccversion" in
 1.*) cpp=`./loc gcc-cpp $cpp $pth` ;;
 esac
+case "$gccversion" in
+'') gccosandvers='' ;;
+*) gccshortvers=`echo "$gccversion"|sed 's/ .*//'`
+   gccosandvers=`$cc -v 2>&1|grep '/specs$'|sed "s!.*/[^-/]*-[^-/]*-\([^-/]*\)/$gccshortvers/specs!\1!"`
+   gccshortvers=''
+   case "$gccosandvers" in
+   $osname) gccosandvers='' ;; # linux gccs seem to have no linux osvers, grr
+   $osname$osvers) ;; # looking good
+   $osname*) cat <<EOM >&4
+
+*** WHOA THERE!!! ***
+
+    Your gcc has not been compiled for the exact release of
+    your operating system ($gccosandvers versus $osname$osvers).
+
+    In general it is a good idea to keep gcc synchronized with
+    the operating system because otherwise serious problems
+    may ensue when trying to compile software, like Perl.
+
+    I'm trying to be optimistic here, though, and will continue.
+    If later during the configuration and build icky compilation
+    problems appear (headerfile conflicts being the most common
+    manifestation), I suggest reinstalling the gcc to match
+    your operating system release.
 
-: decide how portable to be.  Allow command line overrides.
-case "$d_portable" in
-"$undef") ;;
-*)	d_portable="$define" ;;
+EOM
+      ;;
+   *) gccosandvers='' ;; # failed to parse, better be silent
+   esac
+   ;;
+esac
+case "$ccname" in
+'') ccname="$cc" ;;
 esac
 
-: set up shell script to do ~ expansion
-cat >filexp <<EOSS
-$startsh
-: expand filename
-case "\$1" in
- ~/*|~)
-	echo \$1 | $sed "s|~|\${HOME-\$LOGDIR}|"
-	;;
- ~*)
-	if $test -f /bin/csh; then
-		/bin/csh -f -c "glob \$1"
-		failed=\$?
-		echo ""
-		exit \$failed
+: see how we invoke the C preprocessor
+echo " "
+echo "Now, how can we feed standard input to your C preprocessor..." >&4
+cat <<'EOT' >testcpp.c
+#define ABC abc
+#define XYZ xyz
+ABC.XYZ
+EOT
+cd ..
+if test ! -f cppstdin; then
+	if test "X$osname" = "Xaix" -a "X$gccversion" = X; then
+		# AIX cc -E doesn't show the absolute headerfile
+		# locations but we'll cheat by using the -M flag.
+		echo 'cat >.$$.c; rm -f .$$.u; '"$cc"' ${1+"$@"} -M -c .$$.c 2>/dev/null; test -s .$$.u && awk '"'"'$2 ~ /\.h$/ { print "# 0 \""$2"\"" }'"'"' .$$.u; rm -f .$$.o .$$.u; '"$cc"' -E ${1+"$@"} .$$.c; rm .$$.c' > cppstdin
 	else
-		name=\`$expr x\$1 : '..\([^/]*\)'\`
-		dir=\`$sed -n -e "/^\${name}:/{s/^[^:]*:[^:]*:[^:]*:[^:]*:[^:]*:\([^:]*\).*"'\$'"/\1/" -e p -e q -e '}' </etc/passwd\`
-		if $test ! -d "\$dir"; then
-			me=\`basename \$0\`
-			echo "\$me: can't locate home directory for: \$name" >&2
-			exit 1
-		fi
-		case "\$1" in
-		*/*)
-			echo \$dir/\`$expr x\$1 : '..[^/]*/\(.*\)'\`
-			;;
-		*)
-			echo \$dir
-			;;
-		esac
+		echo 'cat >.$$.c; '"$cc"' -E ${1+"$@"} .$$.c; rm .$$.c' >cppstdin
 	fi
-	;;
-*)
-	echo \$1
-	;;
-esac
-EOSS
-chmod +x filexp
-$eunicefix filexp
-
-: now set up to get a file name
-cat <<EOS >getfile
-$startsh
-EOS
-cat <<'EOSC' >>getfile
-tilde=''
-fullpath=''
-already=''
-skip=''
-none_ok=''
-exp_file=''
-nopath_ok=''
-orig_rp="$rp"
-orig_dflt="$dflt"
-case "$gfpth" in
-'') gfpth='.' ;;
-esac
+else
+	echo "Keeping your $hint cppstdin wrapper."
+fi
+chmod 755 cppstdin
+wrapper=`pwd`/cppstdin
+ok='false'
+cd UU
 
-case "$fn" in
-*\(*)
-	expr $fn : '.*(\(.*\)).*' | tr ',' $trnl >getfile.ok
-	fn=`echo $fn | sed 's/(.*)//'`
-	;;
-esac
+if $test "X$cppstdin" != "X" && \
+	$cppstdin $cppminus <testcpp.c >testcpp.out 2>&1 && \
+	$contains 'abc.*xyz' testcpp.out >/dev/null 2>&1
+then
+	echo "You used to use $cppstdin $cppminus so we'll use that again."
+	case "$cpprun" in
+	'') echo "But let's see if we can live without a wrapper..." ;;
+	*)
+		if $cpprun $cpplast <testcpp.c >testcpp.out 2>&1 && \
+			$contains 'abc.*xyz' testcpp.out >/dev/null 2>&1
+		then
+			echo "(And we'll use $cpprun $cpplast to preprocess directly.)"
+			ok='true'
+		else
+			echo "(However, $cpprun $cpplast does not work, let's see...)"
+		fi
+		;;
+	esac
+else
+	case "$cppstdin" in
+	'') ;;
+	*)
+		echo "Good old $cppstdin $cppminus does not seem to be of any help..."
+		;;
+	esac
+fi
 
-case "$fn" in
-*:*)
-	loc_file=`expr $fn : '.*:\(.*\)'`
-	fn=`expr $fn : '\(.*\):.*'`
-	;;
-esac
+if $ok; then
+	: nothing
+elif echo 'Maybe "'"$cc"' -E" will work...'; \
+	$cc -E <testcpp.c >testcpp.out 2>&1; \
+	$contains 'abc.*xyz' testcpp.out >/dev/null 2>&1 ; then
+	echo "Yup, it does."
+	x_cpp="$cc -E"
+	x_minus='';
+elif echo 'Nope...maybe "'"$cc"' -E -" will work...'; \
+	$cc -E - <testcpp.c >testcpp.out 2>&1; \
+	$contains 'abc.*xyz' testcpp.out >/dev/null 2>&1 ; then
+	echo "Yup, it does."
+	x_cpp="$cc -E"
+	x_minus='-';
+elif echo 'Nope...maybe "'"$cc"' -P" will work...'; \
+	$cc -P <testcpp.c >testcpp.out 2>&1; \
+	$contains 'abc.*xyz' testcpp.out >/dev/null 2>&1 ; then
+	echo "Yipee, that works!"
+	x_cpp="$cc -P"
+	x_minus='';
+elif echo 'Nope...maybe "'"$cc"' -P -" will work...'; \
+	$cc -P - <testcpp.c >testcpp.out 2>&1; \
+	$contains 'abc.*xyz' testcpp.out >/dev/null 2>&1 ; then
+	echo "At long last!"
+	x_cpp="$cc -P"
+	x_minus='-';
+elif echo 'No such luck, maybe "'$cpp'" will work...'; \
+	$cpp <testcpp.c >testcpp.out 2>&1; \
+	$contains 'abc.*xyz' testcpp.out >/dev/null 2>&1 ; then
+	echo "It works!"
+	x_cpp="$cpp"
+	x_minus='';
+elif echo 'Nixed again...maybe "'$cpp' -" will work...'; \
+	$cpp - <testcpp.c >testcpp.out 2>&1; \
+	$contains 'abc.*xyz' testcpp.out >/dev/null 2>&1 ; then
+	echo "Hooray, it works!  I was beginning to wonder."
+	x_cpp="$cpp"
+	x_minus='-';
+elif echo 'Uh-uh.  Time to get fancy.  Trying a wrapper...'; \
+	$wrapper <testcpp.c >testcpp.out 2>&1; \
+	$contains 'abc.*xyz' testcpp.out >/dev/null 2>&1 ; then
+	x_cpp="$wrapper"
+	x_minus=''
+	echo "Eureka!"
+else
+	dflt=''
+	rp="No dice.  I can't find a C preprocessor.  Name one:"
+	. ./myread
+	x_cpp="$ans"
+	x_minus=''
+	$x_cpp <testcpp.c >testcpp.out 2>&1
+	if $contains 'abc.*xyz' testcpp.out >/dev/null 2>&1 ; then
+		echo "OK, that will do." >&4
+	else
+echo "Sorry, I can't get that to work.  Go find one and rerun Configure." >&4
+		exit 1
+	fi
+fi
+
+case "$ok" in
+false)
+	cppstdin="$x_cpp"
+	cppminus="$x_minus"
+	cpprun="$x_cpp"
+	cpplast="$x_minus"
+	set X $x_cpp
+	shift
+	case "$1" in
+	"$cpp")
+		echo "Perhaps can we force $cc -E using a wrapper..."
+		if $wrapper <testcpp.c >testcpp.out 2>&1; \
+			$contains 'abc.*xyz' testcpp.out >/dev/null 2>&1
+		then
+			echo "Yup, we can."
+			cppstdin="$wrapper"
+			cppminus='';
+		else
+			echo "Nope, we'll have to live without it..."
+		fi
+		;;
+	esac
+	case "$cpprun" in
+	"$wrapper")
+		cpprun=''
+		cpplast=''
+		;;
+	esac
+	;;
+esac
+
+case "$cppstdin" in
+"$wrapper"|'cppstdin') ;;
+*) $rm -f $wrapper;;
+esac
+$rm -f testcpp.c testcpp.out
+
+: decide how portable to be.  Allow command line overrides.
+case "$d_portable" in
+"$undef") ;;
+*)	d_portable="$define" ;;
+esac
+
+: set up shell script to do ~ expansion
+cat >filexp <<EOSS
+$startsh
+: expand filename
+case "\$1" in
+ ~/*|~)
+	echo \$1 | $sed "s|~|\${HOME-\$LOGDIR}|"
+	;;
+ ~*)
+	if $test -f /bin/csh; then
+		/bin/csh -f -c "glob \$1"
+		failed=\$?
+		echo ""
+		exit \$failed
+	else
+		name=\`$expr x\$1 : '..\([^/]*\)'\`
+		dir=\`$sed -n -e "/^\${name}:/{s/^[^:]*:[^:]*:[^:]*:[^:]*:[^:]*:\([^:]*\).*"'\$'"/\1/" -e p -e q -e '}' </etc/passwd\`
+		if $test ! -d "\$dir"; then
+			me=\`basename \$0\`
+			echo "\$me: can't locate home directory for: \$name" >&2
+			exit 1
+		fi
+		case "\$1" in
+		*/*)
+			echo \$dir/\`$expr x\$1 : '..[^/]*/\(.*\)'\`
+			;;
+		*)
+			echo \$dir
+			;;
+		esac
+	fi
+	;;
+*)
+	echo \$1
+	;;
+esac
+EOSS
+chmod +x filexp
+$eunicefix filexp
+
+: now set up to get a file name
+cat <<EOS >getfile
+$startsh
+EOS
+cat <<'EOSC' >>getfile
+tilde=''
+fullpath=''
+already=''
+skip=''
+none_ok=''
+exp_file=''
+nopath_ok=''
+orig_rp="$rp"
+orig_dflt="$dflt"
+case "$gfpth" in
+'') gfpth='.' ;;
+esac
+
+case "$fn" in
+*\(*)
+	: getfile will accept an answer from the comma-separated list
+	: enclosed in parentheses even if it does not meet other criteria.
+	expr "$fn" : '.*(\(.*\)).*' | $tr ',' $trnl >getfile.ok
+	fn=`echo $fn | sed 's/(.*)//'`
+	;;
+esac
+
+case "$fn" in
+*:*)
+	loc_file=`expr $fn : '.*:\(.*\)'`
+	fn=`expr $fn : '\(.*\):.*'`
+	;;
+esac
 
 case "$fn" in
 *~*) tilde=true;;
@@ -3266,6 +3848,7 @@ while test "$type"; do
 		true)
 			case "$ansexp" in
 			/*) value="$ansexp" ;;
+			[a-zA-Z]:/*) value="$ansexp" ;;
 			*)
 				redo=true
 				case "$already" in
@@ -3454,154 +4037,6 @@ y)	fn=d/
 	;;
 esac
 
-: see how we invoke the C preprocessor
-echo " "
-echo "Now, how can we feed standard input to your C preprocessor..." >&4
-cat <<'EOT' >testcpp.c
-#define ABC abc
-#define XYZ xyz
-ABC.XYZ
-EOT
-cd ..
-if test ! -f cppstdin; then
-	if test "X$osname" = "Xaix" -a "X$gccversion" = X; then
-		# AIX cc -E doesn't show the absolute headerfile
-		# locations but we'll cheat by using the -M flag.
-		echo 'cat >.$$.c; rm -f .$$.u; '"$cc"' ${1+"$@"} -M -c .$$.c 2>/dev/null; test -s .$$.u && awk '"'"'$2 ~ /\.h$/ { print "# 0 \""$2"\"" }'"'"' .$$.u; rm -f .$$.o .$$.u; '"$cc"' -E ${1+"$@"} .$$.c; rm .$$.c' > cppstdin
-	else
-		echo 'cat >.$$.c; '"$cc"' -E ${1+"$@"} .$$.c; rm .$$.c' >cppstdin
-	fi
-else
-	echo "Keeping your $hint cppstdin wrapper."
-fi
-chmod 755 cppstdin
-wrapper=`pwd`/cppstdin
-ok='false'
-cd UU
-
-if $test "X$cppstdin" != "X" && \
-	$cppstdin $cppminus <testcpp.c >testcpp.out 2>&1 && \
-	$contains 'abc.*xyz' testcpp.out >/dev/null 2>&1
-then
-	echo "You used to use $cppstdin $cppminus so we'll use that again."
-	case "$cpprun" in
-	'') echo "But let's see if we can live without a wrapper..." ;;
-	*)
-		if $cpprun $cpplast <testcpp.c >testcpp.out 2>&1 && \
-			$contains 'abc.*xyz' testcpp.out >/dev/null 2>&1
-		then
-			echo "(And we'll use $cpprun $cpplast to preprocess directly.)"
-			ok='true'
-		else
-			echo "(However, $cpprun $cpplast does not work, let's see...)"
-		fi
-		;;
-	esac
-else
-	case "$cppstdin" in
-	'') ;;
-	*)
-		echo "Good old $cppstdin $cppminus does not seem to be of any help..."
-		;;
-	esac
-fi
-
-if $ok; then
-	: nothing
-elif echo 'Maybe "'"$cc"' -E" will work...'; \
-	$cc -E <testcpp.c >testcpp.out 2>&1; \
-	$contains 'abc.*xyz' testcpp.out >/dev/null 2>&1 ; then
-	echo "Yup, it does."
-	x_cpp="$cc -E"
-	x_minus='';
-elif echo 'Nope...maybe "'"$cc"' -E -" will work...'; \
-	$cc -E - <testcpp.c >testcpp.out 2>&1; \
-	$contains 'abc.*xyz' testcpp.out >/dev/null 2>&1 ; then
-	echo "Yup, it does."
-	x_cpp="$cc -E"
-	x_minus='-';
-elif echo 'Nope...maybe "'"$cc"' -P" will work...'; \
-	$cc -P <testcpp.c >testcpp.out 2>&1; \
-	$contains 'abc.*xyz' testcpp.out >/dev/null 2>&1 ; then
-	echo "Yipee, that works!"
-	x_cpp="$cc -P"
-	x_minus='';
-elif echo 'Nope...maybe "'"$cc"' -P -" will work...'; \
-	$cc -P - <testcpp.c >testcpp.out 2>&1; \
-	$contains 'abc.*xyz' testcpp.out >/dev/null 2>&1 ; then
-	echo "At long last!"
-	x_cpp="$cc -P"
-	x_minus='-';
-elif echo 'No such luck, maybe "'$cpp'" will work...'; \
-	$cpp <testcpp.c >testcpp.out 2>&1; \
-	$contains 'abc.*xyz' testcpp.out >/dev/null 2>&1 ; then
-	echo "It works!"
-	x_cpp="$cpp"
-	x_minus='';
-elif echo 'Nixed again...maybe "'$cpp' -" will work...'; \
-	$cpp - <testcpp.c >testcpp.out 2>&1; \
-	$contains 'abc.*xyz' testcpp.out >/dev/null 2>&1 ; then
-	echo "Hooray, it works!  I was beginning to wonder."
-	x_cpp="$cpp"
-	x_minus='-';
-elif echo 'Uh-uh.  Time to get fancy.  Trying a wrapper...'; \
-	$wrapper <testcpp.c >testcpp.out 2>&1; \
-	$contains 'abc.*xyz' testcpp.out >/dev/null 2>&1 ; then
-	x_cpp="$wrapper"
-	x_minus=''
-	echo "Eureka!"
-else
-	dflt=''
-	rp="No dice.  I can't find a C preprocessor.  Name one:"
-	. ./myread
-	x_cpp="$ans"
-	x_minus=''
-	$x_cpp <testcpp.c >testcpp.out 2>&1
-	if $contains 'abc.*xyz' testcpp.out >/dev/null 2>&1 ; then
-		echo "OK, that will do." >&4
-	else
-echo "Sorry, I can't get that to work.  Go find one and rerun Configure." >&4
-		exit 1
-	fi
-fi
-
-case "$ok" in
-false)
-	cppstdin="$x_cpp"
-	cppminus="$x_minus"
-	cpprun="$x_cpp"
-	cpplast="$x_minus"
-	set X $x_cpp
-	shift
-	case "$1" in
-	"$cpp")
-		echo "Perhaps can we force $cc -E using a wrapper..."
-		if $wrapper <testcpp.c >testcpp.out 2>&1; \
-			$contains 'abc.*xyz' testcpp.out >/dev/null 2>&1
-		then
-			echo "Yup, we can."
-			cppstdin="$wrapper"
-			cppminus='';
-		else
-			echo "Nope, we'll have to live without it..."
-		fi
-		;;
-	esac
-	case "$cpprun" in
-	"$wrapper")
-		cpprun=''
-		cpplast=''
-		;;
-	esac
-	;;
-esac
-
-case "$cppstdin" in
-"$wrapper"|'cppstdin') ;;
-*) $rm -f $wrapper;;
-esac
-$rm -f testcpp.c testcpp.out
-
 : Set private lib path
 case "$plibpth" in
 '') if ./mips; then
@@ -3756,7 +4191,7 @@ for thislib in $libswanted; do
 	for thisdir in $libspath; do
 	    xxx=''
 	    if $test ! -f "$xxx" -a "X$ignore_versioned_solibs" = "X"; then
-		xxx=`ls $thisdir/lib$thislib.$so.[0-9] 2>/dev/null|tail -1`
+		xxx=`ls $thisdir/lib$thislib.$so.[0-9] 2>/dev/null|sed -n '$p'`
 	        $test -f "$xxx" && eval $libscheck
 		$test -f "$xxx" && libstyle=shared
 	    fi
@@ -3908,8 +4343,8 @@ for thisincl in $inclwanted; do
 	if $test -d $thisincl; then
 		if $test x$thisincl != x$usrinc; then
 			case "$dflt" in
-			*$thisincl*);;
-			*) dflt="$dflt -I$thisincl";;
+                        *" -I$thisincl "*);;
+                        *) dflt="$dflt -I$thisincl ";;
 esac
 		fi
 	fi
@@ -3967,7 +4402,10 @@ none) ccflags='';;
 esac
 
 : the following weeds options from ccflags that are of no interest to cpp
-cppflags="$ccflags"
+case "$cppflags" in
+'') cppflags="$ccflags" ;;
+*)  cppflags="$cppflags $ccflags" ;;
+esac
 case "$gccversion" in
 1.*) cppflags="$cppflags -D__GNUC__"
 esac
@@ -4075,9 +4513,9 @@ echo " "
 echo "Checking your choice of C compiler and flags for coherency..." >&4
 $cat > try.c <<'EOF'
 #include <stdio.h>
-int main() { printf("Ok\n"); exit(0); }
+int main() { printf("Ok\n"); return(0); }
 EOF
-set X $cc $optimize $ccflags -o try $ldflags try.c $libs
+set X $cc -o try $optimize $ccflags $ldflags try.c $libs
 shift
 $cat >try.msg <<'EOM'
 I've tried to compile and run the following simple program:
@@ -4090,15 +4528,15 @@ $cat >> try.msg <<EOM
 I used the command:
 
 	$*
-	./try
+	$run ./try
 
 and I got the following output:
 
 EOM
 dflt=y
-if sh -c "$cc $optimize $ccflags -o try $ldflags try.c $libs" >>try.msg 2>&1; then
-	if sh -c './try' >>try.msg 2>&1; then
-		xxx=`./try`
+if $sh -c "$cc -o try $optimize $ccflags $ldflags try.c $libs" >>try.msg 2>&1; then
+	if $sh -c "$run ./try" >>try.msg 2>&1; then
+		xxx=`$run ./try`
 		case "$xxx" in
 		"Ok") dflt=n ;;
 		*)	echo 'The program compiled OK, but produced no output.' >> try.msg
@@ -4173,55 +4611,172 @@ case "$varval" in
 *) eval "$var=\$varval";;
 esac'
 
-: define an is-a-typedef? function that prompts if the type is not available.
-typedef_ask='type=$1; var=$2; def=$3; shift; shift; shift; inclist=$@;
-case "$inclist" in
-"") inclist="sys/types.h";;
+: define an is-a-typedef? function that prompts if the type is not available.
+typedef_ask='type=$1; var=$2; def=$3; shift; shift; shift; inclist=$@;
+case "$inclist" in
+"") inclist="sys/types.h";;
+esac;
+eval "varval=\$$var";
+case "$varval" in
+"")
+	$rm -f temp.c;
+	for inc in $inclist; do
+		echo "#include <$inc>" >>temp.c;
+	done;
+	echo "#ifdef $type" >> temp.c;
+	echo "printf(\"We have $type\");" >> temp.c;
+	echo "#endif" >> temp.c;
+	$cppstdin $cppflags $cppminus < temp.c >temp.E 2>/dev/null;
+	echo " " ;
+	echo "$rp" | $sed -e "s/What is/Looking for/" -e "s/?/./";
+	if $contains $type temp.E >/dev/null 2>&1; then
+		echo "$type found." >&4;
+		eval "$var=\$type";
+	else
+		echo "$type NOT found." >&4;
+		dflt="$def";
+		. ./myread ;
+		eval "$var=\$ans";
+	fi;
+	$rm -f temp.?;;
+*) eval "$var=\$varval";;
+esac'
+
+: define a shorthand compile call
+compile='
+mc_file=$1;
+shift;
+$cc -o ${mc_file} $optimize $ccflags $ldflags $* ${mc_file}.c $libs > /dev/null 2>&1;'
+: define a shorthand compile call for compilations that should be ok.
+compile_ok='
+mc_file=$1;
+shift;
+$cc -o ${mc_file} $optimize $ccflags $ldflags $* ${mc_file}.c $libs;'
+
+: determine filename position in cpp output
+echo " "
+echo "Computing filename position in cpp output for #include directives..." >&4
+case "$osname" in
+vos) testaccess=-e ;;
+*)   testaccess=-r ;;
+esac
+echo '#include <stdio.h>' > foo.c
+$cat >fieldn <<EOF
+$startsh
+$cppstdin $cppflags $cppminus <foo.c 2>/dev/null | \
+$grep '^[ 	]*#.*stdio\.h' | \
+while read cline; do
+	pos=1
+	set \$cline
+	while $test \$# -gt 0; do
+		if $test $testaccess \`echo \$1 | $tr -d '"'\`; then
+			echo "\$pos"
+			exit 0
+		fi
+		shift
+		pos=\`expr \$pos + 1\`
+	done
+done
+EOF
+chmod +x fieldn
+fieldn=`./fieldn`
+$rm -f foo.c fieldn
+case $fieldn in
+'') pos='???';;
+1) pos=first;;
+2) pos=second;;
+3) pos=third;;
+*) pos="${fieldn}th";;
+esac
+echo "Your cpp writes the filename in the $pos field of the line."
+
+case "$osname" in
+vos) cppfilter="tr '\\\\>' '/' |" ;; # path component separator is >
+*)   cppfilter='' ;;
+esac
+: locate header file
+$cat >findhdr <<EOF
+$startsh
+wanted=\$1
+name=''
+for usrincdir in $usrinc
+do
+	if test -f \$usrincdir/\$wanted; then
+		echo "\$usrincdir/\$wanted"
+		exit 0
+	fi
+done
+awkprg='{ print \$$fieldn }'
+echo "#include <\$wanted>" > foo\$\$.c
+$cppstdin $cppminus $cppflags < foo\$\$.c 2>/dev/null | \
+$cppfilter $grep "^[ 	]*#.*\$wanted" | \
+while read cline; do
+	name=\`echo \$cline | $awk "\$awkprg" | $tr -d '"'\`
+	case "\$name" in
+	*[/\\\\]\$wanted) echo "\$name"; exit 1;;
+	*[\\\\/]\$wanted) echo "\$name"; exit 1;;
+	*) exit 2;;
+	esac;
+done;
+#
+# status = 0: grep returned 0 lines, case statement not executed
+# status = 1: headerfile found
+# status = 2: while loop executed, no headerfile found
+#
+status=\$?
+$rm -f foo\$\$.c;
+if test \$status -eq 1; then
+	exit 0;
+fi
+exit 1
+EOF
+chmod +x findhdr
+
+: define an alternate in-header-list? function
+inhdr='echo " "; td=$define; tu=$undef; yyy=$@;
+cont=true; xxf="echo \"<\$1> found.\" >&4";
+case $# in 2) xxnf="echo \"<\$1> NOT found.\" >&4";;
+*) xxnf="echo \"<\$1> NOT found, ...\" >&4";;
 esac;
-eval "varval=\$$var";
-case "$varval" in
-"")
-	$rm -f temp.c;
-	for inc in $inclist; do
-		echo "#include <$inc>" >>temp.c;
-	done;
-	echo "#ifdef $type" >> temp.c;
-	echo "printf(\"We have $type\");" >> temp.c;
-	echo "#endif" >> temp.c;
-	$cppstdin $cppflags $cppminus < temp.c >temp.E 2>/dev/null;
-	echo " " ;
-	echo "$rp" | $sed -e "s/What is/Looking for/" -e "s/?/./";
-	if $contains $type temp.E >/dev/null 2>&1; then
-		echo "$type found." >&4;
-		eval "$var=\$type";
-	else
-		echo "$type NOT found." >&4;
-		dflt="$def";
-		. ./myread ;
-		eval "$var=\$ans";
-	fi;
-	$rm -f temp.?;;
-*) eval "$var=\$varval";;
-esac'
+case $# in 4) instead=instead;; *) instead="at last";; esac;
+while $test "$cont"; do
+	xxx=`./findhdr $1`
+	var=$2; eval "was=\$$2";
+	if $test "$xxx" && $test -r "$xxx";
+	then eval $xxf;
+	eval "case \"\$$var\" in $undef) . ./whoa; esac"; eval "$var=\$td";
+		cont="";
+	else eval $xxnf;
+	eval "case \"\$$var\" in $define) . ./whoa; esac"; eval "$var=\$tu"; fi;
+	set $yyy; shift; shift; yyy=$@;
+	case $# in 0) cont="";;
+	2) xxf="echo \"but I found <\$1> $instead.\" >&4";
+		xxnf="echo \"and I did not find <\$1> either.\" >&4";;
+	*) xxf="echo \"but I found <\$1\> instead.\" >&4";
+		xxnf="echo \"there is no <\$1>, ...\" >&4";;
+	esac;
+done;
+while $test "$yyy";
+do set $yyy; var=$2; eval "was=\$$2";
+	eval "case \"\$$var\" in $define) . ./whoa; esac"; eval "$var=\$tu";
+	set $yyy; shift; shift; yyy=$@;
+done'
 
-: define a shorthand compile call
-compile='
-mc_file=$1;
-shift;
-$cc $optimize $ccflags $ldflags -o ${mc_file} $* ${mc_file}.c $libs > /dev/null 2>&1;'
-: define a shorthand compile call for compilations that should be ok.
-compile_ok='
-mc_file=$1;
-shift;
-$cc $optimize $ccflags $ldflags -o ${mc_file} $* ${mc_file}.c $libs;'
+: see if stdlib is available
+set stdlib.h i_stdlib
+eval $inhdr
 
 : check for lengths of integral types
 echo " "
 case "$intsize" in
 '')
 	echo "Checking to see how big your integers are..." >&4
-	$cat >intsize.c <<'EOCP'
+	$cat >try.c <<EOCP
 #include <stdio.h>
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
 int main()
 {
 	printf("intsize=%d;\n", (int)sizeof(int));
@@ -4230,9 +4785,9 @@ int main()
 	exit(0);
 }
 EOCP
-	set intsize
-	if eval $compile_ok && ./intsize > /dev/null; then
-		eval `./intsize`
+	set try
+	if eval $compile_ok && $run ./try > /dev/null; then
+		eval `$run ./try`
 		echo "Your integers are $intsize bytes long."
 		echo "Your long integers are $longsize bytes long."
 		echo "Your short integers are $shortsize bytes long."
@@ -4259,7 +4814,7 @@ EOM
 	fi
 	;;
 esac
-$rm -f intsize intsize.*
+$rm -f try try.*
 
 : see what type lseek is declared as in the kernel
 rp="What is the type used for lseek's offset on this system?"
@@ -4279,7 +4834,7 @@ int main()
 EOCP
 set try
 if eval $compile_ok; then
-	lseeksize=`./try`
+	lseeksize=`$run ./try`
 	echo "Your file offsets are $lseeksize bytes long."
 else
 	dflt=$longsize
@@ -4305,6 +4860,10 @@ echo "Checking the size of $zzz..." >&4
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
@@ -4312,7 +4871,7 @@ int main() {
 EOCP
 set try
 if eval $compile_ok; then
-	yyy=`./try`
+	yyy=`$run ./try`
 	case "$yyy" in
 	'')	fpossize=4
 		echo "(I can't execute the test program--guessing $fpossize.)" >&4
@@ -4391,7 +4950,7 @@ int main()
 EOCP
 		set try
 		if eval $compile_ok; then
-			lseeksize=`./try`
+			lseeksize=`$run ./try`
 			$echo "Your file offsets are now $lseeksize bytes long."
 		else
 			dflt="$lseeksize"
@@ -4409,14 +4968,18 @@ EOCP
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
 		if eval $compile_ok; then
-			yyy=`./try`
+			yyy=`$run ./try`
 			dflt="$lseeksize"
 			case "$yyy" in
 			'')	echo " "
@@ -4640,6 +5203,10 @@ case "$myarchname" in
 	archname=''
 	;;
 esac
+case "$targetarch" in
+'') ;;
+*)  archname=`echo $targetarch|sed 's,^[^-]*-,,'` ;;
+esac
 myarchname="$tarch"
 case "$archname" in
 '') dflt="$tarch";;
@@ -4725,12 +5292,17 @@ esac
 prefix="$ans"
 prefixexp="$ansexp"
 
+case "$afsroot" in
+'')	afsroot=/afs ;;
+*)	afsroot=$afsroot ;;
+esac
+
 : is AFS running?
 echo " "
 case "$afs" in
 $define|true)	afs=true ;;
 $undef|false)	afs=false ;;
-*)	if test -d /afs; then
+*)	if test -d $afsroot; then
 		afs=true
 	else
 		afs=false
@@ -4821,10 +5393,7 @@ else
 	api_version=0
 	api_subversion=0
 fi
-$echo $n "(You have $package revision $revision" $c
-$echo $n " patchlevel $patchlevel" $c
-test 0 -eq "$subversion" || $echo $n " subversion $subversion" $c
-echo ".)"
+$echo "(You have $package version $patchlevel subversion $subversion.)"
 case "$osname" in
 dos|vms)
 	: XXX Should be a Configure test for double-dots in filenames.
@@ -5057,7 +5626,7 @@ val="$undef"
 case "$d_suidsafe" in
 "$define")
 	val="$undef"
-	echo "No need to emulate SUID scripts since they are secure here." >& 4
+	echo "No need to emulate SUID scripts since they are secure here." >&4
 	;;
 *)
 	$cat <<EOM
@@ -5084,120 +5653,20 @@ esac
 set d_dosuid
 eval $setvar
 
-: determine filename position in cpp output
-echo " "
-echo "Computing filename position in cpp output for #include directives..." >&4
-echo '#include <stdio.h>' > foo.c
-$cat >fieldn <<EOF
-$startsh
-$cppstdin $cppflags $cppminus <foo.c 2>/dev/null | \
-$grep '^[ 	]*#.*stdio\.h' | \
-while read cline; do
-	pos=1
-	set \$cline
-	while $test \$# -gt 0; do
-		if $test -r \`echo \$1 | $tr -d '"'\`; then
-			echo "\$pos"
-			exit 0
-		fi
-		shift
-		pos=\`expr \$pos + 1\`
-	done
-done
-EOF
-chmod +x fieldn
-fieldn=`./fieldn`
-$rm -f foo.c fieldn
-case $fieldn in
-'') pos='???';;
-1) pos=first;;
-2) pos=second;;
-3) pos=third;;
-*) pos="${fieldn}th";;
-esac
-echo "Your cpp writes the filename in the $pos field of the line."
-
-: locate header file
-$cat >findhdr <<EOF
-$startsh
-wanted=\$1
-name=''
-for usrincdir in $usrinc
-do
-	if test -f \$usrincdir/\$wanted; then
-		echo "\$usrincdir/\$wanted"
-		exit 0
-	fi
-done
-awkprg='{ print \$$fieldn }'
-echo "#include <\$wanted>" > foo\$\$.c
-$cppstdin $cppminus $cppflags < foo\$\$.c 2>/dev/null | \
-$grep "^[ 	]*#.*\$wanted" | \
-while read cline; do
-	name=\`echo \$cline | $awk "\$awkprg" | $tr -d '"'\`
-	case "\$name" in
-	*[/\\\\]\$wanted) echo "\$name"; exit 1;;
-	*[\\\\/]\$wanted) echo "\$name"; exit 1;;
-	*) exit 2;;
-	esac;
-done;
-#
-# status = 0: grep returned 0 lines, case statement not executed
-# status = 1: headerfile found
-# status = 2: while loop executed, no headerfile found
-#
-status=\$?
-$rm -f foo\$\$.c;
-if test \$status -eq 1; then
-	exit 0;
-fi
-exit 1
-EOF
-chmod +x findhdr
-
-: define an alternate in-header-list? function
-inhdr='echo " "; td=$define; tu=$undef; yyy=$@;
-cont=true; xxf="echo \"<\$1> found.\" >&4";
-case $# in 2) xxnf="echo \"<\$1> NOT found.\" >&4";;
-*) xxnf="echo \"<\$1> NOT found, ...\" >&4";;
-esac;
-case $# in 4) instead=instead;; *) instead="at last";; esac;
-while $test "$cont"; do
-	xxx=`./findhdr $1`
-	var=$2; eval "was=\$$2";
-	if $test "$xxx" && $test -r "$xxx";
-	then eval $xxf;
-	eval "case \"\$$var\" in $undef) . ./whoa; esac"; eval "$var=\$td";
-		cont="";
-	else eval $xxnf;
-	eval "case \"\$$var\" in $define) . ./whoa; esac"; eval "$var=\$tu"; fi;
-	set $yyy; shift; shift; yyy=$@;
-	case $# in 0) cont="";;
-	2) xxf="echo \"but I found <\$1> $instead.\" >&4";
-		xxnf="echo \"and I did not find <\$1> either.\" >&4";;
-	*) xxf="echo \"but I found <\$1\> instead.\" >&4";
-		xxnf="echo \"there is no <\$1>, ...\" >&4";;
-	esac;
-done;
-while $test "$yyy";
-do set $yyy; var=$2; eval "was=\$$2";
-	eval "case \"\$$var\" in $define) . ./whoa; esac"; eval "$var=\$tu";
-	set $yyy; shift; shift; yyy=$@;
-done'
-
 : see if this is a malloc.h system
 set malloc.h i_malloc
 eval $inhdr
 
-: see if stdlib is available
-set stdlib.h i_stdlib
-eval $inhdr
-
 : determine which malloc to compile in
 echo " "
 case "$usemymalloc" in
-''|[yY]*|true|$define)	dflt='y' ;;
-*)	dflt='n' ;;
+[yY]*|true|$define)	dflt='y' ;;
+[nN]*|false|$undef)	dflt='n' ;;
+*)	case "$ptrsize" in
+	4) dflt='y' ;;
+	*) dflt='n' ;;
+esac
+	;;
 esac
 rp="Do you wish to attempt to use the malloc that comes with $package?"
 . ./myread
@@ -5392,7 +5861,11 @@ fi
 : Cruising for prototypes
 echo " "
 echo "Checking out function prototypes..." >&4
-$cat >prototype.c <<'EOCP'
+$cat >prototype.c <<EOCP
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
 int main(int argc, char *argv[]) {
 	exit(0);}
 EOCP
@@ -5453,13 +5926,13 @@ fi
 : Find perl5.005 or later.
 echo "Looking for a previously installed perl5.005 or later... "
 case "$perl5" in
-'')	for tdir in `echo "$binexp:$PATH" | $sed "s/$path_sep/ /g"`; do
+'')	for tdir in `echo "$binexp$path_sep$PATH" | $sed "s/$path_sep/ /g"`; do
 		: Check if this perl is recent and can load a simple module
-		if $test -x $tdir/perl && $tdir/perl -Mless -e 'use 5.005;' >/dev/null 2>&1; then
+		if $test -x $tdir/perl$exe_ext && $tdir/perl -Mless -e 'use 5.005;' >/dev/null 2>&1; then
 			perl5=$tdir/perl
 			break;
-		elif $test -x $tdir/perl5 && $tdir/perl5 -Mless -e 'use 5.005;' >/dev/null 2>&1; then
-			perl5=$tdir/perl
+		elif $test -x $tdir/perl5$exe_ext && $tdir/perl5 -Mless -e 'use 5.005;' >/dev/null 2>&1; then
+			perl5=$tdir/perl5
 			break;
 		fi
 	done
@@ -5549,13 +6022,12 @@ $cat > getverlist <<EOPL
 use File::Basename;
 \$api_versionstring = "$api_versionstring";
 \$version = "$version";
-\$sitelib = "$sitelib";
+\$stem = "$sitelib_stem";
 \$archname = "$archname";
 EOPL
 	$cat >> getverlist <<'EOPL'
 # Can't have leading @ because metaconfig interprets it as a command!
 ;@inc_version_list=();
-$stem=dirname($sitelib);
 # XXX Redo to do opendir/readdir? 
 if (-d $stem) {
     chdir($stem);
@@ -5596,18 +6068,25 @@ else {
 EOPL
 chmod +x getverlist
 case "$inc_version_list" in
-'')	if test -x "$perl5"; then
+'')	if test -x "$perl5$exe_ext"; then
 		dflt=`$perl5 getverlist`
 	else
 		dflt='none'
 	fi
 	;;
 $undef) dflt='none' ;;
-*)  dflt="$inc_version_list" ;;
+*)  eval dflt=\"$inc_version_list\" ;;
 esac
 case "$dflt" in
 ''|' ') dflt=none ;;
 esac
+case "$dflt" in
+5.005) case "$bincompat5005" in
+       $define|true|[yY]*) ;;
+       *) dflt=none ;;
+       esac
+       ;;
+esac
 $cat <<'EOM'
 
 In order to ease the process of upgrading, this version of perl 
@@ -5664,26 +6143,43 @@ eval $setvar
 
 echo " "
 echo "Checking for GNU C Library..." >&4
-cat >gnulibc.c <<EOM
+cat >try.c <<'EOCP'
+/* Find out version of GNU C library.  __GLIBC__ and __GLIBC_MINOR__
+   alone are insufficient to distinguish different versions, such as
+   2.0.6 and 2.0.7.  The function gnu_get_libc_version() appeared in
+   libc version 2.1.0.      A. Dougherty,  June 3, 2002.
+*/
 #include <stdio.h>
-int main()
+int main(void)
 {
 #ifdef __GLIBC__
-    exit(0);
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
 #else
-    exit(1);
+    return 1;
 #endif
 }
-EOM
-set gnulibc
-if eval $compile_ok && ./gnulibc; then
+EOCP
+set try
+if eval $compile_ok && $run ./try > glibc.ver; then
 	val="$define"
-	echo "You are using the GNU C Library"
+	gnulibc_version=`$cat glibc.ver`
+	echo "You are using the GNU C Library version $gnulibc_version"
 else
 	val="$undef"
+	gnulibc_version=''
 	echo "You are not using the GNU C Library"
 fi
-$rm -f gnulibc*
+$rm -f try try.* glibc.ver
 set d_gnulibc
 eval $setvar
 
@@ -5700,7 +6196,7 @@ case "$usenm" in
 	esac
 	case "$dflt" in
 	'') 
-		if $test "$osname" = aix -a ! -f /lib/syscalls.exp; then
+		if $test "$osname" = aix -a "X$PASE" != "Xdefine" -a ! -f /lib/syscalls.exp; then
 			echo " "
 			echo "Whoops!  This is an AIX system without /lib/syscalls.exp!" >&4
 			echo "'nm' won't be sufficient on this sytem." >&4
@@ -5838,7 +6334,7 @@ unknown)
 				s/0*\([0-9][0-9][0-9][0-9][0-9]\)/\1/g
 				G
 				s/\n/ /' | \
-			 sort | $sed -e 's/^.* //'`
+			 $sort | $sed -e 's/^.* //'`
 		eval set \$$#
 	done
 	$test -r $1 || set /usr/ccs/lib/libc.$so
@@ -5898,7 +6394,7 @@ compiler, or your machine supports multiple models), you can override it here.
 EOM
 else
 	dflt=''
-	echo $libpth | tr ' ' $trnl | sort | uniq > libpath
+	echo $libpth | $tr ' ' $trnl | $sort | $uniq > libpath
 	cat >&4 <<EOM
 I can't seem to find your C library.  I've looked in the following places:
 
@@ -5916,7 +6412,7 @@ rp='Where is your C library?'
 libc="$ans"
 
 echo " "
-echo $libc $libnames | tr ' ' $trnl | sort | uniq > libnames
+echo $libc $libnames | $tr ' ' $trnl | $sort | $uniq > libnames
 set X `cat libnames`
 shift
 xxx=files
@@ -5937,9 +6433,9 @@ done >libc.tmp
 $echo $n ".$c"
 $grep fprintf libc.tmp > libc.ptf
 xscan='eval "<libc.ptf $com >libc.list"; $echo $n ".$c" >&4'
-xrun='eval "<libc.tmp $com >libc.list"; echo "done" >&4'
+xrun='eval "<libc.tmp $com >libc.list"; echo "done." >&4'
 xxx='[ADTSIW]'
-if com="$sed -n -e 's/__IO//' -e 's/^.* $xxx  *_[_.]*//p' -e 's/^.* $xxx  *//p'";\
+if com="$sed -n -e 's/__IO//' -e 's/^.* $xxx  *//p'";\
 	eval $xscan;\
 	$contains '^fprintf$' libc.list >/dev/null 2>&1; then
 		eval $xrun
@@ -6064,9 +6560,9 @@ eval $inhdr
 : is a C symbol defined?
 csym='tlook=$1;
 case "$3" in
--v) tf=libc.tmp; tc=""; tdc="";;
--a) tf=libc.tmp; tc="[0]"; tdc="[]";;
-*) tlook="^$1\$"; tf=libc.list; tc="()"; tdc="()";;
+-v) tf=libc.tmp; tdc="";;
+-a) tf=libc.tmp; tdc="[]";;
+*) tlook="^$1\$"; tf=libc.list; tdc="()";;
 esac;
 tx=yes;
 case "$reuseval-$4" in
@@ -6075,25 +6571,28 @@ true-*) tx=no; eval "tval=\$$4"; case "$tval" in "") tx=yes;; esac;;
 esac;
 case "$tx" in
 yes)
-	case "$runnm" in
-	true)
-		if $contains $tlook $tf >/dev/null 2>&1;
-		then tval=true;
-		else tval=false;
-		fi;;
-	*)
-		echo "int main() { extern short $1$tdc; printf(\"%hd\", $1$tc); }" > t.c;
-		if $cc $optimize $ccflags $ldflags -o t t.c $libs >/dev/null 2>&1;
-		then tval=true;
-		else tval=false;
+	tval=false;
+	if $test "$runnm" = true; then
+		if $contains $tlook $tf >/dev/null 2>&1; then
+			tval=true;
+		elif $test "$mistrustnm" = compile -o "$mistrustnm" = run; then
+			echo "void *(*(p()))$tdc { extern void *$1$tdc; return &$1; } int main() { if(p()) return(0); else return(1); }"> try.c;
+			$cc -o try $optimize $ccflags $ldflags try.c >/dev/null 2>&1 $libs && tval=true;
+			$test "$mistrustnm" = run -a -x try && { $run ./try$_exe >/dev/null 2>&1 || tval=false; };
+			$rm -f try$_exe try.c core core.* try.core;
 		fi;
-		$rm -f t t.c;;
-	esac;;
+	else
+		echo "void *(*(p()))$tdc { extern void *$1$tdc; return &$1; } int main() { if(p()) return(0); else return(1); }"> try.c;
+		$cc -o try $optimize $ccflags $ldflags try.c $libs >/dev/null 2>&1 && tval=true;
+		$rm -f try$_exe try.c;
+	fi;
+	;;
 *)
 	case "$tval" in
 	$define) tval=true;;
 	*) tval=false;;
-	esac;;
+esac;
+	;;
 esac;
 eval "$2=$tval"'
 
@@ -6177,7 +6676,7 @@ y*) usedl="$define"
 	esac
     echo "The following dynamic loading files are available:"
 	: Can not go over to $dldir because getfile has path hard-coded in.
-	tdir=`pwd`; cd $rsrc; $ls -C $dldir/dl*.xs; cd $tdir
+	tdir=`pwd`; cd "$rsrc"; $ls -C $dldir/dl*.xs; cd "$tdir"
 	rp="Source file to use for dynamic loading"
 	fn="fne"
 	gfpth="$src"
@@ -6199,13 +6698,14 @@ EOM
 			hpux)	dflt='+z' ;;
 			next)	dflt='none' ;;
 			irix*)	dflt='-KPIC' ;;
-			svr4*|esix*|solaris) dflt='-KPIC' ;;
+			svr4*|esix*|solaris|nonstopux) dflt='-KPIC' ;;
 			sunos)	dflt='-pic' ;;
 			*)	dflt='none' ;;
 		    esac
 			;;
 		*)  case "$osname" in
-			svr4*|esix*|solaris) dflt='-fPIC' ;;
+	                darwin) dflt='none' ;;
+			svr4*|esix*|solaris|nonstopux) dflt='-fPIC' ;;
 			*)	dflt='-fpic' ;;
 		    esac ;;
 	    esac ;;
@@ -6226,10 +6726,13 @@ while other systems (such as those using ELF) use $cc.
 
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
@@ -6241,7 +6744,7 @@ int main() {
 		exit(1); /* fail */
 }
 EOM
-		if $cc $ccflags try.c >/dev/null 2>&1 && ./a.out; then
+		if $cc $ccflags $ldflags try.c >/dev/null 2>&1 && $run ./a.out; then
 			cat <<EOM
 You appear to have ELF support.  I'll use $cc to build dynamic libraries.
 EOM
@@ -6281,7 +6784,7 @@ EOM
 			next)  dflt='none' ;;
 			solaris) dflt='-G' ;;
 			sunos) dflt='-assert nodefinitions' ;;
-			svr4*|esix*) dflt="-G $ldflags" ;;
+			svr4*|esix*|nonstopux) dflt="-G $ldflags" ;;
 	        *)     dflt='none' ;;
 			esac
 			;;
@@ -6295,7 +6798,7 @@ EOM
 	esac
 	for thisflag in $ldflags; do
 		case "$thisflag" in
-		-L*)
+		-L*|-R*|-Wl,-R*)
 			case " $dflt " in
 			*" $thisflag "*) ;;
 			*) dflt="$dflt $thisflag" ;;
@@ -6356,7 +6859,7 @@ $undef)
 	;;
 *)	case "$useshrplib" in
 	'')	case "$osname" in
-		svr4*|dgux|dynixptx|esix|powerux|beos|cygwin*)
+		svr4*|nonstopux|dgux|dynixptx|esix|powerux|beos|cygwin*)
 			dflt=y
 			also='Building a shared libperl is required for dynamic loading to work on your system.'
 			;;
@@ -6426,8 +6929,8 @@ true)
 		linux*)  # ld won't link with a bare -lperl otherwise.
 			dflt=libperl.$so
 			;;
-		cygwin*) # include version
-			dflt=`echo libperl$version | sed -e 's/\./_/g'`$lib_ext
+		cygwin*) # ld links against an importlib
+			dflt=libperl$lib_ext
 			;;
 		*)	# Try to guess based on whether libc has major.minor.
 			case "$libc" in
@@ -6504,13 +7007,13 @@ if "$useshrplib"; then
 	aix)
 		# We'll set it in Makefile.SH...
 		;;
-	solaris|netbsd)
+	solaris)
 		xxx="-R $shrpdir"
 		;;
-	freebsd)
+	freebsd|netbsd)
 		xxx="-Wl,-R$shrpdir"
 		;;
-	linux|irix*|dec_osf)
+	bsdos|linux|irix*|dec_osf)
 		xxx="-Wl,-rpath,$shrpdir"
 		;;
 	next)
@@ -6770,7 +7273,7 @@ case "$man3dir" in
 esac
 
 : see if we have to deal with yellow pages, now NIS.
-if $test -d /usr/etc/yp || $test -d /etc/yp; then
+if $test -d /usr/etc/yp || $test -d /etc/yp || $test -d /usr/lib/yp; then
 	if $test -f /usr/etc/nibindd; then
 		echo " "
 		echo "I'm fairly confident you're on a NeXT."
@@ -6877,6 +7380,9 @@ if $test "$cont"; then
 		fi
 	fi
 fi
+case "$myhostname" in
+'') myhostname=noname ;;
+esac
 : you do not want to know about this
 set $myhostname
 myhostname=$1
@@ -6927,18 +7433,23 @@ case "$myhostname" in
 					/[	 ]$myhostname[	. ]/p" > hosts
 		}
 		tmp_re="[	. ]"
+		if $test -f hosts; then
 		$test x`$awk "/[0-9].*[	 ]$myhostname$tmp_re/ { sum++ }
 			     END { print sum }" hosts` = x1 || tmp_re="[	 ]"
 		dflt=.`$awk "/[0-9].*[	 ]$myhostname$tmp_re/ {for(i=2; i<=NF;i++) print \\\$i}" \
 			hosts | $sort | $uniq | \
 			$sed -n -e "s/$myhostname\.\([-a-zA-Z0-9_.]\)/\1/p"`
 		case `$echo X$dflt` in
-		X*\ *)	echo "(Several hosts in /etc/hosts matched hostname)"
+			X*\ *)	echo "(Several hosts in the database matched hostname)"
 			dflt=.
 			;;
-		X.) echo "(You do not have fully-qualified names in /etc/hosts)"
+			X.) echo "(You do not have fully-qualified names in the hosts database)"
 			;;
 		esac
+		else
+			echo "(I cannot locate a hosts database anywhere)"
+			dflt=.
+		fi
 		case "$dflt" in
 		.)
 			tans=`./loc resolv.conf X /etc /usr/etc`
@@ -6965,9 +7476,14 @@ case "$myhostname" in
 			esac
 			;;
 		esac
+		case "$dflt$osname" in
+		.os390) echo "(Attempting domain name extraction from //'SYS1.TCPPARMS(TCPDATA)')"
+			dflt=.`awk '/^DOMAINORIGIN/ {print $2}' "//'SYS1.TCPPARMS(TCPDATA)'" 2>/dev/null`
+			;;
+		esac
 		case "$dflt" in
 		.) echo "(Lost all hope -- silly guess then)"
-			dflt='.uucp'
+			dflt='.nonet'
 			;;
 		esac
 		$rm -f hosts
@@ -7080,7 +7596,10 @@ want to share those scripts and perl is not in a standard place
 a shell by starting the script with a single ':' character.
 
 EOH
-		dflt="$binexp/perl"
+		case "$versiononly" in
+		"$define")      dflt="$binexp/perl$version";;  
+		*)              dflt="$binexp/perl";;
+		esac
 		rp='What shall I put after the #! to start up perl ("none" to not use #!)?'
 		. ./myread
 		case "$ans" in
@@ -7346,8 +7865,12 @@ echo " "
 case "$doublesize" in
 '')
 	echo "Checking to see how big your double precision numbers are..." >&4
-	$cat >try.c <<'EOCP'
+	$cat >try.c <<EOCP
 #include <stdio.h>
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
 int main()
 {
     printf("%d\n", (int)sizeof(double));
@@ -7356,7 +7879,7 @@ int main()
 EOCP
 	set try
 	if eval $compile_ok; then
-		doublesize=`./try`
+		doublesize=`$run ./try`
 		echo "Your double is $doublesize bytes long."
 	else
 		dflt='8'
@@ -7400,7 +7923,7 @@ EOCP
 	set try
 	set try
 	if eval $compile; then
-		longdblsize=`./try$exe_ext`
+		longdblsize=`$run ./try`
 		echo "Your long doubles are $longdblsize bytes long."
 	else
 		dflt='8'
@@ -7411,7 +7934,9 @@ EOCP
 		longdblsize="$ans"
 	fi
 	if $test "X$doublesize" = "X$longdblsize"; then
-		echo "(That isn't any different from an ordinary double.)"
+		echo "That isn't any different from an ordinary double."
+		echo "I'll keep your setting anyway, but you may see some"
+		echo "harmless compilation warnings."
 	fi	
 	;;
 esac
@@ -7434,7 +7959,7 @@ int main() {
 EOCP
 	set try
 	if eval $compile; then
-		yyy=`./try$exe_ext`
+		yyy=`$run ./try`
 		case "$yyy" in
 		123.456)
 			sPRIfldbl='"f"'; sPRIgldbl='"g"'; sPRIeldbl='"e"';
@@ -7500,7 +8025,7 @@ int main() {
 EOCP
 	set try
 	if eval $compile; then
-		yyy=`./try$exe_ext`
+		yyy=`$run ./try`
 		case "$yyy" in
 		123.456)
 			sPRIfldbl='"lf"'; sPRIgldbl='"lg"'; sPRIeldbl='"le"';
@@ -7557,9 +8082,13 @@ char *myname = "qgcvt";
 #define DOUBLETYPE long double
 #endif
 #ifdef TRY_sprintf
-#if defined(USE_LONG_DOUBLE) && defined(HAS_LONG_DOUBLE) && defined(HAS_PRIgldbl)
+#if defined(USE_LONG_DOUBLE) && defined(HAS_LONG_DOUBLE)
+#ifdef HAS_PRIgldbl
 #define Gconvert(x,n,t,b) sprintf((b),"%.*"$sPRIgldbl,(n),(x))
 #else
+#define Gconvert(x,n,t,b) sprintf((b),"%.*g",(n),(double)(x))
+#endif
+#else
 #define Gconvert(x,n,t,b) sprintf((b),"%.*g",(n),(x))
 #endif
 char *myname = "sprintf";
@@ -7723,7 +8252,7 @@ eval $inlibc
 case "$d_access" in
 "$define")
 	echo " "
-	$cat >access.c <<'EOCP'
+	$cat >access.c <<EOCP
 #include <sys/types.h>
 #ifdef I_FCNTL
 #include <fcntl.h>
@@ -7734,6 +8263,10 @@ case "$d_access" in
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
@@ -7778,7 +8311,7 @@ echo " "
 echo "Checking whether your compiler can handle __attribute__ ..." >&4
 $cat >attrib.c <<'EOCP'
 #include <stdio.h>
-void croak (char* pat,...) __attribute__((format(printf,1,2),noreturn));
+void croak (char* pat,...) __attribute__((__format__(__printf__,1,2),noreturn));
 EOCP
 if $cc $ccflags -c attrib.c >attrib.out 2>&1 ; then
 	if $contains 'warning' attrib.out >/dev/null 2>&1; then
@@ -7816,12 +8349,16 @@ case "$d_getpgrp" in
 "$define")
 	echo " "
 	echo "Checking to see which flavor of getpgrp is in use..."
-	$cat >set.c <<EOP
+	$cat >try.c <<EOP
 #$i_unistd I_UNISTD
 #include <sys/types.h>
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
@@ -7868,7 +8405,7 @@ EOP
 esac
 set d_bsdgetpgrp
 eval $setvar
-$rm -f set set.c
+$rm -f try try.*
 
 : see if setpgrp exists
 set setpgrp d_setpgrp
@@ -7878,12 +8415,16 @@ case "$d_setpgrp" in
 "$define")
 	echo " "
 	echo "Checking to see which flavor of setpgrp is in use..."
-	$cat >set.c <<EOP
+	$cat >try.c <<EOP
 #$i_unistd I_UNISTD
 #include <sys/types.h>
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
@@ -7930,7 +8471,7 @@ EOP
 esac
 set d_bsdsetpgrp
 eval $setvar
-$rm -f set set.c
+$rm -f try try.*
 : see if bzero exists
 set bzero d_bzero
 eval $inlibc
@@ -7989,6 +8530,10 @@ else
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
@@ -8020,7 +8565,7 @@ int main()
 EOCP
 set try
 if eval $compile_ok; then
-	./try
+	$run ./try
 	yyy=$?
 else
 	echo "(I can't seem to compile the test program--assuming it can't)"
@@ -8043,6 +8588,10 @@ echo " "
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
@@ -8116,7 +8665,7 @@ int main()
 EOCP
 set try
 if eval $compile_ok; then
-	./try
+	$run ./try
 	castflags=$?
 else
 	echo "(I can't seem to compile the test program--assuming it can't)"
@@ -8139,8 +8688,12 @@ echo " "
 if set vprintf val -f d_vprintf; eval $csym; $val; then
 	echo 'vprintf() found.' >&4
 	val="$define"
-	$cat >vprintf.c <<'EOF'
+	$cat >try.c <<EOF
 #include <varargs.h>
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
 
 int main() { xxx("foo"); }
 
@@ -8154,8 +8707,8 @@ va_dcl
 	exit((unsigned long)vsprintf(buf,"%s",args) > 10L);
 }
 EOF
-	set vprintf
-	if eval $compile && ./vprintf; then
+	set try
+	if eval $compile && $run ./try; then
 		echo "Your vsprintf() returns (int)." >&4
 		val2="$undef"
 	else
@@ -8167,6 +8720,7 @@ else
 		val="$undef"
 		val2="$undef"
 fi
+$rm -f try try.*
 set d_vprintf
 eval $setvar
 val=$val2
@@ -8208,7 +8762,11 @@ eval $setvar
 
 : see if crypt exists
 echo " "
-if set crypt val -f d_crypt; eval $csym; $val; then
+set crypt d_crypt
+eval $inlibc
+case "$d_crypt" in
+$define) cryptlib='' ;;
+*)	if set crypt val -f d_crypt; eval $csym; $val; then
 	echo 'crypt() found.' >&4
 	val="$define"
 	cryptlib=''
@@ -8238,6 +8796,8 @@ else
 fi
 set d_crypt
 eval $setvar
+	;;
+esac
 
 : get csh whereabouts
 case "$csh" in
@@ -8409,9 +8969,13 @@ EOM
 $cat >fred.c<<EOM
 
 #include <stdio.h>
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
 #$i_dlfcn I_DLFCN
 #ifdef I_DLFCN
-#include <dlfcn.h>      /* the dynamic linker include file for Sunos/Solaris */
+#include <dlfcn.h>      /* the dynamic linker include file for SunOS/Solaris */
 #else
 #include <sys/types.h>
 #include <nlist.h>
@@ -8474,7 +9038,7 @@ EOM
 	;;
 esac
 		
-$rm -f fred fred.? dyna.$dlext dyna.? tmp-dyna.?
+$rm -f fred fred.* dyna.$dlext dyna.* tmp-dyna.*
 
 set d_dlsymun
 eval $setvar
@@ -8541,7 +9105,7 @@ eval $inlibc
 
 : Locate the flags for 'open()'
 echo " "
-$cat >open3.c <<'EOCP'
+$cat >try.c <<EOCP
 #include <sys/types.h>
 #ifdef I_FCNTL
 #include <fcntl.h>
@@ -8549,6 +9113,10 @@ $cat >open3.c <<'EOCP'
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
@@ -8560,10 +9128,10 @@ int main() {
 EOCP
 : check sys/file.h first to get FREAD on Sun
 if $test `./findhdr sys/file.h` && \
-		set open3 -DI_SYS_FILE && eval $compile; then
+		set try -DI_SYS_FILE && eval $compile; then
 	h_sysfile=true;
 	echo "<sys/file.h> defines the O_* constants..." >&4
-	if ./open3; then
+	if $run ./try; then
 		echo "and you have the 3 argument form of open()." >&4
 		val="$define"
 	else
@@ -8571,10 +9139,10 @@ if $test `./findhdr sys/file.h` && \
 		val="$undef"
 	fi
 elif $test `./findhdr fcntl.h` && \
-		set open3 -DI_FCNTL && eval $compile; then
+		set try -DI_FCNTL && eval $compile; then
 	h_fcntl=true;
 	echo "<fcntl.h> defines the O_* constants..." >&4
-	if ./open3; then
+	if $run ./try; then
 		echo "and you have the 3 argument form of open()." >&4
 		val="$define"
 	else
@@ -8587,7 +9155,7 @@ else
 fi
 set d_open3
 eval $setvar
-$rm -f open3*
+$rm -f try try.*
 
 : see which of string.h or strings.h is needed
 echo " "
@@ -8611,6 +9179,35 @@ case "$i_string" in
 *)	  strings=`./findhdr string.h`;;
 esac
 
+: see if fcntl.h is there
+val=''
+set fcntl.h val
+eval $inhdr
+
+: see if we can include fcntl.h
+case "$val" in
+"$define")
+	echo " "
+	if $h_fcntl; then
+		val="$define"
+		echo "We'll be including <fcntl.h>." >&4
+	else
+		val="$undef"
+		if $h_sysfile; then
+	echo "We don't need to include <fcntl.h> if we include <sys/file.h>." >&4
+		else
+			echo "We won't be including <fcntl.h>." >&4
+		fi
+	fi
+	;;
+*)
+	h_fcntl=false
+	val="$undef"
+	;;
+esac
+set i_fcntl
+eval $setvar
+
 : check for non-blocking I/O stuff
 case "$h_sysfile" in
 true) echo "#include <sys/file.h>" > head.c;;
@@ -8626,8 +9223,16 @@ echo "Figuring out the flag used by open() for non-blocking I/O..." >&4
 case "$o_nonblock" in
 '')
 	$cat head.c > try.c
-	$cat >>try.c <<'EOCP'
+	$cat >>try.c <<EOCP
 #include <stdio.h>
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
+#$i_fcntl I_FCNTL
+#ifdef I_FCNTL
+#include <fcntl.h>
+#endif
 int main() {
 #ifdef O_NONBLOCK
 	printf("O_NONBLOCK\n");
@@ -8646,7 +9251,7 @@ int main() {
 EOCP
 	set try
 	if eval $compile_ok; then
-		o_nonblock=`./try`
+		o_nonblock=`$run ./try`
 		case "$o_nonblock" in
 		'') echo "I can't figure it out, assuming O_NONBLOCK will do.";;
 		*) echo "Seems like we can use $o_nonblock.";;
@@ -8669,6 +9274,14 @@ case "$eagain" in
 #include <sys/types.h>
 #include <signal.h>
 #include <stdio.h> 
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
+#$i_fcntl I_FCNTL
+#ifdef I_FCNTL
+#include <fcntl.h>
+#endif
 #define MY_O_NONBLOCK $o_nonblock
 #ifndef errno  /* XXX need better Configure test */
 extern int errno;
@@ -8725,7 +9338,7 @@ int main()
 		ret = read(pd[0], buf, 1);	/* Should read EOF */
 		alarm(0);
 		sprintf(string, "%d\n", ret);
-		write(3, string, strlen(string));
+		write(4, string, strlen(string));
 		exit(0);
 	}
 
@@ -8739,7 +9352,7 @@ EOCP
 	set try
 	if eval $compile_ok; then
 		echo "$startsh" >mtry
-		echo "./try >try.out 2>try.ret 3>try.err || exit 4" >>mtry
+		echo "$run ./try >try.out 2>try.ret 4>try.err || exit 4" >>mtry
 		chmod +x mtry
 		./mtry >/dev/null 2>&1
 		case $? in
@@ -8869,7 +9482,7 @@ else
 							sockethdr="-I/usr/netinclude"
 							;;
 						esac
-						echo "Found Berkeley sockets interface in lib$net." >& 4 
+						echo "Found Berkeley sockets interface in lib$net." >&4 
 						if $contains setsockopt libc.list >/dev/null 2>&1; then
 							d_oldsock="$undef"
 						else
@@ -8895,7 +9508,7 @@ eval $inlibc
 
 
 echo " "
-echo "Checking the availability of certain socket constants..." >& 4
+echo "Checking the availability of certain socket constants..." >&4
 for ENUM in MSG_CTRUNC MSG_DONTROUTE MSG_OOB MSG_PEEK MSG_PROXY SCM_RIGHTS; do
 	enum=`$echo $ENUM|./tr '[A-Z]' '[a-z]'`
 	$cat >try.c <<EOF
@@ -8922,7 +9535,7 @@ echo " "
 if test "X$timeincl" = X; then
 	echo "Testing to see if we should include <time.h>, <sys/time.h> or both." >&4
 	$echo $n "I'm now running the test program...$c"
-	$cat >try.c <<'EOCP'
+	$cat >try.c <<EOCP
 #include <sys/types.h>
 #ifdef I_TIME
 #include <time.h>
@@ -8936,6 +9549,10 @@ if test "X$timeincl" = X; then
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
@@ -9006,7 +9623,11 @@ $cat <<EOM
 
 Checking to see how well your C compiler handles fd_set and friends ...
 EOM
-$cat >fd_set.c <<EOCP
+$cat >try.c <<EOCP
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
 #$i_systime I_SYS_TIME
 #$i_sysselct I_SYS_SELECT
 #$d_socket HAS_SOCKET
@@ -9034,12 +9655,12 @@ int main() {
 #endif
 }
 EOCP
-set fd_set -DTRYBITS
+set try -DTRYBITS
 if eval $compile; then
 	d_fds_bits="$define"
 	d_fd_set="$define"
 	echo "Well, your system knows about the normal fd_set typedef..." >&4
-	if ./fd_set; then
+	if $run ./try; then
 		echo "and you have the normal fd_set macros (just as I'd expect)." >&4
 		d_fd_macros="$define"
 	else
@@ -9052,12 +9673,12 @@ else
 	$cat <<'EOM'
 Hmm, your compiler has some difficulty with fd_set.  Checking further...
 EOM
-	set fd_set
+	set try
 	if eval $compile; then
 		d_fds_bits="$undef"
 		d_fd_set="$define"
 		echo "Well, your system has some sort of fd_set available..." >&4
-		if ./fd_set; then
+		if $run ./try; then
 			echo "and you have the normal fd_set macros." >&4
 			d_fd_macros="$define"
 		else
@@ -9073,7 +9694,7 @@ EOM
 		d_fd_macros="$undef"
 	fi
 fi
-$rm -f fd_set*
+$rm -f try try.*
 
 : see if fgetpos exists
 set fgetpos d_fgetpos
@@ -9585,9 +10206,13 @@ eval $setvar
 
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
@@ -9714,7 +10339,7 @@ int main()
 EOCP
 	set try
 	if eval $compile_ok; then
-		longlongsize=`./try$exe_ext`
+		longlongsize=`$run ./try`
 		echo "Your long longs are $longlongsize bytes long."
 	else
 		dflt='8'
@@ -9949,12 +10574,7 @@ case "$quadtype" in
 '')	echo "Alas, no 64-bit integer types in sight." >&4
 	d_quad="$undef"
 	;;
-*)	if test X"$use64bitint" = Xdefine -o X"$longsize" = X8; then
-	    verb="will"
-	else
-	    verb="could"
-	fi
-	echo "We $verb use '$quadtype' for 64-bit integers." >&4
+*)	echo "We could use '$quadtype' for 64-bit integers." >&4
 	d_quad="$define"
 	;;
 esac
@@ -9964,8 +10584,12 @@ echo " "
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
@@ -9974,7 +10598,7 @@ int main()
 EOCP
 	set try
 	if eval $compile_ok; then
-		dflt=`./try`
+		dflt=`$run ./try`
 	else
 		dflt='1'
 		echo "(I can't seem to compile the test program.  Guessing...)"
@@ -10059,7 +10683,7 @@ esac
 case "$i8type" in
 '')	set try -DINT8
 	if eval $compile; then
-		case "`./try$exe_ext`" in
+		case "`$run ./try`" in
 		int8_t)	i8type=int8_t
 			u8type=uint8_t
 			i8size=1
@@ -10092,7 +10716,7 @@ esac
 case "$i16type" in
 '')	set try -DINT16
 	if eval $compile; then
-		case "`./try$exe_ext`" in
+		case "`$run ./try`" in
 		int16_t)
 			i16type=int16_t
 			u16type=uint16_t
@@ -10134,7 +10758,7 @@ esac
 case "$i32type" in
 '')	set try -DINT32
 	if eval $compile; then
-		case "`./try$exe_ext`" in
+		case "`$run ./try`" in
 		int32_t)
 			i32type=int32_t
 			u32type=uint32_t
@@ -11170,6 +11794,10 @@ if set sigaction val -f d_sigaction; eval $csym; $val; then
 	echo 'sigaction() found.' >&4
 	$cat > try.c <<'EOP'
 #include <stdio.h>
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
 #include <sys/types.h>
 #include <signal.h>
 int main()
@@ -11199,8 +11827,12 @@ $rm -f try try$_o try.c
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
@@ -11214,7 +11846,7 @@ int main()
 EOP
 	set try
 	if eval $compile; then
-		if ./try >/dev/null 2>&1; then
+		if $run ./try >/dev/null 2>&1; then
 			echo "POSIX sigsetjmp found." >&4
 			val="$define"
 		else
@@ -11337,6 +11969,10 @@ fi
 echo "Checking how std your stdio is..." >&4
 $cat >try.c <<EOP
 #include <stdio.h>
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
 #define FILE_ptr(fp)	$stdio_ptr
 #define FILE_cnt(fp)	$stdio_cnt
 int main() {
@@ -11352,8 +11988,8 @@ int main() {
 EOP
 val="$undef"
 set try
-if eval $compile; then
-	if ./try; then
+if eval $compile && $to try.c; then
+	if $run ./try; then
 		echo "Your stdio acts pretty std."
 		val="$define"
 	else
@@ -11363,6 +11999,26 @@ else
 	echo "Your stdio doesn't appear very std."
 fi
 $rm -f try.c try
+
+# glibc 2.2.90 and above apparently change stdio streams so Perl's
+# direct buffer manipulation no longer works.  The Configure tests
+# should be changed to correctly detect this, but until then,
+# the following check should at least let perl compile and run.
+# (This quick fix should be updated before 5.8.1.)
+# To be defensive, reject all unknown versions, and all versions  > 2.2.9.
+# A. Dougherty, June 3, 2002.
+case "$d_gnulibc" in
+$define)
+	case "$gnulibc_version" in
+	2.[01]*)  ;;
+	2.2) ;;
+	2.2.[0-9]) ;;
+	*)  echo "But I will not snoop inside glibc $gnulibc_version stdio buffers."
+		val="$undef"
+		;;
+	esac
+	;;
+esac
 set d_stdstdio
 eval $setvar
 
@@ -11388,6 +12044,10 @@ case "$d_stdstdio" in
 $define)
 	$cat >try.c <<EOP
 #include <stdio.h>
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
 #define FILE_base(fp)	$stdio_base
 #define FILE_bufsiz(fp)	$stdio_bufsiz
 int main() {
@@ -11402,8 +12062,8 @@ int main() {
 }
 EOP
 	set try
-	if eval $compile; then
-		if ./try; then
+	if eval $compile && $to try.c; then
+		if $run ./try; then
 			echo "And its _base field acts std."
 			val="$define"
 		else
@@ -11433,7 +12093,7 @@ EOCP
 	do
 	        set try -DSTDIO_STREAM_ARRAY=$s
 		if eval $compile; then
-		    	case "`./try$exe_ext`" in
+		    	case "`$run ./try`" in
 			yes)	stdio_stream_array=$s; break ;;
 			esac
 		fi
@@ -11623,7 +12283,7 @@ int main() {
 EOCP
 	set try
 	if eval $compile; then
-		case "`./try`" in
+		case "`$run ./try`" in
 		ok) echo "Your strtoull() seems to be working okay." ;;
 		*) cat <<EOM >&4
 Your strtoull() doesn't seem to be working okay.
@@ -11639,6 +12299,54 @@ esac
 set strtouq d_strtouq
 eval $inlibc
 
+case "$d_strtouq" in
+"$define")
+	$cat <<EOM
+Checking whether your strtouq() works okay...
+EOM
+	$cat >try.c <<'EOCP'
+#include <errno.h>
+#include <stdio.h>
+extern unsigned long long int strtouq(char *s, char **, int); 
+static int bad = 0;
+void check(char *s, unsigned long long eull, int een) {
+	unsigned long long gull;
+	errno = 0;
+	gull = strtouq(s, 0, 10);
+	if (!((gull == eull) && (errno == een)))
+		bad++;
+}
+int main() {
+	check(" 1",                                        1LL, 0);
+	check(" 0",                                        0LL, 0);
+	check("18446744073709551615",  18446744073709551615ULL, 0);
+	check("18446744073709551616",  18446744073709551615ULL, ERANGE);
+#if 0 /* strtouq() for /^-/ strings is undefined. */
+	check("-1",                    18446744073709551615ULL, 0);
+	check("-18446744073709551614",                     2LL, 0);
+	check("-18446744073709551615",                     1LL, 0);
+       	check("-18446744073709551616", 18446744073709551615ULL, ERANGE);
+	check("-18446744073709551617", 18446744073709551615ULL, ERANGE);
+#endif
+	if (!bad)
+		printf("ok\n");
+	return 0;
+}
+EOCP
+	set try
+	if eval $compile; then
+		case "`$run ./try`" in
+		ok) echo "Your strtouq() seems to be working okay." ;;
+		*) cat <<EOM >&4
+Your strtouq() doesn't seem to be working okay.
+EOM
+		   d_strtouq="$undef"
+		   ;;
+		esac
+	fi
+	;;
+esac
+
 : see if strxfrm exists
 set strxfrm d_strxfrm
 eval $inlibc
@@ -11780,7 +12488,7 @@ case "$d_closedir" in
 "$define")
 	echo " "
 	echo "Checking whether closedir() returns a status..." >&4
-	cat > closedir.c <<EOM
+	cat > try.c <<EOM
 #$i_dirent I_DIRENT		/**/
 #$i_sysdir I_SYS_DIR		/**/
 #$i_sysndir I_SYS_NDIR		/**/
@@ -11809,9 +12517,9 @@ case "$d_closedir" in
 #endif 
 int main() { return closedir(opendir(".")); }
 EOM
-	set closedir
+	set try
 	if eval $compile_ok; then
-		if ./closedir > /dev/null 2>&1 ; then
+		if $run ./try > /dev/null 2>&1 ; then
 			echo "Yes, it does."
 			val="$undef"
 		else
@@ -11934,7 +12642,7 @@ int main()
 EOCP
 		set try
 		if eval $compile_ok; then
-			dflt=`./try`
+			dflt=`$run ./try`
 		else
 			dflt='8'
 			echo "(I can't seem to compile the test program...)"
@@ -11954,16 +12662,16 @@ esac
 : set the base revision
 baserev=5.0
 
-: check for ordering of bytes in a long
+: check for ordering of bytes in a UV
 echo " "
-case "$crosscompile$multiarch" in
+case "$usecrosscompile$multiarch" in
 *$define*)
 	$cat <<EOM
 You seem to be either cross-compiling or doing a multiarchitecture build,
 skipping the byteorder check.
 
 EOM
-	byteorder='0xffff'
+	byteorder='ffff'
 	;;
 *)
 	case "$byteorder" in
@@ -11977,21 +12685,27 @@ an Alpha will report 12345678. If the test program works the default is
 probably right.
 I'm now running the test program...
 EOM
-		$cat >try.c <<'EOCP'
+		$cat >try.c <<EOCP
 #include <stdio.h>
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
+#include <sys/types.h>
+typedef $uvtype UV;
 int main()
 {
 	int i;
 	union {
-		unsigned long l;
-		char c[sizeof(long)];
+		UV l;
+		char c[$uvsize];
 	} u;
 
-	if (sizeof(long) > 4)
-		u.l = (0x08070605L << 32) | 0x04030201L;
+	if ($uvsize > 4)
+		u.l = (((UV)0x08070605) << 32) | (UV)0x04030201;
 	else
-		u.l = 0x04030201L;
-	for (i = 0; i < sizeof(long); i++)
+		u.l = (UV)0x04030201;
+	for (i = 0; i < $uvsize; i++)
 		printf("%c", u.c[i]+'0');
 	printf("\n");
 	exit(0);
@@ -12000,7 +12714,7 @@ EOCP
 		xxx_prompt=y
 		set try
 		if eval $compile && ./try > /dev/null; then
-			dflt=`./try`
+			dflt=`$run ./try`
 			case "$dflt" in
 			[1-4][1-4][1-4][1-4]|12345678|87654321)
 				echo "(The test program ran ok.)"
@@ -12018,7 +12732,7 @@ EOM
 		fi
 		case "$xxx_prompt" in
 		y)
-			rp="What is the order of bytes in a long?"
+			rp="What is the order of bytes in $uvtype?"
 			. ./myread
 			byteorder="$ans"
 			;;
@@ -12076,8 +12790,12 @@ $define)
 #endif
 #include <sys/types.h>
 #include <stdio.h>
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
 #include <db3/db.h>
-int main()
+int main(int argc, char *argv[])
 {
 #ifdef DB_VERSION_MAJOR	/* DB version >= 2 */
     int Major, Minor, Patch ;
@@ -12092,11 +12810,11 @@ int main()
 
     /* check that db.h & libdb are compatible */
     if (DB_VERSION_MAJOR != Major || DB_VERSION_MINOR != Minor || DB_VERSION_PATCH != Patch) {
-	printf("db.h and libdb are incompatible\n") ;
+	printf("db.h and libdb are incompatible.\n") ;
         exit(3);	
     }
 
-    printf("db.h and libdb are compatible\n") ;
+    printf("db.h and libdb are compatible.\n") ;
 
     Version = DB_VERSION_MAJOR * 1000000 + DB_VERSION_MINOR * 1000
 		+ DB_VERSION_PATCH ;
@@ -12236,7 +12954,11 @@ echo " "
 echo "Checking to see how well your C compiler groks the void type..." >&4
 case "$voidflags" in
 '')
-	$cat >try.c <<'EOCP'
+	$cat >try.c <<EOCP
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
 #if TRY & 1
 void sub() {
 #else
@@ -12456,7 +13178,7 @@ done
 
 echo " "
 echo "Determining whether or not we are on an EBCDIC system..." >&4
-$cat >tebcdic.c <<'EOM'
+$cat >try.c <<'EOM'
 int main()
 {
   if ('M'==0xd4) return 0;
@@ -12492,6 +13214,10 @@ sunos) $echo '#define PERL_FFLUSH_ALL_FOPEN_MAX 32' > try.c ;;
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
@@ -12502,7 +13228,9 @@ $cat >>try.c <<EOCP
 # define STDIO_STREAM_ARRAY $stdio_stream_array
 #endif
 int main() {
-  FILE* p = fopen("try.out", "w");
+  FILE* p;
+  unlink("try.out");
+  p = fopen("try.out", "w");
 #ifdef TRY_FPUTC
   fputc('x', p);
 #else
@@ -12551,24 +13279,26 @@ int main() {
 }
 EOCP
 : first we have to find out how _not_ to flush
+$to try.c
 if $test "X$fflushNULL" = X -o "X$fflushall" = X; then
     output=''
     set try -DTRY_FPUTC
     if eval $compile; then
-	    $rm -f try.out
- 	    ./try$exe_ext 2>/dev/null
-	    if $test ! -s try.out -a "X$?" = X42; then
+ 	    $run ./try 2>/dev/null
+	    code="$?"
+	    $from try.out
+	    if $test ! -s try.out -a "X$code" = X42; then
 		output=-DTRY_FPUTC
 	    fi
     fi
     case "$output" in
     '')
 	    set try -DTRY_FPRINTF
-	    $rm -f try.out
 	    if eval $compile; then
-		    $rm -f try.out
- 		    ./try$exe_ext 2>/dev/null
-		    if $test ! -s try.out -a "X$?" = X42; then
+ 		    $run ./try 2>/dev/null
+		    code="$?"
+		    $from try.out
+		    if $test ! -s try.out -a "X$code" = X42; then
 			output=-DTRY_FPRINTF
 		    fi
 	    fi
@@ -12579,9 +13309,9 @@ fi
 case "$fflushNULL" in
 '') 	set try -DTRY_FFLUSH_NULL $output
 	if eval $compile; then
-	        $rm -f try.out
-	    	./try$exe_ext 2>/dev/null
+	    	$run ./try 2>/dev/null
 		code="$?"
+		$from try.out
 		if $test -s try.out -a "X$code" = X42; then
 			fflushNULL="`$cat try.out`"
 		else
@@ -12627,7 +13357,7 @@ EOCP
                 set tryp
                 if eval $compile; then
                     $rm -f tryp.out
-                    $cat tryp.c | ./tryp$exe_ext 2>/dev/null > tryp.out
+                    $cat tryp.c | $run ./tryp 2>/dev/null > tryp.out
                     if cmp tryp.c tryp.out >/dev/null 2>&1; then
                        $cat >&4 <<EOM
 fflush(NULL) seems to behave okay with input streams.
@@ -12691,7 +13421,7 @@ EOCP
 	set tryp
 	if eval $compile; then
 	    $rm -f tryp.out
-	    $cat tryp.c | ./tryp$exe_ext 2>/dev/null > tryp.out
+	    $cat tryp.c | $run ./tryp 2>/dev/null > tryp.out
 	    if cmp tryp.c tryp.out >/dev/null 2>&1; then
 	       $cat >&4 <<EOM
 Good, at least fflush(stdin) seems to behave okay when stdin is a pipe.
@@ -12703,9 +13433,10 @@ EOM
 				$cat >&4 <<EOM
 (Now testing the other method--but note that this also may fail.)
 EOM
-				$rm -f try.out
-				./try$exe_ext 2>/dev/null
-				if $test -s try.out -a "X$?" = X42; then
+				$run ./try 2>/dev/null
+				code=$?
+				$from try.out
+				if $test -s try.out -a "X$code" = X42; then
 					fflushall="`$cat try.out`"
 				fi
 			fi
@@ -12803,6 +13534,10 @@ echo "Checking the size of $zzz..." >&4
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
@@ -12810,7 +13545,7 @@ int main() {
 EOCP
 set try
 if eval $compile_ok; then
-	yyy=`./try`
+	yyy=`$run ./try`
 	case "$yyy" in
 	'')	gidsize=4
 		echo "(I can't execute the test program--guessing $gidsize.)" >&4
@@ -12844,7 +13579,7 @@ int main() {
 EOCP
 set try
 if eval $compile; then
-	yyy=`./try`
+	yyy=`$run ./try`
 	case "$yyy" in
 	'')	gidsign=1
 		echo "(I can't execute the test program--guessing unsigned.)" >&4
@@ -12879,7 +13614,7 @@ int main() {
 EOCP
 	set try
 	if eval $compile; then
-		yyy=`./try$exe_ext`
+		yyy=`$run ./try`
 		case "$yyy" in
 		12345678901)
 			sPRId64='"d"'; sPRIi64='"i"'; sPRIu64='"u"';
@@ -12901,7 +13636,7 @@ int main() {
 EOCP
 	set try
 	if eval $compile; then
-		yyy=`./try$exe_ext`
+		yyy=`$run ./try`
 		case "$yyy" in
 		12345678901)
 			sPRId64='"ld"'; sPRIi64='"li"'; sPRIu64='"lu"';
@@ -12924,7 +13659,7 @@ int main() {
 EOCP
 	set try
 	if eval $compile; then
-		yyy=`./try$exe_ext`
+		yyy=`$run ./try`
 		case "$yyy" in
 		12345678901)
 			sPRId64=PRId64; sPRIi64=PRIi64; sPRIu64=PRIu64;
@@ -12990,7 +13725,7 @@ int main() {
 EOCP
 	set try
 	if eval $compile; then
-		yyy=`./try$exe_ext`
+		yyy=`$run ./try`
 		case "$yyy" in
 		12345678901)
 			sPRId64='"qd"'; sPRIi64='"qi"'; sPRIu64='"qu"';
@@ -13052,7 +13787,7 @@ else
 fi
 
 case "$ivdformat" in
-'') echo "$0: Fatal: failed to find format strings, cannot continue." >& 4
+'') echo "$0: Fatal: failed to find format strings, cannot continue." >&4
     exit 1
     ;;
 esac
@@ -13329,12 +14064,15 @@ case "$pager" in
 	dflt=''
 	case "$pg" in
 	/*) dflt=$pg;;
+	[a-zA-Z]:/*) dflt=$pg;;
 	esac
 	case "$more" in
 	/*) dflt=$more;;
+	[a-zA-Z]:/*) dflt=$more;;
 	esac
 	case "$less" in
 	/*) dflt=$less;;
+	[a-zA-Z]:/*) dflt=$less;;
 	esac
 	case "$dflt" in
 	'') dflt=/usr/ucb/more;;
@@ -13372,8 +14110,12 @@ case "$ptrsize" in
 	else
 		echo '#define VOID_PTR void *' > try.c
 	fi
-	$cat >>try.c <<'EOCP'
+	$cat >>try.c <<EOCP
 #include <stdio.h>
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
 int main()
 {
     printf("%d\n", (int)sizeof(VOID_PTR));
@@ -13382,7 +14124,7 @@ int main()
 EOCP
 	set try
 	if eval $compile_ok; then
-		ptrsize=`./try`
+		ptrsize=`$run ./try`
 		echo "Your pointers are $ptrsize bytes long."
 	else
 		dflt='4'
@@ -13395,26 +14137,58 @@ EOCP
 esac
 $rm -f try.c try
 
+case "$use64bitall" in
+"$define"|true|[yY]*)
+	case "$ptrsize" in
+	4)	cat <<EOM >&4
+
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
+
+EOM
+
+		exit 1
+		;;
+	esac
+	;;
+esac
+
+
 : see if ar generates random libraries by itself
 echo " "
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
 $cc $ccflags -c bar2.c >/dev/null 2>&1
 $cc $ccflags -c foo.c >/dev/null 2>&1
 $ar rc bar$_a bar2$_o bar1$_o >/dev/null 2>&1
-if $cc $ccflags $ldflags -o foobar foo$_o bar$_a $libs > /dev/null 2>&1 &&
-	./foobar >/dev/null 2>&1; then
+if $cc -o foobar $ccflags $ldflags foo$_o bar$_a $libs > /dev/null 2>&1 &&
+	$run ./foobar >/dev/null 2>&1; then
 	echo "$ar appears to generate random libraries itself."
 	orderlib=false
 	ranlib=":"
 elif $ar ts bar$_a >/dev/null 2>&1 &&
-	$cc $ccflags $ldflags -o foobar foo$_o bar$_a $libs > /dev/null 2>&1 &&
-	./foobar >/dev/null 2>&1; then
+	$cc -o foobar $ccflags $ldflags foo$_o bar$_a $libs > /dev/null 2>&1 &&
+	$run ./foobar >/dev/null 2>&1; then
 		echo "a table of contents needs to be added with '$ar ts'."
 		orderlib=false
 		ranlib="$ar ts"
@@ -13490,7 +14264,8 @@ esac
 
 : check for the select 'width'
 case "$selectminbits" in
-'') case "$d_select" in
+'') safebits=`expr $ptrsize \* 8`
+    case "$d_select" in
 	$define)
 		$cat <<EOM
 
@@ -13522,25 +14297,31 @@ EOM
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
@@ -13548,20 +14329,21 @@ int main() {
     t.tv_usec = 0;
     select(fd + 1, b, 0, 0, &t);
     for (i = NBITS - 1; i > fd && FD_ISSET(i, b); i--);
+    free(s);
     printf("%d\n", i + 1);
     return 0;
 }
 EOCP
 		set try
 		if eval $compile_ok; then
-			selectminbits=`./try`
+			selectminbits=`$run ./try`
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
@@ -13570,7 +14352,8 @@ EOM
 		else
 			rp='What is the minimum number of bits your select() operates on?'
 			case "$byteorder" in
-			1234|12345678)	dflt=32 ;;
+			12345678)	dflt=64 ;;
+			1234)		dflt=32 ;;
 			*)		dflt=1	;;
 			esac
 			. ./myread
@@ -13580,7 +14363,7 @@ EOM
 		$rm -f try.* try
 		;;
 	*)	: no select, so pick a harmless default
-		selectminbits='32'
+		selectminbits=$safebits
 		;;
 	esac
 	;;
@@ -13599,7 +14382,7 @@ else
 	xxx=`echo '#include <signal.h>' |
 	$cppstdin $cppminus $cppflags 2>/dev/null |
 	$grep '^[ 	]*#.*include' | 
-	$awk "{print \\$$fieldn}" | $sed 's!"!!g' | $sort | $uniq`
+	$awk "{print \\$$fieldn}" | $sed 's!"!!g' | $sed 's!\\\\\\\\!/!g' | $sort | $uniq`
 fi
 : Check this list of files to be sure we have parsed the cpp output ok.
 : This will also avoid potentially non-existent files, such 
@@ -13627,9 +14410,13 @@ xxx="$xxx SYS TERM THAW TRAP TSTP TTIN TTOU URG USR1 USR2"
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
 
@@ -13704,7 +14491,7 @@ END {
 $cat >signal.awk <<'EOP'
 BEGIN { ndups = 0 }
 $1 ~ /^NSIG$/ { nsig = $2 }
-($1 !~ /^NSIG$/) && (NF == 2) {
+($1 !~ /^NSIG$/) && (NF == 2) && ($2 ~ /^[0-9][0-9]*$/) {
     if ($2 > maxsig) { maxsig = $2 }
     if (sig_name[$2]) {
 	dup_name[ndups] = $1
@@ -13746,13 +14533,13 @@ $cat >>signal_cmd <<'EOS'
 
 set signal
 if eval $compile_ok; then
-	./signal$_exe | ($sort -n -k 2 2>/dev/null || $sort -n +1) | $uniq | $awk -f signal.awk >signal.lst
+	$run ./signal$_exe | ($sort -n -k 2 2>/dev/null || $sort -n +1) | $uniq | $awk -f signal.awk >signal.lst
 else
 	echo "(I can't seem be able to compile the whole test program)" >&4
 	echo "(I'll try it in little pieces.)" >&4
 	set signal -DJUST_NSIG
 	if eval $compile_ok; then
-		./signal$_exe > signal.nsg
+		$run ./signal$_exe > signal.nsg
 		$cat signal.nsg
 	else
 		echo "I can't seem to figure out how many signals you have." >&4
@@ -13773,14 +14560,14 @@ EOCP
 		set signal
 		if eval $compile; then
 			echo "SIG${xx} found."
-			./signal$_exe  >> signal.ls1
+			$run ./signal$_exe  >> signal.ls1
 		else
 			echo "SIG${xx} NOT found."
 		fi
 	done
 	if $test -s signal.ls1; then
 		$cat signal.nsg signal.ls1 |
-			($sort -n -k 2 2>/dev/null || $sort -n +1) | $uniq | $awk -f signal.awk >signal.lst
+			$sort -n | $uniq | $awk -f signal.awk >signal.lst
 	fi
 
 fi
@@ -13856,6 +14643,10 @@ echo "Checking the size of $zzz..." >&4
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
@@ -13863,7 +14654,7 @@ int main() {
 EOCP
 set try
 if eval $compile_ok; then
-	yyy=`./try`
+	yyy=`$run ./try`
 	case "$yyy" in
 	'')	sizesize=4
 		echo "(I can't execute the test program--guessing $sizesize.)" >&4
@@ -13904,6 +14695,10 @@ $rm -f try try.*
 set d_socklen_t
 eval $setvar
 
+: see if this is a socks.h system
+set socks.h i_socks
+eval $inhdr
+
 : check for type of the size argument to socket calls
 case "$d_socket" in
 "$define")
@@ -13911,7 +14706,6 @@ case "$d_socket" in
 
 Checking to see what type is the last argument of accept().
 EOM
-	hdrs="$define sys/types.h $d_socket sys/socket.h" 
 	yyy=''
 	case "$d_socklen_t" in
 	"$define") yyy="$yyy socklen_t"
@@ -13920,12 +14714,21 @@ EOM
 	for xxx in $yyy; do
 		case "$socksizetype" in
 		'')	try="extern int accept(int, struct sockaddr *, $xxx *);"
-			if ./protochk "$try" $hdrs; then
+			case "$usesocks" in
+			"$define")
+				if ./protochk "$try" $i_systypes sys/types.h $d_socket sys/socket.h literal '#define INCLUDE_PROTOTYPES' $i_socks socks.h.; then
+					echo "Your system accepts '$xxx *' for the last argument of accept()."
+					socksizetype="$xxx"
+				fi
+				;;
+			*)	if ./protochk "$try"  $i_systypes sys/types.h $d_socket sys/socket.h; then
 				echo "Your system accepts '$xxx *' for the last argument of accept()."
 				socksizetype="$xxx"
 			fi
 			;;
 		esac
+			;;
+		esac
 	done
 : In case none of those worked, prompt the user.
 	case "$socksizetype" in
@@ -13945,8 +14748,12 @@ esac
 set ssize_t ssizetype int stdio.h sys/types.h
 eval $typedef
 dflt="$ssizetype"
-$cat > ssize.c <<EOM
+$cat > try.c <<EOM
 #include <stdio.h>
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
 #include <sys/types.h>
 #define Size_t $sizetype
 #define SSize_t $dflt
@@ -13962,9 +14769,9 @@ int main()
 }
 EOM
 echo " "
-set ssize
-if eval $compile_ok && ./ssize > /dev/null; then
-	ssizetype=`./ssize`
+set try
+if eval $compile_ok && $run ./try > /dev/null; then
+	ssizetype=`$run ./try`
 	echo "I'll be using $ssizetype for functions returning a byte count." >&4
 else
 	$cat >&4 <<EOM
@@ -13980,17 +14787,19 @@ EOM
 	. ./myread
 	ssizetype="$ans"
 fi
-$rm -f ssize ssize.*
+$rm -f try try.*
 
 : see what type of char stdio uses.
 echo " "
-if $contains 'unsigned.*char.*_ptr;' `./findhdr stdio.h` >/dev/null 2>&1 ; then
+echo '#include <stdio.h>' | $cppstdin $cppminus > stdioh
+if $contains 'unsigned.*char.*_ptr;' stdioh >/dev/null 2>&1 ; then
 	echo "Your stdio uses unsigned chars." >&4
 	stdchar="unsigned char"
 else
 	echo "Your stdio uses signed chars." >&4
 	stdchar="char"
 fi
+$rm -f stdioh
 
 : see if time exists
 echo " "
@@ -14043,6 +14852,10 @@ echo "Checking the size of $zzz..." >&4
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
@@ -14050,7 +14863,7 @@ int main() {
 EOCP
 set try
 if eval $compile_ok; then
-	yyy=`./try`
+	yyy=`$run ./try`
 	case "$yyy" in
 	'')	uidsize=4
 		echo "(I can't execute the test program--guessing $uidsize.)" >&4
@@ -14083,7 +14896,7 @@ int main() {
 EOCP
 set try
 if eval $compile; then
-	yyy=`./try`
+	yyy=`$run ./try`
 	case "$yyy" in
 	'')	uidsign=1
 		echo "(I can't execute the test program--guessing unsigned.)" >&4
@@ -14256,6 +15069,20 @@ eval $inhdr
 : see if ndbm.h is available
 set ndbm.h t_ndbm
 eval $inhdr
+
+case "$t_ndbm" in
+$undef)
+    # Some Linux distributions such as RedHat 7.1 put the
+    # ndbm.h header in /usr/include/gdbm/ndbm.h.
+    if $test -f /usr/include/gdbm/ndbm.h; then
+	echo '<gdbm/ndbm.h> found.'
+        ccflags="$ccflags -I/usr/include/gdbm"
+        cppflags="$cppflags -I/usr/include/gdbm"
+        t_ndbm=$define
+    fi
+    ;;
+esac
+
 case "$t_ndbm" in
 $define)
 	: see if dbm_open exists
@@ -14378,8 +15205,9 @@ $osname
 EOSH
 ./tr '[a-z]' '[A-Z]' < Cppsym.know > Cppsym.a
 ./tr '[A-Z]' '[a-z]' < Cppsym.know > Cppsym.b
-$cat Cppsym.a Cppsym.b | $tr ' ' $trnl | sort | uniq > Cppsym.know
-$rm -f Cppsym.a Cppsym.b
+$cat Cppsym.know > Cppsym.c
+$cat Cppsym.a Cppsym.b Cppsym.c | $tr ' ' $trnl | $sort | $uniq > Cppsym.know
+$rm -f Cppsym.a Cppsym.b Cppsym.c
 cat <<EOSH > Cppsym
 $startsh
 if $test \$# -gt 0; then
@@ -14407,19 +15235,20 @@ $awk \\
 EOSH
 cat <<'EOSH' >> Cppsym.try
 'length($1) > 0 {
-    printf "#ifdef %s\n#if %s+0\nprintf(\"%s=%%ld\\n\", %s);\n#else\nprintf(\"%s\\n\");\n#endif\n#endif\n", $1, $1, $1, $1, $1
-    printf "#ifdef _%s\n#if _%s+0\nprintf(\"_%s=%%ld\\n\", _%s);\n#else\nprintf(\"_%s\\n\");\n#endif\n#endif\n", $1, $1, $1, $1, $1
-    printf "#ifdef __%s\n#if __%s+0\nprintf(\"__%s=%%ld\\n\", __%s);\n#else\nprintf(\"__%s\\n\");\n#endif\n#endif\n", $1, $1, $1, $1, $1
-    printf "#ifdef __%s__\n#if __%s__+0\nprintf(\"__%s__=%%ld\\n\", __%s__);\n#else\nprintf(\"__%s__\\n\");\n#endif\n#endif\n", $1, $1, $1, $1, $1
+    printf "#ifdef %s\n#if %s+0\nprintf(\"%s=%%ld\\n\", (long)%s);\n#else\nprintf(\"%s\\n\");\n#endif\n#endif\n", $1, $1, $1, $1, $1
+    printf "#ifdef _%s\n#if _%s+0\nprintf(\"_%s=%%ld\\n\", (long)_%s);\n#else\nprintf(\"_%s\\n\");\n#endif\n#endif\n", $1, $1, $1, $1, $1
+    printf "#ifdef __%s\n#if __%s+0\nprintf(\"__%s=%%ld\\n\", (long)__%s);\n#else\nprintf(\"__%s\\n\");\n#endif\n#endif\n", $1, $1, $1, $1, $1
+    printf "#ifdef __%s__\n#if __%s__+0\nprintf(\"__%s__=%%ld\\n\", (long)__%s__);\n#else\nprintf(\"__%s__\\n\");\n#endif\n#endif\n", $1, $1, $1, $1, $1
 }'	 >> try.c
-echo '}' >> try.c
+echo 'return 0;}' >> try.c
 EOSH
 cat <<EOSH >> Cppsym.try
 ccflags="$ccflags"
 case "$osname-$gccversion" in
 irix-) ccflags="\$ccflags -woff 1178" ;;
+os2-*) ccflags="\$ccflags -Zlinker /PM:VIO" ;;
 esac
-$cc $optimize \$ccflags $ldflags -o try try.c $libs && ./try$exe_ext
+$cc -o try $optimize \$ccflags $ldflags try.c $libs && $run ./try
 EOSH
 chmod +x Cppsym.try
 $eunicefix Cppsym.try
@@ -14438,7 +15267,7 @@ for i in \`$cc -v -c tmp.c 2>&1 $postprocess_cc_v\`
 do
 	case "\$i" in
 	-D*) echo "\$i" | $sed 's/^-D//';;
-	-A*) $test "$gccversion" && echo "\$i" | $sed 's/^-A\(.*\)(\(.*\))/\1=\2/';;
+	-A*) $test "$gccversion" && echo "\$i" | $sed 's/^-A//' | $sed 's/\(.*\)(\(.*\))/\1=\2/';;
 	esac
 done
 $rm -f try.c
@@ -14473,7 +15302,7 @@ if $test -z ccsym.raw; then
 else
 	if $test -s ccsym.com; then
 		echo "Your C compiler and pre-processor define these symbols:"
-		$sed -e 's/\(.*\)=.*/\1/' ccsym.com
+		$sed -e 's/\(..*\)=.*/\1/' ccsym.com
 		also='also '
 		symbols='ones'
 		cppccsymbols=`$cat ccsym.com`
@@ -14483,7 +15312,7 @@ else
 	if $test -s ccsym.cpp; then
 		$test "$also" && echo " "
 		echo "Your C pre-processor ${also}defines the following symbols:"
-		$sed -e 's/\(.*\)=.*/\1/' ccsym.cpp
+		$sed -e 's/\(..*\)=.*/\1/' ccsym.cpp
 		also='further '
 		cppsymbols=`$cat ccsym.cpp`
 		cppsymbols=`echo $cppsymbols`
@@ -14492,14 +15321,14 @@ else
 	if $test -s ccsym.own; then
 		$test "$also" && echo " "
 		echo "Your C compiler ${also}defines the following cpp symbols:"
-		$sed -e 's/\(.*\)=1/\1/' ccsym.own
-		$sed -e 's/\(.*\)=.*/\1/' ccsym.own | $uniq >>Cppsym.true
+		$sed -e 's/\(..*\)=1/\1/' ccsym.own
+		$sed -e 's/\(..*\)=.*/\1/' ccsym.own | $uniq >>Cppsym.true
 	        ccsymbols=`$cat ccsym.own`
 	        ccsymbols=`echo $ccsymbols`
 		$test "$silent" || sleep 1
 	fi
 fi
-$rm -f ccsym*
+$rm -f ccsym* Cppsym.*
 
 : see if this is a termio system
 val="$undef"
@@ -14802,7 +15631,7 @@ find_extensions='
            else
                if $test -d $xxx -a $# -lt 10; then
                    set $1$xxx/ $*;
-                   cd $xxx;
+                   cd "$xxx";
                    eval $find_extensions;
                    cd ..;
                    shift;
@@ -14812,17 +15641,21 @@ find_extensions='
        esac;
     done'
 tdir=`pwd`
-cd $rsrc/ext
+cd "$rsrc/ext"
 set X
 shift
 eval $find_extensions
+# Special case:  Add in threads/shared since it is not picked up by the
+# recursive find above (and adding in general recursive finding breaks
+# SDBM_File/sdbm).  A.D.  10/25/2001.
+known_extensions="$known_extensions threads/shared"
 set X $nonxs_extensions
 shift
 nonxs_extensions="$*"
 set X $known_extensions
 shift
 known_extensions="$*"
-cd $tdir
+cd "$tdir"
 
 : Now see which are supported on this system.
 avail_ext=''
PATCH
}

1;
