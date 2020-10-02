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
        'Digest::SHA',
        'File::Spec',
        'Params::Check',
        # configure modules
        'ExtUtils::MakeMaker', 'Module::Build',
        'ExtUtils::CBuilder', 'ExtUtils::MakeMaker::CPANfile',
        'Module::Build::Tiny', 'ExtUtils::ParseXS',
        'Devel::GlobalDestruction::XS',
        'App::cpanminus::fatscript',
        # test modules
        'Test', 'Test2', 'App::Prove','TAP::Harness', 'Perl::OSType',
        # core modules of perl 5
        'Cwd', 'Carp', 'Module::CoreList',
    ),
    "--shebang", '#!/usr/bin/env perl',
    "local/bin/cpm"
);

pl2bat(in=>"cpm");

1;
