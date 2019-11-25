#!/usr/bin/env perl

use utf8;
use warnings;
use strict;
use Try::Tiny;
use Perl::Build;
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
    my $install_dir = "$ENV{RUNNER_TOOL_CACHE}/perl/${version}/x64";
    my $tmpdir = $ENV{RUNNER_TEMP};

    group "build perl $version" => sub {
        my $jobs = 2; # from https://help.github.com/en/actions/automating-your-workflow-with-github-actions/virtual-environments-for-github-hosted-runners#supported-runners-and-hardware-resources
        if (version->parse("v$version") < version->parse("v5.12.0") ) {
            # Makefiles older than v5.12.0 could break parallel make.
            # it fixed by https://github.com/Perl/perl5/commit/0f13ebd5d71f81771c1044e2c89aff29b408bfec and
            # https://github.com/Perl/perl5/commit/2b63e250843b907e476587f037c0784d701fca62
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

    group "install App::cpanminus and Carton" => sub {
        system("sh", "-c", "curl -L https://cpanmin.us | '$install_dir/bin/perl' - --notest App::cpanminus Carton") == 0
            or die "Failed to install App::cpanminus and Carton";
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
