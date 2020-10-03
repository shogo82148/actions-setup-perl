use Test::More;
use Actions::Core qw(perl_versions);

# use in array context
my @versions = perl_versions();
is $versions[-1], '5.8.5';

# use in scalar context
my $versions = perl_versions();
is $versions->[-1], '5.8.5';

# distribution: 'stawberry'
$versions = perl_versions( platform => 'win32', distribution => 'strawberry' );
is $versions->[-1], '5.14.2';

done_testing;
