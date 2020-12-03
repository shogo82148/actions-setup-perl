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
@@ -4797,7 +4797,7 @@ echo " "
 echo "Checking your choice of C compiler and flags for coherency..." >&4
 $cat > try.c <<'EOF'
 #include <stdio.h>
-int main() { printf("Ok\n"); exit(0); }
+int main() { printf("Ok\n"); return(0); }
 EOF
 set X $cc -o try $optimize $ccflags $ldflags try.c $libs
 shift
@@ -4893,7 +4893,7 @@ int main()
 	printf("intsize=%d;\n", (int)sizeof(int));
 	printf("longsize=%d;\n", (int)sizeof(long));
 	printf("shortsize=%d;\n", (int)sizeof(short));
-	exit(0);
+	return(0);
 }
 EOCP
 	set try
@@ -5850,7 +5850,7 @@ case "$doublesize" in
 int main()
 {
     printf("%d\n", (int)sizeof(double));
-    exit(0);
+    return(0);
 }
 EOCP
 	set try
@@ -6767,7 +6767,7 @@ case "$ptrsize" in
 int main()
 {
     printf("%d\n", (int)sizeof(VOID_PTR));
-    exit(0);
+    return(0);
 }
 EOCP
 	set try
@@ -7151,7 +7151,11 @@ eval $setvar
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
@@ -8641,7 +8645,7 @@ cat > try.c <<EOCP
 #include <stdio.h>
 int main() {
     printf("%d\n", (int)sizeof($fpostype));
-    exit(0);
+    return(0);
 }
 EOCP
 set try
@@ -9593,6 +9597,10 @@ else
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
@@ -9647,6 +9655,10 @@ echo " "
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
@@ -13357,7 +13369,7 @@ case "$charsize" in
 int main()
 {
     printf("%d\n", (int)sizeof(char));
-    exit(0);
+    return(0);
 }
 EOCP
 	set try
@@ -16244,6 +16256,10 @@ EOM
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
@@ -17251,7 +17267,7 @@ cat > try.c <<EOCP
 #include <stdio.h>
 int main() {
     printf("%d\n", (int)sizeof($gidtype));
-    exit(0);
+    return(0);
 }
 EOCP
 set try
@@ -18418,7 +18434,7 @@ cat > try.c <<EOCP
 #include <stdio.h>
 int main() {
     printf("%d\n", (int)sizeof($sizetype));
-    exit(0);
+    return(0);
 }
 EOCP
 set try
@@ -18530,7 +18546,7 @@ int main()
 		printf("int\n");
 	else 
 		printf("long\n");
-	exit(0);
+	return(0);
 }
 EOM
 echo " "
@@ -18603,7 +18619,7 @@ cat > try.c <<EOCP
 #include <stdio.h>
 int main() {
     printf("%d\n", (int)sizeof($uidtype));
-    exit(0);
+    return(0);
 }
 EOCP
 set try
PATCH
}

1;
