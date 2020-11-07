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

use Devel::PatchPerl::Plugin::MinGW;

# copy utility functions from Devel::PatchPerl
*_is = *Devel::PatchPerl::_is;
*_patch = *Devel::PatchPerl::_patch;

my @patch = (
    {
        perl => [
            qr/^5\.28\.[01]$/,
        ],
        subs => [
            [ \&_patch_useshrplib ],
        ],
    },
    {
        perl => [
            qr/^5\.24\.2$/,
        ],
        subs => [
            # https://github.com/bingos/devel-patchperl/pull/49
            [ \&Devel::PatchPerl::_patch_time_hires ],
        ],
    },
);

sub patchperl {
    my ($class, %args) = @_;
    my $vers = $args{version};
    my $source = $args{source};
    my $dir = pushd( $source );

    if ($^O eq 'MSWin32') {
        Devel::PatchPerl::Plugin::MinGW->patchperl(%args);
    }

    # copy from https://github.com/bingos/devel-patchperl/blob/acdcf1d67ae426367f42ca763b9ba6b92dd90925/lib/Devel/PatchPerl.pm#L301-L307
    for my $p ( grep { _is( $_->{perl}, $vers ) } @patch ) {
       for my $s (@{$p->{subs}}) {
         my($sub, @args) = @$s;
         push @args, $vers unless scalar @args;
         $sub->(@args);
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

sub _patch_useshrplib {
    # from https://github.com/Perl/perl5/commit/191f8909fa4eca1db16a91ada42dd4a065c04890
    _patch(<<'END');
diff --git a/Makefile.SH b/Makefile.SH
index 6e4d5ee684f..bebe50dc131 100755
--- Makefile.SH
+++ Makefile.SH
@@ -67,8 +67,16 @@ true)
                             -compatibility_version \
 				${api_revision}.${api_version}.${api_subversion} \
 			     -current_version \
-				${revision}.${patchlevel}.${subversion} \
-			     -install_name \$(shrpdir)/\$@"
+				${revision}.${patchlevel}.${subversion}"
+		case "$osvers" in
+	        1[5-9]*|[2-9]*)
+			shrpldflags="$shrpldflags -install_name `pwd`/\$@ -Xlinker -headerpad_max_install_names"
+			exeldflags="-Xlinker -headerpad_max_install_names"
+			;;
+		*)
+			shrpldflags="$shrpldflags -install_name \$(shrpdir)/\$@"
+			;;
+		esac
 		;;
 	cygwin*)
 		shrpldflags="$shrpldflags -Wl,--out-implib=libperl.dll.a -Wl,--image-base,0x52000000"
@@ -339,6 +347,14 @@ MANIFEST_SRT = MANIFEST.srt
 
 !GROK!THIS!
 
+case "$useshrplib$osname" in
+truedarwin)
+	$spitshell >>$Makefile <<!GROK!THIS!
+PERL_EXE_LDFLAGS=$exeldflags
+!GROK!THIS!
+	;;
+esac
+
 case "$usecrosscompile$perl" in
 define?*)
 	$spitshell >>$Makefile <<!GROK!THIS!
@@ -1050,6 +1066,20 @@ $(PERL_EXE): $& $(perlmain_dep) $(LIBPERL) $(static_ext) ext.libs $(PERLEXPORT)
 	$(SHRPENV) $(CC) -o perl $(CLDFLAGS) $(CCDLFLAGS) $(perlmain_objs) $(LLIBPERL) $(static_ext) `cat ext.libs` $(libs)
 !NO!SUBS!
         ;;
+
+	darwin)
+	    case "$useshrplib$osvers" in
+	    true1[5-9]*|true[2-9]*) $spitshell >>$Makefile <<'!NO!SUBS!'
+	$(SHRPENV) $(CC) -o perl $(PERL_EXE_LDFLAGS) $(CLDFLAGS) $(CCDLFLAGS) $(perlmain_objs) $(static_ext) $(LLIBPERL) `cat ext.libs` $(libs)
+!NO!SUBS!
+	       ;;
+	    *) $spitshell >>$Makefile <<'!NO!SUBS!'
+	$(SHRPENV) $(CC) -o perl $(CLDFLAGS) $(CCDLFLAGS) $(perlmain_objs) $(static_ext) $(LLIBPERL) `cat ext.libs` $(libs)
+!NO!SUBS!
+	       ;;
+	    esac
+        ;;
+
         *) $spitshell >>$Makefile <<'!NO!SUBS!'
 	$(SHRPENV) $(CC) -o perl $(CLDFLAGS) $(CCDLFLAGS) $(perlmain_objs) $(static_ext) $(LLIBPERL) `cat ext.libs` $(libs)
 !NO!SUBS!
diff --git a/installperl b/installperl
index 3bf79d2d6fc..6cd65a09238 100755
--- installperl
+++ installperl
@@ -304,6 +304,7 @@ elsif ($^O ne 'dos') {
 	safe_unlink("$installbin/$perl_verbase$ver$exe_ext");
 	copy("perl$exe_ext", "$installbin/$perl_verbase$ver$exe_ext");
 	strip("$installbin/$perl_verbase$ver$exe_ext");
+	fix_dep_names("$installbin/$perl_verbase$ver$exe_ext");
 	chmod(0755, "$installbin/$perl_verbase$ver$exe_ext");
     }
     else {
@@ -388,6 +389,7 @@ foreach my $file (@corefiles) {
     if (copy_if_diff($file,"$installarchlib/CORE/$file")) {
 	if ($file =~ /\.(\Q$so\E|\Q$dlext\E)$/) {
 	    strip("-S", "$installarchlib/CORE/$file") if $^O eq 'darwin';
+	    fix_dep_names("$installarchlib/CORE/$file");
 	    chmod($SO_MODE, "$installarchlib/CORE/$file");
 	} else {
 	    chmod($NON_SO_MODE, "$installarchlib/CORE/$file");
@@ -791,4 +793,27 @@ sub strip
     }
 }
 
+sub fix_dep_names {
+    my $file = shift;
+
+    $^O eq "darwin" && $Config{osvers} =~ /^(1[5-9]|[2-9])/
+      && $Config{useshrplib}
+      or return;
+
+    my @opts;
+    my $so = $Config{so};
+    my $libperl = "$Config{archlibexp}/CORE/libperl.$Config{so}";
+    if ($file =~ /\blibperl.\Q$Config{so}\E$/a) {
+        push @opts, -id => $libperl;
+    }
+    else {
+        push @opts, -change => getcwd . "/libperl.$so", $libperl;
+    }
+    push @opts, $file;
+
+    $opts{verbose} and print "  install_name_tool @opts\n";
+    system "install_name_tool", @opts
+      and die "Cannot update $file dependency paths\n";
+}
+
 # ex: set ts=8 sts=4 sw=4 et:
END
}

1;
