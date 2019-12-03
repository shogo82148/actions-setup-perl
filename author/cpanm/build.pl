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
    "-o", "cpanm",
    "-d", "local",
    "-e", join(
        ',',
        # configure modules
        'ExtUtils::MakeMaker', 'Module::Build',
        'App::cpanminus::fatscript',
        # test modules
        'Test2,App::Prove','TAP::Harness',
        # core modules of perl 5
        'Cwd'
    ),
    "--shebang", '#!/usr/bin/env perl',
    "local/bin/cpanm"
);
