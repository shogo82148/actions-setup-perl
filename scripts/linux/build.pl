#!/usr/bin/env perl

use utf8;
use warnings;
use strict;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Try::Tiny;
use Perl::Build;
use File::Spec;
use version 0.77 ();

local $| = 1;

sub group {
    my ($name, $sub) = @_;
    try {
        print "::group::$name\n";
        $sub->();
    } catch {
        die $_;
    } finally {
        print "::endgroup::\n";
    };
}

sub run {
    my $version = $ENV{PERL_VERSION};
    my $install_dir = File::Spec->catdir($ENV{RUNNER_TOOL_CACHE}, "perl", $version, "x64");
    my $tmpdir = $ENV{RUNNER_TEMP};

    group "build perl $version" => sub {
        local $ENV{PERL5_PATCHPERL_PLUGIN} = "GitHubActions";

        my $jobs = `nproc` + 0; # evaluate `nproc` in number context
        if ($jobs <= 0 || version->parse("v$version") < version->parse("v5.20.0") ) {
            # Makefiles older than v5.20.0 could break parallel make.
            $jobs = 1;
        }

        Perl::Build->install_from_cpan(
            $version => (
                dst_path          => $install_dir,
                configure_options => ["-de", "-Dman1dir=none", "-Dman3dir=none"],
                jobs              => $jobs,
            )
        );
    };

    group "perl -V" => sub {
        system(File::Spec->catfile($install_dir, 'bin', 'perl'), '-V') == 0 or die "$!";
    };

    group "archiving" => sub {
        chdir $install_dir or die "failed to cd $install_dir: $!";
        system("tar", "zcf", "$tmpdir/perl.tar.gz", ".") == 0
            or die "failed to archive";
    };
}

try {
    run();
} catch {
    print "::error::$_\n";
    exit 1;
};

1;
