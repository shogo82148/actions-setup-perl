package Devel::PatchPerl::Plugin::MinGW;

use utf8;
use strict;
use warnings;
use 5.026002;
use Devel::PatchPerl;
use File::pushd qw[pushd];

# copy utility functions from Devel::PatchPerl
*_is = *_Devel::PatchPerl::_is;
*_patch = *_Devel::PatchPerl::_patch;

my @patch = (
    {
        perl => [
            qr/.*/,
        ],
        subs => [
            # patches
        ],
    },
);

sub patchperl {
    my ($class, %args) = @_;
    my $vers = $args{version};
    my $source = $args{source};

    my $dir = pushd( $source );

    # copy from https://github.com/bingos/devel-patchperl/blob/acdcf1d67ae426367f42ca763b9ba6b92dd90925/lib/Devel/PatchPerl.pm#L301-L307
    for my $p ( grep { _is( $_->{perl}, $vers ) } @patch ) {
       for my $s (@{$p->{subs}}) {
         my($sub, @args) = @$s;
         push @args, $vers unless scalar @args;
         $sub->(@args);
       }
    }
}

1;
