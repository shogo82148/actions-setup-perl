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
@@ -2271,6 +2276,250 @@ $define|true|[yY]*)
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
@@ -3124,7 +3373,7 @@ fi
 
 echo " "
 echo "Checking for GNU cc in disguise and/or its version number..." >&4
-$cat >gccvers.c <<EOM
+$cat >try.c <<EOM
 #include <stdio.h>
 int main() {
 #ifdef __GNUC__
@@ -3134,11 +3383,11 @@ int main() {
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
@@ -3156,7 +3405,7 @@ else
 		;;
 	esac
 fi
-$rm -f gccvers*
+$rm -f try try.*
 case "$gccversion" in
 1.*) cpp=`./loc gcc-cpp $cpp $pth` ;;
 esac
@@ -3851,7 +4100,7 @@ for thislib in $libswanted; do
 	for thisdir in $libspath; do
 	    xxx=''
 	    if $test ! -f "$xxx" -a "X$ignore_versioned_solibs" = "X"; then
-		xxx=`ls $thisdir/lib$thislib.$so.[0-9] 2>/dev/null|tail -1`
+		xxx=`ls $thisdir/lib$thislib.$so.[0-9] 2>/dev/null|sed -n '$p'`
 	        $test -f "$xxx" && eval $libscheck
 		$test -f "$xxx" && libstyle=shared
 	    fi
@@ -4063,7 +4312,10 @@ none) ccflags='';;
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
@@ -4171,7 +4423,7 @@ echo " "
 echo "Checking your choice of C compiler and flags for coherency..." >&4
 $cat > try.c <<'EOF'
 #include <stdio.h>
-int main() { printf("Ok\n"); exit(0); }
+int main() { printf("Ok\n"); return(0); }
 EOF
 set X $cc -o try $optimize $ccflags $ldflags try.c $libs
 shift
@@ -4186,15 +4438,15 @@ $cat >> try.msg <<EOM
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
@@ -4311,13 +4563,130 @@ mc_file=$1;
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
@@ -4326,9 +4695,9 @@ int main()
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
@@ -4401,6 +4770,10 @@ echo "Checking the size of $zzz..." >&4
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
@@ -4716,26 +5089,43 @@ esac
 
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
 
@@ -5241,8 +5631,12 @@ echo " "
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
@@ -5251,7 +5645,7 @@ int main()
 EOCP
 	set try
 	if eval $compile_ok; then
-		doublesize=`./try`
+		doublesize=`$run ./try`
 		echo "Your double is $doublesize bytes long."
 	else
 		dflt='8'
@@ -5295,7 +5689,7 @@ EOCP
 	set try
 	set try
 	if eval $compile; then
-		longdblsize=`./try$exe_ext`
+		longdblsize=`$run ./try`
 		echo "Your long doubles are $longdblsize bytes long."
 	else
 		dflt='8'
@@ -5306,7 +5700,9 @@ EOCP
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
@@ -5935,15 +6331,16 @@ $rm -f try.c try
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
@@ -6275,7 +6672,11 @@ eval $setvar
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
@@ -6585,6 +6986,7 @@ EOM
 		    esac
 			;;
 		*)  case "$osname" in
+	                darwin) dflt='none' ;;
 			svr4*|esix*|solaris|nonstopux) dflt='-fPIC' ;;
 			*)	dflt='-fpic' ;;
 		    esac ;;
@@ -6606,10 +7008,13 @@ while other systems (such as those using ELF) use $cc.
 
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
@@ -6621,7 +7026,7 @@ int main() {
 		exit(1); /* fail */
 }
 EOM
-		if $cc $ccflags try.c >/dev/null 2>&1 && ./a.out; then
+		if $cc $ccflags $ldflags try.c >/dev/null 2>&1 && $run ./a.out; then
 			cat <<EOM
 You appear to have ELF support.  I'll use $cc to build dynamic libraries.
 EOM
@@ -8001,7 +8406,7 @@ eval $inlibc
 case "$d_access" in
 "$define")
 	echo " "
-	$cat >access.c <<'EOCP'
+	$cat >access.c <<EOCP
 #include <sys/types.h>
 #ifdef I_FCNTL
 #include <fcntl.h>
@@ -8012,6 +8417,10 @@ case "$d_access" in
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
@@ -8056,7 +8465,7 @@ echo " "
 echo "Checking whether your compiler can handle __attribute__ ..." >&4
 $cat >attrib.c <<'EOCP'
 #include <stdio.h>
