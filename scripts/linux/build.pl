#!/usr/bin/env perl

use utf8;
use warnings;
use strict;
use 5.026001;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Try::Tiny;
use Perl::Build;
use File::Spec;
use File::Path qw/make_path/;
use version 0.77 ();
use Carp qw/croak/;
use Actions::Core qw/warning info group set_failed/;

my $version = $ENV{PERL_VERSION};
my $thread = $ENV{PERL_MULTI_THREAD};
my $tmpdir = File::Spec->rel2abs($ENV{RUNNER_TEMP} || "tmp");
make_path($tmpdir);
my $runner_tool_cache = $tmpdir;
if (my $cache = $ENV{RUNNER_TOOL_CACHE}) {
    # install path is hard coded in the action, so check whether it has expected value.
    if ($cache ne '/opt/hostedtoolcache') {
        die "unexpected RUNNER_TOOL_CACHE: $cache";
    }
    $runner_tool_cache = $cache;
}
my $install_dir = File::Spec->rel2abs(
    File::Spec->catdir($runner_tool_cache, "perl", $version . ($thread ? "-thr" : ""), "x64"));
my $perl = File::Spec->catfile($install_dir, 'bin', 'perl');

# read cpanfile snapshot
my $snapshot = do {
    my $cpanfile = File::Spec->catdir($FindBin::Bin, "..", "common", "cpanfile.snapshot");
    open my $fh, "<", $cpanfile or die "failed to open cpanfile.snapshot: $!";
    local $/;
    my $snapshot = <$fh>;
    close $fh;
    $snapshot;
};

sub execute_or_die {
    my $code = system(@_);
    if ($code != 0) {
        my $cmd = join ' ', @_;
        croak "failed to execute $cmd: exit code $code";
    }
}

