#!C:\Strawberry\perl\bin\perl.exe

use utf8;
use warnings;
use strict;
use 5.026002;
use LWP::UserAgent;

my $version = $ENV{PERL_VERSION};
print STDERR "downloading perl $version...\n";
my $ua = LWP::UserAgent->new;
my $response = $ua->get("https://cpan.metacpan.org/authors/id/X/XS/XSAWYERX/perl-5.30.0.tar.gz"); # TODO: auto generate url
if (!$response->is_success) {
    die "download failed: " . $response->status_line;
}

my $tmpdir = $ENV{RUNNER_TEMP};
open my $fh, ">", "$tmpdir\\perl-5.30.0.tar.gz" or die "$!"; 
binmode $fh;
print $fh $response->content;
close $fh;

print STDERR "extracting...\n";
chdir $tmpdir or die "failed to cd $tmpdir: $!";
system("7z", "x", "perl-5.30.0.tar.gz") == 0 or die "Failed to extract gz";
system("7z", "x", "perl-5.30.0.tar") == 0 or die "Failed to extract tar";

print STDERR "start build\n";
chdir "$tmpdir\\perl-5.30.0\\win32" or die "failed to cd $tmpdir\\perl-5.30.0\\win32: $!";
my $install_dir = "$ENV{RUNNER_TOOL_CACHE}\\perl\\${version}\\x64";
system("gmake", "INST_TOP=$install_dir") == 0
    or die "Failed to build";

print STDERR "start install\n";
system("gmake", "install") == 0
    or die "Failed to install";

print STDERR "archiving...\n";
chdir $install_dir or die "failed to cd $install_dir: $!";
system("7z", "a", "$tmpdir\\perl.zip", ".") == 0
    or die "failed to archive";

1;
