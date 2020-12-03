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
@@ -4797,7 +4797,7 @@ echo " "
 echo "Checking your choice of C compiler and flags for coherency..." >&4
 $cat > try.c <<'EOF'
 #include <stdio.h>
-int main() { printf("Ok\n"); exit(0); }
+int main() { printf("Ok\n"); return(0); }
 EOF
 set X $cc -o try $optimize $ccflags $ldflags try.c $libs
 shift
@@ -5417,7 +5417,7 @@ case "$usenm" in
 	esac
 	case "$dflt" in
 	'') 
-		if $test "$osname" = aix -a ! -f /lib/syscalls.exp; then
+		if $test "$osname" = aix -a "X$PASE" != "Xdefine" -a ! -f /lib/syscalls.exp; then
 			echo " "
 			echo "Whoops!  This is an AIX system without /lib/syscalls.exp!" >&4
 			echo "'nm' won't be sufficient on this sytem." >&4
@@ -5655,7 +5655,7 @@ $grep fprintf libc.tmp > libc.ptf
 xscan='eval "<libc.ptf $com >libc.list"; $echo $n ".$c" >&4'
 xrun='eval "<libc.tmp $com >libc.list"; echo "done." >&4'
 xxx='[ADTSIW]'
-if com="$sed -n -e 's/__IO//' -e 's/^.* $xxx  *_[_.]*//p' -e 's/^.* $xxx  *//p'";\
+if com="$sed -n -e 's/__IO//' -e 's/^.* $xxx  *//p'";\
 	eval $xscan;\
 	$contains '^fprintf$' libc.list >/dev/null 2>&1; then
 		eval $xrun
@@ -5776,9 +5776,9 @@ $rm -f libnames libpath
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
@@ -5787,25 +5787,28 @@ true-*) tx=no; eval "tval=\$$4"; case "$tval" in "") tx=yes;; esac;;
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
 
@@ -5845,8 +5848,12 @@ echo " "
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
@@ -6665,7 +6672,11 @@ echo " "
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
@@ -6762,8 +6773,12 @@ case "$ptrsize" in
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
@@ -7151,7 +7166,11 @@ eval $setvar
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
@@ -7511,10 +7530,13 @@ while other systems (such as those using ELF) use $cc.
 
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
@@ -8639,6 +8661,10 @@ echo "Checking the size of $zzz..." >&4
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
@@ -8743,9 +8769,13 @@ EOCP
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
@@ -9055,7 +9085,7 @@ eval $inlibc
 case "$d_access" in
 "$define")
 	echo " "
-	$cat >access.c <<'EOCP'
+	$cat >access.c <<EOCP
 #include <sys/types.h>
 #ifdef I_FCNTL
 #include <fcntl.h>
@@ -9066,6 +9096,10 @@ case "$d_access" in
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
@@ -9203,7 +9237,7 @@ echo " "
 if test "X$timeincl" = X; then
 	echo "Testing to see if we should include <time.h>, <sys/time.h> or both." >&4
 	$echo $n "I'm now running the test program...$c"
-	$cat >try.c <<'EOCP'
+	$cat >try.c <<EOCP
 #include <sys/types.h>
 #ifdef I_TIME
 #include <time.h>
@@ -9217,6 +9251,10 @@ if test "X$timeincl" = X; then
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
@@ -9382,7 +9420,7 @@ echo " "
 echo "Checking whether your compiler can handle __attribute__ ..." >&4
 $cat >attrib.c <<'EOCP'
 #include <stdio.h>
-void croak (char* pat,...) __attribute__((format(printf,1,2),noreturn));
+void croak (char* pat,...) __attribute__((__format__(__printf__,1,2),noreturn));
 EOCP
 if $cc $ccflags -c attrib.c >attrib.out 2>&1 ; then
 	if $contains 'warning' attrib.out >/dev/null 2>&1; then
