#!/usr/bin/env perl

use strict;
use warnings;
use FindBin;
use App::FatPacker::Simple;
use Carton::Snapshot;
use ExtUtils::PL2Bat qw/pl2bat/;

sub fatpack {
    App::FatPacker::Simple->new->parse_options(@_)->run
}

fatpack(
    "-o", "carton",
    "-d", "local",
    "-e", join(
        ',',
        # configure modules
        'Module::Build',
        # test modules
        'Test2','App::Prove','TAP::Harness',
        # XS modules
        'Cwd',
        'Devel::GlobalDestruction::XS','Class::C3::XS',
        # the Carton does not use Path::Tiny->digest, so we can remove it
        'Digest::SHA'
    ),
    "--shebang", '#!/usr/bin/env perl',
    "local/bin/carton"
);

1;
