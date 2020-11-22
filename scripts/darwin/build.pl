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
use Carp qw/croak/;
use Actions::Core qw/info group set_failed/;

my $version = $ENV{PERL_VERSION};
my $tmpdir = File::Spec->rel2abs($ENV{RUNNER_TEMP} || "tmp");
make_path($tmpdir);
my $install_dir = File::Spec->rel2abs(
    File::Spec->catdir($ENV{RUNNER_TOOL_CACHE} || $tmpdir, "perl", $version, "x64"));
my $perl = File::Spec->catfile($install_dir, 'bin', 'perl');

sub execute_or_die {
    my $code = system(@_);
    if ($code != 0) {
        my $cmd = join ' ', @_;
        croak "failed to execute $cmd: exit code $code";
    }
}

sub cpan_install {
    my ($url, $name, $min_version, $max_version) = @_;

    # this perl is too old to install the module.
    if ($min_version && version->parse("v$version") < version->parse("v$min_version")) {
        info "skip installing $name";
        return;
    }

    # no need to install
    if ($max_version && version->parse("v$version") >= version->parse("v$max_version")) {
        return;
    }

    my @path = split m(/), $url;
    my $filename = $path[-1];
    my @ext = split /[.]tar[.]/, $filename;
    my $dirname = $ext[0];

    info "installing $name from $url";
    chdir $tmpdir or die "failed to cd $tmpdir: $!";
    execute_or_die('curl', '--retry', '3', '-sSL', $url, '-o', $filename);
    execute_or_die('tar', 'xvf', $filename);
    chdir File::Spec->catfile($tmpdir, $dirname) or die "failed to cd $dirname: $!";
    execute_or_die($perl, 'Makefile.PL');
    execute_or_die('make', 'install');
    execute_or_die($perl, "-M$name", "-e1");
}

sub run {
    group "build perl $version" => sub {
        local $ENV{PERL5_PATCHPERL_PLUGIN} = "GitHubActions";

        # get the number of CPU cores to parallel make
        my $jobs = `sysctl -n hw.logicalcpu_max` + 0;
        if ($jobs <= 0 || version->parse("v$version") < version->parse("v5.30.0")) {
            # Makefiles older than v5.30.0 could break parallel make.
            $jobs = 1;
        }

        my @options = ("-de", "-Dman1dir=none", "-Dman3dir=none");
        if ($ENV{PERL_MULTI_THREAD}) {
            # enable multi threading
            push @options, "-Duseithreads";
        }

        Perl::Build->install_from_cpan(
            $version => (
                dst_path          => $install_dir,
                configure_options => \@options,
                jobs              => $jobs,
            )
        );
    };

    group "perl -V" => sub {
        execute_or_die($perl, '-V');
    };

    group "install common CPAN modules" => sub {
        # JSON
        cpan_install('https://cpan.metacpan.org/authors/id/I/IS/ISHIGAKI/JSON-4.02.tar.gz', 'JSON', '5.5.3');

        # Cpanel::JSON::XS
        cpan_install('https://cpan.metacpan.org/authors/id/R/RU/RURBAN/Cpanel-JSON-XS-4.25.tar.gz', 'Cpanel::JSON::XS', '5.6.2');

        # some requirements of JSON::XS
        cpan_install('https://cpan.metacpan.org/authors/id/M/ML/MLEHMANN/Canary-Stability-2013.tar.gz', 'Canary::Stability', '5.8.3');
        cpan_install('https://cpan.metacpan.org/authors/id/M/ML/MLEHMANN/common-sense-3.75.tar.gz', 'common::sense', '5.8.3');
        cpan_install('https://cpan.metacpan.org/authors/id/M/ML/MLEHMANN/Types-Serialiser-1.0.tar.gz', 'Types::Serialiser', '5.8.3');
        # JSON::XS
        cpan_install('https://cpan.metacpan.org/authors/id/M/ML/MLEHMANN/JSON-XS-4.03.tar.gz', 'JSON::XS', '5.8.3');

        # some requirements of JSON::PP
        cpan_install('https://cpan.metacpan.org/authors/id/C/CO/CORION/parent-0.238.tar.gz', 'parent', '5.6.0', '5.10.1');
        cpan_install('https://cpan.metacpan.org/authors/id/J/JK/JKEENAN/File-Path-2.18.tar.gz', 'File::Path', '5.6.0', '5.6.1');
        cpan_install('https://cpan.metacpan.org/authors/id/P/PE/PEVANS/Scalar-List-Utils-1.55.tar.gz', 'Scalar::List::Utils', '5.6.0', '5.8.1');
        cpan_install('https://cpan.metacpan.org/authors/id/T/TO/TODDR/Exporter-5.74.tar.gz', 'Exporter', '5.6.0', '5.6.1');
        cpan_install('https://cpan.metacpan.org/authors/id/E/ET/ETHER/File-Temp-0.2311.tar.gz', 'File::Temp', '5.6.0', '5.6.1');
        cpan_install('https://cpan.metacpan.org/authors/id/M/MA/MAKAMAKA/JSON-PP-Compat5006-1.09.tar.gz', 'JSON::PP::Compat5006', '5.6.0', '5.8.0');
        # JSON::PP
        cpan_install('https://cpan.metacpan.org/authors/id/I/IS/ISHIGAKI/JSON-PP-4.05.tar.gz', 'JSON::PP', '5.6.0');

        # JSON::MaybeXS
        cpan_install('https://cpan.metacpan.org/authors/id/E/ET/ETHER/JSON-MaybeXS-1.004003.tar.gz', 'JSON::MaybeXS', '5.6.0');

        # YAML
        cpan_install('https://cpan.metacpan.org/authors/id/T/TI/TINITA/YAML-1.30.tar.gz', 'YAML', '5.8.1');

        # YAML::Tiny
        cpan_install('https://cpan.metacpan.org/authors/id/E/ET/ETHER/YAML-Tiny-1.73.tar.gz', 'YAML::Tiny', '5.8.1');

        # YAML::XS
        cpan_install('https://cpan.metacpan.org/authors/id/T/TI/TINITA/YAML-LibYAML-0.82.tar.gz', 'YAML::XS', '5.8.1');

        ### SSL/TLS

        # Net::SSLeay
        cpan_install('https://cpan.metacpan.org/authors/id/C/CH/CHRISN/Net-SSLeay-1.88.tar.gz', 'Net::SSLeay', '5.8.1');

        # Mozilla::CA
        cpan_install('https://cpan.metacpan.org/authors/id/A/AB/ABH/Mozilla-CA-20200520.tar.gz', 'Mozilla::CA', '5.6.0');

        # IO::Socket::SSL
        local $ENV{NO_NETWORK_TESTING} = 1;
        local $ENV{PERL_MM_USE_DEFAULT} = 1;
        cpan_install('https://cpan.metacpan.org/authors/id/S/SU/SULLR/IO-Socket-SSL-2.068.tar.gz', 'IO::Socket::SSL', '5.8.0');
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