@@ -9426,6 +9464,10 @@ case "$d_getpgrp" in
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
@@ -9488,6 +9530,10 @@ case "$d_setpgrp" in
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
@@ -9593,6 +9639,10 @@ else
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
@@ -9647,6 +9697,10 @@ echo " "
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
@@ -9743,8 +9797,12 @@ echo " "
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
 
@@ -10283,6 +10341,10 @@ eval $inhdr
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
@@ -10375,6 +10437,10 @@ EOM
 $cat >fred.c<<EOM
 
 #include <stdio.h>
+#$i_stdlib I_STDLIB
+#ifdef I_STDLIB
+#include <stdlib.h>
+#endif
 #$i_dlfcn I_DLFCN
 #ifdef I_DLFCN
 #include <dlfcn.h>      /* the dynamic linker include file for SunOS/Solaris */
@@ -10912,7 +10978,7 @@ esac
 
 : Locate the flags for 'open()'
 echo " "
-$cat >try.c <<'EOCP'
+$cat >try.c <<EOCP
 #include <sys/types.h>
 #ifdef I_FCNTL
 #include <fcntl.h>
@@ -10920,6 +10986,10 @@ $cat >try.c <<'EOCP'
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
@@ -11052,7 +11122,10 @@ case "$o_nonblock" in
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
@@ -11098,7 +11171,10 @@ case "$eagain" in
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
@@ -11258,7 +11334,10 @@ eval $inlibc
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
@@ -11325,6 +11404,10 @@ $cat <<EOM
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
@@ -13005,9 +13088,13 @@ eval $inlibc
 
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
@@ -13352,8 +13439,12 @@ echo " "
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
@@ -13593,6 +13684,10 @@ if test X"$d_volatile" = X"$define"; then
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
@@ -14363,7 +14458,7 @@ $define)
 #endif
 END
 
-    $cat > try.c <<END
+      $cat > try.c <<END
 #include <sys/types.h>
 #include <sys/ipc.h>
 #include <sys/sem.h>
@@ -14410,14 +14505,14 @@ int main() {
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
@@ -14431,7 +14526,7 @@ END
     esac
 
     : see whether semctl IPC_STAT can use struct semid_ds pointer
-    $cat > try.c <<'END'
+      $cat > try.c <<'END'
 #include <sys/types.h>
 #include <sys/ipc.h>
 #include <sys/sem.h>
@@ -15065,10 +15160,14 @@ echo " "
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
@@ -15100,8 +15199,12 @@ eval $inlibc
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
@@ -16182,6 +16285,10 @@ I'm now running the test program...
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
@@ -16244,6 +16351,10 @@ EOM
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
@@ -16595,6 +16706,10 @@ $define)
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
@@ -16933,6 +17048,10 @@ sunos) $echo '#define PERL_FFLUSH_ALL_FOPEN_MAX 32' > try.c ;;
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
@@ -17249,6 +17368,10 @@ echo "Checking the size of $zzz..." >&4
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
@@ -17959,7 +18082,11 @@ echo " "
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
@@ -18081,6 +18208,10 @@ EOM
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
@@ -18186,9 +18317,13 @@ xxx="$xxx SYS TERM THAW TRAP TSTP TTIN TTOU URG USR1 USR2"
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
 
@@ -18263,7 +18398,7 @@ END {
 $cat >signal.awk <<'EOP'
 BEGIN { ndups = 0 }
 $1 ~ /^NSIG$/ { nsig = $2 }
-($1 !~ /^NSIG$/) && (NF == 2) {
+($1 !~ /^NSIG$/) && (NF == 2) && ($2 ~ /^[0-9][0-9]*$/) {
     if ($2 > maxsig) { maxsig = $2 }
     if (sig_name[$2]) {
 	dup_name[ndups] = $1
@@ -18416,6 +18551,10 @@ echo "Checking the size of $zzz..." >&4
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
@@ -18519,6 +18658,10 @@ eval $typedef
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
@@ -18601,6 +18744,10 @@ echo "Checking the size of $zzz..." >&4
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
PATCH
}

1;
