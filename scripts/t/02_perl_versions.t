use Test::More;
use Actions::Core qw(perl_versions);

# use in array context
my @versions = perl_versions();
is $versions[-1], '5.8.9', 'the latest version of 5.8.x';

# use in scalar context
my $versions = perl_versions();
is $versions->[-1], '5.8.9', 'the latest version of 5.8.x';

$versions = perl_versions(patch => 1);
is $versions->[-1], '5.8.5', 'the oldest version of 5.8.x';

# distribution: 'stawberry'
$versions = perl_versions( platform => 'win32', distribution => 'strawberry' );
is $versions->[-1], '5.14.4', 'the latest version of strawberry perl 5.14.x';

done_testing;
