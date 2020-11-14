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
use Actions::Core qw/group set_failed/;
use File::Basename qw(dirname);

my $version = $ENV{PERL_VERSION};
my $tmpdir = File::Spec->rel2abs($ENV{RUNNER_TEMP} || "tmp");
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
        # skip installing CPAN modules
        # see https://github.com/shogo82148/actions-setup-perl/pull/432
        # and https://github.com/shogo82148/actions-setup-perl/issues/225
        return if version->parse("v$version") < version->parse("v5.14.0");

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
