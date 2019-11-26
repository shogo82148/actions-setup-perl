#!C:\Strawberry\perl\bin\perl.exe

use utf8;
use warnings;
use strict;
use 5.026002;
use FindBin;
use lib "$FindBin::Bin/lib";
use File::Copy;
use LWP::UserAgent;
use CPAN::Perl::Releases::MetaCPAN;
use Devel::PatchPerl;
use Try::Tiny;
use File::pushd qw[pushd];

local $| = 1;

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
    my $url = perl_release($version);

    my $tmpdir = $ENV{RUNNER_TEMP};
    $url =~ m/\/(perl-.*)$/;
    my $filename = $1;
    my $install_dir = "$ENV{RUNNER_TOOL_CACHE}\\perl\\${version}\\x64";

    group "downloading perl $version from $url" => sub {
        my $ua = LWP::UserAgent->new;
        my $response = $ua->get($url);
        if (!$response->is_success) {
            die "download failed: " . $response->status_line;
        }

        open my $fh, ">", "$tmpdir\\$filename" or die "$!";
        binmode $fh;
        print $fh $response->content;
        close $fh;
    };

    group "extracting..." => sub {
        my $dir = pushd($tmpdir);
        system("7z", "x", $filename) == 0 or die "Failed to extract gz";
        system("7z", "x", "perl-$version.tar") == 0 or die "Failed to extract tar";
    };

    group "patching..." => sub {
        local $ENV{PERL5_PATCHPERL_PLUGIN} = "MinGW";
        Devel::PatchPerl->patch_source($version, "$tmpdir\\perl-$version");
    };

    group "build" => sub {
        my $dir = pushd("$tmpdir\\perl-$version\\win32");
        system("gmake", "-f", "GNUMakefile", "INST_TOP=$install_dir", "CCHOME=C:\\strawberry\\c") == 0
            or die "Failed to build";
    };

    group "install" => sub {
        my $dir = pushd("$tmpdir\\perl-$version\\win32");
        system("gmake", "-f", "GNUMakefile", "install") == 0
            or die "Failed to install";
    };

    group "install App::cpanminus and Carton" => sub {
        my $ua = LWP::UserAgent->new;
        my $response = $ua->get("https://cpanmin.us");
        if (!$response->is_success) {
            die "download failed: " . $response->status_line;
        }

        open my $fh, ">", "$tmpdir\\cpanm" or die "$!";
        binmode $fh;
        print $fh $response->content;
        close $fh;

        system("$install_dir\\bin\\perl", "$tmpdir\\cpanm", "--notest", "App::cpanminus", "Carton") == 0
            or die "Failed to install App::cpanminus and Carton";
    };

    group "archiving" => sub {
        my $dir = pushd($install_dir);
        system("7z", "a", "$tmpdir\\perl.zip", ".") == 0
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
