#!/usr/bin/env perl

use utf8;
use warnings;
use strict;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Try::Tiny;
use Perl::Build;
use File::Spec;
use File::Path qw/make_path/;
use version 0.77 ();
use Actions::Core qw/group set_failed/;

sub run {
    my $version = $ENV{PERL_VERSION};
    my $tmpdir = File::Spec->rel2abs($ENV{RUNNER_TEMP} || "tmp");
    make_path($tmpdir);
    my $install_dir = File::Spec->rel2abs(
        File::Spec->catdir($ENV{RUNNER_TOOL_CACHE} || $tmpdir, "perl", $version, "x64"));

    group "build perl $version" => sub {
        local $ENV{PERL5_PATCHPERL_PLUGIN} = "GitHubActions";

        my $jobs = 1;

        Perl::Build->install_from_cpan(
            $version => (
                dst_path          => $install_dir,
                configure_options => ["-de", "-Dman1dir=none", "-Dman3dir=none"],
                jobs              => $jobs,
            )
        );
    };

    group "perl -V" => sub {
        system(File::Spec->catfile($install_dir, 'bin', 'perl'), '-V') == 0 or die "$!";
    };

    group "archiving" => sub {
        chdir $install_dir or die "failed to cd $install_dir: $!";
        system("tar", "zcf", "$tmpdir/perl.tar.gz", ".") == 0
            or die "failed to archive";
    };
}

try {
    run();
} catch {
    set_failed("$_");
};

1;
