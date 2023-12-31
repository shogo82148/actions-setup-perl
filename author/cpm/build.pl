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
    "-o", "cpm",
    "-d", "local",
    "-e", join(
        ',',
        # configure modules
        'ExtUtils::CBuilder', 'ExtUtils::MakeMaker::CPANfile',
        'Module::Build::Tiny', 'ExtUtils::ParseXS',
        'Devel::GlobalDestruction::XS',
        # test modules
        'Test2', 'App::Prove','TAP::Harness', 'Perl::OSType',
        # core modules of perl 5
        'Module::CoreList',
        # XS
        'Cwd',
        'Class::C3::XS',
    ),
    "--shebang", '#!/usr/bin/env perl',
    "local/bin/cpm"
);

1;
