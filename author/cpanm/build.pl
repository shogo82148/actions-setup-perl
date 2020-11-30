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
    "-o", "cpanm",
    "-d", "local,lib",
    "-e", join(
        ',',
        # configure modules
        'Module::Build',
        'App::cpanminus::fatscript',
        # test modules
        'Test2', 'App::Prove','TAP::Harness',
        # XS modules
        'Cwd',
    ),
    "--shebang", '#!/usr/bin/env perl',
    "cpanm.PL"
);

1;
