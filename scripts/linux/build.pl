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
    my ($required_version, $url) = @_;

    # this perl is too old to install the module.
    if (version->parse("v$version") < version->parse("v$required_version")) {
        info "skip installing $url";
        return;
    }

    my @path = split m(/), $url;
    my $filename = $path[-1];
    my @ext = split /[.]/, $filename;
    my $dirname = $ext[0];

    info "installing $url";
    chdir $tmpdir or die "failed to cd $tmpdir: $!";
    execute_or_die('curl', '-sSL', $url, '-o', $filename);
    execute_or_die('tar', 'xvf', $filename);
    chdir File::Spec->catfile($tmpdir, $dirname) or die "failed to cd $dirname: $!";
    execute_or_die($perl, 'Makefile.PL');
    execute_or_die('make', 'install');
}

sub run {
    group "build perl $version" => sub {
        local $ENV{PERL5_PATCHPERL_PLUGIN} = "GitHubActions";

        # get the number of CPU cores to parallel make
        my $jobs = `nproc` + 0; # evaluate `nproc` in number context
        if ($jobs <= 0 || version->parse("v$version") < version->parse("v5.20.0") ) {
            # Makefiles older than v5.20.0 could break parallel make.
            $jobs = 1;
        }

        my @options = ("-de", "-Dman1dir=none", "-Dman3dir=none");
        if ($ENV{PERL_MULTI_THREAD}) {
            # enable multi threading
            push @options, "-Duseshrplib", "-Duseithreads";
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
        # some modules require newer version of ExtUtils::MakeMaker
        cpan_install('5.6.0', 'https://cpan.metacpan.org/authors/id/B/BI/BINGOS/ExtUtils-MakeMaker-7.54.tar.gz');

        # JSON
        cpan_install('5.6.0', 'https://cpan.metacpan.org/authors/id/I/IS/ISHIGAKI/JSON-4.02.tar.gz');

        # Cpanel::JSON::XS
        cpan_install('5.6.2', 'https://cpan.metacpan.org/authors/id/R/RU/RURBAN/Cpanel-JSON-XS-4.25.tar.gz');

        # some requirements of JSON::XS
        cpan_install('5.8.3', 'https://cpan.metacpan.org/authors/id/M/ML/MLEHMANN/Canary-Stability-2013.tar.gz');
        cpan_install('5.8.3', 'https://cpan.metacpan.org/authors/id/M/ML/MLEHMANN/common-sense-3.75.tar.gz');
        cpan_install('5.8.3', 'https://cpan.metacpan.org/authors/id/M/ML/MLEHMANN/Types-Serialiser-1.0.tar.gz');

        # JSON::XS
        cpan_install('5.8.3', 'https://cpan.metacpan.org/authors/id/M/ML/MLEHMANN/JSON-XS-4.03.tar.gz');

        # JSON::PP
        cpan_install('5.6.0', 'https://cpan.metacpan.org/authors/id/I/IS/ISHIGAKI/JSON-PP-4.05.tar.gz');

        # JSON::MaybeXS
        cpan_install('5.6.0', 'https://cpan.metacpan.org/authors/id/E/ET/ETHER/JSON-MaybeXS-1.004003.tar.gz');

        # YAML
        cpan_install('5.8.1', 'https://cpan.metacpan.org/authors/id/T/TI/TINITA/YAML-1.30.tar.gz');

        # YAML::Tiny
        cpan_install('5.8.1', 'https://cpan.metacpan.org/authors/id/E/ET/ETHER/YAML-Tiny-1.73.tar.gz');

        # YAML::XS
        cpan_install('5.8.1', 'https://cpan.metacpan.org/authors/id/T/TI/TINITA/YAML-LibYAML-0.82.tar.gz');

        ### SSL/TLS

        # Net::SSLeay
        cpan_install('5.8.1', 'https://cpan.metacpan.org/authors/id/C/CH/CHRISN/Net-SSLeay-1.88.tar.gz');

        # Mozilla::CA
        cpan_install('5.6.0', 'https://cpan.metacpan.org/authors/id/A/AB/ABH/Mozilla-CA-20200520.tar.gz');

        # IO::Socket::SSL
        local $ENV{NO_NETWORK_TESTING} = 1;
        cpan_install('5.8.0', 'https://cpan.metacpan.org/authors/id/S/SU/SULLR/IO-Socket-SSL-2.068.tar.gz');
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
