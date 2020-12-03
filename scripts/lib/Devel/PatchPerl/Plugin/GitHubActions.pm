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
@@ -7519,11 +7523,11 @@ int main() {
 	char b[4];
 	int i = open("a.out",O_RDONLY);
 	if(i == -1) 
-		exit(1); /* fail */
+		return(1); /* fail */
 	if(read(i,b,4)==4 && b[0]==127 && b[1]=='E' && b[2]=='L' && b[3]=='F')
-		exit(0); /* succeed (yes, it's ELF) */
+		return(0); /* succeed (yes, it's ELF) */
 	else
-		exit(1); /* fail */
+		return(1); /* fail */
 }
 EOM
 		if $cc $ccflags $ldflags try.c >/dev/null 2>&1 && $run ./a.out; then
@@ -8641,7 +8645,7 @@ cat > try.c <<EOCP
 #include <stdio.h>
 int main() {
     printf("%d\n", (int)sizeof($fpostype));
-    exit(0);
+    return(0);
 }
 EOCP
 set try
@@ -8745,7 +8749,7 @@ EOCP
 #include <stdio.h>
 int main() {
     printf("%d\n", (int)sizeof($fpostype));
-    exit(0);
+    return(0);
 }
 EOCP
 		set try
@@ -8948,7 +8952,7 @@ int main()
 	 * t/base/num.t for benefit of platforms not using Configure or
 	 * overriding d_Gconvert */
 
-	exit(0);
+	return(0);
 }
 EOP
 : first add preferred functions to our list
@@ -9227,12 +9231,12 @@ int main()
 	struct timezone tzp;
 #endif
 	if (foo.tm_sec == foo.tm_sec)
-		exit(0);
+		return(0);
 #ifdef S_TIMEVAL
 	if (bar.tv_sec == bar.tv_sec)
-		exit(0);
+		return(0);
 #endif
-	exit(1);
+	return(1);
 }
 EOCP
 	flags=''
@@ -9434,12 +9438,12 @@ int main()
 	}
 #ifdef TRY_BSD_PGRP
 	if (getpgrp(1) == 0)
-		exit(0);
+		return(0);
 #else
 	if (getpgrp() > 0)
-		exit(0);
+		return(0);
 #endif
-	exit(1);
+	return(1);
 }
 EOP
 	if $cc -o try -DTRY_BSD_PGRP $ccflags $ldflags try.c $libs >/dev/null 2>&1 && $run ./try; then
@@ -9496,12 +9500,12 @@ int main()
 	}
 #ifdef TRY_BSD_PGRP
 	if (-1 == setpgrp(1, 1))
-		exit(0);
+		return(0);
 #else
 	if (setpgrp() != -1)
-		exit(0);
+		return(0);
 #endif
-	exit(1);
+	return(1);
 }
 EOP
 	if $cc -o try -DTRY_BSD_PGRP $ccflags $ldflags try.c $libs >/dev/null 2>&1 && $run ./try; then
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
@@ -10311,9 +10323,9 @@ $cat >dirfd.c <<EOM
 int main() {
 	DIR *dirp = opendir(".");
 	if (dirfd(dirp) >= 0)
-		exit(0);
+		return(0);
 	else
-		exit(1);
+		return(1);
 }
 EOM
 set dirfd
@@ -10399,7 +10411,7 @@ int main()
     if (handle == NULL) {
 	printf ("1\n") ;
 	fflush (stdout) ;
-	exit(0);
+	return(0);
     }
     symbol = dlsym(handle, "fred") ;
     if (symbol == NULL) {
@@ -10408,14 +10420,14 @@ int main()
 	if (symbol == NULL) {
 	    printf ("2\n") ;
 	    fflush (stdout) ;
-	    exit(0);
+	    return(0);
 	}
 	printf ("3\n") ;
     }
     else
 	printf ("4\n") ;
     fflush (stdout) ;
-    exit(0);
+    return(0);
 }
 EOM
 	: Call the object file tmp-dyna.o in case dlext=o.
@@ -10923,9 +10935,9 @@ $cat >try.c <<'EOCP'
 int main() {
 	if(O_RDONLY);
 #ifdef O_TRUNC
-	exit(0);
+	return(0);
 #else
-	exit(1);
+	return($1);
 #endif
 }
 EOCP
@@ -11060,17 +11072,17 @@ case "$o_nonblock" in
 int main() {
 #ifdef O_NONBLOCK
 	printf("O_NONBLOCK\n");
-	exit(0);
+	return($1);
 #endif
 #ifdef O_NDELAY
 	printf("O_NDELAY\n");
-	exit(0);
+	return($1);
 #endif
 #ifdef FNDELAY
 	printf("FNDELAY\n");
-	exit(0);
+	return($1);
 #endif
-	exit(0);
+	return($1);
 }
 EOCP
 	set try
@@ -11135,14 +11147,14 @@ int main()
 		close(pu[0]);	/* Parent writes (blocking) to pu[1] */
 #ifdef F_SETFL
 		if (-1 == fcntl(pd[0], F_SETFL, MY_O_NONBLOCK))
-			exit(1);
+			return($1);
 #else
-		exit(4);
+		return($1);
 #endif
 		signal(SIGALRM, blech);
 		alarm(5);
 		if ((ret = read(pd[0], buf, 1)) > 0)	/* Nothing to read! */
-			exit(2);
+			return($1);
 		sprintf(string, "%d\n", ret);
 		write(2, string, strlen(string));
 		alarm(0);