-void croak (char* pat,...) __attribute__((format(printf,1,2),noreturn));
+void croak (char* pat,...) __attribute__((__format__(__printf__,1,2),noreturn));
 EOCP
 if $cc $ccflags -c attrib.c >attrib.out 2>&1 ; then
 	if $contains 'warning' attrib.out >/dev/null 2>&1; then
@@ -8267,6 +8676,10 @@ else
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
@@ -8321,6 +8734,10 @@ echo " "
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
@@ -8445,6 +8862,7 @@ else
 		val="$undef"
 		val2="$undef"
 fi
+$rm -f try try.*
 set d_vprintf
 eval $setvar
 val=$val2
@@ -8815,7 +9233,7 @@ eval $inlibc
 
 : Locate the flags for 'open()'
 echo " "
-$cat >open3.c <<'EOCP'
+$cat >try.c <<EOCP
 #include <sys/types.h>
 #ifdef I_FCNTL
 #include <fcntl.h>
@@ -8823,6 +9241,10 @@ $cat >open3.c <<'EOCP'
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
@@ -8834,10 +9256,10 @@ int main() {
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
@@ -8845,10 +9267,10 @@ if $test `./findhdr sys/file.h` && \
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
@@ -8861,7 +9283,7 @@ else
 fi
 set d_open3
 eval $setvar
-$rm -f open3*
+$rm -f try try.*
 
 : see which of string.h or strings.h is needed
 echo " "
@@ -8885,6 +9307,35 @@ case "$i_string" in
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
@@ -8900,8 +9351,16 @@ echo "Figuring out the flag used by open() for non-blocking I/O..." >&4
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
@@ -8920,7 +9379,7 @@ int main() {
 EOCP
 	set try
 	if eval $compile_ok; then
-		o_nonblock=`./try`
+		o_nonblock=`$run ./try`
 		case "$o_nonblock" in
 		'') echo "I can't figure it out, assuming O_NONBLOCK will do.";;
 		*) echo "Seems like we can use $o_nonblock.";;
@@ -8943,6 +9402,14 @@ case "$eagain" in
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
@@ -9003,7 +9470,7 @@ int main()
 		ret = read(pd[0], buf, 1);	/* Should read EOF */
 		alarm(0);
 		sprintf(string, "%d\n", ret);
-		write(3, string, strlen(string));
+		write(4, string, strlen(string));
 		exit(0);
 	}
 
@@ -9017,7 +9484,7 @@ EOCP
 	set try
 	if eval $compile_ok; then
 		echo "$startsh" >mtry
-		echo "./try >try.out 2>try.ret 3>try.err || exit 4" >>mtry
+		echo "$run ./try >try.out 2>try.ret 4>try.err || exit 4" >>mtry
 		chmod +x mtry
 		./mtry >/dev/null 2>&1
 		case $? in
@@ -10315,8 +10782,12 @@ echo " "
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
@@ -11603,10 +12074,14 @@ echo " "
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
@@ -11634,8 +12109,12 @@ $rm -f try try$_o try.c
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
@@ -11649,7 +12128,7 @@ int main()
 EOP
 	set try
 	if eval $compile; then
-		if ./try >/dev/null 2>&1; then
+		if $run ./try >/dev/null 2>&1; then
 			echo "POSIX sigsetjmp found." >&4
 			val="$define"
 		else
@@ -11981,7 +12460,7 @@ EOCP
 	do
 	        set try -DSTDIO_STREAM_ARRAY=$s
 		if eval $compile; then
-		    	case "`./try$exe_ext`" in
+		    	case "`$run ./try`" in
 			yes)	stdio_stream_array=$s; break ;;
 			esac
 		fi
@@ -12458,7 +12937,7 @@ int main()
 EOCP
 		set try
 		if eval $compile_ok; then
-			dflt=`./try`
+			dflt=`$run ./try`
 		else
 			dflt='8'
 			echo "(I can't seem to compile the test program...)"
@@ -12600,14 +13079,24 @@ $define)
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
@@ -12616,11 +13105,11 @@ int main()
 
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
@@ -12628,26 +13117,34 @@ int main()
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
@@ -12675,7 +13172,7 @@ define)
 #define const
 #endif
 #include <sys/types.h>
-#include <db.h>
+#include <db3/db.h>
 
 #ifndef DB_VERSION_MAJOR
 u_int32_t hash_cb (ptr, size)
