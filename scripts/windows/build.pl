#!C:\Strawberry\perl\bin\perl.exe

use utf8;
use warnings;
use strict;
use 5.026002;
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
use Actions::Core qw/info group set_failed/;
use File::Basename qw(dirname);

my $version = $ENV{PERL_VERSION};
my $tmpdir = File::Spec->rel2abs(
    File::Spec->catdir($ENV{RUNNER_TEMP} || "tmp", "build-perl-$$"));
make_path($tmpdir);
remove_tree($tmpdir, {keep_root => 1});
my $install_dir = File::Spec->rel2abs(
    File::Spec->catdir($ENV{RUNNER_TOOL_CACHE} || $tmpdir, "perl", $version, "x64"));
my $perl = File::Spec->catfile($install_dir, 'bin', 'perl');

sub perl_release {
    my $version = shift;
    my $releases = CPAN::Perl::Releases::MetaCPAN->new->get;
    for my $release (@$releases) {
        if ($release->{name} eq "perl-$version") {
            return $release->{download_url};
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
    my ($url, $min_version, $max_version) = @_;

    # this perl is too old to install the module.
    if ($min_version && version->parse("v$version") < version->parse("v$min_version")) {
        info "skip installing $url";
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

    info "installing $url";
    chdir $tmpdir or die "failed to cd $tmpdir: $!";
    execute_or_die('curl', '-sSL', $url, '-o', $filename);
    execute_or_die("7z x $filename -so | 7z x -si -ttar");
    chdir File::Spec->catfile($tmpdir, $dirname) or die "failed to cd $dirname: $!";
    execute_or_die($perl, 'Makefile.PL');
    execute_or_die('gmake', 'install');
}

sub run {
    local $ENV{PERL5LIB} = ""; # ignore libraries of the host perl

    my $url = perl_release($version);

    $url =~ m/\/(perl-.*)$/;
    my $filename = $1;

    group "downloading perl $version from $url" => sub {
        my $ua = LWP::UserAgent->new;
        my $response = $ua->get($url);
        if (!$response->is_success) {
            die "download failed: " . $response->status_line;
        }

        my $path = File::Spec->catfile($tmpdir, $filename);
        open my $fh, ">", $path or die "fail to open $path: $!";
        binmode $fh;
        print $fh $response->content;
        close $fh;
    };

    group "extracting..." => sub {
        my $dir = pushd($tmpdir);
        execute_or_die("7z x $filename -so | 7z x -si -ttar");
    };

    group "patching..." => sub {
        local $ENV{PERL5_PATCHPERL_PLUGIN} = "GitHubActions";
        my $dir = pushd(File::Spec->catdir($tmpdir, "perl-$version"));
        Devel::PatchPerl->patch_source($version);
    };

    group "build and install Perl" => sub {
        # get the number of CPU cores to parallel make
        my $jobs = ($ENV{NUMBER_OF_PROCESSORS} || 1) + 0;
        if ($jobs <= 0 || version->parse("v$version") < version->parse("v5.22.0") ) {
            # Makefiles older than v5.22.0 could break parallel make.
            $jobs = 1;
        }

        my $dir = pushd(File::Spec->catdir($tmpdir, "perl-$version", "win32"));
        execute_or_die("gmake", "-f", "GNUmakefile", "install", "INST_TOP=$install_dir", "CCHOME=C:\\MinGW", "-j", $jobs);
    };

    group "perl -V" => sub {
        execute_or_die(File::Spec->catfile($install_dir, 'bin', 'perl.exe'), '-V');
    };

    group "install common CPAN modules" => sub {
        # JSON
        cpan_install('https://cpan.metacpan.org/authors/id/I/IS/ISHIGAKI/JSON-4.02.tar.gz', '5.5.3');

        # Cpanel::JSON::XS
        # install fails with perl v5.13.0 - v.5.13.8
        # XS.xs:540:61: error: 'UTF8_DISALLOW_SUPER' undeclared (first use in this function); did you mean 'UNICODE_ALLOW_SUPER'?
        cpan_install('https://cpan.metacpan.org/authors/id/R/RU/RURBAN/Cpanel-JSON-XS-4.25.tar.gz', '5.6.2', '5.13.0');
        cpan_install('https://cpan.metacpan.org/authors/id/R/RU/RURBAN/Cpanel-JSON-XS-4.25.tar.gz', '5.13.9');

        # some requirements of JSON::XS
        cpan_install('https://cpan.metacpan.org/authors/id/M/ML/MLEHMANN/Canary-Stability-2013.tar.gz', '5.8.3');
        cpan_install('https://cpan.metacpan.org/authors/id/M/ML/MLEHMANN/common-sense-3.75.tar.gz', '5.8.3');
        cpan_install('https://cpan.metacpan.org/authors/id/M/ML/MLEHMANN/Types-Serialiser-1.0.tar.gz', '5.8.3');
        # JSON::XS
        cpan_install('https://cpan.metacpan.org/authors/id/M/ML/MLEHMANN/JSON-XS-4.03.tar.gz', '5.8.3');

        # some requirements of JSON::PP
        cpan_install('https://cpan.metacpan.org/authors/id/C/CO/CORION/parent-0.238.tar.gz', '5.6.0', '5.10.1');
        cpan_install('https://cpan.metacpan.org/authors/id/J/JK/JKEENAN/File-Path-2.18.tar.gz', '5.6.0', '5.6.1');
        cpan_install('https://cpan.metacpan.org/authors/id/P/PE/PEVANS/Scalar-List-Utils-1.55.tar.gz', '5.6.0', '5.8.1');
        cpan_install('https://cpan.metacpan.org/authors/id/T/TO/TODDR/Exporter-5.74.tar.gz', '5.6.0', '5.6.1');
        cpan_install('https://cpan.metacpan.org/authors/id/E/ET/ETHER/File-Temp-0.2311.tar.gz', '5.6.0', '5.6.1');
        cpan_install('https://cpan.metacpan.org/authors/id/M/MA/MAKAMAKA/JSON-PP-Compat5006-1.09.tar.gz', '5.6.0', '5.8.0');
        # JSON::PP
        cpan_install('https://cpan.metacpan.org/authors/id/I/IS/ISHIGAKI/JSON-PP-4.05.tar.gz', '5.6.0');

        # JSON::MaybeXS
        # unknown error with perl v5.12.x
        cpan_install('https://cpan.metacpan.org/authors/id/E/ET/ETHER/JSON-MaybeXS-1.004003.tar.gz', '5.13.0');
        cpan_install('https://cpan.metacpan.org/authors/id/E/ET/ETHER/JSON-MaybeXS-1.004003.tar.gz', '5.6.0', '5.12.0');

        # YAML
        cpan_install('https://cpan.metacpan.org/authors/id/T/TI/TINITA/YAML-1.30.tar.gz', '5.8.1');

        # YAML::Tiny
        cpan_install('https://cpan.metacpan.org/authors/id/E/ET/ETHER/YAML-Tiny-1.73.tar.gz', '5.8.1');

        # YAML::XS
        cpan_install('https://cpan.metacpan.org/authors/id/T/TI/TINITA/YAML-LibYAML-0.82.tar.gz', '5.8.1');

        ### SSL/TLS

        # Net::SSLeay
        cpan_install('https://cpan.metacpan.org/authors/id/C/CH/CHRISN/Net-SSLeay-1.88.tar.gz', '5.8.1');

        # Mozilla::CA
        cpan_install('https://cpan.metacpan.org/authors/id/A/AB/ABH/Mozilla-CA-20200520.tar.gz', '5.6.0');

        # IO::Socket::SSL
        local $ENV{NO_NETWORK_TESTING} = 1;
        local $ENV{PERL_MM_USE_DEFAULT} = 1;
        cpan_install('https://cpan.metacpan.org/authors/id/S/SU/SULLR/IO-Socket-SSL-2.068.tar.gz', '5.8.0');
    };

    group "archiving" => sub {
        my $dir = pushd($install_dir);
        execute_or_die("7z", "a", File::Spec->catfile($tmpdir, "perl.zip"), ".");
    };
}

try {
    run();
} catch {
    set_failed("$_");
};

1;
