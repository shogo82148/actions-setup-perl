#!C:\Strawberry\perl\bin\perl.exe

use utf8;
use warnings;
use strict;
use 5.026002;
use FindBin;
use File::Copy;
use LWP::UserAgent;
use CPAN::Perl::Releases::MetaCPAN;
use Devel::PatchPerl;
use Try::Tiny;

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
        chdir $tmpdir or die "failed to cd $tmpdir: $!";
        system("7z", "x", $filename) == 0 or die "Failed to extract gz";
        system("7z", "x", "perl-$version.tar") == 0 or die "Failed to extract tar";
        Devel::PatchPerl->patch_source($version, "$tmpdir\\perl-$version");
    };

    group "build" => sub {
        chdir "$tmpdir\\perl-$version\\win32" or die "failed to cd $tmpdir\\perl-$version\\win32: $!";

        if (! -e "GNUMakefile") {
            copy("$FindBin::Bin\\GNUMakefile", "GNUMakefile") or die "copy failed: $!";
        }

        system("gmake", "-f", "GNUMakefile", "INST_TOP=$install_dir", "CCHOME=C:\\strawberry\\c") == 0
            or die "Failed to build";
    };

    group "install" => sub {
        local $ENV{PERL_DL_DEBUG} = 1;
        print STDERR "start install\n";
        system("gmake", "-f", "GNUMakefile", "install") == 0
            or die "Failed to install";
    };

    group "install App::cpanminus and Carton" => sub {
        local $ENV{PATH} = "$install_dir\\bin;C:\\Strawberry\\c;$ENV{PATH}";
        system("$install_dir\\bin\\cpan", "-T", "App::cpanminus", "Carton") == 0;
            or die "Failed to install App::cpanminus and Carton";
    };

    group "archiving" => sub {
        chdir $install_dir or die "failed to cd $install_dir: $!";
        system("7z", "a", "$tmpdir\\perl.zip", ".") == 0
            or die "failed to archive";
    };
}

try {
    run();
} catch {
    print "::error::$_\n";
};

1;