@@ -11164,14 +11176,14 @@ int main()
 		alarm(0);
 		sprintf(string, "%d\n", ret);
 		write(4, string, strlen(string));
-		exit(0);
+		return($1);
 	}
 
 	close(pd[0]);			/* We write to pd[1] */
 	close(pu[1]);			/* We read from pu[0] */
 	read(pu[0], buf, 1);	/* Wait for parent to signal us we may continue */
 	close(pd[1]);			/* Pipe pd is now fully closed! */
-	exit(0);				/* Bye bye, thank you for playing! */
+	return($1);				/* Bye bye, thank you for playing! */
 }
 EOCP
 	set try
@@ -11346,9 +11358,9 @@ int main() {
 #endif
 
 #if defined(FD_SET) && defined(FD_CLR) && defined(FD_ISSET) && defined(FD_ZERO)
-	exit(0);
+	return($1);
 #else
-	exit(1);
+	return($1);
 #endif
 }
 EOCP
@@ -13011,9 +13023,9 @@ $cat >isascii.c <<'EOCP'
 int main() {
 	int c = 'A';
 	if (isascii(c))
-		exit(0);
+		return($1);
 	else
-		exit(1);
+		return($1);
 }
 EOCP
 set isascii
@@ -13357,7 +13369,7 @@ case "$charsize" in
 int main()
 {
     printf("%d\n", (int)sizeof(char));
-    exit(0);
+    return(0);
 }
 EOCP
 	set try
@@ -13625,7 +13637,7 @@ int main() {
       }	
     }
     printf("%d\n", ((i == n) ? -n : i));
-    exit(0);
+    return($1);
 }
 EOP
 set try
@@ -14102,11 +14114,11 @@ for (align = 7; align >= 0; align--) {
 			bcopy(b, b+off, len);
 			bcopy(b+off, b, len);
 			if (bcmp(b, abc, len))
-				exit(1);
+				return($1);
 		}
 	}
 }
-exit(0);
+return($1);
 }
 EOCP
 		set try
@@ -14178,11 +14190,11 @@ for (align = 7; align >= 0; align--) {
 			memcpy(b+off, b, len);
 			memcpy(b, b+off, len);
 			if (memcmp(b, abc, len))
-				exit(1);
+				return($1);
 		}
 	}
 }
-exit(0);
+return($1);
 }
 EOCP
 		set try
@@ -14237,8 +14249,8 @@ int main()
 char a = -1;
 char b = 0;
 if ((a < b) && memcmp(&a, &b, 1) < 0)
-	exit(1);
-exit(0);
+	return($1);
+return($1);
 }
 EOCP
 	set try
@@ -15110,7 +15122,7 @@ int main()
 		exit(set);
 	set = 0;
 	siglongjmp(env, 1);
-	exit(1);
+	return($1);
 }
 EOP
 	set try
@@ -15374,8 +15386,8 @@ int main() {
 		18 <= FILE_cnt(fp) &&
 		strncmp(FILE_ptr(fp), "include <stdio.h>\n", 18) == 0
 	)
-		exit(0);
-	exit(1);
+		return($1);
+	return($1);
 }
 EOP
 val="$undef"
@@ -15452,12 +15464,12 @@ int main() {
 	size_t cnt;
 	if (!fp) {
 	    puts("Fail even to read");
-	    exit(1);
+	    return($1);
 	}
 	c = getc(fp); /* Read away the first # */
 	if (c == EOF) {
 	    puts("Fail even to read");
-	    exit(1);
+	    return($1);
 	}
 	if (!(
 		18 <= FILE_cnt(fp) &&
@@ -15532,8 +15544,8 @@ int main() {
 		19 <= FILE_bufsiz(fp) &&
 		strncmp(FILE_base(fp), "#include <stdio.h>\n", 19) == 0
 	)
-		exit(0);
-	exit(1);
+		return($1);
+	return($1);
 }
 EOP
 	set try
@@ -16199,7 +16211,7 @@ int main()
 	for (i = 0; i < $uvsize; i++)
 		printf("%c", u.c[i]+'0');
 	printf("\n");
-	exit(0);
+	return($1);
 }
 EOCP
 		xxx_prompt=y
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
@@ -16595,6 +16611,10 @@ $define)
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
@@ -17251,7 +17271,7 @@ cat > try.c <<EOCP
 #include <stdio.h>
 int main() {
     printf("%d\n", (int)sizeof($gidtype));
-    exit(0);
+    return(0);
 }
 EOCP
 set try
@@ -18257,7 +18277,7 @@ echo $xxx | $tr ' ' $trnl | $sort | $uniq | $awk '
 }
 END {
 	printf "#endif /* JUST_NSIG */\n";
-	printf "exit(0);\n}\n";
+	printf "return(0);\n}\n";
 }
 ' >>signal.c
 $cat >signal.awk <<'EOP'
@@ -18418,7 +18438,7 @@ cat > try.c <<EOCP
 #include <stdio.h>
 int main() {
     printf("%d\n", (int)sizeof($sizetype));
-    exit(0);
+    return(0);
 }
 EOCP
 set try
@@ -18530,7 +18550,7 @@ int main()
 		printf("int\n");
 	else 
 		printf("long\n");
-	exit(0);
+	return(0);
 }
 EOM
 echo " "
@@ -18603,7 +18623,7 @@ cat > try.c <<EOCP
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
