#!/usr/bin/env perl

use v5.42.0;
use utf8;
use JSON::PP;
use Digest::SHA qw(sha256_hex);
use File::Basename qw(dirname);
use File::Path qw(make_path remove_tree);
use File::Spec;
use File::Temp qw(tempdir);

# Pre-install Mozilla::CA under the "lib" directory.
#
# This script downloads the latest Mozilla-CA distribution from MetaCPAN and
# extracts its "lib/Mozilla" tree into this repository's "lib" directory so that
# Mozilla::CA (and its bundled cacert.pem) is available without installing it
# from CPAN at runtime.

my $root    = File::Spec->rel2abs(dirname(__FILE__));
my $lib_dir = File::Spec->catdir($root, "lib");

# Fetch the latest release metadata from MetaCPAN.
my $meta = decode_json(http_get("https://fastapi.metacpan.org/v1/download_url/Mozilla::CA"));
my $version      = $meta->{version};
my $download_url = $meta->{download_url};
my $sha256       = $meta->{checksum_sha256};
say "latest Mozilla::CA is $version";
say "downloading $download_url";

my $tmp = tempdir(CLEANUP => 1);

# Download the tarball.
my $tarball = File::Spec->catfile($tmp, "Mozilla-CA.tar.gz");
my $content = http_get($download_url);
open my $fh, ">:raw", $tarball or die "failed to open $tarball: $!";
print $fh $content;
close $fh;

# Verify the checksum.
my $got = sha256_hex($content);
die "checksum mismatch: expected $sha256, got $got\n" if $sha256 && $got ne $sha256;
say "verified sha256: $got";

# Extract the tarball.
system("tar", "xzf", $tarball, "-C", $tmp) == 0 or die "failed to extract $tarball\n";

# Locate the extracted "lib/Mozilla" directory.
my ($src) = glob File::Spec->catdir($tmp, "Mozilla-CA-*", "lib", "Mozilla");
die "could not find lib/Mozilla in the distribution\n" unless $src && -d $src;

# Replace the existing copy under lib/Mozilla.
my $dest = File::Spec->catdir($lib_dir, "Mozilla");
remove_tree($dest) if -d $dest;
make_path($lib_dir);
system("cp", "-R", $src, $dest) == 0 or die "failed to copy into $dest\n";

say "installed Mozilla::CA $version into $dest";

# Download a URL and return its body, dying on any error.
sub http_get {
    my ($url) = @_;
    my $body = `curl --fail --silent --show-error --location "$url"`;
    die "failed to download $url\n" if $? != 0;
    return $body;
}
