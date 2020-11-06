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
use File::Path qw/make_path/;
use Carp qw/croak/;
use Actions::Core qw/group set_failed/;

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

sub run {
    local $ENV{PERL5LIB} = ""; # ignore libraries of the host perl

    my $version = $ENV{PERL_VERSION};
    my $url = perl_release($version);

    $url =~ m/\/(perl-.*)$/;
    my $filename = $1;
    my $tmpdir = File::Spec->rel2abs($ENV{RUNNER_TEMP} || "tmp");
    make_path($tmpdir);
    my $install_dir = File::Spec->rel2abs(
        File::Spec->catdir($ENV{RUNNER_TOOL_CACHE} || $tmpdir, "perl", $version, "x64"));

    # NASM is required by OpenSSL
    group "install nasm" => sub {
        execute_or_die("choco install nasm");
        $ENV{PATH} = 'C:\Program Files\NASM;' . $ENV{PATH};
    };

    group "downloading OpenSSL" => sub {
        my $OPENSSL_VERSION = "1_1_1h";
        my $ua = LWP::UserAgent->new;
        my $response = $ua->get("https://github.com/openssl/openssl/archive/OpenSSL_$OPENSSL_VERSION.zip");
        if (!$response->is_success) {
            die "download failed: " . $response->status_line;
        }

        my $path = File::Spec->catfile($tmpdir, "openssl.tar.gz");
        open my $fh, ">", $path or die "fail to open $path: $!";
        binmode $fh;
        print $fh $response->content;
        close $fh;
    };

    group "extracting" => sub {
        my $dir = pushd($tmpdir);
        execute_or_die("7z x openssl.tar.gz -so | 7z x -si -ttar");
    };

    group "build and install OpenSSL" => sub {
        # get the number of CPU cores to parallel make
        my $jobs = ($ENV{NUMBER_OF_PROCESSORS} || 1) + 0;
        if ($jobs <= 0) {
            $jobs = 1;
        }
        execute_or_die('C:\strawberry\perl\bin\perl.exe Configure --prefix="' . $install_dir . '" mingw64');
        execute_or_die("gmake -j$jobs");
        execute_or_die('gmake install_sw');
    };

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
        execute_or_die(File::Spec->catfile($install_dir, 'bin', 'perl'), '-V');
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
