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

open my $fh, ">", "perl-5.30.0.tar.gz" or die "$!"; 
print $fh $response->content;

print STDERR "extracting...\n";
system("7z x perl-5.30.0.tar.gz | 7z x -si -ttar") == 0 or die "Failed to extract";

print STDERR "start build\n";
system("gmake", "-C" "perl-5.30.0\\win32", "INST_TOP=$ENV{RUNNER_TOOL_CACHE}\\perl\\${version}\\x64")

1;