@@ -12720,7 +13217,7 @@ define)
 #define const
 #endif
 #include <sys/types.h>
-#include <db.h>
+#include <db3/db.h>
 
 #ifndef DB_VERSION_MAJOR
 size_t prefix_cb (key1, key2)
@@ -13016,6 +13513,10 @@ sunos) $echo '#define PERL_FFLUSH_ALL_FOPEN_MAX 32' > try.c ;;
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
@@ -13026,7 +13527,9 @@ $cat >>try.c <<EOCP
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
@@ -13075,24 +13578,26 @@ int main() {
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
@@ -13103,9 +13608,9 @@ fi
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
@@ -13151,7 +13656,7 @@ EOCP
                 set tryp
                 if eval $compile; then
                     $rm -f tryp.out
-                    $cat tryp.c | ./tryp$exe_ext 2>/dev/null > tryp.out
+                    $cat tryp.c | $run ./tryp 2>/dev/null > tryp.out
                     if cmp tryp.c tryp.out >/dev/null 2>&1; then
                        $cat >&4 <<EOM
 fflush(NULL) seems to behave okay with input streams.
@@ -13327,6 +13832,10 @@ echo "Checking the size of $zzz..." >&4
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
@@ -13334,7 +13843,7 @@ int main() {
 EOCP
 set try
 if eval $compile_ok; then
-	yyy=`./try`
+	yyy=`$run ./try`
 	case "$yyy" in
 	'')	gidsize=4
 		echo "(I can't execute the test program--guessing $gidsize.)" >&4
@@ -13919,8 +14428,12 @@ case "$ptrsize" in
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
@@ -13947,7 +14460,11 @@ echo " "
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
@@ -13955,13 +14472,13 @@ $cc $ccflags -c bar2.c >/dev/null 2>&1
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
@@ -14037,7 +14554,8 @@ esac
 
 : check for the select 'width'
 case "$selectminbits" in
-'') case "$d_select" in
+'') safebits=`expr $ptrsize \* 8`
+    case "$d_select" in
 	$define)
 		$cat <<EOM
 
@@ -14069,25 +14587,31 @@ EOM
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
@@ -14095,20 +14619,21 @@ int main() {
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
@@ -14117,7 +14642,8 @@ EOM
 		else
 			rp='What is the minimum number of bits your select() operates on?'
 			case "$byteorder" in
-			1234|12345678)	dflt=32 ;;
+			12345678)	dflt=64 ;;
+			1234)		dflt=32 ;;
 			*)		dflt=1	;;
 			esac
 			. ./myread
@@ -14127,7 +14653,7 @@ EOM
 		$rm -f try.* try
 		;;
 	*)	: no select, so pick a harmless default
-		selectminbits='32'
+		selectminbits=$safebits
 		;;
 	esac
 	;;
@@ -14174,9 +14700,13 @@ xxx="$xxx SYS TERM THAW TRAP TSTP TTIN TTOU URG USR1 USR2"
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
 
@@ -14403,6 +14933,10 @@ echo "Checking the size of $zzz..." >&4
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
@@ -14410,7 +14944,7 @@ int main() {
 EOCP
 set try
 if eval $compile_ok; then
-	yyy=`./try`
+	yyy=`$run ./try`
 	case "$yyy" in
 	'')	sizesize=4
 		echo "(I can't execute the test program--guessing $sizesize.)" >&4
@@ -14504,8 +15038,12 @@ esac
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
@@ -14521,9 +15059,9 @@ int main()
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
@@ -14539,7 +15077,7 @@ EOM
 	. ./myread
 	ssizetype="$ans"
 fi
-$rm -f ssize ssize.*
+$rm -f try try.*
 
 : see what type of char stdio uses.
 echo " "
@@ -14604,6 +15142,10 @@ echo "Checking the size of $zzz..." >&4
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
@@ -14611,7 +15153,7 @@ int main() {
 EOCP
 set try
 if eval $compile_ok; then
-	yyy=`./try`
+	yyy=`$run ./try`
 	case "$yyy" in
 	'')	uidsize=4
 		echo "(I can't execute the test program--guessing $uidsize.)" >&4
@@ -14786,35 +15328,6 @@ esac
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
@@ -15005,10 +15518,10 @@ $awk \\
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
 echo '}' >> try.c
 EOSH
PATCH
}

1;
