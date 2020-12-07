#!/usr/bin/env perl

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/local/lib/perl5";
use App::FatPacker::Simple;
use Carton::Snapshot;

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
        # fat-packing
        'App::FatPacker', 'App::FatPacker::Simple',
        'Clone', 'Distribution::Metadata',
        'ExtUtils::CBuilder', 'ExtUtils::ParseXS',
        'IO::String', 'JSON', 'Module::Build::Tiny', 'PPI',
        'Params::Util', 'Cwd', 'List::Util',
        'Perl::Strip', 'Scalar::Util', 'Storable',
        'Task::Weaken', 'Perl::OSType', 'XSLoader', 'common::sense',
        # test modules
        'Test2', 'App::Prove','TAP::Harness',
        # XS modules
        'Cwd',
    ),
    "--shebang", '#!/usr/bin/env perl',
    "cpanm.PL"
);

1;
