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

# Verify the checksum. Require a well-formed SHA-256 before installing so a
# missing or malformed checksum is never silently treated as verified.
die "missing or malformed sha256 checksum for $download_url\n"
    unless defined $sha256 && $sha256 =~ /\A[0-9a-f]{64}\z/;
my $got = sha256_hex($content);
die "checksum mismatch: expected $sha256, got $got\n" if $got ne $sha256;
say "verified sha256: $got";

# Extract the tarball.
system("tar", "xzf", $tarball, "-C", $tmp) == 0 or die "failed to extract $tarball\n";

# Locate the extracted "lib/Mozilla" directory.
my ($src) = glob File::Spec->catdir($tmp, "Mozilla-CA-*", "lib", "Mozilla");
die "could not find lib/Mozilla in the distribution\n" unless $src && -d $src;

# Replace the existing copy under lib/Mozilla. Copy into a staging directory
# first and swap it in only once the copy succeeds, so a failed copy never
# leaves the previously installed CA bundle deleted or half-written.
my $dest    = File::Spec->catdir($lib_dir, "Mozilla");
my $staging = File::Spec->catdir($lib_dir, "Mozilla.new");
my $backup  = File::Spec->catdir($lib_dir, "Mozilla.old");

make_path($lib_dir);
remove_tree($staging) if -d $staging;
remove_tree($backup)  if -d $backup;

system("cp", "-R", $src, $staging) == 0 or die "failed to copy into $staging\n";

# Swap the staged copy in atomically, keeping a backup to roll back to.
rename($dest, $backup) if -d $dest;
unless (rename($staging, $dest)) {
    my $err = $!;
    rename($backup, $dest) if -d $backup;    # roll back to the previous copy
    remove_tree($staging) if -d $staging;
    die "failed to install into $dest: $err\n";
}
remove_tree($backup) if -d $backup;

say "installed Mozilla::CA $version into $dest";

# Download a URL and return its body, dying on any error. The URL is passed to
# curl as a process argument (no shell), so its contents can never be
# interpreted as shell syntax.
sub http_get {
    my ($url) = @_;
    open my $curl, "-|", "curl", "--fail", "--silent", "--show-error", "--location", $url
        or die "failed to run curl for $url: $!\n";
    binmode $curl;
    local $/;
    my $body = <$curl>;
    close $curl or die "failed to download $url\n";
    return defined $body ? $body : "";
}
