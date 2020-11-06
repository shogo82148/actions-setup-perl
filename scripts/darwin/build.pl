#!/usr/bin/env perl

use utf8;
use warnings;
use strict;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Try::Tiny;
use Perl::Build;
use File::Spec;
use File::Path qw/make_path/;
use version 0.77 ();
use Actions::Core qw/group set_failed/;

sub run {
    my $version = $ENV{PERL_VERSION};
    my $tmpdir = File::Spec->rel2abs($ENV{RUNNER_TEMP} || "tmp");
    make_path($tmpdir);
    my $install_dir = File::Spec->rel2abs(
        File::Spec->catdir($ENV{RUNNER_TOOL_CACHE} || $tmpdir, "perl", $version, "x64"));

    group "build perl $version" => sub {
        local $ENV{PERL5_PATCHPERL_PLUGIN} = "GitHubActions";

        # get the number of CPU cores to parallel make
        my $jobs = `sysctl -n hw.logicalcpu_max` + 0;
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

    group "install common CPAN modules" => sub {
        my $perl = File::Spec->catfile($install_dir, 'bin', 'perl.exe');
        my $cpanm = File::Spec->catfile($FindBin::Bin, '..', '..', 'bin', 'cpanm');

        # JSON and YAML
        execute_or_die($perl, $cpanm, '-n', 'JSON', 'Cpanel::JSON::XS', 'JSON::XS', 'JSON::MaybeXS', 'YAML', 'YAML::Tiny', 'YAML::XS');

        # SSL/TLS
        execute_or_die($perl, $cpanm, '-n', 'Net::SSLeay');
        execute_or_die($perl, $cpanm, '-n', 'IO::Socket::SSL');
        execute_or_die($perl, $cpanm, '-n', 'Mozilla::CA');
    };

    group "archiving" => sub {
        chdir $install_dir or die "failed to cd $install_dir: $!";
        system("tar", "Jcvf", "$tmpdir/perl.tar.xz", ".") == 0
            or die "failed to archive";
    };
}

try {
    run();
} catch {
    set_failed("$_");
};

1;
