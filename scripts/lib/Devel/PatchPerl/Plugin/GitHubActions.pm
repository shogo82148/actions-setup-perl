package Devel::PatchPerl::Plugin::GitHubActions;

use utf8;
use strict;
use warnings;
use 5.026001;
use File::pushd qw[pushd];
use File::Basename;
use File::Slurp qw/read_file/;
use File::Spec;
use JSON qw/encode_json decode_json/;
use Devel::PatchPerl;

use Devel::PatchPerl::Plugin::MinGW;

# copy utility functions from Devel::PatchPerl
*_is = *Devel::PatchPerl::_is;
*_patch = *Devel::PatchPerl::_patch;

my @patch = (
);

sub patchperl {
    my ($class, %args) = @_;
    my $vers = $args{version};
    my $source = $args{source};
    my $dir = pushd( $source );

    if ($^O eq 'MSWin32') {
        Devel::PatchPerl::Plugin::MinGW->patchperl(%args);
    }

    # copy from https://github.com/bingos/devel-patchperl/blob/acdcf1d67ae426367f42ca763b9ba6b92dd90925/lib/Devel/PatchPerl.pm#L301-L307
    for my $p ( grep { _is( $_->{perl}, $vers ) } @patch ) {
       for my $s (@{$p->{subs}}) {
         my($sub, @args) = @$s;
         push @args, $vers unless scalar @args;
         $sub->(@args);
       }
    }

    _patch_patchlevel();
}

# adapted from patchlevel.h for use with perls that predate it
sub _patch_patchlevel {
    my $package_json = File::Spec->catfile(dirname(__FILE__), ("..") x 5, "package.json");
    my $package = decode_json(read_file($package_json));
    my $dpv = $package->{version};
    open my $plin, "patchlevel.h" or die "Couldn't open patchlevel.h : $!";
    open my $plout, ">patchlevel.new" or die "Couldn't write on patchlevel.new : $!";
    my $seen=0;
    while (<$plin>) {
        if (/\t,NULL/ and $seen) {
            print {$plout} qq{\t,"shogo82148/actions-setup-perl $dpv"\n};
        }
        $seen++ if /local_patches\[\]/;
        print {$plout} $_;
    }
    close $plout or die "Couldn't close filehandle writing to patchlevel.new : $!";
    close $plin or die "Couldn't close filehandle reading from patchlevel.h : $!";
    unlink "patchlevel.bak" or warn "Couldn't unlink patchlevel.bak : $!"
        if -e "patchlevel.bak";
    rename "patchlevel.h", "patchlevel.bak" or
        die "Couldn't rename patchlevel.h to patchlevel.bak : $!";
    rename "patchlevel.new", "patchlevel.h" or
        die "Couldn't rename patchlevel.new to patchlevel.h : $!";
}

# it is same as ge operator of strings but it assumes the strings are versions
sub _ge {
    my ($v1, $v2) = @_;
    return version->parse("v$v1") >= version->parse("v$v2");
}

1;
