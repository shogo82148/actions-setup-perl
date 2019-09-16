#!C:\Strawberry\perl\bin\perl.exe

use utf8;
use warnings;
use strict;
use 5.026002;
use LWP::UserAgent;

my $ua = LWP::UserAgent->new;
my $response = $ua->get("https://cpan.metacpan.org/authors/id/X/XS/XSAWYERX/perl-5.30.0.tar.gz"); # TODO: auto generate url
if (!$response->is_success) {
    die "download failed: " . $response->status_line;
}

open my $fh, ">", "perl-5.30.0.tar.gz" or die "$!"; 
print $fh $response->content;

1;
