#!C:\Strawberry\perl\bin\perl.exe

use utf8;
use warnings;
use strict;
use 5.026001;
use FindBin;
use lib "$FindBin::Bin/../lib";
use File::Copy;
use LWP::UserAgent;
use CPAN::Perl::Releases::MetaCPAN;
use Devel::PatchPerl;
use Try::Tiny;
use File::pushd qw[pushd];
use File::Spec;
use File::Path qw/make_path remove_tree/;
use Carp qw/croak/;
use Actions::Core qw/warning info group set_failed/;
use Actions::Core::Command qw(issue_command);

my $version = $ENV{PERL_VERSION};
my $thread = $ENV{PERL_MULTI_THREAD};
my $tmpdir = File::Spec->rel2abs(
    File::Spec->catdir($ENV{RUNNER_TEMP} || "tmp"));
my $runner_tool_cache = $tmpdir;
if (my $cache = $ENV{RUNNER_TOOL_CACHE}) {
    # install path is hard coded in the action, so check whether it has expected value.
    if ($cache ne 'C:\hostedtoolcache\windows') {
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


sub perl_release {
    my $version = shift;

    if ($version =~ /^[0-9a-f]{7,}$/i) {
        # it looks like SHA1 Hash of git commit.
        # download from GitHub.
        return "https://github.com/Perl/perl5/archive/$version.tar.gz", "perl5-$version";
    }

    my $releases = CPAN::Perl::Releases::MetaCPAN->new->get;
    for my $release (@$releases) {
        if ($release->{name} eq "perl-$version") {
            return $release->{download_url}, "perl-$version";
        }
    }
    die "not found the tarball for perl-$version\n";
}

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
        local $ENV{PATH} = "$install_dir\\bin;C:\\strawberry\\c\\bin;$ENV{PATH}";
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
        execute_or_die("7z x $filename -so | 7z x -si -ttar");
        chdir File::Spec->catfile($tmpdir, $dirname) or die "failed to cd $dirname: $!";
        execute_or_die($perl, 'Makefile.PL');
        execute_or_die('gmake', 'install');
        execute_or_die($perl, "-M$name", "-e1");
    } catch {
        warning "installing $name from $url fails: @_";
    };
}

# get the number of CPU cores to parallel make
sub jobs {
    my $version = shift;
    my $new = eval { version->parse("v$version") >= version->parse("v5.22.0") };
    if (!$new) {
        # Makefile of old perl versions could break parallel make.
        return 1;
    }

    my $jobs = ($ENV{NUMBER_OF_PROCESSORS} || 1) + 0;
    if ($jobs < 0) {
        return 1;
    }
    return $jobs;
}

sub run {
    local $ENV{PERL5LIB} = ""; # ignore libraries of the host perl

    my ($url, $perldir) = perl_release($version);
    my $filename = "perl.tar.gz";

    # extracted directory
    $perldir = File::Spec->catdir($tmpdir, $perldir);

    group "downloading perl $version from $url" => sub {
        my $path = File::Spec->catfile($tmpdir, $filename);
        execute_or_die('curl', '--retry', '3', '-sSL', $url, '-o', $path);
    };

    group "extracting..." => sub {
        my $dir = pushd($tmpdir);
        execute_or_die("7z x $filename -so | 7z x -si -ttar");
    };

    group "patching..." => sub {
        local $ENV{PERL5_PATCHPERL_PLUGIN} = "GitHubActions";
        my $dir = pushd($perldir);
        Devel::PatchPerl->patch_source();
    };

    group "build and install Perl" => sub {
        my $dir = pushd(File::Spec->catdir($perldir, "win32"));
        my @args = (
            "-f", "GNUmakefile",
            "-j", jobs($version),
            "INST_TOP=$install_dir",
            'CCHOME=C:\strawberry\c',

            # I don't know why, but the build fails with the following error on Windows, Perl 5.38.0 threaded:
            #   ..\miniperl.exe -I..\lib ..\make_patchnum.pl
            #   Updating 'git_version.h' and 'lib/Config_git.pl'
            #   'CCLIBDIR' contains the following non-existing paths:
            #   	C:\strawberry\c\lib\gcc\x86_64-w64-mingw32\8.1.0
            #   Did you provide a correct value for the 'CCHOME' option?
            
            #   (This check can be skipped by using the SKIP_CCHOME_CHECK=1 option)
            #   gmake: *** [GNUmakefile:1202: ..\config.sh] Error 1
            # https://github.com/shogo82148/actions-setup-perl/pull/1555#issuecomment-1618505106
            'SKIP_CCHOME_CHECK=1',
        );
        if ($thread) {
            push @args, "USE_ITHREADS=define";
        } else {
            push @args, "USE_ITHREADS=undef";
        }
        execute_or_die("gmake", @args, "install");
    };

    group "perl -V" => sub {
        execute_or_die(File::Spec->catfile($install_dir, 'bin', 'perl.exe'), '-V');
    };

    group "install common CPAN modules" => sub {
        # Win32
        cpan_install('https://cpan.metacpan.org/authors/id/J/JD/JDB/Win32-0.59.tar.gz', 'Win32', 'Win32', '5.6.0', '5.8.3');
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
        # NOTE:
        # IO::Socket::SSL supports v5.8.1, but it doesn't work on Windows
        # https://github.com/shogo82148/actions-setup-perl/pull/480#issuecomment-735391122
        local $ENV{NO_NETWORK_TESTING} = 1;
        local $ENV{PERL_MM_USE_DEFAULT} = 1;
        cpan_install('https://cpan.metacpan.org/authors/id/S/SU/SULLR/IO-Socket-SSL-2.084.tar.gz', 'IO-Socket-SSL', 'IO::Socket::SSL', '5.8.1');

        # Test::Harness
        cpan_install('https://cpan.metacpan.org/authors/id/L/LE/LEONT/Test-Harness-3.48.tar.gz', 'Test-Harness', 'Test::Harness', '5.6.0', '5.8.3');

        # requirements of Module::CoreList
        cpan_install('https://cpan.metacpan.org/authors/id/L/LE/LEONT/version-0.9930.tar.gz', 'version', 'version', '5.6.0', '5.8.9');
        # Module::CoreList
        cpan_install('https://cpan.metacpan.org/authors/id/B/BI/BINGOS/Module-CoreList-5.20231230.tar.gz', 'Module-CoreList', 'Module::CoreList', '5.6.0', '5.8.9');
    };

    group "archiving" => sub {
        my $dir = pushd($install_dir);
        execute_or_die("7z", "a", File::Spec->catfile($tmpdir, "perl.zip"), ".");
    };
}

try {
    issue_command('add-matcher', {}, File::Spec->catfile($FindBin::Bin, "..", "matcher.json"));
    run();
} catch {
    set_failed("$_");
} finally {
    issue_command('remove-matcher', {owner => 'perl-builder'});
};

1;
