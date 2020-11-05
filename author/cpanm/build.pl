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
    "-d", "local",
    "-e", join(
        ',',
        # configure modules
        'Module::Build',
        'App::cpanminus::fatscript',
        # test modules
        'Test2', 'App::Prove','TAP::Harness',
    ),
    "--shebang", '#!/usr/bin/env perl',
    "local/bin/cpanm"
);

pl2bat(in=>"cpanm");

1;
