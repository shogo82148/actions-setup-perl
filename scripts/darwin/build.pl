#!/usr/bin/env perl

use utf8;
use warnings;
use strict;
use Try::Tiny;
use Perl::Build;

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
        Perl::Build->install_from_cpan(
            $version => (
                dst_path          => $install_dir,
                configure_options => ["-de", "-Dman1dir=none", "-Dman3dir=none"],
                jobs              => 2,
            )
        );
    };

    group "install App::cpanminus and Carton" => sub {
        system("sh", "-c" "curl -L https://cpanmin.us | '$install_dir/bin/perl' - --notest App::cpanminus Carton") == 0
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
