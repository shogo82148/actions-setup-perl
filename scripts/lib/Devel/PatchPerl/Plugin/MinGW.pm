package Devel::PatchPerl::Plugin::MinGW;

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
            qr/.*/,
        ],
        subs => [
            [ \&_patch_config_h_gc ],
            [ \&_patch_config_gc ],
            [ \&_patch_config_sh_pl ],
            [ \&_patch_installperl ],
            [ \&_patch_buildext_pl ],
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
            qr/^5\.19\.4$/,
        ],
        subs => [
            [ \&_patch_convert_errno_to_wsa_error ],
        ],
    },
    {
        perl => [
            qr/^5\.1[0-9]\./,
            qr/^5\.9\./,
            qr/^5\.8\.[789]$/,
        ],
        subs => [
            [ \&_patch_errno ],
        ],
    },
    {
        perl => [
            qr/^5\.13\.[0-6]$/,
            qr/^5\.1[012]\./,
        ],
        subs => [
            [ \&_patch_socket_h ],
        ],
    },
    {
        perl => [
            qr/^5\.11\.[01]/,
            qr/^5\.10\./,
            qr/^5\.9\.[345]$/,
        ],
        subs => [
            [ \&_patch_perlhost ],
        ],
    },
    {
        perl => [
            qr/^5\.11\.[01]$/,
            qr/^5\.10\./,
            qr/^5\.9\.[45]/,
            qr/^5\.8\.9$/,
        ],
        subs => [
            [ \&_patch_threads ],
        ],
    },

    # patches for MakeMaker
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
            qr/^5\.1[1-8]\./,
        ],
        subs => [
            [ \&_patch_make_maker_dirfilesep_518 ],
        ],
    },
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

