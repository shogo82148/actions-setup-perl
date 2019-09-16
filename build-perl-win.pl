#!C:\Strawberry\perl\bin\perl.exe

use utf8;
use warnings;
use strict;
use 5.026002;
use LWP::UserAgent;

my $version = $ENV{PERL_VERSION};
my %version2url = (
    "5.30.0" => "https://cpan.metacpan.org/authors/id/X/XS/XSAWYERX/perl-5.30.0.tar.gz",
    "5.28.2" => "https://cpan.metacpan.org/authors/id/S/SH/SHAY/perl-5.28.2.tar.gz",
    "5.28.1" => "https://cpan.metacpan.org/authors/id/S/SH/SHAY/perl-5.28.1.tar.gz",
    "5.28.0" => "https://cpan.metacpan.org/authors/id/X/XS/XSAWYERX/perl-5.28.0.tar.gz",
    "5.26.3" => "https://cpan.metacpan.org/authors/id/S/SH/SHAY/perl-5.26.3.tar.bz2",
    "5.26.2" => "https://cpan.metacpan.org/authors/id/S/SH/SHAY/perl-5.26.2.tar.gz",
    "5.26.1" => "https://cpan.metacpan.org/authors/id/S/SH/SHAY/perl-5.26.1.tar.gz",
    "5.26.0" => "https://cpan.metacpan.org/authors/id/X/XS/XSAWYERX/perl-5.26.0.tar.bz2",
);
my $url = $version2url{$version};
print STDERR "downloading perl $version...\n";
my $ua = LWP::UserAgent->new;
my $response = $ua->get($url);
if (!$response->is_success) {
    die "download failed: " . $response->status_line;
}

$url =~ m/\/(perl-.*)$/;
my $filename = $1;
my $tmpdir = $ENV{RUNNER_TEMP};
open my $fh, ">", "$tmpdir\\$filename" or die "$!";
binmode $fh;
print $fh $response->content;
close $fh;

print STDERR "extracting...\n";
chdir $tmpdir or die "failed to cd $tmpdir: $!";
system("7z", "x", $filename) == 0 or die "Failed to extract gz";
system("7z", "x", "perl-$version.tar") == 0 or die "Failed to extract tar";

print STDERR "start build\n";
chdir "$tmpdir\\perl-$version\\win32" or die "failed to cd $tmpdir\\perl-$version\\win32: $!";
my $install_dir = "$ENV{RUNNER_TOOL_CACHE}\\perl\\${version}\\x64";
system("gmake", "INST_TOP=$install_dir") == 0
    or die "Failed to build";

print STDERR "start install\n";
system("gmake", "install") == 0
    or die "Failed to install";

print STDERR "install App::cpanminus and Carton\n";
my $ret = do {
    local $ENV{PATH} = "$install_dir\\bin;C:\\Strawberry\\c;$ENV{PATH}";
    system("$install_dir\\bin\\cpan", "-T", "App::cpanminus", "Carton") == 0;
};

if (!$ret) {
    die "Failed to install App::cpanminus and Carton";
}

print STDERR "archiving...\n";
chdir $install_dir or die "failed to cd $install_dir: $!";
system("7z", "a", "$tmpdir\\perl.zip", ".") == 0
    or die "failed to archive";

1;
