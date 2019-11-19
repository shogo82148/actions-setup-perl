#!C:\Strawberry\perl\bin\perl.exe

use utf8;
use warnings;
use strict;
use 5.026002;
use LWP::UserAgent;

my $version = $ENV{PERL_VERSION};
my %version2url = (
    "5.30.1" => "https://cpan.metacpan.org/authors/id/S/SH/SHAY/perl-5.30.1.tar.gz",
    "5.30.0" => "https://cpan.metacpan.org/authors/id/X/XS/XSAWYERX/perl-5.30.0.tar.gz",
    "5.28.2" => "https://cpan.metacpan.org/authors/id/S/SH/SHAY/perl-5.28.2.tar.gz",
    "5.28.1" => "https://cpan.metacpan.org/authors/id/S/SH/SHAY/perl-5.28.1.tar.gz",
    "5.28.0" => "https://cpan.metacpan.org/authors/id/X/XS/XSAWYERX/perl-5.28.0.tar.gz",
    "5.26.3" => "https://cpan.metacpan.org/authors/id/S/SH/SHAY/perl-5.26.3.tar.bz2",
    "5.26.2" => "https://cpan.metacpan.org/authors/id/S/SH/SHAY/perl-5.26.2.tar.gz",
    "5.26.1" => "https://cpan.metacpan.org/authors/id/S/SH/SHAY/perl-5.26.1.tar.gz",
    "5.26.0" => "https://cpan.metacpan.org/authors/id/X/XS/XSAWYERX/perl-5.26.0.tar.bz2",
    "5.24.4" => "https://cpan.metacpan.org/authors/id/S/SH/SHAY/perl-5.24.4.tar.gz",
    "5.24.3" => "https://cpan.metacpan.org/authors/id/S/SH/SHAY/perl-5.24.3.tar.gz",
    "5.24.2" => "https://cpan.metacpan.org/authors/id/S/SH/SHAY/perl-5.24.2.tar.gz",
    "5.24.1" => "https://cpan.metacpan.org/authors/id/S/SH/SHAY/perl-5.24.1.tar.gz",
    "5.24.0" => "https://cpan.metacpan.org/authors/id/R/RJ/RJBS/perl-5.24.0.tar.bz2",
    "5.22.4" => "https://cpan.metacpan.org/authors/id/S/SH/SHAY/perl-5.22.4.tar.bz2",
    "5.22.3" => "https://cpan.metacpan.org/authors/id/S/SH/SHAY/perl-5.22.3.tar.gz",
    "5.22.2" => "https://cpan.metacpan.org/authors/id/S/SH/SHAY/perl-5.22.2.tar.bz2",
    "5.22.1" => "https://cpan.metacpan.org/authors/id/S/SH/SHAY/perl-5.22.1.tar.gz",
    "5.22.0" => "https://cpan.metacpan.org/authors/id/R/RJ/RJBS/perl-5.22.0.tar.bz2",
    "5.20.3" => "https://cpan.metacpan.org/authors/id/S/SH/SHAY/perl-5.20.3.tar.bz2",
    "5.20.2" => "https://cpan.metacpan.org/authors/id/S/SH/SHAY/perl-5.20.2.tar.bz2",
    "5.20.1" => "https://cpan.metacpan.org/authors/id/S/SH/SHAY/perl-5.20.1.tar.bz2",
    "5.20.0" => "https://cpan.metacpan.org/authors/id/R/RJ/RJBS/perl-5.20.0.tar.bz2",
    "5.18.4" => "https://cpan.metacpan.org/authors/id/R/RJ/RJBS/perl-5.18.4.tar.bz2",
    "5.18.3" => "https://cpan.metacpan.org/authors/id/R/RJ/RJBS/perl-5.18.3.tar.bz2",
    "5.18.2" => "https://cpan.metacpan.org/authors/id/R/RJ/RJBS/perl-5.18.2.tar.bz2",
    "5.18.1" => "https://cpan.metacpan.org/authors/id/R/RJ/RJBS/perl-5.18.1.tar.bz2",
    "5.18.0" => "https://cpan.metacpan.org/authors/id/R/RJ/RJBS/perl-5.18.0.tar.bz2",
    "5.16.3" => "https://cpan.metacpan.org/authors/id/R/RJ/RJBS/perl-5.16.3.tar.bz2",
    "5.16.2" => "https://cpan.metacpan.org/authors/id/R/RJ/RJBS/perl-5.16.2.tar.bz2",
    "5.16.1" => "https://cpan.metacpan.org/authors/id/R/RJ/RJBS/perl-5.16.1.tar.bz2",
    "5.16.0" => "https://cpan.metacpan.org/authors/id/R/RJ/RJBS/perl-5.16.0.tar.bz2",
    "5.14.4" => "https://cpan.metacpan.org/authors/id/D/DA/DAPM/perl-5.14.4.tar.bz2",
    "5.14.3" => "https://cpan.metacpan.org/authors/id/D/DO/DOM/perl-5.14.3.tar.bz2",
    "5.14.2" => "https://cpan.metacpan.org/authors/id/F/FL/FLORA/perl-5.14.2.tar.bz2",
    "5.14.1" => "https://cpan.metacpan.org/authors/id/J/JE/JESSE/perl-5.14.1.tar.bz2",
    "5.14.0" => "https://cpan.metacpan.org/authors/id/J/JE/JESSE/perl-5.14.0.tar.bz2",
    "5.12.5" => "https://cpan.metacpan.org/authors/id/D/DO/DOM/perl-5.12.5.tar.bz2",
    "5.12.4" => "https://cpan.metacpan.org/authors/id/L/LB/LBROCARD/perl-5.12.4.tar.bz2",
    "5.12.3" => "https://cpan.metacpan.org/authors/id/R/RJ/RJBS/perl-5.12.3.tar.bz2",
    "5.12.2" => "https://cpan.metacpan.org/authors/id/J/JE/JESSE/perl-5.12.2.tar.bz2",
    "5.12.1" => "https://cpan.metacpan.org/authors/id/J/JE/JESSE/perl-5.12.1.tar.bz2",
    "5.12.0" => "https://cpan.metacpan.org/authors/id/J/JE/JESSE/perl-5.12.0.tar.bz2",
    "5.10.1" => "https://cpan.metacpan.org/authors/id/D/DA/DAPM/perl-5.10.1.tar.bz2",
    "5.10.0" => "https://cpan.metacpan.org/authors/id/R/RG/RGARCIA/perl-5.10.0.tar.gz",
    "5.8.9" => "https://cpan.metacpan.org/authors/id/N/NW/NWCLARK/perl-5.8.9.tar.bz2",
    "5.10.1" => "https://cpan.metacpan.org/authors/id/D/DA/DAPM/perl-5.10.1.tar.bz2",
    "5.10.0" => "https://cpan.metacpan.org/authors/id/R/RG/RGARCIA/perl-5.10.0.tar.gz",
    "5.8.9" => "https://cpan.metacpan.org/authors/id/N/NW/NWCLARK/perl-5.8.9.tar.bz2",
    "5.8.8" => "https://cpan.metacpan.org/authors/id/N/NW/NWCLARK/perl-5.8.8.tar.bz2",
    "5.8.7" => "https://cpan.metacpan.org/authors/id/N/NW/NWCLARK/perl-5.8.7.tar.bz2",
    "5.8.6" => "https://cpan.metacpan.org/authors/id/N/NW/NWCLARK/perl-5.8.6.tar.bz2",
    "5.8.5" => "https://cpan.metacpan.org/authors/id/N/NW/NWCLARK/perl-5.8.5.tar.bz2",

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
system("nmake", "INST_TOP=$install_dir", "CCTYPE=MSVC142") == 0
    or die "Failed to build";

print STDERR "nmake install\n";
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