sub _patch_make_maker {
    # from https://github.com/Perl/perl5/commit/9cc600a92e7d683d4b053eb5e84ca8654ce82ac4
    # Win32 gmake needs SHELL to be specified
    my $version = shift;
    if (_ge($version, "5.11.0")) {
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
        return
    }

    if (_ge($version, "5.10.1")) {
        _patch(<<'PATCH');
--- lib/ExtUtils/MM_Unix.pm
+++ lib/ExtUtils/MM_Unix.pm
@@ -296,8 +296,8 @@ sub const_cccmd {
 
 =item const_config (o)
 
-Defines a couple of constants in the Makefile that are imported from
-%Config.
+Sets SHELL if needed, then defines a couple of constants in the Makefile
+that are imported from %Config.
 
 =cut
 
@@ -305,7 +305,8 @@ sub const_config {
 # --- Constants Sections ---
 
     my($self) = shift;
-    my @m = <<"END";
+    my @m = $self->specify_shell(); # Usually returns empty string
+    push @m, <<"END";
 
 # These definitions are from config.sh (via $INC{'Config.pm'}).
 # They may have been overridden via Makefile.PL or on the command line.
@@ -3056,6 +3057,16 @@ MAKE_FRAG
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
--- lib/ExtUtils/MM_Win32.pm
+++ lib/ExtUtils/MM_Win32.pm
@@ -128,7 +128,8 @@ sub init_DIRFILESEP {
 
     # The ^ makes sure its not interpreted as an escape in nmake
     $self->{DIRFILESEP} = $self->is_make_type('nmake') ? '^\\' :
-                          $self->is_make_type('dmake') ? '\\\\'
+                          $self->is_make_type('dmake') ? '\\\\' :
+                          $self->is_make_type('gmake') ? '/'
                                                        : '\\';
 }
 
@@ -153,7 +154,7 @@ sub init_others {
     $self->{DEV_NULL} ||= '> NUL';
 
     $self->{FIXIN}    ||= $self->{PERL_CORE} ? 
-      "\$(PERLRUN) $self->{PERL_SRC}/win32/bin/pl2bat.pl" : 
+      "\$(PERLRUN) $self->{PERL_SRC}\\win32\\bin\\pl2bat.pl" :
       'pl2bat.bat';
 
     $self->{LD}     ||= 'link';
@@ -209,6 +210,17 @@ sub platform_constants {
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
 
 =item special_targets
 
PATCH
        return;
    }

    if (_ge($version, "5.9.4")) {
        _patch(<<'PATCH');
--- lib/ExtUtils/MM_Unix.pm
+++ lib/ExtUtils/MM_Unix.pm
@@ -299,8 +299,8 @@ sub const_cccmd {
 
 =item const_config (o)
 
-Defines a couple of constants in the Makefile that are imported from
-%Config.
+Sets SHELL if needed, then defines a couple of constants in the Makefile
+that are imported from %Config.
 
 =cut
 
@@ -311,6 +311,7 @@ sub const_config {
     my(@m,$m);
     push(@m,"\n# These definitions are from config.sh (via $INC{'Config.pm'})\n");
     push(@m,"\n# They may have been overridden via Makefile.PL or on the command line\n");
+    push(@m, $self->specify_shell()); # Usually returns empty string
     my(%once_only);
     foreach $m (@{$self->{CONFIG}}){
 	# SITE*EXP macros are defined in &constants; avoid duplicates here
@@ -3135,6 +3136,16 @@ MAKE_FRAG
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
--- lib/ExtUtils/MM_Win32.pm
+++ lib/ExtUtils/MM_Win32.pm
@@ -121,19 +121,18 @@ sub maybe_command {
 
 =item B<init_DIRFILESEP>
 
-Using \ for Windows.
+Using \ for Windows, except for "gmake" where it is /.
 
 =cut
 
 sub init_DIRFILESEP {
     my($self) = shift;
 
-    my $make = $self->make;
-
     # The ^ makes sure its not interpreted as an escape in nmake
-    $self->{DIRFILESEP} = $make eq 'nmake' ? '^\\' :
-                          $make eq 'dmake' ? '\\\\'
-                                           : '\\';
+    $self->{DIRFILESEP} = $self->is_make_type('nmake') ? '^\\' :
+                          $self->is_make_type('dmake') ? '\\\\' :
+                          $self->is_make_type('gmake') ? '/'
+                                                       : '\\';
 }
 
 =item B<init_others>
@@ -168,7 +167,7 @@ sub init_others {
     $self->{DEV_NULL} ||= '> NUL';
 
     $self->{FIXIN}    ||= $self->{PERL_CORE} ? 
-      "\$(PERLRUN) $self->{PERL_SRC}/win32/bin/pl2bat.pl" : 
+      "\$(PERLRUN) $self->{PERL_SRC}\\win32\\bin\\pl2bat.pl" :
       'pl2bat.bat';
 
     $self->{LD}     ||= $Config{ld} || 'link';
@@ -224,6 +223,17 @@ sub platform_constants {
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
 
 =item special_targets
 
@@ -564,6 +574,11 @@ PERLTYPE = $self->{PERLTYPE}
 
 }
 
+sub is_make_type {
+    my($self, $type) = @_;
+    return !! ($self->make =~ /\b$type(?:\.exe)?$/);
+}
+
 1;
 __END__
 
PATCH
        return;
    }

    if (_ge($version, "5.9.2")) {
        _patch(<<'PATCH');
--- lib/ExtUtils/MM_Unix.pm
+++ lib/ExtUtils/MM_Unix.pm
@@ -382,10 +382,11 @@ sub const_config {
 # --- Constants Sections ---
 
     my($self) = shift;
-    my(@m,$m);
+    my @m = $self->specify_shell(); # Usually returns empty string
     push(@m,"\n# These definitions are from config.sh (via $INC{'Config.pm'})\n");
     push(@m,"\n# They may have been overridden via Makefile.PL or on the command line\n");
     my(%once_only);
+    my($m);
     foreach $m (@{$self->{CONFIG}}){
 	# SITE*EXP macros are defined in &constants; avoid duplicates here
 	next if $once_only{$m};
@@ -3438,6 +3439,16 @@ $target :: $plfile
     join "", @m;
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
--- lib/ExtUtils/MM_Win32.pm
+++ lib/ExtUtils/MM_Win32.pm
@@ -24,7 +24,7 @@ use File::Basename;
 use File::Spec;
 use ExtUtils::MakeMaker qw( neatvalue );
 
-use vars qw(@ISA $VERSION $BORLAND $GCC $DMAKE $NMAKE);
+use vars qw(@ISA $VERSION $BORLAND $GCC $DMAKE $NMAKE $GMAKE);
 
 require ExtUtils::MM_Any;
 require ExtUtils::MM_Unix;
@@ -36,6 +36,7 @@ $ENV{EMXSHELL} = 'sh'; # to run `commands`
 $BORLAND = 1 if $Config{'cc'} =~ /^bcc/i;
 $GCC     = 1 if $Config{'cc'} =~ /^gcc/i;
 $DMAKE = 1 if $Config{'make'} =~ /^dmake/i;
+$GMAKE = 1 if $Config{'make'} =~ /^gmake/i;
 $NMAKE = 1 if $Config{'make'} =~ /^nmake/i;
 
 
@@ -146,7 +147,8 @@ sub init_DIRFILESEP {
 
     # The ^ makes sure its not interpreted as an escape in nmake
     $self->{DIRFILESEP} = $NMAKE ? '^\\' :
-                          $DMAKE ? '\\\\'
+                          $DMAKE ? '\\\\' :
+                          $GMAKE ? '/'
                                  : '\\';
 }
 
@@ -234,6 +236,17 @@ sub platform_constants {
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
+    return '' unless $GMAKE;
+    "\nSHELL = $ENV{COMSPEC}\n";
+}
 
 =item special_targets (o)
 
PATCH
        return;
    }

    if (_ge($version, "5.9.1")) {
        _patch(<<'PATCH');
--- lib/ExtUtils/MM_Unix.pm
+++ lib/ExtUtils/MM_Unix.pm
@@ -382,10 +382,11 @@ sub const_config {
 # --- Constants Sections ---
 
     my($self) = shift;
-    my(@m,$m);
+    my @m = $self->specify_shell(); # Usually returns empty string
     push(@m,"\n# These definitions are from config.sh (via $INC{'Config.pm'})\n");
     push(@m,"\n# They may have been overridden via Makefile.PL or on the command line\n");
     my(%once_only);
+    my($m);
     foreach $m (@{$self->{CONFIG}}){
 	# SITE*EXP macros are defined in &constants; avoid duplicates here
 	next if $once_only{$m};
@@ -434,9 +435,11 @@ sub constants {
     my($self) = @_;
     my @m = ();
 
+    $self->{DFSEP} = '$(DIRFILESEP)';  # alias for internal use
+
     for my $macro (qw(
 
-              AR_STATIC_ARGS DIRFILESEP
+              AR_STATIC_ARGS DIRFILESEP DFSEP
               NAME NAME_SYM 
               VERSION    VERSION_MACRO    VERSION_SYM DEFINE_VERSION
               XS_VERSION XS_VERSION_MACRO             XS_DEFINE_VERSION
@@ -605,7 +608,7 @@ sub dir_target {
 
         push @targs, $targ;
         $make .= <<MAKE_FRAG;
-$targ ::
+$dir\$(DFSEP).exists ::
 	\$(NOECHO) \$(MKPATH) $targdir
 	\$(NOECHO) \$(TOUCH) $targ
 	\$(NOECHO) \$(CHMOD) \$(PERM_RWX) $targdir
@@ -3481,6 +3484,16 @@ $target :: $plfile
     join "", @m;
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
--- lib/ExtUtils/MM_Win32.pm
+++ lib/ExtUtils/MM_Win32.pm
@@ -24,7 +24,7 @@ use File::Basename;
 use File::Spec;
 use ExtUtils::MakeMaker qw( neatvalue );
 
-use vars qw(@ISA $VERSION $BORLAND $GCC $DMAKE $NMAKE);
+use vars qw(@ISA $VERSION $BORLAND $GCC $DMAKE $NMAKE $GMAKE);
 
 require ExtUtils::MM_Any;
 require ExtUtils::MM_Unix;
@@ -36,6 +36,7 @@ $ENV{EMXSHELL} = 'sh'; # to run `commands`
 $BORLAND = 1 if $Config{'cc'} =~ /^bcc/i;
 $GCC     = 1 if $Config{'cc'} =~ /^gcc/i;
 $DMAKE = 1 if $Config{'make'} =~ /^dmake/i;
+$GMAKE = 1 if $Config{'make'} =~ /^gmake/i;
 $NMAKE = 1 if $Config{'make'} =~ /^nmake/i;
 
 
@@ -146,7 +147,8 @@ sub init_DIRFILESEP {
 
     # The ^ makes sure its not interpreted as an escape in nmake
     $self->{DIRFILESEP} = $NMAKE ? '^\\' :
-                          $DMAKE ? '\\\\'
+                          $DMAKE ? '\\\\' :
+                          $GMAKE ? '/'
                                  : '\\';
 }
 
@@ -234,6 +236,17 @@ sub platform_constants {
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
+    return '' unless $GMAKE;
+    "\nSHELL = $ENV{COMSPEC}\n";
+}
 
 =item special_targets (o)
 
PATCH
        return;
    }

    if (_ge($version, "5.9.0")) {
        _patch(<<'PATCH');
--- lib/ExtUtils/MM_Unix.pm
+++ lib/ExtUtils/MM_Unix.pm
@@ -381,10 +381,11 @@ sub const_config {
 # --- Constants Sections ---
 
     my($self) = shift;
-    my(@m,$m);
+    my @m = $self->specify_shell(); # Usually returns empty string
     push(@m,"\n# These definitions are from config.sh (via $INC{'Config.pm'})\n");
     push(@m,"\n# They may have been overridden via Makefile.PL or on the command line\n");
     my(%once_only);
+    my($m);
     foreach $m (@{$self->{CONFIG}}){
 	# SITE*EXP macros are defined in &constants; avoid duplicates here
 	next if $once_only{$m};
@@ -433,9 +434,11 @@ sub constants {
     my($self) = @_;
     my @m = ();
 
+    $self->{DFSEP} = '$(DIRFILESEP)';  # alias for internal use
+
     for my $macro (qw(
 
-              AR_STATIC_ARGS DIRFILESEP
+              AR_STATIC_ARGS DIRFILESEP DFSEP
               NAME NAME_SYM 
               VERSION    VERSION_MACRO    VERSION_SYM DEFINE_VERSION
               XS_VERSION XS_VERSION_MACRO             XS_DEFINE_VERSION
@@ -591,7 +594,7 @@ sub dir_target {
 	}
 	next if $self->{DIR_TARGET}{$self}{$targdir}++;
 	push @m, qq{
-$targ :: $src
+$dir\$(DFSEP).exists :: $src
 	\$(NOECHO) \$(MKPATH) $targdir
 	\$(NOECHO) \$(EQUALIZE_TIMESTAMP) $src $targ
 };
@@ -2633,7 +2636,7 @@ realclean ::
 	last unless defined $from;
 	my $todir = dirname($to);
 	push @m, "
-$to: $from \$(FIRST_MAKEFILE) " . $self->catdir($todir,'.exists') . "
+$to: $from \$(FIRST_MAKEFILE) $todir\$(DFSEP).exists
 	\$(NOECHO) \$(RM_F) $to
 	\$(CP) $from $to
 	\$(FIXIN) $to
@@ -3470,6 +3473,16 @@ $target :: $plfile
     join "", @m;
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
--- lib/ExtUtils/MM_Win32.pm
+++ lib/ExtUtils/MM_Win32.pm
@@ -24,7 +24,7 @@ use File::Basename;
 use File::Spec;
 use ExtUtils::MakeMaker qw( neatvalue );
 
-use vars qw(@ISA $VERSION $BORLAND $GCC $DMAKE $NMAKE);
+use vars qw(@ISA $VERSION $BORLAND $GCC $DMAKE $NMAKE $GMAKE);
 
 require ExtUtils::MM_Any;
 require ExtUtils::MM_Unix;
@@ -36,6 +36,7 @@ $ENV{EMXSHELL} = 'sh'; # to run `commands`
 $BORLAND = 1 if $Config{'cc'} =~ /^bcc/i;
 $GCC     = 1 if $Config{'cc'} =~ /^gcc/i;
 $DMAKE = 1 if $Config{'make'} =~ /^dmake/i;
+$GMAKE = 1 if $Config{'make'} =~ /^gmake/i;
 $NMAKE = 1 if $Config{'make'} =~ /^nmake/i;
 
 
@@ -146,7 +147,8 @@ sub init_DIRFILESEP {
 
     # The ^ makes sure its not interpreted as an escape in nmake
     $self->{DIRFILESEP} = $NMAKE ? '^\\' :
-                          $DMAKE ? '\\\\'
+                          $DMAKE ? '\\\\' :
+                          $GMAKE ? '/'
                                  : '\\';
 }
 
@@ -234,6 +236,17 @@ sub platform_constants {
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
+    return '' unless $GMAKE;
+    "\nSHELL = $ENV{COMSPEC}\n";
+}
 
 =item special_targets (o)
 
PATCH
        return;
    }

    if (_ge($version, "5.8.9")) {
        _patch(<<'PATCH');
--- lib/ExtUtils/MM_Unix.pm
+++ lib/ExtUtils/MM_Unix.pm
@@ -296,8 +296,8 @@ sub const_cccmd {
 
 =item const_config (o)
 
-Defines a couple of constants in the Makefile that are imported from
-%Config.
+Sets SHELL if needed, then defines a couple of constants in the Makefile
+that are imported from %Config.
 
 =cut
 
@@ -305,7 +305,8 @@ sub const_config {
 # --- Constants Sections ---
 
     my($self) = shift;
-    my @m = <<"END";
+    my @m = $self->specify_shell(); # Usually returns empty string
+    push @m, <<"END";
 
 # These definitions are from config.sh (via $INC{'Config.pm'}).
 # They may have been overridden via Makefile.PL or on the command line.
@@ -3056,6 +3057,16 @@ MAKE_FRAG
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
--- lib/ExtUtils/MM_Win32.pm
+++ lib/ExtUtils/MM_Win32.pm
@@ -128,7 +128,8 @@ sub init_DIRFILESEP {
 
     # The ^ makes sure its not interpreted as an escape in nmake
     $self->{DIRFILESEP} = $self->is_make_type('nmake') ? '^\\' :
-                          $self->is_make_type('dmake') ? '\\\\'
+                          $self->is_make_type('dmake') ? '\\\\' :
+                          $self->is_make_type('gmake') ? '/'
                                                        : '\\';
 }
 
@@ -153,7 +154,7 @@ sub init_others {
     $self->{DEV_NULL} ||= '> NUL';
 
     $self->{FIXIN}    ||= $self->{PERL_CORE} ? 
-      "\$(PERLRUN) $self->{PERL_SRC}/win32/bin/pl2bat.pl" : 
+      "\$(PERLRUN) $self->{PERL_SRC}\\win32\\bin\\pl2bat.pl" :
       'pl2bat.bat';
 
     $self->{LD}     ||= 'link';
@@ -209,6 +210,17 @@ sub platform_constants {
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
 
 =item special_targets
 
PATCH
        return;
    }

    if (_ge($version, "5.8.1")) {
        _patch(<<'PATCH');
--- lib/ExtUtils/MM_Any.pm
+++ lib/ExtUtils/MM_Any.pm
@@ -339,6 +339,29 @@ END_OF_TARGET
 
 }
 
+=head3 make
+
+    my $make = $MM->make;
+
+Returns the make variant we're generating the Makefile for.  This attempts
+to do some normalization on the information from %Config or the user.
+
+=cut
+
+sub make {
+    my $self = shift;
+
+    my $make = lc $self->{MAKE};
+
+    # Truncate anything like foomake6 to just foomake.
+    $make =~ s/^(\w+make).*/$1/;
+
+    # Turn gnumake into gmake.
+    $make =~ s/^gnu/g/;
+
+    return $make;
+}
+
 
 =item manifypods_target
 
@@ -847,6 +870,19 @@ Michael G Schwern <schwern@pobox.com> and the denizens of
 makemaker@perl.org with code from ExtUtils::MM_Unix and
 ExtUtils::MM_Win32.
 
+=head3 init_MAKE
+
+    $mm->init_MAKE
+
+Initialize MAKE from either a MAKE environment variable or $Config{make}.
+
+=cut
+
+sub init_MAKE {
+    my $self = shift;
+ 
+    $self->{MAKE} ||= $ENV{MAKE} || $Config{make};
+}
 
 =cut
 
--- lib/ExtUtils/MM_Unix.pm
+++ lib/ExtUtils/MM_Unix.pm
@@ -372,8 +372,8 @@ sub const_cccmd {
 
 =item const_config (o)
 
-Defines a couple of constants in the Makefile that are imported from
-%Config.
+Sets SHELL if needed, then defines a couple of constants in the Makefile
+that are imported from %Config.
 
 =cut
 
@@ -384,6 +384,7 @@ sub const_config {
     my(@m,$m);
     push(@m,"\n# These definitions are from config.sh (via $INC{'Config.pm'})\n");
     push(@m,"\n# They may have been overridden via Makefile.PL or on the command line\n");
+    push(@m, $self->specify_shell()); # Usually returns empty string
     my(%once_only);
     foreach $m (@{$self->{CONFIG}}){
 	# SITE*EXP macros are defined in &constants; avoid duplicates here
@@ -433,9 +434,11 @@ sub constants {
     my($self) = @_;
     my @m = ();
 
+    $self->{DFSEP} = '$(DIRFILESEP)';  # alias for internal use
+
     for my $macro (qw(
 
-              AR_STATIC_ARGS DIRFILESEP
+              AR_STATIC_ARGS DIRFILESEP DFSEP
               NAME NAME_SYM 
               VERSION    VERSION_MACRO    VERSION_SYM DEFINE_VERSION
               XS_VERSION XS_VERSION_MACRO             XS_DEFINE_VERSION
@@ -591,7 +594,7 @@ sub dir_target {
 	}
 	next if $self->{DIR_TARGET}{$self}{$targdir}++;
 	push @m, qq{
-$targ :: $src
+$dir\$(DFSEP).exists :: $src
 	\$(NOECHO) \$(MKPATH) $targdir
 	\$(NOECHO) \$(EQUALIZE_TIMESTAMP) $src $targ
 };
@@ -2633,7 +2636,7 @@ realclean ::
 	last unless defined $from;
 	my $todir = dirname($to);
 	push @m, "
-$to: $from \$(FIRST_MAKEFILE) " . $self->catdir($todir,'.exists') . "
+$to: $from \$(FIRST_MAKEFILE) $todir\$(DFSEP).exists
 	\$(NOECHO) \$(RM_F) $to
 	\$(CP) $from $to
 	\$(FIXIN) $to
@@ -3470,6 +3473,16 @@ $target :: $plfile
     join "", @m;
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
--- lib/ExtUtils/MM_Win32.pm
+++ lib/ExtUtils/MM_Win32.pm
@@ -137,7 +137,7 @@ sub find_tests {
 
 =item B<init_DIRFILESEP>
 
-Using \ for Windows.
+Using \ for Windows, except for "gmake" where it is /.
 
 =cut
 
@@ -145,9 +145,10 @@ sub init_DIRFILESEP {
     my($self) = shift;
 
     # The ^ makes sure its not interpreted as an escape in nmake
-    $self->{DIRFILESEP} = $NMAKE ? '^\\' :
-                          $DMAKE ? '\\\\'
-                                 : '\\';
+    $self->{DIRFILESEP} = $self->is_make_type('nmake') ? '^\\' :
+                          $self->is_make_type('dmake') ? '\\\\' :
+                          $self->is_make_type('gmake') ? '/'
+                                                       : '\\';
 }
 
 =item B<init_others>
@@ -510,6 +511,22 @@ sub os_flavor {
     return('Win32');
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
+
+sub is_make_type {
+    my($self, $type) = @_;
+    return !! ($self->make =~ /\b$type(?:\.exe)?$/);
+}
 
 1;
 __END__
--- lib/ExtUtils/MakeMaker.pm
+++ lib/ExtUtils/MakeMaker.pm
@@ -482,6 +482,7 @@ sub new {
 
     ($self->{NAME_SYM} = $self->{NAME}) =~ s/\W+/_/g;
 
+    $self->init_MAKE;
     $self->init_main;
     $self->init_VERSION;
     $self->init_dist;
PATCH
        return;
    }

    if (_ge($version, "5.8.0")) {
        _patch(<<'PATCH');
--- lib/ExtUtils/MM_Any.pm
+++ lib/ExtUtils/MM_Any.pm
@@ -169,6 +169,43 @@ sub test_via_script {
 
 =back
 
+=head3 make
+
+    my $make = $MM->make;
+
+Returns the make variant we're generating the Makefile for.  This attempts
+to do some normalization on the information from %Config or the user.
+
+=cut
+
+sub make {
+    my $self = shift;
+
+    my $make = lc $self->{MAKE};
+
+    # Truncate anything like foomake6 to just foomake.
+    $make =~ s/^(\w+make).*/$1/;
+
+    # Turn gnumake into gmake.
+    $make =~ s/^gnu/g/;
+
+    return $make;
+}
+
+=head3 init_MAKE
+
+    $mm->init_MAKE
+
+Initialize MAKE from either a MAKE environment variable or $Config{make}.
+
+=cut
+
+sub init_MAKE {
+    my $self = shift;
+
+    $self->{MAKE} ||= $ENV{MAKE} || $Config{make};
+}
+
 =head1 AUTHOR
 
 Michael G Schwern <schwern@pobox.com> with code from ExtUtils::MM_Unix
--- lib/ExtUtils/MM_Unix.pm
+++ lib/ExtUtils/MM_Unix.pm
@@ -415,8 +415,8 @@ sub const_cccmd {
 
 =item const_config (o)
 
-Defines a couple of constants in the Makefile that are imported from
-%Config.
+Sets SHELL if needed, then defines a couple of constants in the Makefile
+that are imported from %Config.
 
 =cut
 
@@ -427,6 +427,7 @@ sub const_config {
     my(@m,$m);
     push(@m,"\n# These definitions are from config.sh (via $INC{'Config.pm'})\n");
     push(@m,"\n# They may have been overridden via Makefile.PL or on the command line\n");
+    push(@m, $self->specify_shell()); # Usually returns empty string
     my(%once_only);
     foreach $m (@{$self->{CONFIG}}){
 	# SITE*EXP macros are defined in &constants; avoid duplicates here
@@ -474,9 +475,12 @@ sub constants {
     my($self) = @_;
     my(@m,$tmp);
 
+    $self->{DFSEP} = '$(DIRFILESEP)';  # alias for internal use
+
     for $tmp (qw/
 
 	      AR_STATIC_ARGS NAME DISTNAME NAME_SYM VERSION
+          DIRFILESEP DFSEP
 	      VERSION_SYM XS_VERSION 
 	      INST_ARCHLIB INST_SCRIPT INST_BIN INST_LIB
               INSTALLDIRS
@@ -582,7 +586,7 @@ makemakerdflt: all
 .PHONY: all config static dynamic test linkext manifest
 
 # Where is the Config information that we are using/depend on
-CONFIGDEP = \$(PERL_ARCHLIB)/Config.pm \$(PERL_INC)/config.h
+CONFIGDEP = \$(PERL_ARCHLIB)/Config.pm \$(PERL_INC)\$(DIRFILESEP)config.h
 };
 
     my @parentdir = split(/::/, $self->{PARENT_NAME});
@@ -942,7 +946,7 @@ BOOTSTRAP = '."$self->{BASEEXT}.bs".'
 # As Mkbootstrap might not write a file (if none is required)
 # we use touch to prevent make continually trying to remake it.
 # The DynaLoader only reads a non-empty file.
-$(BOOTSTRAP): '."$self->{MAKEFILE} $self->{BOOTDEP}".' $(INST_ARCHAUTODIR)/.exists
+$(BOOTSTRAP): '."$self->{MAKEFILE} $self->{BOOTDEP}".' $(INST_ARCHAUTODIR)$(DIRFILESEP).exists
 	'.$self->{NOECHO}.'echo "Running Mkbootstrap for $(NAME) ($(BSLOADLIBS))"
 	'.$self->{NOECHO}.'$(PERLRUN) \
 		"-MExtUtils::Mkbootstrap" \
@@ -950,7 +954,7 @@ $(BOOTSTRAP): '."$self->{MAKEFILE} $self->{BOOTDEP}".' $(INST_ARCHAUTODIR)/.exis
 	'.$self->{NOECHO}.'$(TOUCH) $(BOOTSTRAP)
 	$(CHMOD) $(PERM_RW) $@
 
-$(INST_BOOT): $(BOOTSTRAP) $(INST_ARCHAUTODIR)/.exists
+$(INST_BOOT): $(BOOTSTRAP) $(INST_ARCHAUTODIR)$(DIRFILESEP).exists
 	'."$self->{NOECHO}$self->{RM_RF}".' $(INST_BOOT)
 	-'.$self->{CP}.' $(BOOTSTRAP) $(INST_BOOT)
 	$(CHMOD) $(PERM_RW) $@
@@ -983,7 +987,7 @@ ARMAYBE = '.$armaybe.'
 OTHERLDFLAGS = '.$ld_opt.$otherldflags.'
 INST_DYNAMIC_DEP = '.$inst_dynamic_dep.'
 
-$(INST_DYNAMIC): $(OBJECT) $(MYEXTLIB) $(BOOTSTRAP) $(INST_ARCHAUTODIR)/.exists $(EXPORT_LIST) $(PERL_ARCHIVE) $(PERL_ARCHIVE_AFTER) $(INST_DYNAMIC_DEP)
+$(INST_DYNAMIC): $(OBJECT) $(MYEXTLIB) $(BOOTSTRAP) $(INST_ARCHAUTODIR)$(DIRFILESEP).exists $(EXPORT_LIST) $(PERL_ARCHIVE) $(PERL_ARCHIVE_AFTER) $(INST_DYNAMIC_DEP)
 ');
     if ($armaybe ne ':'){
 	$ldfrom = 'tmp$(LIB_EXT)';
@@ -1492,6 +1496,16 @@ sub init_dirscan {	# --- File and Directory Lists (.xs .pm .pod etc)
     }
 }
 
+=item init_DIRFILESEP
+Using / for Unix.  Called by init_main.
+=cut
+
+sub init_DIRFILESEP {
+    my($self) = shift;
+
+    $self->{DIRFILESEP} = '/';
+}
+
 =item init_main
 
 Initializes AR, AR_STATIC_ARGS, BASEEXT, CONFIG, DISTNAME, DLBASE,
@@ -2615,7 +2629,7 @@ LLIBPERL    = $llibperl
 ";
 
     push @m, "
-\$(INST_ARCHAUTODIR)/extralibs.all: \$(INST_ARCHAUTODIR)/.exists ".join(" \\\n\t", @$extra)."
+\$(INST_ARCHAUTODIR)/extralibs.all: \$(INST_ARCHAUTODIR)\$(DIRFILESEP).exists ".join(" \\\n\t", @$extra)."
 	$self->{NOECHO}$self->{RM_F} \$\@
 	$self->{NOECHO}\$(TOUCH) \$\@
 ";
@@ -3434,7 +3448,7 @@ sub static_lib {
 
     my(@m);
     push(@m, <<'END');
-$(INST_STATIC): $(OBJECT) $(MYEXTLIB) $(INST_ARCHAUTODIR)/.exists
+$(INST_STATIC): $(OBJECT) $(MYEXTLIB) $(INST_ARCHAUTODIR)$(DIRFILESEP).exists
 	$(RM_RF) $@
 END
     # If this extension has its own library (eg SDBM_File)
@@ -3887,13 +3901,13 @@ pure_all :: config pm_to_blib subdirs linkext
 subdirs :: $(MYEXTLIB)
 	'.$self->{NOECHO}.'$(NOOP)
 
-config :: '.$self->{MAKEFILE}.' $(INST_LIBDIR)/.exists
+config :: '.$self->{MAKEFILE}.' $(INST_LIBDIR)$(DIRFILESEP).exists
 	'.$self->{NOECHO}.'$(NOOP)
 
-config :: $(INST_ARCHAUTODIR)/.exists
+config :: $(INST_ARCHAUTODIR)$(DIRFILESEP).exists
 	'.$self->{NOECHO}.'$(NOOP)
 
-config :: $(INST_AUTODIR)/.exists
+config :: $(INST_AUTODIR)$(DIRFILESEP).exists
 	'.$self->{NOECHO}.'$(NOOP)
 ';
 
@@ -3901,7 +3915,7 @@ config :: $(INST_AUTODIR)/.exists
 
     if (%{$self->{MAN1PODS}}) {
 	push @m, qq[
-config :: \$(INST_MAN1DIR)/.exists
+config :: \$(INST_MAN1DIR)$(DIRFILESEP).exists
 	$self->{NOECHO}\$(NOOP)
 
 ];
@@ -3909,7 +3923,7 @@ config :: \$(INST_MAN1DIR)/.exists
     }
     if (%{$self->{MAN3PODS}}) {
 	push @m, qq[
-config :: \$(INST_MAN3DIR)/.exists
+config :: \$(INST_MAN3DIR)$(DIRFILESEP).exists
 	$self->{NOECHO}\$(NOOP)
 
 ];
--- lib/ExtUtils/MM_Win32.pm
+++ lib/ExtUtils/MM_Win32.pm
@@ -147,6 +147,19 @@ sub find_tests {
     return join(' ', <t\\*.t>);
 }
 
+=item B<init_DIRFILESEP>
+Using \ for Windows.
+=cut
+
+sub init_DIRFILESEP {
+    my($self) = shift;
+
+    # The ^ makes sure its not interpreted as an escape in nmake
+    $self->{DIRFILESEP} = $self->is_make_type('nmake') ? '^\\' :
+                          $self->is_make_type('dmake') ? '\\\\' :
+                          $self->is_make_type('gmake') ? '/'
+                                                       : '\\';
+}
 
 sub init_others
 {
@@ -781,6 +794,22 @@ sub pasthru {
     return "PASTHRU = " . ($NMAKE ? "-nologo" : "");
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
+
+sub is_make_type {
+    my($self, $type) = @_;
+    return !! ($self->make =~ /\b$type(?:\.exe)?$/);
+}
 
 1;
 __END__
--- lib/ExtUtils/MakeMaker.pm
+++ lib/ExtUtils/MakeMaker.pm
@@ -520,7 +520,9 @@ sub new {
 
     ($self->{NAME_SYM} = $self->{NAME}) =~ s/\W+/_/g;
 
-    $self->init_main();
+    $self->init_main;
+    $self->init_MAKE;
+    $self->init_DIRFILESEP;
 
     if (! $self->{PERL_SRC} ) {
         require VMS::Filespec if $Is_VMS;
PATCH
        return;
    }

    if (_ge($version, "5.7.3")) {
        _patch(<<'PATCH');
--- lib/ExtUtils/MM_Unix.pm
+++ lib/ExtUtils/MM_Unix.pm
@@ -182,6 +182,7 @@ sub has_link_code;
 sub htmlifypods;
 sub init_dirscan;
 sub init_main;
+sub init_DIRFILESEP;
 sub init_others;
 sub install;
 sub installbin;
@@ -537,8 +538,11 @@ sub constants {
     my($self) = @_;
     my(@m,$tmp);
 
+    $self->{DFSEP} = '$(DIRFILESEP)';  # alias for internal use
+
     for $tmp (qw/
 
+	      DIRFILESEP DFSEP
 	      AR_STATIC_ARGS NAME DISTNAME NAME_SYM VERSION
 	      VERSION_SYM XS_VERSION INST_BIN INST_EXE INST_LIB
 	      INST_ARCHLIB INST_SCRIPT PREFIX  INSTALLDIRS
@@ -1022,7 +1026,7 @@ BOOTSTRAP = '."$self->{BASEEXT}.bs".'
 # As Mkbootstrap might not write a file (if none is required)
 # we use touch to prevent make continually trying to remake it.
 # The DynaLoader only reads a non-empty file.
-$(BOOTSTRAP): '."$self->{MAKEFILE} $self->{BOOTDEP}".' $(INST_ARCHAUTODIR)/.exists
+$(BOOTSTRAP): '."$self->{MAKEFILE} $self->{BOOTDEP}".' $(INST_ARCHAUTODIR)$(DFSEP).exists
 	'.$self->{NOECHO}.'echo "Running Mkbootstrap for $(NAME) ($(BSLOADLIBS))"
 	'.$self->{NOECHO}.'$(PERLRUN) \
 		-MExtUtils::Mkbootstrap \
@@ -1030,7 +1034,7 @@ $(BOOTSTRAP): '."$self->{MAKEFILE} $self->{BOOTDEP}".' $(INST_ARCHAUTODIR)/.exis
 	'.$self->{NOECHO}.'$(TOUCH) $(BOOTSTRAP)
 	$(CHMOD) $(PERM_RW) $@
 
-$(INST_BOOT): $(BOOTSTRAP) $(INST_ARCHAUTODIR)/.exists
+$(INST_BOOT): $(BOOTSTRAP) $(INST_ARCHAUTODIR)$(DFSEP).exists
 	'."$self->{NOECHO}$self->{RM_RF}".' $(INST_BOOT)
 	-'.$self->{CP}.' $(BOOTSTRAP) $(INST_BOOT)
 	$(CHMOD) $(PERM_RW) $@
@@ -1063,7 +1067,7 @@ ARMAYBE = '.$armaybe.'
 OTHERLDFLAGS = '.$ld_opt.$otherldflags.'
 INST_DYNAMIC_DEP = '.$inst_dynamic_dep.'
 
-$(INST_DYNAMIC): $(OBJECT) $(MYEXTLIB) $(BOOTSTRAP) $(INST_ARCHAUTODIR)/.exists $(EXPORT_LIST) $(PERL_ARCHIVE) $(PERL_ARCHIVE_AFTER) $(INST_DYNAMIC_DEP)
+$(INST_DYNAMIC): $(OBJECT) $(MYEXTLIB) $(BOOTSTRAP) $(INST_ARCHAUTODIR)$(DFSEP).exists $(EXPORT_LIST) $(PERL_ARCHIVE) $(PERL_ARCHIVE_AFTER) $(INST_DYNAMIC_DEP)
 ');
     if ($armaybe ne ':'){
 	$ldfrom = 'tmp$(LIB_EXT)';
@@ -2073,6 +2077,20 @@ usually solves this kind of problem.
         $self->{$targ} .= " -${aq}I\$(PERL_ARCHLIB)$aq -${aq}I\$(PERL_LIB)$aq"
           if $self->{PERL_CORE};
     }
+
+    $self->init_DIRFILESEP();
+}
+
+=item init_DIRFILESEP
+
+Using / for Unix.  Called by init_main.
+
+=cut
+
+sub init_DIRFILESEP {
+    my($self) = shift;
+
+    $self->{DIRFILESEP} = '/';
 }
 
 =item init_others
@@ -2543,7 +2561,7 @@ MAP_LIBPERL = $libperl
 ";
 
     push @m, "
-\$(INST_ARCHAUTODIR)/extralibs.all: \$(INST_ARCHAUTODIR)/.exists ".join(" \\\n\t", @$extra)."
+\$(INST_ARCHAUTODIR)$(DFSEP)extralibs.all: \$(INST_ARCHAUTODIR)$(DFSEP).exists ".join(" \\\n\t", @$extra)."
 	$self->{NOECHO}$self->{RM_F} \$\@
 	$self->{NOECHO}\$(TOUCH) \$\@
 ";
@@ -3319,7 +3337,7 @@ sub static_lib {
 
     my(@m);
     push(@m, <<'END');
-$(INST_STATIC): $(OBJECT) $(MYEXTLIB) $(INST_ARCHAUTODIR)/.exists
+$(INST_STATIC): $(OBJECT) $(MYEXTLIB) $(INST_ARCHAUTODIR)$(DFSEP).exists
 	$(RM_RF) $@
 END
     # If this extension has its own library (eg SDBM_File)
@@ -3767,13 +3785,13 @@ pure_all :: config pm_to_blib subdirs linkext
 subdirs :: $(MYEXTLIB)
 	'.$self->{NOECHO}.'$(NOOP)
 
-config :: '.$self->{MAKEFILE}.' $(INST_LIBDIR)/.exists
+config :: '.$self->{MAKEFILE}.' $(INST_LIBDIR)$(DFSEP).exists
 	'.$self->{NOECHO}.'$(NOOP)
 
-config :: $(INST_ARCHAUTODIR)/.exists
+config :: $(INST_ARCHAUTODIR)$(DFSEP).exists
 	'.$self->{NOECHO}.'$(NOOP)
 
-config :: $(INST_AUTODIR)/.exists
+config :: $(INST_AUTODIR)$(DFSEP).exists
 	'.$self->{NOECHO}.'$(NOOP)
 ';
 
@@ -3781,7 +3799,7 @@ config :: $(INST_AUTODIR)/.exists
 
     if (%{$self->{HTMLLIBPODS}}) {
 	push @m, qq[
-config :: \$(INST_HTMLLIBDIR)/.exists
+config :: \$(INST_HTMLLIBDIR)$(DFSEP).exists
 	$self->{NOECHO}\$(NOOP)
 
 ];
@@ -3790,7 +3808,7 @@ config :: \$(INST_HTMLLIBDIR)/.exists
 
     if (%{$self->{HTMLSCRIPTPODS}}) {
 	push @m, qq[
-config :: \$(INST_HTMLSCRIPTDIR)/.exists
+config :: \$(INST_HTMLSCRIPTDIR)$(DFSEP).exists
 	$self->{NOECHO}\$(NOOP)
 
 ];
@@ -3799,7 +3817,7 @@ config :: \$(INST_HTMLSCRIPTDIR)/.exists
 
     if (%{$self->{MAN1PODS}}) {
 	push @m, qq[
-config :: \$(INST_MAN1DIR)/.exists
+config :: \$(INST_MAN1DIR)$(DFSEP).exists
 	$self->{NOECHO}\$(NOOP)
 
 ];
@@ -3807,7 +3825,7 @@ config :: \$(INST_MAN1DIR)/.exists
     }
     if (%{$self->{MAN3PODS}}) {
 	push @m, qq[
-config :: \$(INST_MAN3DIR)/.exists
+config :: \$(INST_MAN3DIR)$(DFSEP).exists
 	$self->{NOECHO}\$(NOOP)
 
 ];
--- lib/ExtUtils/MM_Win32.pm
+++ lib/ExtUtils/MM_Win32.pm
@@ -37,6 +37,7 @@ $GCC     = 1 if $Config{'cc'} =~ /^gcc/i;
 $DMAKE = 1 if $Config{'make'} =~ /^dmake/i;
 $NMAKE = 1 if $Config{'make'} =~ /^nmake/i;
 $PERLMAKE = 1 if $Config{'make'} =~ /^pmake/i;
+$GMAKE = 1 if $Config{'make'} =~ /^gmake/i;
 
 # a few workarounds for command.com (very basic)
 {
@@ -198,6 +199,22 @@ sub catfile {
     return File::Spec->catfile(@_);
 }
 
+=item init_DIRFILESEP
+
+Using \ for Windows.
+
+=cut
+
+sub init_DIRFILESEP {
+    my($self) = shift;
+
+    # The ^ makes sure its not interpreted as an escape in nmake
+    $self->{DIRFILESEP} = $NMAKE ? '^\\' :
+                          $DMAKE ? '\\\\' :
+                          $GMAKE ? '/'
+                                 : '\\';
+}
+
 sub init_others
 {
  my ($self) = @_;
@@ -240,8 +257,11 @@ sub constants {
     my($self) = @_;
     my(@m,$tmp);
 
+    $self->{DFSEP} = '$(DIRFILESEP)';  # alias for internal use
+
     for $tmp (qw/
 
+	      DIRFILESEP DFSEP
 	      AR_STATIC_ARGS NAME DISTNAME NAME_SYM VERSION
 	      VERSION_SYM XS_VERSION INST_BIN INST_EXE INST_LIB
 	      INST_ARCHLIB INST_SCRIPT PREFIX  INSTALLDIRS
@@ -655,9 +675,14 @@ sub tools_other {
     my($self) = shift;
     my @m;
     my $bin_sh = $Config{sh} || 'cmd /c';
-    push @m, qq{
+
+    if ($GMAKE) {
+        push @m, "\nSHELL = $ENV{COMSPEC}\n";
+    } elsif (!$DMAKE) { # dmake determines its own shell
+        push @m, qq{
 SHELL = $bin_sh
-} unless $DMAKE;  # dmake determines its own shell 
+}
+    }
 
     for (qw/ CHMOD CP LD MV NOOP RM_F RM_RF TEST_F TOUCH UMASK_NULL DEV_NULL/ ) {
 	push @m, "$_ = $self->{$_}\n";
PATCH
        return;
    }

    if (_ge($version, "5.7.2")) {
        _patch(<<'PATCH');
--- lib/ExtUtils/MM_Unix.pm
+++ lib/ExtUtils/MM_Unix.pm
@@ -194,6 +194,7 @@ sub ExtUtils::MM_Unix::has_link_code ;
 sub ExtUtils::MM_Unix::htmlifypods ;
 sub ExtUtils::MM_Unix::init_dirscan ;
 sub ExtUtils::MM_Unix::init_main ;
+sub ExtUtils::MM_Unix::init_DIRFILESEP ;
 sub ExtUtils::MM_Unix::init_others ;
 sub ExtUtils::MM_Unix::install ;
 sub ExtUtils::MM_Unix::installbin ;
@@ -566,8 +567,11 @@ sub constants {
     my($self) = @_;
     my(@m,$tmp);
 
+    $self->{DFSEP} = '$(DIRFILESEP)';  # alias for internal use
+
     for $tmp (qw/
 
+	      DIRFILESEP DFSEP
 	      AR_STATIC_ARGS NAME DISTNAME NAME_SYM VERSION
 	      VERSION_SYM XS_VERSION INST_BIN INST_EXE INST_LIB
 	      INST_ARCHLIB INST_SCRIPT PREFIX  INSTALLDIRS
@@ -1051,7 +1055,7 @@ BOOTSTRAP = '."$self->{BASEEXT}.bs".'
 # As Mkbootstrap might not write a file (if none is required)
 # we use touch to prevent make continually trying to remake it.
 # The DynaLoader only reads a non-empty file.
-$(BOOTSTRAP): '."$self->{MAKEFILE} $self->{BOOTDEP}".' $(INST_ARCHAUTODIR)/.exists
+$(BOOTSTRAP): '."$self->{MAKEFILE} $self->{BOOTDEP}".' $(INST_ARCHAUTODIR)$(DFSEP).exists
 	'.$self->{NOECHO}.'echo "Running Mkbootstrap for $(NAME) ($(BSLOADLIBS))"
 	'.$self->{NOECHO}.'$(PERLRUN) \
 		-MExtUtils::Mkbootstrap \
@@ -1059,7 +1063,7 @@ $(BOOTSTRAP): '."$self->{MAKEFILE} $self->{BOOTDEP}".' $(INST_ARCHAUTODIR)/.exis
 	'.$self->{NOECHO}.'$(TOUCH) $(BOOTSTRAP)
 	$(CHMOD) $(PERM_RW) $@
 
-$(INST_BOOT): $(BOOTSTRAP) $(INST_ARCHAUTODIR)/.exists
+$(INST_BOOT): $(BOOTSTRAP) $(INST_ARCHAUTODIR)$(DFSEP).exists
 	'."$self->{NOECHO}$self->{RM_RF}".' $(INST_BOOT)
 	-'.$self->{CP}.' $(BOOTSTRAP) $(INST_BOOT)
 	$(CHMOD) $(PERM_RW) $@
@@ -1092,7 +1096,7 @@ ARMAYBE = '.$armaybe.'
 OTHERLDFLAGS = '.$ld_opt.$otherldflags.'
 INST_DYNAMIC_DEP = '.$inst_dynamic_dep.'
 
-$(INST_DYNAMIC): $(OBJECT) $(MYEXTLIB) $(BOOTSTRAP) $(INST_ARCHAUTODIR)/.exists $(EXPORT_LIST) $(PERL_ARCHIVE) $(PERL_ARCHIVE_AFTER) $(INST_DYNAMIC_DEP)
+$(INST_DYNAMIC): $(OBJECT) $(MYEXTLIB) $(BOOTSTRAP) $(INST_ARCHAUTODIR)$(DFSEP).exists $(EXPORT_LIST) $(PERL_ARCHIVE) $(PERL_ARCHIVE_AFTER) $(INST_DYNAMIC_DEP)
 ');
     if ($armaybe ne ':'){
 	$ldfrom = 'tmp$(LIB_EXT)';
@@ -2070,8 +2074,21 @@ usually solves this kind of problem.
         $self->{$targ} .= ' -I$(PERL_ARCHLIB) -I$(PERL_LIB)'
           if $self->{PERL_CORE};
     }
+    $self->init_DIRFILESEP();
 }
 
+=item init_DIRFILESEP
+
+Using / for Unix.  Called by init_main.
+
+=cut
+
+sub init_DIRFILESEP {
+    my($self) = shift;
+
+    $self->{DIRFILESEP} = '/';
+ }
+
 =item init_others
 
 Initializes EXTRALIBS, BSLOADLIBS, LDLOADLIBS, LIBS, LD_RUN_PATH,
@@ -2540,7 +2557,7 @@ MAP_LIBPERL = $libperl
 ";
 
     push @m, "
-\$(INST_ARCHAUTODIR)/extralibs.all: \$(INST_ARCHAUTODIR)/.exists ".join(" \\\n\t", @$extra)."
+\$(INST_ARCHAUTODIR)/extralibs.all: \$(INST_ARCHAUTODIR)$(DFSEP).exists ".join(" \\\n\t", @$extra)."
 	$self->{NOECHO}$self->{RM_F} \$\@
 	$self->{NOECHO}\$(TOUCH) \$\@
 ";
@@ -3278,7 +3295,7 @@ sub static_lib {
 
     my(@m);
     push(@m, <<'END');
-$(INST_STATIC): $(OBJECT) $(MYEXTLIB) $(INST_ARCHAUTODIR)/.exists
+$(INST_STATIC): $(OBJECT) $(MYEXTLIB) $(INST_ARCHAUTODIR)$(DFSEP).exists
 	$(RM_RF) $@
 END
     # If this extension has its own library (eg SDBM_File)
@@ -3727,13 +3744,13 @@ pure_all :: config pm_to_blib subdirs linkext
 subdirs :: $(MYEXTLIB)
 	'.$self->{NOECHO}.'$(NOOP)
 
-config :: '.$self->{MAKEFILE}.' $(INST_LIBDIR)/.exists
+config :: '.$self->{MAKEFILE}.' $(INST_LIBDIR)$(DFSEP).exists
 	'.$self->{NOECHO}.'$(NOOP)
 
-config :: $(INST_ARCHAUTODIR)/.exists
+config :: $(INST_ARCHAUTODIR)$(DFSEP).exists
 	'.$self->{NOECHO}.'$(NOOP)
 
-config :: $(INST_AUTODIR)/.exists
+config :: $(INST_AUTODIR)$(DFSEP).exists
 	'.$self->{NOECHO}.'$(NOOP)
 ';
 
@@ -3741,7 +3758,7 @@ config :: $(INST_AUTODIR)/.exists
 
     if (%{$self->{HTMLLIBPODS}}) {
 	push @m, qq[
-config :: \$(INST_HTMLLIBDIR)/.exists
+config :: \$(INST_HTMLLIBDIR)$(DFSEP).exists
 	$self->{NOECHO}\$(NOOP)
 
 ];
@@ -3750,7 +3767,7 @@ config :: \$(INST_HTMLLIBDIR)/.exists
 
     if (%{$self->{HTMLSCRIPTPODS}}) {
 	push @m, qq[
-config :: \$(INST_HTMLSCRIPTDIR)/.exists
+config :: \$(INST_HTMLSCRIPTDIR)$(DFSEP).exists
 	$self->{NOECHO}\$(NOOP)
 
 ];
@@ -3759,7 +3776,7 @@ config :: \$(INST_HTMLSCRIPTDIR)/.exists
 
     if (%{$self->{MAN1PODS}}) {
 	push @m, qq[
-config :: \$(INST_MAN1DIR)/.exists
+config :: \$(INST_MAN1DIR)$(DFSEP).exists
 	$self->{NOECHO}\$(NOOP)
 
 ];
@@ -3767,7 +3784,7 @@ config :: \$(INST_MAN1DIR)/.exists
     }
     if (%{$self->{MAN3PODS}}) {
 	push @m, qq[
-config :: \$(INST_MAN3DIR)/.exists
+config :: \$(INST_MAN3DIR)$(DFSEP).exists
 	$self->{NOECHO}\$(NOOP)
 
 ];
--- lib/ExtUtils/MM_Win32.pm
+++ lib/ExtUtils/MM_Win32.pm
@@ -36,6 +36,7 @@ $GCC     = 1 if $Config{'cc'} =~ /^gcc/i;
 $DMAKE = 1 if $Config{'make'} =~ /^dmake/i;
 $NMAKE = 1 if $Config{'make'} =~ /^nmake/i;
 $PERLMAKE = 1 if $Config{'make'} =~ /^pmake/i;
+$GMAKE = 1 if $Config{'make'} =~ /^gmake/i;
 $OBJ   = 1 if $Config{'ccflags'} =~ /PERL_OBJECT/i;
 
 # a few workarounds for command.com (very basic)
@@ -203,6 +204,22 @@ sub catfile {
     return $dir.$file;
 }
 
+=item init_DIRFILESEP
+
+Using \ for Windows.
+
+=cut
+
+sub init_DIRFILESEP {
+    my($self) = shift;
+
+    # The ^ makes sure its not interpreted as an escape in nmake
+    $self->{DIRFILESEP} = $NMAKE ? '^\\' :
+                          $DMAKE ? '\\\\' :
+                          $GMAKE ? '/'
+                                 : '\\';
+}
+
 sub init_others
 {
  my ($self) = @_;
@@ -245,8 +262,11 @@ sub constants {
     my($self) = @_;
     my(@m,$tmp);
 
+    $self->{DFSEP} = '$(DIRFILESEP)';  # alias for internal use
+
     for $tmp (qw/
 
+	      DIRFILESEP DFSEP
 	      AR_STATIC_ARGS NAME DISTNAME NAME_SYM VERSION
 	      VERSION_SYM XS_VERSION INST_BIN INST_EXE INST_LIB
 	      INST_ARCHLIB INST_SCRIPT PREFIX  INSTALLDIRS
@@ -664,9 +684,13 @@ sub tools_other {
     my($self) = shift;
     my @m;
     my $bin_sh = $Config{sh} || 'cmd /c';
-    push @m, qq{
+    if ($GMAKE) {
+        push @m, "\nSHELL = $ENV{COMSPEC}\n";
+    } elsif (!$DMAKE) { # dmake determines its own shell
+        push @m, qq{
 SHELL = $bin_sh
-} unless $DMAKE;  # dmake determines its own shell 
+}
+    }
 
     for (qw/ CHMOD CP LD MV NOOP RM_F RM_RF TEST_F TOUCH UMASK_NULL DEV_NULL/ ) {
 	push @m, "$_ = $self->{$_}\n";
PATCH
    }
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
    my $version = shift;
    if (_ge($version, "5.18.0")) {
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
PATCH
    return
    }

    if (_ge($version, "5.12.0")) {
	    _patch(<<'PATCH');
diff --git a/win32/win32.c b/win32/win32.c
index 89413fc28c..fd7b326466 100644
--- win32/win32.c
+++ win32/win32.c
@@ -1090,6 +1090,7 @@ chown(const char *path, uid_t owner, gid_t group)
  * XXX this needs strengthening  (for PerlIO)
  *   -- BKS, 11-11-200
 */
+#if !defined(__MINGW64_VERSION_MAJOR) || __MINGW64_VERSION_MAJOR < 4
 int mkstemp(const char *path)
 {
     dTHX;
@@ -1110,6 +1111,7 @@ retry:
 	goto retry;
     return fd;
 }
+#endif
 
 static long
 find_pid(int pid)
diff --git a/win32/win32.h b/win32/win32.h
index e906266a4a..cc96d338f3 100644
--- win32/win32.h
+++ win32/win32.h
@@ -292,7 +292,9 @@ extern  void	*sbrk(ptrdiff_t need);
 #endif
 extern	char *	getlogin(void);
 extern	int	chown(const char *p, uid_t o, gid_t g);
+#if !defined(__MINGW64_VERSION_MAJOR) || __MINGW64_VERSION_MAJOR < 4
 extern  int	mkstemp(const char *path);
+#endif
 
 #undef	 Stat
 #define  Stat		win32_stat

PATCH
    return
    }

    if (_ge($version, "5.10.1")) {
        _patch(<<'PATCH');
--- win32/win32.c
+++ win32/win32.c
@@ -1101,6 +1101,7 @@ chown(const char *path, uid_t owner, gid_t group)
  * XXX this needs strengthening  (for PerlIO)
  *   -- BKS, 11-11-200
 */
+#if !defined(__MINGW64_VERSION_MAJOR) || __MINGW64_VERSION_MAJOR < 4
 int mkstemp(const char *path)
 {
     dTHX;
@@ -1121,6 +1122,7 @@ retry:
 	goto retry;
     return fd;
 }
+#endif
 
 static long
 find_pid(int pid)
--- win32/win32.h
+++ win32/win32.h
@@ -292,7 +292,9 @@ extern  void	*sbrk(ptrdiff_t need);
 #endif
 extern	char *	getlogin(void);
 extern	int	chown(const char *p, uid_t o, gid_t g);
+#if !defined(__MINGW64_VERSION_MAJOR) || __MINGW64_VERSION_MAJOR < 4
 extern  int	mkstemp(const char *path);
+#endif
 
 #undef	 Stat
 #define  Stat		win32_stat
PATCH
        return
    }

    if (_ge($version, "5.10.0")) {
        _patch(<<'PATCH');
--- win32/win32.c
+++ win32/win32.c
@@ -1101,6 +1101,7 @@ chown(const char *path, uid_t owner, gid_t group)
  * XXX this needs strengthening  (for PerlIO)
  *   -- BKS, 11-11-200
 */
+#if !defined(__MINGW64_VERSION_MAJOR) || __MINGW64_VERSION_MAJOR < 4
 int mkstemp(const char *path)
 {
     dTHX;
@@ -1121,6 +1122,7 @@ retry:
 	goto retry;
     return fd;
 }
+#endif
 
 static long
 find_pid(int pid)
--- win32/win32.h
+++ win32/win32.h
@@ -292,7 +292,9 @@ extern  void	*sbrk(ptrdiff_t need);
 #endif
 extern	char *	getlogin(void);
 extern	int	chown(const char *p, uid_t o, gid_t g);
+#if !defined(__MINGW64_VERSION_MAJOR) || __MINGW64_VERSION_MAJOR < 4
 extern  int	mkstemp(const char *path);
+#endif
 
 #undef	 Stat
 #define  Stat		win32_stat
PATCH
        return;
    }

    if(_ge($version, "5.8.8")) {
    _patch(<<'PATCH');
--- win32/win32.c
+++ win32/win32.c
@@ -985,6 +985,7 @@ chown(const char *path, uid_t owner, gid_t group)
  * XXX this needs strengthening  (for PerlIO)
  *   -- BKS, 11-11-200
 */
+#if !defined(__MINGW64_VERSION_MAJOR) || __MINGW64_VERSION_MAJOR < 4
 int mkstemp(const char *path)
 {
     dTHX;
@@ -1005,6 +1006,7 @@ retry:
 	goto retry;
     return fd;
 }
+#endif
 
 static long
 find_pid(int pid)
--- win32/win32.h
+++ win32/win32.h
@@ -264,7 +264,9 @@ extern  void	*sbrk(ptrdiff_t need);
 #endif
 extern	char *	getlogin(void);
 extern	int	chown(const char *p, uid_t o, gid_t g);
+#if !defined(__MINGW64_VERSION_MAJOR) || __MINGW64_VERSION_MAJOR < 4
 extern  int	mkstemp(const char *path);
+#endif
 
 #undef	 Stat
 #define  Stat		win32_stat
PATCH
        return;
    }

    if(_ge($version, "5.7.3")) {
        _patch(<<'PATCH');
--- win32/win32.c
+++ win32/win32.c
@@ -1094,6 +1094,7 @@ chown(const char *path, uid_t owner, gid_t group)
  * XXX this needs strengthening  (for PerlIO)
  *   -- BKS, 11-11-200
 */
+#if !defined(__MINGW64_VERSION_MAJOR) || __MINGW64_VERSION_MAJOR < 4
 int mkstemp(const char *path)
 {
     dTHX;
@@ -1114,6 +1115,7 @@ retry:
 	goto retry;
     return fd;
 }
+#endif
 
 static long
 find_pid(int pid)
--- win32/win32.h
+++ win32/win32.h
@@ -292,7 +292,9 @@ extern  void	*sbrk(ptrdiff_t need);
 #endif
 extern	char *	getlogin(void);
 extern	int	chown(const char *p, uid_t o, gid_t g);
+#if !defined(__MINGW64_VERSION_MAJOR) || __MINGW64_VERSION_MAJOR < 4
 extern  int	mkstemp(const char *path);
+#endif
 
 #undef	 Stat
 #define  Stat		win32_stat
PATCH
        return;
    }

    if(_ge($version, "5.7.1")) {
        _patch(<<'PATCH');
--- win32/win32.c
+++ win32/win32.c
@@ -979,6 +979,7 @@ chown(const char *path, uid_t owner, gid_t group)
  * XXX this needs strengthening  (for PerlIO)
  *   -- BKS, 11-11-200
 */
+#if !defined(__MINGW64_VERSION_MAJOR) || __MINGW64_VERSION_MAJOR < 4
 int mkstemp(const char *path)
 {
     dTHX;
@@ -999,6 +1000,7 @@ retry:
 	goto retry;
     return fd;
 }
+#endif
 
 static long
 find_pid(int pid)
@@ -1649,14 +1651,17 @@ win32_uname(struct utsname *name)
     /* machine (architecture) */
     {
 	SYSTEM_INFO info;
+	DWORD procarch;
 	char *arch;
 	GetSystemInfo(&info);
 
-#if (defined(__BORLANDC__)&&(__BORLANDC__<=0x520)) || defined(__MINGW32__)
-	switch (info.u.s.wProcessorArchitecture) {
+#if (defined(__BORLANDC__)&&(__BORLANDC__<=0x520)) \
+ || (defined(__MINGW32__) && !defined(_ANONYMOUS_UNION))
+	procarch = info.u.s.wProcessorArchitecture;
 #else
-	switch (info.wProcessorArchitecture) {
+	procarch = info.wProcessorArchitecture;
 #endif
+	switch (procarch) {
 	case PROCESSOR_ARCHITECTURE_INTEL:
 	    arch = "x86"; break;
 	case PROCESSOR_ARCHITECTURE_MIPS:
--- win32/win32.h
+++ win32/win32.h
@@ -298,7 +298,9 @@ extern  int	kill(int pid, int sig);
 extern  void	*sbrk(int need);
 extern	char *	getlogin(void);
 extern	int	chown(const char *p, uid_t o, gid_t g);
+#if !defined(__MINGW64_VERSION_MAJOR) || __MINGW64_VERSION_MAJOR < 4
 extern  int	mkstemp(const char *path);
+#endif
 
 #undef	 Stat
 #define  Stat		win32_stat
PATCH
        return;
    }

    _patch(<<'PATCH');
--- win32/win32.c
+++ win32/win32.c
@@ -1630,14 +1630,17 @@ win32_uname(struct utsname *name)
     /* machine (architecture) */
     {
 	SYSTEM_INFO info;
+	DWORD procarch;
 	char *arch;
 	GetSystemInfo(&info);
 
-#if defined(__BORLANDC__) || defined(__MINGW32__)
-	switch (info.u.s.wProcessorArchitecture) {
+#if (defined(__BORLANDC__)&&(__BORLANDC__<=0x520)) \
+ || (defined(__MINGW32__) && !defined(_ANONYMOUS_UNION))
+	procarch = info.u.s.wProcessorArchitecture;
 #else
-	switch (info.wProcessorArchitecture) {
+	procarch = info.wProcessorArchitecture;
 #endif
+	switch (procarch) {
 	case PROCESSOR_ARCHITECTURE_INTEL:
 	    arch = "x86"; break;
 	case PROCESSOR_ARCHITECTURE_MIPS:
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

sub _patch_errno {
    my $version = shift;

    if (_ge($version, "5.9.2")) {
        # Silence noise from Errno_pm.PL on Windows
        # from https://github.com/Perl/perl5/commit/7bf140906596458f94aa2d5969d3067c0d6441a4
        # and https://github.com/Perl/perl5/commit/f974e9b91d22c1ef2d849ded64674df4f1b18bad
        _patch(<<'PATCH');
--- ext/Errno/Errno_pm.PL
+++ ext/Errno/Errno_pm.PL
@@ -245,7 +245,7 @@ sub write_errno_pm {
 	    my($name,$expr);
 	    next unless ($name, $expr) = /"(.*?)"\s*\[\s*\[\s*(.*?)\s*\]\s*\]/;
 	    next if $name eq $expr;
-	    $expr =~ s/\(?\([a-z_]\w*\)([^\)]*)\)?/$1/i; # ((type)0xcafebabe) at alia
-	    $expr =~ s/((?:0x)?[0-9a-fA-F]+)[LU]+\b/$1/g; # 2147483647L et alia
+	    $expr =~ s/\(?\(\s*[a-z_]\w*\s*\)([^\)]*)\)?/$1/i; # ((type)0xcafebabe) at alia
+	    $expr =~ s/((?:0x)?[0-9a-fA-F]+)[luLU]+\b/$1/g; # 2147483647L et alia
 	    next if $expr =~ m/^[a-zA-Z]+$/; # skip some Win32 functions
 	    if($expr =~ m/^0[xX]/) {
PATCH
    } else {
        _patch(<<'PATCH');
--- ext/Errno/Errno_pm.PL
+++ ext/Errno/Errno_pm.PL
@@ -229,8 +229,8 @@ sub write_errno_pm {
 	    my($name,$expr);
 	    next unless ($name, $expr) = /"(.*?)"\s*\[\s*\[\s*(.*?)\s*\]\s*\]/;
 	    next if $name eq $expr;
-	    $expr =~ s/\(?\(\w+\)([^\)]*)\)?/$1/; # ((type)0xcafebabe) at alia
-	    $expr =~ s/((?:0x)?[0-9a-fA-F]+)[LU]+\b/$1/g; # 2147483647L et alia
+	    $expr =~ s/\(?\(\s*[a-z_]\w*\s*\)([^\)]*)\)?/$1/i; # ((type)0xcafebabe) at alia
+	    $expr =~ s/((?:0x)?[0-9a-fA-F]+)[luLU]+\b/$1/g; # 2147483647L et alia
 	    next if $expr =~ m/^[a-zA-Z]+$/; # skip some Win32 functions
 	    if($expr =~ m/^0[xX]/) {
 		$err{$name} = hex $expr;
PATCH
    }

    if (_ge($version, "5.13.5")) {
        return;
    }

    if (_ge($version, "5.13.1")) {
        # Sanity check on Errno values.
        # https://github.com/Perl/perl5/commit/be54382c6ee2d28448a2bfa85dedcbb6144583ae
        _patch(<<'PATCH');
--- ext/Errno/Errno_pm.PL
+++ ext/Errno/Errno_pm.PL
@@ -357,8 +357,9 @@ my %err;
 BEGIN {
     %err = (
 EDQ
-   
-    my @err = sort { $err{$a} <=> $err{$b} } keys %err;
+
+    my @err = sort { $err{$a} <=> $err{$b} }
+	grep { $err{$_} =~ /-?\d+$/ } keys %err;
 
     foreach $err (@err) {
 	print "\t$err => $err{$err},\n";
PATCH
    }
}

sub _patch_socket_h {
    _patch(<<'PATCH')
--- win32/include/sys/socket.h
+++ win32/include/sys/socket.h
@@ -29,6 +29,7 @@ extern "C" {
 
 #include "win32.h"
 
+#undef ENOTSOCK
 #define  ENOTSOCK	WSAENOTSOCK
 
 #ifdef USE_SOCKETS_AS_HANDLES
PATCH
}

sub _patch_perlhost {
    my $version = shift;

    _patch(<<'PATCH');
--- win32/perlhost.h
+++ win32/perlhost.h
@@ -1745,7 +1747,7 @@ win32_start_child(LPVOID arg)
     parent_message_hwnd = w32_message_hwnd;
     w32_message_hwnd = win32_create_message_window();
     if (parent_message_hwnd != NULL)
-        PostMessage(parent_message_hwnd, WM_USER_MESSAGE, w32_pseudo_id, (LONG)w32_message_hwnd);
+        PostMessage(parent_message_hwnd, WM_USER_MESSAGE, w32_pseudo_id, (LPARAM)w32_message_hwnd);
 
     /* push a zero on the stack (we are the child) */
     {
PATCH
}

sub _patch_threads {
    my $version = shift;

    if (_ge($version, "5.11.0")) {
        _patch(<<'PATCH');
--- dist/threads/threads.xs
+++ dist/threads/threads.xs
@@ -1,13 +1,22 @@
 #define PERL_NO_GET_CONTEXT
+/* Workaround for mingw 32-bit compiler by mingw-w64.sf.net - has to come before any #include.
+ * It also defines USE_NO_MINGW_SETJMP_TWO_ARGS for the mingw.org 32-bit compilers ... but
+ * that's ok as that compiler makes no use of that symbol anyway */
+#if defined(WIN32) && defined(__MINGW32__) && !defined(__MINGW64__)
+#  define USE_NO_MINGW_SETJMP_TWO_ARGS 1
+#endif
 #include "EXTERN.h"
 #include "perl.h"
 #include "XSUB.h"
 /* Workaround for XSUB.h bug under WIN32 */
 #ifdef WIN32
 #  undef setjmp
-#  if !defined(__BORLANDC__)
+#  if defined(USE_NO_MINGW_SETJMP_TWO_ARGS) || (!defined(__BORLANDC__) && !defined(__MINGW64__))
 #    define setjmp(x) _setjmp(x)
 #  endif
+#  if defined(__MINGW64__)
+#    define setjmp(x) _setjmpex((x), mingw_getsp())
+#  endif
 #endif
 #ifdef HAS_PPPORT_H
 #  define NEED_PL_signals
PATCH
        return;
    }

    _patch(<<'PATCH');
--- ext/threads/threads.xs
+++ ext/threads/threads.xs
@@ -1,13 +1,22 @@
 #define PERL_NO_GET_CONTEXT
+/* Workaround for mingw 32-bit compiler by mingw-w64.sf.net - has to come before any #include.
+ * It also defines USE_NO_MINGW_SETJMP_TWO_ARGS for the mingw.org 32-bit compilers ... but
+ * that's ok as that compiler makes no use of that symbol anyway */
+#if defined(WIN32) && defined(__MINGW32__) && !defined(__MINGW64__)
+#  define USE_NO_MINGW_SETJMP_TWO_ARGS 1
+#endif
 #include "EXTERN.h"
 #include "perl.h"
 #include "XSUB.h"
 /* Workaround for XSUB.h bug under WIN32 */
 #ifdef WIN32
 #  undef setjmp
-#  if !defined(__BORLANDC__)
+#  if defined(USE_NO_MINGW_SETJMP_TWO_ARGS) || (!defined(__BORLANDC__) && !defined(__MINGW64__))
 #    define setjmp(x) _setjmp(x)
 #  endif
+#  if defined(__MINGW64__)
+#    define setjmp(x) _setjmpex((x), mingw_getsp())
+#  endif
 #endif
 #ifdef HAS_PPPORT_H
 #  define NEED_PL_signals
PATCH
}

sub _patch_config_h_gc {
    my $version = shift;

    if (_ge($version, "5.20.3")) {
        return;
    }

    if (_ge($version, "5.18.0")) {
        _patch(<<'PATCH');
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
        return;
    }

    if (_ge($version, "5.12.0")) {
	    _patch(<<'PATCH');
--- win32/config_H.gc
+++ win32/config_H.gc
@@ -2643,7 +2643,9 @@
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
        return;
    }

    if (_ge($version, "5.11.4")) {
        _patch(<<'PATCH');
--- win32/config_H.gc
+++ win32/config_H.gc
@@ -3746,14 +3746,18 @@
  *	This symbol, if defined, indicates that the mkdtemp routine is
  *	available to exclusively create a uniquely named temporary directory.
  */
-/*#define HAS_MKDTEMP		/ **/
+#if __MINGW64_VERSION_MAJOR >= 4
+#define HAS_MKDTEMP
+#endif
 
 /* HAS_MKSTEMPS:
  *	This symbol, if defined, indicates that the mkstemps routine is
  *	available to excluslvely create and open a uniquely named
  *	(with a suffix) temporary file.
  */
-/*#define HAS_MKSTEMPS		/ **/
+#if __MINGW64_VERSION_MAJOR >= 4
+#define HAS_MKSTEMPS
+#endif
 
 /* HAS_MODFL:
  *	This symbol, if defined, indicates that the modfl routine is

PATCH
        return;
    }

    if (_ge($version, "5.10.1")) {
        _patch(<<'PATCH');
--- win32/config_H.gc
+++ win32/config_H.gc
@@ -3692,14 +3692,18 @@
  *	This symbol, if defined, indicates that the mkdtemp routine is
  *	available to exclusively create a uniquely named temporary directory.
  */
-/*#define HAS_MKDTEMP		/**/
+#if __MINGW64_VERSION_MAJOR >= 4
+#define HAS_MKDTEMP
+#endif
 
 /* HAS_MKSTEMPS:
  *	This symbol, if defined, indicates that the mkstemps routine is
  *	available to excluslvely create and open a uniquely named
  *	(with a suffix) temporary file.
  */
-/*#define HAS_MKSTEMPS		/**/
+#if __MINGW64_VERSION_MAJOR >= 4
+#define HAS_MKSTEMPS
+#endif
 
 /* HAS_MODFL:
  *	This symbol, if defined, indicates that the modfl routine is
PATCH
        return;
    }

    if (_ge($version, "5.10.0")) {
        _patch(<<'PATCH');
--- win32/config_H.gc
+++ win32/config_H.gc
@@ -2356,14 +2356,18 @@
  *	This symbol, if defined, indicates that the mkdtemp routine is
  *	available to exclusively create a uniquely named temporary directory.
  */
-/*#define HAS_MKDTEMP		/**/
+#if __MINGW64_VERSION_MAJOR >= 4
+#define HAS_MKSTEMP
+#endif
 
 /* HAS_MKSTEMP:
  *	This symbol, if defined, indicates that the mkstemp routine is
  *	available to exclusively create and open a uniquely named
  *	temporary file.
  */
-/*#define HAS_MKSTEMP		/**/
+#if __MINGW64_VERSION_MAJOR >= 4
+#define HAS_MKSTEMPS
+#endif
 
 /* HAS_MKSTEMPS:
  *	This symbol, if defined, indicates that the mkstemps routine is
@@ -3849,7 +3853,7 @@
  *	Quad_t, and its unsigned counterpar, Uquad_t. QUADKIND will be one
  *	of QUAD_IS_INT, QUAD_IS_LONG, QUAD_IS_LONG_LONG, or QUAD_IS_INT64_T.
  */
-/*#define HAS_QUAD	/**/
+#define HAS_QUAD
 #ifdef HAS_QUAD
 #   ifndef _MSC_VER
 #	define Quad_t long long	/**/
PATCH
        return;
    }

    _patch(<<'PATCH');
PATCH

    if (_ge($version, "5.9.4")) {
        _patch(<<'PATCH');
--- win32/config_H.gc
+++ win32/config_H.gc
@@ -3849,21 +3849,15 @@
  *	Quad_t, and its unsigned counterpar, Uquad_t. QUADKIND will be one
  *	of QUAD_IS_INT, QUAD_IS_LONG, QUAD_IS_LONG_LONG, or QUAD_IS_INT64_T.
  */
-/*#define HAS_QUAD	/**/
-#ifdef HAS_QUAD
-#   ifndef _MSC_VER
-#	define Quad_t long long	/**/
-#	define Uquad_t unsigned long long	/**/
-#   else
-#	define Quad_t __int64	/**/
-#	define Uquad_t unsigned __int64	/**/
-#   endif
-#   define QUADKIND 5	/**/
+#define HAS_QUAD
+#   define Quad_t long long	/**/
+#   define Uquad_t unsigned long long	/**/
+#   define QUADKIND 3	/**/
 #   define QUAD_IS_INT	1
 #   define QUAD_IS_LONG	2
 #   define QUAD_IS_LONG_LONG	3
 #   define QUAD_IS_INT64_T	4
-#endif
+#   define QUAD_IS___INT64	5
 
 /* IVTYPE:
  *	This symbol defines the C type used for Perl's IV.
PATCH
        return;
    }

    if (_ge($version, "5.9.0")) {
        _patch(<<'PATCH');
--- win32/config_H.gc
+++ win32/config_H.gc
@@ -3161,16 +3161,14 @@
  *	Quad_t, and its unsigned counterpar, Uquad_t. QUADKIND will be one
  *	of QUAD_IS_INT, QUAD_IS_LONG, QUAD_IS_LONG_LONG, or QUAD_IS_INT64_T.
  */
-/*#define HAS_QUAD	/**/
-#ifdef HAS_QUAD
+#define HAS_QUAD
 #   define Quad_t long long	/**/
 #   define Uquad_t unsigned long long	/**/
-#   define QUADKIND 5	/**/
+#   define QUADKIND 3	/**/
 #   define QUAD_IS_INT	1
 #   define QUAD_IS_LONG	2
 #   define QUAD_IS_LONG_LONG	3
 #   define QUAD_IS_INT64_T	4
-#endif
 
 /* IVTYPE:
  *	This symbol defines the C type used for Perl's IV.
PATCH
        return;
    }

    if (_ge($version, "5.8.9")) {
        _patch(<<'PATCH');
--- win32/config_H.gc
+++ win32/config_H.gc
@@ -3849,21 +3849,15 @@
  *	Quad_t, and its unsigned counterpar, Uquad_t. QUADKIND will be one
  *	of QUAD_IS_INT, QUAD_IS_LONG, QUAD_IS_LONG_LONG, or QUAD_IS_INT64_T.
  */
-/*#define HAS_QUAD	/**/
-#ifdef HAS_QUAD
-#   ifndef _MSC_VER
-#	define Quad_t long long	/**/
-#	define Uquad_t unsigned long long	/**/
-#   else
-#	define Quad_t __int64	/**/
-#	define Uquad_t unsigned __int64	/**/
-#   endif
-#   define QUADKIND 5	/**/
+#define HAS_QUAD
+#   define Quad_t long long	/**/
+#   define Uquad_t unsigned long long	/**/
+#   define QUADKIND 3	/**/
 #   define QUAD_IS_INT	1
 #   define QUAD_IS_LONG	2
 #   define QUAD_IS_LONG_LONG	3
 #   define QUAD_IS_INT64_T	4
-#endif
+#   define QUAD_IS___INT64	5
 
 /* IVTYPE:
  *	This symbol defines the C type used for Perl's IV.
PATCH
        return;
    }

    if (_ge($version, "5.8.8")) {
        _patch(<<'PATCH');
--- win32/config_H.gc
+++ win32/config_H.gc
@@ -3150,16 +3150,15 @@
  *	Quad_t, and its unsigned counterpar, Uquad_t. QUADKIND will be one
  *	of QUAD_IS_INT, QUAD_IS_LONG, QUAD_IS_LONG_LONG, or QUAD_IS_INT64_T.
  */
-/*#define HAS_QUAD	/**/
-#ifdef HAS_QUAD
+#define HAS_QUAD
 #   define Quad_t long long	/**/
 #   define Uquad_t unsigned long long	/**/
-#   define QUADKIND 5	/**/
+#   define QUADKIND 3	/**/
 #   define QUAD_IS_INT	1
 #   define QUAD_IS_LONG	2
 #   define QUAD_IS_LONG_LONG	3
 #   define QUAD_IS_INT64_T	4
-#endif
+#   define QUAD_IS___INT64	5
 
 /* IVTYPE:
  *	This symbol defines the C type used for Perl's IV.
PATCH
        return;
    }

    if (_ge($version, "5.7.0")) {
        _patch(<<'PATCH');
--- win32/config_H.gc
+++ win32/config_H.gc
@@ -911,16 +911,15 @@
  *	Quad_t, and its unsigned counterpar, Uquad_t. QUADKIND will be one
  *	of QUAD_IS_INT, QUAD_IS_LONG, QUAD_IS_LONG_LONG, or QUAD_IS_INT64_T.
  */
-/*#define HAS_QUAD	/**/
-#ifdef HAS_QUAD
+#define HAS_QUAD
 #   define Quad_t long long	/**/
 #   define Uquad_t unsigned long long	/**/
-#   define QUADKIND 5	/**/
+#   define QUADKIND 3	/**/
 #   define QUAD_IS_INT	1
 #   define QUAD_IS_LONG	2
 #   define QUAD_IS_LONG_LONG	3
 #   define QUAD_IS_INT64_T	4
-#endif
+#   define QUAD_IS___INT64	5
 
 /* HAS_ACCESSX:
  *	This symbol, if defined, indicates that the accessx routine is
@@ -1825,7 +1824,9 @@
  *	available to exclusively create and open a uniquely named
  *	temporary file.
  */
-/*#define HAS_MKSTEMP		/**/
+#if __MINGW64_VERSION_MAJOR >= 4
+#define HAS_MKSTEMP
+#endif
 
 /* HAS_MMAP:
  *	This symbol, if defined, indicates that the mmap system call is
@@ -2614,7 +2615,9 @@
  *	available to excluslvely create and open a uniquely named
  *	(with a suffix) temporary file.
  */
-/*#define HAS_MKSTEMPS		/**/
+#if __MINGW64_VERSION_MAJOR >= 4
+#define HAS_MKSTEMPS
+#endif
 
 /* HAS_MODFL:
  *	This symbol, if defined, indicates that the modfl routine is
PATCH
        return;
    }
}

sub _patch_config_gc {
    my $version = shift;
    if (_ge($version, "5.10.0")) {
        return;
    }

    if (_ge($version, "5.8.0")) {
        _patch(<<'PATCH');
--- win32/config.gc
+++ win32/config.gc
@@ -345,7 +345,7 @@ d_pwgecos='undef'
 d_pwpasswd='undef'
 d_pwquota='undef'
 d_qgcvt='undef'
-d_quad='undef'
+d_quad='define'
 d_random_r='undef'
 d_readdir64_r='undef'
 d_readdir='define'
PATCH
        return;
    }

    if (_ge($version, "5.7.1")) {
        _patch(<<'PATCH');
--- win32/config.gc
+++ win32/config.gc
@@ -280,7 +280,7 @@ d_pwgecos='undef'
 d_pwpasswd='undef'
 d_pwquota='undef'
 d_qgcvt='undef'
-d_quad='undef'
+d_quad='define'
 d_readdir='define'
 d_readlink='undef'
 d_readv='undef'
PATCH
        return;
    }

    if (_ge($version, "5.7.0")) {
        _patch(<<'PATCH');
--- win32/config.gc
+++ win32/config.gc
@@ -258,7 +258,7 @@ d_pwgecos='undef'
 d_pwpasswd='undef'
 d_pwquota='undef'
 d_qgcvt='undef'
-d_quad='undef'
+d_quad='define'
 d_readdir='define'
 d_readlink='undef'
 d_rename='define'
PATCH
        return;
    }
}

sub _patch_config_sh_pl {
    my $version = shift;
    if (_ge($version, "5.10.0")) {
        return;
    }

    _patch(<<'PATCH');
--- win32/config_sh.PL
+++ win32/config_sh.PL
@@ -133,6 +133,34 @@ if ($opt{useithreads} eq 'define' && $opt{ccflags} =~ /-DPERL_IMPLICIT_SYS\b/) {
     $opt{d_pseudofork} = 'define';
 }
 
+# 64-bit patch is hard coded from here
+my $int64  = 'long long';
+$opt{d_atoll} = 'define';
+$opt{d_strtoll} = 'define';
+$opt{d_strtoull} = 'define';
+$opt{ptrsize} = 8;
+$opt{sizesize} = 8;
+$opt{ssizetype} = $int64;
+$opt{st_ino_size} = 8;
+$opt{d_nv_preserves_uv} = 'undef';
+$opt{nv_preserves_uv_bits} = 53;
+$opt{ivdformat} = qq{"I64d"};
+$opt{ivsize} = 8;
+$opt{ivtype} = $int64;
+$opt{sPRIXU64} = qq{"I64X"};
+$opt{sPRId64} = qq{"I64d"};
+$opt{sPRIi64} = qq{"I64i"};
+$opt{sPRIo64} = qq{"I64o"};
+$opt{sPRIu64} = qq{"I64u"};
+$opt{sPRIx64} = qq{"I64x"};
+$opt{uvXUformat} = qq{"I64X"};
+$opt{uvoformat} = qq{"I64o"};
+$opt{uvsize} = 8;
+$opt{uvtype} = qq{unsigned $int64};
+$opt{uvuformat} = qq{"I64u"};
+$opt{uvxformat} = qq{"I64x"};
+# end of 64-bit patch
+
 while (<>) {
     s/~([\w_]+)~/$opt{$1}/g;
     if (/^([\w_]+)=(.*)$/) {
PATCH
}

sub _patch_installperl {
    my $version = shift;
    if (_ge($version, "5.24.0")) {
        return;
    }

    if (_ge($version, "5.20.2")) {
        _patch(<<'PATCH');
--- installperl
+++ installperl
@@ -365,6 +365,8 @@ elsif ($Is_Cygwin) { # On Cygwin symlink it to CORE to make Makefile happy
     ( copy("$installbin/$libperl", $coredll) &&
       push(@corefiles, $instcoredll)
     )
+} elsif ($Is_W32) {
+    @corefiles = <*.h>;
 } else {
     # [als] hard-coded 'libperl' name... not good!
     @corefiles = <*.h libperl*.* perl*$Config{lib_ext}>;
@@ -385,6 +387,13 @@ foreach my $file (@corefiles) {
     }
 }
 
+if ($Is_W32) { #linking lib isn't made in root but in CORE on Win32
+    @corefiles = <lib/CORE/libperl*.* lib/CORE/perl*$Config{lib_ext}>;
+    my $dest;
+    copy_if_diff($_,($dest = $installarchlib.substr($_,3))) &&
+    chmod(0444, $dest) foreach @corefiles;
+}
+
 # Install main perl executables
 # Make links to ordinary names if installbin directory isn't current directory.
 
@@ -659,8 +668,8 @@ sub installlib {
     return if $name =~ /^(?:cpan|instmodsh|prove|corelist|ptar|ptardiff|ptargrep|zipdetails)\z/;
     # ignore the Makefiles
     return if $name =~ /^makefile$/i;
-    # ignore the test extensions
-    return if $dir =~ m{\bXS/(?:APItest|Typemap)\b};
+    # ignore the test extensions, dont install PPPort.so/.dll
+    return if $dir =~ m{\b(?:XS/(?:APItest|Typemap)|Devel/PPPort)\b};
     return if $name =~ m{\b(?:APItest|Typemap)\.pm$};
     # ignore the build support code
     return if $name =~ /\bbuildcustomize\.pl$/;
@@ -703,6 +712,9 @@ sub installlib {
 
     return if $name eq 'ExtUtils/XSSymSet.pm' and !$Is_VMS;
 
+    #blead comes with version, blead isn't 5.8/5.6
+    return if $name eq 'ExtUtils/MakeMaker/version/regex.pm';
+
     my $installlib = $installprivlib;
     if ($dir =~ /^auto\// ||
 	  ($name =~ /^(.*)\.(?:pm|pod)$/ && $archpms{$1}) ||
PATCH
        return;
    }

    if (_ge($version, "5.10.1")) {
        _patch(<<'PATCH');
--- installperl
+++ installperl
@@ -260,7 +260,7 @@ if (($Is_W32 and ! $Is_NetWare) or $Is_Cygwin) {
     if ($Is_Cygwin) {
 	$perldll = $libperl;
     } else {
-	$perldll = 'perl5'.$Config{patchlevel}.'.'.$dlext;
+	$perldll = 'perl5'.$Config{patchlevel}.'.'.$so;
     }
 
     if ($dlsrc ne "dl_none.xs") {
@@ -370,6 +370,8 @@ elsif ($Is_Cygwin) { # On Cygwin symlink it to CORE to make Makefile happy
     ( copy("$installbin/$libperl", $coredll) &&
       push(@corefiles, $instcoredll)
     )
+} elsif ($Is_W32) {
+    @corefiles = <*.h>;
 } else {
     # [als] hard-coded 'libperl' name... not good!
     @corefiles = <*.h libperl*.* perl*$Config{lib_ext}>;
@@ -390,6 +392,13 @@ foreach my $file (@corefiles) {
     }
 }
 
+if ($Is_W32) { #linking lib isn't made in root but in CORE on Win32
+    @corefiles = <lib/CORE/libperl*.* lib/CORE/perl*$Config{lib_ext}>;
+    my $dest;
+    copy_if_diff($_,($dest = $installarchlib.substr($_,3))) &&
+    chmod(0444, $dest) foreach @corefiles;
+}
+
 # Install main perl executables
 # Make links to ordinary names if installbin directory isn't current directory.
 
@@ -677,8 +686,8 @@ sub installlib {
     return if $name =~ /^(?:cpan|instmodsh|prove|corelist|ptar|ptardiff|ptargrep|config_data|zipdetails)\z/;
     # ignore the Makefiles
     return if $name =~ /^makefile$/i;
-    # ignore the test extensions
-    return if $dir =~ m{\bXS/(?:APItest|Typemap)\b};
+    # ignore the test extensions, dont install PPPort.so/.dll
+    return if $dir =~ m{\b(?:XS/(?:APItest|Typemap)|Devel/PPPort)\b};
     return if $name =~ m{\b(?:APItest|Typemap)\.pm$};
     # ignore the build support code
     return if $name =~ /\bbuildcustomize\.pl$/;
@@ -721,6 +730,9 @@ sub installlib {
 
     return if $name eq 'ExtUtils/XSSymSet.pm' and !$Is_VMS;
 
+    #blead comes with version, blead isn't 5.8/5.6
+    return if $name eq 'ExtUtils/MakeMaker/version/regex.pm';
+
     my $installlib = $installprivlib;
     if ($dir =~ /^auto\// ||
 	  ($name =~ /^(.*)\.(?:pm|pod)$/ && $archpms{$1}) ||
PATCH
        return;
    }

    if ($version eq "5.9.4") {
        _patch(<<'PATCH');
--- installperl
+++ installperl
@@ -426,6 +426,9 @@ if ($Is_VMS) {  # We did core file selection during build
     $coredir =~ tr/./_/;
     map { s|^$coredir/||i; } @corefiles = <$coredir/*.*>;
 }
+elsif ($Is_W32) {
+    @corefiles = <*.h>;
+}
 else {
     # [als] hard-coded 'libperl' name... not good!
     @corefiles = <*.h libperl*.* perl*$Config{lib_ext}>;
@@ -453,6 +456,13 @@ foreach my $file (@corefiles) {
     }
 }
 
+if ($Is_W32) { #linking lib isn't made in root but in CORE on Win32
+    @corefiles = <lib/CORE/libperl*.* lib/CORE/perl*$Config{lib_ext}>;
+    my $dest;
+    copy_if_diff($_,($dest = $installarchlib.substr($_,3))) &&
+    chmod(0444, $dest) foreach @corefiles;
+}
+
 # Install main perl executables
 # Make links to ordinary names if installbin directory isn't current directory.
 
@@ -833,8 +843,8 @@ sub installlib {
     return if $name =~ /^(?:cpan|instmodsh|prove|corelist|ptar|ptardiff|config_data)\z/;
     # ignore the Makefiles
     return if $name =~ /^makefile$/i;
-    # ignore the test extensions
-    return if $dir =~ m{ext/XS/(?:APItest|Typemap)/};
+    # ignore the test extensions, dont install PPPort.so/.dll
+    return if $dir =~ m{\b(?:XS/(?:APItest|Typemap)|Devel/PPPort)\b};
     # ignore the demo files
     return if $dir =~ /\bdemos?\b/;
 
@@ -846,6 +856,9 @@ sub installlib {
 
     $name = "$dir/$name" if $dir ne '';
 
+    #blead comes with version, blead isn't 5.8/5.6
+    return if $name eq 'ExtUtils/MakeMaker/version/regex.pm';
+
     my $installlib = $installprivlib;
     if ($dir =~ /^auto/ ||
 	  ($name =~ /^(.*)\.(?:pm|pod)$/ && $archpms{$1}) ||
PATCH
        return;
    }

    if ($version eq "5.9.3") {
        _patch(<<'PATCH');
--- installperl
+++ installperl
@@ -404,6 +404,9 @@ if ($Is_VMS) {  # We did core file selection during build
     $coredir =~ tr/./_/;
     map { s|^$coredir/||i; } @corefiles = <$coredir/*.*>;
 }
+elsif ($Is_W32) {
+    @corefiles = <*.h>;
+}
 else {
     # [als] hard-coded 'libperl' name... not good!
     @corefiles = <*.h libperl*.* perl*$Config{lib_ext}>;
@@ -431,6 +434,13 @@ foreach my $file (@corefiles) {
     }
 }
 
+if ($Is_W32) { #linking lib isn't made in root but in CORE on Win32
+    @corefiles = <lib/CORE/libperl*.* lib/CORE/perl*$Config{lib_ext}>;
+    my $dest;
+    copy_if_diff($_,($dest = $installarchlib.substr($_,3))) &&
+    chmod(0444, $dest) foreach @corefiles;
+}
+
 # Install main perl executables
 # Make links to ordinary names if installbin directory isn't current directory.
 
@@ -811,8 +821,8 @@ sub installlib {
     return if $name =~ /^(?:cpan|instmodsh|prove|corelist|ptar|ptardiff)\z/;
     # ignore the Makefiles
     return if $name =~ /^makefile$/i;
-    # ignore the test extensions
-    return if $dir =~ m{ext/XS/(?:APItest|Typemap)/};
+    # ignore the test extensions, dont install PPPort.so/.dll
+    return if $dir =~ m{\b(?:XS/(?:APItest|Typemap)|Devel/PPPort)\b};
     # ignore the demo files
     return if $dir =~ /\bdemos?\b/;
 
@@ -824,6 +834,9 @@ sub installlib {
 
     $name = "$dir/$name" if $dir ne '';
 
+    #blead comes with version, blead isn't 5.8/5.6
+    return if $name eq 'ExtUtils/MakeMaker/version/regex.pm';
+
     my $installlib = $installprivlib;
     if ($dir =~ /^auto/ ||
 	  ($name =~ /^(.*)\.(?:pm|pod)$/ && $archpms{$1}) ||
PATCH
        return;
    }

    if ($version eq "5.9.2") {
        _patch(<<'PATCH');
--- installperl
+++ installperl
@@ -404,6 +404,9 @@ if ($Is_VMS) {  # We did core file selection during build
     $coredir =~ tr/./_/;
     map { s|^$coredir/||i; } @corefiles = <$coredir/*.*>;
 }
+elsif ($Is_W32) {
+    @corefiles = <*.h>;
+}
 else {
     # [als] hard-coded 'libperl' name... not good!
     @corefiles = <*.h libperl*.* perl*$Config{lib_ext}>;
@@ -431,6 +434,13 @@ foreach my $file (@corefiles) {
     }
 }
 
+if ($Is_W32) { #linking lib isn't made in root but in CORE on Win32
+    @corefiles = <lib/CORE/libperl*.* lib/CORE/perl*$Config{lib_ext}>;
+    my $dest;
+    copy_if_diff($_,($dest = $installarchlib.substr($_,3))) &&
+    chmod(0444, $dest) foreach @corefiles;
+}
+
 # Install main perl executables
 # Make links to ordinary names if installbin directory isn't current directory.
 
@@ -810,11 +820,14 @@ sub installlib {
     return if $name =~ /^(?:cpan|instmodsh|prove|corelist)\z/;
     # ignore the Makefiles
     return if $name =~ /^makefile$/i;
-    # ignore the test extensions
-    return if $dir =~ m{ext/XS/(?:APItest|Typemap)/};
+    # ignore the test extensions, dont install PPPort.so/.dll
+    return if $dir =~ m{\b(?:XS/(?:APItest|Typemap)|Devel/PPPort)\b};
 
     $name = "$dir/$name" if $dir ne '';
 
+    #blead comes with version, blead isn't 5.8/5.6
+    return if $name eq 'ExtUtils/MakeMaker/version/regex.pm';
+
     my $installlib = $installprivlib;
     if ($dir =~ /^auto/ ||
 	  ($name =~ /^(.*)\.(?:pm|pod)$/ && $archpms{$1}) ||
PATCH
        return;
    }

    if ($version eq "5.9.1") {
        _patch(<<'PATCH');
--- installperl
+++ installperl
@@ -402,6 +402,9 @@ if ($Is_VMS) {  # We did core file selection during build
     $coredir =~ tr/./_/;
     map { s|^$coredir/||i; } @corefiles = <$coredir/*.*>;
 }
+elsif ($Is_W32) {
+    @corefiles = <*.h>;
+}
 else {
     # [als] hard-coded 'libperl' name... not good!
     @corefiles = <*.h libperl*.* perl*$Config{lib_ext}>;
@@ -429,6 +432,13 @@ foreach my $file (@corefiles) {
     }
 }
 
+if ($Is_W32) { #linking lib isn't made in root but in CORE on Win32
+    @corefiles = <lib/CORE/libperl*.* lib/CORE/perl*$Config{lib_ext}>;
+    my $dest;
+    copy_if_diff($_,($dest = $installarchlib.substr($_,3))) &&
+    chmod(0444, $dest) foreach @corefiles;
+}
+
 # Install main perl executables
 # Make links to ordinary names if installbin directory isn't current directory.
 
@@ -807,11 +817,14 @@ sub installlib {
     return if $name =~ /^(?:cpan|instmodsh|prove)\z/;
     # ignore the Makefiles
     return if $name =~ /^makefile$/i;
-    # ignore the test extensions
-    return if $dir =~ m{ext/XS/(?:APItest|Typemap)/};
+    # ignore the test extensions, dont install PPPort.so/.dll
+    return if $dir =~ m{\b(?:XS/(?:APItest|Typemap)|Devel/PPPort)\b};
 
     $name = "$dir/$name" if $dir ne '';
 
+    #blead comes with version, blead isn't 5.8/5.6
+    return if $name eq 'ExtUtils/MakeMaker/version/regex.pm';
+
     my $installlib = $installprivlib;
     if ($dir =~ /^auto/ ||
 	  ($name =~ /^(.*)\.(?:pm|pod)$/ && $archpms{$1}) ||
PATCH
        return;
    }

    if ($version eq "5.9.0") {
        _patch(<<'PATCH');
--- installperl
+++ installperl
@@ -401,6 +401,9 @@ if ($Is_VMS) {  # We did core file selection during build
     $coredir =~ tr/./_/;
     map { s|^$coredir/||i; } @corefiles = <$coredir/*.*>;
 }
+elsif ($Is_W32) {
+    @corefiles = <*.h>;
+}
 else {
     # [als] hard-coded 'libperl' name... not good!
     @corefiles = <*.h libperl*.*>;
@@ -428,6 +431,13 @@ foreach my $file (@corefiles) {
     }
 }
 
+if ($Is_W32) { #linking lib isn't made in root but in CORE on Win32
+    @corefiles = <lib/CORE/libperl*.* lib/CORE/perl*$Config{lib_ext}>;
+    my $dest;
+    copy_if_diff($_,($dest = $installarchlib.substr($_,3))) &&
+    chmod(0444, $dest) foreach @corefiles;
+}
+
 # Install main perl executables
 # Make links to ordinary names if installbin directory isn't current directory.
 
@@ -797,11 +807,14 @@ sub installlib {
 	      $dir  =~ m{/t(?:/|$)};
     # ignore the cpan script in lib/CPAN/bin (installed later with other utils)
     return if $name eq 'cpan';
-    # ignore the test extensions
-    return if $dir =~ m{ext/XS/(?:APItest|Typemap)/};
+    # ignore the test extensions, dont install PPPort.so/.dll
+    return if $dir =~ m{\b(?:XS/(?:APItest|Typemap)|Devel/PPPort)\b};
 
     $name = "$dir/$name" if $dir ne '';
 
+    #blead comes with version, blead isn't 5.8/5.6
+    return if $name eq 'ExtUtils/MakeMaker/version/regex.pm';
+
     my $installlib = $installprivlib;
     if ($dir =~ /^auto/ ||
 	  ($name =~ /^(.*)\.(?:pm|pod)$/ && $archpms{$1}) ||
PATCH
        return;
    }

    if (_ge($version, "5.8.9")) {
        _patch(<<'PATCH');
--- installperl
+++ installperl
@@ -395,6 +395,9 @@ if ($Is_VMS) {  # We did core file selection during build
     $coredir =~ tr/./_/;
     map { s|^$coredir/||i; } @corefiles = <$coredir/*.*>;
 }
+elsif ($Is_W32) {
+    @corefiles = <*.h>;
+}
 else {
     # [als] hard-coded 'libperl' name... not good!
     @corefiles = <*.h libperl*.* perl*$Config{lib_ext}>;
@@ -422,6 +425,13 @@ foreach my $file (@corefiles) {
     }
 }
 
+if ($Is_W32) { #linking lib isn't made in root but in CORE on Win32
+    @corefiles = <lib/CORE/libperl*.* lib/CORE/perl*$Config{lib_ext}>;
+    my $dest;
+    copy_if_diff($_,($dest = $installarchlib.substr($_,3))) &&
+    chmod(0444, $dest) foreach @corefiles;
+}
+
 # Install main perl executables
 # Make links to ordinary names if installbin directory isn't current directory.
 
@@ -802,8 +812,8 @@ sub installlib {
     return if $name =~ /^(?:cpan|instmodsh|prove|corelist|ptar|cpan2dist|cpanp|cpanp-run-perl|ptardiff|config_data)\z/;
     # ignore the Makefiles
     return if $name =~ /^makefile$/i;
-    # ignore the test extensions
-    return if $dir =~ m{\bXS/(?:APItest|Typemap)\b};
+    # ignore the test extensions, dont install PPPort.so/.dll
+    return if $dir =~ m{\b(?:XS/(?:APItest|Typemap)|Devel/PPPort)\b};
     return if $name =~ m{\b(?:APItest|Typemap)\.pm$};
     # ignore the demo files
     return if $dir =~ /\b(?:demos?|eg)\b/;
@@ -826,6 +836,9 @@ sub installlib {
 
     $name = "$dir/$name" if $dir ne '';
 
+    #blead comes with version, blead isn't 5.8/5.6
+    return if $name eq 'ExtUtils/MakeMaker/version/regex.pm';
+
     my $installlib = $installprivlib;
     if ($dir =~ /^auto/ ||
 	  ($name =~ /^(.*)\.(?:pm|pod)$/ && $archpms{$1}) ||
PATCH
        return;
    }

    if (_ge($version, "5.8.8")) {
        _patch(<<'PATCH');
--- installperl
+++ installperl
@@ -404,6 +404,9 @@ if ($Is_VMS) {  # We did core file selection during build
     $coredir =~ tr/./_/;
     map { s|^$coredir/||i; } @corefiles = <$coredir/*.*>;
 }
+elsif ($Is_W32) {
+    @corefiles = <*.h>;
+}
 else {
     # [als] hard-coded 'libperl' name... not good!
     @corefiles = <*.h *.inc libperl*.* perl*$Config{lib_ext}>;
@@ -442,6 +445,13 @@ if ($Config{use5005threads}) {
     }
 }
 
+if ($Is_W32) { #linking lib isn't made in root but in CORE on Win32
+    @corefiles = <lib/CORE/libperl*.* lib/CORE/perl*$Config{lib_ext}>;
+    my $dest;
+    copy_if_diff($_,($dest = $installarchlib.substr($_,3))) &&
+    chmod(0444, $dest) foreach @corefiles;
+}
+
 # Install main perl executables
 # Make links to ordinary names if installbin directory isn't current directory.
 
@@ -825,8 +835,8 @@ sub installlib {
 
     # ignore the Makefiles
     return if $name =~ /^makefile$/i;
-    # ignore the test extensions
-    return if $dir =~ m{ext/XS/(?:APItest|Typemap)/};
+    # ignore the test extensions, dont install PPPort.so/.dll
+    return if $dir =~ m{\b(?:XS/(?:APItest|Typemap)|Devel/PPPort)\b};
     # ignore the demo files
     return if $dir =~ /\bdemos?\b/;
 
@@ -838,6 +848,9 @@ sub installlib {
 
     $name = "$dir/$name" if $dir ne '';
 
+    #blead comes with version, blead isn't 5.8/5.6
+    return if $name eq 'ExtUtils/MakeMaker/version/regex.pm';
+
     my $installlib = $installprivlib;
     if ($dir =~ /^auto/ ||
 	  ($name =~ /^(.*)\.(?:pm|pod)$/ && $archpms{$1}) ||
PATCH
        return;
    }

    if (_ge($version, "5.8.2")) {
        _patch(<<'PATCH');
--- installperl
+++ installperl
@@ -404,6 +404,9 @@ if ($Is_VMS) {  # We did core file selection during build
     $coredir =~ tr/./_/;
     map { s|^$coredir/||i; } @corefiles = <$coredir/*.*>;
 }
+elsif ($Is_W32) {
+    @corefiles = <*.h>;
+}
 else {
     # [als] hard-coded 'libperl' name... not good!
     @corefiles = <*.h *.inc libperl*.* perl*$Config{lib_ext}>;
@@ -441,6 +444,12 @@ if ($Config{use5005threads}) {
 	chmod(0444, $t);
     }
 }
+if ($Is_W32) { #linking lib isn't made in root but in CORE on Win32
+    @corefiles = <lib/CORE/libperl*.* lib/CORE/perl*$Config{lib_ext}>;
+    my $dest;
+    copy_if_diff($_,($dest = $installarchlib.substr($_,3))) &&
+    chmod(0444, $dest) foreach @corefiles;
+}
 
 # Install main perl executables
 # Make links to ordinary names if installbin directory isn't current directory.
@@ -825,11 +834,14 @@ sub installlib {
 
     # ignore the Makefiles
     return if $name =~ /^makefile$/i;
-    # ignore the test extensions
-    return if $dir =~ m{ext/XS/(?:APItest|Typemap)/};
+    # ignore the test extensions, dont install PPPort.so/.dll
+    return if $dir =~ m{\b(?:XS/(?:APItest|Typemap)|Devel/PPPort)\b};
 
     $name = "$dir/$name" if $dir ne '';
 
+    #blead comes with version, blead isn't 5.8/5.6
+    return if $name eq 'ExtUtils/MakeMaker/version/regex.pm';
+
     my $installlib = $installprivlib;
     if ($dir =~ /^auto/ ||
 	  ($name =~ /^(.*)\.(?:pm|pod)$/ && $archpms{$1}) ||
PATCH
        return;
    }

    if (_ge($version, "5.8.1")) {
        _patch(<<'PATCH');
--- installperl
+++ installperl
@@ -401,6 +401,9 @@ if ($Is_VMS) {  # We did core file selection during build
     $coredir =~ tr/./_/;
     map { s|^$coredir/||i; } @corefiles = <$coredir/*.*>;
 }
+elsif ($Is_W32) {
+    @corefiles = <*.h>;
+}
 else {
     # [als] hard-coded 'libperl' name... not good!
     @corefiles = <*.h libperl*.*>;
@@ -438,6 +441,12 @@ if ($Config{use5005threads}) {
 	chmod(0444, $t);
     }
 }
+if ($Is_W32) { #linking lib isn't made in root but in CORE on Win32
+    @corefiles = <lib/CORE/libperl*.* lib/CORE/perl*$Config{lib_ext}>;
+    my $dest;
+    copy_if_diff($_,($dest = $installarchlib.substr($_,3))) &&
+    chmod(0444, $dest) foreach @corefiles;
+}
 
 # Install main perl executables
 # Make links to ordinary names if installbin directory isn't current directory.
@@ -808,11 +817,14 @@ sub installlib {
 	      $dir  =~ m{/t(?:/|$)};
     # ignore the cpan script in lib/CPAN/bin (installed later with other utils)
     return if $name eq 'cpan';
-    # ignore the test extensions
-    return if $dir =~ m{ext/XS/(?:APItest|Typemap)/};
+    # ignore the test extensions, dont install PPPort.so/.dll
+    return if $dir =~ m{\b(?:XS/(?:APItest|Typemap)|Devel/PPPort)\b};
 
     $name = "$dir/$name" if $dir ne '';
 
+    #blead comes with version, blead isn't 5.8/5.6
+    return if $name eq 'ExtUtils/MakeMaker/version/regex.pm';
+
     my $installlib = $installprivlib;
     if ($dir =~ /^auto/ ||
 	  ($name =~ /^(.*)\.(?:pm|pod)$/ && $archpms{$1}) ||
PATCH
        return;
    }

    if (_ge($version, "5.8.0")) {
        _patch(<<'PATCH');
--- installperl
+++ installperl
@@ -359,6 +359,9 @@ if ($Is_VMS) {  # We did core file selection during build
     $coredir =~ tr/./_/;
     map { s|^$coredir/||i; } @corefiles = <$coredir/*.*>;
 }
+elsif ($Is_W32) {
+    @corefiles = <*.h>;
+}
 else {
     # [als] hard-coded 'libperl' name... not good!
     @corefiles = <*.h libperl*.*>;
@@ -397,6 +400,13 @@ if ($Config{use5005threads}) {
     }
 }
 
+if ($Is_W32) { #linking lib isn't made in root but in CORE on Win32
+    @corefiles = <lib/CORE/libperl*.* lib/CORE/perl*$Config{lib_ext}>;
+    my $dest;
+    copy_if_diff($_,($dest = $installarchlib.substr($_,3))) &&
+    chmod(0444, $dest) foreach @corefiles;
+}
+
 # Install main perl executables
 # Make links to ordinary names if installbin directory isn't current directory.
 
@@ -757,11 +767,14 @@ sub installlib {
     # .exists files, .PL files, and .t files.
     return if $name =~ m{\.orig$|~$|^#.+#$|,v$|^\.exists|\.PL$|\.t$} ||
               $dir  =~ m{/t(?:/|$)};
-    # ignore the test extensions
-    return if $dir =~ m{ext/XS/(?:APItest|Typemap)/};
+    # ignore the test extensions, dont install PPPort.so/.dll
+    return if $dir =~ m{\b(?:XS/(?:APItest|Typemap)|Devel/PPPort)\b};
 
     $name = "$dir/$name" if $dir ne '';
 
+    #blead comes with version, blead isn't 5.8/5.6
+    return if $name eq 'ExtUtils/MakeMaker/version/regex.pm';
+
     my $installlib = $installprivlib;
     if ($dir =~ /^auto/ ||
 	  ($name =~ /^(.*)\.(?:pm|pod)$/ && $archpms{$1}) ||
PATCH
        return;
    }

    _patch(<<'PATCH');
--- installperl
+++ installperl
@@ -359,6 +359,9 @@ if ($Is_VMS) {  # We did core file selection during build
     $coredir =~ tr/./_/;
     map { s|^$coredir/||i; } @corefiles = <$coredir/*.*>;
 }
+elsif ($Is_W32) {
+    @corefiles = <*.h>;
+}
 else {
     # [als] hard-coded 'libperl' name... not good!
     @corefiles = <*.h libperl*.*>;
@@ -386,6 +389,13 @@ foreach my $file (@corefiles) {
     }
 }
 
+if ($Is_W32) { #linking lib isn't made in root but in CORE on Win32
+    @corefiles = <lib/CORE/libperl*.* lib/CORE/perl*$Config{lib_ext}>;
+    my $dest;
+    copy_if_diff($_,($dest = $installarchlib.substr($_,3))) &&
+    chmod(0444, $dest) foreach @corefiles;
+}
+
 # Install main perl executables
 # Make links to ordinary names if installbin directory isn't current directory.
 
PATCH
}

sub _patch_buildext_pl {
    my $version = shift;
    if ($version eq '5.7.3') {
        _patch(<<'PATCH');
--- win32/buildext.pl
+++ win32/buildext.pl
@@ -60,12 +60,12 @@ foreach my $dir (sort @ext)
     if ($targ)
      {
       print "Making $targ in $dir\n$make $targ\n";
-      system("$make $targ");
+      system("$make --debug $targ");
      }
     else
      {
       print "Making $dir\n$make\n";
-      system($make);
+      system("$make --debug");
      }
     chdir($here) || die "Cannot cd to $here:$!";
    }
PATCH
        return;
    }
}

1;
