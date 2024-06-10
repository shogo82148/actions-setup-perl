#!/usr/bin/env perl

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/local/lib/perl5";
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
        # fat-packing
        'App::FatPacker', 'App::FatPacker::Simple',
        'Clone', 'Distribution::Metadata',
        'ExtUtils::CBuilder', 'ExtUtils::ParseXS',
        'IO::String', 'JSON', 'Module::Build::Tiny', 'PPI',
        'Params::Util', 'Cwd', 'List::Util',
        'Perl::Strip', 'Scalar::Util', 'Storable',
        'Task::Weaken', 'Perl::OSType', 'XSLoader', 'common::sense',
        # test modules
        'Test2','App::Prove','TAP::Harness',
        # core modules of perl 5
        'Module::CoreList',
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
