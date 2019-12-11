#!/usr/bin/env perl

use strict;
use warnings;
use FindBin;
use App::FatPacker::Simple;
use Carton::Snapshot;

sub fatpack {
    App::FatPacker::Simple->new->parse_options(@_)->run
}

fatpack(
    "-o", "carton",
    "-d", "local",
    "-e", join(
        ',',
        # configure modules
        'ExtUtils::MakeMaker', 'Module::Build',
        # test modules
        'Test2,App::Prove','TAP::Harness',
        # core modules of perl 5
        'Cwd', 'Carp', 'Module::CoreList',
        # XS modules
        'Devel::GlobalDestruction::XS','Class::C3::XS',
        # the Carton does not use Path::Tiny->digest, so we can remove it
        'Digest::SHA'
    ),
    "--shebang", '#!/usr/bin/env perl',
    "local/bin/carton"
);