sub cpan_install {
    my ($url, $fragment, $name, $min_version, $max_version) = @_;

    my $skip = try {
        # this perl is too old to install the module.
        if ($min_version && version->parse("v$version") < version->parse("v$min_version")) {
            return 1;
        }
        # no need to install
        if ($max_version && version->parse("v$version") >= version->parse("v$max_version")) {
            return 1;
        }
        return 0;
    } catch {
        # perhaps, we clouldn't parse the version.
        # try installing.
        return 0;
    };
    return if $skip;

    try {
        local $ENV{PATH} = "$install_dir/bin:$ENV{PATH}";
        my ($filename, $dirname);
        # find version from cpanfile.snapshot
        if ($fragment && $snapshot =~ m(pathname:\s*(.*/(($fragment-[0-9.]+)[.]tar[.][0-9a-z]+)))) {
            $dirname = $3;
            $filename = $2;
            $url = "https://cpan.metacpan.org/authors/id/$1";

        # fallback to url
        } elsif ($url =~ m(^http://.*/([^/]+)/archive/(([0-9a-fA-F]+)[.]tar[.][0-9a-z]+))) {
            $dirname = "$1-$3";
            $filename = $2;
        } elsif ($url =~ m(^https://.*/(([^/]+)[.]tar[.][0-9a-z]+))) {
            $dirname = $2;
            $filename = $1
        }

        info "installing $name from $url";
        chdir $tmpdir or die "failed to cd $tmpdir: $!";
        execute_or_die('curl', '--retry', '3', '-sSL', $url, '-o', $filename);
        execute_or_die('tar', 'xvf', $filename);
        chdir File::Spec->catfile($tmpdir, $dirname) or die "failed to cd $dirname: $!";
        execute_or_die($perl, 'Makefile.PL');
        execute_or_die('make', 'install');
        execute_or_die($perl, "-M$name", "-e1");
    } catch {
        warning "installing $name from $url fails: @_";
    };
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
        if ($thread) {
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

    # cpanm or carton doesn't work with very very old version of perl.
    # so we manually install CPAN modules.
    group "install common CPAN modules" => sub {
        # JSON
        cpan_install('https://cpan.metacpan.org/authors/id/I/IS/ISHIGAKI/JSON-4.10.tar.gz', 'JSON', 'JSON', '5.5.3');

        # Cpanel::JSON::XS
        cpan_install('https://cpan.metacpan.org/authors/id/R/RU/RURBAN/Cpanel-JSON-XS-4.37.tar.gz', 'Cpanel-JSON-XS', 'Cpanel::JSON::XS', '5.6.2');

        # some requirements of JSON::XS
        cpan_install('https://cpan.metacpan.org/authors/id/M/ML/MLEHMANN/Canary-Stability-2013.tar.gz', 'Canary-Stability', 'Canary::Stability', '5.8.3');
        cpan_install('https://cpan.metacpan.org/authors/id/M/ML/MLEHMANN/common-sense-3.75.tar.gz', 'common-sense', 'common::sense', '5.8.3');
        cpan_install('https://cpan.metacpan.org/authors/id/M/ML/MLEHMANN/Types-Serialiser-1.01.tar.gz', 'Types-Serialiser', 'Types::Serialiser', '5.8.3');
        # JSON::XS
        cpan_install('https://cpan.metacpan.org/authors/id/M/ML/MLEHMANN/JSON-XS-4.03.tar.gz', 'JSON-XS', 'JSON::XS', '5.8.3');

        # some requirements of JSON::PP
        cpan_install('https://cpan.metacpan.org/authors/id/C/CO/CORION/parent-0.241.tar.gz', 'parent', 'parent', '5.6.0', '5.10.1');
        cpan_install('https://cpan.metacpan.org/authors/id/J/JK/JKEENAN/File-Path-2.18.tar.gz', 'File-Path', 'File::Path', '5.6.0', '5.6.1');
        cpan_install('https://cpan.metacpan.org/authors/id/P/PE/PEVANS/Scalar-List-Utils-1.63.tar.gz', 'Scalar-List-Utils', 'Scalar::Util', '5.6.0', '5.8.1');
        cpan_install('https://cpan.metacpan.org/authors/id/T/TO/TODDR/Exporter-5.78.tar.gz', 'Exporter', 'Exporter', '5.6.0', '5.6.1');
        cpan_install('https://cpan.metacpan.org/authors/id/E/ET/ETHER/File-Temp-0.2311.tar.gz', 'File-Temp', 'File::Temp', '5.6.0', '5.6.1');
        cpan_install('https://cpan.metacpan.org/authors/id/M/MA/MAKAMAKA/JSON-PP-Compat5006-1.09.tar.gz', 'JSON-PP-Compat5006', 'JSON::PP::Compat5006', '5.6.0', '5.8.0');
        # JSON::PP
        cpan_install('https://cpan.metacpan.org/authors/id/I/IS/ISHIGAKI/JSON-PP-4.16.tar.gz', 'JSON-PP', 'JSON::PP', '5.6.0');

        # JSON::MaybeXS
        cpan_install('https://cpan.metacpan.org/authors/id/E/ET/ETHER/JSON-MaybeXS-1.004005.tar.gz', 'JSON-MaybeXS', 'JSON::MaybeXS', '5.6.0');

        # YAML
        cpan_install('https://cpan.metacpan.org/authors/id/I/IN/INGY/YAML-1.31.tar.gz', 'YAML', 'YAML', '5.8.1');

        # YAML::Tiny
        cpan_install('https://cpan.metacpan.org/authors/id/E/ET/ETHER/YAML-Tiny-1.74.tar.gz', 'YAML-Tiny', 'YAML::Tiny', '5.8.1');

        # YAML::XS
        cpan_install('https://cpan.metacpan.org/authors/id/I/IN/INGY/YAML-LibYAML-0.88.tar.gz', 'YAML-LibYAML', 'YAML::XS', '5.8.1');

        ### SSL/TLS

        # Net::SSLeay
        cpan_install('https://cpan.metacpan.org/authors/id/C/CH/CHRISN/Net-SSLeay-1.92.tar.gz', 'Net-SSLeay', 'Net::SSLeay', '5.8.1');

        # Mozilla::CA
        cpan_install('https://cpan.metacpan.org/authors/id/L/LW/LWP/Mozilla-CA-20231213.tar.gz', 'Mozilla-CA', 'Mozilla::CA', '5.6.0');

        # IO::Socket::SSL
        local $ENV{NO_NETWORK_TESTING} = 1;
        local $ENV{PERL_MM_USE_DEFAULT} = 1;
        cpan_install('https://cpan.metacpan.org/authors/id/S/SU/SULLR/IO-Socket-SSL-2.084.tar.gz', 'IO-Socket-SSL', 'IO::Socket::SSL', '5.8.1');

        # Test::Harness
        cpan_install('https://cpan.metacpan.org/authors/id/L/LE/LEONT/Test-Harness-3.48.tar.gz', 'Test-Harness', 'Test::Harness', '5.6.0', '5.8.3');

        # local::lib
        cpan_install('https://cpan.metacpan.org/authors/id/H/HA/HAARG/local-lib-2.000029.tar.gz', 'local-lib', 'local::lib', '5.6.0');

        # requirements of Module::CoreList
        cpan_install('https://cpan.metacpan.org/authors/id/L/LE/LEONT/version-0.9930.tar.gz', 'version', 'version', '5.6.0', '5.8.9');
        # Module::CoreList
        cpan_install('https://cpan.metacpan.org/authors/id/B/BI/BINGOS/Module-CoreList-5.20231230.tar.gz', 'Module-CoreList', 'Module::CoreList', '5.6.0', '5.8.9');
    };

    group "archiving" => sub {
        chdir $install_dir or die "failed to cd $install_dir: $!";
        system("tar", "--use-compress-program", "zstd -T0 --long=30 --ultra -22", "-cf", "$tmpdir/perl.tar.zstd", ".") == 0
            or die "failed to archive";
    };
}

try {
    run();
} catch {
    set_failed("$_");
};

1;
